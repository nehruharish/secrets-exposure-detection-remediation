# Single customer-managed KMS key used to encrypt the demo secret, both
# Lambda functions' environment variables, both CloudWatch Log Groups, and
# the SNS alerts topic. One shared CMK keeps this demo's KMS footprint to a single key instead of one per resource.
resource "aws_kms_key" "workload" {
  description             = "CMK for ${local.name_prefix} secrets, logs, env vars and alerts"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowGithubActionsRoleToUseAndManage"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.github_actions.arn }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant",
          "kms:PutKeyPolicy",
          "kms:GetKeyPolicy",
          "kms:EnableKeyRotation",
          "kms:GetKeyRotationStatus",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ListResourceTags",
          "kms:ScheduleKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowWorkloadLambdaRoles"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.lambda.arn,
            aws_iam_role.rotation.arn
          ]
        }
        Action   = ["kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      {
        Sid       = "AllowSecretsManager"
        Effect    = "Allow"
        Principal = { Service = "secretsmanager.amazonaws.com" }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
      },
      {
        Sid       = "AllowSNS"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "workload" {
  name          = "alias/${local.name_prefix}-workload"
  target_key_id = aws_kms_key.workload.key_id
}
