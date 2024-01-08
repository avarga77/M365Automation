#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [System.String]
    $Environment
)

######## FUNCTIONS ########

$functionPath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "SupportFunctions.psm1"
try {
    Import-Module -Name $functionPath -ErrorAction Stop
}
catch {
    Write-Host "ERROR: Could not load library 'SupportFunctions.psm1'. $($_.Exception.Message.Trim(".")). Exiting." -ForegroundColor Red
    exit -1
}

######## SCRIPT VARIABLES ########

$level = 1
$workingDirectory = $PSScriptRoot
$global:progressPreference = "SilentlyContinue"

######## START SCRIPT ########

Write-Log -Message "*********************************************************"
Write-Log -Message "*      Starting M365 DSC Configuration Deployment       *"
Write-Log -Message "*********************************************************"
Write-Log -Message "Environment to be deployed: $Environment"
Write-Log -Message "*********************************************************"
Write-Log -Message " "

Write-Log -Message "Switching to path: $workingDirectory" -Level $level
Set-Location -Path $workingDirectory

Write-Log -Message "Checking for presence of the specified environment" -Level $level
$environmentPath = Join-Path -Path $workingDirectory -ChildPath $Environment
if ((Test-Path -Path $environmentPath) -eq $false) {
    Write-Log -Message "[ERROR] Unable to find specified environment in build artifacts" -Level $level
    Write-Host "##vso[task.complete result=Failed;]Failed"
    Exit 20
}

Write-Log -Message " "
Write-Log -Message "------------------------------------------------------------------"
Write-Log -Message " Checking for presence of Microsoft365DSC module and dependencies"
Write-Log -Message "------------------------------------------------------------------"
Write-Log -Message " "
$null = Install-DSCModule

Write-Log -Message "Checking module dependencies" -Level $level
Update-M365DSCDependencies

Write-Log -Message "Checking outdated module dependencies" -Level $level
Uninstall-M365DSCOutdatedDependencies

$envPath = Join-Path -Path $workingDirectory -ChildPath $Environment

try {
    $deploymentSucceeded = $true
    Write-Log -Message " "
    Write-Log -Message "---------------------------------------------------------"
    Write-Log -Message " Running deployment of MOF file"
    Write-Log -Message "---------------------------------------------------------"
    Write-Log -Message " "
    Start-DscConfiguration -Path $envPath -Verbose -Wait -Force
}
catch {
    Write-Log -Message "MOF Deployment Failed!" -Level $level
    Write-Log -Message "Error occurred during deployment: $($_.Exception.Message)" -Level $level
    $deploymentSucceeded = $false
}
finally {
    Write-Log -Message " "
    Write-Log -Message "---------------------------------------------------------"
    if ($deploymentSucceeded -eq $true) {
        Write-Log -Message " RESULT: MOF Deployment Succeeded!"
    }
    else {
        Write-Log -Message " RESULT: MOF Deployment Failed!"
        Write-Log -Message " Issues found during configuration deployment!" -Level $level
        Write-Log -Message " Make sure you correct all issues and try again." -Level $level
        Write-Host "##vso[task.complete result=Failed;]Failed"
    }
    Write-Log -Message "---------------------------------------------------------"
    Write-Log -Message " "
    Write-Log -Message "*********************************************************"
    Write-Log -Message "*   Finished Microsoft365DSC Configuration Deployment   *"
    Write-Log -Message "*********************************************************"
    Write-Log -Message " "
}
