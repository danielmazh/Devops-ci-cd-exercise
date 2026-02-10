#!/bin/bash
set -ex

# Log output
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting user-data script at $(date)"

# Update system
dnf update -y

# Install required packages
dnf install -y docker git python3 python3-pip jq curl

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

# Create application directory
mkdir -p /opt/devops-app
chown -R ec2-user:ec2-user /opt/devops-app

# Create marker file for Ansible
touch /var/log/user-data-complete
echo "User-data script completed at $(date)"
