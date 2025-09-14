Here’s a pragmatic, “modern best-practice” way to do this that scales cleanly across multiple AWS accounts and keeps credentials out of GitHub:

# What we’re going to do

1. **Use GitHub Actions OIDC → AWS** (no long-lived AWS keys) with a **least-privileged role per account** (STAGING & PROD).
2. **Split CI and CD**: your existing `ci.yml` runs tests; a separate `cd.yml` runs **only after `ci.yml` passes** via `workflow_run`.
3. **Branch-based routing**:

   * `staging` → STAGING account ECR repo
   * `main` → PROD account ECR repo
4. **Hardened container builds** with `buildx`, provenance-ready tagging, and reproducible caching.
5. **Reusable infra**: same role name in each account, different ARNs; same workflow selects the right one based on the branch.

---

# 1) AWS (per account): OIDC + least privilege IAM

Create this **once in each account** (STAGING & PROD). Use Terraform or CloudFormation, but here’s the essence.

**OIDC provider (only needed once per account):**

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub's OIDC thumbprint
}
```

**CD role** (one per account; same name is fine, e.g., `GitHubCDRole`):
Trust ONLY your repo (and optionally only specific branches/environments).

```hcl
resource "aws_iam_role" "github_cd_role" {
  name = "GitHubCDRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          # Limit to your repo; you can also add :ref:refs/heads/main|staging to bind to branch
          "token.actions.githubusercontent.com:sub" = "repo:<OWNER>/<REPO>:ref:refs/heads/*"
        }
      }
    }]
  })
}

# ECR-only least privilege (push, set tags, get auth, etc.)
resource "aws_iam_policy" "ecr_push_policy" {
  name   = "EcrPushPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect="Allow", Action=[
          "ecr:GetAuthorizationToken"
        ], Resource="*" },
      { Effect="Allow", Action=[
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchDeleteImage"
        ],
        Resource = "arn:aws:ecr:<REGION>:<ACCOUNT_ID>:repository/<ECR_REPO_NAME>*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.github_cd_role.name
  policy_arn = aws_iam_policy.ecr_push_policy.arn
}
```

**ECR repos (per account):**

* STAGING account: `myapp/backend-staging`
* PROD account: `myapp/backend-prod`
* Turn on **Scan on Push**, server-side **encryption**, and a **lifecycle policy** (e.g., keep last N images).

---

# 2) GitHub → environments & secrets

Use **GitHub Environments** (`staging`, `prod`) with protection rules if you want approvals or manual gates.

Add these repository or environment secrets/vars:

* `AWS_REGION`: `us-east-1` (or your region)
* `AWS_ROLE_TO_ASSUME_STAGING`: `arn:aws:iam::<STAGING_ACCOUNT_ID>:role/GitHubCDRole`
* `AWS_ROLE_TO_ASSUME_PROD`: `arn:aws:iam::<PROD_ACCOUNT_ID>:role/GitHubCDRole`
* `ECR_REPO_STAGING`: `myapp/backend-staging`
* `ECR_REPO_PROD`: `myapp/backend-prod`

(You can store them as **environment variables** in each environment to simplify branching logic.)

---

# 3) CI → CD handoff

Your existing `ci.yml` runs tests. We’ll trigger `cd.yml` **only after that workflow succeeds** using `workflow_run`. This prevents image pushes if tests fail and keeps pipelines composable.

---

# 4) `cd.yml` (single workflow handles both branches/accounts)

Place in `.github/workflows/cd.yml`:

```yaml
name: CD (Push to ECR after CI)

on:
  workflow_run:
    workflows: ["CI"]            # <-- must match the name: of your test workflow (ci.yml)
    types: [completed]

permissions:
  id-token: write    # OIDC
  contents: read

concurrency:
  group: cd-${{ github.ref }}   # avoid overlapping deploys per branch
  cancel-in-progress: true

