package com.estateflow.user.repository;

import com.estateflow.user.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

// WHY JpaRepository:
// Spring Data generates ALL SQL from method names.
// findByRole("BUYER") → SELECT * FROM users WHERE role = 'BUYER'
// No SQL files needed for standard queries.
// Custom queries use @Query when you need JOINs or aggregations.

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {
    List<User> findByRole(String role);
    List<User> findByActive(Boolean active);
    Optional<User> findByEmail(String email);
    List<User> findByRoleAndActive(String role, Boolean active);

    @Query("SELECT COUNT(u) FROM User u WHERE u.active = true")
    Long countActive();

    @Query("SELECT u.role, COUNT(u) FROM User u GROUP BY u.role")
    List<Object[]> countByRole();
}
