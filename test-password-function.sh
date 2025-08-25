#!/bin/bash

# Standalone PostgreSQL Password Update Function Tester
# Usage: ./test-password-function.sh
# 
# This script extracts and tests only the password update functionality
# without running the full PostgreSQL installation

set -euo pipefail

echo "🧪 PostgreSQL Password Function Tester"
echo "======================================"

# Mock required PostgreSQL environment variables for testing
export POSTGRESQL_PORT="${POSTGRESQL_PORT:-5432}"

# Test configuration - modify these as needed
export AUTO_UPDATE_PASSWORD="${AUTO_UPDATE_PASSWORD:-true}"
export GITHUB_REPO="${GITHUB_REPO:-bhumi46/infra}"  # Replace with your repo
export GITHUB_TOKEN="${GITHUB_TOKEN:-}"             # Set your GitHub token
export BRANCH="${BRANCH:-testgrid}"                 # Replace with your branch
export POSTGRES_SECRET_ACTION="${POSTGRES_SECRET_ACTION:-skip}"

echo "📋 Test Configuration:"
echo "  GITHUB_REPO: $GITHUB_REPO"
echo "  BRANCH: $BRANCH"
echo "  POSTGRES_SECRET_ACTION: $POSTGRES_SECRET_ACTION"
echo "  GITHUB_TOKEN: ${GITHUB_TOKEN:+[SET]}${GITHUB_TOKEN:-[MISSING]}"
echo ""

# Check if required tools are available
echo "🔧 Checking required tools..."
required_tools=("curl" "jq" "openssl" "python3")
missing_tools=()

for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        missing_tools+=("$tool")
    else
        echo "  ✅ $tool: $(command -v $tool)"
    fi
done

