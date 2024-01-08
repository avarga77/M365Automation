#Requires -Version 5.1
#Requires -Modules Az.KeyVault
#Requires -RunAsAdministrator

[CmdletBinding()]
param
(
    [Parameter(Mandatory, ParameterSetName = 'Environment')]
    [System.String]
    $Environment,

    [Parameter(Mandatory, ParameterSetName = 'OperationsCenter')]
    [switch]
    $OCConfiguration,

    [Parameter(Mandatory)]
    [System.String]
    $VaultName
)

######## FUNCTIONS ########

try {
    $mainFunctionsModule = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "SupportFunctions.psm1"
    Import-Module -Name $mainFunctionsModule -ErrorAction Stop
}
catch {
    Write-Host "ERROR: Could not load library 'SupportFunctions.psm1'. $($_.Exception.Message.Trim(".")). Exiting." -ForegroundColor Red
    exit -1
}

function Connect-Azure {
    $WarningPreference = "SilentlyContinue"
    $null = Connect-AzAccount

    $script:level++
    Write-Log -Message "Checking available tenants" -Level $script:level
    $tenants = Get-AzTenant
    if ($tenants.Count -gt 1) {
        Write-Log -Message "- Found multiple tenants, specify which tenant you would like to use:" -Level $script:level
        $i = 0
        $script:level++
        foreach ($tenant in $tenants) {
            $i++
            Write-Log -Message ("{0:D2} - {1} ({2})" -f $i, $tenant.Name, $tenant.Id) -Level $script:level
        }
        $validInput = $false
        do {
            $inputTenantNo = Read-Host -Prompt "Enter number of tenant"
            $tenantnr = 0
            if ([int]::TryParse($inputTenantNo, [ref]$tenantnr)) {
                if ($tenantnr -le 0 -or $tenantnr -gt $i) {
                    Write-Host "Provided number is not valid. Please try again!"
                }
                else {
                    $validInput = $true

                    #Correcting for zero based array
                    $tenantnr--
                }
            }
            else {
                Write-Host "Provided input is not a number. Please try again!"
            }
        }
        until ($validInput)
        $script:level--

        Write-Log -Message "Switching tenant to $($tenants[$tenantnr].Name)"
        $null = Set-AzContext -Tenant $tenants[$tenantnr]
    }

    $WarningPreference = "Continue"
    $script:level--
}

######## SCRIPT VARIABLES ########

$configFileSeparator = "#"
$level = 1
$global:progressPreference = "SilentlyContinue"

######## START SCRIPT ########

Write-Log -Message "***********************************************************"
Write-Log -Message "* Starting Microsoft365DSC Key Vault secret configuration *"
Write-Log -Message "***********************************************************"
Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Checking connection to Azure"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "

$connection = Get-AzContext
if ($null -eq $connection) {
    Write-Log -Message "Connecting to Azure"
    Connect-Azure
}
else {
    Write-Log -Message "Already connected to Azure"
    Write-Log -Message "Environment  : $($connection.Environment)" -Level $level
    Write-Log -Message "Subscription : $(($connection.Name -split " ")[0])" -Level $level
    Write-Log -Message "Account      : $($connection.Account)" -Level $level

    $answer = Read-Host -Prompt "Do you want to use these credentials (y/N)?"
    if ($answer.ToLower() -eq "y") {
        Write-Log -Message "Continuing with these credentials!"
    }
    else {
        Write-Log -Message "Reconnecting to Microsoft Azure!"
        $null = Disconnect-AzAccount
        Connect-Azure
    }
}

$KeyVault = Get-AzKeyVault -VaultName $VaultName
if ($null -eq $KeyVault) {
    Write-Log -Message "Cannot find the specified Key Vault '$VaultName'. Please make sure you specify a valid vault name! Exiting."
    return
}

$certificatesUpdated = 0
$certificatePasswordsUpdated = 0
$pwdSecretsUpdated = 0

