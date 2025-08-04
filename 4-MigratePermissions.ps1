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
    [ValidateNotNullOrEmpty()]
    [string]$AzureDevOpsOrg,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzureDevOpsPAT,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GitHubOrg,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GitHubRepo,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GitHubPAT,

    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_})]
    [string]$MappingFilePath,

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

Write-LogInfo "Starting permissions migration" -Source "MigratePermissions"
Write-LogInfo "Azure DevOps Org: $AzureDevOpsOrg" -Source "MigratePermissions"
Write-LogInfo "Project: $Project" -Source "MigratePermissions"
Write-LogInfo "Repository: $RepositoryName" -Source "MigratePermissions"
Write-LogInfo "GitHub Org: $GitHubOrg" -Source "MigratePermissions"
Write-LogInfo "GitHub Repo: $GitHubRepo" -Source "MigratePermissions"
Write-LogInfo "Mapping File: $MappingFilePath" -Source "MigratePermissions"

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
Write-LogProgress -Activity "Permissions Migration" -Status "Loading mapping configuration" -PercentComplete 10 -Source "MigratePermissions"

try {
    $mappingConfig = Get-Content $MappingFilePath | ConvertFrom-Json
    Write-LogInfo "Successfully loaded mapping configuration with $($mappingConfig.Count) entries" -Source "MigratePermissions"
}
catch {
    Write-LogError "Failed to parse mapping file: $($_.Exception.Message)" -Source "MigratePermissions" -TerminateScript
}

# Fetch permissions for the repository from Azure DevOps (simplified example).
# Note: The real Azure DevOps permissions API can be more complex.
$azPermissionsUrl = "https://dev.azure.com/$AzureDevOpsOrg/$Project/_apis/git/repositories/$RepositoryName/permissions?api-version=6.0-preview.1"
Write-LogProgress -Activity "Permissions Migration" -Status "Fetching Azure DevOps permissions" -PercentComplete 25 -Source "MigratePermissions"

try {
    $azPermissions = Invoke-RestMethod -Uri $azPermissionsUrl -Headers $azHeaders -Method GET -ErrorAction Stop
    Write-LogInfo "Azure DevOps permissions fetched successfully" -Source "MigratePermissions"
}
catch {
    Write-LogError "Failed to fetch permissions from Azure DevOps: $($_.Exception.Message)" -Source "MigratePermissions" -TerminateScript
}

# Iterate over each mapping entry to update GitHub team memberships based on Azure DevOps groups.
$totalMappings = $mappingConfig.Count
$currentMapping = 0

foreach ($mapping in $mappingConfig) {
    $currentMapping++
    $progressPercent = [math]::Round(($currentMapping / $totalMappings) * 75 + 25)
    
    $adoGroup = $mapping.AzureDevOpsGroup
    $ghTeam = $mapping.GitHubTeam
    $permissionLevel = $mapping.Permission

    Write-LogProgress -Activity "Permissions Migration" -Status "Processing mapping $currentMapping of $totalMappings" -PercentComplete $progressPercent -Source "MigratePermissions"
    Write-LogInfo "Migrating permissions: Azure DevOps Group '$adoGroup' -> GitHub Team '$ghTeam' (permission: '$permissionLevel')" -Source "MigratePermissions"

    # Placeholder for retrieving Azure DevOps group members.
    # In a real scenario, you would query Azure DevOps REST API to get the member list.
    # For demonstration, we use a static list.
    $adoGroupMembers = @("user1@example.com", "user2@example.com")  # Example user emails
    Write-LogDebug "Found $($adoGroupMembers.Count) members in Azure DevOps group '$adoGroup'" -Source "MigratePermissions"

    # For each member, determine a GitHub username and add to the appropriate GitHub Team.
    foreach ($member in $adoGroupMembers) {
        Write-LogDebug "Processing member: $member" -Source "MigratePermissions"
        
        # Simple assumption: GitHub username is the part before "@" in the email.
        $ghUsername = $member.Split("@")[0]

        # GitHub API endpoint to add/update a team member
        $ghTeamUrl = "https://api.github.com/orgs/$GitHubOrg/teams/$ghTeam/memberships/$ghUsername"
        
        # Map permission level to GitHub role (fix from original script)
        $ghRole = switch ($permissionLevel.ToLower()) {
            "admin" { "maintainer" }
            "push" { "member" }
            "pull" { "member" }
            default { "member" }
        }
        
        $body = @{
            role = $ghRole
        } | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Uri $ghTeamUrl -Headers $ghHeaders -Method PUT -Body $body -ErrorAction Stop
            Write-LogInfo "User '$ghUsername' added/updated in GitHub team '$ghTeam' with role '$ghRole'" -Source "MigratePermissions"
        }
        catch {
            Write-LogWarning "Failed to add user '$ghUsername' to team '$ghTeam': $($_.Exception.Message)" -Source "MigratePermissions"
        }
    }
}

Write-LogProgress -Activity "Permissions Migration" -Status "Migration completed successfully" -PercentComplete 100 -Source "MigratePermissions"
Write-LogInfo "Permissions migration completed successfully" -Source "MigratePermissions"

# Close logging
Close-Logging 