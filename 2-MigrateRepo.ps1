# MigrateRepo.ps1
# This script migrates a repository from Azure DevOps to GitHub Enterprise.
# It performs a mirror clone to capture all branches, tags, and the complete commit history,
# then mirror-pushes the data to the GitHub Enterprise repository.
#
# Usage:
#   .\MigrateRepo.ps1 -SourceRepoUrl "https://dev.azure.com/YourOrg/YourProject/_git/YourRepo" `
#                     -DestinationRepoUrl "https://github.yourcompany.com/YourOrg/YourRepo.git" `
#                     -LocalPath "C:\Temp\YourRepo"

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceRepoUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationRepoUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$LocalPath,

    [Parameter(Mandatory = $false)]
    [string]$LogFilePath
)

# Import the common logging module with improved path resolution
$scriptDir = if ($PSScriptRoot) { 
    $PSScriptRoot 
} else { 
    Split-Path -Parent $MyInvocation.MyCommand.Path 
}
$loggingModulePath = Join-Path $scriptDir "Common-Logging.psm1"

if (Test-Path $loggingModulePath) {
    Import-Module -Name $loggingModulePath -Force
} else {
    Write-Error "Cannot find Common-Logging.psm1 module at: $loggingModulePath"
    exit 1
}

# Initialize logging
if ($LogFilePath) {
    Initialize-Logging -LogFilePath $LogFilePath -MinimumLogLevel "INFO"
} else {
    Initialize-Logging -MinimumLogLevel "INFO"
}

Write-LogInfo "Starting repository migration" -Source "MigrateRepo"
Write-LogInfo "Source: $SourceRepoUrl" -Source "MigrateRepo"
Write-LogInfo "Destination: $DestinationRepoUrl" -Source "MigrateRepo"
Write-LogInfo "Local Path: $LocalPath" -Source "MigrateRepo"

# Clean-up: Remove any existing directory to ensure a fresh clone
if (Test-Path $LocalPath) {
    Write-LogWarning "Existing directory found. Removing: $LocalPath" -Source "MigrateRepo"
    try {
        Remove-Item -Recurse -Force $LocalPath
        Write-LogInfo "Successfully removed existing directory" -Source "MigrateRepo"
    }
    catch {
        Write-LogError "Failed to remove existing directory: $($_.Exception.Message)" -Source "MigrateRepo" -TerminateScript
    }
}

# Perform a mirror clone from the Azure DevOps repository
Write-LogProgress -Activity "Repository Migration" -Status "Performing mirror clone from Azure DevOps" -PercentComplete 25 -Source "MigrateRepo"

try {
    $gitResult = git clone --mirror $SourceRepoUrl $LocalPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Git clone failed with exit code $LASTEXITCODE. Output: $gitResult"
    }
    Write-LogInfo "Mirror clone successful. Repository available at: $LocalPath" -Source "MigrateRepo"
}
catch {
    Write-LogError "Mirror clone failed. Verify the repository URL and your network connectivity. Error: $($_.Exception.Message)" -Source "MigrateRepo" -TerminateScript
}

if (-Not (Test-Path $LocalPath)) {
    Write-LogError "Clone operation completed but local path does not exist: $LocalPath" -Source "MigrateRepo" -TerminateScript
}

# Change directory context into the cloned repository folder
Push-Location $LocalPath

# Perform a mirror push to the GitHub Enterprise repository
Write-LogProgress -Activity "Repository Migration" -Status "Pushing repository to GitHub Enterprise" -PercentComplete 75 -Source "MigrateRepo"

try {
    $pushResult = git push --mirror $DestinationRepoUrl 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Git push failed with exit code $LASTEXITCODE. Output: $pushResult"
    }
    Write-LogInfo "Successfully pushed repository to GitHub Enterprise" -Source "MigrateRepo"
}
catch {
    Write-LogError "Mirror push failed. Ensure that the destination URL and credentials are correct. Error: $($_.Exception.Message)" -Source "MigrateRepo" -TerminateScript
}

Write-LogProgress -Activity "Repository Migration" -Status "Migration completed successfully" -PercentComplete 100 -Source "MigrateRepo"
Write-LogInfo "Repository successfully migrated to GitHub Enterprise." -Source "MigrateRepo"

# Restore the previous directory context
Pop-Location

# Close logging
Close-Logging 