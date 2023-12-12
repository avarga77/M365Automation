#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param
(
	[Parameter()]
	[AllowEmptyString()]
	[AllowNull()]
	[System.String]
	$PackageSourceLocation = $null,

	[Parameter()]
	[AllowEmptyString()]
	[AllowNull()]
	[System.String]
	$PATToken = $null,

	[Parameter(Mandatory)]
	[System.String]
	$BlobResourceGroup,

	[Parameter(Mandatory)]
	[System.String]
	$BlobStorageAccount,

	[Parameter(Mandatory)]
	[System.String]
	$BlobContainer
)

######## FUNCTIONS ########

try {
	Import-Module -Name ".\SupportFunctions.psm1" -ErrorAction Stop
}
catch {
	Write-Host "ERROR: Could not load library 'SupportFunctions.psm1'. $($_.Exception.Message.Trim(".")). Exiting." -ForegroundColor Red
	exit -1
}

######## SCRIPT VARIABLES ########

$level = 1
$workingDirectory = $PSScriptRoot

######## START SCRIPT ########

Write-Log -Message "*********************************************************"
Write-Log -Message "*  Starting Deployment of M365 DSC Module Dependencies  *"
Write-Log -Message "*********************************************************"
Write-Log -Message " "

Write-Log -Message "Switching to path: $workingDirectory" -Level $level
Set-Location -Path $workingDirectory

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Checking required Microsoft365DSC version"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
$reqModules = Import-DataFile -Path (Join-Path -Path $workingDirectory -ChildPath "DscResources.psd1")
if ($reqModules.ContainsKey("Microsoft365DSC")) {
	$reqVersion = $reqModules.Microsoft365DSC
	Write-Log -Message "- Required version: $reqVersion" -Level $level
}
else {
	Write-Log "[ERROR] Unable to find Microsoft365DSC in DscResources.psd1. Exiting!" -Level $level
	Write-Host "##vso[task.complete result=Failed;]Failed"
	exit 10
}

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Initializing PowerShell Gallery"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
Initialize-PSGallery

Write-Log -Message " "
Write-Log -Message "-----------------------------------------------------------------------"
Write-Log -Message " Installing generic modules from PSGallery or a custom NuGet repository"
Write-Log -Message "-----------------------------------------------------------------------"
Write-Log -Message " "
Install-GenericModules -PackageSourceLocation $PackageSourceLocation -PATToken $PATToken -Version $reqVersion
Write-Log -Message "Importing module: M365DSCTools" -Level $level
Import-Module -Name M365DSCTools -Force

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Deploying all required modules from Azure Blob Storage"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
Get-ModulesFromBlobStorage -ResourceGroupName $BlobResourceGroup -StorageAccountName $BlobStorageAccount -ContainerName $BlobContainer -Version $reqVersion

Write-Log -Message " "
Write-Log -Message "*********************************************************"
Write-Log -Message "*  Finished Deployment of M365 DSC Module Dependencies  *"
Write-Log -Message "*********************************************************"
Write-Log -Message " "
