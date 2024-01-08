@{
    AllNodes    = @(
        @{
            NodeName        = 'localhost' # For Microsoft-hosted solutions, leave it as 'localhost'; for self-hosted or mixed solutions, enter the 'agent name' you specified in section 4.6.1 for the given operations center
            CertificateFile = '.\DSCEncryptionCert.cer' # The file path in the repo to the encryption certificate of the given operations center
            CertThumbprint  = '?' # The thumbprint of the encryption certificate in the given operations center (should be in $encryptionCertThumb)
        }
    )
    NonNodeData = @{
        Environment    = @{
            Name             = 'Production' # Environment name, e.g., 'Production'
            ShortName        = 'PROD' # Environment short name, e.g., 'PROD'
            TenantId         = '?.onmicrosoft.com' # The name of the tenant that belongs to the given environment
            OrganizationName = '?.onmicrosoft.com' # The same as TenantId
        }
        Accounts       = @{} # Leave it empty if you're using service principals
        AppCredentials = @(
            @{
                Workload       = 'AzureAD'
                ApplicationId  = '?' # The AppId of the DSC app for the given environment (should be in $DSCApp.AppId)
                CertThumbprint = '?' # The thumbprint of the authentication certificate for the given environment (should be in $DSCCertThumb)
            }
            @{
                Workload       = 'Exchange'
                ApplicationId  = '?' # The AppId of the DSC app for the given operations center (should be in $DSCApp.AppId)
                CertThumbprint = '?' # The thumbprint of the encryption certificate for the given operations center (should be in $DSCCertThumb)
            }
            @{
                Workload       = 'Intune'
                ApplicationId  = '?' # The AppId of the DSC app for the given operations center (should be in $DSCApp.AppId)
                CertThumbprint = '?' # The thumbprint of the encryption certificate for the given operations center (should be in $DSCCertThumb)
            }
            @{
                Workload       = 'Office365'
                ApplicationId  = '?' # The AppId of the DSC app for the given operations center (should be in $DSCApp.AppId)
                CertThumbprint = '?' # The thumbprint of the encryption certificate for the given operations center (should be in $DSCCertThumb)
            }
            @{
                Workload       = 'OneDrive'
                ApplicationId  = '?' # The AppId of the DSC app for the given operations center (should be in $DSCApp.AppId)
                CertThumbprint = '?' # The thumbprint of the encryption certificate for the given operations center (should be in $DSCCertThumb)
            }
            @{
                Workload       = 'Planner'
                ApplicationId  = '?' # The AppId of the DSC app for the given operations center (should be in $DSCApp.AppId)
                CertThumbprint = '?' # The thumbprint of the encryption certificate for the given operations center (should be in $DSCCertThumb)
            }
            @{
                Workload       = 'PowerPlatform'
                ApplicationId  = '?' # The AppId of the DSC app for the given operations center (should be in $DSCApp.AppId)
                CertThumbprint = '?' # The thumbprint of the encryption certificate for the given operations center (should be in $DSCCertThumb)
            }
            @{
                Workload       = 'SecurityCompliance'
                ApplicationId  = '?' # The AppId of the DSC app for the given operations center (should be in $DSCApp.AppId)
                CertThumbprint = '?' # The thumbprint of the encryption certificate for the given operations center (should be in $DSCCertThumb)
            }
            @{
                Workload       = 'SharePoint'
                ApplicationId  = '?' # The AppId of the DSC app for the given operations center (should be in $DSCApp.AppId)
                CertThumbprint = '?' # The thumbprint of the encryption certificate for the given operations center (should be in $DSCCertThumb)
            }
            @{
                Workload       = 'Teams'
                ApplicationId  = '?' # The AppId of the DSC app for the given operations center (should be in $DSCApp.AppId)
                CertThumbprint = '?' # The thumbprint of the encryption certificate for the given operations center (should be in $DSCCertThumb)
            }
        )
    }
}
