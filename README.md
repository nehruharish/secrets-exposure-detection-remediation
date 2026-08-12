# Secrets Exposure Detection & Remediation Pipeline

A production-style DevSecOps reference project for detecting accidental exposure of credentials and secrets in source code and infrastructure, blocking insecure changes in CI/CD, and demonstrating secure runtime secret retrieval on AWS.

> Portfolio project inspired by a common enterprise security problem. This repository is intentionally small enough to understand end-to-end while demonstrating patterns used in real environments.

## Problem

Developers can accidentally commit API keys, passwords, tokens or private keys to source control. A mature engineering platform should detect these issues early, prevent insecure changes from progressing, and provide a documented remediation path.

## What this project demonstrates

- Secret detection with Gitleaks
- Terraform/IaC security scanning with Checkov, findings triaged and either fixed or explicitly accepted with documented rationale (see `docs/security-exceptions.md`)
- IaC/container configuration scanning with Trivy
- GitHub Actions security gates
- GitHub OIDC authentication to AWS without long-lived AWS keys
- AWS Secrets Manager for runtime secrets, encrypted with a customer-managed KMS key
- IAM least privilege
- Lambda runtime secret retrieval, with X-Ray tracing, a dead-letter queue and encrypted environment variables
- CloudWatch monitoring for credential-like log content, alerting via SNS
- Automated Secrets Manager rotation via a dedicated rotation Lambda
- Automated tests and pre-commit scanning
- Incident response and credential remediation

## Architecture

```text
Developer
   |
   v
GitHub Pull Request
   |
   +--> Gitleaks -----> secret found? ------> FAIL
   +--> Checkov ------> insecure IaC? ------> FAIL
   +--> Trivy --------> HIGH/CRITICAL? -----> FAIL
   +--> Unit tests ---> failure? ------------> FAIL
   |
   v
Security gates pass
   |
   v
GitHub Actions -- OIDC --> AWS STS --> IAM role
                                      |
                         +------------+-------------+
                         |                          |
                         v                          v
                 Terraform / AWS             Deployment
                         |                          |
                         v                          v
                 Secrets Manager <--------- Lambda (KMS-encrypted,
                         |                    X-Ray traced, DLQ-backed)
                    (rotation Lambda)                |
                         |                          |
                         +--------------------------+
                                    |
                                    v
                              CloudWatch Logs (KMS-encrypted)
                                    |
                                    v
                         Metric filter / Alarm --> SNS (KMS-encrypted) --> email
```

A single customer-managed KMS key (`terraform/kms.tf`) encrypts the demo secret, both Lambda functions' environment variables, both CloudWatch Log Groups, and the SNS topic.

## Repository structure

```text
.github/workflows/security.yml        Security gates
.github/workflows/terraform.yml       Terraform plan/apply workflow
app/lambda/handler.py                 Runtime secret demo
terraform/                            AWS infrastructure
terraform/kms.tf                      Shared customer-managed KMS key
terraform/dlq.tf                      Shared Lambda dead-letter queue
terraform/rotation_lambda/rotate.py   Secrets Manager rotation Lambda
tests/                                Unit tests
docs/                                 Architecture, incident runbooks, and documented Checkov exceptions
```

## Local checks

Requirements: Python 3.11+, Terraform, Gitleaks, Checkov and Trivy.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
make test
make security
make terraform-validate
```

## AWS deployment

The Terraform example creates a synthetic secret with automated rotation, a Lambda execution role, a Lambda function that reads the secret at runtime, a CloudWatch log group/metric filter/alarm wired to an SNS topic, a shared dead-letter queue, a customer-managed KMS key encrypting all of the above, and a GitHub OIDC role scoped to everything above.

Before deployment, change `github_repository` in `terraform/variables.tf` to your real `OWNER/REPOSITORY`, and optionally set `alert_email` to receive the CloudWatch alarm's SNS notifications (confirm the subscription email AWS sends before it will deliver).

**Bootstrap order:** the `github_actions` IAM role is deliberately not permitted to manage itself or the OIDC provider (see the comment in `terraform/iam.tf`), so the very first `terraform apply` — the one that creates that role — must run with your own AWS credentials, not through CI:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Every apply after that (of the Lambda, secret, rotation, monitoring and everything else this config manages) can run through the `terraform.yml` GitHub Actions workflow using the role that first apply created.

For a real organisation, use separate AWS accounts/environments and a remote Terraform backend. Do not commit Terraform state.

The demo secret is intentionally synthetic. Never put a real credential into `demo_secret_value` in source control or a command history.

## Demonstrating the security gate

Create a temporary branch and add a file containing an obviously fake credential-like value, then open a PR. Gitleaks should fail the workflow. Remove the finding, rotate/revoke any real credential if one had been exposed, and rerun the checks.

The project deliberately treats a real credential as compromised if it is ever committed. Removing it from the latest commit is not sufficient because it may remain in Git history, PR metadata, logs, caches or forks.
