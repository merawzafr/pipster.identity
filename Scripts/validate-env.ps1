# ====================================
# Pipster Identity Server - Environment Validation Script (PowerShell)
# ====================================
# Validates .env file for security and completeness
# Usage: .\validate-env.ps1
# ====================================

$ErrorActionPreference = "Continue"

# Colors
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Error-Custom { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Warning-Custom { param($Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host "$Message" -ForegroundColor Cyan }

Write-Info "====================================="
Write-Info "Environment Validation"
Write-Info "====================================="
Write-Host ""

# Check if .env exists
if (-not (Test-Path ".env")) {
    Write-Error-Custom ".env file not found!"
    Write-Warning-Custom "Run .\setup-env.ps1 to create it"
    exit 1
}

Write-Success ".env file exists"

# Load .env file
$envVars = @{}
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)\s*=\s*(.+)\s*$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $envVars[$key] = $value
        # Also set as environment variable for this session
        Set-Item -Path "env:$key" -Value $value -ErrorAction SilentlyContinue
    }
}

# Validation counters
$script:ERRORS = 0
$script:WARNINGS = 0

# Function to check required variable
function Test-RequiredVariable {
    param(
        [string]$VarName
    )
    
    if (-not $envVars.ContainsKey($VarName) -or [string]::IsNullOrWhiteSpace($envVars[$VarName])) {
        Write-Error-Custom "$VarName is not set"
        $script:ERRORS++
        return $false
    } else {
        Write-Success "$VarName is set"
        return $true
    }
}

# Function to check for default/insecure values
function Test-NotDefault {
    param(
        [string]$VarName,
        [string]$DefaultPattern
    )
    
    if ($envVars.ContainsKey($VarName) -and $envVars[$VarName] -like "*$DefaultPattern*") {
        Write-Warning-Custom "$VarName contains default/placeholder value"
        $script:WARNINGS++
        return $false
    }
    return $true
}

# Function to check password strength
function Test-PasswordStrength {
    param(
        [string]$VarName
    )
    
    if ($envVars.ContainsKey($VarName)) {
        $password = $envVars[$VarName]
        if ($password.Length -lt 16) {
            Write-Warning-Custom "$VarName is too short (< 16 chars)"
            $script:WARNINGS++
            return $false
        }
    }
    return $true
}

Write-Host ""
Write-Info "Checking required variables..."

# Required variables
$requiredVars = @(
    "ASPNETCORE_ENVIRONMENT",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "POSTGRES_DB",
    "DB_HOST",
    "DB_NAME",
    "DB_USERNAME",
    "DB_PASSWORD",
    "IDENTITYSERVER_ISSUER_URI"
)

foreach ($var in $requiredVars) {
    Test-RequiredVariable $var | Out-Null
}

Write-Host ""
Write-Info "Checking for insecure defaults..."

# Check for default passwords
$environment = $envVars["ASPNETCORE_ENVIRONMENT"]

if ($environment -eq "Production") {
    # Check for any default/weak passwords
    if ($envVars["POSTGRES_PASSWORD"] -eq "postgres" -or $envVars["DB_PASSWORD"] -eq "postgres") {
        Write-Error-Custom "CRITICAL: Using default 'postgres' password in production!"
        Write-Warning-Custom "  Production MUST use unique, strong passwords"
        $script:ERRORS++
    }
    
    # Check if passwords match development defaults
    if ($envVars["POSTGRES_PASSWORD"] -eq "postgres" -or $envVars["DB_PASSWORD"] -eq "postgres") {
        Write-Error-Custom "CRITICAL: Production password matches development default!"
        Write-Warning-Custom "  Each environment must have different credentials"
        $script:ERRORS++
    }
    
    Test-NotDefault "POSTGRES_PASSWORD" "CHANGE_ME" | Out-Null
    Test-NotDefault "DB_PASSWORD" "CHANGE_ME" | Out-Null
    Test-NotDefault "JWT_SIGNING_KEY" "CHANGE_ME" | Out-Null
    Test-NotDefault "DATA_PROTECTION_KEY" "CHANGE_ME" | Out-Null
}

Write-Host ""
Write-Info "Checking password strength..."

