# Terraform: Spot ASG in EKS VPC (Full Stack)

Includes:
- Spot Auto Scaling Group (3)
- User-data bootstrap
- IAM + SSM + CloudWatch
- ALB, Listener, Target Group
- SSM Parameter Store config
- EC2 auto-join EKS cluster

## Prereqs
- Terraform >= 1.6
- AWS CLI configured
- Existing EKS cluster + VPC

## tfvars example
region       = "us-east-1"
vpc_name     = "eks-vpc-main"
cluster_name = "my-eks"
ami_id       = "ami-xxxx"
instance_type= "t3.medium"
app_config   = "Hello from SSM!"

## Deploy
terraform init
terraform plan
terraform apply -auto-approve

## Validate
aws elbv2 describe-load-balancers
aws autoscaling describe-auto-scaling-groups
aws eks list-clusters

## Destroy
terraform destroy -auto-approve
