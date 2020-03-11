#!/usr/bin/env bash

set -eo pipefail

NAME=$1

echo ">>> Delete stack fargate-playground..."
aws cloudformation delete-stack --stack-name ${NAME}-fargate

echo
echo ">>> Delete stack alb..."
aws cloudformation delete-stack --stack-name ${NAME}-alb

echo
echo ">>> Delete stack certificate..."
aws cloudformation delete-stack --stack-name ${NAME}-certificate

echo
echo ">>> Delete stack vpc..."
aws cloudformation delete-stack --stack-name ${NAME}-vpc
