#!/bin/bash
set -euo pipefail

echo "=== EstateFlow AI Platform Starting ==="
cd "$(dirname "$0")"

# Step 1 — Start infrastructure first
echo "Starting databases and infrastructure..."
docker-compose up -d \
  postgres-users \
  postgres-products \
  postgres-orders \
  mongodb \
  redis \
  rabbitmq

# Step 2 — Wait for all databases to be healthy
echo "Waiting for databases to be healthy..."
MAX_WAIT=120
WAITED=0
while true; do
  UNHEALTHY=$(docker ps --format "{{.Names}}\t{{.Status}}" | \
    grep -E "ef-postgres|ef-mongodb|ef-redis|ef-rabbitmq" | \
    grep -v "healthy" | wc -l)
  
  if [ "$UNHEALTHY" -eq 0 ]; then
    echo "✅ All databases healthy"
    break
  fi
  
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "❌ Databases not healthy after ${MAX_WAIT}s"
    docker ps --format "{{.Names}}\t{{.Status}}" | grep ef-
    exit 1
  fi
  
  echo "  Waiting... (${WAITED}s) — ${UNHEALTHY} databases not ready"
  sleep 10
  WAITED=$((WAITED + 10))
done

# Step 3 — Start observability
echo "Starting observability..."
docker-compose up -d prometheus grafana pgadmin
sleep 5

# Step 4 — Start application services
echo "Starting application services..."
docker-compose up -d user-service product-service order-service
sleep 15

# Step 5 — Start gateway and frontend last
echo "Starting gateway and frontend..."
docker-compose up -d gateway-service frontend
sleep 30

# Step 6 — Final health check
echo ""
echo "=== Final Status ==="
docker ps --format "{{.Names}}\t{{.Status}}" | grep ef- | \
  while IFS=$'\t' read name status; do
    if echo "$status" | grep -q "healthy"; then
      echo "  ✅ $name"
    elif echo "$status" | grep -q "Up"; then
      echo "  🟡 $name (starting)"
    else
      echo "  ❌ $name — $status"
    fi
  done

echo ""
echo "=== URLs ==="
echo "  Frontend:   http://localhost:3000"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana:    http://localhost:3001"
echo "  pgAdmin:    http://localhost:5050"
echo "  RabbitMQ:   http://localhost:15672"
echo "=== Platform Ready ==="
