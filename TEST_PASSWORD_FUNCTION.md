# PostgreSQL Password Function Testing Guide

## 🧪 How to Test the Password Function

### Quick Test (5 minutes)

1. **Set your GitHub token:**
   ```bash
   export GITHUB_TOKEN="ghp_your_token_here"
   ```

2. **Run the test:**
   ```bash
   ./test-password-function.sh
   ```

### Advanced Testing

#### Test Different Behaviors:

1. **Default (Skip existing secrets):**
   ```bash
   export POSTGRES_SECRET_ACTION="skip"
   ./test-password-function.sh
   ```

2. **Force update existing secrets:**
   ```bash
   export POSTGRES_SECRET_ACTION="update"
   ./test-password-function.sh
   ```

3. **Fail if secrets exist:**
   ```bash
   export POSTGRES_SECRET_ACTION="fail"
   ./test-password-function.sh
   ```

#### Test Different Repositories/Branches:

```bash
export GITHUB_REPO="your-username/your-repo"
export BRANCH="your-branch-name"
./test-password-function.sh
```

## 🔍 What the Test Does

### ✅ Validates:
- GitHub token permissions
- Required tools (curl, jq, openssl, python3, PyNaCl)
- Password generation (16-character secure passwords)
- GitHub API connectivity
- Encryption using GitHub's public key
- Secret creation/update logic
- Environment vs repository secret detection

### 🔧 Mocked Operations:
- PostgreSQL password update (simulated)
- PostgreSQL connection test (simulated)

### 🎯 Real Operations:
- GitHub API calls
- Secret encryption
- Secret creation/update in GitHub

## 📋 Expected Output

### Successful Test:
```
🧪 PostgreSQL Password Function Tester
======================================
📋 Test Configuration:
  GITHUB_REPO: bhumi46/infra
  BRANCH: testgrid
  POSTGRES_SECRET_ACTION: skip
  GITHUB_TOKEN: [SET]

🔧 Checking required tools...
  ✅ curl: /usr/bin/curl
  ✅ jq: /usr/bin/jq
  ✅ openssl: /usr/bin/openssl
  ✅ python3: /usr/bin/python3
  🐍 Checking Python cryptography library...
  ✅ PyNaCl: Available

🚀 Starting password function test...

=== [SECURITY] Automated PostgreSQL Password Update Started ===
[INFO] Starting secure password generation and update process...
[INFO] Repository: bhumi46/infra
[INFO] Branch/Environment: testgrid
[STEP 1/6] Generating secure random password...
[SUCCESS] Secure password generated (16 characters)
[DEBUG] Password (first 4 chars): Xy9Z****
[STEP 2/6] Updating PostgreSQL password...
🔧 Mock Mode: Simulating PostgreSQL operations...
  [MOCK] Updating PostgreSQL password...
  [MOCK] ✅ PostgreSQL password updated successfully
[STEP 3/6] Testing PostgreSQL connection with new password...
[SUCCESS] PostgreSQL connection test passed (MOCKED)
[STEP 4/6] Retrieving GitHub public key for secure transmission...
[SUCCESS] GitHub public key retrieved successfully
[DEBUG] Key ID: 568250167242549743
[STEP 5/6] Encrypting password for secure transmission...
[SUCCESS] Password encrypted for secure transmission
[DEBUG] Encrypted length: 124 characters
[STEP 6/6] Updating GitHub environment secret for branch 'testgrid'...
[INFO] Environment 'testgrid' not found, checking for repository secret with branch suffix
[SUCCESS] Repository secret 'POSTGRES_PASSWORD_testgrid' CREATED successfully
[STEP 7/7] Security cleanup...
[SUCCESS] PostgreSQL password update completed successfully
[SECURITY] All sensitive data cleared from memory
[INFO] Secret name: POSTGRES_PASSWORD_testgrid
=== [SECURITY] Automated PostgreSQL Password Update Completed ===

✅ Password function test PASSED

🎯 Test Results:
  - Password generation: ✅ Success
  - GitHub API access: ✅ Success
  - Encryption: ✅ Success
  - Secret management: ✅ Success

🔧 Next Steps:
  1. Check GitHub repository secrets/environment secrets
  2. Verify the secret was created/updated as expected
  3. Test with different POSTGRES_SECRET_ACTION values
```

## 🛠️ Troubleshooting

### Missing GitHub Token:
```bash
❌ ERROR: GITHUB_TOKEN environment variable is required

Please set your GitHub token:
  export GITHUB_TOKEN='ghp_your_token_here'
```

### Missing Tools:
```bash
❌ Missing required tools:
  - jq
  - python3

Please install missing tools first:
  sudo apt-get update
  sudo apt-get install -y jq python3
```

### GitHub API Errors:
- **401 Unauthorized**: Invalid or expired GitHub token
- **403 Forbidden**: Insufficient token permissions
- **404 Not Found**: Repository doesn't exist or no access

### Token Permissions Required:
- `repo` (Full repository access)
- `admin:repo_hook` (Repository webhooks and services)

## 🎯 Real-World Integration

Once testing passes, the function will work automatically in:
- Terraform deployments via `terraform.yml` workflow
- Manual PostgreSQL installations via `postgresql-setup.sh`
- Custom deployment scripts

The test ensures everything works before actual deployment! 🚀
