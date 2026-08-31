package diy.atelier.core.atproto

import java.math.BigInteger
import java.net.URI
import java.nio.charset.StandardCharsets
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.time.Instant
import java.util.Base64
import java.util.Locale
import java.util.UUID

enum class AtProtoPrimitiveError {
    INVALID_PKCE_BYTE_COUNT,
    INVALID_DPOP_METHOD,
    INVALID_DPOP_TARGET,
    INVALID_DPOP_IDENTIFIER,
    INVALID_XRPC_BASE_URL,
    INVALID_XRPC_METHOD,
}

class AtProtoPrimitiveException(
    val reason: AtProtoPrimitiveError,
    message: String,
) : IllegalArgumentException(message)

/**
 * RFC 7636 S256 primitives only. Authorization discovery, PAR, callback
 * validation, token exchange, and verifier persistence belong to a later OAuth
 * layer and are deliberately absent here.
 */
class PkcePair private constructor(
    val verifier: String,
    val challenge: String,
) {
    constructor(verifier: String) : this(
        verifier = verifier,
        challenge = sha256(verifier.toByteArray(StandardCharsets.UTF_8)).base64Url(),
    )

    companion object {
        fun generate(
            byteCount: Int = 48,
            random: SecureRandom = SecureRandom(),
        ): PkcePair {
            if (byteCount !in 32..96) {
                throw AtProtoPrimitiveException(
                    AtProtoPrimitiveError.INVALID_PKCE_BYTE_COUNT,
                    "PKCE entropy must be between 32 and 96 bytes.",
                )
            }
            val bytes = ByteArray(byteCount).also(random::nextBytes)
            return PkcePair(bytes.base64Url())
        }
    }
}

/**
 * An in-memory P-256 signing key for producing RFC 9449 DPoP proofs.
 *
 * This type does not persist key material. Production OAuth code must provide
 * an Android Keystore-backed lifecycle before sessions or tokens are added.
 */
class DpopKey private constructor(
    private val keyPair: KeyPair,
) {
    internal val verificationKey get() = keyPair.public

    fun proof(
        method: String,
        target: URI,
        accessToken: String? = null,
        nonce: String? = null,
        issuedAtEpochSeconds: Long = Instant.now().epochSecond,
        identifier: String = UUID.randomUUID().toString(),
        signatureRandom: SecureRandom = SecureRandom(),
    ): String {
        val normalizedMethod = method.trim().uppercase(Locale.ROOT)
        if (normalizedMethod.isEmpty()) {
            throw AtProtoPrimitiveException(
                AtProtoPrimitiveError.INVALID_DPOP_METHOD,
                "A DPoP HTTP method is required.",
            )
        }
        if (identifier.isBlank()) {
            throw AtProtoPrimitiveException(
                AtProtoPrimitiveError.INVALID_DPOP_IDENTIFIER,
                "A DPoP jti is required.",
            )
        }

        val publicKey = keyPair.public as ECPublicKey
        val header = buildString {
            append("{\"alg\":\"ES256\",\"jwk\":{")
            append("\"crv\":\"P-256\",\"kty\":\"EC\",")
            append("\"x\":")
            appendJsonString(publicKey.w.affineX.toUnsignedFixed(32).base64Url())
            append(",\"y\":")
            appendJsonString(publicKey.w.affineY.toUnsignedFixed(32).base64Url())
            append("},\"typ\":\"dpop+jwt\"}")
        }
        val claims = sortedMapOf(
            "htm" to normalizedMethod,
            "htu" to normalizeHtu(target),
            "jti" to identifier,
        )
        nonce?.let { claims["nonce"] = it }
        accessToken?.let {
            claims["ath"] = sha256(it.toByteArray(StandardCharsets.UTF_8)).base64Url()
        }
        val payload = buildString {
            append('{')
            val entries = claims.entries.toMutableList()
                .map { it.key to JsonClaim.StringValue(it.value) }
                .plus("iat" to JsonClaim.IntegerValue(issuedAtEpochSeconds))
                .sortedBy { it.first }
            entries.forEachIndexed { index, (name, value) ->
                if (index > 0) append(',')
                appendJsonString(name)
                append(':')
                when (value) {
                    is JsonClaim.StringValue -> appendJsonString(value.value)
                    is JsonClaim.IntegerValue -> append(value.value)
                }
            }
            append('}')
        }
        val signingInput = "${header.utf8().base64Url()}.${payload.utf8().base64Url()}"
        val derSignature = Signature.getInstance("SHA256withECDSA").run {
            initSign(keyPair.private, signatureRandom)
            update(signingInput.utf8())
            sign()
        }
        return "$signingInput.${JoseEcdsa.derToJose(derSignature).base64Url()}"
    }

    companion object {
        fun generate(random: SecureRandom = SecureRandom()): DpopKey {
            val generator = KeyPairGenerator.getInstance("EC")
            generator.initialize(ECGenParameterSpec("secp256r1"), random)
            return DpopKey(generator.generateKeyPair())
        }

        private fun normalizeHtu(target: URI): String {
            val scheme = target.scheme?.lowercase(Locale.ROOT)
            if (
                scheme !in setOf("http", "https") ||
                target.rawAuthority.isNullOrBlank() ||
                target.host.isNullOrBlank() ||
                target.rawUserInfo != null
            ) {
                throw AtProtoPrimitiveException(
                    AtProtoPrimitiveError.INVALID_DPOP_TARGET,
                    "A DPoP target must be an absolute HTTP(S) URI.",
                )
            }
            val raw = target.toASCIIString()
            val boundary = listOf(raw.indexOf('?'), raw.indexOf('#'))
                .filter { it >= 0 }
                .minOrNull()
            return boundary?.let { raw.substring(0, it) } ?: raw
        }
    }
}

