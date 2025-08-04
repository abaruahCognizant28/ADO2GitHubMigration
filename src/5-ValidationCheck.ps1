# ValidationCheck.ps1
# This script performs post-migration validation by checking:
# - Local repository integrity (commit count, branches, tags)
# - GitHub repository details via its REST API
# - User/group permissions by checking the membership of a specified GitHub team.
#
# Usage:
#   .\ValidationCheck.ps1 -LocalRepoPath "C:\Temp\YourRepo" `
#                         -GitHubRepoUrl "https://github.yourcompany.com/YourOrg/YourRepo.git" `
#                         -GitHubPAT "YourGitHubPAT" -GitHubOrg "YourGitHubOrg" -GitHubTeam "dev-team"

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_})]
    [string]$LocalRepoPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GitHubRepoUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GitHubPAT,

    [Parameter(Mandatory = $false)]
    [string]$GitHubOrg,

    [Parameter(Mandatory = $false)]
    [string]$GitHubTeam,

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

Write-LogInfo "Starting post-migration validation" -Source "ValidationCheck"
Write-LogInfo "Local Repository Path: $LocalRepoPath" -Source "ValidationCheck"
Write-LogInfo "GitHub Repository URL: $GitHubRepoUrl" -Source "ValidationCheck"
if ($GitHubOrg) { Write-LogInfo "GitHub Organization: $GitHubOrg" -Source "ValidationCheck" }
if ($GitHubTeam) { Write-LogInfo "GitHub Team: $GitHubTeam" -Source "ValidationCheck" }

Write-LogProgress -Activity "Migration Validation" -Status "Analyzing local repository" -PercentComplete 25 -Source "ValidationCheck"

# Change directory context into the local repository and gather details
Push-Location $LocalRepoPath

try {
    $localCommitCount = git rev-list --all --count 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-LogInfo "Local commit count: $localCommitCount" -Source "ValidationCheck"
    } else {
        Write-LogWarning "Failed to get commit count: $localCommitCount" -Source "ValidationCheck"
        $localCommitCount = "Unknown"
    }

    $localBranches = git branch -r 2>&1
    if ($LASTEXITCODE -eq 0 -and $localBranches) {
        $branchCount = ($localBranches | Measure-Object).Count
        Write-LogInfo "Local repository has $branchCount remote branches" -Source "ValidationCheck"
        Write-LogDebug "Local remote branches: $($localBranches -join ', ')" -Source "ValidationCheck"
    } else {
        Write-LogWarning "No remote branches found in local repository" -Source "ValidationCheck"
        $localBranches = @()
    }

    $localTags = git tag 2>&1
    if ($LASTEXITCODE -eq 0 -and $localTags) {
        $tagCount = ($localTags | Measure-Object).Count
        Write-LogInfo "Local repository has $tagCount tags" -Source "ValidationCheck"
        Write-LogDebug "Local repository tags: $($localTags -join ', ')" -Source "ValidationCheck"
    } else {
        Write-LogInfo "No tags found in local repository" -Source "ValidationCheck"
        $localTags = @()
    }
}
catch {
    Write-LogError "Failed to analyze local repository: $($_.Exception.Message)" -Source "ValidationCheck" -TerminateScript
}

Pop-Location

Write-LogProgress -Activity "Migration Validation" -Status "Connecting to GitHub API" -PercentComplete 50 -Source "ValidationCheck"

# Prepare GitHub API headers using the provided personal access token
$ghAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$GitHubPAT"))
$ghHeaders = @{
    Authorization = "Basic $ghAuth"
    "Accept"      = "application/vnd.github.v3+json"
}

# Parse the GitHub repository URL to extract the owner and repository name.
# Expected URL format: https://github.yourcompany.com/OrgName/RepoName.git
if ($GitHubRepoUrl -match "https://[^/]+/([^/]+)/([^/.]+)(\.git)?") {
    $repoOwner = $Matches[1]
    $repoName  = $Matches[2]
    Write-LogInfo "Parsed GitHub repository: Owner='$repoOwner', Name='$repoName'" -Source "ValidationCheck"
} else {
    Write-LogError "Failed to parse the GitHub repository URL: $GitHubRepoUrl" -Source "ValidationCheck" -TerminateScript
}

