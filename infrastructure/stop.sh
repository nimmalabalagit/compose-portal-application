#!/bin/bash
set -euo pipefail

echo "=== Graceful shutdown starting ==="
cd "$(dirname "$0")"

# Stop application services first (not databases)
echo "Stopping application services..."
docker-compose stop gateway-service frontend 2>/dev/null || true
sleep 3

docker-compose stop order-service user-service product-service 2>/dev/null || true
sleep 5

# Now stop databases gracefully
echo "Stopping databases gracefully..."
docker-compose stop rabbitmq redis 2>/dev/null || true
sleep 3

# MongoDB needs graceful shutdown - send proper shutdown command
echo "Shutting down MongoDB gracefully..."
docker exec ef-mongodb mongosh --quiet \
  "mongodb://mongo:localdev123@localhost:27017/admin?authSource=admin" \
  --eval "db.adminCommand({shutdown: 1})" 2>/dev/null || true
sleep 5

# PostgreSQL graceful shutdown
echo "Stopping PostgreSQL instances..."
docker-compose stop postgres-users postgres-products postgres-orders 2>/dev/null || true
sleep 3

# Now remove everything
docker-compose down
echo "=== Shutdown complete ==="
