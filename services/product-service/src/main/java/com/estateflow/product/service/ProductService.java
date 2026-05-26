package com.estateflow.product.service;
import com.estateflow.product.entity.Product;
import com.estateflow.product.repository.ProductRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;
@Service @Transactional
public class ProductService {
    private static final Logger log = LoggerFactory.getLogger(ProductService.class);
    private final ProductRepository repo;
    public ProductService(ProductRepository repo) { this.repo = repo; }

    @Cacheable(value="products", key="'all'")
    @Transactional(readOnly=true)
    public List<Product> findAll() {
        log.info("Cache MISS — fetching products from PostgreSQL");
        return repo.findAll();
    }

    @Cacheable(value="products", key="#id")
    @Transactional(readOnly=true)
    public Product findById(UUID id) {
        return repo.findById(id).orElseThrow(() -> new RuntimeException("Product not found: " + id));
    }

    @Cacheable(value="products-by-status", key="#status")
    @Transactional(readOnly=true)
    public List<Product> findByStatus(String status) { return repo.findByStatus(status); }

    @CacheEvict(value={"products","products-by-status"}, allEntries=true)
    public Product create(Product p) { return repo.save(p); }

    @CacheEvict(value={"products","products-by-status"}, allEntries=true)
    public Product update(UUID id, Product patch) {
        Product existing = findById(id);
        if (patch.getTitle() != null) existing.setTitle(patch.getTitle());
        if (patch.getStatus() != null) existing.setStatus(patch.getStatus());
        if (patch.getPriceAmount() != null) existing.setPriceAmount(patch.getPriceAmount());
        return repo.save(existing);
    }

    @CacheEvict(value={"products","products-by-status"}, allEntries=true)
    public void delete(UUID id) { repo.deleteById(id); }
}
