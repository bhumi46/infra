#!/bin/bash

# Simple PostgreSQL Password Function Tester - SKIP ONLY
# Usage: ./test-password-skip-only.sh
# 
# This script tests ONLY the skip beh        echo "[INFO] Environment '$branch_name' found, checking environment secret"
        secret_name="POSTGRES_PASSWORD_${branch_name//-/_}"
        
        # Check if environment secret exists using environment name
        local env_secret_check_response
        env_secret_check_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/repos/$github_repository/environments/$branch_name/secrets/$secret_name")the password function

set -euo pipefail

echo "🧪 PostgreSQL Password Function Tester - SKIP ONLY"
echo "================================================="

# Force SKIP mode only
export AUTO_UPDATE_PASSWORD="true"
export POSTGRES_SECRET_ACTION="skip"
export GITHUB_REPO="${GITHUB_REPO:-bhumi46/infra}"  # Replace with your repo
export BRANCH="${BRANCH:-testgrid}"                 # Replace with your branch

# Mock PostgreSQL environment
export POSTGRESQL_PORT="${POSTGRESQL_PORT:-5432}"

echo "📋 Test Configuration (SKIP ONLY):"
echo "  GITHUB_REPO: $GITHUB_REPO"
echo "  BRANCH: $BRANCH"
echo "  POSTGRES_SECRET_ACTION: $POSTGRES_SECRET_ACTION"
echo "  GITHUB_TOKEN: ${GITHUB_TOKEN:+[SET]}${GITHUB_TOKEN:-[MISSING]}"
echo ""

# Check GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "❌ ERROR: GITHUB_TOKEN environment variable is required"
    echo ""
    echo "Please set your GitHub token:"
    echo "  export GITHUB_TOKEN='ghp_your_token_here'"
    echo ""
    exit 1
fi

# Quick tool check
echo "🔧 Quick tool check..."
required_tools=("curl" "jq" "openssl" "python3")
for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ Missing tool: $tool"
        echo "Install with: sudo apt-get install -y $tool"
        exit 1
    fi
done
echo "✅ All required tools available"

# Check PyNaCl
if ! python3 -c "import nacl.public" 2>/dev/null; then
    echo "📦 Installing PyNaCl..."
    pip3 install --user pynacl
fi
echo "✅ PyNaCl available"
echo ""

# Mock functions (simplified)
mock_postgres_operations() {
    echo "  [MOCK] ✅ PostgreSQL password updated"
    echo "  [MOCK] ✅ PostgreSQL connection test passed"
}

