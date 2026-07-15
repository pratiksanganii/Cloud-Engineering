#!/bin/bash
# Project 3: Centralized Configuration File
# This file prevents configuration drift by sharing resource names between deploy.sh and cleanup.sh

# AWS Region Configuration
export REGION="ap-south-1"  # CHANGE THIS Ex: us-east-1, ap-south-1 etc.

# Email Configuration
export SENDER_EMAIL="your-email@example.com"     # CHANGE THIS
export RECIPIENT_EMAIL="your-email@example.com"  # CHANGE THIS

# Resource Names (Do not change unless you want to provision a parallel stack)
export ROLE_NAME="ContactFormLambdaRole"
export FUNCTION_NAME="ContactFormHandler"
export API_NAME="ContactFormAPI"
