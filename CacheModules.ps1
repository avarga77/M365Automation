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

Write-Log -Message "***********************************************************"
Write-Log -Message "* Starting Caching of Microsoft365DSC Module Dependencies *"
Write-Log -Message "***********************************************************"
Write-Log -Message " "

Write-Log -Message "Switching to path: $workingDirectory" -Level $level
Set-Location -Path $workingDirectory

Write-Log -Message " "
Write-Log -Message "-----------------------------------------------------------"
Write-Log -Message " Checking for presence of Microsoft365DSC module"
Write-Log -Message "-----------------------------------------------------------"
Write-Log -Message " "
$reqVersion = Install-DSCModule

Write-Log -Message " "
Write-Log -Message "-----------------------------------------------------------------------"
Write-Log -Message " Installing generic modules from PSGallery or a custom NuGet repository"
Write-Log -Message "-----------------------------------------------------------------------"
Write-Log -Message " "
Install-GenericModules -PackageSourceLocation $PackageSourceLocation -PATToken $PATToken -Version $reqVersion
Write-Log -Message "Importing module: M365DSCTools" -Level $level
Import-Module -Name M365DSCTools -Force

Write-Log -Message " "
Write-Log -Message "--------------------------------------------------------------------"
Write-Log -Message " Downloading and caching all required modules to Azure Blob Storage"
Write-Log -Message "--------------------------------------------------------------------"
Write-Log -Message " "
Add-ModulesToBlobStorage -ResourceGroupName $BlobResourceGroup -StorageAccountName $BlobStorageAccount -ContainerName $BlobContainer

Write-Log -Message " "
Write-Log -Message "***********************************************************"
Write-Log -Message "* Finished Caching of Microsoft365DSC Module Dependencies *"
Write-Log -Message "***********************************************************"
Write-Log -Message " "
