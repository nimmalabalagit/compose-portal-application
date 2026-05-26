package com.estateflow.order.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "orders")
public class Order {

    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "order_number", unique = true)
    private String orderNumber;  // Set by DB trigger

    @Column(name = "buyer_user_id", nullable = false)
    private UUID buyerUserId;

    @Column(name = "product_id", nullable = false)
    private UUID productId;

    @Column(nullable = false)
    private String status = "PENDING";

    @Column(name = "amount_total", nullable = false, precision = 12, scale = 2)
    private BigDecimal amountTotal;

    @Column(nullable = false)
    private String currency = "INR";

    private String notes;

    @Column(name = "cancellation_reason")
    private String cancellationReason;

    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "updated_at")
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    @Column(name = "completed_at")
    private OffsetDateTime completedAt;

    @PreUpdate
    public void onUpdate() { this.updatedAt = OffsetDateTime.now(); }

    public UUID getId() { return id; }
    public String getOrderNumber() { return orderNumber; }
    public UUID getBuyerUserId() { return buyerUserId; }
    public void setBuyerUserId(UUID v) { this.buyerUserId = v; }
    public UUID getProductId() { return productId; }
    public void setProductId(UUID v) { this.productId = v; }
    public String getStatus() { return status; }
    public void setStatus(String v) { this.status = v; }
    public BigDecimal getAmountTotal() { return amountTotal; }
    public void setAmountTotal(BigDecimal v) { this.amountTotal = v; }
    public String getCurrency() { return currency; }
    public void setCurrency(String v) { this.currency = v; }
    public String getNotes() { return notes; }
    public void setNotes(String v) { this.notes = v; }
    public String getCancellationReason() { return cancellationReason; }
    public void setCancellationReason(String v) { this.cancellationReason = v; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public OffsetDateTime getCompletedAt() { return completedAt; }
    public void setCompletedAt(OffsetDateTime v) { this.completedAt = v; }
}