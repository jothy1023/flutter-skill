package com.aidashboad.flutterskill

import com.intellij.testFramework.fixtures.BasePlatformTestCase
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Integration tests for SessionManager
 * Tests session creation, switching, state transitions, and port assignment
 */
class SessionManagerTest : BasePlatformTestCase() {

    private lateinit var sessionManager: SessionManager

    override fun setUp() {
        super.setUp()
        sessionManager = SessionManager(project)
    }

    override fun tearDown() {
        try {
            sessionManager.closeAllSessions()
        } finally {
            super.tearDown()
        }
    }

    @Test
    fun testCreateSession() {
        val session = sessionManager.createSession(
            name = "Test Session",
            projectPath = "/tmp/test_project",
            deviceId = "test-device"
        )

        assertNotNull(session.id)
        assertEquals("Test Session", session.name)
        assertEquals("/tmp/test_project", session.projectPath)
        assertEquals("test-device", session.deviceId)
        assertEquals(SessionState.CREATED, session.state)
        assertNotNull(session.port)
        assertTrue(session.port >= 50001)
    }

    @Test
    fun testCreateSessionWithCustomPort() {
        val customPort = 55555
        val session = sessionManager.createSession(
            name = "Custom Port Session",
            projectPath = "/tmp/custom",
            deviceId = "custom-device",
            port = customPort
        )

        assertEquals(customPort, session.port)
    }

    @Test
    fun testFirstSessionBecomesActive() {
        val session = sessionManager.createSession(
            name = "First Session",
            projectPath = "/tmp/first",
            deviceId = "first-device"
        )

        val activeSession = sessionManager.getActiveSession()
        assertNotNull(activeSession)
        assertEquals(session.id, activeSession.id)
    }

    @Test
    fun testGetSessionById() {
        val session = sessionManager.createSession(
            name = "Test Session",
            projectPath = "/tmp/test",
            deviceId = "test-device"
        )

        val retrieved = sessionManager.getSession(session.id)
        assertNotNull(retrieved)
        assertEquals(session.id, retrieved.id)
        assertEquals("Test Session", retrieved.name)
    }

    @Test
    fun testGetNonExistentSession() {
        val retrieved = sessionManager.getSession("non-existent-id")
        assertNull(retrieved)
    }

    @Test
    fun testGetAllSessions() {
        // Initially empty
        assertEquals(0, sessionManager.getAllSessions().size)

        // Create multiple sessions
        sessionManager.createSession("Session 1", "/tmp/s1", "device1")
        sessionManager.createSession("Session 2", "/tmp/s2", "device2")
        sessionManager.createSession("Session 3", "/tmp/s3", "device3")

        val allSessions = sessionManager.getAllSessions()
        assertEquals(3, allSessions.size)
    }

    @Test
    fun testSwitchToSession() {
        val session1 = sessionManager.createSession("Session 1", "/tmp/s1", "device1")
        val session2 = sessionManager.createSession("Session 2", "/tmp/s2", "device2")

        // session1 should be active (first created)
        assertEquals(session1.id, sessionManager.getActiveSession()?.id)

        // Switch to session2
        val switched = sessionManager.switchToSession(session2.id)
        assertTrue(switched)
        assertEquals(session2.id, sessionManager.getActiveSession()?.id)

        // Switch back to session1
        sessionManager.switchToSession(session1.id)
        assertEquals(session1.id, sessionManager.getActiveSession()?.id)
    }

    @Test
    fun testSwitchToNonExistentSession() {
        val switched = sessionManager.switchToSession("non-existent-id")
        assertFalse(switched)
    }

    @Test
    fun testCloseSession() {
        val session1 = sessionManager.createSession("Session 1", "/tmp/s1", "device1")
        val session2 = sessionManager.createSession("Session 2", "/tmp/s2", "device2")

        assertEquals(2, sessionManager.getAllSessions().size)

        // Close session2
        sessionManager.closeSession(session2.id)

        assertEquals(1, sessionManager.getAllSessions().size)
        assertNull(sessionManager.getSession(session2.id))
        assertNotNull(sessionManager.getSession(session1.id))
    }

    @Test
    fun testCloseActiveSession() {
        val session1 = sessionManager.createSession("Session 1", "/tmp/s1", "device1")
        val session2 = sessionManager.createSession("Session 2", "/tmp/s2", "device2")

        // Switch to session1 and close it
        sessionManager.switchToSession(session1.id)
        assertEquals(session1.id, sessionManager.getActiveSession()?.id)

        sessionManager.closeSession(session1.id)

        // Active session should switch to session2
        val activeSession = sessionManager.getActiveSession()
        assertNotNull(activeSession)
        assertEquals(session2.id, activeSession.id)
    }

    @Test
    fun testCloseLastSession() {
        val session = sessionManager.createSession("Last Session", "/tmp/last", "last-device")

        assertNotNull(sessionManager.getActiveSession())

        sessionManager.closeSession(session.id)

        assertNull(sessionManager.getActiveSession())
        assertEquals(0, sessionManager.getAllSessions().size)
    }

