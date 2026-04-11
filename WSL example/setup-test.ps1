# ══════════════════════════════════════════════════════════════
# Claude Agent Kit - Test Environment Setup (WSL2)
# Run this in PowerShell as Administrator
# ══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "   Claude Agent Kit - Test Environment (WSL2)                  " -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Check/Install WSL ──
Write-Host "[>>] Checking WSL..." -ForegroundColor Blue

$wslInstalled = $false
try {
    $wslOutput = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) {
        $wslInstalled = $true
    }
} catch {}

if (-not $wslInstalled) {
    Write-Host "[>>] Installing WSL2 with Ubuntu..." -ForegroundColor Blue
    Write-Host "  This may take a few minutes and require a reboot." -ForegroundColor White
    Write-Host ""

    wsl --install -d Ubuntu

    Write-Host ""
    Write-Host "[!!] WSL installed. You may need to REBOOT your PC." -ForegroundColor Yellow
    Write-Host "  After reboot:" -ForegroundColor White
    Write-Host "  1. Ubuntu will open and ask you to create a user" -ForegroundColor White
    Write-Host "  2. Once done, run this script again" -ForegroundColor White
    Write-Host ""
    exit 0
}

Write-Host "[OK] WSL2 is installed" -ForegroundColor Green

# ── Step 2: Check Ubuntu is available ──
Write-Host "[>>] Checking Ubuntu distribution..." -ForegroundColor Blue

# wsl --list outputs UTF-16 with null bytes, so we clean it before matching
$distroRaw = wsl --list --quiet 2>&1 | Out-String
$distroClean = $distroRaw -replace '\x00', '' -replace '\r', ''

if ($distroClean -match "Ubuntu") {
    Write-Host "[OK] Ubuntu found" -ForegroundColor Green
} else {
    Write-Host "[>>] Installing Ubuntu..." -ForegroundColor Blue
    wsl --install -d Ubuntu
    Write-Host ""
    Write-Host "[!!] Ubuntu installed. Open it from Start menu to finish setup." -ForegroundColor Yellow
    Write-Host "  Create your Linux username and password when prompted." -ForegroundColor White
    Write-Host "  Then run this script again." -ForegroundColor White
    exit 0
}

# ── Step 3: Verify Ubuntu is usable (user created) ──
Write-Host "[>>] Checking Ubuntu is ready..." -ForegroundColor Blue

$testResult = wsl -d Ubuntu -- echo "ok" 2>&1
if ($testResult -match "ok") {
    Write-Host "[OK] Ubuntu is ready" -ForegroundColor Green
} else {
    Write-Host "[!!] Ubuntu is installed but not fully set up." -ForegroundColor Yellow
    Write-Host "  Open Ubuntu from the Start menu to create your user." -ForegroundColor White
    Write-Host "  Then run this script again." -ForegroundColor White
    exit 0
}

# ── Step 4: Ready ──
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "   TEST ENVIRONMENT READY!                                     " -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Enter the test environment:" -ForegroundColor White
Write-Host ""
Write-Host "    wsl -d Ubuntu" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Then run the one-liner installer (same as a real server):" -ForegroundColor White
Write-Host ""
Write-Host "    curl -fsSL https://raw.githubusercontent.com/SamDreamsMaker/claude-remote-kit/main/01-install.sh -o /tmp/install.sh && bash /tmp/install.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Then start Telegram setup:" -ForegroundColor White
Write-Host ""
Write-Host "    ~/claude-remote-kit/02-install-telegram.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "  -- To reset WSL completely: --" -ForegroundColor Yellow
Write-Host ""
Write-Host "    wsl --unregister Ubuntu" -ForegroundColor Cyan
Write-Host "    wsl --install -d Ubuntu" -ForegroundColor Cyan
Write-Host ""
