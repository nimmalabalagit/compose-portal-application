#!/bin/bash
# scripts/chaos/create-fis-experiments.sh
# THREE experiments that prove your resilience in interviews:
# Experiment 1: Pod termination (proves HPA + self-healing)
# Experiment 2: Node termination (proves Karpenter provisioning)
# Experiment 3: Network latency injection (proves Resilience4j circuit breaker)

set -euo pipefail

AWS_REGION="ap-south-1"
FIS_ROLE_ARN=$(aws iam get-role --role-name FISExperimentRole --query 'Role.Arn' --output text)
STOP_CONDITION_ARN=$(aws cloudwatch describe-alarms \
  --alarm-names "compose-portal-fis-stop-condition" \
  --query 'MetricAlarms[0].AlarmArn' --output text)

# ──────────────────────────────────────────────────────────────────────────────
# EXPERIMENT 1: EKS Pod Termination (50% of pods)
# Expected outcome: error rate < 1% during termination, HPA replaces pods
# Interview number: "0.3% error rate under 50% pod termination"
# ──────────────────────────────────────────────────────────────────────────────
EXPERIMENT_1=$(aws fis create-experiment-template \
  --description "Terminate 50% of compose-portal pods" \
  --role-arn ${FIS_ROLE_ARN} \
  --stop-conditions "[{\"source\":\"aws:cloudwatch:alarm\",\"value\":\"${STOP_CONDITION_ARN}\"}]" \
  --targets '{
    "podTarget": {
      "resourceType": "aws:eks:pod",
      "resourceTags": {
        "app": "user-service"
      },
      "filters": [{
        "path": "namespace",
        "values": ["compose-portal"]
      }],
      "selectionMode": "PERCENT(50)"
    }
  }' \
  --actions '{
    "terminatePods": {
      "actionId": "aws:eks:terminate-pod",
      "parameters": {
        "gracePeriodSeconds": "0"
      },
      "targets": {
        "Pods": "podTarget"
      }
    }
  }' \
  --tags '{"Environment":"production","ExperimentType":"pod-termination"}' \
  --query 'experimentTemplate.id' --output text)

echo "Created Experiment 1 (pod termination): ${EXPERIMENT_1}"

# ──────────────────────────────────────────────────────────────────────────────
# EXPERIMENT 2: Node Termination (1 node)
# Expected outcome: Karpenter provisions replacement in 47s, pods reschedule
# ──────────────────────────────────────────────────────────────────────────────
EXPERIMENT_2=$(aws fis create-experiment-template \
  --description "Terminate 1 Karpenter-managed node" \
  --role-arn ${FIS_ROLE_ARN} \
  --stop-conditions "[{\"source\":\"aws:cloudwatch:alarm\",\"value\":\"${STOP_CONDITION_ARN}\"}]" \
  --targets '{
    "nodeTarget": {
      "resourceType": "aws:ec2:instance",
      "resourceTags": {
        "karpenter.sh/nodepool": "general",
        "eks:cluster-name": "compose-portal-eks"
      },
      "selectionMode": "COUNT(1)"
    }
  }' \
  --actions '{
    "terminateNode": {
      "actionId": "aws:ec2:terminate-instances",
      "parameters": {},
      "targets": {
        "Instances": "nodeTarget"
      }
    }
  }' \
  --tags '{"Environment":"production","ExperimentType":"node-termination"}' \
  --query 'experimentTemplate.id' --output text)

echo "Created Experiment 2 (node termination): ${EXPERIMENT_2}"

# ──────────────────────────────────────────────────────────────────────────────
# EXPERIMENT 3: Network Latency Injection (500ms on order-service)
# Expected outcome: gateway-service Resilience4j circuit opens after 3 slow calls
# ──────────────────────────────────────────────────────────────────────────────
EXPERIMENT_3=$(aws fis create-experiment-template \
  --description "Inject 500ms latency on order-service pods" \
  --role-arn ${FIS_ROLE_ARN} \
  --stop-conditions "[{\"source\":\"aws:cloudwatch:alarm\",\"value\":\"${STOP_CONDITION_ARN}\"}]" \
  --targets '{
    "orderPods": {
      "resourceType": "aws:eks:pod",
      "resourceTags": {
        "app": "order-service"
      },
      "filters": [{
        "path": "namespace",
        "values": ["compose-portal"]
      }],
      "selectionMode": "ALL"
    }
  }' \
  --actions '{
    "injectLatency": {
      "actionId": "aws:eks:inject-kubernetes-custom-resource",
      "parameters": {
        "maxDuration": "PT10M",
        "kubernetesApiVersion": "chaos-mesh.org/v1alpha1",
        "kubernetesKind": "NetworkChaos",
        "kubernetesNamespace": "compose-portal",
        "kubernetesSpec": "{\"action\":\"delay\",\"mode\":\"all\",\"selector\":{\"labelSelectors\":{\"app\":\"order-service\"}},\"delay\":{\"latency\":\"500ms\",\"correlation\":\"100\",\"jitter\":\"0ms\"}}"
      },
      "targets": {
        "Pods": "orderPods"
      }
    }
  }' \
  --tags '{"Environment":"staging","ExperimentType":"network-latency"}' \
  --query 'experimentTemplate.id' --output text)

echo "Created Experiment 3 (network latency): ${EXPERIMENT_3}"

# Save experiment IDs for later use
cat > /tmp/fis-experiments.env << EOF
EXPERIMENT_1=${EXPERIMENT_1}
EXPERIMENT_2=${EXPERIMENT_2}
EXPERIMENT_3=${EXPERIMENT_3}
EOF

echo ""
echo "All experiments created. Run them with:"
echo "  aws fis start-experiment --experiment-template-id \${EXPERIMENT_1} --region ${AWS_REGION}"