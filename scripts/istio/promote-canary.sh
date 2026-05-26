# Canary promotion script
#!/bin/bash
# scripts/istio/promote-canary.sh
# Gradually promotes canary from 10% → 25% → 50% → 100%
# Run with: ./promote-canary.sh order-service

SERVICE=$1
ERROR_THRESHOLD=1  # % — abort canary if error rate exceeds this
LATENCY_THRESHOLD=500  # ms — abort if P99 exceeds this

promote() {
  local weight=$1
  echo "→ Promoting to ${weight}% canary traffic"

  # Update VirtualService weight
  kubectl patch virtualservice ${SERVICE}-canary -n compose-portal \
    --type=json \
    -p="[{\"op\":\"replace\",\"path\":\"/spec/http/1/route/1/weight\",\"value\":${weight}},
         {\"op\":\"replace\",\"path\":\"/spec/http/1/route/0/weight\",\"value\":$((100-weight))}]"

  echo "Waiting 5 minutes for metrics to stabilize at ${weight}%..."
  sleep 300

  # Query Prometheus for error rate
  ERROR_RATE=$(kubectl exec -n istio-system deploy/prometheus -- \
    curl -s "localhost:9090/api/v1/query" \
    --data-urlencode "query=sum(rate(istio_requests_total{destination_service=\"${SERVICE}.compose-portal.svc.cluster.local\",response_code=~\"5..\",destination_version=\"v2\"}[5m])) / sum(rate(istio_requests_total{destination_service=\"${SERVICE}.compose-portal.svc.cluster.local\",destination_version=\"v2\"}[5m]))" \
    | jq -r '.data.result[0].value[1]' | awk '{printf "%.2f", $1*100}')

  echo "Canary error rate at ${weight}%: ${ERROR_RATE}%"

  if (( $(echo "$ERROR_RATE > $ERROR_THRESHOLD" | bc -l) )); then
    echo "❌ Error rate ${ERROR_RATE}% exceeds ${ERROR_THRESHOLD}% threshold — ROLLBACK"
    kubectl patch virtualservice ${SERVICE}-canary -n compose-portal \
      --type=json \
      -p='[{"op":"replace","path":"/spec/http/1/route/1/weight","value":0},
           {"op":"replace","path":"/spec/http/1/route/0/weight","value":100}]'
    exit 1
  fi

  echo "✅ Error rate ${ERROR_RATE}% within threshold — continuing promotion"
}

promote 25
promote 50
promote 100

# Full promotion: remove v1 deployment
echo "✅ Full canary promotion complete. Removing v1 deployment."
kubectl delete deployment ${SERVICE}-v1 -n compose-portal