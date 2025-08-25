# infra/org-roles/outputs.tf
# Export deployment role ARNs for use in application stacks

output "deploy_role_arns" {
  description = "ARNs of TerraformDeployRole in each account"
  value = {
    dev  = aws_iam_role.deploy_dev.arn
    prod = aws_iam_role.deploy_prod.arn
  }
}

output "account_ids" {
  description = "Account IDs from Stage 1"
  value = data.terraform_remote_state.bootstrap.outputs.account_ids
}