    @Test
    fun testCloseAllSessions() {
        sessionManager.createSession("Session 1", "/tmp/s1", "device1")
        sessionManager.createSession("Session 2", "/tmp/s2", "device2")
        sessionManager.createSession("Session 3", "/tmp/s3", "device3")

        assertEquals(3, sessionManager.getAllSessions().size)

        sessionManager.closeAllSessions()

        assertEquals(0, sessionManager.getAllSessions().size)
        assertNull(sessionManager.getActiveSession())
    }

    @Test
    fun testRenameSession() {
        val session = sessionManager.createSession(
            name = "Original Name",
            projectPath = "/tmp/test",
            deviceId = "test-device"
        )

        assertEquals("Original Name", session.name)

        sessionManager.renameSession(session.id, "New Name")

        val updated = sessionManager.getSession(session.id)
        assertNotNull(updated)
        assertEquals("New Name", updated.name)
    }

    @Test
    fun testRenameNonExistentSession() {
        // Should not throw exception
        sessionManager.renameSession("non-existent-id", "New Name")
    }

    @Test
    fun testUpdateSessionState() {
        val session = sessionManager.createSession("Test", "/tmp/test", "device")

        assertEquals(SessionState.CREATED, session.state)

        sessionManager.updateSessionState(
            sessionId = session.id,
            state = SessionState.LAUNCHING
        )

        val updated = sessionManager.getSession(session.id)
        assertNotNull(updated)
        assertEquals(SessionState.LAUNCHING, updated.state)

        sessionManager.updateSessionState(
            sessionId = session.id,
            state = SessionState.CONNECTED,
            vmServiceUri = "ws://127.0.0.1:50000/ws"
        )

        val connected = sessionManager.getSession(session.id)
        assertNotNull(connected)
        assertEquals(SessionState.CONNECTED, connected.state)
        assertEquals("ws://127.0.0.1:50000/ws", connected.vmServiceUri)
    }

    @Test
    fun testUpdateSessionStateWithError() {
        val session = sessionManager.createSession("Test", "/tmp/test", "device")

        sessionManager.updateSessionState(
            sessionId = session.id,
            state = SessionState.ERROR,
            error = "Connection failed"
        )

        val updated = sessionManager.getSession(session.id)
        assertNotNull(updated)
        assertEquals(SessionState.ERROR, updated.state)
        assertEquals("Connection failed", updated.errorMessage)
    }

    @Test
    fun testUpdateSessionVmService() {
        val session = sessionManager.createSession("Test", "/tmp/test", "device")

        val vmService = VmServiceInfo(
            uri = "ws://127.0.0.1:50001/ws",
            port = 50001,
            appName = "test_app"
        )

        sessionManager.updateSessionVmService(session.id, vmService)

        val updated = sessionManager.getSession(session.id)
        assertNotNull(updated)
        assertEquals(vmService, updated.vmService)
        assertEquals(vmService.uri, updated.vmServiceUri)
    }

    @Test
    fun testSessionStateTransitions() {
        val session = sessionManager.createSession("Test", "/tmp/test", "device")

        // CREATED -> LAUNCHING
        session.updateState(SessionState.LAUNCHING)
        assertEquals(SessionState.LAUNCHING, session.state)
        assertNull(session.errorMessage)

        // LAUNCHING -> CONNECTED
        session.updateState(SessionState.CONNECTED)
        assertEquals(SessionState.CONNECTED, session.state)

        // CONNECTED -> DISCONNECTED
        session.updateState(SessionState.DISCONNECTED)
        assertEquals(SessionState.DISCONNECTED, session.state)

        // DISCONNECTED -> ERROR
        session.updateState(SessionState.ERROR, "Connection lost")
        assertEquals(SessionState.ERROR, session.state)
        assertEquals("Connection lost", session.errorMessage)
    }

    @Test
    fun testSessionDisplayName() {
        val session = sessionManager.createSession(
            name = "My App",
            projectPath = "/tmp/app",
            deviceId = "iPhone 15 Pro"
        )

        assertEquals("My App (iPhone 15 Pro)", session.getDisplayName())
    }

    @Test
    fun testSessionStatusIcon() {
        val session = sessionManager.createSession("Test", "/tmp/test", "device")

        session.updateState(SessionState.CREATED)
        assertEquals("○", session.getStatusIcon())

        session.updateState(SessionState.LAUNCHING)
        assertEquals("⏳", session.getStatusIcon())

        session.updateState(SessionState.CONNECTED)
        assertEquals("●", session.getStatusIcon())

        session.updateState(SessionState.DISCONNECTED)
        assertEquals("○", session.getStatusIcon())

        session.updateState(SessionState.ERROR)
        assertEquals("⚠️", session.getStatusIcon())
    }

    @Test
    fun testAutoPortAssignment() {
        val session1 = sessionManager.createSession("S1", "/tmp/s1", "d1")
        val session2 = sessionManager.createSession("S2", "/tmp/s2", "d2")
        val session3 = sessionManager.createSession("S3", "/tmp/s3", "d3")

        // All ports should be different
        assertTrue(session1.port >= 50001)
        assertTrue(session2.port >= 50001)
        assertTrue(session3.port >= 50001)

        val ports = setOf(session1.port, session2.port, session3.port)
        assertEquals(3, ports.size) // All unique
    }

