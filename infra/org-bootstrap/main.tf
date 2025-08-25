# infra/org-bootstrap/main.tf
# Stage 1: Reference existing organization and create OUs and member accounts

# Reference the existing organization
data "aws_organizations_organization" "org" {}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_organizational_unit" "dev" {
  name      = "Dev"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "prod" {
  name      = "Prod"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

# Define the accounts you want
locals {    
  accounts = {
    dev  = { email = var.account_emails.dev,  ou_id = aws_organizations_organizational_unit.dev.id }
    prod = { email = var.account_emails.prod, ou_id = aws_organizations_organizational_unit.prod.id }
  }
}

# Create accounts with a consistent bootstrap role
resource "aws_organizations_account" "members" {
  for_each  = local.accounts
  name      = upper(each.key)
  email     = each.value.email
  parent_id = each.value.ou_id

  # Keep the default name; easy to reason about later
  role_name = "OrganizationAccountAccessRole"
}
