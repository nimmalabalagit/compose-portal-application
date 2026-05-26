package com.estateflow.product.controller;
import com.estateflow.product.entity.Product;
import com.estateflow.product.service.ProductService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.*;
@RestController @RequestMapping("/api/products")
public class ProductController {
    private final ProductService svc;
    private final String podName = System.getenv().getOrDefault("POD_NAME","local-"+ProcessHandle.current().pid());
    public ProductController(ProductService svc) { this.svc = svc; }
    private Map<String,Object> meta(String cid) {
        return Map.of("timestamp",Instant.now().toString(),"service","product-service",
            "version","1.0","pod",podName,"correlationId",cid!=null?cid:"none");
    }
    @GetMapping
    public ResponseEntity<Map<String,Object>> getAll(
            @RequestParam(required=false) String status,
            @RequestHeader(value="X-Correlation-ID",defaultValue="none") String cid) {
        List<Product> products = status != null ? svc.findByStatus(status) : svc.findAll();
        return ResponseEntity.ok(Map.of("data",products,"meta",meta(cid)));
    }
    @GetMapping("/{id}")
    public ResponseEntity<Map<String,Object>> getById(@PathVariable UUID id,
            @RequestHeader(value="X-Correlation-ID",defaultValue="none") String cid) {
        return ResponseEntity.ok(Map.of("data",svc.findById(id),"meta",meta(cid)));
    }
    @PostMapping
    public ResponseEntity<Map<String,Object>> create(@RequestBody Product p,
            @RequestHeader(value="X-Correlation-ID",defaultValue="none") String cid) {
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("data",svc.create(p),"meta",meta(cid)));
    }
    @PutMapping("/{id}")
    public ResponseEntity<Map<String,Object>> update(@PathVariable UUID id,
            @RequestBody Product patch,
            @RequestHeader(value="X-Correlation-ID",defaultValue="none") String cid) {
        return ResponseEntity.ok(Map.of("data",svc.update(id,patch),"meta",meta(cid)));
    }
    @PatchMapping("/{id}/status")
    public ResponseEntity<Map<String,Object>> updateStatus(@PathVariable UUID id,
            @RequestBody Map<String,String> body,
            @RequestHeader(value="X-Correlation-ID",defaultValue="none") String cid) {
        Product p = svc.findById(id); p.setStatus(body.get("status"));
        return ResponseEntity.ok(Map.of("data",svc.update(id,p),"meta",meta(cid)));
    }
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        svc.delete(id); return ResponseEntity.noContent().build();
    }
}
