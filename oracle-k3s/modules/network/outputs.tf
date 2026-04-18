output "subnet_id" {
  description = "ID of the public subnet"
  value       = oci_core_subnet.this.id
}

output "vcn_id" {
  description = "ID of the VCN"
  value       = oci_core_vcn.this.id
}

output "ingress_security_rules" {
  description = "Ingress rules on the security list"
  value       = oci_core_security_list.this.ingress_security_rules
}

output "subnet_prohibit_public_ip" {
  description = "Whether public IPs are blocked on the subnet"
  value       = oci_core_subnet.this.prohibit_public_ip_on_vnic
}
