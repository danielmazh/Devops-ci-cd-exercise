#!/bin/bash
set -ex

# Log output
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting user-data script at $(date)"

# Update system
dnf update -y

# Install required packages
dnf install -y docker git python3 python3-pip jq curl wget unzip

# Start and enable Docker
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install Docker Compose v2
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# Install AWS CLI v2 (if not present)
if ! command -v aws > /dev/null 2>&1; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
  rm -rf aws awscliv2.zip
fi

# Create directories
mkdir -p /opt/jenkins/data /opt/jenkins/casc
chown -R 1000:1000 /opt/jenkins

# Create marker file for Ansible
touch /var/log/user-data-complete
echo "User-data script completed at $(date)"
