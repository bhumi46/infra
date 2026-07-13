---
name: terraform-workflow
description: Use when working on this repo's terraform/ infrastructure code or its GitHub Actions workflows (terraform.yml, terraform-destroy.yml) — validating a component's Terraform locally before pushing, constructing a correct `gh workflow run` dispatch for plan/apply/destroy, watching a run, or decrypting a GPG-encrypted local-backend state file for debugging. Triggers on "terraform plan", "terraform apply", "run the terraform workflow", "trigger terraform", "decrypt state", "check tfvars", "base-infra/infra/observ-infra deploy".
---

Real applies/destroys in this repo only happen inside GitHub Actions (they need AWS creds, the WireGuard VPN, and GPG secrets that live in GitHub, not locally). Locally you can validate syntax and dispatch/watch workflow runs. See `CLAUDE.md` at repo root for the full architecture map before using this.

## 1. Local validation before pushing

Run from `terraform/implementations/{cloud}/{component}/` (e.g. `terraform/implementations/aws/infra/`). No AWS credentials needed since `-backend=false` skips remote state:

```bash
cd terraform/implementations/<cloud>/<component>
terraform fmt -recursive -check   # matches the workflow's `terraform fmt -recursive` step
terraform init -backend=false -input=false
terraform validate -no-color
```

If it's the `infra` component with a profile, tfvars live at `profiles/<profile>/<cloud>.tfvars` — pass `-var-file` if you want a real plan-shape check (still won't produce a valid plan without a backend/credentials, but catches variable-reference errors).

## 2. tfvars pre-flight checklist

Before pushing a tfvars change, check the gotchas in `CLAUDE.md` — most common mistakes:
- `enable_postgresql_setup = true` requires `nginx_node_ebs_volume_size_2 > 0`
- `enable_activemq_setup = true` requires `nginx_node_ebs_volume_size_3 > 0`
- `rancher_import_url` must be double-quote-escaped: `"\"kubectl apply -f ...\""`
- `specific_availability_zones` should usually be `[]`
- `cluster_name` / `cluster_env_domain` must match the `ENV_NAME` / `DOMAIN_NAME` GitHub Environment variables for that branch

## 3. Dispatching a workflow run

Find the repo slug first (`gh repo view --json nameWithOwner`) since origin may be `mosip/infra` or a fork. Then dispatch with explicit `-f` for every input — omitting one silently falls back to the workflow's declared default, which is easy to get wrong for a two-input dependency like component+profile:

```bash
gh workflow run terraform.yml \
  --ref <branch> \
  -f CLOUD_PROVIDER=aws \
  -f TERRAFORM_COMPONENT=infra \
  -f INFRA_PROFILE=mosip \
  -f BACKEND_TYPE=local \
  -f SSH_PRIVATE_KEY=<github-secret-name> \
  -f TERRAFORM_APPLY=false   # false = plan only, always do this first
```

For destroy, same shape against `terraform-destroy.yml` with `TERRAFORM_DESTROY=true` instead of `TERRAFORM_APPLY` — confirm with the user before setting this true, it's a real-resource-destroying action.

`SSH_PRIVATE_KEY` is a **secret name string** (e.g. `mosip-aws`), not the key contents — the workflow does `secrets[inputs.SSH_PRIVATE_KEY]` to look it up.

## 4. Watching a run

```bash
gh run list --workflow=terraform.yml --branch <branch> --limit 5
gh run watch <run-id>
gh run view <run-id> --log-failed     # fastest way to find the failing step's output
```

## 5. Decrypting local-backend state for debugging

State files live at e.g. `terraform/implementations/aws/infra/profiles/mosip/aws-infra-mosip-<branch>-terraform.tfstate.gpg`. If you have the `GPG_PASSPHRASE`, decrypt with the same script CI uses (run from the component directory, so `backend.tf`'s relative path resolves):

```bash
cd terraform/implementations/<cloud>/<component>
../../../../.github/scripts/decrypt-state.sh --backend-type local --passphrase "$GPG_PASSPHRASE"
# inspect the resulting .tfstate, then re-encrypt before committing anything back:
../../../../.github/scripts/encrypt-state.sh --backend-type local --passphrase "$GPG_PASSPHRASE" --operation apply
```

Never commit a decrypted `.tfstate` file — only the `.gpg` should ever be pushed. Check `git status` before staging anything after this.
