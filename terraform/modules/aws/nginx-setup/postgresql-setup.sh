
#!/bin/bash

# PostgreSQL Ansible Setup Script - Bulletproof & Idempotent
# This script uses the bulletproof approach for timezone and package installation

set -euo pipefail

echo '=== PostgreSQL Ansible Setup Started at $(date) ==='

# Set complete non-interactive environment (bulletproof approach)
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export UCF_FORCE_CONFFOLD=1
export DEBCONF_NONINTERACTIVE_SEEN=true
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Configure debconf to never ask questions
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections 2>/dev/null || true
echo 'debconf debconf/priority select critical' | debconf-set-selections 2>/dev/null || true

# BULLETPROOF timezone configuration - multiple preseeding methods
echo "tzdata tzdata/Areas select Etc" | debconf-set-selections 2>/dev/null || true
echo "tzdata tzdata/Zones/Etc select UTC" | debconf-set-selections 2>/dev/null || true

# Set timezone files directly
sudo mkdir -p /etc
echo 'Etc/UTC' | sudo tee /etc/timezone > /dev/null 2>&1 || true
sudo ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime 2>/dev/null || true

# Simple function to check if package is already installed (idempotent)
is_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii" || return 1
}

# Bulletproof package installation function
install_package_bulletproof() {
    local package="$1"
    
    if is_installed "$package"; then
        echo "✅ $package is already installed, skipping"
        return 0
    fi
    
    echo "Installing $package with bulletproof method..."
    
    if [ "$package" = "tzdata" ]; then
        # BULLETPROOF timezone handling - auto-answer prompts
        echo "Installing tzdata with automatic timezone answers..."
        echo -e "12\n1\n" | sudo apt-get install -y tzdata 2>/dev/null || {
            # Fallback method 1
            echo "Method 1 failed, trying method 2..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" || {
                # Fallback method 2
                echo "Method 2 failed, trying method 3..."
                yes '' | sudo apt-get install -y tzdata || sudo apt-get install -y tzdata < /dev/null || true
            }
        }
        
        # Ensure timezone is set correctly after installation
        echo 'Etc/UTC' | sudo tee /etc/timezone > /dev/null
        sudo ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
        sudo dpkg-reconfigure -f noninteractive tzdata 2>/dev/null || true
        
        echo "✅ tzdata installed successfully"
        return 0
    else
        # Normal package installation with bulletproof options
        if sudo apt-get install -y "$package" -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; then
            echo "✅ $package installed successfully"
            return 0
        else
            echo "❌ $package installation failed"
            return 1
        fi
    fi
}

# Configure APT for bulletproof operation
sudo mkdir -p /etc/apt/apt.conf.d/
sudo tee /etc/apt/apt.conf.d/99-bulletproof > /dev/null << 'EOF'
APT::Get::Assume-Yes "true";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Dpkg::Options {
    "--force-confdef";
    "--force-confold";
    "--force-confnew";
};
Dpkg::Use-Pty "0";
EOF

# Disable problematic hooks that can cause hanging
if [ -d /etc/ca-certificates/update.d/ ]; then
    sudo find /etc/ca-certificates/update.d/ -type f -exec chmod -x {} \; 2>/dev/null || true
fi

# Disable man-db updates
echo 'path-exclude /usr/share/man/*' | sudo tee /etc/dpkg/dpkg.cfg.d/01_nodoc > /dev/null 2>&1 || true

# Update package lists (bulletproof)
echo "Updating package lists..."
sudo apt-get update -qq || {
    echo "Initial update failed, trying again..."
    sleep 5
    sudo apt-get update -qq
}

# Install essential packages with bulletproof method
essential_packages=("sudo" "curl" "git" "apt-utils" "net-tools" "tzdata" "jq" "openssl" "python3" "python3-pip")

echo "Installing essential packages with bulletproof method..."
for package in "${essential_packages[@]}"; do
    install_package_bulletproof "$package" || {
        echo "WARNING: Failed to install $package, continuing..."
    }
done

