#!/usr/bin/env bash

set -eo pipefail

echo "Delete stack fargate-playground..."
aws cloudformation delete-stack --stack-name fargate-playground

echo
echo "Delete stack vpc..."
aws cloudformation delete-stack --stack-name vpc