package diy.atelier.core.atproto

import java.math.BigInteger
import java.net.URI
import java.nio.charset.StandardCharsets
import java.security.SecureRandom
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.util.Base64
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AtProtoPrimitivesTest {
    @Test
    fun pkceMatchesRfc7636S256Fixture() {
        val pair = PkcePair(fixture.pkceVerifier)
        assertEquals(1, fixture.version)
        assertEquals(fixture.pkceChallenge, pair.challenge)
    }

    @Test
    fun pkceGenerationUsesRfcLengthBoundsAndInjectedEntropy() {
        val random = object : SecureRandom() {
            override fun nextBytes(bytes: ByteArray) {
                bytes.indices.forEach { bytes[it] = it.toByte() }
            }
        }
        val pair = PkcePair.generate(byteCount = 32, random = random)
        assertEquals("AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8", pair.verifier)
        assertEquals(43, pair.verifier.length)
        val error = assertThrows(AtProtoPrimitiveException::class.java) {
            PkcePair.generate(byteCount = 31, random = random)
        }
        assertEquals(AtProtoPrimitiveError.INVALID_PKCE_BYTE_COUNT, error.reason)
    }

    @Test
    fun dpopProofBindsHashMethodNormalizedTargetTimeNonceAndJti() {
        val key = DpopKey.generate()
        val proof = key.proof(
            method = fixture.dpopMethodInput,
            target = URI(fixture.dpopTarget),
            accessToken = fixture.accessToken,
            nonce = fixture.dpopNonce,
            issuedAtEpochSeconds = fixture.dpopIssuedAtEpochSeconds,
            identifier = fixture.dpopJti,
        )
        val segments = proof.split('.')
        assertEquals(3, segments.size)
        val header = String(segments[0].decodeBase64Url(), StandardCharsets.UTF_8)
        val payload = String(segments[1].decodeBase64Url(), StandardCharsets.UTF_8)
        assertTrue(header.startsWith("{\"alg\":\"ES256\",\"jwk\":{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":"))
        assertTrue(header.endsWith("},\"typ\":\"dpop+jwt\"}"))
        val publicKey = key.verificationKey as ECPublicKey
        assertTrue(header.contains("\"x\":\"${publicKey.w.affineX.toUnsignedFixed(32).base64Url()}\""))
        assertTrue(header.contains("\"y\":\"${publicKey.w.affineY.toUnsignedFixed(32).base64Url()}\""))
        assertEquals(
            "{\"ath\":\"${fixture.accessTokenSha256Base64Url}\",\"htm\":\"${fixture.dpopMethod}\"," +
                "\"htu\":\"${fixture.dpopNormalizedHtu}\",\"iat\":${fixture.dpopIssuedAtEpochSeconds}," +
                "\"jti\":\"${fixture.dpopJti}\",\"nonce\":\"${fixture.dpopNonce}\"}",
            payload,
        )

        val signature = segments[2].decodeBase64Url()
        assertEquals(64, signature.size)
        val verifier = Signature.getInstance("SHA256withECDSA").apply {
            initVerify(key.verificationKey)
            update("${segments[0]}.${segments[1]}".toByteArray(StandardCharsets.UTF_8))
        }
        assertTrue(verifier.verify(JoseEcdsa.joseToDer(signature)))
    }

    @Test
    fun dpopRejectsMissingBindingValuesAndCredentialBearingTargets() {
        val key = DpopKey.generate()
        assertEquals(
            AtProtoPrimitiveError.INVALID_DPOP_METHOD,
            assertThrows(AtProtoPrimitiveException::class.java) {
                key.proof(" ", URI("https://pds.example"), identifier = "jti")
            }.reason,
        )
        assertEquals(
            AtProtoPrimitiveError.INVALID_DPOP_IDENTIFIER,
            assertThrows(AtProtoPrimitiveException::class.java) {
                key.proof("GET", URI("https://pds.example"), identifier = " ")
            }.reason,
        )
        assertEquals(
            AtProtoPrimitiveError.INVALID_DPOP_TARGET,
            assertThrows(AtProtoPrimitiveException::class.java) {
                key.proof("GET", URI("https://user@pds.example/resource"), identifier = "jti")
            }.reason,
        )
    }

    @Test
    fun joseSignatureConversionPreservesFixedWidthIntegers() {
        val raw = ByteArray(64) { index ->
            when (index) {
                0 -> 0x80.toByte()
                32 -> 0x00
                33 -> 0x7f
                else -> index.toByte()
            }
        }
        assertArrayEquals(raw, JoseEcdsa.derToJose(JoseEcdsa.joseToDer(raw)))
    }

    @Test
    fun xrpcTargetPreservesCamelCaseAndDeterministicQueryEncoding() {
        val target = XrpcRequestTarget.uri(
            service = URI(fixture.xrpcService),
            method = fixture.xrpcMethod,
            queryItems = listOf(
                XrpcQueryItem(fixture.xrpcQueryName, fixture.xrpcQueryValue),
            ),
        )
        assertEquals(fixture.xrpcTarget, target.toASCIIString())
        assertTrue(target.rawPath.endsWith(fixture.xrpcMethod))
        assertFalse(target.rawPath.endsWith(fixture.xrpcMethod.lowercase()))
        assertEquals(
            "/xrpc/${fixture.xrpcMethod}",
            XrpcRequestTarget.uri(
                URI(fixture.xrpcService),
                "Com.AtProto.repo.${fixture.xrpcMethod.substringAfterLast('.')}",
            ).rawPath,
        )
    }

    @Test
    fun xrpcTargetPercentEncodesQueryDelimiters() {
        val target = XrpcRequestTarget.uri(
            service = URI(fixture.xrpcService),
            method = fixture.xrpcMethod,
            queryItems = listOf(XrpcQueryItem("cursor", "next page/+")),
        )
        assertTrue(target.toASCIIString().endsWith("?cursor=next%20page%2F%2B"))
    }

    @Test
    fun xrpcTargetRejectsMalformedNsidAndUnsafeBaseComponents() {
        val invalidMethod = assertThrows(AtProtoPrimitiveException::class.java) {
            XrpcRequestTarget.uri(URI("https://pds.example"), "invalid")
        }
        assertEquals(AtProtoPrimitiveError.INVALID_XRPC_METHOD, invalidMethod.reason)

        for (method in listOf("com.atproto.repo.get-record", "1om.atproto.repo.getRecord", "com..repo.getRecord")) {
            assertThrows(AtProtoPrimitiveException::class.java) {
                XrpcRequestTarget.uri(URI("https://pds.example"), method)
            }
        }
        for (service in listOf("ftp://pds.example", "https://user@pds.example", "https://pds.example?query=yes")) {
            val error = assertThrows(AtProtoPrimitiveException::class.java) {
                XrpcRequestTarget.uri(URI(service), fixture.xrpcMethod)
            }
            assertEquals(AtProtoPrimitiveError.INVALID_XRPC_BASE_URL, error.reason)
        }
    }

    private fun BigInteger.toUnsignedFixed(size: Int): ByteArray {
        val bytes = toByteArray().dropWhile { it == 0.toByte() }.toByteArray()
        return ByteArray(size - bytes.size) + bytes
    }

    private fun ByteArray.base64Url(): String =
        Base64.getUrlEncoder().withoutPadding().encodeToString(this)

    companion object {
        private val fixture: ATProtoPrimitiveFixture by lazy(ATProtoPrimitiveFixture::load)
    }
}

private data class ATProtoPrimitiveFixture(
    val version: Int,
    val pkceVerifier: String,
    val pkceChallenge: String,
    val accessToken: String,
    val accessTokenSha256Base64Url: String,
    val dpopMethodInput: String,
    val dpopMethod: String,
    val dpopTarget: String,
    val dpopNormalizedHtu: String,
    val dpopNonce: String,
    val dpopIssuedAtEpochSeconds: Long,
    val dpopJti: String,
    val xrpcService: String,
    val xrpcMethod: String,
    val xrpcQueryName: String,
    val xrpcQueryValue: String,
    val xrpcTarget: String,
) {
    companion object {
        fun load(): ATProtoPrimitiveFixture {
            val source = requireNotNull(
                ATProtoPrimitiveFixture::class.java.classLoader
                    ?.getResourceAsStream("atproto-primitives.json"),
            ) { "Shared ATProto primitive fixture is missing from the Android test resources." }
                .bufferedReader(StandardCharsets.UTF_8)
                .use { it.readText() }
            fun string(name: String): String = requireNotNull(
                Regex("\"${Regex.escape(name)}\"\\s*:\\s*\"([^\"\\\\]*)\"").find(source),
            ) { "Shared ATProto primitive fixture is missing $name." }.groupValues[1]
            fun long(name: String): Long = requireNotNull(
                Regex("\"${Regex.escape(name)}\"\\s*:\\s*(\\d+)").find(source),
            ) { "Shared ATProto primitive fixture is missing $name." }.groupValues[1].toLong()
            return ATProtoPrimitiveFixture(
                version = long("version").toInt(),
                pkceVerifier = string("pkceVerifier"),
                pkceChallenge = string("pkceChallenge"),
                accessToken = string("accessToken"),
                accessTokenSha256Base64Url = string("accessTokenSha256Base64Url"),
                dpopMethodInput = string("dpopMethodInput"),
                dpopMethod = string("dpopMethod"),
                dpopTarget = string("dpopTarget"),
                dpopNormalizedHtu = string("dpopNormalizedHtu"),
                dpopNonce = string("dpopNonce"),
                dpopIssuedAtEpochSeconds = long("dpopIssuedAtEpochSeconds"),
                dpopJti = string("dpopJti"),
                xrpcService = string("xrpcService"),
                xrpcMethod = string("xrpcMethod"),
                xrpcQueryName = string("xrpcQueryName"),
                xrpcQueryValue = string("xrpcQueryValue"),
                xrpcTarget = string("xrpcTarget"),
            )
        }
    }
}
