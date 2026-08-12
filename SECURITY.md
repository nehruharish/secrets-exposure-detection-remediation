# Security Policy

Never commit real credentials, tokens, private keys or production secrets to this repository.

If a real secret is accidentally committed:

1. Treat it as compromised.
2. Revoke or rotate it immediately.
3. Remove it from the active code path.
4. Investigate relevant logs/audit trails.
5. Remove it from repository history using the organisation's approved procedure.
6. Rerun secret scanning.

Do not open a public GitHub issue containing a real secret.
