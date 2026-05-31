output "kubecost_namespace" {
  value       = "kubecost"
  description = "Namespace where Kubecost is installed"
}

output "budget_name" {
  value       = aws_budgets_budget.monthly_total.name
  description = "AWS Budget name"
}

output "anomaly_monitor_arn" {
  value       = aws_ce_anomaly_monitor.services.arn
  description = "Cost anomaly monitor ARN"
}

output "sp_lambda_arn" {
  value       = aws_lambda_function.sp_recommendation.arn
  description = "Savings Plans recommendation Lambda ARN"
}
