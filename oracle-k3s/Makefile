BACKEND_CONFIG := backend.hcl

.PHONY: init plan apply destroy test output public-ip kubeconfig-path

init:
	terraform init -backend-config=$(BACKEND_CONFIG)

plan:
	terraform plan -var-file=terraform.tfvars

apply:
	terraform apply -var-file=terraform.tfvars

destroy:
	terraform destroy -var-file=terraform.tfvars

test:
	terraform test

output:
	terraform output

public-ip:
	@terraform output -raw public_ip

kubeconfig-path:
	@terraform output -raw kubeconfig_path
