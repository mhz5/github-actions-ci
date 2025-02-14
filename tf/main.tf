provider "aws" {
  region = "us-west-1"
}

resource "aws_instance" "github_runner" {
  ami           = "ami-07d2649d67dbe8900" # Ubuntu 22.04 LTS (Update as needed)
  instance_type = "t3.micro"
  # key_name      = "your-key-name"  # Replace with your SSH key

  security_groups = [aws_security_group.github_runner_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Install required packages
    sudo apt update && sudo apt install -y curl jq

    # Create GitHub runner directory
    mkdir -p /home/ubuntu/actions-runner && cd /home/ubuntu/actions-runner

    # Download GitHub Actions runner
    curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64.tar.gz
    tar xzf actions-runner-linux-x64.tar.gz

    # Configure runner (Replace with your GitHub repo and token)
    ./config.sh --url https://github.com/YOUR_GITHUB_ORG/YOUR_REPO --token YOUR_GITHUB_TOKEN --name self-hosted-runner --unattended --replace

    # Start runner
    ./svc.sh install
    ./svc.sh start
  EOF

  tags = {
    Name = "GitHub-Runner"
  }
}

# Security group to allow SSH and GitHub communication
resource "aws_security_group" "github_runner_sg" {
  name        = "github-runner-sg"
  description = "Allow SSH and GitHub Actions traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