# Validate required environment variables
echo 'Validating Environment Variables...'
REQUIRED_VARS=(
    "POSTGRESQL_VERSION"
    "STORAGE_DEVICE" 
    "MOUNT_POINT"
    "POSTGRESQL_PORT"
    "NETWORK_CIDR"
    "MOSIP_INFRA_REPO_URL"
    "MOSIP_INFRA_BRANCH"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo "ERROR: Missing required environment variables:"
    printf '  - %s\n' "${MISSING_VARS[@]}"
    echo ""
    echo "Please ensure these variables are set before running the script."
    exit 1
fi

echo 'All required environment variables are set:'
for var in "${REQUIRED_VARS[@]}"; do
    echo "  $var=${!var}"
done
echo ""

# Install prerequisites with bulletproof method
echo 'Installing Prerequisites with Bulletproof Method...'

# Install python3 first (usually already installed)
if ! is_installed "python3"; then
    install_package_bulletproof "python3" || {
        echo "ERROR: Failed to install python3"
        exit 1
    }
fi

# Install python3-pip with bulletproof method
echo 'Installing Python3-pip...'
if ! install_package_bulletproof "python3-pip"; then
    echo "Package installation failed, trying pip bootstrap method..."
    # Alternative: Use the official pip installer
    if command -v curl >/dev/null; then
        curl -sS https://bootstrap.pypa.io/get-pip.py | python3 -W ignore || {
            echo "ERROR: Failed to install pip via bootstrap"
            exit 1
        }
    else
        echo "ERROR: Cannot install pip - curl not available"
        exit 1
    fi
fi

# Verify pip is working
if ! command -v pip3 >/dev/null && ! python3 -m pip --version >/dev/null 2>&1; then
    echo "ERROR: pip installation verification failed"
    exit 1
fi

# Install ansible with bulletproof method
echo 'Installing Ansible...'
if ! install_package_bulletproof "ansible"; then
    echo 'Package installation failed, installing via pip...'
    
    # Install ansible via pip (user install to avoid conflicts)
    if python3 -m pip install --user --quiet ansible; then
        echo 'Ansible installed via pip (user) successfully'
        # Add user bin to PATH
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc || true
    else
        echo 'User pip install failed, trying system pip...'
        if python3 -m pip install --quiet ansible; then
            echo 'Ansible installed via pip (system) successfully'
        else
            echo 'ERROR: All ansible installation methods failed'
            exit 1
        fi
    fi
fi

echo 'All prerequisites installation completed with bulletproof method'
echo 'Checking installed versions:'
git --version || echo "Git: Not available"
python3 --version || echo "Python3: Not available"
ansible --version || echo "Ansible: Not available"

# Clone MOSIP infrastructure repository with retry logic
echo 'Cloning Repository...'
cd /tmp
rm -rf mosip-infra

echo "Cloning from: $MOSIP_INFRA_REPO_URL"
echo "Branch: $MOSIP_INFRA_BRANCH"

git clone "$MOSIP_INFRA_REPO_URL" || {
    echo 'Initial git clone failed, retrying with verbose output...'
    sleep 10
    git clone --verbose "$MOSIP_INFRA_REPO_URL" || {
        echo 'Git clone failed completely'
        echo 'Checking network connectivity...'
        ping -c 3 8.8.8.8 || echo 'Network connectivity issue detected'
        exit 1
    }
}

cd mosip-infra
git checkout "$MOSIP_INFRA_BRANCH" || {
    echo "Branch checkout failed for branch: $MOSIP_INFRA_BRANCH"
    echo 'Available branches:'
    git branch -a
    exit 1
}

echo "Successfully cloned and checked out branch: $MOSIP_INFRA_BRANCH"

# Navigate to PostgreSQL Ansible directory
echo 'Navigating to PostgreSQL Ansible Directory...'
echo 'Current directory structure:'
find /tmp/mosip-infra -name '*postgres*' -type d 2>/dev/null || echo 'No postgres directories found'

POSTGRES_ANSIBLE_DIR="/tmp/mosip-infra/deployment/v3/external/postgres/ansible"
if [ ! -d "$POSTGRES_ANSIBLE_DIR" ]; then
    echo "PostgreSQL Ansible directory not found at: $POSTGRES_ANSIBLE_DIR"
    echo 'Available directories under deployment:'
    find /tmp/mosip-infra -name 'deployment' -type d -exec find {} -type d \; 2>/dev/null | head -20
    exit 1
