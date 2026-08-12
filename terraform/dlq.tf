# Shared dead-letter queue for both Lambda functions. A failed asynchronous
# invocation lands here instead of silently disappearing.
resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "${local.name_prefix}-lambda-dlq"
  message_retention_seconds = 1209600 # 14 days, the SQS maximum
  kms_master_key_id         = aws_kms_key.workload.id
}


resource "aws_iam_role_policy" "lambda_dlq" {
  name = "${local.name_prefix}-lambda-dlq"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.lambda_dlq.arn
    }]
  })
}

resource "aws_iam_role_policy" "rotation_dlq" {
  name = "${local.name_prefix}-rotation-dlq"
  role = aws_iam_role.rotation.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.lambda_dlq.arn
    }]
  })
}
