package com.estateflow.user.controller;

import com.estateflow.user.entity.User;
import com.estateflow.user.service.UserService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

// WHY consistent envelope:
// Every response has { data, meta }. meta.pod shows which Kubernetes pod
// served the request — critical for debugging multi-replica deployments.
// If user-service has 3 replicas and only pod-2 is failing, you see it here.

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService svc;
    private final String podName = System.getenv().getOrDefault(
            "POD_NAME", "local-" + ProcessHandle.current().pid());

    public UserController(UserService svc) {
        this.svc = svc;
    }

    private Map<String, Object> meta(String correlationId) {
        return Map.of(
                "timestamp",     Instant.now().toString(),
                "service",       "user-service",
                "version",       "1.0",
                "pod",           podName,         // Which K8s pod served this
                "correlationId", correlationId != null ? correlationId : "none"
        );
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> getAll(
            @RequestParam(required = false) String role,
            @RequestHeader(value = "X-Correlation-ID", defaultValue = "none") String correlationId) {

        List<User> users = role != null ? svc.findByRole(role) : svc.findAll();
        return ResponseEntity.ok(Map.of("data", users, "meta", meta(correlationId)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getById(
            @PathVariable UUID id,
            @RequestHeader(value = "X-Correlation-ID", defaultValue = "none") String correlationId) {
        User user = svc.findById(id);
        return ResponseEntity.ok(Map.of("data", user, "meta", meta(correlationId)));
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> create(
            @Valid @RequestBody User user,
            @RequestHeader(value = "X-Correlation-ID", defaultValue = "none") String correlationId) {
        User created = svc.create(user);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("data", created, "meta", meta(correlationId)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Map<String, Object>> update(
            @PathVariable UUID id,
            @RequestBody User patch,
            @RequestHeader(value = "X-Correlation-ID", defaultValue = "none") String correlationId) {
        User updated = svc.update(id, patch);
        return ResponseEntity.ok(Map.of("data", updated, "meta", meta(correlationId)));
    }

    @PatchMapping("/{id}/deactivate")
    public ResponseEntity<Map<String, Object>> deactivate(
            @PathVariable UUID id,
            @RequestHeader(value = "X-Correlation-ID", defaultValue = "none") String correlationId) {
        svc.deactivate(id);
        return ResponseEntity.ok(Map.of(
                "data", Map.of("id", id, "active", false),
                "meta", meta(correlationId)));
    }
}