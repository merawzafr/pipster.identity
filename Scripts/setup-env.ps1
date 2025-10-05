# ====================================
# Pipster Identity Server - Environment Setup Script (PowerShell)
# ====================================
# This script helps set up environment files for different environments
# Usage: .\setup-env.ps1 -Environment Development
# ====================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Development", "Staging", "Production")]
    [string]$Environment = "Development",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Pipster Identity Server - Environment Setup" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if .env already exists
$envFile = ".env"
if (Test-Path $envFile) {
    if (-not $Force) {
        Write-Host "ERROR: .env file already exists!" -ForegroundColor Red
        Write-Host "Use -Force to overwrite, or manually edit .env" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Current .env contents:" -ForegroundColor Yellow
        Get-Content $envFile | Select-Object -First 5
        Write-Host "..." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "WARNING: Overwriting existing .env file" -ForegroundColor Yellow
}

# Copy appropriate template
$sourceFile = switch ($Environment) {
    "Development" { ".env.example" }
    "Staging" { ".env.staging" }
    "Production" { ".env.production" }
}

if (-not (Test-Path $sourceFile)) {
    Write-Host "ERROR: Source file $sourceFile not found!" -ForegroundColor Red
    Write-Host "Please ensure .env.example, .env.staging, and .env.production exist" -ForegroundColor Yellow
    exit 1
}

# Copy file
Copy-Item $sourceFile $envFile
Write-Host "✓ Created .env from $sourceFile" -ForegroundColor Green

# For Development: Replace placeholders with development defaults
if ($Environment -eq "Development") {
    (Get-Content $envFile) `
        -replace 'your_secure_password_here', 'postgres' `
        -replace 'your_256_bit_secret_key_here', '' `
        -replace 'your_data_protection_key_here', '' |
        Set-Content $envFile
    Write-Host "✓ Updated .env with development defaults (weak passwords OK for local dev)" -ForegroundColor Green
}

# For Staging/Production: Generate secure passwords
if ($Environment -eq "Staging" -or $Environment -eq "Production") {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Yellow
    Write-Host "GENERATING SECURE PASSWORDS" -ForegroundColor Yellow
    Write-Host "=====================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Generating secure random passwords..." -ForegroundColor Cyan
    
    # Generate secure passwords using RNGCryptoServiceProvider
    function Generate-SecurePassword {
        $bytes = New-Object byte[] 32
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
        return [Convert]::ToBase64String($bytes)
    }
    
    $dbPassword = Generate-SecurePassword
    $jwtKey = Generate-SecurePassword
    $dataProtectionKey = Generate-SecurePassword
    
    Write-Host ""
    Write-Host "Generated secure credentials:" -ForegroundColor Green
    Write-Host "DB Password: $dbPassword" -ForegroundColor Yellow
    Write-Host "JWT Signing Key: $jwtKey" -ForegroundColor Yellow
    Write-Host "Data Protection Key: $dataProtectionKey" -ForegroundColor Yellow
    Write-Host ""
    
    if ($Environment -eq "Production") {
        Write-Host "CRITICAL: Store these in Azure Key Vault!" -ForegroundColor Red
        Write-Host "CRITICAL: Never commit .env to version control!" -ForegroundColor Red
        Write-Host ""
    }
    
    # Replace placeholders with generated passwords
    (Get-Content $envFile) `
        -replace 'CHANGE_ME_STAGING_PASSWORD', $dbPassword `
        -replace 'CHANGE_ME_USE_AZURE_KEY_VAULT', $dbPassword `
        -replace 'CHANGE_ME_GENERATE_SECURE_KEY', $jwtKey `
        -replace 'your_secure_password_here', $dbPassword `
        -replace 'your_256_bit_secret_key_here', $jwtKey `
        -replace 'your_data_protection_key_here', $dataProtectionKey |
        Set-Content $envFile
    
    # Add keys to .env if they're commented out
    $envContent = Get-Content $envFile -Raw
    if ($envContent -notmatch 'JWT_SIGNING_KEY=\S') {
        Add-Content $envFile "`nJWT_SIGNING_KEY=$jwtKey"
    }
    if ($envContent -notmatch 'DATA_PROTECTION_KEY=\S') {
        Add-Content $envFile "`nDATA_PROTECTION_KEY=$dataProtectionKey"
    }
    
    Write-Host "✓ Updated .env with generated secure passwords" -ForegroundColor Green
}

# Show next steps
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Review and edit .env file:" -ForegroundColor Yellow
Write-Host "   code .env" -ForegroundColor White
Write-Host ""
Write-Host "2. Verify configuration:" -ForegroundColor Yellow
Write-Host "   docker-compose config" -ForegroundColor White
Write-Host ""
Write-Host "3. Start services:" -ForegroundColor Yellow
Write-Host "   docker-compose up -d" -ForegroundColor White
Write-Host ""
Write-Host "4. Check health:" -ForegroundColor Yellow
Write-Host "   .\scripts\test-health.ps1" -ForegroundColor White
Write-Host ""

if ($Environment -eq "Production") {
    Write-Host "=====================================" -ForegroundColor Red
    Write-Host "PRODUCTION CHECKLIST" -ForegroundColor Red
    Write-Host "=====================================" -ForegroundColor Red
    Write-Host "[ ] Change all default passwords" -ForegroundColor Yellow
    Write-Host "[ ] Store secrets in Azure Key Vault" -ForegroundColor Yellow
    Write-Host "[ ] Configure SSL/TLS certificates" -ForegroundColor Yellow
    Write-Host "[ ] Set up database backups" -ForegroundColor Yellow
    Write-Host "[ ] Enable monitoring & alerting" -ForegroundColor Yellow
    Write-Host "[ ] Verify .env is in .gitignore" -ForegroundColor Yellow
    Write-Host "[ ] Test disaster recovery" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "✓ Environment setup complete!" -ForegroundColor Green
Write-Host ""