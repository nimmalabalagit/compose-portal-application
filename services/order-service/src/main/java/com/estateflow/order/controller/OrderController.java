package com.estateflow.order.controller;
import com.estateflow.order.entity.Order;
import com.estateflow.order.service.OrderService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.*;
@RestController @RequestMapping("/api/orders")
public class OrderController {
    private final OrderService svc;
    private final String podName = System.getenv().getOrDefault("POD_NAME","local-"+ProcessHandle.current().pid());
    public OrderController(OrderService svc) { this.svc = svc; }
    private Map<String,Object> meta(String cid) {
        return Map.of("timestamp",Instant.now().toString(),"service","order-service",
            "version","1.0","pod",podName,"correlationId",cid!=null?cid:"none");
    }
    @GetMapping
    public ResponseEntity<Map<String,Object>> getAll(
            @RequestParam(required=false) String status,
            @RequestHeader(value="X-Correlation-ID",defaultValue="none") String cid) {
        List<Order> orders = status != null ? svc.findByStatus(status) : svc.findAll();
        return ResponseEntity.ok(Map.of("data",orders,"meta",meta(cid)));
    }
    @GetMapping("/{id}")
    public ResponseEntity<Map<String,Object>> getById(@PathVariable UUID id,
            @RequestHeader(value="X-Correlation-ID",defaultValue="none") String cid) {
        return ResponseEntity.ok(Map.of("data",svc.findById(id),"meta",meta(cid)));
    }
    @GetMapping("/by-user/{userId}")
    public ResponseEntity<Map<String,Object>> getByUser(@PathVariable UUID userId,
            @RequestHeader(value="X-Correlation-ID",defaultValue="none") String cid) {
        return ResponseEntity.ok(Map.of("data",svc.findByBuyerUserId(userId),"meta",meta(cid)));
    }
    @PostMapping
    public ResponseEntity<Map<String,Object>> create(@RequestBody Order order,
            @RequestHeader(value="X-Correlation-ID",defaultValue="none") String cid) {
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("data",svc.create(order),"meta",meta(cid)));
    }
    @PatchMapping("/{id}/status")
    public ResponseEntity<Map<String,Object>> updateStatus(@PathVariable UUID id,
            @RequestBody Map<String,String> body,
            @RequestHeader(value="X-Correlation-ID",defaultValue="none") String cid) {
        Order updated = svc.updateStatus(id, body.get("status"),
            body.get("cancellationReason"), body.getOrDefault("changedBy","system"));
        return ResponseEntity.ok(Map.of("data",updated,"meta",meta(cid)));
    }
}
