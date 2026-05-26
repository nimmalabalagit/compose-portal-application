CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email
ON users(email);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_role
ON users(role);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_active
ON users(active);