jobs:
  push-image:
    name: Build & Push Image to ECR
    if: >
      ${{ github.event.workflow_run.conclusion == 'success' &&
          (github.event.workflow_run.head_branch == 'main' || github.event.workflow_run.head_branch == 'staging') }}
    runs-on: self-hosted   # your private runner
    env:
      AWS_REGION: ${{ vars.AWS_REGION }}
      BRANCH: ${{ github.event.workflow_run.head_branch }}
      # Pick env-specific mappings
      ROLE_ARN: ${{ github.event.workflow_run.head_branch == 'main' && vars.AWS_ROLE_TO_ASSUME_PROD || vars.AWS_ROLE_TO_ASSUME_STAGING }}
      ECR_REPO: ${{ github.event.workflow_run.head_branch == 'main' && vars.ECR_REPO_PROD || vars.ECR_REPO_STAGING }}
      ACCOUNT_ID: ${{ github.event.workflow_run.head_branch == 'main' && vars.AWS_ACCOUNT_ID_PROD || vars.AWS_ACCOUNT_ID_STAGING }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.workflow_run.head_sha }}

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Buildx
        uses: docker/setup-buildx-action@v3

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ env.ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to ECR
        id: ecr-login
        uses: aws-actions/amazon-ecr-login@v2

      - name: Extract Docker metadata (tags/labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: |
            ${{ env.ACCOUNT_ID }}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com/${{ env.ECR_REPO }}
          tags: |
            type=raw,value=${{ env.BRANCH }}
            type=raw,value=latest
            type=sha,format=long
            type=semver,pattern={{version}},value=${{ github.event.workflow_run.head_branch == 'main' && github.ref_name || '' }}
          labels: |
            org.opencontainers.image.source=${{ github.repository }}
            org.opencontainers.image.revision=${{ github.event.workflow_run.head_sha }}
            org.opencontainers.image.created=${{ github.event.workflow_run.created_at }}

      - name: Build & Push (linux/amd64)
        uses: docker/build-push-action@v6
        with:
          context: .
          file: ./docker/Dockerfile # <-- update if needed
          platforms: linux/amd64
          push: true
          provenance: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Output image tags
        run: |
          echo "Pushed tags:"
          echo "${{ steps.meta.outputs.tags }}"
```

### Notes

* **`workflow_run`**: This listens for completion of your “CI” workflow and filters to only run on `main`/`staging` if the CI **succeeded**.
* **OIDC**: `aws-actions/configure-aws-credentials@v4` exchanges short-lived credentials by assuming the per-account role.
* **Tagging**: we publish `latest`, the branch name, and the commit SHA. (Optionally include semver on release tags if you cut releases.)
* **Caching**: `cache-from/to: type=gha` makes builds much faster on your private runner.
* **Provenance**: `provenance: true` adds SLSA-style attestation metadata (supply chain best practice).

---

# 5) Optional: environment protections & promotion flow

* **Manual approval**: Put the job behind GitHub Environments `prod` with required reviewers.
* **Image promotion**: Instead of rebuilding for prod, you can **promote** the exact staging image by digest and retag it in the PROD account (pull-by-digest from staging → push to prod) to ensure bit-for-bit parity. This requires allowing cross-account pull (or using your CI to act as the copier). Many teams trigger this on a **release** event.

Example promotion step (in a `release` workflow):

```bash
# Given DIGEST=sha256:abc...
aws ecr batch-get-image \
  --repository-name myapp/backend-staging \
  --image-ids imageDigest=$DIGEST \
  --query 'images[0].imageManifest' \
  --output text > manifest.json

aws ecr put-image \
  --repository-name myapp/backend-prod \
  --image-tag "release-${GITHUB_REF_NAME}" \
  --image-manifest file://manifest.json
```

---

# 6) Extra hardening & niceties

* **ECR lifecycle policy** to prune old tags and `sha` images.
* **Image scanning** (ECR scan on push) + optionally fail the CD if critical vulns are found (separate gate).
* **Immutability** for `latest` can be off (teams differ); but you can enforce *no-overwrite* for immutable tags like `sha`/`release`.
* **SBOM**: generate with `syft` and upload as artifact; consider signing images with `cosign` (key-less OIDC).
* **Branch filters in IAM**: tighten the trust policy so only `refs/heads/main` can assume the PROD role and only `refs/heads/staging` can assume the STAGING role.
* **Matrix**: if you later add services, convert the job to a matrix over service folders → each builds & pushes its own image.

---

# 7) Quick checklist

* [ ] OIDC provider exists in each AWS account.
* [ ] `GitHubCDRole` (per account) with trust limited to your repo (and branch).
* [ ] ECR repos exist with scan on push & lifecycle policy.
* [ ] `ci.yml` passes on PR → `main`/`staging`.
* [ ] `cd.yml` (above) present and `workflows: ["CI"]` matches your CI workflow name.
* [ ] GitHub vars/secrets set for role ARNs, account IDs, repo names, region.
* [ ] (Optional) Environments `staging`/`prod` with approvals.

This setup gives you: credentials-free auth, strict separation per account, deterministic routing from branch → account, and a clean CI→CD handoff that only pushes on green builds.
