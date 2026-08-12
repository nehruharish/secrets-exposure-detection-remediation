import importlib.util
import logging
import os
from pathlib import Path


HANDLER_PATH = Path(__file__).resolve().parents[1] / "app" / "lambda" / "handler.py"
spec = importlib.util.spec_from_file_location("portfolio_handler", HANDLER_PATH)
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)


def test_redact_password():
    value = "password=EXAMPLE_NOT_A_REAL_SECRET_123"
    result = handler.redact(value)
    assert "EXAMPLE_NOT_A_REAL_SECRET_123" not in result
    assert "[REDACTED]" in result


def test_redact_aws_key():
    value = "key=AKIA1234567890ABCDEF"
    result = handler.redact(value)
    assert "AKIA1234567890ABCDEF" not in result
    assert "[AWS_ACCESS_KEY_REDACTED]" in result


def test_lambda_does_not_return_secret(monkeypatch):
    secret = "EXAMPLE_NOT_A_REAL_SECRET_123"
    monkeypatch.setenv("SECRET_ARN", "arn:aws:secretsmanager:eu-west-2:123456789012:secret:test")
    monkeypatch.setattr(handler, "get_secret", lambda _: secret)

    result = handler.lambda_handler(
        {"diagnostic": f"password={secret}"},
        object(),
    )

    assert result["statusCode"] == 200
    assert secret not in result["body"]


def test_lambda_diagnostic_is_redacted_before_logging(monkeypatch, caplog):
    """
    test_lambda_does_not_return_secret above only checks the HTTP response,
    but the response body never carried the diagnostic value to begin with
    -- it only ever contains secret_length. That test would pass even with
    a no-op redact(). This test checks the thing redact() actually
    protects: what gets written to logs.
    """
    secret = "EXAMPLE_NOT_A_REAL_SECRET_123"
    monkeypatch.setenv("SECRET_ARN", "arn:aws:secretsmanager:eu-west-2:123456789012:secret:test")
    monkeypatch.setattr(handler, "get_secret", lambda _: secret)

    with caplog.at_level(logging.INFO):
        result = handler.lambda_handler(
            {"diagnostic": f"password={secret}"},
            object(),
        )

    assert result["statusCode"] == 200
    logged_text = "\n".join(record.getMessage() for record in caplog.records)
    assert secret not in logged_text
    assert "[REDACTED]" in logged_text


def test_exception_is_redacted_before_logging(monkeypatch, caplog):
    """Covers the except block's logger.error call, which also runs redact()."""
    secret = "AKIA1234567890ABCDEF"
    monkeypatch.setenv("SECRET_ARN", "arn:aws:secretsmanager:eu-west-2:123456789012:secret:test")

    def boom(_arn):
        raise RuntimeError(f"upstream error, key={secret}")

    monkeypatch.setattr(handler, "get_secret", boom)

    with caplog.at_level(logging.INFO):
        result = handler.lambda_handler({}, object())

    assert result["statusCode"] == 500
    logged_text = "\n".join(record.getMessage() for record in caplog.records)
    assert secret not in logged_text
    assert "[AWS_ACCESS_KEY_REDACTED]" in logged_text
