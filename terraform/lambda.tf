data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../app/lambda/handler.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "app" {
  #checkov:skip=CKV_AWS_117:Only calls AWS APIs over the AWS backbone (Secrets Manager, KMS, CloudWatch); VPC placement would add NAT/endpoint cost with no corresponding security benefit for this demo.
  #checkov:skip=CKV_AWS_272:Single-developer portfolio repo with one CI deploy path; code signing defends against multi-party/multi-account tampering that doesn't apply here.
  function_name    = "${local.name_prefix}-runtime-secret-demo"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10
  memory_size      = 256

  reserved_concurrent_executions = 5
  kms_key_arn                    = aws_kms_key.workload.arn

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.demo.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.lambda_xray,
    aws_iam_role_policy.lambda_dlq,
  ]
}
