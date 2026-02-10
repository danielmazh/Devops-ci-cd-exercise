# =============================================================================
# DevOps Testing App - Application EC2 Instance
# =============================================================================
# Creates the application server for staging/production deployment
# =============================================================================

# -----------------------------------------------------------------------------
# Application EC2 Instance
# -----------------------------------------------------------------------------
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.app_instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  root_block_device {
    volume_size           = var.app_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.name_prefix}-app-root"
    }
  }

  # User data script to install Docker
  user_data = base64encode(<<-'USERDATA'
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
USERDATA
  )

  tags = {
    Name = "${local.name_prefix}-app"
    Role = "application"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# -----------------------------------------------------------------------------
# Elastic IP for App
# -----------------------------------------------------------------------------
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "${local.name_prefix}-app-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Null resource to wait for instance initialization
# -----------------------------------------------------------------------------
resource "null_resource" "wait_for_app" {
  depends_on = [aws_instance.app, aws_eip.app]

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user-data to complete...'",
      "timeout 300 bash -c 'while [ ! -f /var/log/user-data-complete ]; do sleep 10; echo \"Waiting...\"; done'",
      "echo 'Instance initialization complete!'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.ssh_private_key_path)
      host        = aws_eip.app.public_ip
      timeout     = "10m"
    }
  }
}
