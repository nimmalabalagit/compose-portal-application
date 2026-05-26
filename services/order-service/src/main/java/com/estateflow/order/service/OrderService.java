package com.estateflow.order.service;
import com.estateflow.order.document.OrderAuditLog;
import com.estateflow.order.entity.Order;
import com.estateflow.order.repository.OrderAuditLogRepository;
import com.estateflow.order.repository.OrderRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.OffsetDateTime;
import java.util.*;

@Service @Transactional
public class OrderService {
    private static final Logger log = LoggerFactory.getLogger(OrderService.class);

    private static final Map<String,Set<String>> VALID_TRANSITIONS = Map.of(
        "PENDING",    Set.of("PROCESSING","CANCELLED"),
        "PROCESSING", Set.of("COMPLETED","CANCELLED"),
        "COMPLETED",  Set.of(),
        "CANCELLED",  Set.of()
    );

    private final OrderRepository orderRepo;
    private final OrderAuditLogRepository auditRepo;
    private final RabbitTemplate rabbitTemplate;

    public OrderService(OrderRepository orderRepo, OrderAuditLogRepository auditRepo,
                        RabbitTemplate rabbitTemplate) {
        this.orderRepo = orderRepo;
        this.auditRepo = auditRepo;
        this.rabbitTemplate = rabbitTemplate;
    }

    public List<Order> findAll() { return orderRepo.findAll(); }
    public List<Order> findByStatus(String status) { return orderRepo.findByStatus(status); }
    public List<Order> findByBuyerUserId(UUID userId) { return orderRepo.findByBuyerUserId(userId); }

    public Order findById(UUID id) {
        return orderRepo.findById(id).orElseThrow(() -> new RuntimeException("Order not found: " + id));
    }

    public Order create(Order order) {
        Order saved = orderRepo.save(order);
        publishAuditLogAsync(saved, "CREATED", null, "PENDING", Map.of("source","order-service"));
        return saved;
    }

    public Order updateStatus(UUID id, String newStatus, String cancellationReason, String changedBy) {
        Order order = findById(id);
        String currentStatus = order.getStatus();
        Set<String> allowed = VALID_TRANSITIONS.getOrDefault(currentStatus, Set.of());
        if (!allowed.contains(newStatus)) {
            throw new IllegalStateException(String.format(
                "Transition %s to %s not allowed. Valid: %s", currentStatus, newStatus, allowed));
        }
        String fromStatus = order.getStatus();
        order.setStatus(newStatus);
        if ("COMPLETED".equals(newStatus)) order.setCompletedAt(OffsetDateTime.now());
        if ("CANCELLED".equals(newStatus) && cancellationReason != null)
            order.setCancellationReason(cancellationReason);
        Order saved = orderRepo.save(order);
        Map<String,Object> metadata = new HashMap<>();
        metadata.put("changedAt", OffsetDateTime.now().toString());
        if (cancellationReason != null) metadata.put("cancellationReason", cancellationReason);
        publishAuditLogAsync(saved, "STATUS_CHANGE", fromStatus, newStatus, metadata);
        publishRabbitMQEventAsync(saved, fromStatus, newStatus);
        log.info("Order {} transitioned: {} to {} by {}", saved.getOrderNumber(), fromStatus, newStatus, changedBy);
        return saved;
    }

    @Async
    public void publishAuditLogAsync(Order order, String eventType, String fromStatus,
                                      String toStatus, Map<String,Object> metadata) {
        try {
            OrderAuditLog entry = new OrderAuditLog();
            entry.setOrderId(order.getId());
            entry.setOrderNumber(order.getOrderNumber());
            entry.setEventType(eventType);
            entry.setFromStatus(fromStatus);
            entry.setToStatus(toStatus);
            entry.setChangedBy("order-service");
            entry.setMetadata(metadata);
            auditRepo.save(entry);
        } catch (Exception e) { log.error("MongoDB audit log failed: {}", e.getMessage()); }
    }

    @Async
    public void publishRabbitMQEventAsync(Order order, String fromStatus, String toStatus) {
        try {
            Map<String,Object> event = Map.of(
                "orderId",     order.getId().toString(),
                "orderNumber", order.getOrderNumber(),
                "fromStatus",  fromStatus != null ? fromStatus : "NEW",
                "toStatus",    toStatus,
                "amountTotal", order.getAmountTotal(),
                "timestamp",   OffsetDateTime.now().toString()
            );
            rabbitTemplate.convertAndSend("orders.events","order.status.changed",event);
        } catch (Exception e) { log.error("RabbitMQ publish failed: {}", e.getMessage()); }
    }
}
