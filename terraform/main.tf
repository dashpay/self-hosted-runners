provider "aws" {
  region = "us-west-2" # Adjust as needed
}

variable "ami_id" {
  description = "AMI ID for GitHub Actions runner"
}

variable "desired_capacity" {
  description = "Amount of runners"
}

variable "subnet_ids" {
  type    = list(string)
  description = "List of subnet IDs for the Auto Scaling Group"
}

variable "instance_type" {
  description = "EC2 instance type for the runner"
}

variable "asg_min_size" {
  default     = 0
  description = "Minimum number of instances in ASG"
}

variable "asg_max_size" {
  default     = 5
  description = "Maximum number of instances in ASG"
}

variable "github_token" {
  description = "GitHub Actions runner token"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

resource "aws_iam_instance_profile" "ec2_s3_full_profile" {
  name = "EC2-S3-Full-Instance-Profile"
  role = "EC2-S3-Full"  # Name of your existing IAM role
}

resource "aws_launch_template" "github_actions_runner" {
  name          = "github-actions-runner-launch-template"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = "dashdev.rsa"

  # Attach the instance profile
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_s3_full_profile.name
  }

  # Use Spot instances
  instance_market_options {
    market_type = "spot"
  }

    block_device_mappings {
    device_name = "/dev/sda1" # Root volume for most Linux AMIs; adjust if needed
    ebs {
      volume_size = 50            # Set the desired volume size in GB
      volume_type = "gp3"         # Recommended: gp3 for general-purpose SSD
      delete_on_termination = true
    }
  }

  # User data with passed variables for configuring the runner
    user_data = base64encode(file("${path.module}/setup_runner.sh"))

}

resource "aws_autoscaling_group" "github_actions_asg" {
  desired_capacity     = var.desired_capacity
  max_size             = var.asg_max_size
  min_size             = var.asg_min_size
  vpc_zone_identifier = var.subnet_ids
  launch_template {
    id      = aws_launch_template.github_actions_runner.id
    version = "$Latest"
  }

  # Scaling policies for on-demand adjustment
  tag {
    key                 = "Name"
    value               = "github-actions-runner"
    propagate_at_launch = true
  }
}

output "asg_id" {
  value = aws_autoscaling_group.github_actions_asg.id
}

output "launch_template_id" {
  value = aws_launch_template.github_actions_runner.id
}