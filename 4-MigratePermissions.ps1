# MigratePermissions.ps1
# This script migrates repository permissions from Azure DevOps to GitHub Enterprise.
# It uses a mapping configuration (in JSON format) that defines the relationship between
# Azure DevOps groups and GitHub teams.
#
# Usage:
#   .\MigratePermissions.ps1 -AzureDevOpsOrg "YourOrg" -Project "YourProject" `
#                     -RepositoryName "YourRepo" -AzureDevOpsPAT "YourDevOpsPAT" `
#                     -GitHubOrg "YourGitHubOrg" -GitHubRepo "YourRepo" -GitHubPAT "YourGitHubPAT" `
#                     -MappingFilePath "C:\Path\To\Mapping.json"

param(
    [Parameter(Mandatory = $true)]
    [string]$AzureDevOpsOrg,

    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,

    [Parameter(Mandatory = $true)]
    [string]$AzureDevOpsPAT,

    [Parameter(Mandatory = $true)]
    [string]$GitHubOrg,

    [Parameter(Mandatory = $true)]
    [string]$GitHubRepo,

    [Parameter(Mandatory = $true)]
    [string]$GitHubPAT,

    [Parameter(Mandatory = $true)]
    [string]$MappingFilePath
)

# Prepare authorization headers for both Azure DevOps and GitHub APIs
$azDevOpsAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$AzureDevOpsPAT"))
$ghAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$GitHubPAT"))

$azHeaders = @{
    Authorization = "Basic $azDevOpsAuth"
    "Content-Type" = "application/json"
}

$ghHeaders = @{
    Authorization = "Basic $ghAuth"
    "Content-Type" = "application/json"
}

# Load the mapping configuration from a JSON file.
# Expected structure (example):
# [
#   {
#     "AzureDevOpsGroup": "Developers",
#     "GitHubTeam": "dev-team",
#     "Permission": "push"     # Options might be: push, pull, or admin
#   },
#   {
#     "AzureDevOpsGroup": "Testers",
#     "GitHubTeam": "qa-team",
#     "Permission": "pull"
#   }
# ]
if (-Not (Test-Path $MappingFilePath)) {
    Write-Error "Error: Mapping file not found at: $MappingFilePath"
    exit 1
}
$mappingConfig = Get-Content $MappingFilePath | ConvertFrom-Json

# Fetch permissions for the repository from Azure DevOps (simplified example).
# Note: The real Azure DevOps permissions API can be more complex.
$azPermissionsUrl = "https://dev.azure.com/$AzureDevOpsOrg/$Project/_apis/git/repositories/$RepositoryName/permissions?api-version=6.0-preview.1"
Write-Host "Fetching repository permissions from Azure DevOps for '$RepositoryName'..."
$azPermissions = Invoke-RestMethod -Uri $azPermissionsUrl -Headers $azHeaders -Method GET

if (-Not $azPermissions) {
    Write-Error "Error: Failed to fetch permissions from Azure DevOps."
    exit 1
}
Write-Host "Azure DevOps permissions fetched successfully."

# Iterate over each mapping entry to update GitHub team memberships based on Azure DevOps groups.
foreach ($mapping in $mappingConfig) {
    $adoGroup = $mapping.AzureDevOpsGroup
    $ghTeam = $mapping.GitHubTeam
    $permissionLevel = $mapping.Permission

    Write-Host "Migrating permissions for mapping: Azure DevOps Group '$adoGroup' to GitHub Team '$ghTeam' with permission '$permissionLevel'."

    # Placeholder for retrieving Azure DevOps group members.
    # In a real scenario, you would query Azure DevOps REST API to get the member list.
    # For demonstration, we use a static list.
    $adoGroupMembers = @("user1@example.com", "user2@example.com")  # Example user emails

    # For each member, determine a GitHub username and add to the appropriate GitHub Team.
    foreach ($member in $adoGroupMembers) {
        Write-Host "Processing member: $member"
        
        # Simple assumption: GitHub username is the part before "@" in the email.
        $ghUsername = $member.Split("@")[0]

        # GitHub API endpoint to add/update a team member
        $ghTeamUrl = "https://api.github.com/orgs/$GitHubOrg/teams/$ghTeam/memberships/$ghUsername"
        $body = @{
            role = $permissionLevel  # GitHub expects role values such as 'member' or 'maintainer'.
        } | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Uri $ghTeamUrl -Headers $ghHeaders -Method PUT -Body $body
            Write-Host "User '$ghUsername' added/updated in GitHub team '$ghTeam' with permission '$permissionLevel'."
        }
        catch {
            Write-Warning "Warning: Failed to add user '$ghUsername' to team '$ghTeam'. Error: $_"
        }
    }
}
Write-Host "Permissions migration completed successfully."