if [ ${#missing_tools[@]} -ne 0 ]; then
    echo "❌ Missing required tools:"
    printf '  - %s\n' "${missing_tools[@]}"
    echo ""
    echo "Please install missing tools first:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y ${missing_tools[*]}"
    exit 1
fi

# Check if PyNaCl is available
echo "  🐍 Checking Python cryptography library..."
if python3 -c "import nacl.public" 2>/dev/null; then
    echo "  ✅ PyNaCl: Available"
else
    echo "  ⚠️ PyNaCl: Not installed"
    echo "  Installing PyNaCl for encryption..."
    pip3 install --user pynacl
    if python3 -c "import nacl.public" 2>/dev/null; then
        echo "  ✅ PyNaCl: Installed successfully"
    else
        echo "  ❌ PyNaCl: Installation failed"
        exit 1
    fi
fi

echo ""

# Mock PostgreSQL functions for testing
mock_postgres_operations() {
    echo "🔧 Mock Mode: Simulating PostgreSQL operations..."
    
    # Simulate PostgreSQL password update
    echo "  [MOCK] Updating PostgreSQL password..."
    sleep 1
    echo "  [MOCK] ✅ PostgreSQL password updated successfully"
    
    # Simulate connection test
    echo "  [MOCK] Testing PostgreSQL connection..."
    sleep 1
    echo "  [MOCK] ✅ PostgreSQL connection test passed"
}

# ============================================================================
# EXTRACTED PASSWORD UPDATE FUNCTION (from postgresql-setup.sh)
# ============================================================================

update_postgres_password() {
    echo ""
    echo "=== [SECURITY] Automated PostgreSQL Password Update Started ==="
    
    # Use dynamic GitHub Actions environment variables
    local github_token="$GITHUB_TOKEN"
    local github_repository="$GITHUB_REPO"
    local branch_name="$BRANCH"
    
    # Validate required environment variables for password update
    if [ -z "$github_token" ] || [ -z "$github_repository" ] || [ -z "$branch_name" ]; then
        echo "WARNING: Missing required GitHub environment variables:"
        echo "  GITHUB_TOKEN: ${github_token:+[SET]}${github_token:-[MISSING]}"
        echo "  GITHUB_REPO: ${github_repository:-[MISSING]}"
        echo "  BRANCH: ${branch_name:-[MISSING]}"
        echo "Skipping automated password update. Manual password configuration required."
        return 0
    fi
    
    echo "[INFO] Starting secure password generation and update process..."
    echo "[INFO] Repository: $github_repository"
    echo "[INFO] Branch/Environment: $branch_name"
    
    # Step 1: Generate secure random password (16 characters)
    echo "[STEP 1/6] Generating secure random password..."
    local new_password
    new_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)
    
    if [ ${#new_password} -ne 16 ]; then
        echo "[ERROR] Password generation failed - invalid length"
        return 1
    fi
    
    echo "[SUCCESS] Secure password generated (16 characters)"
    echo "[DEBUG] Password (first 4 chars): ${new_password:0:4}****"
    
    # Step 2: Mock PostgreSQL operations (for testing)
    echo "[STEP 2/6] Updating PostgreSQL password..."
    mock_postgres_operations
    
    # Step 3: Mock connection test (for testing) 
    echo "[STEP 3/6] Testing PostgreSQL connection with new password..."
    echo "[SUCCESS] PostgreSQL connection test passed (MOCKED)"
    
    # Step 4: Get GitHub repository public key for encryption
    echo "[STEP 4/6] Retrieving GitHub public key for secure transmission..."
    
    local public_key_response
    public_key_response=$(curl -s \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$github_repository/actions/secrets/public-key")
    
    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to fetch GitHub public key"
        return 1
    fi
    
    local public_key
    local key_id
    public_key=$(echo "$public_key_response" | jq -r '.key' 2>/dev/null)
    key_id=$(echo "$public_key_response" | jq -r '.key_id' 2>/dev/null)
    
    if [ -z "$public_key" ] || [ "$public_key" = "null" ] || [ -z "$key_id" ] || [ "$key_id" = "null" ]; then
        echo "[ERROR] Failed to parse GitHub public key response"
        echo "[DEBUG] Response: $public_key_response"
        return 1
    fi
    
    echo "[SUCCESS] GitHub public key retrieved successfully"
    echo "[DEBUG] Key ID: $key_id"
    
    # Step 5: Encrypt password using libsodium-compatible method (Python)
    echo "[STEP 5/6] Encrypting password for secure transmission..."
    
    # Create temporary Python script for encryption
    local encrypt_script=$(mktemp)
    cat > "$encrypt_script" <<'ENCRYPT_EOF'
import sys
import base64
from nacl.public import PublicKey, SealedBox

def encrypt_secret(public_key_b64, secret_value):
    try:
        # Decode the public key
        public_key_bytes = base64.b64decode(public_key_b64)
        public_key = PublicKey(public_key_bytes)
        
        # Create a sealed box for encryption
        sealed_box = SealedBox(public_key)
        
        # Encrypt the secret
        encrypted = sealed_box.encrypt(secret_value.encode('utf-8'))
        
        # Return base64 encoded encrypted value
        return base64.b64encode(encrypted).decode('utf-8')
    except Exception as e:
        print(f"Encryption error: {e}", file=sys.stderr)
        return None

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 encrypt.py <public_key_b64> <secret_value>", file=sys.stderr)
        sys.exit(1)
    
    public_key_b64 = sys.argv[1]
    secret_value = sys.argv[2]
    
    encrypted_value = encrypt_secret(public_key_b64, secret_value)
    if encrypted_value:
        print(encrypted_value)
    else:
        sys.exit(1)
ENCRYPT_EOF
    
    # Encrypt the password
    local encrypted_password
    encrypted_password=$(python3 "$encrypt_script" "$public_key" "$new_password" 2>/dev/null)
    
    # Clean up encryption script
    rm -f "$encrypt_script"
    
    if [ -z "$encrypted_password" ]; then
        echo "[ERROR] Failed to encrypt password"
        return 1
    fi
    
    echo "[SUCCESS] Password encrypted for secure transmission"
    echo "[DEBUG] Encrypted length: ${#encrypted_password} characters"
    
    # Step 6: Update GitHub environment secret
    echo "[STEP 6/6] Updating GitHub environment secret for branch '$branch_name'..."
    
    # Get environment info
    local env_response
    env_response=$(curl -s \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$github_repository/environments")
    
    local environment_id
    environment_id=$(echo "$env_response" | jq -r ".environments[] | select(.name==\"$branch_name\") | .id" 2>/dev/null)
    
    local secret_name="POSTGRES_PASSWORD"
    local secret_exists=false
    local existing_secret_name=""
    
    if [ -z "$environment_id" ] || [ "$environment_id" = "null" ]; then
        echo "[INFO] Environment '$branch_name' not found, checking for repository secret with branch suffix"
        secret_name="POSTGRES_PASSWORD_${branch_name//-/_}" # Replace hyphens with underscores for secret name
        
        # Check if repository secret already exists
        local secret_check_response
        secret_check_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$github_repository/actions/secrets/$secret_name")
        
        if [ "$secret_check_response" = "200" ]; then
            secret_exists=true
            existing_secret_name="$secret_name (repository secret)"
        fi
        
        # Handle existing secret based on POSTGRES_SECRET_ACTION
        local secret_action="${POSTGRES_SECRET_ACTION:-skip}"  # Default: skip for non-interactive behavior
        
        if [ "$secret_exists" = true ]; then
            case "$secret_action" in
                "skip"|*)
                    echo "[INFO] Repository secret '$secret_name' already exists - SKIPPING update (POSTGRES_SECRET_ACTION=skip)"
                    echo "[SUCCESS] PostgreSQL password update completed (no changes made to existing secret)"
                    return 0
                    ;;
                "fail")
                    echo "[ERROR] Repository secret '$secret_name' already exists - FAILING as requested (POSTGRES_SECRET_ACTION=fail)"
                    echo "[INFO] To update existing secret, set POSTGRES_SECRET_ACTION=update or POSTGRES_SECRET_ACTION=skip"
                    return 1
                    ;;
                "update")
                    echo "[INFO] Repository secret '$secret_name' already exists - UPDATING with new password (POSTGRES_SECRET_ACTION=update)"
                    ;;
            esac
        fi
        
        # Create/Update repository secret
        local update_response
        update_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -X PUT \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            "https://api.github.com/repos/$github_repository/actions/secrets/$secret_name" \
            -d "{\"encrypted_value\":\"$encrypted_password\",\"key_id\":\"$key_id\"}")
        
        local http_code="${update_response}"
        if [[ "$http_code" =~ ^(201|204)$ ]]; then
            if [ "$secret_exists" = true ]; then
                echo "[SUCCESS] Repository secret '$secret_name' UPDATED successfully"
            else
                echo "[SUCCESS] Repository secret '$secret_name' CREATED successfully"
            fi
        else
            echo "[ERROR] Failed to update repository secret (HTTP: $http_code)"
            return 1
        fi
    else
        echo "[INFO] Found environment '$branch_name' (ID: $environment_id)"
        
        # Check if environment secret already exists
        local env_secret_check_response
        env_secret_check_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$github_repository/environments/$environment_id/secrets/$secret_name")
        
        if [ "$env_secret_check_response" = "200" ]; then
            secret_exists=true
            existing_secret_name="$secret_name (environment secret)"
        fi
        
        # Handle existing secret based on POSTGRES_SECRET_ACTION
        local secret_action="${POSTGRES_SECRET_ACTION:-skip}"  # Default: skip for non-interactive behavior
        
        if [ "$secret_exists" = true ]; then
            case "$secret_action" in
                "skip"|*)
                    echo "[INFO] Environment secret '$secret_name' already exists - SKIPPING update (POSTGRES_SECRET_ACTION=skip)"
                    echo "[SUCCESS] PostgreSQL password update completed (no changes made to existing secret)"
                    return 0
                    ;;
                "fail")
                    echo "[ERROR] Environment secret '$secret_name' already exists - FAILING as requested (POSTGRES_SECRET_ACTION=fail)"
                    echo "[INFO] To update existing secret, set POSTGRES_SECRET_ACTION=update or POSTGRES_SECRET_ACTION=skip"
                    return 1
                    ;;
                "update")
                    echo "[INFO] Environment secret '$secret_name' already exists - UPDATING with new password (POSTGRES_SECRET_ACTION=update)"
                    ;;
            esac
        fi
        
        # Create/Update environment secret
        local update_response
        update_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -X PUT \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            "https://api.github.com/repos/$github_repository/environments/$environment_id/secrets/$secret_name" \
            -d "{\"encrypted_value\":\"$encrypted_password\",\"key_id\":\"$key_id\"}")
        
        local http_code="${update_response}"
        if [[ "$http_code" =~ ^(201|204)$ ]]; then
            if [ "$secret_exists" = true ]; then
                echo "[SUCCESS] Environment secret '$secret_name' UPDATED for environment '$branch_name'"
            else
                echo "[SUCCESS] Environment secret '$secret_name' CREATED for environment '$branch_name'"
            fi
        else
            echo "[ERROR] Failed to update environment secret (HTTP: $http_code)"
            return 1
        fi
    fi
    
    # Step 7: Final security cleanup
    echo "[STEP 7/7] Security cleanup..."
    
    # Clear sensitive variables from memory
    new_password=""
    encrypted_password=""
    unset new_password
    unset encrypted_password
    
    # Clear bash history of this session (if possible)
    history -c 2>/dev/null || true
    
    echo "[SUCCESS] PostgreSQL password update completed successfully"
    echo "[SECURITY] All sensitive data cleared from memory"
    echo "[INFO] Secret name: $secret_name"
    echo "=== [SECURITY] Automated PostgreSQL Password Update Completed ==="
    echo ""
}

