# Incident Response

If a real credential is detected, treat it as compromised immediately.

1. Stop propagation/deployment.
2. Identify the credential and owner.
3. Revoke or rotate it.
4. Remove it from the active code/configuration.
5. Investigate logs and audit trails.
6. Remove it from repository history using the approved procedure.
7. Replace it with a managed runtime secret.
8. Rerun security scanning and verify the old credential no longer works.
9. Record lessons learned and preventative controls.

Removing a secret from the latest commit alone is not sufficient because it may exist in Git history, PR metadata, CI logs, caches or forks.
