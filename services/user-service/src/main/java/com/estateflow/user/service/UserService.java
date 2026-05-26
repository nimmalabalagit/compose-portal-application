package com.estateflow.user.service;

import com.estateflow.user.entity.User;
import com.estateflow.user.repository.UserRepository;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;


import org.springframework.stereotype.Service;

import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@Transactional
public class UserService {

    private static final Logger log =
            LoggerFactory.getLogger(UserService.class);

    private final UserRepository repo;

    public UserService(UserRepository repo) {
        this.repo = repo;
    }

    // =====================================================
    // FIND ALL USERS
    // =====================================================

    @Cacheable(value = "users", key = "'all'")
    @Transactional(readOnly = true)
    public List<User> findAll() {

        log.info("Cache MISS — fetching all users from PostgreSQL");

        return repo.findAll();
    }

    // =====================================================
    // FIND USER BY ID
    // =====================================================

    @Cacheable(value = "users", key = "#id")
    @Transactional(readOnly = true)
    public User findById(UUID id) {

        return repo.findById(id)
                .orElseThrow(() ->
                        new RuntimeException(
                                "User not found: " + id
                        )
                );
    }

    // =====================================================
    // FIND USERS BY ROLE
    // =====================================================

    @Cacheable(value = "users-by-role", key = "#role")
    @Transactional(readOnly = true)
    public List<User> findByRole(String role) {

        return repo.findByRole(role);
    }

    // =====================================================
    // CREATE USER
    // =====================================================

    @CacheEvict(
            value = {"users", "users-by-role"},
            allEntries = true
    )
    public User create(User user) {

        if (repo.findByEmail(user.getEmail()).isPresent()) {

            throw new RuntimeException(
                    "Email already exists: " + user.getEmail()
            );
        }

        log.info(
                "Creating user: {} — cache evicted",
                user.getEmail()
        );

        return repo.save(user);
    }

    // =====================================================
    // UPDATE USER
    // =====================================================

    @CacheEvict(
            value = {"users", "users-by-role"},
            allEntries = true
    )
    public User update(UUID id, User patch) {

        User existing = findById(id);

        if (patch.getFirstName() != null) {
            existing.setFirstName(patch.getFirstName());
        }

        if (patch.getLastName() != null) {
            existing.setLastName(patch.getLastName());
        }

        if (patch.getRole() != null) {
            existing.setRole(patch.getRole());
        }

        if (patch.getPhoneNumber() != null) {
            existing.setPhoneNumber(patch.getPhoneNumber());
        }

        log.info(
                "Updating user: {} — cache evicted",
                id
        );

        return repo.save(existing);
    }

    // =====================================================
    // DEACTIVATE USER
    // =====================================================

    @CacheEvict(
            value = {"users", "users-by-role"},
            allEntries = true
    )
    public void deactivate(UUID id) {

        User user = findById(id);

        user.setActive(false);

        repo.save(user);

        log.info(
                "Deactivated user: {} — cache evicted",
                id
        );
    }
}
