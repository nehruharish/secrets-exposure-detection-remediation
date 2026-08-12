resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.app.function_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.workload.arn
}

# CloudWatch Logs' basic filter-pattern syntax matches terms literally
# (case-sensitive), so common capitalizations of each term are listed
# explicitly. This still isn't exhaustive of every possible casing -- a
# production setup would route logs through a subscription filter with a
# real case-insensitive regex (e.g. a small Lambda) instead of relying on
# this pattern language.
resource "aws_cloudwatch_log_metric_filter" "secret_like_content" {
  name           = "${local.name_prefix}-secret-like-log-content"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "?password ?Password ?PASSWORD ?passwd ?Passwd ?secret ?Secret ?SECRET ?token ?Token ?TOKEN ?api_key ?API_KEY ?Api_Key ?AKIA"
  metric_transformation {
    name      = "SecretLikeLogContent"
    namespace = "Security/SecretsExposure"
    value     = "1"
  }
}

# Alerting destination for the alarm below. Subscribes var.alert_email if
# set; otherwise the topic exists (so the alarm always has somewhere to
# publish to) but has no subscriber until one is added.
resource "aws_sns_topic" "security_alerts" {
  name              = "${local.name_prefix}-security-alerts"
  kms_master_key_id = aws_kms_key.workload.id
}

resource "aws_sns_topic_subscription" "security_alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "secret_like_content" {
  alarm_name          = "${local.name_prefix}-secret-like-log-content"
  alarm_description   = "Potential credential-like content detected in application logs"
  namespace           = "Security/SecretsExposure"
  metric_name         = "SecretLikeLogContent"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  ok_actions          = [aws_sns_topic.security_alerts.arn]
}
