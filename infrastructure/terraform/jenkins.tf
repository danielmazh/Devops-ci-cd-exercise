# =============================================================================
# DevOps Testing App - Jenkins EC2 Instance
# =============================================================================
# Creates the Jenkins server with Docker and required tools
# =============================================================================

# -----------------------------------------------------------------------------
# Jenkins EC2 Instance
# -----------------------------------------------------------------------------
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.jenkins_instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  root_block_device {
    volume_size           = var.jenkins_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.name_prefix}-jenkins-root"
    }
  }

  # User data script to install Docker
  user_data = base64encode(<<-EOF
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
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
    
    # Install AWS CLI v2 (if not present)
    if ! command -v aws &> /dev/null; then
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
  EOF
  )

  tags = {
    Name = "${local.name_prefix}-jenkins"
    Role = "jenkins"
  }

  # Wait for instance to be ready
  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# -----------------------------------------------------------------------------
# Elastic IP for Jenkins
# -----------------------------------------------------------------------------
resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name = "${local.name_prefix}-jenkins-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Null resource to wait for instance initialization
# -----------------------------------------------------------------------------
resource "null_resource" "wait_for_jenkins" {
  depends_on = [aws_instance.jenkins, aws_eip.jenkins]

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
      host        = aws_eip.jenkins.public_ip
      timeout     = "10m"
    }
  }
}