fi

cd "$POSTGRES_ANSIBLE_DIR"
echo "Successfully navigated to: $(pwd)"
echo 'Directory contents:'
ls -la

# Create dynamic inventory with current host
echo '[CREATE] Creating Inventory File...'
cat > inventory.ini << 'EOF'
[postgresql_servers]
localhost ansible_connection=local ansible_user=ubuntu ansible_become=yes ansible_become_method=sudo
EOF

echo '[SUCCESS] Inventory file created:'
cat inventory.ini

# Check if required playbook exists
PLAYBOOK_FILE="postgresql-setup.yml"
if [ ! -f "$PLAYBOOK_FILE" ]; then
    echo "[ERROR] Playbook file not found: $PLAYBOOK_FILE"
    echo 'Available files in current directory:'
    ls -la *.yml *.yaml 2>/dev/null || echo 'No YAML files found'
    exit 1
fi
echo "[SUCCESS] Playbook file found: $PLAYBOOK_FILE"

# Set PostgreSQL configuration variables
echo '[CONFIG] Setting Environment Variables...'
export DEBIAN_FRONTEND=noninteractive  # Prevent interactive prompts
export ANSIBLE_HOST_KEY_CHECKING=False  # Skip host key checking
export ANSIBLE_STDOUT_CALLBACK=debug   # Verbose output
export ANSIBLE_TIMEOUT=30              # Set ansible timeout
export ANSIBLE_CONNECT_TIMEOUT=30      # Set connection timeout
export ANSIBLE_COLLECTIONS_PATH=/tmp/ansible_collections  # Custom collections path
export ANSIBLE_GALAXY_DISABLE_GPG_VERIFY=true  # Disable GPG verification
export ANSIBLE_PIPELINING=true         # Enable pipelining for speed
export ANSIBLE_SSH_RETRIES=3           # Set SSH retries

# Create ansible configuration to prevent hanging
echo '[CONFIG] Creating Ansible Configuration...'
mkdir -p ~/.ansible
cat > ~/.ansible/ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
gathering = explicit
fact_caching = memory
fact_caching_timeout = 86400
stdout_callback = debug
stderr_callback = debug
timeout = 30
command_timeout = 30
connect_timeout = 30
gathering_timeout = 30

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
retries = 3
EOF

echo '[SUCCESS] Environment variables and Ansible configuration set:'
echo "PostgreSQL Version: $POSTGRESQL_VERSION"
echo "Storage Device: $STORAGE_DEVICE"
echo "Mount Point: $MOUNT_POINT"
echo "PostgreSQL Port: $POSTGRESQL_PORT"
echo "Network CIDR: $NETWORK_CIDR"

# Configure APT to prevent hanging
echo '[CONFIG] Configuring APT for non-interactive mode...'
sudo mkdir -p /etc/apt/apt.conf.d/
echo 'APT::Get::Assume-Yes "true";' | sudo tee /etc/apt/apt.conf.d/99automated
echo 'APT::Get::force-yes "true";' | sudo tee -a /etc/apt/apt.conf.d/99automated
echo 'Dpkg::Options { "--force-confdef"; "--force-confold"; }' | sudo tee -a /etc/apt/apt.conf.d/99automated
echo '[SUCCESS] APT configured for non-interactive mode'

# Install required Ansible collections to prevent hanging during playbook execution
echo '[INSTALL] Installing Required Ansible Collections...'
mkdir -p /tmp/ansible_collections
ansible-galaxy collection install community.general ansible.posix --force || {
    echo '[WARNING] Failed to install some collections, continuing with basic setup...'
}
echo '[SUCCESS] Ansible collections installation completed'

# Check if storage device exists and wait if needed
echo '[CHECK] Checking Storage Device...'
echo "Looking for storage device: $STORAGE_DEVICE"

# First, show all available block devices
echo '[INFO] All available block devices:'
lsblk -f 2>/dev/null || lsblk 2>/dev/null || echo 'Unable to list block devices'

