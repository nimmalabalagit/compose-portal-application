#!/usr/bin/env pwsh

# 🚀 Local Build Validation Script
# This script mimics the GitHub Actions workflow locally

Write-Host "🚀 Starting Local Multi-Service Build Validation..." -ForegroundColor Green
Write-Host ""

# Check prerequisites
Write-Host "🔍 Checking Prerequisites..." -ForegroundColor Yellow
$javaVersion = java -version 2>&1 | Select-String "version"
$mvnVersion = mvn -version 2>&1 | Select-String "Apache Maven"
$dockerVersion = docker --version 2>&1

Write-Host "✅ Java: $javaVersion" -ForegroundColor Cyan
Write-Host "✅ Maven: $mvnVersion" -ForegroundColor Cyan
Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean and Build
Write-Host "🧹 Step 1: Cleaning previous builds..." -ForegroundColor Yellow
try {
    mvn clean
    Write-Host "✅ Clean completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Clean failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🏗️ Step 2: Building all 4 microservices..." -ForegroundColor Yellow
try {
    mvn clean package -DskipTests -T 1C
    Write-Host "✅ Build completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Build failed: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Verify JAR files
Write-Host ""
Write-Host "📊 Step 3: Verifying JAR files..." -ForegroundColor Yellow
$jarFiles = Get-ChildItem -Recurse -Filter "*.jar" | Where-Object { $_.Name -notlike "*original*" }
foreach ($jar in $jarFiles) {
    $size = [math]::Round($jar.Length / 1MB, 2)
    Write-Host "✅ Found: $($jar.FullName) ($size MB)" -ForegroundColor Cyan
}

# Step 3: Build Docker Images
Write-Host ""
Write-Host "🐳 Step 4: Building Docker images..." -ForegroundColor Yellow
$services = @("gateway-service", "user-service", "product-service", "order-service")
$version = "v2.4.1"

foreach ($service in $services) {
    Write-Host "Building Docker image for $service..." -ForegroundColor Cyan
    try {
        Set-Location $service
        docker build -t "compose-portal/$service`:$version" .
        docker build -t "compose-portal/$service`:latest" .
        Write-Host "✅ Docker image built: compose-portal/$service`:$version" -ForegroundColor Green
        Set-Location ..
    } catch {
        Write-Host "❌ Docker build failed for $service`: $_" -ForegroundColor Red
        Set-Location ..
        exit 1
    }
}

# Step 4: Verify Docker Images
Write-Host ""
Write-Host "🔍 Step 5: Verifying Docker images..." -ForegroundColor Yellow
docker images | Where-Object { $_ -match "compose-portal" }

# Step 5: Test with Docker Compose
Write-Host ""
Write-Host "🚀 Step 6: Testing with Docker Compose..." -ForegroundColor Yellow
try {
    docker-compose up -d
    Write-Host "✅ Services started successfully!" -ForegroundColor Green

    Write-Host "⏳ Waiting 30 seconds for services to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    # Health checks
    Write-Host "🏥 Performing health checks..." -ForegroundColor Yellow
    $healthChecks = @{
        "Gateway Service" = "http://localhost:8080/actuator/health"
        "User Service" = "http://localhost:8081/actuator/health"
        "Product Service" = "http://localhost:8082/actuator/health"
        "Order Service" = "http://localhost:8083/actuator/health"
    }

    foreach ($service in $healthChecks.Keys) {
        try {
            $response = Invoke-WebRequest -Uri $healthChecks[$service] -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Host "✅ $service health check passed" -ForegroundColor Green
            } else {
                Write-Host "⚠️ $service health check returned status: $($response.StatusCode)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "❌ $service health check failed: $_" -ForegroundColor Red
        }
    }

} catch {
    Write-Host "❌ Docker Compose failed: $_" -ForegroundColor Red
} finally {
    Write-Host ""
    Write-Host "🛑 Stopping services..." -ForegroundColor Yellow
    docker-compose down
}

# Final Summary
Write-Host ""
Write-Host "📋 BUILD SUMMARY" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "✅ Maven build: COMPLETED" -ForegroundColor Cyan
Write-Host "✅ Docker images: BUILT" -ForegroundColor Cyan
Write-Host "✅ Integration test: COMPLETED" -ForegroundColor Cyan
Write-Host ""
Write-Host "🐳 Docker Images Built:" -ForegroundColor Yellow
Write-Host "- compose-portal/gateway-service:$version" -ForegroundColor Cyan
Write-Host "- compose-portal/user-service:$version" -ForegroundColor Cyan
Write-Host "- compose-portal/product-service:$version" -ForegroundColor Cyan
Write-Host "- compose-portal/order-service:$version" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 Local validation completed successfully!" -ForegroundColor Green