$ghRepoApiUrl = "https://api.github.com/repos/$repoOwner/$repoName"
Write-LogProgress -Activity "Migration Validation" -Status "Fetching GitHub repository details" -PercentComplete 65 -Source "ValidationCheck"

try {
    $ghRepoDetails = Invoke-RestMethod -Uri $ghRepoApiUrl -Headers $ghHeaders -Method GET -ErrorAction Stop
    Write-LogInfo "GitHub repository details retrieved successfully" -Source "ValidationCheck"
    Write-LogInfo "GitHub repository size: $($ghRepoDetails.size) KB" -Source "ValidationCheck"
    Write-LogInfo "GitHub repository default branch: $($ghRepoDetails.default_branch)" -Source "ValidationCheck"
    Write-LogInfo "GitHub repository creation date: $($ghRepoDetails.created_at)" -Source "ValidationCheck"
    Write-LogInfo "GitHub repository last updated: $($ghRepoDetails.updated_at)" -Source "ValidationCheck"
}
catch {
    Write-LogError "Failed to fetch repository details from GitHub: $($_.Exception.Message)" -Source "ValidationCheck" -TerminateScript
}

# If a GitHub organization and team are provided, validate that the team has members
if ($GitHubOrg -and $GitHubTeam) {
    Write-LogProgress -Activity "Migration Validation" -Status "Validating GitHub team permissions" -PercentComplete 80 -Source "ValidationCheck"
    
    $ghTeamUrl = "https://api.github.com/orgs/$GitHubOrg/teams/$GitHubTeam/members"
    Write-LogInfo "Checking GitHub team '$GitHubTeam' in organization '$GitHubOrg'" -Source "ValidationCheck"
    
    try {
        $teamMembers = Invoke-RestMethod -Uri $ghTeamUrl -Headers $ghHeaders -Method GET -ErrorAction Stop
        if ($teamMembers.count -gt 0) {
            Write-LogInfo "Team '$GitHubTeam' has $($teamMembers.count) members" -Source "ValidationCheck"
            $membersList = ($teamMembers | ForEach-Object { $_.login }) -join ', '
            Write-LogDebug "Team members: $membersList" -Source "ValidationCheck"
        }
        else {
            Write-LogWarning "GitHub team '$GitHubTeam' appears to have no members" -Source "ValidationCheck"
        }
    }
    catch {
        Write-LogWarning "Failed to fetch GitHub team details: $($_.Exception.Message)" -Source "ValidationCheck"
    }
} else {
    Write-LogInfo "GitHub organization and team validation skipped (parameters not provided)" -Source "ValidationCheck"
}

Write-LogProgress -Activity "Migration Validation" -Status "Validation completed successfully" -PercentComplete 100 -Source "ValidationCheck"
Write-LogInfo "Post-migration validation completed successfully" -Source "ValidationCheck"

# Generate validation summary
$validationSummary = @"
=== MIGRATION VALIDATION SUMMARY ===
Local Repository: $LocalRepoPath
- Commit Count: $localCommitCount
- Branches: $(if($localBranches) { $localBranches.Count } else { 0 })
- Tags: $(if($localTags) { $localTags.Count } else { 0 })

GitHub Repository: $GitHubRepoUrl
- Owner: $repoOwner
- Name: $repoName
- Size: $($ghRepoDetails.size) KB
- Default Branch: $($ghRepoDetails.default_branch)
- Last Updated: $($ghRepoDetails.updated_at)

Validation Status: COMPLETED SUCCESSFULLY
"@

Write-LogInfo "Validation Summary:`n$validationSummary" -Source "ValidationCheck"

# Close logging
Close-Logging 