# Upload environment-specific secrets
if ($Environment) {
    Write-Log -Message " "
    Write-Log -Message "---------------------------------------------------------"
    Write-Log -Message " Processing environment-specific secrets"
    Write-Log -Message "---------------------------------------------------------"
    Write-Log -Message " "

    $dataFileFolder = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "DataFiles\Environments"
    $dataFilePath = Join-Path -Path $dataFileFolder -ChildPath "$($Environment)$($configFileSeparator)Generic.psd1"

    if ((Test-Path -Path $dataFilePath) -eq $false) {
        Write-Log -Message "An environment-specific generic data file ($dataFilePath) does not exist. Exiting."
        return
    }

    $data = Import-DataFile -Path $dataFilePath
    $envShortName = $data.NonNodeData.Environment.ShortName

    Write-Log -Message "Processing accounts"
    foreach ($account in $data.NonNodeData.Accounts) {
        $updateSecret = $false

        $kvSecretName = "{0}-Cred-{1}" -f $envShortName, $account.Workload
        Write-Log -Message "Checking $kvSecretName ($($account.account))" -Level $level

        $kvSecret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $kvSecretName
        $level++
        if ($null -eq $kvSecret) {
            Write-Log -Message "Secret does not exist, adding it to Key Vault" -Level $level
            $updateSecret = $true
        }
        else {
            $answer = Read-Host -Prompt "Secret already exists. Do you want to overwrite it (y/N)?"
            if ($answer.ToLower() -eq "y") {
                $updateSecret = $true
            }
            else {
                Write-Log -Message "Skipping secret $kvSecretName" -Level $level
            }
        }

        if ($updateSecret -eq $true) {
            $securePassword = Read-Host -Prompt "Enter password for $envShortName $($account.Workload)" -AsSecureString
            Write-Log -Message "Updating secret $kvSecretName" -Level $level
            $null = Set-AzKeyVaultSecret -VaultName $VaultName -Name $kvSecretName -SecretValue $securePassword
            $pwdSecretsUpdated++
        }
        $level--
    }

    Write-Log -Message " "
    Write-Log -Message "Processing AppCredential certificates"
    foreach ($appCred in $data.NonNodeData.AppCredentials) {
        $updateCertificate = $false

        $kvSecretName = "{0}-CertPw-{1}" -f $envShortName, $appCred.Workload
        Write-Log -Message "Checking certificate password $kvSecretName" -Level $level

        $kvSecret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $kvSecretName
        $level++
        if ($null -eq $kvSecret) {
            Write-Log -Message "Certificate password does not exist, adding it to Key Vault" -Level $level
            $updateCertificate = $true
        }
        else {
            $answer = Read-Host -Prompt "Certificate password already exists. Do you want to overwrite it (y/N)?"
            if ($answer.ToLower() -eq "y") {
                $updateCertificate = $true
            }
            else {
                Write-Log -Message "Skipping secret $kvSecretName" -Level $level
                $securePassword = $kvSecret.SecretValue
            }
        }

        if ($updateCertificate -eq $true) {
            $securePassword = Read-Host -Prompt "Enter password for $envShortName $($appCred.Workload)" -AsSecureString
            Write-Log -Message "Updating secret $kvSecretName" -Level $level
            $null = Set-AzKeyVaultSecret -VaultName $VaultName -Name $kvSecretName -SecretValue $securePassword
            $certificatePasswordsUpdated++
        }
        $level--

        $kvCertName = "{0}-Cert-{1}" -f $envShortName, $appCred.Workload
        Write-Log -Message "Checking certificate $kvCertName" -Level $level

        $updateCertificate = $false
        $kvCertificate = Get-AzKeyVaultCertificate -VaultName $VaultName -Name $kvCertName
        $level++
        if ($null -eq $kvCertificate) {
            Write-Log -Message "Certificate does not exist, adding it to Key Vault" -Level $level
            $updateCertificate = $true
        }
        else {
            if ($kvCertificate.Thumbprint -ne $appCred.CertThumbprint) {
                Write-Log -Message "Certificate has a different thumbprint. Updating certificate!" -Level $level
                $updateCertificate = $true
            }
            else {
                Write-Log -Message "Certificate already exists. Skipping certificate!" -Level $level
            }
        }
        $level--

        if ($updateCertificate -eq $true) {
            Write-Log -Message "Please select the $envShortName $($appCred.Workload) certificate Pfx file" -Level $level
            # Dialog for selecting PFX input file
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.InitialDirectory = $PSScriptRoot
            $dialog.Title = "Please select the $envShortName $($appCred.Workload) certificate Pfx file"
            $dialog.Filter = "Pfx (*.pfx) | *.pfx"
            $result = $dialog.ShowDialog()

            if ($result -eq "OK") {
                $importedCert = Import-AzKeyVaultCertificate -VaultName $VaultName -Name $kvCertName -Password $securePassword -FilePath $dialog.FileName
                if ($importedCert.Thumbprint -ne $appCred.CertThumbprint) {
                    Write-Log -Message "[WARNING] Selected certificate does not match the Thumbprint specified in the data file (Certificate: $($importedCert.Thumbprint) / Data file: $($appCred.CertThumbprint)" -Level $level
                }
                $certificatesUpdated++
            }
        }
    }
}

