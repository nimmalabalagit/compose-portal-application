# modules/iam-roles/outputs.tf
output "service_role_arns" {
  value = {
    gateway        = aws_iam_role.gateway.arn
    user_service   = aws_iam_role.user_service.arn
    product_service = aws_iam_role.product_service.arn
    order_service  = aws_iam_role.order_service.arn
  }
}
output "lbc_role_arn"              { value = aws_iam_role.aws_lbc.arn }
output "external_secrets_role_arn" { value = aws_iam_role.external_secrets.arn }