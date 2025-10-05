# Health Check Testing Script for Pipster Identity Server (PowerShell)

# Configuration
$BaseUrl = "http://localhost:5000"
$ContainerName = "pipster-identity"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   Pipster Identity Server - Health Check Tests" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
try {
    docker info | Out-Null
    Write-Host "[OK] Docker is running" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker is not running or not installed" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again" -ForegroundColor Yellow
    exit 1
}

# Check if container is running
$containerRunning = docker ps --format "{{.Names}}" | Select-String -Pattern $ContainerName -Quiet

if (-not $containerRunning) {
    Write-Host "[ERROR] Container '$ContainerName' is not running" -ForegroundColor Red
    Write-Host "Run: docker-compose up -d" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "[OK] Container is running" -ForegroundColor Green
}

Write-Host ""
Write-Host "Waiting for application to start (5 seconds grace period)..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
Write-Host ""

# Function to test endpoint
function Test-HealthEndpoint {
    param(
        [string]$Endpoint,
        [string]$Name
    )
    
    Write-Host "Testing $Name ($Endpoint)..." -ForegroundColor Cyan
    
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl$Endpoint" -Method Get -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-Host "[PASS] $Name - HTTP $($response.StatusCode)" -ForegroundColor Green
            
            # Pretty print JSON if available
            if ($response.Content) {
                try {
                    $json = $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
                    Write-Host $json -ForegroundColor Gray
                } catch {
                    Write-Host $response.Content -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "[FAIL] $Name - HTTP $($response.StatusCode)" -ForegroundColor Red
            Write-Host $response.Content -ForegroundColor Gray
        }
    } catch {
        Write-Host "[FAIL] $Name - Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Test endpoints
Write-Host "Testing Health Endpoints" -ForegroundColor Cyan
Write-Host "----------------------------" -ForegroundColor Cyan
Write-Host ""

Test-HealthEndpoint -Endpoint "/health" -Name "Full Health Check"
Test-HealthEndpoint -Endpoint "/health/ready" -Name "Readiness Probe"
Test-HealthEndpoint -Endpoint "/health/live" -Name "Liveness Probe"

# Docker Container Health Status
Write-Host "Docker Container Health Status" -ForegroundColor Cyan
Write-Host "----------------------------------" -ForegroundColor Cyan

try {
    $healthStatus = docker inspect --format='{{.State.Health.Status}}' $ContainerName 2>$null
    
    if ($healthStatus) {
        if ($healthStatus -eq "healthy") {
            Write-Host "[OK] Container health: $healthStatus" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Container health: $healthStatus" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[WARN] No healthcheck configured in container" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARN] Could not get container health status" -ForegroundColor Yellow
}

Write-Host ""

# Recent health check logs
Write-Host "Recent Health Check Logs (Last 3 entries)" -ForegroundColor Cyan
Write-Host "------------------------------------" -ForegroundColor Cyan

try {
    $healthLogs = docker inspect $ContainerName | ConvertFrom-Json
    $logs = $healthLogs.State.Health.Log | Select-Object -Last 3
    
    if ($logs) {
        $logs | ForEach-Object {
            Write-Host "Time: $($_.Start)" -ForegroundColor Gray
            Write-Host "Exit Code: $($_.ExitCode)" -ForegroundColor Gray
            Write-Host "Output: $($_.Output)" -ForegroundColor Gray
            Write-Host ""
        }
    } else {
        Write-Host "No health logs available" -ForegroundColor Gray
    }
} catch {
    Write-Host "Could not retrieve health logs" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Health check tests completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Tip: Watch health checks in real-time:" -ForegroundColor Yellow
Write-Host "  docker logs -f $ContainerName | Select-String -Pattern 'health'" -ForegroundColor Gray
Write-Host ""