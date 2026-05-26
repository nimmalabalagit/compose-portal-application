package com.estateflow.product.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "products")
public class Product implements java.io.Serializable {

    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "property_type", nullable = false)
    private String propertyType;

    // WHY BigDecimal (maps to PostgreSQL NUMERIC):
    // Never use double/float for money — binary approximation.
    // BigDecimal is exact decimal arithmetic. NUMERIC(12,2) in PostgreSQL.
    @Column(name = "price_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal priceAmount;

    @Column(name = "price_currency", nullable = false)
    private String priceCurrency = "INR";

    @Column(nullable = false)
    private String location;

    private Integer bedrooms;
    private Integer bathrooms;

    @Column(name = "area_sqft", precision = 10, scale = 2)
    private BigDecimal areaSqft;

    @Column(nullable = false)
    private String status = "AVAILABLE";

    @Column(name = "listed_by_user_id")
    private UUID listedByUserId;

    @Column(name = "stock_count", nullable = false)
    private Integer stockCount = 1;

    @Column(columnDefinition = "jsonb")
    private String tags;

    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "updated_at")
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    @PreUpdate
    public void onUpdate() { this.updatedAt = OffsetDateTime.now(); }

    // All getters and setters
    public UUID getId() { return id; }
    public String getTitle() { return title; }
    public void setTitle(String v) { this.title = v; }
    public String getDescription() { return description; }
    public void setDescription(String v) { this.description = v; }
    public String getPropertyType() { return propertyType; }
    public void setPropertyType(String v) { this.propertyType = v; }
    public BigDecimal getPriceAmount() { return priceAmount; }
    public void setPriceAmount(BigDecimal v) { this.priceAmount = v; }
    public String getPriceCurrency() { return priceCurrency; }
    public void setPriceCurrency(String v) { this.priceCurrency = v; }
    public String getLocation() { return location; }
    public void setLocation(String v) { this.location = v; }
    public Integer getBedrooms() { return bedrooms; }
    public void setBedrooms(Integer v) { this.bedrooms = v; }
    public Integer getBathrooms() { return bathrooms; }
    public void setBathrooms(Integer v) { this.bathrooms = v; }
    public BigDecimal getAreaSqft() { return areaSqft; }
    public void setAreaSqft(BigDecimal v) { this.areaSqft = v; }
    public String getStatus() { return status; }
    public void setStatus(String v) { this.status = v; }
    public UUID getListedByUserId() { return listedByUserId; }
    public void setListedByUserId(UUID v) { this.listedByUserId = v; }
    public Integer getStockCount() { return stockCount; }
    public void setStockCount(Integer v) { this.stockCount = v; }
    public String getTags() { return tags; }
    public void setTags(String v) { this.tags = v; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
}