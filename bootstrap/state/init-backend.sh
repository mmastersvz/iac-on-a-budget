#!/usr/bin/env bash
# Creates the OCI Object Storage bucket and migrates oracle-k3s Terraform state into it.
# Reads credentials from oracle-k3s/terraform.tfvars — no extra config needed.
#
# Usage: bash bootstrap/state/init-backend.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORACLE_K3S_DIR="${SCRIPT_DIR}/../../oracle-k3s"
TFVARS="${ORACLE_K3S_DIR}/terraform.tfvars"
BACKEND_HCL="${ORACLE_K3S_DIR}/backend.hcl"
BUCKET_NAME="${BUCKET_NAME:-tf-state-oracle-k3s}"

# ── helpers ────────────────────────────────────────────────────────────────

check_deps() {
  for cmd in terraform kubectl python3; do
    command -v "$cmd" &>/dev/null || { echo "Error: $cmd not found in PATH"; exit 1; }
  done
}

get_var() {
  grep "^${1}\s*=" "$TFVARS" \
    | sed 's/[^=]*=\s*//' \
    | tr -d '"' | tr -d "'" \
    | xargs
}

# ── preflight ──────────────────────────────────────────────────────────────

check_deps

if [[ ! -f "$TFVARS" ]]; then
  echo "Error: ${TFVARS} not found."
  echo "Copy oracle-k3s/terraform.tfvars.example to terraform.tfvars and fill it in first."
  exit 1
fi

if [[ -f "$BACKEND_HCL" ]]; then
  echo "backend.hcl already exists at ${BACKEND_HCL}."
  read -rp "Overwrite and re-migrate? [y/N] " confirm
  [[ "${confirm,,}" == "y" ]] || exit 0
fi

# ── extract vars from oracle-k3s/terraform.tfvars ─────────────────────────

echo "→ Reading credentials from ${TFVARS}..."

TENANCY_OCID=$(get_var tenancy_ocid)
COMPARTMENT_OCID=$(get_var compartment_ocid)
USER_OCID=$(get_var user_ocid)
FINGERPRINT=$(get_var fingerprint)
PRIVATE_KEY_PATH=$(get_var private_key_path)
REGION=$(get_var region)

# ── create bucket ──────────────────────────────────────────────────────────

echo "→ Initialising state bootstrap Terraform..."
cd "$SCRIPT_DIR"
terraform init -input=false -reconfigure

echo "→ Creating state bucket: ${BUCKET_NAME} (region: ${REGION})..."
terraform apply -auto-approve \
  -var "tenancy_ocid=${TENANCY_OCID}" \
  -var "compartment_ocid=${COMPARTMENT_OCID}" \
  -var "user_ocid=${USER_OCID}" \
  -var "fingerprint=${FINGERPRINT}" \
  -var "private_key_path=${PRIVATE_KEY_PATH}" \
  -var "region=${REGION}" \
  -var "bucket_name=${BUCKET_NAME}"

NAMESPACE=$(terraform output -raw namespace)
S3_ENDPOINT=$(terraform output -raw s3_endpoint)

echo ""
echo "✓ Bucket ready"
echo "  Namespace : ${NAMESPACE}"
echo "  Endpoint  : ${S3_ENDPOINT}"
echo ""

# ── customer secret key ────────────────────────────────────────────────────

cat <<'EOF'
═══════════════════════════════════════════════════════════════
 You need an OCI Customer Secret Key to authenticate with the
 S3-compatible Object Storage API. This is separate from your
 API key used by the Terraform provider.

 Create one now (takes ~30 seconds):
   1. OCI Console → top-right avatar → User Settings
   2. My Profile → Tokens and keys → Customer Secret Keys → Generate Secret Key
   3. Enter a description (e.g. "terraform-state")
   4. SAVE THE SECRET — it is only shown once
   5. Note the Access Key ID shown in the table after creation
═══════════════════════════════════════════════════════════════

EOF

read -rp  "Paste the Access Key (Key ID from the table): " ACCESS_KEY
read -rsp "Paste the Secret Key (shown once at creation): " SECRET_KEY
echo ""

# ── write backend.hcl ──────────────────────────────────────────────────────

cat > "$BACKEND_HCL" <<EOF
bucket   = "${BUCKET_NAME}"
key      = "terraform.tfstate"
region   = "${REGION}"
endpoints = {
  s3 = "${S3_ENDPOINT}"
}

skip_region_validation      = true
skip_credentials_validation = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
skip_s3_checksum            = true
force_path_style            = true

access_key = "${ACCESS_KEY}"
secret_key  = "${SECRET_KEY}"
EOF

echo "✓ Written ${BACKEND_HCL}"
echo ""

# ── migrate state ──────────────────────────────────────────────────────────

echo "→ Migrating local state to OCI Object Storage..."
cd "$ORACLE_K3S_DIR"
terraform init -migrate-state -backend-config=backend.hcl

echo ""
echo "✓ State migrated to OCI Object Storage"
echo ""
echo "  Bucket   : ${BUCKET_NAME}"
echo "  Endpoint : ${S3_ENDPOINT}"
echo ""
echo "From now on, always init with:"
echo "  terraform init -backend-config=backend.hcl"
echo ""
echo "Or use the Makefile:"
echo "  make init   (from oracle-k3s/)"