data class XrpcQueryItem(
    val name: String,
    val value: String?,
)

/**
 * Builds XRPC targets without performing a request. It intentionally owns no
 * OAuth session, nonce-retry, response-decoding, or network behavior.
 */
object XrpcRequestTarget {
    fun uri(
        service: URI,
        method: String,
        queryItems: List<XrpcQueryItem> = emptyList(),
    ): URI {
        val trimmedMethod = method.trim()
        val normalizedMethod = Nsid.normalize(trimmedMethod)
        if (normalizedMethod == null) {
            throw AtProtoPrimitiveException(
                AtProtoPrimitiveError.INVALID_XRPC_METHOD,
                "Invalid XRPC NSID: $method",
            )
        }
        val scheme = service.scheme?.lowercase(Locale.ROOT)
        if (
            scheme !in setOf("http", "https") ||
            service.rawAuthority.isNullOrBlank() ||
            service.host.isNullOrBlank() ||
            service.rawUserInfo != null ||
            service.rawQuery != null ||
            service.rawFragment != null
        ) {
            throw AtProtoPrimitiveException(
                AtProtoPrimitiveError.INVALID_XRPC_BASE_URL,
                "An absolute HTTP(S) service URL without credentials, query, or fragment is required.",
            )
        }

        val servicePath = service.rawPath.orEmpty().trimEnd('/')
        val base = "${service.scheme}://${service.rawAuthority}$servicePath"
        val query = queryItems.takeIf { it.isNotEmpty() }?.joinToString("&") { item ->
            val name = item.name.percentEncodeQueryComponent()
            item.value?.let { "$name=${it.percentEncodeQueryComponent()}" } ?: name
        }
        val value = buildString {
            append(base)
            append("/xrpc/")
            // Authority labels are normalized, while the final camel-case
            // method name remains a case-sensitive identifier.
            append(normalizedMethod)
            query?.let { append('?').append(it) }
        }
        return try {
            URI(value)
        } catch (_: IllegalArgumentException) {
            throw AtProtoPrimitiveException(
                AtProtoPrimitiveError.INVALID_XRPC_BASE_URL,
                "The XRPC target could not be represented as a URI.",
            )
        }
    }
}

internal object Nsid {
    private const val MaximumLength = 317
    private const val MaximumAuthorityLength = 253

    fun normalize(value: String): String? {
        if (value.isEmpty() || value.length > MaximumLength || !value.isAscii()) return null
        val labels = value.split('.')
        if (labels.size < 3 || labels.any(String::isEmpty)) return null
        val authority = labels.dropLast(1)
        if (
            authority.joinToString(".").length > MaximumAuthorityLength ||
            !authority.first().first().isAsciiLetter() ||
            !authority.all(::isValidAuthorityLabel)
        ) {
            return null
        }
        val name = labels.last()
        if (
            name.length !in 1..63 ||
            !name.first().isAsciiLetter() ||
            !name.all { it.isAsciiLetter() || it.isDigit() }
        ) {
            return null
        }
        return authority.joinToString(".") { it.lowercase(Locale.ROOT) } + "." + name
    }

    private fun isValidAuthorityLabel(label: String): Boolean =
        label.length in 1..63 &&
            label.first().isAsciiLetterOrDigit() &&
            label.last().isAsciiLetterOrDigit() &&
            label.all { it.isAsciiLetterOrDigit() || it == '-' }
}

private sealed interface JsonClaim {
    data class StringValue(val value: String) : JsonClaim
    data class IntegerValue(val value: Long) : JsonClaim
}

internal object JoseEcdsa {
    fun derToJose(der: ByteArray): ByteArray {
        var index = 0
        require(readByte(der, index++) == 0x30) { "ECDSA signature is not a DER sequence." }
        val sequenceLength = readLength(der, index)
        index = sequenceLength.next
        require(sequenceLength.length == der.size - index) { "ECDSA DER sequence has trailing data." }
        require(readByte(der, index++) == 0x02) { "ECDSA signature is missing r." }
        val rLength = readLength(der, index)
        index = rLength.next
        require(index + rLength.length <= der.size) { "Truncated ECDSA r integer." }
        val r = der.copyOfRange(index, index + rLength.length)
        index += rLength.length
        require(readByte(der, index++) == 0x02) { "ECDSA signature is missing s." }
        val sLength = readLength(der, index)
        index = sLength.next
        require(index + sLength.length <= der.size) { "Truncated ECDSA s integer." }
        val s = der.copyOfRange(index, index + sLength.length)
        index += sLength.length
        require(index == der.size) { "ECDSA DER signature has trailing data." }
        return r.toJoseInteger(32) + s.toJoseInteger(32)
    }

