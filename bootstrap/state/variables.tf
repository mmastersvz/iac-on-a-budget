variable "tenancy_ocid" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "user_ocid" {
  type = string
}

variable "fingerprint" {
  type = string
}

variable "private_key_path" {
  type = string
}

variable "region" {
  type = string
}

variable "bucket_name" {
  description = "Name of the OCI Object Storage bucket for Terraform state"
  type        = string
  default     = "tf-state-oracle-k3s"
}