# ============================================================================
# TEST EXECUTION
# ============================================================================

echo "🚀 Starting password function test..."
echo ""

# Validate GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ ERROR: GITHUB_TOKEN environment variable is required"
    echo ""
    echo "Please set your GitHub token:"
    echo "  export GITHUB_TOKEN='ghp_your_token_here'"
    echo ""
    echo "To create a GitHub token:"
    echo "  1. Go to GitHub Settings > Developer settings > Personal access tokens"
    echo "  2. Generate new token (classic)"
    echo "  3. Select scopes: 'repo' and 'admin:repo_hook'"
    echo ""
    exit 1
fi

# Run the test
if update_postgres_password; then
    echo "✅ Password function test PASSED"
    echo ""
    echo "🎯 Test Results:"
    echo "  - Password generation: ✅ Success"
    echo "  - GitHub API access: ✅ Success" 
    echo "  - Encryption: ✅ Success"
    echo "  - Secret management: ✅ Success"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Check GitHub repository secrets/environment secrets"
    echo "  2. Verify the secret was created/updated as expected"
    echo "  3. Test with different POSTGRES_SECRET_ACTION values:"
    echo "     export POSTGRES_SECRET_ACTION=update"
    echo "     export POSTGRES_SECRET_ACTION=fail"
else
    echo "❌ Password function test FAILED"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "  1. Check GitHub token permissions"
    echo "  2. Verify repository name is correct"
    echo "  3. Check if environment exists for the branch"
    echo "  4. Review error messages above"
fi

echo ""
echo "🧪 Test completed at $(date)"
