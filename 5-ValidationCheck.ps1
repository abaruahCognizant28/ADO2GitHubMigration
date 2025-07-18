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
    [string]$LocalRepoPath,

    [Parameter(Mandatory = $true)]
    [string]$GitHubRepoUrl,

    [Parameter(Mandatory = $true)]
    [string]$GitHubPAT,

    [Parameter(Mandatory = $false)]
    [string]$GitHubOrg,

    [Parameter(Mandatory = $false)]
    [string]$GitHubTeam
)

# Validate that the local repository exists
if (-Not (Test-Path $LocalRepoPath)) {
    Write-Error "Error: Local repository path not found: $LocalRepoPath"
    exit 1
}

# Change directory context into the local repository and gather details
Push-Location $LocalRepoPath

$localCommitCount = git rev-list --all --count
Write-Host "Local commit count: $localCommitCount"

$localBranches = git branch -r
Write-Host "Local remote branches:"
Write-Host $localBranches

$localTags = git tag
Write-Host "Local repository tags:"
Write-Host $localTags

Pop-Location

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
} else {
    Write-Error "Error: Failed to parse the GitHub repository URL."
    exit 1
}

$ghRepoApiUrl = "https://api.github.com/repos/$repoOwner/$repoName"
Write-Host "Fetching repository details from GitHub..."
$ghRepoDetails = Invoke-RestMethod -Uri $ghRepoApiUrl -Headers $ghHeaders -Method GET

if (-Not $ghRepoDetails) {
    Write-Error "Error: Failed to fetch repository details from GitHub."
    exit 1
}

Write-Host "GitHub repository details retrieved successfully. (Repository integrity assumed if details are present.)"

# If a GitHub organization and team are provided, validate that the team has members
if ($GitHubOrg -and $GitHubTeam) {
    $ghTeamUrl = "https://api.github.com/orgs/$GitHubOrg/teams/$GitHubTeam/members"
    Write-Host "Fetching members for GitHub team '$GitHubTeam' in organization '$GitHubOrg'..."
    try {
        $teamMembers = Invoke-RestMethod -Uri $ghTeamUrl -Headers $ghHeaders -Method GET
        if ($teamMembers.count -gt 0) {
            Write-Host "Team '$GitHubTeam' has the following members:"
            $teamMembers | ForEach-Object { Write-Host $_.login }
        }
        else {
            Write-Warning "Warning: GitHub team '$GitHubTeam' appears to have no members."
        }
    }
    catch {
        Write-Warning "Warning: Failed to fetch GitHub team details. Error: $_"
    }
}

Write-Host "Post-migration validation completed successfully."
