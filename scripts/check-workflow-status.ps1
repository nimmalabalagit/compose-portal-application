#!/usr/bin/env pwsh

# 🔍 GitHub Actions Workflow Checker
# This script helps you monitor and validate GitHub Actions workflows

param(
    [string]$Repository = "TechNaidu/compose-portal-service-applications",
    [string]$WorkflowName = "test-aws.yml",
    [switch]$Watch
)

Write-Host "🔍 GitHub Actions Workflow Checker" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host ""

function Show-WorkflowStatus {
    param($Repository, $WorkflowName)

    Write-Host "📊 Repository: $Repository" -ForegroundColor Cyan
    Write-Host "🔧 Workflow: $WorkflowName" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Check if gh CLI is available
        $ghVersion = gh --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ GitHub CLI (gh) is not installed or not in PATH" -ForegroundColor Red
            Write-Host "💡 Install from: https://cli.github.com/" -ForegroundColor Yellow
            return
        }

        Write-Host "✅ GitHub CLI Version: $($ghVersion[0])" -ForegroundColor Green
        Write-Host ""

        # Get workflow runs
        Write-Host "🏃 Recent Workflow Runs:" -ForegroundColor Yellow
        gh run list --repo $Repository --workflow $WorkflowName --limit 10

        Write-Host ""
        Write-Host "📈 Workflow Run Summary:" -ForegroundColor Yellow
        gh run list --repo $Repository --workflow $WorkflowName --limit 5 --json status,conclusion,createdAt,headBranch | ConvertFrom-Json | ForEach-Object {
            $status = $_.status
            $conclusion = $_.conclusion
            $created = [DateTime]::Parse($_.createdAt).ToString("yyyy-MM-dd HH:mm:ss")
            $branch = $_.headBranch

            $statusIcon = switch ($conclusion) {
                "success" { "✅" }
                "failure" { "❌" }
                "cancelled" { "🔶" }
                default { "⏳" }
            }

            Write-Host "$statusIcon Status: $status | Conclusion: $conclusion | Branch: $branch | Created: $created" -ForegroundColor Cyan
        }

    } catch {
        Write-Host "❌ Error checking workflow status: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "💡 Manual Check Instructions:" -ForegroundColor Yellow
        Write-Host "1. Go to: https://github.com/$Repository/actions" -ForegroundColor Cyan
        Write-Host "2. Look for workflow: '$WorkflowName'" -ForegroundColor Cyan
        Write-Host "3. Check recent runs and their status" -ForegroundColor Cyan
    }
}

function Show-ValidationSteps {
    Write-Host ""
    Write-Host "🧪 Workflow Validation Steps:" -ForegroundColor Yellow
    Write-Host "=============================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. 🏗️ Build & Test Services" -ForegroundColor Cyan
    Write-Host "   - Checkout repository" -ForegroundColor Gray
    Write-Host "   - Setup JDK 17" -ForegroundColor Gray
    Write-Host "   - Maven clean package -DskipTests" -ForegroundColor Gray
    Write-Host "   - Run all tests" -ForegroundColor Gray
    Write-Host "   - Upload JAR artifacts" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. 🐳 Build Docker Images (Parallel)" -ForegroundColor Cyan
    Write-Host "   - gateway-service -> compose-portal/gateway-service:v2.4.1" -ForegroundColor Gray
    Write-Host "   - user-service -> compose-portal/user-service:v2.4.1" -ForegroundColor Gray
    Write-Host "   - product-service -> compose-portal/product-service:v2.4.1" -ForegroundColor Gray
    Write-Host "   - order-service -> compose-portal/order-service:v2.4.1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. 🧪 Integration Tests" -ForegroundColor Cyan
    Write-Host "   - Start all services with Docker Compose" -ForegroundColor Gray
    Write-Host "   - Health check all endpoints" -ForegroundColor Gray
    Write-Host "   - Collect logs if failed" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. ☁️ AWS Connection Test (Manual trigger)" -ForegroundColor Cyan
    Write-Host "   - Configure AWS credentials" -ForegroundColor Gray
    Write-Host "   - Test connection with aws sts get-caller-identity" -ForegroundColor Gray
    Write-Host ""
    Write-Host "5. 📋 Build Summary" -ForegroundColor Cyan
    Write-Host "   - Generate comprehensive build report" -ForegroundColor Gray
    Write-Host "   - List all created artifacts" -ForegroundColor Gray
}

# Main execution
Show-WorkflowStatus -Repository $Repository -WorkflowName $WorkflowName
Show-ValidationSteps

if ($Watch) {
    Write-Host ""
    Write-Host "👀 Watching workflow status (press Ctrl+C to stop)..." -ForegroundColor Yellow
    while ($true) {
        Start-Sleep -Seconds 30
        Clear-Host
        Show-WorkflowStatus -Repository $Repository -WorkflowName $WorkflowName
        Write-Host ""
        Write-Host "👀 Auto-refreshing every 30 seconds... ($(Get-Date))" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "🚀 To trigger the workflow manually:" -ForegroundColor Green
Write-Host "gh workflow run test-aws.yml --repo $Repository" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔍 To view detailed logs of latest run:" -ForegroundColor Green
Write-Host "gh run view --repo $Repository" -ForegroundColor Cyan
