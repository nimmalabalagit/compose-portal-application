package com.estateflow.gateway.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.time.Instant;
import java.util.Map;

// WHY fallback:
// When CircuitBreaker opens (50% failures in 10 requests),
// instead of returning 500 errors, we return a structured response.
// The React frontend can show "Service temporarily unavailable"
// instead of a broken page.

@RestController
@RequestMapping("/fallback")
public class FallbackController {

    @GetMapping("/user-service")
    public ResponseEntity<Map<String, Object>> userServiceFallback() {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Map.of(
                "error", Map.of(
                        "code", "SERVICE_UNAVAILABLE",
                        "message", "User service is temporarily unavailable",
                        "service", "user-service",
                        "retryAfter", 30
                ),
                "meta", Map.of(
                        "timestamp", Instant.now().toString(),
                        "circuit", "OPEN"
                )
        ));
    }

    @GetMapping("/product-service")
    public ResponseEntity<Map<String, Object>> productServiceFallback() {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Map.of(
                "error", Map.of("code", "SERVICE_UNAVAILABLE",
                        "message", "Product service is temporarily unavailable",
                        "service", "product-service", "retryAfter", 30),
                "meta", Map.of("timestamp", Instant.now().toString(), "circuit", "OPEN")
        ));
    }

    @GetMapping("/order-service")
    public ResponseEntity<Map<String, Object>> orderServiceFallback() {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Map.of(
                "error", Map.of("code", "SERVICE_UNAVAILABLE",
                        "message", "Order service is temporarily unavailable",
                        "service", "order-service", "retryAfter", 30),
                "meta", Map.of("timestamp", Instant.now().toString(), "circuit", "OPEN")
        ));
    }
}