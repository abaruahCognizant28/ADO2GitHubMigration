# PreMigrationAnalysis.ps1
# This script performs a pre-migration analysis on the Azure DevOps repository.
# It mirror-clones the repository and then gathers relevant details:
# - List of remote branches
# - List of tags
# - Total commit count
#
# Usage:
#   .\PreMigrationAnalysis.ps1 -RepoUrl "https://dev.azure.com/YourOrg/YourProject/_git/YourRepo" -LocalPath "C:\Temp\YourRepo"

param(
    [Parameter(Mandatory = $true)]
    [string]$RepoUrl,

    [Parameter(Mandatory = $true)]
    [string]$LocalPath
)

# Remove local path if it already exists to ensure a clean environment
if (Test-Path $LocalPath) {
    Write-Host "Removing existing directory: $LocalPath"
    Remove-Item -Recurse -Force $LocalPath
}

# Clone the repository as a mirror, which includes all refs, branches, tags, and full history
Write-Host "Cloning the repository from Azure DevOps..."
git clone --mirror $RepoUrl $LocalPath

if (-Not (Test-Path $LocalPath)) {
    Write-Error "Error: Clone failed. Check the repository URL and your network connection."
    exit 1
}

# Change directory into the cloned repository
Push-Location $LocalPath

# Get list of all remote branches
$branches = git branch -r
Write-Host "Remote Branches in the repository:"
Write-Host $branches

# Get list of all tags present in the repository
$tags = git tag
Write-Host "Tags in the repository:"
Write-Host $tags

# Count total number of commits across all refs
$commitCount = git rev-list --all --count
Write-Host "Total commit count in the repository: $commitCount"

# Optionally, save these repository details into a report file for future reference
$report = @"
Repository URL: $RepoUrl
Local Path: $LocalPath

Branches:
$branches

Tags:
$tags

Total Commits: $commitCount
"@
$reportPath = Join-Path $LocalPath "PreMigrationReport.txt"
$report | Out-File -FilePath $reportPath

Write-Host "Pre-migration analysis completed. Report saved at: $reportPath"

# Revert to the previous directory context
Pop-Location
