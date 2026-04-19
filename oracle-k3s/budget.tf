# OCI allows only 1 budget per compartment on the free tier.
# If one already exists we attach the alert rule to it rather than creating a new one.

data "oci_budget_budgets" "existing" {
  compartment_id = var.tenancy_ocid
}

locals {
  existing_budget_id = length(data.oci_budget_budgets.existing.budgets) > 0 ? data.oci_budget_budgets.existing.budgets[0].id : null
}

resource "oci_budget_budget" "free_tier_guard" {
  count = local.existing_budget_id == null ? 1 : 0

  compartment_id = var.tenancy_ocid
  amount         = 1
  reset_period   = "MONTHLY"
  display_name   = "always-free-guard"
  description    = "Alerts on any spend — all resources should be Always Free"
  target_type    = "COMPARTMENT"
  targets        = [var.compartment_ocid]
}

locals {
  budget_id = local.existing_budget_id != null ? local.existing_budget_id : oci_budget_budget.free_tier_guard[0].id
}

resource "oci_budget_alert_rule" "any_spend" {
  budget_id      = local.budget_id
  threshold      = 0.01
  threshold_type = "ABSOLUTE"
  type           = "ACTUAL"
  display_name   = "zero-spend-alert"
  recipients     = var.alert_email
  message        = "OCI charges detected on always-free account — check for non-free resources immediately."
}