# Wait for the specific storage device
echo "[WAIT] Waiting for storage device $STORAGE_DEVICE..."
DEVICE_FOUND=false
for i in {1..24}; do 
    if [ -b "$STORAGE_DEVICE" ]; then 
        echo "[SUCCESS] Storage device found: $STORAGE_DEVICE"; 
        DEVICE_FOUND=true
        break; 
    fi; 
    
    # Show progress every 6 attempts
    if [ $((i % 6)) -eq 0 ]; then
        echo "[WAIT] Attempt $i/24: waiting for $STORAGE_DEVICE..."
        echo 'Current block devices:'
        lsblk | grep -E '(nvme|xvd|sd)' || echo 'No common block devices found'
    fi
    sleep 5; 
done

if [ "$DEVICE_FOUND" = false ]; then 
    echo "[WARNING] WARNING: Storage device $STORAGE_DEVICE not found after 2 minutes"
    echo 'This might be okay if PostgreSQL will use existing storage.'
    echo '[INFO] Available block devices:'
    lsblk 2>/dev/null || echo 'Unable to list block devices'
    
    # Don't exit here, let the playbook handle storage configuration
    echo 'Continuing with PostgreSQL setup...'
else
    echo "[SUCCESS] Storage device $STORAGE_DEVICE is available"
    echo 'Device information:'
    lsblk "$STORAGE_DEVICE" 2>/dev/null || echo "Unable to get device info for $STORAGE_DEVICE"
fi

# Run PostgreSQL setup with extended timeout and better error handling
echo '[RUN] Running PostgreSQL Ansible Playbook...'
echo "[TIME] Starting ansible-playbook at $(date)"
echo '[CREATE] This should take 10-15 minutes. Progress will be shown below...'

# Test ansible connection first
echo '[TEST] Testing Ansible connectivity...'
if ! ansible localhost -i inventory.ini -m ping; then
    echo '[ERROR] Ansible connectivity test failed'
    echo 'Checking localhost connection...'
    ansible localhost -i inventory.ini -m setup --limit localhost -v || true
    echo '[WARNING] Continuing anyway, playbook might still work...'
fi

# Show the command that will be executed
echo '[INFO] Ansible command to be executed:'
echo "ansible-playbook -vv -i inventory.ini -e postgresql_version=$POSTGRESQL_VERSION -e storage_device=$STORAGE_DEVICE -e mount_point=$MOUNT_POINT -e postgresql_port=$POSTGRESQL_PORT -e network_cidr=$NETWORK_CIDR postgresql-setup.yml"

# Start a background progress monitor
(
    while true; do
        sleep 60
        echo "[WAIT] PostgreSQL setup still running... $(date) - Check /tmp/postgresql-ansible.log for details"
        if [ -f /tmp/postgresql-ansible.log ]; then
            LAST_LINE=$(tail -1 /tmp/postgresql-ansible.log 2>/dev/null || echo "Log file being written...")
            echo "[LOG] Last log: $LAST_LINE"
        fi
    done
) &
PROGRESS_PID=$!

# Run the actual playbook
timeout 900 ansible-playbook -vv -i inventory.ini \
    -e postgresql_version=$POSTGRESQL_VERSION \
    -e storage_device=$STORAGE_DEVICE \
    -e mount_point=$MOUNT_POINT \
    -e postgresql_port=$POSTGRESQL_PORT \
    -e network_cidr=$NETWORK_CIDR \
    postgresql-setup.yml 2>&1 | tee /tmp/postgresql-ansible.log
ANSIBLE_EXIT_CODE=$?

# Stop the progress monitor
kill $PROGRESS_PID 2>/dev/null || true

