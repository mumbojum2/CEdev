# PowerShell script for fully automated CEdev repo update on Windows
# Save as update-cedev.ps1 and run with: powershell -ExecutionPolicy Bypass -File update-cedev.ps1

param(
    [switch]$Silent = $false
)
j
$REPO_DIR = "C:\Users\Akiva\Documents\CEdev"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    if (-not $Silent) { Write-Host $logEntry }
}

try {
    Set-Location $REPO_DIR
    Write-Log "Started update in $REPO_DIR"
} catch {
    Write-Log "Failed to change to ${REPO_DIR}: $($_.Exception.Message)"
    exit 1
}

# Stage all changes
git add . 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Log "git add failed"
    exit 1
}

# Check for staged changes and commit
if (-not (git diff-index --quiet HEAD --)) {
    git commit -m "Auto-commit unstaged changes: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Committed unstaged changes"
    } else {
        Write-Log "Commit failed - stashing"
        git stash push -m "Auto-stash before pull: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Stash failed - aborting"
            exit 1
        }
    }
}

# Pull without rebase (uses merge, safer for auto scripts)
git pull origin master 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Log "Pull failed - restoring stash if any"
    git stash pop 2>$null
    exit 1
}

# Stage any new changes from pull
git add . 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Log "git add after pull failed"
    exit 1
}

# Commit if changes
if (-not (git diff-index --quiet HEAD --)) {
    git commit -m "Auto-commit after pull: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Committed changes after pull"
    } else {
        Write-Log "Commit after pull failed - stashing"
        git stash push -m "Auto-stash after pull: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Stash after pull failed"
            exit 1
        }
    }
} else {
    Write-Log "No changes after pull"
}

# Push
git push origin master 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Log "Pushed successfully"
    # Clean up any stashes (pop if exists)
    git stash list 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        git stash pop 2>$null
        Write-Log "Cleaned up stashes"
    }
} else {
    Write-Log "Push failed"
    exit 1
}

Write-Log "Update completed successfully"