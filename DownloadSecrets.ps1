#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [System.String]
    $KeyVault,

    [Parameter()]
    [System.String]
    $Environment
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

$workingDirectory = $PSScriptRoot
$configFileSeparator = "#"
$level = 1
$global:progressPreference = "SilentlyContinue"

######## START SCRIPT ########

Write-Log -Message "*********************************************************"
Write-Log -Message "*     Starting Deployment of Microsoft365DSC Secrets    *"
Write-Log -Message "*********************************************************"
Write-Log -Message " "

Write-Log -Message "Switching to path: $workingDirectory" -Level $level
Set-Location -Path $workingDirectory

Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Reading environment-specific configuration file(s)"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "

if ($Environment) {
    Write-Log -Message "Getting generic data file for environment '$Environment'" -Level $level
    $dataFilePath = Join-Path -Path $workingDirectory -ChildPath "DataFiles\Environments\$($Environment)$($configFileSeparator)Generic.psd1"
    [System.Array]$dataFiles = Get-Item -Path $dataFilePath -ErrorAction SilentlyContinue
    if ($null -eq $dataFiles) {
        Write-Log -Message "[ERROR] Could not find a generic data file for environment '$Environment'. Exiting." -Level $level
        Write-Host "##vso[task.complete result=Failed;]Failed"
        exit -1
    }
}
else {
    Write-Log -Message "Getting generic data files for all environments" -Level $level
    $dataFileFolder = Join-Path -Path $workingDirectory -ChildPath "DataFiles\Environments"
    [System.Array]$dataFiles = Get-ChildItem -Path $dataFileFolder -Filter "*$($configFileSeparator)Generic.psd1"
    if ($null -eq $dataFiles) {
        Write-Log -Message "[ERROR] Could not find any generic data file. Exiting." -Level $level
        Write-Host "##vso[task.complete result=Failed;]Failed"
        exit -1
    }
    else {
        Write-Log -Message "- Found $($dataFiles.Count) data file(s)" -Level $level
    }
}

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Getting environment-specific secrets"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "

