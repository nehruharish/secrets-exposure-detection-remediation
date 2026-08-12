test:
	pytest -q

security:
	gitleaks detect --source . --config .gitleaks.toml --redact
	checkov -d terraform
	trivy config terraform

terraform-validate:
	terraform -chdir=terraform fmt -check -recursive
	terraform -chdir=terraform init -backend=false
	terraform -chdir=terraform validate