    @Test
    fun testPortReuseAfterClose() {
        val session1 = sessionManager.createSession("S1", "/tmp/s1", "d1")
        val port1 = session1.port

        sessionManager.closeSession(session1.id)

        val session2 = sessionManager.createSession("S2", "/tmp/s2", "d2")
        val port2 = session2.port

        // Port can be reused or incremented
        assertTrue(port2 >= 50001)
    }

    @Test
    fun testStateChangeListener() {
        var stateChangedCalled = false
        var changedSession: Session? = null

        sessionManager.addStateChangeListener { session ->
            stateChangedCalled = true
            changedSession = session
        }

        val session = sessionManager.createSession("Test", "/tmp/test", "device")

        sessionManager.updateSessionState(session.id, SessionState.LAUNCHING)

        // Listener should be called
        assertTrue(stateChangedCalled)
        assertNotNull(changedSession)
        assertEquals(session.id, changedSession?.id)
        assertEquals(SessionState.LAUNCHING, changedSession?.state)
    }

    @Test
    fun testSessionListListener() {
        var listChangedCount = 0

        sessionManager.addSessionListListener {
            listChangedCount++
        }

        // Create session - should trigger listener
        sessionManager.createSession("S1", "/tmp/s1", "d1")
        assertEquals(1, listChangedCount)

        // Create another session
        sessionManager.createSession("S2", "/tmp/s2", "d2")
        assertEquals(2, listChangedCount)

        // Close session - should trigger listener
        val allSessions = sessionManager.getAllSessions()
        sessionManager.closeSession(allSessions[0].id)
        assertEquals(3, listChangedCount)

        // Close all - should trigger listener
        sessionManager.closeAllSessions()
        assertEquals(4, listChangedCount)
    }

    @Test
    fun testSessionIsolation() {
        val session1 = sessionManager.createSession("S1", "/tmp/s1", "d1")
        val session2 = sessionManager.createSession("S2", "/tmp/s2", "d2")

        // Update session1 state
        sessionManager.updateSessionState(
            session1.id,
            SessionState.CONNECTED,
            vmServiceUri = "ws://127.0.0.1:50001/ws"
        )

        // session2 should not be affected
        val s2 = sessionManager.getSession(session2.id)
        assertNotNull(s2)
        assertEquals(SessionState.CREATED, s2.state)
        assertNull(s2.vmServiceUri)

        // session1 should have updated state
        val s1 = sessionManager.getSession(session1.id)
        assertNotNull(s1)
        assertEquals(SessionState.CONNECTED, s1.state)
        assertEquals("ws://127.0.0.1:50001/ws", s1.vmServiceUri)
    }

    @Test
    fun testConcurrentSessionOperations() {
        val sessions = mutableListOf<Session>()

        // Create multiple sessions rapidly
        repeat(10) { i ->
            sessions.add(
                sessionManager.createSession(
                    name = "Session $i",
                    projectPath = "/tmp/s$i",
                    deviceId = "device$i"
                )
            )
        }

        // All sessions should exist
        assertEquals(10, sessionManager.getAllSessions().size)

        // All ports should be unique
        val ports = sessions.map { it.port }.toSet()
        assertEquals(10, ports.size)

        // All IDs should be unique
        val ids = sessions.map { it.id }.toSet()
        assertEquals(10, ids.size)
    }

    @Test
    fun testSessionTimestamp() {
        val beforeCreate = java.time.Instant.now()
        Thread.sleep(10) // Small delay to ensure timestamp difference

        val session = sessionManager.createSession("Test", "/tmp/test", "device")

        val afterCreate = java.time.Instant.now()

        assertTrue(session.lastUpdate.isAfter(beforeCreate))
        assertTrue(session.lastUpdate.isBefore(afterCreate))
    }

    @Test
    fun testSessionUpdateTimestamp() {
        val session = sessionManager.createSession("Test", "/tmp/test", "device")
        val initialTimestamp = session.lastUpdate

        Thread.sleep(10) // Small delay

        sessionManager.updateSessionState(session.id, SessionState.LAUNCHING)

        val updated = sessionManager.getSession(session.id)
        assertNotNull(updated)
        assertTrue(updated.lastUpdate.isAfter(initialTimestamp))
    }

    @Test
    fun testMaxPortLimit() {
        // Create many sessions to test port allocation limit
        val sessions = mutableListOf<Session>()

        repeat(100) { i ->
            sessions.add(
                sessionManager.createSession(
                    name = "Session $i",
                    projectPath = "/tmp/s$i",
                    deviceId = "device$i"
                )
            )
        }

        // All ports should be within valid range (50001-60000)
        sessions.forEach { session ->
            assertTrue(session.port >= 50001)
            assertTrue(session.port < 60000)
        }

        // Clean up
        sessionManager.closeAllSessions()
    }
}
