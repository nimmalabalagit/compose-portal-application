package com.estateflow.order.repository;
import com.estateflow.order.entity.Order;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.*;
@Repository
public interface OrderRepository extends JpaRepository<Order, UUID> {
    List<Order> findByStatus(String status);
    List<Order> findByBuyerUserId(UUID buyerUserId);
}