# Upload operations center-specific secrets
if ($OCConfiguration) {
    Write-Log -Message " "
    Write-Log -Message "---------------------------------------------------------"
    Write-Log -Message " Processing operations center-specific secrets"
    Write-Log -Message "---------------------------------------------------------"
    Write-Log -Message " "

    Write-Log -Message "Reading data files" -Level $level
    $dataFileFolder = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "DataFiles\Environments"
    $dataFile = Get-ChildItem -Path $dataFileFolder -Filter "*$($configFileSeparator)Generic.psd1" | Select-Object -First 1
    if ($null -eq $dataFile) {
        Write-Log -Message "[ERROR] Could not find any generic data file. Exiting." -Level $level
        return
    }
    else {
        Write-Log -Message "- Using data file '$($dataFile.Name)'" -Level $level
    }

    $data = Import-DataFile -Path $dataFile.FullName
    $node = $data.AllNodes | Where-Object {$_.NodeName -eq "localhost"}
    if ($null -eq $node) {
        Write-Log -Message "[ERROR] No information exists in the data file '$($dataFile.Name)' for 'localhost'. Exiting." -Level $level
        return
    }

    Write-Log -Message "Processing encryption certificate"
    $updateCertificate = $false

    $kvSecretName = "CertPw-DSCEncrypt"
    Write-Log -Message "Checking certificate password $kvSecretName" -Level $level

    $kvSecret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $kvSecretName
    $level++
    if ($null -eq $kvSecret) {
        Write-Log -Message "Certificate password does not exist, adding it to Key Vault" -Level $level
        $updateCertificate = $true
    }
    else {
        $answer = Read-Host -Prompt "Certificate password already exists. Do you want to overwrite it (y/N)?"
        if ($answer.ToLower() -eq "y") {
            $updateCertificate = $true
        }
        else {
            Write-Log -Message "Skipping secret $kvSecretName" -Level $level
            $securePassword = $kvSecret.SecretValue
        }
    }

    if ($updateCertificate -eq $true) {
        $securePassword = Read-Host -Prompt "Enter password for encryption certificate" -AsSecureString
        Write-Log -Message "Updating secret $kvSecretName" -Level $level
        $null = Set-AzKeyVaultSecret -VaultName $VaultName -Name $kvSecretName -SecretValue $securePassword
        $certificatePasswordsUpdated++
    }
    $level--

    $kvCertName = "Cert-DSCEncrypt"
    Write-Log -Message "Checking certificate $kvCertName" -Level $level

    $updateCertificate = $false
    $kvCertificate = Get-AzKeyVaultCertificate -VaultName $VaultName -Name $kvCertName
    $level++
    if ($null -eq $kvCertificate) {
        Write-Log -Message "Certificate does not exist, adding it to Key Vault" -Level $level
        $updateCertificate = $true
    }
    else {
        if ($kvCertificate.Thumbprint -ne $node.CertThumbprint) {
            Write-Log -Message "Certificate has a different thumbprint. Updating certificate!" -Level $level
            $updateCertificate = $true
        }
        else {
            Write-Log -Message "Certificate already exists. Skipping certificate!" -Level $level
        }
    }
    $level--

    if ($updateCertificate -eq $true) {
        Write-Log -Message "Please select the encryption certificate Pfx file" -Level $level
        # Dialog for selecting PFX input file
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.InitialDirectory = $PSScriptRoot
        $dialog.Title = "Please select the encryption certificate Pfx file"
        $dialog.Filter = "Pfx (*.pfx) | *.pfx"
        $result = $dialog.ShowDialog()

        if ($result -eq "OK") {
            $importedCert = Import-AzKeyVaultCertificate -VaultName $VaultName -Name $kvCertName -Password $securePassword -FilePath $dialog.FileName
            if ($importedCert.Thumbprint -ne $node.CertThumbprint) {
                Write-Log -Message "[WARNING] Selected certificate does not match the Thumbprint specified in the data file (Certificate: $($importedCert.Thumbprint) / Data file: $($node.CertThumbprint)" -Level $level
            }
            $certificatesUpdated++
        }
    }

    Write-Log -Message " "
    Write-Log -Message "Processing email application client secret"
    $updateSecret = $false

    $kvSecretName = "Pwd-EmailApp"
    Write-Log -Message "Checking client secret $kvSecretName" -Level $level

    $kvSecret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $kvSecretName
    $level++
    if ($null -eq $kvSecret) {
        Write-Log -Message "Client secret does not exist, adding it to Key Vault" -Level $level
        $updateSecret = $true
    }
    else {
        $answer = Read-Host -Prompt "Client secret already exists. Do you want to overwrite it (y/N)?"
        if ($answer.ToLower() -eq "y") {
            $updateSecret = $true
        }
        else {
            Write-Log -Message "Skipping secret $kvSecretName" -Level $level
        }
    }

    if ($updateSecret -eq $true) {
        $securePassword = Read-Host -Prompt "Enter email application client secret" -AsSecureString
        Write-Log -Message "Updating secret $kvSecretName" -Level $level
        $null = Set-AzKeyVaultSecret -VaultName $VaultName -Name $kvSecretName -SecretValue $securePassword
        $pwdSecretsUpdated++
    }
    $level--

    Write-Log -Message " "
    Write-Log -Message "Processing password secret for private package feed access"
    $updateSecret = $false

    $kvSecretName = "Pwd-PackageFeed"
    Write-Log -Message "Checking password secret $kvSecretName" -Level $level

    $kvSecret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $kvSecretName
    $level++
    if ($null -eq $kvSecret) {
        Write-Log -Message "Password secret does not exist, adding it to Key Vault" -Level $level
        $updateSecret = $true
    }
    else {
        $answer = Read-Host -Prompt "Password secret already exists. Do you want to overwrite it (y/N)?"
        if ($answer.ToLower() -eq "y") {
            $updateSecret = $true
        }
        else {
            Write-Log -Message "Skipping secret $kvSecretName" -Level $level
        }
    }

    if ($updateSecret -eq $true) {
        $securePassword = Read-Host -Prompt "Enter private package feed secret (PAT token or password)" -AsSecureString
        Write-Log -Message "Updating secret $kvSecretName" -Level $level
        $null = Set-AzKeyVaultSecret -VaultName $VaultName -Name $kvSecretName -SecretValue $securePassword
        $pwdSecretsUpdated++
    }
    $level--
}

Write-Log -Message " "
Write-Log -Message "-----------------------------------------------------------"
Write-Log -Message " RESULT: Key Vault configuration script completed successfully:"
Write-Log -Message "- Updated $certificatePasswordsUpdated certificate passwords" -Level $level
Write-Log -Message "- Updated $certificatesUpdated certificates" -Level $level
Write-Log -Message "- Updated $pwdSecretsUpdated password secrets" -Level $level
Write-Log -Message "-----------------------------------------------------------"
Write-Log -Message " "
Write-Log -Message "***********************************************************"
Write-Log -Message "* Finished Microsoft365DSC Key Vault secret configuration *"
Write-Log -Message "***********************************************************"
Write-Log -Message " "