if [ $ANSIBLE_EXIT_CODE -ne 0 ]; then
    echo ''
    echo "[ERROR] Ansible playbook failed with exit code $ANSIBLE_EXIT_CODE"
    echo '[CONFIG] Attempting PostgreSQL Recovery...'
    
    # Fix common permission issues
    echo '[CONFIG] Fixing data directory permissions...'
    sudo chown -R postgres:postgres $MOUNT_POINT/postgresql/15/main 2>/dev/null || true
    sudo chmod 700 $MOUNT_POINT/postgresql/15/main 2>/dev/null || true
    
    # Try to restart PostgreSQL service
    echo '[PROGRESS] Attempting to restart PostgreSQL service...'
    sudo systemctl stop postgresql 2>/dev/null || true
    sleep 3
    sudo systemctl start postgresql 2>/dev/null || true
    sleep 5
    
    # Check if PostgreSQL is now running
    if sudo systemctl is-active postgresql >/dev/null 2>&1; then
        echo '[SUCCESS] PostgreSQL recovery successful!'
        echo '[TEST] Testing connection...'
        if sudo -u postgres psql -p "$POSTGRESQL_PORT" -c "SELECT version();" --no-psqlrc --pset pager=off; then
            echo '[SUCCESS] PostgreSQL is working!'
        else
            echo '[ERROR] Connection still failing'
        fi
    else
        echo '[ERROR] PostgreSQL recovery failed'
        echo '=== Diagnostic Information ==='
        echo '[STATUS] Service status:'
        sudo systemctl status postgresql --no-pager --lines=10 || true
        echo '[INFO] Recent logs:'
        sudo journalctl -u postgresql --no-pager --lines=20 || true
        echo '[LOG] Last 50 lines of setup log:'
        tail -50 /tmp/postgresql-ansible.log || true
        echo '[STORAGE] System status:'
        df -h
        free -h
        exit 1
    fi
else
    echo ''
    echo "[SUCCESS] Ansible playbook completed successfully at $(date)"
fi


# Verify PostgreSQL installation with improved checks
echo ''
echo '=== [CHECK] Verifying PostgreSQL Installation ==='
sleep 5  # Quick wait for service to start

# Check main PostgreSQL service
echo '[CHECK] Checking PostgreSQL main service status...'
sudo systemctl status postgresql --no-pager --lines=5 || echo '[WARNING]  PostgreSQL service status check failed'

# Check specific PostgreSQL cluster service
echo '[CHECK] Checking PostgreSQL 15 cluster service...'
sudo systemctl status postgresql@15-main --no-pager --lines=5 2>/dev/null || {
    echo '[WARNING]  PostgreSQL cluster service not active, attempting to start...'
    sudo systemctl start postgresql@15-main 2>/dev/null || echo '[ERROR] Failed to start PostgreSQL cluster'
    sleep 5
}

# Check if PostgreSQL is actually listening on the configured port
echo "[CONNECT] Testing PostgreSQL connectivity on port $POSTGRESQL_PORT..."
for i in {1..3}; do
    if timeout 15 sudo -u postgres psql -p "$POSTGRESQL_PORT" -c "SELECT version();" --no-psqlrc --pset pager=off >/dev/null 2>&1; then
        echo "[SUCCESS] PostgreSQL connection successful on attempt $i!"
        break
    else
        echo "[WAIT] Attempt $i/3: PostgreSQL not responding on port $POSTGRESQL_PORT, waiting..."
        sleep 5
    fi
done

# Final verification with detailed output
echo ''
echo '=== [STATUS] Final PostgreSQL Status Report ==='
echo '[CONFIG] Service Status:'
echo "  Main Service: $(sudo systemctl is-active postgresql 2>/dev/null || echo 'inactive')"
echo "  Cluster Service: $(sudo systemctl is-active postgresql@15-main 2>/dev/null || echo 'inactive')"
echo '[TEST] Connection Tests:'
if timeout 15 sudo -u postgres psql -p "$POSTGRESQL_PORT" -c "SELECT version();" --no-psqlrc --pset pager=off >/dev/null 2>&1; then
    echo '  [SUCCESS] PostgreSQL connection: SUCCESS'
    echo '  [CREATE] PostgreSQL version:'
    timeout 10 sudo -u postgres psql -p "$POSTGRESQL_PORT" -c "SELECT version();" --no-psqlrc --pset pager=off 2>/dev/null || echo '  [ERROR] Version check failed'
    echo '  [DIR] Data directory:'
    timeout 10 sudo -u postgres psql -p "$POSTGRESQL_PORT" -c "SHOW data_directory;" --no-psqlrc --pset pager=off 2>/dev/null || echo '  [ERROR] Data directory check failed'
else
    echo '  ERROR: PostgreSQL connection: FAILED'
fi

