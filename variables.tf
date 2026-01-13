variable "region"       { type=string default="us-east-1" }
variable "project_name" { type=string default="eks-spot-asg" }
variable "vpc_name"     { type=string }
variable "cluster_name" { type=string description="EKS cluster name" }
variable "instance_type"{ type=string default="t3.medium" }
variable "ami_id"       { type=string }
variable "app_config"   { type=string default="Hello world" }
