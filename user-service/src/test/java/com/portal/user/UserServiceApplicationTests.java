package com.portal.user;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

@SpringBootTest
@TestPropertySource(properties = {
    "spring.config.import=",
    "aws.parameter-store.enabled=false"
})
class UserServiceApplicationTests {

    @Test
    void contextLoads() {
        // Basic context loading test
    }

    @Test
    void applicationStartsSuccessfully() {
        // Test that application can start without errors
        assert true;
    }
}
