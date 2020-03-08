#!/usr/bin/env bash

set -eo pipefail

# Adapt these variables to your needs
HOSTED_ZONE_NAME="devops-hamburg.de"
CERTIFICATE_ARN="arn:aws:acm:eu-central-1:446914570106:certificate/cc6eb2bd-f88b-47f8-890c-55ae84ad2dd5"
CONTAINER_PORT="443"
HEALTHCHECK_PATH="/"
DOCKER_IMAGE="masterycloud/simplehttp"
SUBNET_TYPE="Public"  # or Private
ASSIGN_PUBLIC_IP="ENABLED"  # should be ENABLED for public subnets without NAT gateway, otherwise DISABLED

echo "Deploy VPC..."
aws cloudformation deploy \
  --template-file cloudformation/vpc.yaml \
  --stack-name vpc \
  --no-fail-on-empty-changeset

VPC_STACK_OUTPUTS=$(aws cloudformation describe-stacks --stack-name vpc | jq .Stacks[0].Outputs)
VPC_ID=$(echo $VPC_STACK_OUTPUTS | jq '. | map(select(.OutputKey == "VPCId")) | .[].OutputValue' -r)
SUBNET_A=$(echo $VPC_STACK_OUTPUTS | jq '. | map(select(.OutputKey == "'${SUBNET_TYPE}'Subnet0")) | .[].OutputValue' -r)
SUBNET_B=$(echo $VPC_STACK_OUTPUTS | jq '. | map(select(.OutputKey == "'${SUBNET_TYPE}'Subnet1")) | .[].OutputValue' -r)

echo
echo "Deploy Fargate playground..."
aws cloudformation deploy \
  --template-file cloudformation/fargate.yaml \
  --stack-name fargate-playground \
  --parameter-overrides \
      Image=${DOCKER_IMAGE} \
      ContainerPort=${CONTAINER_PORT} \
      HealthCheckPath=${HEALTHCHECK_PATH} \
      CertificateArn=${CERTIFICATE_ARN} \
      VpcId=${VPC_ID} \
      SubnetA=${SUBNET_A} \
      SubnetB=${SUBNET_B} \
      AssignPublicIp=${ASSIGN_PUBLIC_IP} \
      HostedZoneName=${HOSTED_ZONE_NAME} \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset