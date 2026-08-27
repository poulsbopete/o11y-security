"""Lab configuration. LAB_VULN:hardcoded_secret — credentials live in source, not a secret store."""

# LAB_VULN:hardcoded_secret — default operator password committed to git (never do this).
ADMIN_USER = "claims-admin"
ADMIN_PASSWORD = "AcmeClaimsLabOnly-ChangeMe!"

# LAB_VULN:hardcoded_secret — API key used by the claims adapter to call a downstream payer API.
PAYER_API_KEY = "sk_lab_live_4f8c1e9b2a7d0c3e5b6a8f1d9c2e4a70"

# Shared host name with workshop-synth-* documents so A2A correlation still works.
SERVICE_HOST = "prod-db-01"
SERVICE_NAME = "claims-portal"
