# modules/eks-cluster/karpenter.tf
#
# INTERVIEW TALKING POINT - Karpenter architecture:
#   Traditional CA: scales node groups → slow (~3–5min), group-constrained
#   Karpenter:      creates EC2 directly → fast (47s), instance-type diversified
#
# Karpenter needs:
#   1. An IAM role for the controller (IRSA)
#   2. An IAM role for provisioned nodes (instance profile)
#   3. An EC2NodeClass pointing to subnets/SGs via tags
#   4. A NodePool defining instance diversity and constraints
#
# The NodePool and EC2NodeClass are Kubernetes CRDs - deployed via eks-addons module.
# Here we create only the AWS IAM resources.

# ── Karpenter Controller IRSA ─────────────────────────────────────────────────
resource "aws_iam_role" "karpenter_controller" {
  name = "${local.cluster_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${local.cluster_name}-karpenter-controller-policy"
  description = "Karpenter controller permissions to create/terminate EC2 instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Core EC2 instance lifecycle permissions
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSpotPriceHistory",
        ]
        Resource = "*"
      },
      {
        # Pass the node instance profile to EC2
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.karpenter_node.arn
      },
      {
        # SQS for Spot interruption notifications
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        # Allow Karpenter to call EKS to update cluster config
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = aws_eks_cluster.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# ── Karpenter Node Role (for EC2 instances Karpenter creates) ─────────────────
resource "aws_iam_role" "karpenter_node" {
  name = "${local.cluster_name}-karpenter-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${local.cluster_name}-karpenter-node"
  role = aws_iam_role.karpenter_node.name
}

# ── Spot Interruption Queue ───────────────────────────────────────────────────
# INTERVIEW TALKING POINT: Karpenter subscribes to EC2 Spot interruption notices
# via EventBridge → SQS. When a 2-minute warning arrives, Karpenter:
#   1. Cordons the node (prevents new pod scheduling)
#   2. Drains the node (evicts pods gracefully via PDB rules)
#   3. Provisions replacement capacity BEFORE the interruption
# This is how we achieve <0.1% error rate during Spot interruptions.

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${local.cluster_name}-karpenter-interruption"
  message_retention_seconds = 300  # 5 minutes - interruption events are time-sensitive

  tags = { Name = "${local.cluster_name}-karpenter-interruption" }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# EventBridge rules → SQS for Spot interruption signals
resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${local.cluster_name}-spot-interruption"
  description = "Spot Instance Interruption Warning → Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}