if ($environment -eq "Production") {
    Test-PasswordStrength "POSTGRES_PASSWORD" | Out-Null
    Test-PasswordStrength "DB_PASSWORD" | Out-Null
    
    if ($envVars.ContainsKey("JWT_SIGNING_KEY") -and -not [string]::IsNullOrWhiteSpace($envVars["JWT_SIGNING_KEY"])) {
        Test-PasswordStrength "JWT_SIGNING_KEY" | Out-Null
    }
}

Write-Host ""
Write-Info "Checking environment-specific settings..."

# Check issuer URI format
if ($envVars.ContainsKey("IDENTITYSERVER_ISSUER_URI")) {
    $issuerUri = $envVars["IDENTITYSERVER_ISSUER_URI"]
    if ($issuerUri -notmatch '^https?://') {
        Write-Warning-Custom "IDENTITYSERVER_ISSUER_URI should start with http:// or https://"
        $script:WARNINGS++
    }
}

# Production-specific checks
if ($environment -eq "Production") {
    Write-Host ""
    Write-Info "Production-specific checks..."
    
    # Should use HTTPS
    if ($envVars["IDENTITYSERVER_ISSUER_URI"] -notmatch '^https://') {
        Write-Error-Custom "Production should use HTTPS for IDENTITYSERVER_ISSUER_URI"
        $script:ERRORS++
    } else {
        Write-Success "Using HTTPS for issuer URI"
    }
    
    # Should have JWT key
    if (-not $envVars.ContainsKey("JWT_SIGNING_KEY") -or [string]::IsNullOrWhiteSpace($envVars["JWT_SIGNING_KEY"])) {
        Write-Error-Custom "JWT_SIGNING_KEY is required in production"
        $script:ERRORS++
    } else {
        Write-Success "JWT_SIGNING_KEY is set"
    }
    
    # Should have Data Protection key
    if (-not $envVars.ContainsKey("DATA_PROTECTION_KEY") -or [string]::IsNullOrWhiteSpace($envVars["DATA_PROTECTION_KEY"])) {
        Write-Error-Custom "DATA_PROTECTION_KEY is required in production"
        $script:ERRORS++
    } else {
        Write-Success "DATA_PROTECTION_KEY is set"
    }
    
    # Restart policy
    if ($envVars.ContainsKey("RESTART_POLICY") -and $envVars["RESTART_POLICY"] -ne "always") {
        Write-Warning-Custom "Production should use RESTART_POLICY=always"
        $script:WARNINGS++
    }
}

# Check .gitignore
Write-Host ""
Write-Info "Checking .gitignore..."

if (Test-Path ".gitignore") {
    $gitignoreContent = Get-Content ".gitignore" -Raw
    if ($gitignoreContent -match '(?m)^\.env$') {
        Write-Success ".env is in .gitignore"
    } else {
        Write-Error-Custom ".env is NOT in .gitignore!"
        Write-Warning-Custom "  Add '.env' to .gitignore immediately"
        $script:ERRORS++
    }
} else {
    Write-Warning-Custom ".gitignore not found"
    $script:WARNINGS++
}

# Check if .env is committed to git
if (Test-Path ".git") {
    try {
        $gitStatus = git ls-files --error-unmatch .env 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Error-Custom "CRITICAL: .env is tracked by git!"
            Write-Warning-Custom "  Run: git rm --cached .env"
            $script:ERRORS++
        } else {
            Write-Success ".env is not tracked by git"
        }
    } catch {
        Write-Success ".env is not tracked by git"
    }
}

# Summary
Write-Host ""
Write-Info "====================================="
Write-Info "Validation Summary"
Write-Info "====================================="

if ($script:ERRORS -eq 0 -and $script:WARNINGS -eq 0) {
    Write-Success "All checks passed!"
    exit 0
} elseif ($script:ERRORS -eq 0) {
    Write-Warning-Custom "$($script:WARNINGS) warning(s) found"
    Write-Warning-Custom "Review warnings above"
    exit 0
} else {
    Write-Error-Custom "$($script:ERRORS) error(s) found"
    Write-Warning-Custom "$($script:WARNINGS) warning(s) found"
    Write-Host ""
    Write-Error-Custom "Please fix errors before deploying"
    exit 1
}