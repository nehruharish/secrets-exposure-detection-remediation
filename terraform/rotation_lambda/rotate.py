"""
AWS Secrets Manager rotation Lambda implementing the standard 4-step
rotation contract (createSecret / setSecret / testSecret / finishSecret).

This demo secret has no backing external system (no database, no
third-party API) to rotate credentials against. setSecret and testSecret
are documented no-ops for that reason: they exist so the Lambda has the
correct shape of a real rotation function, with a clear comment on exactly
what a production implementation would do in their place, rather than
silently skipping steps.
"""
import logging
import secrets as secrets_module

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    arn = event["SecretId"]
    token = event["ClientRequestToken"]
    step = event["Step"]

    client = boto3.client("secretsmanager")
    metadata = client.describe_secret(SecretId=arn)

    if not metadata.get("RotationEnabled"):
        raise ValueError(f"Secret {arn} is not enabled for rotation")

    versions = metadata.get("VersionIdsToStages", {})
    if token not in versions:
        raise ValueError(f"Version {token} has no stage for rotation of secret {arn}")
    if "AWSCURRENT" in versions[token]:
        logger.info("Version %s already marked AWSCURRENT, nothing to do", token)
        return
    if "AWSPENDING" not in versions[token]:
        raise ValueError(f"Version {token} not staged as AWSPENDING for secret {arn}")

    if step == "createSecret":
        create_secret(client, arn, token)
    elif step == "setSecret":
        set_secret(client, arn, token)
    elif step == "testSecret":
        test_secret(client, arn, token)
    elif step == "finishSecret":
        finish_secret(client, arn, token)
    else:
        raise ValueError(f"Unknown rotation step: {step}")


def create_secret(client, arn, token):
    """Generate a new synthetic secret value and stage it as AWSPENDING."""
    try:
        client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        logger.info("createSecret: AWSPENDING version %s already exists", token)
        return
    except client.exceptions.ResourceNotFoundException:
        pass

    new_value = secrets_module.token_urlsafe(32)
    client.put_secret_value(
        SecretId=arn,
        ClientRequestToken=token,
        SecretString=new_value,
        VersionStages=["AWSPENDING"],
    )
    logger.info("createSecret: staged new AWSPENDING version %s", token)


def set_secret(client, arn, token):
    """
    No-op in this demo. A real rotation Lambda would push the AWSPENDING
    value out to the system that consumes this credential (e.g. create a
    new database user, call a provider's key-rotation API) before it can be
    verified in testSecret. This demo secret has no backing system to push
    the new value to.
    """
    logger.info("setSecret: no external system to update in this demo, skipping")


def test_secret(client, arn, token):
    """
    No-op in this demo, for the same reason as setSecret. A real
    implementation would authenticate against the backing system using the
    AWSPENDING value and raise an exception here (failing the rotation) if
    that authentication doesn't work.
    """
    logger.info("testSecret: no external system to verify against in this demo, skipping")


def finish_secret(client, arn, token):
    """Promote the AWSPENDING version to AWSCURRENT."""
    metadata = client.describe_secret(SecretId=arn)
    current_version = None
    for version_id, stages in metadata.get("VersionIdsToStages", {}).items():
        if "AWSCURRENT" in stages:
            if version_id == token:
                logger.info("finishSecret: version %s already AWSCURRENT", token)
                return
            current_version = version_id
            break

    client.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version,
    )
    logger.info("finishSecret: promoted version %s to AWSCURRENT", token)
