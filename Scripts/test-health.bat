@echo off
REM Health Check Testing Script for Pipster Identity Server (Windows)
setlocal enabledelayedexpansion

echo ========================================================
echo    Pipster Identity Server - Health Check Tests
echo ========================================================
echo.

REM Configuration
set BASE_URL=http://localhost:5000
set CONTAINER_NAME=pipster-identity

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running or not installed
    echo Please start Docker Desktop and try again
    exit /b 1
)

REM Check if container is running
docker ps | findstr /C:"%CONTAINER_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Container '%CONTAINER_NAME%' is not running
    echo Run: docker-compose up -d
    exit /b 1
) else (
    echo [OK] Container is running
)

echo.
echo Waiting for application to start (5 seconds grace period)...
timeout /t 5 /nobreak >nul
echo.

REM ========================================
REM Test Endpoints
REM ========================================
echo Testing Health Endpoints
echo ----------------------------
echo.

REM Test 1: Full Health Check
echo Testing Full Health Check (/health)...
curl -s -w "%%{http_code}" -o health_response.tmp %BASE_URL%/health > health_status.tmp 2>nul
set /p HTTP_CODE=<health_status.tmp

if "%HTTP_CODE%"=="200" (
    echo [PASS] Full Health Check - HTTP %HTTP_CODE%
    type health_response.tmp
    echo.
) else (
    echo [FAIL] Full Health Check - HTTP %HTTP_CODE%
    type health_response.tmp
    echo.
)
echo.

REM Test 2: Readiness Probe
echo Testing Readiness Probe (/health/ready)...
curl -s -w "%%{http_code}" -o ready_response.tmp %BASE_URL%/health/ready > ready_status.tmp 2>nul
set /p HTTP_CODE_READY=<ready_status.tmp

if "%HTTP_CODE_READY%"=="200" (
    echo [PASS] Readiness Probe - HTTP %HTTP_CODE_READY%
    type ready_response.tmp
    echo.
) else (
    echo [FAIL] Readiness Probe - HTTP %HTTP_CODE_READY%
    type ready_response.tmp
    echo.
)
echo.

REM Test 3: Liveness Probe
echo Testing Liveness Probe (/health/live)...
curl -s -w "%%{http_code}" -o live_response.tmp %BASE_URL%/health/live > live_status.tmp 2>nul
set /p HTTP_CODE_LIVE=<live_status.tmp

if "%HTTP_CODE_LIVE%"=="200" (
    echo [PASS] Liveness Probe - HTTP %HTTP_CODE_LIVE%
) else (
    echo [FAIL] Liveness Probe - HTTP %HTTP_CODE_LIVE%
)
echo.

REM ========================================
REM Docker Container Health Status
REM ========================================
echo Docker Container Health Status
echo ----------------------------------

REM Get container health status
for /f "tokens=*" %%i in ('docker inspect --format="{{.State.Health.Status}}" %CONTAINER_NAME% 2^>nul') do set HEALTH_STATUS=%%i

if "%HEALTH_STATUS%"=="" (
    echo [WARN] No healthcheck configured in container
) else if "%HEALTH_STATUS%"=="healthy" (
    echo [OK] Container health: %HEALTH_STATUS%
) else (
    echo [WARN] Container health: %HEALTH_STATUS%
)

echo.

REM ========================================
REM Summary
REM ========================================
echo ========================================
echo Health check tests completed!
echo ========================================
echo.

REM Cleanup temp files
del health_response.tmp health_status.tmp ready_response.tmp ready_status.tmp live_response.tmp live_status.tmp 2>nul

echo Tip: Watch health checks in real-time with:
echo   docker logs -f %CONTAINER_NAME%
echo.

endlocal