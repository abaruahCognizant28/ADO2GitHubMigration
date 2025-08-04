# UpdateCICD.ps1
# This script updates an Azure DevOps build definition to point to a new GitHub Enterprise repository.
# It retrieves the build definition via the Azure DevOps REST API, updates the repository settings,
# and then pushes the updated configuration back.
#
# Usage:
#   .\UpdateCICD.ps1 -Organization "YourOrg" -Project "YourProject" -BuildDefinitionId 123 `
#                     -NewRepoUrl "https://github.yourcompany.com/YourOrg/YourRepo.git" -AzureDevOpsPAT "YourPAT"

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Organization,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$BuildDefinitionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$NewRepoUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzureDevOpsPAT,

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

Write-LogInfo "Starting CI/CD pipeline update" -Source "UpdateCICD"
Write-LogInfo "Organization: $Organization" -Source "UpdateCICD"
Write-LogInfo "Project: $Project" -Source "UpdateCICD"
Write-LogInfo "Build Definition ID: $BuildDefinitionId" -Source "UpdateCICD"
Write-LogInfo "New Repository URL: $NewRepoUrl" -Source "UpdateCICD"

# Create an encoded authorization token for the Azure DevOps REST API
$authToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$AzureDevOpsPAT"))
$headers = @{
    Authorization = "Basic $authToken"
    "Content-Type" = "application/json"
}

# Construct the REST API URL for the build definition
$buildDefUrl = "https://dev.azure.com/$Organization/$Project/_apis/build/definitions/$BuildDefinitionId?api-version=6.0"

Write-LogProgress -Activity "CI/CD Update" -Status "Fetching build definition from Azure DevOps" -PercentComplete 25 -Source "UpdateCICD"

try {
    $buildDefinition = Invoke-RestMethod -Uri $buildDefUrl -Headers $headers -Method GET -ErrorAction Stop
    Write-LogInfo "Successfully fetched build definition" -Source "UpdateCICD"
}
catch {
    Write-LogError "Failed to fetch build definition. Verify the Organization, Project, and BuildDefinitionId. Error: $($_.Exception.Message)" -Source "UpdateCICD" -TerminateScript
}

Write-LogProgress -Activity "CI/CD Update" -Status "Updating repository configuration" -PercentComplete 50 -Source "UpdateCICD"

# Store original values for backup/logging
$originalUrl = $buildDefinition.repository.url
$originalType = $buildDefinition.repository.type

Write-LogInfo "Original repository URL: $originalUrl" -Source "UpdateCICD"
Write-LogInfo "Original repository type: $originalType" -Source "UpdateCICD"

# Update the repository URL and type within the build definition JSON object
$buildDefinition.repository.url = $NewRepoUrl
$buildDefinition.repository.type = "GitHub"

Write-LogInfo "Updated repository URL to: $NewRepoUrl" -Source "UpdateCICD"
Write-LogInfo "Updated repository type to: GitHub" -Source "UpdateCICD"

# Convert updated configuration to JSON
$jsonBody = $buildDefinition | ConvertTo-Json -Depth 10

# Push the updated build definition back to Azure DevOps
Write-LogProgress -Activity "CI/CD Update" -Status "Pushing updated build definition to Azure DevOps" -PercentComplete 75 -Source "UpdateCICD"

try {
    $updateResult = Invoke-RestMethod -Uri $buildDefUrl -Headers $headers -Method PUT -Body $jsonBody -ErrorAction Stop
    Write-LogProgress -Activity "CI/CD Update" -Status "Update completed successfully" -PercentComplete 100 -Source "UpdateCICD"
    Write-LogInfo "Build definition updated successfully. The new repository URL is: $NewRepoUrl" -Source "UpdateCICD"
}
catch {
    Write-LogError "Failed to update build definition. Error: $($_.Exception.Message)" -Source "UpdateCICD" -TerminateScript
}

# Close logging
Close-Logging 