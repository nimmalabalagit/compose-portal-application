# modules/eks-cluster/outputs.tf
output "cluster_name"              { value = aws_eks_cluster.main.name }
output "cluster_endpoint"          { value = aws_eks_cluster.main.endpoint }
output "cluster_ca_certificate"    { value = aws_eks_cluster.main.certificate_authority[0].data }
output "oidc_provider_arn"         { value = aws_iam_openid_connect_provider.eks.arn }
output "oidc_provider_url"         { value = aws_iam_openid_connect_provider.eks.url }
output "node_security_group_id" { value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id }
output "karpenter_node_role_arn"   { value = aws_iam_role.karpenter_node.arn }
output "karpenter_controller_role_arn" { value = aws_iam_role.karpenter_controller.arn }
output "interruption_queue_url"    { value = aws_sqs_queue.karpenter_interruption.id }
output "interruption_queue_arn"    { value = aws_sqs_queue.karpenter_interruption.arn }