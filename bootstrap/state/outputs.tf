output "namespace" {
  description = "OCI Object Storage namespace (used in S3-compatible endpoint)"
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "bucket_name" {
  value = oci_objectstorage_bucket.tfstate.name
}

output "s3_endpoint" {
  description = "S3-compatible endpoint for the Terraform backend"
  value       = "https://${data.oci_objectstorage_namespace.this.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}
