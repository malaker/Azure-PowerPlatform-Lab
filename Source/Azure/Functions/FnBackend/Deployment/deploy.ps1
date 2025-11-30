[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FunctionAppName
)

# Set error action preference
$ErrorActionPreference = 'Stop'

$scriptPath = $PSScriptRoot

Push-Location "$scriptPath\..\"

func azure functionapp publish $FunctionAppName $scriptPath/../FnBackend.csproj

Pop-Location