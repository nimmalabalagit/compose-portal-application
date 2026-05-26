package com.estateflow.order.repository;
import com.estateflow.order.document.OrderAuditLog;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.*;
@Repository
public interface OrderAuditLogRepository extends MongoRepository<OrderAuditLog, String> {
    List<OrderAuditLog> findByOrderId(UUID orderId);
}
