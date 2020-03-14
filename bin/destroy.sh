#!/usr/bin/env bash

SERVICE=$1

BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name "${SERVICE}-buckets" | jq .Stacks[0].Outputs[0].OutputValue -r)
echo ${BUCKET_NAME}
aws s3 rb s3://${BUCKET_NAME} --force || true

aws cloudformation delete-stack --stack-name ${SERVICE}-dashboard
aws cloudformation delete-stack --stack-name ${SERVICE}-fargate
aws cloudformation delete-stack --stack-name ${SERVICE}-certificate
aws cloudformation delete-stack --stack-name ${SERVICE}-alb
aws cloudformation delete-stack --stack-name ${SERVICE}-vpc
aws cloudformation delete-stack --stack-name ${SERVICE}-buckets
