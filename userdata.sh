#!/bin/bash
set -eux

# Pull config
aws ssm get-parameter --name "/${project}/config" --with-decryption \
  --query Parameter.Value --output text > /etc/${project}.conf || true

# Install agents
yum update -y
yum install -y amazon-ssm-agent jq

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# CloudWatch agent config
cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
{
 "logs": {
   "logs_collected": {
     "files": {
       "collect_list": [
         { "file_path": "/var/log/messages", "log_group_name": "/${project}/app", "log_stream_name": "{instance_id}" }
       ]
     }
   },
   "force_flush_interval": 5
 }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a start -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# EKS bootstrap
/etc/eks/bootstrap.sh ${cluster}

echo "Bootstrapped $(date)" >> /var/log/bootstrap.log
