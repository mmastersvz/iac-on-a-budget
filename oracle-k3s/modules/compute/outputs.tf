output "public_ip" {
  description = "Public IP address of the k3s node"
  value       = oci_core_instance.this.public_ip
}

output "shape" {
  description = "Shape of the provisioned instance"
  value       = oci_core_instance.this.shape
}

output "ocpus" {
  description = "Number of OCPUs allocated"
  value       = oci_core_instance.this.shape_config[0].ocpus
}

output "memory_in_gbs" {
  description = "Memory allocated in GB"
  value       = oci_core_instance.this.shape_config[0].memory_in_gbs
}

output "boot_volume_size_in_gbs" {
  description = "Boot volume size in GB"
  value       = oci_core_instance.this.source_details[0].boot_volume_size_in_gbs
}
