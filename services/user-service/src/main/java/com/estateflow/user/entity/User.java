package com.estateflow.user.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "users")
public class User implements java.io.Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @NotBlank @Size(min = 2, max = 50)
    @Column(name = "first_name", nullable = false)
    private String firstName;

    @NotBlank @Size(min = 2, max = 50)
    @Column(name = "last_name", nullable = false)
    private String lastName;

    @NotBlank @Email
    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @NotBlank @Pattern(regexp = "BUYER|SELLER|ADMIN")
    @Column(nullable = false)
    private String role;

    @Column(name = "phone_number")
    private String phoneNumber;

    @Column(nullable = false)
    private Boolean active = true;

    @Column(name = "cost_center")
    private String costCenter = "engineering";

    @Column(name = "environment")
    private String environment = "production";

    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "updated_at")
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    @PreUpdate
    public void onUpdate() { this.updatedAt = OffsetDateTime.now(); }

    // Getters and setters
    public UUID getId() { return id; }
    public String getFirstName() { return firstName; }
    public void setFirstName(String v) { this.firstName = v; }
    public String getLastName() { return lastName; }
    public void setLastName(String v) { this.lastName = v; }
    public String getEmail() { return email; }
    public void setEmail(String v) { this.email = v; }
    public String getPasswordHash() { return passwordHash; }
    public void setPasswordHash(String v) { this.passwordHash = v; }
    public String getRole() { return role; }
    public void setRole(String v) { this.role = v; }
    public String getPhoneNumber() { return phoneNumber; }
    public void setPhoneNumber(String v) { this.phoneNumber = v; }
    public Boolean getActive() { return active; }
    public void setActive(Boolean v) { this.active = v; }
    public String getCostCenter() { return costCenter; }
    public void setCostCenter(String v) { this.costCenter = v; }
    public String getEnvironment() { return environment; }
    public void setEnvironment(String v) { this.environment = v; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
}