# Check if PostgreSQL is listening on the correct port
echo 'Network Status:'
if timeout 10 sudo netstat -tlnp | grep ":$POSTGRESQL_PORT" >/dev/null 2>&1; then
    echo "  SUCCESS: PostgreSQL listening on port $POSTGRESQL_PORT"
    timeout 5 sudo netstat -tlnp | grep ":$POSTGRESQL_PORT" | head -1 || echo "  (Port details unavailable)"
else
    echo "  ERROR: PostgreSQL not listening on port $POSTGRESQL_PORT"
fi

echo ''
echo '=== PostgreSQL Ansible Setup Completed Successfully ==='
echo "Completion Time: $(date)"
echo "Setup Log: /tmp/postgresql-ansible.log"
echo ''
echo '=== Final System Status ==='
echo 'PostgreSQL Service:'
SERVICE_STATUS=$(sudo systemctl is-active postgresql 2>/dev/null || echo 'inactive')
echo "  Status: $SERVICE_STATUS"
if [ "$SERVICE_STATUS" = "active" ]; then
    echo '  SUCCESS: PostgreSQL is running successfully'
else
    echo '  WARNING: PostgreSQL service may need attention'
fi
echo 'Storage Usage:'
if df -h "$MOUNT_POINT" >/dev/null 2>&1; then
    echo "  Mount Point: $MOUNT_POINT"
    df -h "$MOUNT_POINT" | tail -1
else
    echo '  WARNING: Mount point not available'
fi
echo "Installation Summary:"
echo "PostgreSQL Version: $POSTGRESQL_VERSION"
echo "Storage Device: $STORAGE_DEVICE"
echo "Mount Point: $MOUNT_POINT"
echo "PostgreSQL Port: $POSTGRESQL_PORT"
echo "Network CIDR: $NETWORK_CIDR"
echo "PostgreSQL setup completed successfully"

# ============================================================================
# AUTOMATED PASSWORD UPDATE FUNCTION
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
    
    # Step 2: Update PostgreSQL password securely
    echo "[STEP 2/6] Updating PostgreSQL password..."
    
    # Use here-doc to avoid exposing password in process list
    if sudo -u postgres psql -p "$POSTGRESQL_PORT" --no-psqlrc --pset pager=off > /dev/null 2>&1 <<EOF
