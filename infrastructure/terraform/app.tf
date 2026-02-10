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
  user_data = base64encode(templatefile("${path.module}/templates/app-userdata.sh", {}))

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
