
# CloudFormation Stacks Deployment Guide

## Overview

This guide explains how to deploy two AWS CloudFormation stacks:

1. **Network Stack**: Sets up the network infrastructure, including VPC, subnets, and other networking resources.
2. **Udagram Stack**: Creates server resources such as EC2 instances, which depend on the network infrastructure established by the Network Stack.

The deployment of the Udagram Stack must occur after the successful creation of the Network Stack, as it relies on resources created by the Network Stack.

## Prerequisites

- AWS CLI installed and configured with appropriate AWS credentials and default region.
- Basic understanding of AWS CloudFormation and the resources being created.

## Steps to Deploy Stacks

### Step 1: Deploy the Network Stack


1. Run the following command to create the Network Stack:
    ```
    aws cloudformation create-stack --stack-name network-stack --template-body file://network.yml --parameters file://network-parameters.json
    ```
2. Wait for the stack creation to complete. This can be monitored in the AWS CloudFormation Console.

### Step 2: Deploy the Udagram Stack

1. Ensure that the Network Stack is in `CREATE_COMPLETE` status.
2. Navigate to the directory where `udagram.yml` is located.
3. Run the following command to create the Udagram Stack:
    ```
    aws cloudformation create-stack --stack-name udagram --template-body file://udagram.yml
    ```
4. Monitor the stack creation in the AWS CloudFormation Console.

## Post-Deployment

After both stacks are successfully created, validate the resources in the AWS Management Console. Ensure that the EC2 instances in the Udagram Stack are correctly configured and can communicate within the network established by the Network Stack.

## Troubleshooting

If stack creation fails, refer to the `Events` tab in the AWS CloudFormation Console for the specific stack. This tab provides detailed error messages that can help in troubleshooting.

## Additional Resources

- [AWS CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/index.html)
- [AWS CLI Command Reference](https://awscli.amazonaws.com/v2/documentation/api/latest/index.html)


