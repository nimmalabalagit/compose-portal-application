package com.estateflow.product.repository;
import com.estateflow.product.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.*;
@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {
    List<Product> findByStatus(String status);
    List<Product> findByPropertyType(String propertyType);
}
