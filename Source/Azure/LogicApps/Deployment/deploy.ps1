[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName="rg-dev-logicapps",

    [Parameter(Mandatory = $true)]
    [string]$LogicAppStandardResourceName
)

$scriptPath = $PSScriptRoot

# Set error action preference
$ErrorActionPreference = 'Stop'

Compress-Archive -Path "$scriptPath\..\Workflows\*" -DestinationPath "$scriptPath\workflows.zip"

az functionapp deployment source config-zip --resource-group $ResourceGroupName --name $LogicAppStandardResourceName --src "$scriptPath\workflows.zip"