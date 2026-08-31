package diy.atelier.collaboration

import org.junit.Assert.assertEquals
import org.junit.Test

class CollaborationProtocolTest {
    @Test
    fun foundationProtocolVersionIsExplicit() {
        assertEquals(0u.toUShort(), CollaborationProtocolVersion.Foundation.major)
        assertEquals(1u.toUShort(), CollaborationProtocolVersion.Foundation.minor)
    }
}
