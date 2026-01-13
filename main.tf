terraform {
  required_version = ">= 1.6.0"
  required_providers { aws = { source="hashicorp/aws" version="~>5.0"} }
}

provider "aws" { region = var.region }

data "aws_vpc" "eks" {
  filter { name="tag:Name" values=[var.vpc_name] }
}
data "aws_subnets" "eks" {
  filter { name="vpc-id" values=[data.aws_vpc.eks.id] }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions=["sts:AssumeRole"]
    principals { type="Service" identifiers=["ec2.amazonaws.com"] }
  }
}

resource "aws_ssm_parameter" "app_config" {
  name  = "/${var.project_name}/config"
  type  = "String"
  value = var.app_config
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "base" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "cw" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-sg"
  vpc_id      = data.aws_vpc.eks.id
  ingress { from_port=22 to_port=22 protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
  egress  { from_port=0 to_port=0 protocol="-1" cidr_blocks=["0.0.0.0/0"] }
}

resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.eks.ids
  security_groups    = [aws_security_group.ec2_sg.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.eks.id
  health_check { path="/" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${var.project_name}-lt"
  image_id      = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile { name = aws_iam_instance_profile.ec2_profile.name }
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  instance_market_options { market_type = "spot" }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    cluster = var.cluster_name
    project = var.project_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = { Name = var.project_name }
  }
}

resource "aws_autoscaling_group" "asg" {
  name                = "${var.project_name}-asg"
  max_size            = 3
  min_size            = 3
  desired_capacity    = 3
  vpc_zone_identifier = data.aws_subnets.eks.ids

  launch_template { id = aws_launch_template.lt.id version = "$Latest" }

  target_group_arns = [aws_lb_target_group.tg.arn]

  tag { key="Name" value=var.project_name propagate_at_launch=true }

  lifecycle { ignore_changes=[desired_capacity] }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/app"
  retention_in_days = 7
}
