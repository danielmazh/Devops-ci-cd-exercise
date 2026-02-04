# =============================================================================
# DevOps Testing App - Terraform Outputs
# =============================================================================
# All output values for use by Ansible and scripts
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Outputs
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# -----------------------------------------------------------------------------
# Jenkins Outputs
# -----------------------------------------------------------------------------
output "jenkins_instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = aws_instance.jenkins.id
}

output "jenkins_private_ip" {
  description = "Jenkins private IP"
  value       = aws_instance.jenkins.private_ip
}

output "jenkins_public_ip" {
  description = "Jenkins public IP (Elastic IP)"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins"
  value       = "ssh -i ${var.ssh_private_key_path} ec2-user@${aws_eip.jenkins.public_ip}"
}

# -----------------------------------------------------------------------------
# App Outputs
# -----------------------------------------------------------------------------
output "app_instance_id" {
  description = "App EC2 instance ID"
  value       = aws_instance.app.id
}

output "app_private_ip" {
  description = "App private IP"
  value       = aws_instance.app.private_ip
}

output "app_public_ip" {
  description = "App public IP (Elastic IP)"
  value       = aws_eip.app.public_ip
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_eip.app.public_ip}"
}

output "app_health_url" {
  description = "Application health check URL"
  value       = "http://${aws_eip.app.public_ip}/health"
}

output "app_ssh_command" {
  description = "SSH command to connect to App server"
  value       = "ssh -i ${var.ssh_private_key_path} ec2-user@${aws_eip.app.public_ip}"
}

# -----------------------------------------------------------------------------
# Security Group Outputs
# -----------------------------------------------------------------------------
output "jenkins_security_group_id" {
  description = "Jenkins security group ID"
  value       = aws_security_group.jenkins.id
}

output "app_security_group_id" {
  description = "App security group ID"
  value       = aws_security_group.app.id
}

# -----------------------------------------------------------------------------
# Ansible Inventory Output
# -----------------------------------------------------------------------------
output "ansible_inventory" {
  description = "Ansible inventory content"
  value       = <<-EOT
    [jenkins]
    ${aws_eip.jenkins.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=${var.ssh_private_key_path}

    [app]
    ${aws_eip.app.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=${var.ssh_private_key_path}

    [jenkins:vars]
    jenkins_url=http://${aws_eip.jenkins.public_ip}:8080
    app_server_ip=${aws_eip.app.public_ip}

    [app:vars]
    environment=${var.environment}
    docker_image=${var.docker_hub_username}/${var.docker_image_name}
  EOT
}

# -----------------------------------------------------------------------------
# Summary Output
# -----------------------------------------------------------------------------
output "summary" {
  description = "Deployment summary"
  value       = <<-EOT
    
    ============================================
    DevOps Testing App - Infrastructure Summary
    ============================================
    
    Environment: ${var.environment}
    Region:      ${var.aws_region}
    
    JENKINS SERVER
    --------------
    Public IP:   ${aws_eip.jenkins.public_ip}
    URL:         http://${aws_eip.jenkins.public_ip}:8080
    SSH:         ssh -i ${var.ssh_private_key_path} ec2-user@${aws_eip.jenkins.public_ip}
    
    APPLICATION SERVER
    ------------------
    Public IP:   ${aws_eip.app.public_ip}
    URL:         http://${aws_eip.app.public_ip}
    Health:      http://${aws_eip.app.public_ip}/health
    SSH:         ssh -i ${var.ssh_private_key_path} ec2-user@${aws_eip.app.public_ip}
    
    ============================================
  EOT
}
