# CLAUDE.md

## AI collaboration guardrails

Applies to any Claude Code session working in this repo:

1. **Do not guess.** If a fact isn't verified against this repo's actual files, command output, or docs, say so instead of asserting it.
2. **Missing information → ask, don't assume.** Secrets, credentials, branch/environment state, and intent are the user's to provide — pause and ask rather than filling gaps.
3. **Only verified commands.** Every suggested command must be checked against this repo's actual scripts/workflows (real paths, real flags) — never invent an untested invocation.
4. **Label every suggested command** `[read-only]` or `[modifying]` so the blast radius is clear before it runs.
5. **Attach a confidence level** (High / Medium / Low) to non-trivial suggestions or diagnoses.
6. **Root-cause explanations are evidence-bound** — base them only on the logs/config the user actually shares, not on speculation about what "probably" happened.
7. **Commits**: always `git commit -s` (sign-off) using this repo's configured git identity — `bhumi46 <thisisbn46@gmail.com>` — never a Claude/Anthropic co-author trailer.
8. **Push only to `origin`** (the `bhumi46/infra` fork), **never `upstream`** (`mosip/infra`). Verify the target remote before every push — never push to, or open PRs against, `upstream` without the user explicitly asking.

---

MOSIP Rapid Deployment repo: **Terraform** provisions cloud infrastructure, **Helmsman** deploys MOSIP/eSignet services onto it via Helm-based Desired State Files (DSF). AWS is the only fully-implemented cloud; Azure/GCP Terraform modules are `null_resource` placeholders — no real cloud resources are created there yet.

## Repo map

- `terraform/` — IaC, see "Terraform architecture" below.
- `Helmsman/` — Helm deployment layer. `dsf/` holds Desired State Files per profile (`mosip-platform-1.2.0.x`, `mosip-platform-1.2.1.x`, `esignet-standalone`); `hooks/` and `utils/` hold supporting scripts/configs (istio, logging, monitoring).
- `Rancher-keycloak-integration/` — standalone Python automation (`automation_script.py`, `rancher_diagnostic.py`) wiring Keycloak as Rancher's SAML identity provider. Run once, after `observ-infra` is deployed and before MOSIP `infra` is deployed — only relevant if `observ-infra` is used.
- `.github/workflows/` — all CI, see "Workflows" below.
- `.github/scripts/` — bash helpers the terraform workflows call: `configure-backend.sh` (writes `backend.tf`), `setup-cloud-storage.sh` (remote backend bootstrap), `setup-gpg.sh`/`decrypt-state.sh`/`encrypt-state.sh` (GPG state lifecycle), `cleanup-state-locking.sh`, `rancher-register-cluster.sh`. `setup-s3-backend.sh` is dead code (0 bytes) — ignore it.
- `docs/` — extensive guides, `docs/README.md` is the index. Notable: `TERRAFORM_WORKFLOW_GUIDE.md`, `WORKFLOW_GUIDE.md`, `SECRET_GENERATION_GUIDE.md`, `DSF_CONFIGURATION_GUIDE.md`, `GLOSSARY.md`, `ENVIRONMENT_DESTRUCTION_GUIDE.md`, per-Helmsman-stage guides.

## Terraform architecture (4 layers, thinnest on top)

```
implementations/{cloud}/{component}/   → root module CI actually runs
  → terraform/{component}/main.tf      → cloud-agnostic switchboard (count-based)
    → terraform/{component}/{cloud}/   → cloud-specific composition
      → terraform/modules/{cloud}/*    → reusable building blocks
```

1. **`terraform/implementations/{cloud}/{component}/`** — the workflow's `working-directory`. Provider block + `{cloud}.tfvars` (or `profiles/<profile>/{cloud}.tfvars` for `infra`) + thin `main.tf` forwarding vars into layer 2.
2. **`terraform/{component}/main.tf`** (`base-infra` \| `infra` \| `observ-infra`) — picks the cloud submodule via `count = var.cloud_provider == "aws" ? 1 : 0`.
3. **`terraform/{component}/{cloud}/main.tf`** — the real cloud-specific composition.
4. **`terraform/modules/aws/*`** — `aws-resource-creation` (VPC/subnets/SGs/EC2/certbot SSL), `rke2-cluster` (+ `ansible/` playbooks), `nginx-setup`, `nfs-setup`, `postgresql-setup`, `activemq-setup`, `rancher-keycloak-setup`.

### Three components

| Component | Purpose | Lifecycle | State file |
|---|---|---|---|
| `base-infra` | VPC, jumpserver, WireGuard | deploy once, essentially never destroy | `{cloud}-base-infra-{branch}-terraform.tfstate` |
| `observ-infra` | Rancher + Keycloak management plane | optional, independent | `{cloud}-observ-infra-{branch}-terraform.tfstate` |
| `infra` | MOSIP/eSignet K8s cluster, external PostgreSQL, ActiveMQ | destroy/recreate freely | `profiles/<profile>/{cloud}-infra-<profile>-{branch}-terraform.tfstate` |