    fun joseToDer(raw: ByteArray): ByteArray {
        require(raw.size == 64) { "ES256 JOSE signatures must be 64 bytes." }
        val r = encodeInteger(raw.copyOfRange(0, 32))
        val s = encodeInteger(raw.copyOfRange(32, 64))
        val body = r + s
        return byteArrayOf(0x30) + encodeLength(body.size) + body
    }

    private data class Length(val length: Int, val next: Int)

    private fun readLength(bytes: ByteArray, start: Int): Length {
        val first = readByte(bytes, start)
        if (first < 0x80) return Length(first, start + 1)
        val count = first and 0x7f
        require(count in 1..4 && start + count < bytes.size) { "Invalid DER length." }
        var value = 0
        repeat(count) { offset -> value = (value shl 8) or readByte(bytes, start + 1 + offset) }
        require(value >= 0) { "Invalid DER length." }
        return Length(value, start + 1 + count)
    }

    private fun readByte(bytes: ByteArray, index: Int): Int {
        require(index in bytes.indices) { "Truncated DER signature." }
        return bytes[index].toInt() and 0xff
    }

    private fun ByteArray.toJoseInteger(size: Int): ByteArray {
        val firstNonZero = indexOfFirst { it != 0.toByte() }.let { if (it == -1) lastIndex else it }
        val unsigned = copyOfRange(firstNonZero, this.size)
        require(unsigned.size <= size) { "ECDSA integer exceeds curve size." }
        return ByteArray(size - unsigned.size) + unsigned
    }

    private fun encodeInteger(raw: ByteArray): ByteArray {
        val firstNonZero = raw.indexOfFirst { it != 0.toByte() }.let { if (it == -1) raw.lastIndex else it }
        var integer = raw.copyOfRange(firstNonZero, raw.size)
        if ((integer.first().toInt() and 0x80) != 0) integer = byteArrayOf(0) + integer
        return byteArrayOf(0x02) + encodeLength(integer.size) + integer
    }

    private fun encodeLength(length: Int): ByteArray {
        require(length >= 0)
        if (length < 0x80) return byteArrayOf(length.toByte())
        var remaining = length
        val reversed = mutableListOf<Byte>()
        while (remaining > 0) {
            reversed += (remaining and 0xff).toByte()
            remaining = remaining ushr 8
        }
        return byteArrayOf((0x80 or reversed.size).toByte()) + reversed.reversed()
    }
}

private fun sha256(value: ByteArray): ByteArray = MessageDigest.getInstance("SHA-256").digest(value)

internal fun ByteArray.base64Url(): String = Base64.getUrlEncoder().withoutPadding().encodeToString(this)

internal fun String.decodeBase64Url(): ByteArray = Base64.getUrlDecoder().decode(this)

private fun String.utf8(): ByteArray = toByteArray(StandardCharsets.UTF_8)

private fun BigInteger.toUnsignedFixed(size: Int): ByteArray {
    val bytes = toByteArray()
    val firstNonZero = bytes.indexOfFirst { it != 0.toByte() }.let { if (it == -1) bytes.lastIndex else it }
    val unsigned = bytes.copyOfRange(firstNonZero, bytes.size)
    require(unsigned.size <= size) { "EC coordinate exceeds curve size." }
    return ByteArray(size - unsigned.size) + unsigned
}

private fun StringBuilder.appendJsonString(value: String) {
    append('"')
    value.forEach { character ->
        when (character) {
            '"' -> append("\\\"")
            '\\' -> append("\\\\")
            '\b' -> append("\\b")
            '\u000C' -> append("\\f")
            '\n' -> append("\\n")
            '\r' -> append("\\r")
            '\t' -> append("\\t")
            else -> if (character.code < 0x20) {
                append("\\u")
                append(character.code.toString(16).padStart(4, '0'))
            } else {
                append(character)
            }
        }
    }
    append('"')
}

private fun String.percentEncodeQueryComponent(): String = buildString {
    this@percentEncodeQueryComponent.utf8().forEach { byte ->
        val value = byte.toInt() and 0xff
        val character = value.toChar()
        if (character.isAsciiLetter() || character.isDigit() || character in "-._~:") {
            append(character)
        } else {
            append('%')
            append(value.toString(16).uppercase(Locale.ROOT).padStart(2, '0'))
        }
    }
}

private fun String.isAscii(): Boolean = all { it.code in 0..127 }

private fun Char.isAsciiLetter(): Boolean = this in 'a'..'z' || this in 'A'..'Z'

private fun Char.isAsciiLetterOrDigit(): Boolean = isAsciiLetter() || this in '0'..'9'
