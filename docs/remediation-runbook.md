# Remediation Runbook

## Gitleaks finding

### 1. Stop propagation
Do not merge the pull request. If already merged, stop deployment where appropriate.

### 2. Identify
Record the secret type, owner, affected environment, service and exposure window.

### 3. Rotate/revoke
For the demo secret in AWS Secrets Manager, trigger rotation immediately rather than waiting for the scheduled window:

```bash
aws secretsmanager rotate-secret --secret-id <secret-id>
```

This invokes the rotation Lambda in `terraform/rotation_lambda/rotate.py`, which stages and promotes a new value through the standard createSecret/setSecret/testSecret/finishSecret contract. For AWS access keys outside Secrets Manager, deactivate/delete the exposed key and issue a replacement. For SaaS tokens or other credentials with no automated rotation path here, revoke and issue a new token through the provider's own mechanism, then update Secrets Manager manually.

### 4. Remove from source
Remove the credential from code/configuration. If required, clean Git history using the organisation's approved process.

### 5. Store securely
Move runtime credentials to AWS Secrets Manager or the organisation's approved secret-management platform.

### 6. Verify
Run:

```bash
gitleaks detect --source . --config .gitleaks.toml --redact
```

Inspect CI logs and relevant audit logs. Confirm the CloudWatch alarm (`terraform/monitoring.tf`) did not fire on the new value, and check the SNS topic for any alert generated during the incident.

### 7. Prevent recurrence
Use pre-commit scanning, branch protection, required security checks, least-privilege credentials and short-lived CI authentication such as OIDC.
