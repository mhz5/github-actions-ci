provider "aws" {
  region = "us-west-1"
}

terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

resource "aws_key_pair" "github_runner_key" {
  key_name   = "github-runner-key"
  # ssh-keygen -t rsa -b 4096 -f ~/.ssh/github-runner-key -N ""
  public_key = file("~/.ssh/github-runner-key.pub") # Use an existing public key
}

resource "aws_instance" "github_runner" {
  ami           = "ami-07d2649d67dbe8900" # Ubuntu 22.04 LTS (Update as needed)
  instance_type = "t3.micro"
  key_name      = aws_key_pair.github_runner_key.key_name  # Use Terraform key

  security_groups = [aws_security_group.github_runner_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    set -e  # Stop script if any command fails

    GITHUB_PAT=${var.github_token}
    ORG="mhz5"
    REPO="github-actions-ci"

    # Ensure curl is installed
    sudo apt update && sudo apt install -y curl jq

    # Fetch GitHub Runner Token via API
    export RUNNER_TOKEN=$(curl -s -X POST -H "Authorization: token $GITHUB_PAT" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/$ORG/$REPO/actions/runners/registration-token | jq -r .token)

    echo  $RUNNER_TOKEN > runnertoken
    # Create actions-runner directory and set correct permissions
    # Must use su to run as ubuntu user, because cannot run ./config.sh as sudo.
    su - ubuntu -c "mkdir -p /home/ubuntu/actions-runner \
      && cd /home/ubuntu/actions-runner \
      && curl -fsSL -o actions-runner-linux-x64-2.322.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-linux-x64-2.322.0.tar.gz \
      && echo 'b13b784808359f31bc79b08a191f5f83757852957dd8fe3dbfcc38202ccf5768  actions-runner-linux-x64-2.322.0.tar.gz' | shasum -a 256 -c \
      && tar xzf ./actions-runner-linux-x64-2.322.0.tar.gz \
      && ./config.sh --url https://github.com/mhz5/github-actions-ci --token $RUNNER_TOKEN --unattended --replace --labels mz --name aws-gha-runner >out 2>err"

    touch config-done

    # Start runner
    cd /home/ubuntu/actions-runner
    sudo ./svc.sh install
    touch install-done
    sudo ./svc.sh start
    touch start-done
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
    cidr_blocks = ["${var.my_ip}/32"] # Restrict this to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# terraform output public_ip
output "public_ip" {
  value = aws_instance.github_runner.public_ip
}
