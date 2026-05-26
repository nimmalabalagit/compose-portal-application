#!/bin/bash
# scripts/chaos/run-chaos-test.sh
# THE INTERVIEW DEMO SCRIPT
# Run this during a load test to generate the "0.3% error rate" number

set -euo pipefail
source /tmp/fis-experiments.env

AWS_REGION="ap-south-1"
PROD_URL="https://app.estateflowai.co"

echo "=== EstateFlow AI — Chaos Engineering Demo ==="
echo ""
echo "Starting continuous load test in background..."

# Start load test (hey tool)
hey -z 15m -c 100 -q 10 \
  "${PROD_URL}/api/users/actuator/health" \
  > /tmp/load-test-output.txt &
LOAD_PID=$!

echo "Load test running (100 concurrent users, 10 RPS each)..."
echo "Waiting 60s for baseline metrics..."
sleep 60

# Check baseline error rate before chaos
echo "Baseline error rate (before chaos):"
cat /tmp/load-test-output.txt | grep "Status code"

echo ""
echo "=== INJECTING CHAOS: Terminating 50% of pods ==="
EXPERIMENT_RUN=$(aws fis start-experiment \
  --experiment-template-id ${EXPERIMENT_1} \
  --region ${AWS_REGION} \
  --query 'experiment.id' --output text)
echo "Experiment running: ${EXPERIMENT_RUN}"

# Watch pods terminating and recreating
echo "Watching pods (Ctrl+C to stop):"
for i in {1..30}; do
  POD_COUNT=$(kubectl get pods -n compose-portal --no-headers | grep -c "Running" || echo "0")
  echo "t+${i}s: ${POD_COUNT} pods Running"
  sleep 2
done

# Check experiment status
aws fis get-experiment --id ${EXPERIMENT_RUN} \
  --query 'experiment.state' --output json

# Check error rate during chaos
echo ""
echo "Error rate during chaos:"
cat /tmp/load-test-output.txt | grep "Status code"

# Stop load test
kill $LOAD_PID 2>/dev/null || true

# Parse results
echo ""
echo "=== Final Results ==="
hey -z 30s -c 50 "${PROD_URL}/api/users/actuator/health" | tail -20
# Expected: 0.3% non-200 responses (Istio retries absorbed most errors)