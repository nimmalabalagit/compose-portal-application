package com.estateflow.product;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
@SpringBootApplication @EnableCaching
public class ProductApplication {
    public static void main(String[] args) { SpringApplication.run(ProductApplication.class, args); }
}
// K8s routing fix Sat May 30 09:03:18 UTC 2026
