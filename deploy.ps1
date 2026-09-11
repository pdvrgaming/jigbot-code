<#
.SYNOPSIS
    Automated dual-repo deployment script for Jigurujingania Bot by PDVR.
    Pushes private source code (including .mq5) to your Private Repository,
    and publishes clean website/release assets (strictly without .mq5) to GitHub Pages.
.EXAMPLE
    .\deploy.ps1 "Updated bot trial period and website theme"
#>

param(
    [string]$CommitMessage = "Update Jigurujingania Bot and Website $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
)

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  JIGURUJINGANIA BOT - DUAL-REPO AUTOMATION & DEPLOYMENT" -ForegroundColor Cyan
Write-Host "  Powered by Razel Tech" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$WorkspaceRoot = $PSScriptRoot
$PublicDir = Join-Path $WorkspaceRoot "public_pages"
$MetaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$BotMq5 = Join-Path $WorkspaceRoot "Jigurujingania_Bot_PDVR.mq5"
$BotEx5 = Join-Path $WorkspaceRoot "Jigurujingania_Bot_PDVR.ex5"

# 1. COMPILE BOT TO .EX5
if (Test-Path $MetaEditor) {
    Write-Host "`n[STEP 1/4] Compiling $BotMq5 to EX5..." -ForegroundColor Yellow
    Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$BotMq5`"" -Wait
    Start-Sleep -Seconds 2
    if (Test-Path $BotEx5) {
        Write-Host "  [OK] EX5 compiled successfully! ($( (Get-Item $BotEx5).Length ) bytes)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] EX5 file not found after compile check." -ForegroundColor Yellow
    }
} else {
    Write-Host "`n[STEP 1/4] MetaEditor not found, skipping compile." -ForegroundColor Gray
}

# 2. PREPARE PUBLIC PAGES DIRECTORY
Write-Host "`n[STEP 2/4] Syncing public website files to public_pages/ (Strictly zero .mq5)..." -ForegroundColor Yellow

if (!(Test-Path $PublicDir)) {
    New-Item -ItemType Directory -Path $PublicDir | Out-Null
}

# Copy public files only
Copy-Item (Join-Path $WorkspaceRoot "index.html") -Destination (Join-Path $PublicDir "index.html") -Force
if (Test-Path $BotEx5) {
    Copy-Item $BotEx5 -Destination (Join-Path $PublicDir "Jigurujingania_Bot_PDVR.ex5") -Force
}

# Create .gitignore in public_pages that permanently blocks any mq5 files
$PublicGitIgnore = @"
# ZERO-LEAK SECURITY: Strict block on all MQL5 source code files
*.mq5
*.mq4
*.mqh
*.cpp
*.h
*.log
"@
Set-Content -Path (Join-Path $PublicDir ".gitignore") -Value $PublicGitIgnore -Encoding UTF8
Write-Host "  [OK] Public pages synced. Protected by zero-leak .gitignore." -ForegroundColor Green

# 3. COMMIT & PUSH PRIVATE REPO
Write-Host "`n[STEP 3/4] Checking Private Repository (Source of Truth)..." -ForegroundColor Yellow
Set-Location $WorkspaceRoot

if (Test-Path (Join-Path $WorkspaceRoot ".git")) {
    git add -A
    $status = git status --porcelain
    if ($status) {
        git commit -m $CommitMessage
        Write-Host "  Committed changes to private repo." -ForegroundColor Green
        # Push to origin if remote exists
        $hasRemote = git remote
        if ($hasRemote -contains "origin") {
            Write-Host "  Pushing to private repository (origin)..." -ForegroundColor Cyan
            git push origin
        } else {
            Write-Host "  [NOTE] No remote 'origin' configured yet. Set with: git remote add origin <PRIVATE_REPO_URL>" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No changes to commit in private repo." -ForegroundColor Gray
    }
} else {
    Write-Host "  Private repository not initialized. Initializing git..." -ForegroundColor Cyan
    git init
    git add -A
    git commit -m "Initial commit: Jigurujingania Bot private source"
    Write-Host "  [OK] Private git initialized. Set remote with: git remote add origin <PRIVATE_REPO_URL>" -ForegroundColor Green
}

# 4. COMMIT & PUSH PUBLIC GITHUB PAGES REPO
Write-Host "`n[STEP 4/4] Checking Public GitHub Pages Repository..." -ForegroundColor Yellow
Set-Location $PublicDir

if (Test-Path (Join-Path $PublicDir ".git")) {
    git add -A
    $pubStatus = git status --porcelain
    if ($pubStatus) {
        git commit -m $CommitMessage
        Write-Host "  Committed changes to public GitHub Pages repo." -ForegroundColor Green
        $hasPubRemote = git remote
        if ($hasPubRemote -contains "origin") {
            Write-Host "  Pushing to public GitHub Pages (origin)..." -ForegroundColor Cyan
            git push origin main
        } else {
            Write-Host "  [NOTE] Set public remote inside public_pages with: git remote add origin <PUBLIC_PAGES_REPO_URL>" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No changes to commit in public repo." -ForegroundColor Gray
    }
} else {
    Write-Host "  Public pages git not initialized. Initializing git inside public_pages/..." -ForegroundColor Cyan
    git init -b main
    git add -A
    git commit -m "Initial release: Jigurujingania Bot website and EX5"
    Write-Host "  [OK] Public pages git initialized. Set remote with:" -ForegroundColor Green
    Write-Host "       cd public_pages; git remote add origin <PUBLIC_GITHUB_PAGES_REPO_URL>" -ForegroundColor Gray
}

Set-Location $WorkspaceRoot
Write-Host "`n======================================================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT SYNC COMPLETE!" -ForegroundColor Green
Write-Host "======================================================================`n" -ForegroundColor Green
