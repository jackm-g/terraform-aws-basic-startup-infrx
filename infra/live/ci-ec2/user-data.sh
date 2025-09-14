#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    jq \
    build-essential \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install Node.js LTS (20.x) - recommended for Ubuntu 24.04
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Playwright system dependencies for headless browser testing
apt-get install -y \
    libnss3 \
    libnspr4 \
    libatk-bridge2.0-0t64 \
    libdrm2 \
    libxkbcommon0 \
    libgtk-3-0t64 \
    libgbm1 \
    libasound2t64 \
    libxrandr2 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxss1 \
    libatspi2.0-0t64 \
    fonts-liberation \
    fonts-noto-color-emoji \
    fonts-noto-cjk

# Install additional tools needed for CI pipeline
apt-get install -y \
    postgresql-client \
    redis-tools

# Create runner user
useradd -m -s /bin/bash runner
usermod -aG docker runner
usermod -aG sudo runner

# Configure passwordless sudo for runner user (needed for Playwright browser installation)
echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner
chmod 440 /etc/sudoers.d/runner

# Create runner directory
mkdir -p /opt/actions-runner
chown runner:runner /opt/actions-runner

# Create environment file directory
mkdir -p /opt/cgm
chown runner:runner /opt/cgm

# Write environment file
cat > /opt/cgm/.env.test << 'EOF'
${env_file_content}
EOF
chown runner:runner /opt/cgm/.env.test
chmod 600 /opt/cgm/.env.test

# Note: Playwright will be installed per CI job via npm ci in the project workspace
# System dependencies for Playwright browsers are already installed above
# Playwright browsers will be installed during CI jobs using: npx playwright install

# Switch to runner user for GitHub Actions setup
sudo -u runner bash << 'RUNNER_SETUP'
cd /opt/actions-runner

# Download GitHub Actions runner
RUNNER_VERSION="2.320.0"
curl -o actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz

# Verify download was successful
if [ ! -f "actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz" ]; then
    echo "Failed to download GitHub Actions runner"
    exit 1
fi

# Extract the runner
tar xzf ./actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz

# Verify extraction was successful
if [ ! -f "config.sh" ]; then
    echo "Failed to extract GitHub Actions runner - config.sh not found"
    exit 1
fi

# Get registration token from GitHub API using PAT
REGISTRATION_TOKEN=$(curl -X POST \
    -H "Authorization: token ${github_token}" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/${github_repo}/actions/runners/registration-token | jq -r '.token')

# Verify registration token was obtained
if [ -z "$REGISTRATION_TOKEN" ] || [ "$REGISTRATION_TOKEN" = "null" ]; then
    echo "Failed to obtain registration token from GitHub API"
    exit 1
fi

# Configure the runner with the registration token
./config.sh \
    --url https://github.com/${github_repo} \
    --token $REGISTRATION_TOKEN \
    --name ${runner_name} \
    --work _work \
    --labels self-hosted,linux,x64,docker \
    --unattended \
    --replace

# Verify configuration was successful
if [ ! -f ".runner" ]; then
    echo "Runner configuration failed - .runner file not found"
    exit 1
fi

RUNNER_SETUP

# Install and start the runner service
cd /opt/actions-runner

# Verify svc.sh exists before trying to use it
if [ ! -f "svc.sh" ]; then
    echo "ERROR: svc.sh not found in /opt/actions-runner"
    exit 1
fi

# Install the service
if ! ./svc.sh install runner; then
    echo "ERROR: Failed to install runner service"
    exit 1
fi

# Start the service
if ! ./svc.sh start; then
    echo "ERROR: Failed to start runner service"
    exit 1
fi

# Enable Docker service
systemctl enable docker
systemctl start docker

# Configure log rotation for runner logs
cat > /etc/logrotate.d/actions-runner << 'EOF'
/opt/actions-runner/_diag/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 runner runner
}
EOF

# Set up monitoring script with enhanced checks
cat > /usr/local/bin/monitor-runner.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/runner-monitor.log"

# Check if runner service is active
if ! systemctl is-active --quiet actions.runner.*.service; then
    echo "$(date): GitHub Actions runner service is not running, attempting restart..." >> $LOG_FILE
    systemctl restart actions.runner.*.service
fi

# Check Docker service
if ! systemctl is-active --quiet docker; then
    echo "$(date): Docker service is not running, attempting restart..." >> $LOG_FILE
    systemctl restart docker
fi

# Check disk space (warn if less than 10GB free)
DISK_USAGE=$(df / | awk 'NR==2 {print $4}')
if [ $DISK_USAGE -lt 10485760 ]; then
    echo "$(date): Low disk space warning: $(($DISK_USAGE/1024/1024))GB remaining" >> $LOG_FILE
fi

# Clean up old Docker images and containers if disk space is low
if [ $DISK_USAGE -lt 5242880 ]; then
    echo "$(date): Critical disk space, cleaning up Docker..." >> $LOG_FILE
    docker system prune -f >> $LOG_FILE 2>&1
fi
EOF

chmod +x /usr/local/bin/monitor-runner.sh

# Add monitoring to crontab (every 5 minutes)
echo "*/5 * * * * /usr/local/bin/monitor-runner.sh" | crontab -

# Create cleanup script for CI workspace permissions
cat > /usr/local/bin/fix-workspace-permissions.sh << 'EOF'
#!/bin/bash
# Fix workspace permissions after CI runs
if [ -d "/opt/actions-runner/_work" ]; then
    chown -R runner:runner /opt/actions-runner/_work
fi
EOF

chmod +x /usr/local/bin/fix-workspace-permissions.sh

# Set up automatic cleanup (daily at 2 AM)
echo "0 2 * * * /usr/local/bin/fix-workspace-permissions.sh" | crontab -u runner -

# Increase file descriptor limits for Node.js and Playwright
echo "runner soft nofile 65536" >> /etc/security/limits.conf
echo "runner hard nofile 65536" >> /etc/security/limits.conf

# Optimize for CI workloads
echo "vm.swappiness=1" >> /etc/sysctl.conf
echo "fs.file-max=2097152" >> /etc/sysctl.conf
sysctl -p

# Signal completion
echo "GitHub Actions runner with Playwright setup completed at $(date)" > /var/log/runner-setup.log
