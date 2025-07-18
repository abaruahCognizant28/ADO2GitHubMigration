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
    [string]$SourceRepoUrl,

    [Parameter(Mandatory = $true)]
    [string]$DestinationRepoUrl,

    [Parameter(Mandatory = $true)]
    [string]$LocalPath
)

# Clean-up: Remove any existing directory to ensure a fresh clone
if (Test-Path $LocalPath) {
    Write-Host "Removing existing directory: $LocalPath"
    Remove-Item -Recurse -Force $LocalPath
}

# Perform a mirror clone from the Azure DevOps repository
Write-Host "Performing mirror clone from Azure DevOps..."
git clone --mirror $SourceRepoUrl $LocalPath

if (-Not (Test-Path $LocalPath)) {
    Write-Error "Error: Mirror clone failed. Verify the repository URL and your network connectivity."
    exit 1
}

Write-Host "Mirror clone successful. Repository available at: $LocalPath"

# Change directory context into the cloned repository folder
Push-Location $LocalPath

# Perform a mirror push to the GitHub Enterprise repository
Write-Host "Pushing repository to GitHub Enterprise..."
git push --mirror $DestinationRepoUrl

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: Mirror push failed. Ensure that the destination URL and credentials are correct."
    exit 1
}

Write-Host "Repository successfully migrated to GitHub Enterprise."

# Restore the previous directory context
Pop-Location
