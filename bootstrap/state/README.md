# Terraform State Backend

Provisions an [OCI Object Storage](https://docs.oracle.com/en-us/iaas/Content/Object/Concepts/objectstorageoverview.htm) bucket and attempts to migrate `oracle-k3s/terraform.tfstate` into it.

> **Known limitation:** OCI Object Storage S3-compatible API does not support AWS chunked transfer encoding, which [Terraform 1.8+ (AWS SDK v2)](https://github.com/hashicorp/terraform/issues/34879) uses by default. State uploads will fail with `501 NotImplemented: AWS chunked encoding not supported`. See [alternatives](#alternatives) below.

---

## What the script does

1. Creates an OCI Object Storage bucket (`tf-state-oracle-k3s`) using the same credentials as `oracle-k3s/terraform.tfvars`
2. Prompts you to create an OCI Customer Secret Key
3. Writes `oracle-k3s/backend.hcl` (gitignored)
4. Runs `terraform init -migrate-state`

The bucket itself is always free (OCI Object Storage: 20 GB free). The migration step will fail due to the chunked encoding issue, but the bucket is still created and usable if the limitation is resolved in a future Terraform release.

---

## Run it

```bash
bash bootstrap/state/init-backend.sh
```

Custom bucket name:

```bash
BUCKET_NAME=my-tfstate bash bootstrap/state/init-backend.sh
```

---

## Alternatives

### Terraform Cloud (recommended — free)

[Free for 1 user](https://www.hashicorp.com/products/terraform/pricing), no chunked encoding issue, officially supported.

1. Sign up at [app.terraform.io](https://app.terraform.io)
2. Create an organisation and a workspace named `oracle-k3s`
3. Run `terraform login` in `oracle-k3s/`
4. Replace the backend comment in `versions.tf`:

```hcl
cloud {
  organization = "your-org-name"
  workspaces {
    name = "oracle-k3s"
  }
}
```

5. `terraform init`

---

### Cloudflare R2 (free 10 GB, S3-compatible)

[R2](https://developers.cloudflare.com/r2/) supports chunked encoding — the [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3) works correctly.

1. Sign up at cloudflare.com → R2 → Create bucket `terraform-state`
2. R2 → Manage R2 API Tokens → Create token with Object Read & Write
3. Add `backend "s3" {}` to `oracle-k3s/versions.tf`
4. Create `oracle-k3s/backend.hcl`:

```hcl
bucket   = "terraform-state"
key      = "oracle-k3s/terraform.tfstate"
region   = "auto"
endpoints = {
  s3 = "https://<account_id>.r2.cloudflarestorage.com"
}

skip_region_validation      = true
skip_credentials_validation = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
skip_s3_checksum            = true
force_path_style            = true

access_key = "<r2_access_key_id>"
secret_key  = "<r2_secret_access_key>"
```

5. `terraform init -backend-config=backend.hcl`

---

## Customer Secret Key vs API Key

| | API Key | Customer Secret Key |
|---|---|---|
| Used by | Terraform OCI provider | S3-compatible Object Storage API |
| Format | PEM key pair + fingerprint | access_key / secret_key pair |
| Create at | Profile → API Keys | Profile → Customer Secret Keys |

Both live under the same OCI user profile.

---

## State bucket properties

- **Versioning enabled** — every write creates a recoverable version
- **No public access** — credentials required
- **Always Free** — OCI Object Storage is free up to 20 GB
