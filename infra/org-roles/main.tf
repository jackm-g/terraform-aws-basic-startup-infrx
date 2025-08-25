# infra/org-roles/main.tf
# Stage 2: Create deployment roles in member accounts

# Trust policy allowing management account to assume the deployment role
data "aws_iam_policy_document" "deploy_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.terraform_remote_state.bootstrap.outputs.management_account_id}:root"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Create deployment role in DEV account
resource "aws_iam_role" "deploy_dev" {
  name               = "TerraformDeployRole"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust.json
  provider           = aws.member_dev
}

resource "aws_iam_role_policy_attachment" "deploy_admin_dev" {
  role       = aws_iam_role.deploy_dev.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  provider   = aws.member_dev
}

# Create deployment role in PROD account
resource "aws_iam_role" "deploy_prod" {
  name               = "TerraformDeployRole"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust.json
  provider           = aws.member_prod
}

resource "aws_iam_role_policy_attachment" "deploy_admin_prod" {
  role       = aws_iam_role.deploy_prod.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  provider   = aws.member_prod
}
