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
    [string]$Organization,

    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [int]$BuildDefinitionId,

    [Parameter(Mandatory = $true)]
    [string]$NewRepoUrl,

    [Parameter(Mandatory = $true)]
    [string]$AzureDevOpsPAT
)

# Create an encoded authorization token for the Azure DevOps REST API
$authToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$AzureDevOpsPAT"))
$headers = @{
    Authorization = "Basic $authToken"
    "Content-Type" = "application/json"
}

# Construct the REST API URL for the build definition
$buildDefUrl = "https://dev.azure.com/$Organization/$Project/_apis/build/definitions/$BuildDefinitionId?api-version=6.0"

Write-Host "Fetching build definition from Azure DevOps..."
$buildDefinition = Invoke-RestMethod -Uri $buildDefUrl -Headers $headers -Method GET

if (-not $buildDefinition) {
    Write-Error "Error: Failed to fetch build definition. Verify the Organization, Project, and BuildDefinitionId."
    exit 1
}

Write-Host "Build definition fetched successfully. Updating repository URL..."
# Update the repository URL and type within the build definition JSON object
$buildDefinition.repository.url = $NewRepoUrl
$buildDefinition.repository.type = "GitHub"

# Convert updated configuration to JSON
$jsonBody = $buildDefinition | ConvertTo-Json -Depth 10

# Push the updated build definition back to Azure DevOps
Write-Host "Updating build definition with the new repository URL..."
$updateResult = Invoke-RestMethod -Uri $buildDefUrl -Headers $headers -Method PUT -Body $jsonBody

if ($updateResult) {
    Write-Host "Build definition updated successfully. The new repository URL is: $NewRepoUrl"
} else {
    Write-Error "Error: Failed to update build definition. Please verify the parameters and try again."
}
