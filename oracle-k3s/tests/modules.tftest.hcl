# Module-level assertions run against the root plan — no separate init needed
# Run: terraform test

mock_provider "oci" {
  mock_data "oci_identity_availability_domains" {
    defaults = {
      availability_domains = [{ name = "US-ASHBURN-AD-1", id = "fake-ad-1" }]
    }
  }

  mock_data "oci_core_images" {
    defaults = {
      images = [{ id = "ocid1.image.oc1..fake" }]
    }
  }
}

mock_provider "null" {}

variables {
  tenancy_ocid         = "ocid1.tenancy.oc1..fake"
  compartment_ocid     = "ocid1.compartment.oc1..fake"
  user_ocid            = "ocid1.user.oc1..fake"
  fingerprint          = "00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff"
  private_key_path     = "/tmp/fake_oci.pem"
  region               = "us-ashburn-1"
  ssh_public_key       = "ssh-rsa AAAAB3NzaC1yc2E test@test"
  ssh_private_key_path = "/tmp/fake_ssh"
  allowed_cidr         = "1.2.3.4/32"
  alert_email          = "test@example.com"
}

# --- network module ---

run "network_ssh_restricted_to_allowed_cidr" {
  command = plan

  assert {
    condition = alltrue([
      for rule in module.network.ingress_security_rules :
      rule.source == var.allowed_cidr
      if length(rule.tcp_options) > 0 && rule.tcp_options[0].min == 22
    ])
    error_message = "SSH port 22 must only be accessible from allowed_cidr, not 0.0.0.0/0"
  }
}

run "network_k8s_api_restricted_to_allowed_cidr" {
  command = plan

  assert {
    condition = alltrue([
      for rule in module.network.ingress_security_rules :
      rule.source == var.allowed_cidr
      if length(rule.tcp_options) > 0 && rule.tcp_options[0].min == 6443
    ])
    error_message = "K8s API port 6443 must only be accessible from allowed_cidr, not 0.0.0.0/0"
  }
}

run "network_http_open_to_all" {
  command = plan

  assert {
    condition = anytrue([
      for rule in module.network.ingress_security_rules :
      rule.source == "0.0.0.0/0"
      if length(rule.tcp_options) > 0 && rule.tcp_options[0].min == 80
    ])
    error_message = "HTTP port 80 should be open to 0.0.0.0/0 for workloads"
  }
}

run "network_subnet_assigns_public_ips" {
  command = plan

  assert {
    condition     = module.network.subnet_prohibit_public_ip == false
    error_message = "Subnet must allow public IP assignment"
  }
}

# --- compute module ---

run "compute_uses_always_free_shape" {
  command = plan

  assert {
    condition     = module.compute.shape == "VM.Standard.A1.Flex"
    error_message = "Must use VM.Standard.A1.Flex — the Always Free ARM shape"
  }
}

run "compute_uses_always_free_max_ocpus" {
  command = plan

  assert {
    condition     = module.compute.ocpus == 4
    error_message = "Must use 4 OCPUs — the Always Free maximum for VM.Standard.A1.Flex"
  }
}

run "compute_uses_always_free_max_memory" {
  command = plan

  assert {
    condition     = module.compute.memory_in_gbs == 24
    error_message = "Must use 24 GB RAM — the Always Free maximum for VM.Standard.A1.Flex"
  }
}

run "compute_boot_volume_within_free_tier" {
  command = plan

  assert {
    condition     = module.compute.boot_volume_size_in_gbs == "100"
    error_message = "Boot volume should be 100 GB (within the 200 GB Always Free total)"
  }
}
