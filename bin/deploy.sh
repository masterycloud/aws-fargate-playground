#!/usr/bin/env bash

set -eo pipefail

NAME=$1
HOSTED_ZONE_NAME="devops-hamburg.de"
DOMAIN="${NAME}.${HOSTED_ZONE_NAME}"
DOCKER_IMAGE="masterycloud/simplehttp"
LOAD_BALANCER_PORT="443"
HOST_PORT="443"
CONTAINER_PORT="443"
DESIRED_COUNT=2
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones | jq '.HostedZones | map(select(.Name == "'${HOSTED_ZONE_NAME}'.")) | .[0].Id' -r)
APPLICATION_PROTOCOL="HTTPS"

function get-cf-output-value {
    STACK_NAME=$1
    OUTPUT_KEY=$2
    aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
    | jq .[][].Outputs | jq '. | map(select(.OutputKey == "'${OUTPUT_KEY}'")) | .[0].OutputValue' -r
}

echo
echo ">>> Deploy VPC..."
aws cloudformation deploy \
    --template-file cloudformation/vpc.yaml \
    --stack-name ${NAME}-vpc \
    --parameter-overrides \
        VPCName="${NAME}-vpc" \
    --no-fail-on-empty-changeset

# Retrieve vpc outputs
VPC_ID=$(get-cf-output-value ${NAME}-vpc "VPCId")
SUBNET_A=$(get-cf-output-value ${NAME}-vpc "PrivateSubnet0")
SUBNET_B=$(get-cf-output-value ${NAME}-vpc "PrivateSubnet1")

echo
echo ">>> Deploy elastic load balancer v2 (ALB)..."
aws cloudformation deploy \
    --template-file cloudformation/alb.yaml \
    --stack-name ${NAME}-alb \
    --parameter-overrides \
        VpcId="${VPC_ID}" \
        SubnetA="${SUBNET_A}" \
        SubnetB="${SUBNET_B}" \
        HostedZoneId="${HOSTED_ZONE_ID}" \
        DomainName="${DOMAIN}" \
    --no-fail-on-empty-changeset

LOAD_BALANCER_ARN=$(get-cf-output-value ${NAME}-alb LoadBalancer)
LOAD_BALANCER_SG_ID=$(get-cf-output-value ${NAME}-alb LoadBalancerSecurityGroupId)


echo
echo ">>> Deploy SSL certificate..."
aws cloudformation deploy \
    --template-file cloudformation/certificate.yaml \
    --stack-name ${NAME}-certificate \
    --parameter-overrides \
        Subdomain=${NAME} \
        DomainName=${DOMAIN} \
    --no-fail-on-empty-changeset

SSL_CERTIFICATE_ARN=$(get-cf-output-value ${NAME}-certificate Certificate)

echo
echo ">>> Deploy fargate..."
aws cloudformation deploy \
    --template-file cloudformation/fargate.yaml \
    --stack-name ${NAME}-fargate \
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
        SubnetA="${SUBNET_A}" \
        SubnetB="${SUBNET_B}" \
        ApplicationProtocol="${APPLICATION_PROTOCOL}" \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset