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
    $PATToken = $null
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

$dscScriptName = "M365Configuration.ps1"
$workingDirectory = $PSScriptRoot
$configFileSeparator = "#"
$level = 1
$global:progressPreference = "SilentlyContinue"

######## START SCRIPT ########

Write-Log -Message "*********************************************************"
Write-Log -Message "*   Starting Microsoft365DSC Configuration Compilation  *"
Write-Log -Message "*********************************************************"
Write-Log -Message " "
Write-Log -Message "Switching to path: $workingDirectory" -Level $level
Set-Location -Path $workingDirectory

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Checking for presence of Microsoft365DSC module"
Write-Log -Message "---------------------------------------------------------"
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

# Quality checks
Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Running quality checks "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
$testPath = Join-Path -Path $PSScriptRoot -ChildPath "Tests\Run-QATests.ps1"
$qaTestResults = & $testPath
if ($qaTestResults.Result -ne "Passed") {
    Write-Log -Message "[ERROR] $($qaTestResults.FailedCount) QA checks failed! Exiting!" -Level $level
    Write-Host "##vso[task.complete result=Failed;]Failed"
    exit -1
}

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Preparing MOF compilation"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
Write-Log -Message "Loading DSC configuration '$dscScriptName'" -Level $level
. (Join-Path -Path $workingDirectory -ChildPath $dscScriptName)

$outputFolder = Join-Path -Path $workingDirectory -ChildPath "Output"
Write-Log -Message "Preparing OutputFolder '$outputFolder'" -Level $level
if ((Test-Path -Path $outputFolder)) {
    Remove-Item -Path $outputFolder -Recurse -Confirm:$false
}
$null = New-Item -Path $outputFolder -ItemType Directory

Copy-Item -Path "DscResources.psd1" -Destination $outputFolder
Copy-Item -Path "deploy.ps1" -Destination $outputFolder
Copy-Item -Path "checkdsccompliance.ps1" -Destination $outputFolder
Copy-Item -Path "PsExec.exe" -Destination $outputFolder

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Reading Microsoft365DSC configuration files"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
Write-Log -Message "Reading and merging Basic configuration file(s): Basic*.psd1" -Level $level
[System.Array]$basicConfigFiles = Get-ChildItem -Path (Join-Path -Path $workingDirectory -ChildPath "DataFiles") -Filter "Basic*.psd1"
$level++
Write-Log -Message "- Found $($basicConfigFiles.Count) Basic configuration file(s)" -Level $level
Write-Log -Message "Processing Basic configuration file(s)" -Level $level
$c = 0
foreach ($basicConfigFile in $basicConfigFiles) {
    $level++
    if ($c -eq 0) {
        Write-Log -Message "Importing file: $($basicConfigFile.Name)" -Level $level
        $basicConfig = Import-DataFile -Path $basicConfigFile.FullName
    }
    else {
        Write-Log -Message "Merging file: $($basicConfigFile.Name)" -Level $level
        $basicConfigNextFragment = Import-DataFile -Path $basicConfigFile.FullName
        $basicConfig = Merge-DataFile -Reference $basicConfig -Merge $basicConfigNextFragment
    }
    $level--
    $c++
}
$level--

