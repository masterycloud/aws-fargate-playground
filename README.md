# aws-fargate-playground

This project serves as a playground for AWS Fargate and related
resources. AWS Fargate is a serverless compute engine for containers
that works with both Amazon Elastic Container Service (ECS) and
Amazon Elastic Kubernetes Service (EKS).

## Infrastructure

![Infrastructure](./infrastructure.png)

## Deploy

You can deploy the fargate-playground with

```
./bin/deploy.sh
```

Before executing this script you should open it and change the values
for `HOSTED_ZONE_NAME` and `CERTIFICATE_ARN`. For these values you
need to setup a hosted zone for a given domain name in AWS Route53
and an SSL certificate in AWS ACM for `playground.<your-domain>`.

## Test

In order to see the autoscaling work run a HTTP benchmark tool like
[hey](https://github.com/rakyll/hey) like so

```
hey -n 10000000 -c 1000 https://playground.<your domain>
```

Then navigate to the AWS ECS console and wait until the average
load of any running ECS tasks exceeds the given threshold of 50%.
This event will trigger ECS to create more tasks.