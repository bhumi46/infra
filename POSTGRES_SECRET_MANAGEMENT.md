# PostgreSQL Secret Management - Handling Existing Secrets

## Overview

The PostgreSQL password update system now intelligently handles existing secrets with three configurable behaviors.

## Secret Detection

### Environment Secrets
- **Location**: GitHub Environment secrets for specific branch
- **Name**: `POSTGRES_PASSWORD`
- **Check**: GET `/repos/{owner}/{repo}/environments/{environment_id}/secrets/POSTGRES_PASSWORD`

### Repository Secrets (Fallback)
- **Location**: GitHub Repository secrets
- **Name**: `POSTGRES_PASSWORD_{branch_name}` (hyphens converted to underscores)
- **Example**: `POSTGRES_PASSWORD_develop`, `POSTGRES_PASSWORD_feature_auth`
- **Check**: GET `/repos/{owner}/{repo}/actions/secrets/POSTGRES_PASSWORD_{branch_name}`

## Behavior Control: POSTGRES_SECRET_ACTION

### 1. `skip` (Default - Non-Interactive)
```bash
POSTGRES_SECRET_ACTION=skip  # Default behavior
```
**Behavior:**
- If secret exists: Skips update, keeps existing password
- If secret doesn't exist: Creates new secret
- **Status**: Always succeeds (preserves existing)
- **Use Case**: Non-interactive deployments, avoid changing working passwords

**Output Examples:**
```
[INFO] Repository secret 'POSTGRES_PASSWORD_develop' already exists - SKIPPING update
[SUCCESS] PostgreSQL password update completed (no changes made to existing secret)
```

### 2. `update`
```bash
POSTGRES_SECRET_ACTION=update
```
**Behavior:**
- If secret exists: Updates with new password
- If secret doesn't exist: Creates new secret
- **Status**: Always succeeds (idempotent)
- **Use Case**: Force password rotation and updates

**Output Examples:**
```
[INFO] Repository secret 'POSTGRES_PASSWORD_develop' already exists - UPDATING with new password
[SUCCESS] Repository secret 'POSTGRES_PASSWORD_develop' UPDATED successfully
```

### 3. `fail`
```bash
POSTGRES_SECRET_ACTION=fail
```
**Behavior:**
- If secret exists: Fails with error
- If secret doesn't exist: Creates new secret
- **Status**: Fails if secret exists
- **Use Case**: Strict environments where duplicate secrets indicate errors

**Output Examples:**
```
[ERROR] Repository secret 'POSTGRES_PASSWORD_develop' already exists - FAILING as requested
[INFO] To update existing secret, set POSTGRES_SECRET_ACTION=update or POSTGRES_SECRET_ACTION=skip
```

## Implementation in GitHub Actions

### Terraform Workflow (terraform.yml)
```yaml
env:
  AUTO_UPDATE_PASSWORD: "true"
  GITHUB_REPO: ${{ github.repository }}
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  BRANCH: ${{ github.ref_name }}
  POSTGRES_SECRET_ACTION: "skip"  # Default: non-interactive, skip if exists
```

### Custom Workflows
```yaml
- name: Deploy with password rotation (force update)
  env:
    POSTGRES_SECRET_ACTION: "update"  # Force new password generation
  run: ./postgresql-setup.sh

- name: Deploy with existing secret protection (default)
  env:
    POSTGRES_SECRET_ACTION: "skip"   # Default: keep existing passwords
  run: ./postgresql-setup.sh

- name: Deploy with strict checking
  env:
    POSTGRES_SECRET_ACTION: "fail"  # Fail if secrets already exist
  run: ./postgresql-setup.sh
```

## Security Considerations

### Password Rotation
- **update**: Generates new password each time (good for security)
- **skip**: Preserves existing password (good for stability)
- **fail**: Prevents accidental overwrites (good for strict compliance)

### Branch Isolation
Each branch gets its own secret namespace:
- `main` branch → `POSTGRES_PASSWORD_main`
- `develop` branch → `POSTGRES_PASSWORD_develop`
- `feature/auth` branch → `POSTGRES_PASSWORD_feature_auth`

### Encryption
All secrets use GitHub's public key encryption:
- PyNaCl (libsodium) compatible encryption
- Same encryption as GitHub UI
- Base64 encoded for transmission

## Common Scenarios

### 1. First Deployment
```
Branch: develop
Existing Secret: None
Action: update
Result: Creates POSTGRES_PASSWORD_develop
```

### 2. Re-deployment (Normal)
```
Branch: develop
Existing Secret: POSTGRES_PASSWORD_develop
Action: update (default)
Result: Updates secret with new password
```

### 3. Re-deployment (Preserve Password)
```
Branch: develop
Existing Secret: POSTGRES_PASSWORD_develop
Action: skip
Result: Keeps existing password, skips update
```

### 4. Strict Deployment
```
Branch: develop
Existing Secret: POSTGRES_PASSWORD_develop
Action: fail
Result: Fails deployment (error condition)
```

## Troubleshooting

### Secret Already Exists Error
```bash
# Problem: Secret exists and POSTGRES_SECRET_ACTION=fail
# Solution: Change action or remove secret

# Option 1: Allow updates
export POSTGRES_SECRET_ACTION=update

# Option 2: Skip if exists
export POSTGRES_SECRET_ACTION=skip

# Option 3: Manual secret removal (if needed)
# Use GitHub UI or API to remove secret first
```

### Environment vs Repository Secrets
```bash
# Environment secrets take precedence
# If environment "develop" exists:
#   - Checks: /environments/{env_id}/secrets/POSTGRES_PASSWORD
# If environment doesn't exist:
#   - Falls back to: /actions/secrets/POSTGRES_PASSWORD_develop
```

## Best Practices

1. **Default Behavior**: Use `skip` for non-interactive, safe deployments (DEFAULT)
2. **Password Rotation**: Use `update` explicitly when you need to rotate passwords
3. **First-Time Setup**: `skip` works perfectly - creates new secrets, preserves existing ones
4. **CI/CD Pipelines**: `skip` prevents accidental password changes that could break services
5. **Strict Environments**: Use `fail` where duplicate secrets indicate configuration errors
6. **Branch Strategy**: Each branch should have isolated secrets
7. **Manual Rotation**: Use `update` periodically for security when needed

This system provides flexible, secure, and intelligent handling of existing PostgreSQL secrets across all deployment scenarios.
