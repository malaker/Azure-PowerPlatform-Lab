# Azure Data Factory Import Script
# This script imports datasets and pipelines from exported JSON files
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName="rg-dev-datafactory",

    [Parameter(Mandatory = $true)]
    [string]$AdfResourceName
)
$RG = $ResourceGroupName
$ADF = $AdfResourceName

$scriptPath = $PSScriptRoot

$IMPORT_DIR = "$scriptPath\..\adf_export"

Write-Host "Importing datasets..." -ForegroundColor Cyan

# Import datasets
$datasetFiles = Get-ChildItem -Path "$IMPORT_DIR\datasets\*.json"
foreach ($file in $datasetFiles) {
    $datasetName = $file.BaseName
    Write-Host "Importing dataset: $datasetName" -ForegroundColor Yellow

    # Read and parse JSON
    $jsonContent = Get-Content $file.FullName -Raw | ConvertFrom-Json

    # Extract properties and convert back to JSON
    $properties = $jsonContent.properties | ConvertTo-Json -Depth 100 -Compress

    # Create temporary file with properties only
    $tempFile = New-TemporaryFile
    $properties | Out-File -FilePath $tempFile.FullName -Encoding utf8

    try {
        # Import dataset
        az datafactory dataset create `
            --resource-group $RG `
            --factory-name $ADF `
            --name $datasetName `
            --properties "@$($tempFile.FullName)"

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Successfully imported dataset: $datasetName" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to import dataset: $datasetName" -ForegroundColor Red
        }
    }
    finally {
        # Clean up temporary file
        Remove-Item $tempFile.FullName -Force
    }
}

Write-Host "`nImporting pipelines..." -ForegroundColor Cyan

# Import pipelines
$pipelineFiles = Get-ChildItem -Path "$IMPORT_DIR\pipelines\*.json"
foreach ($file in $pipelineFiles) {
    $pipelineName = $file.BaseName
    Write-Host "Importing pipeline: $pipelineName" -ForegroundColor Yellow

    # Read and parse JSON
    $jsonContent = Get-Content $file.FullName -Raw | ConvertFrom-Json

    # Extract properties and convert back to JSON
    $properties = $jsonContent.properties | ConvertTo-Json -Depth 100 -Compress

    # Create temporary file with properties only
    $tempFile = New-TemporaryFile
    $properties | Out-File -FilePath $tempFile.FullName -Encoding utf8

    try {
        # Import pipeline
        az datafactory pipeline create `
            --resource-group $RG `
            --factory-name $ADF `
            --name $pipelineName `
            --pipeline "@$($tempFile.FullName)"

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Successfully imported pipeline: $pipelineName" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to import pipeline: $pipelineName" -ForegroundColor Red
        }
    }
    finally {
        # Clean up temporary file
        Remove-Item $tempFile.FullName -Force
    }
}

Write-Host "`nImport complete!" -ForegroundColor Cyan