foreach ($dataFile in $dataFiles) {
    Write-Log -Message "Processing data file: $($dataFile.Name)" -Level $level
    $envData = Import-DataFile -Path $dataFile.FullName
    $envShortName = $envData.NonNodeData.Environment.ShortName

    $level++
    Write-Log -Message "Getting certificate secrets from Azure Key Vault '$KeyVault'" -Level $level
    $certsImported = @()
    $level++
    foreach ($appcred in $envData.NonNodeData.AppCredentials) {
        $kvCertName = "{0}-Cert-{1}" -f $envShortName, $appCred.Workload
        Write-Log -Message "Processing certificate: $kvCertName" -Level $level

        $level++
        $secret = Get-AzKeyVaultSecret -VaultName $KeyVault -Name $kvCertName -AsPlainText -ErrorAction SilentlyContinue
        if ($null -eq $secret) {
            Write-Log -Message "[ERROR] Cannot find $kvCertName in Azure Key Vault" -Level $level
            Write-Host "##vso[task.complete result=Failed;]Failed"
            exit 20
        }
        $secretByte = [Convert]::FromBase64String($secret)

        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($secretByte, "", "Exportable,MachineKeySet,PersistKeySet")
        Write-Log -Message "Importing certificate $kvCertName with thumbprint $($cert.Thumbprint) into the LocalMachine Certificate Store" -Level $level
        if ((Test-Path -Path "Cert:\LocalMachine\My\$($cert.Thumbprint)") -eq $false) {
            $CertStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
            $CertStore.Open("ReadWrite")
            $CertStore.Add($cert)
            $CertStore.Close()
        }
        else {
            $level++
            Write-Log -Message "Certificate already exists. Skipping..." -Level $level
            $level--
        }

        Write-Log -Message "Importing certificate $kvCertName with thumbprint $($cert.Thumbprint) into the 'NT AUTHORITY\System' User Certificate Store" -Level $level
        if ($certsImported -notcontains $cert.Thumbprint) {
            $sysScript = "
				`$secretByte = [Convert]::FromBase64String('$secret')
				`$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(`$secretByte, '', 'Exportable,UserKeySet,PersistKeySet')
				if ((Test-Path -Path ('Cert:\CurrentUser\My\' + `$cert.Thumbprint)) -eq `$false) {
					`$CertStore = New-Object System.Security.Cryptography.X509Certificates.X509Store('My','CurrentUser')
					`$CertStore.Open('ReadWrite')
					`$CertStore.Add(`$cert)
					`$CertStore.Close()
					`$cert.Reset()
				}
			"
            $tempPref = $ErrorActionPreference
            $ErrorActionPreference = "SilentlyContinue"
            .\PsExec.exe -accepteula -nobanner -s powershell.exe -command "Invoke-Command -ScriptBlock {$sysScript}" *> $null
            $certsImported += $cert.Thumbprint
            $ErrorActionPreference = $tempPref
        }
        else {
            $level++
            Write-Log -Message "Certificate already exists. Skipping..." -Level $level
            $level--
        }
        $cert.Reset()
        $level--
    }
    $level--
    $level--
}

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Getting operations center-specific secrets"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "

Write-Log -Message "Getting encryption certificate secret from Key Vault '$KeyVault'" -Level $level

$level++
$encryptCertName = "Cert-DSCEncrypt"
Write-Log -Message "Processing certificate: $encryptCertName" -Level $level

$level++
$secret = Get-AzKeyVaultSecret -VaultName $KeyVault -Name $encryptCertName -AsPlainText -ErrorAction SilentlyContinue
if ($null -eq $secret) {
    Write-Log -Message "[ERROR] Cannot find $encryptCertName in Azure Key Vault" -Level $level
    Write-Host "##vso[task.complete result=Failed;]Failed"
    exit 20
}
$secretByte = [Convert]::FromBase64String($secret)
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($secretByte, "", "Exportable,MachineKeySet,PersistKeySet")
Write-Log -Message "Importing certificate $encryptCertName with thumbprint $($cert.Thumbprint) into the LocalMachine Certificate Store" -Level $level
if ((Test-Path -Path "Cert:\LocalMachine\My\$($cert.Thumbprint)") -eq $false) {
    $CertStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
    $CertStore.Open("ReadWrite")
    $CertStore.Add($cert)
    $CertStore.Close()
}
else {
    $level++
    Write-Log -Message "Certificate already exists. Skipping..." -Level $level
    $level--
}
$level--
$level--

Write-Log -Message "Getting email application client secret from Key Vault '$KeyVault'" -Level $level

$level++
$kvSecretName = "Pwd-EmailApp"
Write-Log -Message "Processing secret: $kvSecretName" -Level $level

$level++
$secret = Get-AzKeyVaultSecret -VaultName $KeyVault -Name $kvSecretName -AsPlainText -ErrorAction SilentlyContinue
if ($null -eq $secret) {
    Write-Log -Message "[WARNING] Cannot find $kvSecretName in Azure Key Vault" -Level $level
    Write-Log -Message "Setting the corresponding pipeline variable to empty" -Level $level
}
else {
    Write-Log -Message "Saving secret as pipeline variable for further use" -Level $level
    Write-Host "##vso[task.setvariable variable=mailAppSecret;issecret=true;isreadonly=true]$secret"
}
$level--
$level--

Write-Log -Message "Getting password secret for private package feed access from Key Vault '$KeyVault'" -Level $level

$level++
$kvSecretName = "Pwd-PackageFeed"
Write-Log -Message "Processing secret: $kvSecretName" -Level $level

$level++
$secret = Get-AzKeyVaultSecret -VaultName $KeyVault -Name $kvSecretName -AsPlainText -ErrorAction SilentlyContinue
if ($null -eq $secret) {
    Write-Log -Message "[WARNING] Cannot find $kvSecretName in Azure Key Vault" -Level $level
    Write-Log -Message "Setting the corresponding pipeline variable to empty" -Level $level
}
else {
    Write-Log -Message "Saving secret as pipeline variable for further use" -Level $level
    Write-Host "##vso[task.setvariable variable=patToken;issecret=true;isreadonly=true]$secret"
}
$level--
$level--

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Configuring LCM with the encryption certificate"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "

Configuration ConfigureLCM {
    Import-DscResource -ModuleName PsDesiredStateConfiguration
    node localhost {
        LocalConfigurationManager {
            ConfigurationMode = "ApplyOnly"
            CertificateId     = $cert.Thumbprint
        }
    }
}
$LCMConfig = ConfigureLCM
Set-DscLocalConfigurationManager -Path $LCMConfig.Directory
Get-DscLocalConfigurationManager | Format-Table -Property CertificateID, ConfigurationMode -AutoSize
$cert.Reset()

Write-Log -Message " "
Write-Log -Message "*********************************************************"
Write-Log -Message "*     Finished Deployment of Microsoft365DSC Secrets    *"
Write-Log -Message "*********************************************************"
Write-Log -Message " "
