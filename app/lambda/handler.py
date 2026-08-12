import json
import logging
import os
import re
from typing import Any

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_secret(secret_arn: str) -> str:
    """Retrieve a runtime secret without logging its value."""
    client = boto3.client("secretsmanager")
    response = client.get_secret_value(SecretId=secret_arn)
    return response["SecretString"]


def redact(value: str) -> str:
    """Redact common credential-like values before they reach logs."""
    patterns = [
        (r"(?i)(password|passwd|secret|token|api[_-]?key)\s*[:=]\s*([^\s,]+)", r"\1=[REDACTED]"),
        (r"AKIA[0-9A-Z]{16}", "[AWS_ACCESS_KEY_REDACTED]"),
        (r"-----BEGIN [A-Z ]+ PRIVATE KEY-----.*?-----END [A-Z ]+ PRIVATE KEY-----", "[PRIVATE_KEY_REDACTED]"),
    ]
    redacted = value
    for pattern, replacement in patterns:
        redacted = re.sub(pattern, replacement, redacted, flags=re.DOTALL)
    return redacted


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    secret_arn = os.environ.get("SECRET_ARN")
    if not secret_arn:
        logger.error("SECRET_ARN is not configured")
        return {"statusCode": 500, "body": json.dumps({"error": "configuration error"})}

    try:
        secret = get_secret(secret_arn)
        diagnostic = event.get("diagnostic", "")
        if diagnostic:
            logger.info("Diagnostic data: %s", redact(str(diagnostic)))

        logger.info("Runtime secret retrieved successfully")
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Runtime secret retrieved successfully",
                "secret_length": len(secret),
            }),
        }
    except Exception as exc:
        logger.error("Runtime secret retrieval failed: %s", redact(str(exc)))
        return {"statusCode": 500, "body": json.dumps({"error": "secret retrieval failed"})}
