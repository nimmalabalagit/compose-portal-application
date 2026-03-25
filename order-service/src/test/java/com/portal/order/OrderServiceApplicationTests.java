package com.portal.order;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class OrderServiceApplicationTests {

    @Test
    void contextLoads() {
        // Basic context loading test - if this passes, Spring context loaded successfully
    }

    @Test
    void applicationStartsSuccessfully() {
        // Test that application can start without errors
        // No assertions needed - if context loads, test passes
    }
}
