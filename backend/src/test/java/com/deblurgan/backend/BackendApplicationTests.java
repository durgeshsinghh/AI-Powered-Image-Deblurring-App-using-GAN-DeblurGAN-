package com.deblurgan.backend;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * Smoke test: verifies the full Spring application context wires up
 * correctly (controllers, services, the ML WebClient bean, CORS config,
 * exception handler, etc.).
 */
@SpringBootTest
class BackendApplicationTests {

    @Test
    void contextLoads() {
        // If the application context fails to start, this test fails.
    }

}