Write-Log -Message "Reading and merging environment-specific configuration file(s): <EnvName>[$($configFileSeparator)]*.psd1" -Level $level
[System.Array]$dataFiles = Get-ChildItem -Path (Join-Path -Path $workingDirectory -ChildPath "DataFiles\Environments") -Filter "*.psd1"
[System.Array]$environments = $dataFiles | Select-Object @{Label = "Environment"; Expression = { ($_.BaseName -split $configFileSeparator)[0] } } | Sort-Object -Unique -Property Environment
$level++
Write-Log -Message "- Found $($dataFiles.Count) data file(s) for $($environments.Count) environment(s)" -Level $level
$envConfig = @()
foreach ($environment in $environments.Environment) {
    Write-Log -Message "Processing data files for environment '$environment'" -Level $level
    [System.Array]$envDataFiles = $dataFiles | Where-Object { $_.BaseName -match "^($environment$|$environment$configFileSeparator)" }
    $c = 0
    $envData = $null
    $level++
    foreach ($envDataFile in $envDataFiles) {
        if ($c -eq 0) {
            Write-Log -Message "Importing file: $($envDataFile.Name)" -Level $level
            $envData = Import-DataFile -Path $envDataFile.FullName
        }
        else {
            Write-Log -Message "Merging file: $($envDataFile.Name)" -Level $level
            $envDataNextFragment = Import-DataFile -Path $envDataFile.FullName
            $envData = Merge-DataFile -Reference $envData -Merge $envDataNextFragment
        }
        $c++
    }
    $certPath = Join-Path -Path $workingDirectory -ChildPath $envData.AllNodes[0].CertificateFile.TrimStart(".\")
    $envData.AllNodes[0].CertificateFile = $certPath

    $envConfig += @{
        Name   = $environment
        Config = $envData
    }
    $level--
}
$level--

Write-Log -Message "Reading and merging Mandatory configuration file(s): Mandatory*.psd1" -Level $level
[System.Array]$mandatoryConfigFiles = Get-ChildItem -Path (Join-Path -Path $workingDirectory -ChildPath "DataFiles") -Filter "Mandatory*.psd1"
$level++
Write-Log -Message "- Found $($mandatoryConfigFiles.Count) Mandatory configuration file(s)" -Level $level
Write-Log -Message "Processing Mandatory configuration file(s)" -Level $level
$c = 0
foreach ($mandatoryConfigFile in $mandatoryConfigFiles) {
    $level++
    if ($c -eq 0) {
        Write-Log -Message "Importing file: $($mandatoryConfigFile.Name)" -Level $level
        $mandatoryConfig = Import-DataFile -Path $mandatoryConfigFile.FullName
    }
    else {
        Write-Log -Message "Merging file: $($mandatoryConfigFile.Name)" -Level $level
        $mandatoryConfigNextFragment = Import-DataFile -Path $mandatoryConfigFile.FullName
        $mandatoryConfig = Merge-DataFile -Reference $mandatoryConfig -Merge $mandatoryConfigNextFragment
    }
    $level--
    $c++
}
$level--

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Starting MOF compilation"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
foreach ($environment in $envConfig) {
    Write-Log -Message "Processing environment: $($environment.Name)" -Level $level

    $outputPathDataFile = Join-Path -Path $outputFolder -ChildPath $environment.Name
    if ((Test-Path -Path $outputPathDataFile) -eq $false) {
        $null = New-Item -Path $outputPathDataFile -ItemType Directory
    }

    $level++
    Write-Log -Message "Merging basic config with environment-specific config" -Level $level
    $newConfig = Clone-Object -Object $basicConfig
    $basicAndEnvConfig = Merge-DataFile -Reference $newConfig -Merge $environment.Config

    Write-Log -Message "Merging basic and environment-specific config with mandatory config" -Level $level
    $mergedConfigData = Merge-DataFile -Reference $basicAndEnvConfig -Merge $mandatoryConfig

    $psdStringData = $mergedConfigData | ConvertTo-Psd
    $psdPath = Join-Path -Path $outputPathDataFile -ChildPath "$($environment.Name).psd1"
    Set-Content -Path $psdPath -Value $psdStringData

    Write-Log -Message "Testing merged configuration data" -Level $level
    $testPath = Join-Path -Path $PSScriptRoot -ChildPath "Tests\Run-DVTests.ps1"
    $qaTestResults = & $testPath -ConfigData $mergedConfigData

    if ($qaTestResults.Result -eq "Passed") {
        Write-Log -Message "Generating MOF file" -Level $level
        try {
            $compileError = $false
            $targetConfig = Clone-Object -Object $mergedConfigData
            $null = M365Configuration -ConfigurationData $targetConfig -OutputPath $outputPathDataFile -ErrorVariable $err
        }
        catch {
            Write-Log -Message "[ERROR] An error occurred during MOF compilation" -Level $level
            Write-Log -Message "Error: $($_.Exception.Message)" -Level $level
            $compileError = $true
        }
    }
    else {
        Write-Log -Message "[ERROR] There's an error in the merged configuration data files" -Level $level
        $compileError = $true
    }
    $level--
}

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
if ($compileError) {
    Write-Log -Message " RESULT: Build script encountered errors!"
}
else {
    Write-Log -Message " RESULT: Build script completed successfully!"
}
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
Write-Log -Message "*********************************************************"
Write-Log -Message "*   Finished Microsoft365DSC Configuration Compilation  *"
Write-Log -Message "*********************************************************"
Write-Log -Message " "
