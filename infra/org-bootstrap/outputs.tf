# infra/org-bootstrap/outputs.tf
# Export account IDs for Stage 2

output "account_ids" {
  description = "Map of account names to account IDs"
  value = {
    for name, account in aws_organizations_account.members : name => account.id
  }
}

output "management_account_id" {
  description = "Management account ID"
  value = data.aws_caller_identity.mgmt.account_id
}
