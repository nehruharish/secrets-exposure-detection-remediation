data "archive_file" "rotation_lambda" {
  type        = "zip"
  source_file = "${path.module}/rotation_lambda/rotate.py"
  output_path = "${path.module}/rotation_lambda.zip"
}

resource "aws_iam_role" "rotation" {
  name = "${local.name_prefix}-rotation"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "rotation_secrets" {
  name = "${local.name_prefix}-rotation-secrets"
  role = aws_iam_role.rotation.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage"
      ]
      Resource = aws_secretsmanager_secret.demo.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rotation_logs" {
  role       = aws_iam_role.rotation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Required for aws_lambda_function.rotation's tracing_config (CKV_AWS_50).
resource "aws_iam_role_policy_attachment" "rotation_xray" {
  role       = aws_iam_role.rotation.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_cloudwatch_log_group" "rotation" {
  name              = "/aws/lambda/${local.name_prefix}-rotation"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.workload.arn
}

# Documented, deliberate scanner exceptions -- see docs/security-exceptions.md
resource "aws_lambda_function" "rotation" {
  #checkov:skip=CKV_AWS_117:Only calls AWS APIs over the AWS backbone; VPC placement would add NAT/endpoint cost with no corresponding security benefit for this demo.
  #checkov:skip=CKV_AWS_272:Single-developer portfolio repo with one CI deploy path; code signing defends against multi-party/multi-account tampering that doesn't apply here.
  function_name    = "${local.name_prefix}-rotation"
  role             = aws_iam_role.rotation.arn
  handler          = "rotate.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.rotation_lambda.output_path
  source_code_hash = data.archive_file.rotation_lambda.output_base64sha256
  timeout          = 30
  memory_size      = 128

  reserved_concurrent_executions = 2

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.rotation_logs,
    aws_iam_role_policy_attachment.rotation_xray,
    aws_iam_role_policy.rotation_dlq,
    aws_cloudwatch_log_group.rotation,
  ]
}

resource "aws_lambda_permission" "allow_secretsmanager_rotation" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.demo.arn
}

# Automated rotation: Secrets Manager calls the rotation Lambda above on the
# schedule below, driving it through the createSecret / setSecret /
# testSecret / finishSecret contract. This replaces manual rotation as the
# default path; docs/remediation-runbook.md still documents the manual
# steps for providers/credentials that can't go through this Lambda (e.g. a
# third-party SaaS token).
resource "aws_secretsmanager_secret_rotation" "demo" {
  secret_id           = aws_secretsmanager_secret.demo.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [aws_lambda_permission.allow_secretsmanager_rotation]
}
