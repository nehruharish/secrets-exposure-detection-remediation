output "lambda_function_name" {
  value = aws_lambda_function.app.function_name
}

output "secret_arn" {
  value     = aws_secretsmanager_secret.demo.arn
  sensitive = true
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "rotation_lambda_function_name" {
  value = aws_lambda_function.rotation.function_name
}

output "security_alerts_topic_arn" {
  value = aws_sns_topic.security_alerts.arn
}
