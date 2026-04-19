# Terraform State Backend

Provisions an OCI Object Storage bucket for remote Terraform state and migrates `oracle-k3s/terraform.tfstate` into it.

OCI Object Storage is free up to 20 GB — a Terraform state file is a few KB.

---

## How it works

1. A small standalone Terraform config here creates the bucket (its own state lives locally — just one resource, safe to lose).
2. The script reads credentials from `oracle-k3s/terraform.tfvars` — no separate config needed.
3. You create an OCI Customer Secret Key (30-second console action).
4. The script writes `oracle-k3s/backend.hcl` and runs `terraform init -migrate-state`.

After migration, `oracle-k3s/terraform.tfstate` is no longer used — state lives in OCI.

---

## Run it

```bash
bash bootstrap/state/init-backend.sh
```

The script will:
- Create the `tf-state-oracle-k3s` bucket in your compartment
- Prompt you to create a Customer Secret Key in the OCI Console
- Write `oracle-k3s/backend.hcl` (gitignored)
- Migrate local state to the bucket

Custom bucket name:

```bash
BUCKET_NAME=my-tfstate bash bootstrap/state/init-backend.sh
```

---

## After migration

All `terraform` commands in `oracle-k3s/` must pass the backend config.
Use the Makefile targets — they handle this automatically:

```bash
cd oracle-k3s
make init     # terraform init -backend-config=backend.hcl
make plan
make apply
make destroy
```

Or manually:

```bash
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
```

---

## Customer Secret Key vs API Key

| | API Key | Customer Secret Key |
|---|---|---|
| Used by | Terraform OCI provider | S3-compatible Object Storage API |
| Format | PEM key pair + fingerprint | access_key / secret_key pair |
| Create at | Profile → API Keys | Profile → Customer Secret Keys |

Both live under the same OCI user profile. You need both.

---

## State bucket properties

- **Versioning enabled** — every state write creates a recoverable version
- **No public access** — private bucket, credentials required
- **Always Free** — OCI Object Storage is free up to 20 GB
