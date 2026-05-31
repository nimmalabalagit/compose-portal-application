output "triage_lambda_arn" {
  value       = aws_lambda_function.triage_agent.arn
  description = "AIOps triage Lambda ARN"
}

output "bedrock_agent_role_arn" {
  value       = aws_iam_role.bedrock_agent.arn
  description = "Bedrock Agent IAM role ARN"
}

output "p1_p2_rule_arn" {
  value       = aws_cloudwatch_event_rule.p1_p2_alarms.arn
  description = "EventBridge rule ARN for P1/P2 alarms"
}

output "p3_p4_rule_arn" {
  value       = aws_cloudwatch_event_rule.p3_p4_alarms.arn
  description = "EventBridge rule ARN for P3/P4 alarms"
}
