#!/usr/bin/env bash

set -eo pipefail

# Used in Cloudformation stack names so that each user can deploy stacks
SERVICE=$1
HOSTED_ZONE_NAME="devops-hamburg.de"
DOMAIN_NAME="${SERVICE}.${HOSTED_ZONE_NAME}"
DOCKER_IMAGE="rancher/hello-world"
LOAD_BALANCER_PORT="443"
HOST_PORT="80"
CONTAINER_PORT="80"
DESIRED_COUNT=2
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones | jq '.HostedZones | map(select(.Name == "'${HOSTED_ZONE_NAME}'.")) | .[0].Id' -r)
APPLICATION_PROTOCOL="HTTP"
BUCKET_PREFIX="${SERVICE}"
MIN_CAPACITY="2"
MAX_CAPACITY="16"
CPU="256"
MEMORY="512"
CPU_TARGET_VALUE_FOR_SCALING="10" # average cpu utilization in per cent

function get-cf-output-value {
    STACK_NAME=$1
    OUTPUT_KEY=$2
    aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
    | jq .[][].Outputs | jq '. | map(select(.OutputKey == "'${OUTPUT_KEY}'")) | .[0].OutputValue' -r
}

echo
echo ">>> Deploy buckets..."
aws cloudformation deploy \
    --template-file cloudformation/buckets.yaml \
    --stack-name ${SERVICE}-buckets \
    --parameter-overrides \
        BucketPrefix="${BUCKET_PREFIX}" \
    --no-fail-on-empty-changeset

LOGS_BUCKET=$(get-cf-output-value ${SERVICE}-buckets LogsBucket)

echo
echo ">>> Deploy VPC..."
aws cloudformation deploy \
    --template-file cloudformation/vpc.yaml \
    --stack-name ${SERVICE}-vpc \
    --parameter-overrides \
        VPCName="${SERVICE}-vpc" \
    --no-fail-on-empty-changeset

# Retrieve vpc outputs
VPC_ID=$(get-cf-output-value ${SERVICE}-vpc "VPCId")
PUBLIC_SUBNET_A=$(get-cf-output-value ${SERVICE}-vpc "PublicSubnet0")
PUBLIC_SUBNET_B=$(get-cf-output-value ${SERVICE}-vpc "PublicSubnet1")
PRIVATE_SUBNET_A=$(get-cf-output-value ${SERVICE}-vpc "PrivateSubnet0")
PRIVATE_SUBNET_B=$(get-cf-output-value ${SERVICE}-vpc "PrivateSubnet1")

echo
echo ">>> Deploy elastic load balancer v2 (ALB)..."
aws cloudformation deploy \
    --template-file cloudformation/alb.yaml \
    --stack-name ${SERVICE}-alb \
    --parameter-overrides \
        VpcId="${VPC_ID}" \
        PublicSubnetA="${PUBLIC_SUBNET_A}" \
        PublicSubnetB="${PUBLIC_SUBNET_B}" \
        HostedZoneId="${HOSTED_ZONE_ID}" \
        DomainName="${DOMAIN_NAME}" \
        LogsBucket="${LOGS_BUCKET}" \
    --no-fail-on-empty-changeset

LOAD_BALANCER_ARN=$(get-cf-output-value ${SERVICE}-alb LoadBalancer)
LOAD_BALANCER_SG_ID=$(get-cf-output-value ${SERVICE}-alb LoadBalancerSecurityGroupId)

echo
echo ">>> Deploy SSL certificate..."
aws cloudformation deploy \
    --template-file cloudformation/certificate.yaml \
    --stack-name ${SERVICE}-certificate \
    --parameter-overrides \
        Subdomain=${SERVICE} \
        DomainName=${DOMAIN_NAME} \
    --no-fail-on-empty-changeset

SSL_CERTIFICATE_ARN=$(get-cf-output-value ${SERVICE}-certificate Certificate)

echo
echo ">>> Deploy fargate..."
aws cloudformation deploy \
    --template-file cloudformation/fargate.yaml \
    --stack-name ${SERVICE}-fargate \
    --parameter-overrides \
        VpcId="${VPC_ID}" \
        LoadBalancerArn="${LOAD_BALANCER_ARN}" \
        SslCertificateArn="${SSL_CERTIFICATE_ARN}" \
        LoadBalancerPort="${LOAD_BALANCER_PORT}" \
        HostPort="${HOST_PORT}" \
        ContainerPort="${CONTAINER_PORT}" \
        DockerImage="${DOCKER_IMAGE}" \
        DesiredCount="${DESIRED_COUNT}" \
        LoadBalancerSecurityGroupId="${LOAD_BALANCER_SG_ID}" \
        SubnetA="${PRIVATE_SUBNET_A}" \
        SubnetB="${PRIVATE_SUBNET_B}" \
        ApplicationProtocol="${APPLICATION_PROTOCOL}" \
        MinCapacity="${MIN_CAPACITY}" \
        MaxCapacity="${MAX_CAPACITY}" \
        Cpu="${CPU}" \
        Memory="${MEMORY}" \
        CpuTargetValueForScaling="${CPU_TARGET_VALUE_FOR_SCALING}" \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset

CLUSTER_NAME=$(get-cf-output-value ${SERVICE}-fargate ClusterName)
SERVICE_NAME=$(get-cf-output-value ${SERVICE}-fargate ServiceName)

echo
echo ">>> Deploy dashboard..."
aws cloudformation deploy \
    --template-file cloudformation/dashboard.yaml \
    --stack-name ${SERVICE}-dashboard \
    --parameter-overrides \
        ClusterName="${CLUSTER_NAME}" \
        ServiceName="${SERVICE_NAME}" \
    --no-fail-on-empty-changeset
