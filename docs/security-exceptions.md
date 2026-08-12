# Security scanner exceptions

This project treats a failing Checkov check as something to evaluate, not
something to automatically satisfy. Most findings get fixed outright. Two
are deliberately accepted instead, and this doc is where that reasoning
lives (the same rationale is also inline as a `#checkov:skip` comment next
to each resource, in `terraform/lambda.tf` and `terraform/rotation.tf`).

## CKV_AWS_117 -- Lambda not configured inside a VPC

**Finding:** both `aws_lambda_function.app` and `aws_lambda_function.rotation`
run outside a VPC.

**Why it's accepted:** neither function talks to anything that requires
VPC networking -- they call Secrets Manager, KMS and CloudWatch over the
AWS network backbone, nothing more. Putting them in a VPC would mean either
a NAT gateway (a real, ongoing per-hour cost) or interface VPC endpoints
for every one of those services, purely so the functions could reach
services they already reach for free outside a VPC. That trade only makes
sense when a function needs to reach something VPC-only (an RDS instance,
an internal load balancer, on-prem via VPN/Direct Connect) or when network
egress needs to be tightly controlled beyond what IAM already restricts
here. Neither applies to this demo.

**What would change the calculus:** if this evolved into a real service
talking to a private database or an internal API, VPC placement (with
interface endpoints for the AWS services it still needs) would become the
right call, and this exception would be removed.

## CKV_AWS_272 -- Lambda code signing not configured

**Finding:** neither Lambda function has a code-signing configuration
(AWS Signer).

**Why it's accepted:** code signing exists to answer "did this code come
from a trusted publisher and reach this account through an approved
pipeline," which matters when multiple teams, contractors or accounts can
push code into a shared Lambda, or when supply-chain tampering between
"code was written" and "code was deployed" is a realistic threat. This is
a single-developer portfolio repository with exactly one deploy path --
this repo's own CI, itself gated by the security checks in this same
workflow. There's no second party or alternate deploy path the control
would be defending against here.

**What would change the calculus:** in a team or org setting with multiple
contributors and deploy paths, code signing is worth the setup cost (an
AWS Signer signing profile, a code-signing config resource, and a CI step
to sign the build artifact) even for infrastructure this small.
