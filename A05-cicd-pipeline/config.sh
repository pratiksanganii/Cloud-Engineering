#!/bin/bash
# Project 5: Centralized Configuration File
# This file prevents configuration drift by sharing resource names between configure-aws.sh and cleanup-aws.sh

# AWS Region Configuration
export REGION="ap-south-1"

# Resource Names
export ROLE_NAME="GitHubActionsRole"
export OIDC_PROVIDER_URL="https://token.actions.githubusercontent.com"
export OIDC_AUDIENCE="sts.amazonaws.com"
export S3_BUCKET_PREFIX="cicd-artifacts"
export CONFIG_FILE="aws-config.txt"
