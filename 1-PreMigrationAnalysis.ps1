# PreMigrationAnalysis.ps1
# This script performs a pre-migration analysis on the Azure DevOps repository.
# It mirror-clones the repository and then gathers relevant details:
# - List of remote branches
# - List of tags
# - Total commit count
#
# Usage:
#   .\1-PreMigrationAnalysis.ps1 -RepoUrl "https://dev.azure.com/YourOrg/YourProject/_git/YourRepo" -LocalPath "C:\Temp\YourRepo"

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoUrl,

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

Write-LogInfo "Starting pre-migration analysis" -Source "PreMigrationAnalysis"
Write-LogInfo "Repository URL: $RepoUrl" -Source "PreMigrationAnalysis"
Write-LogInfo "Local Path: $LocalPath" -Source "PreMigrationAnalysis"

# Remove local path if it already exists to ensure a clean environment
if (Test-Path $LocalPath) {
    Write-LogWarning "Existing directory found. Removing: $LocalPath" -Source "PreMigrationAnalysis"
    try {
        Remove-Item -Recurse -Force $LocalPath
        Write-LogInfo "Successfully removed existing directory" -Source "PreMigrationAnalysis"
    }
    catch {
        Write-LogError "Failed to remove existing directory: $($_.Exception.Message)" -Source "PreMigrationAnalysis" -TerminateScript
    }
}

# Create the local path if it doesn't exist
if (-not (Test-Path $LocalPath)) {
    try {
        New-Item -ItemType Directory -Path $LocalPath -Force
        Write-LogInfo "Successfully created local path: $LocalPath" -Source "PreMigrationAnalysis"
    }
    catch {
        Write-LogError "Failed to create local path: $($_.Exception.Message)" -Source "PreMigrationAnalysis" -TerminateScript
    }
}

# Clone the repository as a mirror, which includes all refs, branches, tags, and full history
Write-LogProgress -Activity "Repository Analysis" -Status "Cloning repository from Azure DevOps" -PercentComplete 25 -Source "PreMigrationAnalysis"

try {
    $gitResult = git clone --mirror $RepoUrl $LocalPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Git clone failed with exit code $LASTEXITCODE. Output: $gitResult"
    }
    Write-LogInfo "Successfully cloned repository" -Source "PreMigrationAnalysis"
}
catch {
    Write-LogError "Clone failed. Check the repository URL and your network connection. Error: $($_.Exception.Message)" -Source "PreMigrationAnalysis" -TerminateScript
}

if (-Not (Test-Path $LocalPath)) {
    Write-LogError "Clone operation completed but local path does not exist: $LocalPath" -Source "PreMigrationAnalysis" -TerminateScript
}

# Change directory into the cloned repository
Push-Location $LocalPath

Write-LogProgress -Activity "Repository Analysis" -Status "Analyzing repository structure" -PercentComplete 50 -Source "PreMigrationAnalysis"

try {
    # Get list of all remote branches
    $branches = git branch -r 2>&1
    if ($LASTEXITCODE -eq 0 -and $branches) {
        $branchCount = ($branches | Measure-Object).Count
        Write-LogInfo "Found $branchCount remote branches in the repository" -Source "PreMigrationAnalysis"
        Write-LogDebug "Remote branches: $($branches -join ', ')" -Source "PreMigrationAnalysis"
    } else {
        Write-LogWarning "No remote branches found or error retrieving branches" -Source "PreMigrationAnalysis"
        $branches = @()
    }

    # Get list of all tags present in the repository
    $tags = git tag 2>&1
    if ($LASTEXITCODE -eq 0 -and $tags) {
        $tagCount = ($tags | Measure-Object).Count
        Write-LogInfo "Found $tagCount tags in the repository" -Source "PreMigrationAnalysis"
        Write-LogDebug "Tags: $($tags -join ', ')" -Source "PreMigrationAnalysis"
    } else {
        Write-LogInfo "No tags found in the repository" -Source "PreMigrationAnalysis"
        $tags = @()
    }

    # Count total number of commits across all refs
    $commitCount = git rev-list --all --count 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-LogInfo "Total commit count in the repository: $commitCount" -Source "PreMigrationAnalysis"
    } else {
        Write-LogWarning "Failed to count commits: $commitCount" -Source "PreMigrationAnalysis"
        $commitCount = "Unknown"
    }
}
catch {
    Write-LogError "Failed to analyze repository: $($_.Exception.Message)" -Source "PreMigrationAnalysis" -TerminateScript
}

Write-LogProgress -Activity "Repository Analysis" -Status "Generating analysis report" -PercentComplete 75 -Source "PreMigrationAnalysis"

# Save repository details into a report file for future reference
$report = @"
Repository URL: $RepoUrl
Local Path: $LocalPath
Analysis Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Branches:
$($branches -join "`n")

Tags:
$($tags -join "`n")

Total Commits: $commitCount
"@

$reportPath = Join-Path $LocalPath "PreMigrationReport.txt"
try {
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-LogInfo "Analysis report saved at: $reportPath" -Source "PreMigrationAnalysis"
}
catch {
    Write-LogWarning "Failed to save analysis report: $($_.Exception.Message)" -Source "PreMigrationAnalysis"
}

Write-LogProgress -Activity "Repository Analysis" -Status "Analysis completed successfully" -PercentComplete 100 -Source "PreMigrationAnalysis"
Write-LogInfo "Pre-migration analysis completed successfully" -Source "PreMigrationAnalysis"

# Revert to the previous directory context
Pop-Location

# Close logging
Close-Logging 