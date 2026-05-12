variable "datadog_api_key" {
  type      = string
  sensitive = true
}

# IaC scan: public bucket / data exposure risk.
resource "aws_s3_bucket" "student_exports" {
  bucket = "campushub-student-exports-demo"
}

resource "aws_s3_bucket_public_access_block" "student_exports" {
  bucket = aws_s3_bucket.student_exports.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# IaC/secrets demo: intentionally bad practice.
variable "database_password" {
  type    = string
  default = "UniversityDemoPassword123!"
}

resource "aws_security_group" "campushub_api" {
  name        = "campushub-api-demo"
  description = "Intentionally vulnerable demo SG"

  ingress {
    description = "Open demo app"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "campushub_api" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.campushub_api.id]

  user_data = <<-EOF
  #!/bin/bash
  set -euo pipefail

  exec > /var/log/campushub-user-data.log 2>&1

  trap 'echo "USER DATA FAILED"; tail -n 200 /var/log/campushub-user-data.log; test -f /tmp/ddog_install_error_msg && cat /tmp/ddog_install_error_msg' ERR

  yum update -y
  yum install -y git

  curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
  yum install -y nodejs

  DD_API_KEY=${var.datadog_api_key} DD_SITE="datadoghq.com" bash -c "$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)"

  cat >> /etc/datadog-agent/datadog.yaml <<DDCONF
  apm_config:
    enabled: true

  appsec_config:
    enabled: true
  DDCONF

  systemctl restart datadog-agent

  cd /opt
  git clone https://github.com/nascowe/badapp-demo.git
  cd badapp-demo/backend
  npm install

  cat > /etc/systemd/system/campushub.service <<SERVICE
  [Unit]
  Description=CampusHub Vulnerable Demo
  After=network.target datadog-agent.service

  [Service]
  WorkingDirectory=/opt/badapp-demo/backend
  Environment=DD_SERVICE=campushub-api
  Environment=DD_ENV=demo
  Environment=DD_VERSION=1.0.0
  Environment=DD_APPSEC_ENABLED=true
  Environment=DD_IAST_ENABLED=true
  ExecStart=/usr/bin/node --require dd-trace/init src/server.js
  Restart=always

  [Install]
  WantedBy=multi-user.target
  SERVICE

  cat > /etc/systemd/system/campushub-traffic.service <<TRAFFIC
  [Unit]
  Description=CampusHub demo traffic generator
  After=campushub.service
  Requires=campushub.service

  [Service]
  WorkingDirectory=/opt/badapp-demo
  ExecStartPre=/bin/sleep 10
  ExecStart=/bin/bash /opt/badapp-demo/generate-realistic-traffic.sh
  Restart=always
  StandardOutput=append:/var/log/campushub-traffic.log
  StandardError=append:/var/log/campushub-traffic.log

  [Install]
  WantedBy=multi-user.target
  TRAFFIC

  chmod +x /opt/badapp-demo/generate-realistic-traffic.sh

  systemctl daemon-reload
  systemctl enable --now campushub
  systemctl enable --now campushub-traffic

  EOF

  tags = {
    Name = "campushub-api-demo"
  }
}

output "campushub_public_ip" { 
  value = aws_instance.campushub_api.public_ip 
}
