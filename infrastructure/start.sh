#!/bin/bash
cd "$(dirname "$0")"

echo "=== EstateFlow AI Platform Starting ==="

# Step 1 — Start databases
echo "Step 1: Starting databases..."
docker-compose up -d \
  postgres-users postgres-products postgres-orders \
  mongodb redis rabbitmq

# Step 2 — Wait for databases
echo "Step 2: Waiting for databases (max 120s)..."
WAITED=0
while [ $WAITED -lt 120 ]; do
  UNHEALTHY=$(docker ps --format "{{.Names}}\t{{.Status}}" | \
    grep -E "ef-postgres|ef-mongodb|ef-redis|ef-rabbitmq" | \
    grep -v "healthy" | wc -l)
  if [ "$UNHEALTHY" -eq 0 ]; then
    echo "  ✅ All databases healthy after ${WAITED}s"
    break
  fi
  echo "  Waiting ${WAITED}s — ${UNHEALTHY} not ready..."
  sleep 10
  WAITED=$((WAITED + 10))
done

# Step 3 — Start observability
echo "Step 3: Starting observability..."
docker-compose up -d prometheus grafana pgadmin
sleep 5

# Step 4 — Start application services
echo "Step 4: Starting application services..."
docker-compose up -d user-service product-service order-service
echo "  Waiting 30s for services to initialize..."
sleep 30

# Step 5 — Start gateway and frontend
echo "Step 5: Starting gateway and frontend..."
docker-compose up -d gateway-service frontend
echo "  Waiting 30s for gateway to initialize..."
sleep 30

# Step 6 — Final status
echo ""
echo "=== FINAL STATUS ==="
docker ps --format "{{.Names}}\t{{.Status}}" | grep ef- | \
  while IFS=$'\t' read name status; do
    if echo "$status" | grep -q "healthy"; then
      echo "  ✅ $name"
    elif echo "$status" | grep -q "Up"; then
      echo "  🟡 $name"
    else
      echo "  ❌ $name — $status"
    fi
  done

echo ""
echo "=== API CHECK ==="
sleep 5
USERS=$(curl -s http://localhost:8080/api/users | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  print(len(d.get('data',d)))" 2>/dev/null)
echo "  Users API: $USERS records $([ -n "$USERS" ] && echo ✅ || echo ❌)"

echo ""
echo "=== URLS ==="
echo "  http://localhost:3000   → Frontend"
echo "  http://localhost:9090   → Prometheus"
echo "  http://localhost:3001   → Grafana (admin/admin123)"
echo "  http://localhost:5050   → pgAdmin (admin@estateflowai.co/admin123)"
echo "  http://localhost:15672  → RabbitMQ (rabbitmq/localdev123)"
# Create RabbitMQ exchange
echo "Creating RabbitMQ orders.events exchange..."
sleep 5
curl -s -X PUT \
  -u rabbitmq:localdev123 \
  -H "Content-Type: application/json" \
  http://localhost:15672/api/exchanges/%2F/orders.events \
  -d '{"type":"topic","durable":true,"auto_delete":false}' > /dev/null && \
  echo "  ✅ orders.events exchange created"

echo "=== Platform Ready ==="
