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
  user_data = base64encode(templatefile("${path.module}/templates/jenkins-userdata.sh", {}))

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