Deploy order: `base-infra` → (optional `observ-infra` → `keycloak-rancher-integration.yml`) → `infra`. `infra` takes an `INFRA_PROFILE`: `mosip` or `esignet-standalone`, each with its own `profiles/<profile>/{cloud}.tfvars`.

## Workflows (`.github/workflows/`)

**Terraform:**
- `terraform.yml` — plan always runs; `TERRAFORM_APPLY: true` gates apply. Inputs: `CLOUD_PROVIDER`, `TERRAFORM_COMPONENT`, `INFRA_PROFILE`, `BACKEND_TYPE` (local\|remote), `REMOTE_BACKEND_CONFIG`, `ENABLE_STATE_LOCKING`, `SSH_PRIVATE_KEY` (a **secret name**, not the key content — `TF_VAR_ssh_private_key: ${{ secrets[inputs.SSH_PRIVATE_KEY] }}`), `TERRAFORM_APPLY`, `ENABLE_RANCHER_IMPORT`, `RANCHER_CLUSTER_NAME`.
- `terraform-destroy.yml` — mirrors `terraform.yml`; `TERRAFORM_DESTROY: true` gates destroy. Default component dropdown is `infra`, not `base-infra` — base-infra destruction is intentionally more friction-full.
- Both skip the WireGuard/ufw setup steps only for `base-infra` (nothing to VPN into yet); every other component needs the runner on the WireGuard VPN to reach private nodes over SSH.
- State round-trips through git when `BACKEND_TYPE=local`: GPG-decrypt at job start, GPG-encrypt + `git commit`+push (rebase, falling back to `merge -X ours` on conflict) at job end.

**Helmsman** (sequential, after Terraform `infra` is up):
- `helmsman_external.yml` — prereqs (monitoring/Istio/logging) + external deps (PostgreSQL conn, MinIO, Keycloak, Kafka) in parallel. Always run in `apply` mode — `dry-run` fails because MOSIP services reference cross-namespace ConfigMaps/Secrets that don't exist yet.
- `helmsman_mosip.yml` — MOSIP core services, auto-triggered after external (MOSIP-platform profile only).
- `helmsman_esignet.yml` — eSignet stack; manual step after MOSIP platform, or the entry point for esignet-standalone. Also push-triggered on `Helmsman/dsf/esignet-dsf.yaml` changes.
- `helmsman_signup.yml`, `helmsman_testrigs.yml` — later pipeline stages.
- `helmsman_*_destroy*.yml` — safe teardown of Helmsman-deployed services without touching Terraform infra.
- `wg-onboard.yml` — WireGuard peer onboarding. `keycloak-rancher-integration.yml` — SAML wiring (needed once if `observ-infra` deployed). `k8s_health_check.yml` — cluster health checks.

Env vars (`DOMAIN_NAME`, `ENV_NAME`, `CLUSTER_ID`, `DB_PORT`, `ESIGNET_DB_PORT`, `SLACK_CHANNEL_NAME`) drive Helmsman DSF `${VAR}` substitution at deploy time via workflow inputs (or GitHub Environment Variables for push-triggered runs) — DSF YAML files are not hand-edited per environment, except `postgres.enabled` in `external-dsf.yaml` and `dbBranch` in `mosip-dsf.yaml`.

## State management

Default: **local backend + GPG encryption** — state `.gpg` files committed straight into git, branch-isolated, AES256, decrypted/re-encrypted each run (`GPG_PASSPHRASE` secret). Alternative: `BACKEND_TYPE=remote` → S3/AzureRM/GCS with optional DynamoDB locking (`configure-backend.sh` + `setup-cloud-storage.sh`).

## Gotchas learned so far

- `rancher_import_url` in tfvars needs double-escaped quotes — `"\"kubectl apply -f ...\""` — otherwise Terraform throws an indentation/parse error.
- `nginx_node_ebs_volume_size_2` must be set (>0) when `enable_postgresql_setup = true`; `_size_3` when `enable_activemq_setup = true`.
- `specific_availability_zones = []` is the recommended default — pinning specific AZs risks `InsufficientInstanceCapacity` errors on `t3a.2xlarge`.
- `cluster_name`/`cluster_env_domain` in tfvars must match `ENV_NAME`/`DOMAIN_NAME` GitHub Environment values — Helmsman substitution depends on the match.
- KUBECONFIG secret must be raw YAML, not base64.

## Where to look for more detail

- Root `README.md` — full onboarding/deploy walkthrough, canonical deploy order, secrets checklist.
- `terraform/README.md`, `docs/TERRAFORM_WORKFLOW_GUIDE.md` — Terraform deep dive.
- `.github/workflows/README.md` — workflow parameter reference + troubleshooting.
- `docs/HELMSMAN_*_GUIDE.md`, `docs/esignet_README.md`, `docs/DSF_CONFIGURATION_GUIDE.md` — per-Helmsman-stage guides.
