resource "aws_secretsmanager_secret" "demo" {
  name                    = "${local.name_prefix}/runtime-api-key"
  description             = "Synthetic runtime secret for the portfolio demonstration"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.workload.id
}

resource "aws_secretsmanager_secret_version" "demo" {
  secret_id     = aws_secretsmanager_secret.demo.id
  secret_string = var.demo_secret_value
}