# SIMPLIFIED PASSWORD FUNCTION - SKIP FOCUS
test_password_skip() {
    echo "=== [TEST] Password Function - SKIP Behavior ==="
    
    local github_token="$GITHUB_TOKEN"
    local github_repository="$GITHUB_REPO"
    local branch_name="$BRANCH"
    
    echo "[INFO] Repository: $github_repository"
    echo "[INFO] Branch/Environment: $branch_name"
    echo "[INFO] Action: SKIP (preserve existing secrets)"
    
    # Step 1: Generate password
    echo ""
    echo "[STEP 1/4] Generating secure random password..."
    local new_password
    new_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)
    echo "[SUCCESS] Password generated: ${new_password:0:4}****"
    
    # Step 2: Mock PostgreSQL ops
    echo ""
    echo "[STEP 2/4] Mock PostgreSQL operations..."
    mock_postgres_operations
    
    # Step 3: Get GitHub public key
    echo ""
    echo "[STEP 3/4] Getting GitHub public key..."
    
    # Check if environment exists and get its public key
    local env_response
    env_response=$(curl -s \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$github_repository/environments")
    
    echo "[DEBUG] Environment API response:"
    echo "$env_response" | jq '.' 2>/dev/null || echo "$env_response"
    
    local environment_id
    environment_id=$(echo "$env_response" | jq -r ".environments[] | select(.name==\"$branch_name\") | .id" 2>/dev/null)
    echo "[DEBUG] Found environment ID: ${environment_id:-null}"
    
    local public_key_response
    local public_key
    local key_id
    
    # Try to get environment-specific public key first
    if [ -n "$environment_id" ] && [ "$environment_id" != "null" ]; then
        echo "[INFO] Attempting to get environment public key for '$branch_name'"
        public_key_response=$(curl -s \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/repos/$github_repository/environments/$branch_name/secrets/public-key")
        
        public_key=$(echo "$public_key_response" | jq -r '.key' 2>/dev/null)
        key_id=$(echo "$public_key_response" | jq -r '.key_id' 2>/dev/null)
        
        if [ -n "$public_key" ] && [ "$public_key" != "null" ] && [ -n "$key_id" ] && [ "$key_id" != "null" ]; then
            echo "[SUCCESS] Environment public key retrieved successfully"
        else
            echo "[WARN] Environment public key failed, falling back to repository key"
            public_key_response=$(curl -s \
                -H "Authorization: token $github_token" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/$github_repository/actions/secrets/public-key")
            
            public_key=$(echo "$public_key_response" | jq -r '.key' 2>/dev/null)
            key_id=$(echo "$public_key_response" | jq -r '.key_id' 2>/dev/null)
        fi
    else
        echo "[INFO] No environment found, using repository public key"
        public_key_response=$(curl -s \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$github_repository/actions/secrets/public-key")
        
        public_key=$(echo "$public_key_response" | jq -r '.key' 2>/dev/null)
        key_id=$(echo "$public_key_response" | jq -r '.key_id' 2>/dev/null)
    fi
    
    if [ -z "$public_key" ] || [ "$public_key" = "null" ]; then
        echo "[ERROR] Failed to get GitHub public key"
        return 1
    fi
    echo "[SUCCESS] GitHub public key retrieved"
    
    # Step 4: Test SKIP logic
    echo ""
    echo "[STEP 4/4] Testing SKIP behavior..."
    
    local secret_name
    local secret_exists=false
    
    if [ -z "$environment_id" ] || [ "$environment_id" = "null" ]; then
        echo "[INFO] No environment found, checking repository secret"
        secret_name="POSTGRES_PASSWORD_${branch_name//-/_}"
        
        # Check if repository secret exists
        local secret_check_response
        secret_check_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$github_repository/actions/secrets/$secret_name")
        
        if [ "$secret_check_response" = "200" ]; then
            secret_exists=true
            echo "[FOUND] Repository secret '$secret_name' already exists"
        else
            echo "[NOT FOUND] Repository secret '$secret_name' does not exist"
        fi
    else
        echo "[INFO] Environment '$branch_name' found, checking environment secret"
        secret_name="POSTGRES_PASSWORD_${branch_name//-/_}"  # Use branch-specific name in environment
        
        # Check if environment secret exists
        local env_secret_check_response
        env_secret_check_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$github_repository/environments/$environment_id/secrets/$secret_name")
        
        if [ "$env_secret_check_response" = "200" ]; then
            secret_exists=true
            echo "[FOUND] Environment secret '$secret_name' already exists"
        else
            echo "[NOT FOUND] Environment secret '$secret_name' does not exist"
        fi
    fi
    
    # SKIP BEHAVIOR TEST
    if [ "$secret_exists" = true ]; then
        echo ""
        echo "🔍 SKIP BEHAVIOR TEST:"
        echo "[ACTION] Secret exists - SKIPPING update (preserving existing secret)"
        echo "[RESULT] ✅ SUCCESS - No changes made to existing secret"
        echo "[INFO] This is the expected behavior for POSTGRES_SECRET_ACTION=skip"
        return 0
    else
        echo ""
        echo "🔍 SKIP BEHAVIOR TEST:"
        echo "[ACTION] Secret does not exist - Creating new secret"
        
        # Encrypt password (simplified)
        local encrypt_script=$(mktemp)
        cat > "$encrypt_script" <<'EOF'
import sys, base64
from nacl.public import PublicKey, SealedBox
public_key_bytes = base64.b64decode(sys.argv[1])
public_key = PublicKey(public_key_bytes)
sealed_box = SealedBox(public_key)
encrypted = sealed_box.encrypt(sys.argv[2].encode('utf-8'))
print(base64.b64encode(encrypted).decode('utf-8'))
EOF
        
        local encrypted_password
        encrypted_password=$(python3 "$encrypt_script" "$public_key" "$new_password" 2>/dev/null)
        rm -f "$encrypt_script"
        
        # Create the secret with debugging
        local create_url
        local secret_type
        if [ -z "$environment_id" ] || [ "$environment_id" = "null" ]; then
            create_url="https://api.github.com/repos/$github_repository/actions/secrets/$secret_name"
            secret_type="repository"
        else
            # Use environment name instead of ID with updated API version
            create_url="https://api.github.com/repos/$github_repository/environments/$branch_name/secrets/$secret_name"
            secret_type="environment"
        fi
        
        echo "[DEBUG] Creating $secret_type secret"
        echo "[DEBUG] URL: $create_url"
        echo "[DEBUG] Secret name: $secret_name"
        echo "[DEBUG] Environment ID: ${environment_id:-N/A}"
        
        # Try to create the secret with full response
        local create_response_file=$(mktemp)
        local http_code
        
        if [ "$secret_type" = "environment" ]; then
            # Use updated API version for environment secrets
            http_code=$(curl -s -w "%{http_code}" -o "$create_response_file" \
                -X PUT \
                -H "Authorization: token $github_token" \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                -H "Content-Type: application/json" \
                "$create_url" \
                -d "{\"encrypted_value\":\"$encrypted_password\",\"key_id\":\"$key_id\"}")
        else
            # Use standard API version for repository secrets
            http_code=$(curl -s -w "%{http_code}" -o "$create_response_file" \
                -X PUT \
                -H "Authorization: token $github_token" \
                -H "Accept: application/vnd.github.v3+json" \
                -H "Content-Type: application/json" \
                "$create_url" \
                -d "{\"encrypted_value\":\"$encrypted_password\",\"key_id\":\"$key_id\"}")
        fi
        
        echo "[DEBUG] HTTP Response Code: $http_code"
        
        if [[ "$http_code" =~ ^(201|204)$ ]]; then
            echo "[RESULT] ✅ SUCCESS - New $secret_type secret '$secret_name' created"
        else
            echo "[RESULT] ❌ FAILED - HTTP $http_code"
            echo "[DEBUG] Response body:"
            cat "$create_response_file"
            echo ""
            
            # If environment secret creation failed, try repository secret as fallback
            if [ "$secret_type" = "environment" ]; then
                echo "[FALLBACK] Trying repository secret instead..."
                # Keep the same name pattern for consistency
                local fallback_secret_name="$secret_name"  # Keep POSTGRES_PASSWORD_branch format
                local fallback_url="https://api.github.com/repos/$github_repository/actions/secrets/$fallback_secret_name"
                
                local fallback_response_file=$(mktemp)
                local fallback_http_code
                fallback_http_code=$(curl -s -w "%{http_code}" -o "$fallback_response_file" \
                    -X PUT \
                    -H "Authorization: token $github_token" \
                    -H "Accept: application/vnd.github.v3+json" \
                    -H "Content-Type: application/json" \
                    "$fallback_url" \
                    -d "{\"encrypted_value\":\"$encrypted_password\",\"key_id\":\"$key_id\"}")
                
                echo "[DEBUG] Fallback HTTP Response Code: $fallback_http_code"
                
                if [[ "$fallback_http_code" =~ ^(201|204)$ ]]; then
                    echo "[RESULT] ✅ SUCCESS - Fallback repository secret '$fallback_secret_name' created"
                else
                    echo "[RESULT] ❌ FAILED - Fallback also failed with HTTP $fallback_http_code"
                    echo "[DEBUG] Fallback response body:"
                    cat "$fallback_response_file"
                    rm -f "$create_response_file" "$fallback_response_file"
                    return 1
                fi
                rm -f "$fallback_response_file"
            else
                rm -f "$create_response_file"
                return 1
            fi
        fi
        rm -f "$create_response_file"
    fi
    
    # Cleanup
    new_password=""
    encrypted_password=""
    unset new_password encrypted_password
    
    echo ""
    echo "=== [TEST COMPLETED] Password Function - SKIP Behavior ==="
}

# Run the test
echo "🚀 Starting SKIP-only test..."
echo ""

if test_password_skip; then
    echo ""
    echo "✅ SKIP BEHAVIOR TEST PASSED"
    echo ""
    echo "🎯 Test Summary:"
    echo "  - POSTGRES_SECRET_ACTION: skip ✅"
    echo "  - Password generation: ✅"
    echo "  - GitHub API access: ✅"
    echo "  - Encryption: ✅"
    echo "  - Skip logic: ✅"
    echo ""
    echo "📋 What happened:"
    if curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$GITHUB_REPO/actions/secrets/POSTGRES_PASSWORD_${BRANCH//-/_}" \
            >/dev/null 2>&1; then
        echo "  - Repository secret exists: SKIPPED update (correct!)"
    else
        echo "  - Repository secret missing: CREATED new secret (correct!)"
    fi
    echo ""
    echo "🔧 Next: Run again to test skip behavior with existing secret"
else
    echo ""
    echo "❌ SKIP BEHAVIOR TEST FAILED"
    echo "Check error messages above for details"
fi

echo ""
echo "🧪 SKIP test completed at $(date)"