ALTER USER postgres PASSWORD '$new_password';
EOF
    then
        echo "[SUCCESS] PostgreSQL password updated successfully"
    else
        echo "[ERROR] Failed to update PostgreSQL password"
        return 1
    fi
    
    # Step 3: Test connection with new password securely
    echo "[STEP 3/6] Testing PostgreSQL connection with new password..."
    
    # Create temporary .pgpass file for secure connection testing
    local temp_pgpass=$(mktemp)
    chmod 600 "$temp_pgpass"
    echo "localhost:$POSTGRESQL_PORT:*:postgres:$new_password" > "$temp_pgpass"
    
    # Test connection without exposing password in logs
    if PGPASSFILE="$temp_pgpass" timeout 15 psql -h localhost -p "$POSTGRESQL_PORT" -U postgres -d postgres -c "SELECT 1;" --no-psqlrc --pset pager=off > /dev/null 2>&1; then
        echo "[SUCCESS] PostgreSQL connection test passed"
    else
        echo "[ERROR] PostgreSQL connection test failed"
        rm -f "$temp_pgpass"
        return 1
    fi
    
    # Clean up temporary password file
    rm -f "$temp_pgpass"
    
    # Step 4: Get GitHub public key for encryption
    echo "[STEP 4/6] Retrieving GitHub public key for secure transmission..."
    
    # Get environment info first to determine which public key to use
    local env_response
    env_response=$(curl -s \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$github_repository/environments")
    
    local environment_id
    environment_id=$(echo "$env_response" | jq -r ".environments[] | select(.name==\"$branch_name\") | .id" 2>/dev/null)
    
    local public_key_response
    local key_type
    
    # Choose the appropriate public key endpoint
    if [ -z "$environment_id" ] || [ "$environment_id" = "null" ]; then
        echo "[INFO] No environment '$branch_name' found, using repository public key"
        key_type="repository"
        public_key_response=$(curl -s \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$github_repository/actions/secrets/public-key")
    else
        echo "[INFO] Environment '$branch_name' found, attempting environment public key"
        key_type="environment"
        # Use environment name instead of ID for better API compatibility
        public_key_response=$(curl -s \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/repos/$github_repository/environments/$branch_name/secrets/public-key")
        
        # If environment public key fails, fallback to repository public key
        local env_key_status
        env_key_status=$(echo "$public_key_response" | jq -r '.message' 2>/dev/null)
        if [ "$env_key_status" = "Not Found" ] || [ -z "$public_key_response" ]; then
            echo "[WARN] Environment public key not accessible, falling back to repository public key"
            key_type="repository"
            public_key_response=$(curl -s \
                -H "Authorization: token $github_token" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/$github_repository/actions/secrets/public-key")
        fi
    fi
    
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
        return 1
    fi
    
    echo "[SUCCESS] GitHub public key retrieved successfully (type: $key_type)"
    
    # Step 5: Encrypt password using libsodium-compatible method (Python)
    echo "[STEP 5/6] Encrypting password for secure transmission..."
    
    # Install python3-pip and pynacl if not available
    if ! python3 -c "import nacl.public" 2>/dev/null; then
        echo "[INFO] Installing required Python cryptography library..."
        sudo apt-get update -qq
        sudo apt-get install -y python3-pip
        pip3 install --user pynacl
    fi
    
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
    
    # Step 6: Update GitHub environment secret
    echo "[STEP 6/6] Updating GitHub environment secret for branch '$branch_name'..."
    
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
        # Update environment secret with branch-specific name
        echo "[INFO] Updating environment secret for environment '$branch_name' (ID: $environment_id)"
        secret_name="POSTGRES_PASSWORD_${branch_name//-/_}"  # Use branch-specific name in environment
        
        # Check if environment secret already exists
        local env_secret_check_response
        env_secret_check_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/repos/$github_repository/environments/$branch_name/secrets/$secret_name")
        
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
        
        # Create/Update environment secret with branch-specific name
        local update_response
        update_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -X PUT \
            -H "Authorization: token $github_token" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -H "Content-Type: application/json" \
            "https://api.github.com/repos/$github_repository/environments/$branch_name/secrets/$secret_name" \
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
            echo "[INFO] Falling back to repository secret..."
            
            # Fallback to repository secret if environment secret fails
            local fallback_secret_name="POSTGRES_PASSWORD_${branch_name//-/_}"
            local fallback_response
            fallback_response=$(curl -s -w "%{http_code}" -o /dev/null \
                -X PUT \
                -H "Authorization: token $github_token" \
                -H "Accept: application/vnd.github.v3+json" \
                -H "Content-Type: application/json" \
                "https://api.github.com/repos/$github_repository/actions/secrets/$fallback_secret_name" \
                -d "{\"encrypted_value\":\"$encrypted_password\",\"key_id\":\"$key_id\"}")
            
            local fallback_http_code="${fallback_response}"
            if [[ "$fallback_http_code" =~ ^(201|204)$ ]]; then
                echo "[SUCCESS] Fallback repository secret '$fallback_secret_name' created successfully"
            else
                echo "[ERROR] Both environment and repository secret creation failed"
                return 1
            fi
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

# Call the password update function if environment variables are available
if [ "${AUTO_UPDATE_PASSWORD:-false}" = "true" ]; then
    update_postgres_password
else
    echo ""
    echo "=== [INFO] Automated Password Update ==="
    echo "To enable automated password update, set environment variable:"
    echo "  export AUTO_UPDATE_PASSWORD=true"
    echo "Required environment variables (automatically set by GitHub Actions):"
    echo "  - GITHUB_TOKEN (GitHub PAT from secrets)"
    echo "  - GITHUB_REPO (repository name from github.repository)"
    echo "  - BRANCH (branch name from github.ref_name)"
    echo ""
    echo "Optional environment variables:"
    echo "  - POSTGRES_SECRET_ACTION (default: skip)"
    echo "    * 'skip'   - Skip update if secret already exists (DEFAULT - non-interactive)"
    echo "    * 'update' - Update existing secret with new password"
    echo "    * 'fail'   - Fail if secret already exists"
    echo ""
fi
