# AWS Connection Test Script for Windows PowerShell
# This script helps verify AWS setup locally (if AWS CLI is installed)

Write-Host "🔍 Checking AWS CLI installation..." -ForegroundColor Cyan

try {
    $awsVersion = aws --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ AWS CLI is installed" -ForegroundColor Green
        Write-Host $awsVersion -ForegroundColor Gray
    } else {
        throw "AWS CLI not found"
    }
} catch {
    Write-Host "❌ AWS CLI is not installed" -ForegroundColor Red
    Write-Host "Please install AWS CLI: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "🔍 Checking AWS credentials..." -ForegroundColor Cyan

try {
    $callerIdentity = aws sts get-caller-identity 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ AWS credentials are configured correctly" -ForegroundColor Green
        Write-Host $callerIdentity -ForegroundColor Gray
    } else {
        throw "AWS credentials invalid"
    }
} catch {
    Write-Host "❌ AWS credentials are not configured or invalid" -ForegroundColor Red
    Write-Host "Please run: aws configure" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "🎉 AWS connection test completed successfully!" -ForegroundColor Green
