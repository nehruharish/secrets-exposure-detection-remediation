# Architecture

## Security flow

The project applies security checks before infrastructure deployment. Gitleaks identifies exposed secrets; Checkov and Trivy assess infrastructure/configuration; unit tests validate application behaviour. GitHub Actions authenticates to AWS using OIDC and short-lived credentials.

## Runtime flow

Lambda receives an invocation, reads the secret ARN from configuration, calls Secrets Manager, and keeps the secret in process memory only. It never returns the secret and redacts credential-like diagnostic input before logging.

## Production evolution

For enterprise rollout, use separate AWS accounts, a remote Terraform backend, centralised reusable CI workflows, stronger IAM scoping, CloudTrail/EventBridge integration, SIEM forwarding and provider-specific automated rotation.
