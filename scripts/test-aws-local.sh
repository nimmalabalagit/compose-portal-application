#!/bin/bash

# AWS Connection Test Script
# This script helps verify AWS setup locally (if AWS CLI is installed)

echo "🔍 Checking AWS CLI installation..."
if command -v aws &> /dev/null; then
    echo "✅ AWS CLI is installed"
    aws --version
else
    echo "❌ AWS CLI is not installed"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

echo ""
echo "🔍 Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    echo "✅ AWS credentials are configured correctly"
    aws sts get-caller-identity
else
    echo "❌ AWS credentials are not configured or invalid"
    echo "Please run: aws configure"
    exit 1
fi

echo ""
echo "🎉 AWS connection test completed successfully!"
