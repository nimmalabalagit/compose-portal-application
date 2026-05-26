package com.estateflow.order.document;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

// WHY MongoDB for audit log (not PostgreSQL):
// Each status change has different metadata:
// PENDING→PROCESSING: {assignedAgent, processingStarted}
// PROCESSING→COMPLETED: {completedAt, signedBy}
// PROCESSING→CANCELLED: {cancellationReason, refundInitiated}
// PostgreSQL requires fixed columns — you'd have 10+ nullable fields.
// MongoDB stores exactly what each event needs — perfect schema match.

@Document(collection = "order_audit_logs")
public class OrderAuditLog {

    @Id
    private String id;

    private UUID orderId;

    private String orderNumber;

    private String eventType;

    private String fromStatus;

    private String toStatus;

    private String changedBy;

    private Instant changedAt = Instant.now();

    // WHY Map<String, Object> instead of fixed fields:
    // Each event type has different metadata.
    // MongoDB stores as nested BSON document.

    private Map<String, Object> metadata;

    public String getId() {
        return id;
    }

    public void setId(String v) {
        this.id = v;
    }

    public UUID getOrderId() {
        return orderId;
    }

    public void setOrderId(UUID v) {
        this.orderId = v;
    }

    public String getOrderNumber() {
        return orderNumber;
    }

    public void setOrderNumber(String v) {
        this.orderNumber = v;
    }

    public String getEventType() {
        return eventType;
    }

    public void setEventType(String v) {
        this.eventType = v;
    }

    public String getFromStatus() {
        return fromStatus;
    }

    public void setFromStatus(String v) {
        this.fromStatus = v;
    }

    public String getToStatus() {
        return toStatus;
    }

    public void setToStatus(String v) {
        this.toStatus = v;
    }

    public String getChangedBy() {
        return changedBy;
    }

    public void setChangedBy(String v) {
        this.changedBy = v;
    }

    public Instant getChangedAt() {
        return changedAt;
    }

    public void setChangedAt(Instant v) {
        this.changedAt = v;
    }

    public Map<String, Object> getMetadata() {
        return metadata;
    }

    public void setMetadata(Map<String, Object> v) {
        this.metadata = v;
    }
}
