Configuration M365Configuration
{
    Import-DscResource -ModuleName M365DSC.CompositeResources

    node localhost
    {
        $azureadAppCreds = $ConfigurationData.NonNodeData.AppCredentials | Where-Object -FilterScript { $_.Workload -eq 'AzureAD' }
        $exchangeAppCreds = $ConfigurationData.NonNodeData.AppCredentials | Where-Object -FilterScript { $_.Workload -eq 'Exchange' }
        $intuneAppCreds = $ConfigurationData.NonNodeData.AppCredentials | Where-Object -FilterScript { $_.Workload -eq 'Intune' }
        $officeAppCreds = $ConfigurationData.NonNodeData.AppCredentials | Where-Object -FilterScript { $_.Workload -eq 'Office365' }
        $onedriveAppCreds = $ConfigurationData.NonNodeData.AppCredentials | Where-Object -FilterScript { $_.Workload -eq 'OneDrive' }
        $plannerAppCreds = $ConfigurationData.NonNodeData.AppCredentials | Where-Object -FilterScript { $_.Workload -eq 'Planner' }
        $powerplatformAppCreds = $ConfigurationData.NonNodeData.AppCredentials | Where-Object -FilterScript { $_.Workload -eq 'PowerPlatform' }
        $securitycomplianceAppCreds = $ConfigurationData.NonNodeData.AppCredentials | Where-Object -FilterScript { $_.Workload -eq 'SecurityCompliance' }
        $sharepointAppCreds = $ConfigurationData.NonNodeData.AppCredentials | Where-Object -FilterScript { $_.Workload -eq 'SharePoint' }
        $teamsAppCreds = $ConfigurationData.NonNodeData.AppCredentials | Where-Object -FilterScript { $_.Workload -eq 'Teams' }

        AzureAD 'AzureAD_Configuration'
        {
            ApplicationId         = $azureadAppCreds.ApplicationId
            TenantId              = $ConfigurationData.NonNodeData.Environment.TenantId
            CertificateThumbprint = $azureadAppCreds.CertThumbprint
        }

        Exchange 'Exchange_Configuration'
        {
            ApplicationId         = $exchangeAppCreds.ApplicationId
            TenantId              = $ConfigurationData.NonNodeData.Environment.TenantId
            CertificateThumbprint = $exchangeAppCreds.CertThumbprint
        }

        Intune 'Intune_Configuration'
        {
            ApplicationId         = $intuneAppCreds.ApplicationId
            TenantId              = $ConfigurationData.NonNodeData.Environment.TenantId
            CertificateThumbprint = $intuneAppCreds.CertThumbprint
        }

        Office365 'Office365_Configuration'
        {
            ApplicationId         = $officeAppCreds.ApplicationId
            TenantId              = $ConfigurationData.NonNodeData.Environment.TenantId
            CertificateThumbprint = $officeAppCreds.CertThumbprint
        }

        OneDrive 'OneDrive_Configuration'
        {
            ApplicationId         = $onedriveAppCreds.ApplicationId
            TenantId              = $ConfigurationData.NonNodeData.Environment.TenantId
            CertificateThumbprint = $onedriveAppCreds.CertThumbprint
        }

        Planner 'Planner_Configuration'
        {
            ApplicationId         = $plannerAppCreds.ApplicationId
            TenantId              = $ConfigurationData.NonNodeData.Environment.TenantId
            CertificateThumbprint = $plannerAppCreds.CertThumbprint
        }

        PowerPlatform 'PowerPlatform_Configuration'
        {
            ApplicationId         = $powerplatformAppCreds.ApplicationId
            TenantId              = $ConfigurationData.NonNodeData.Environment.TenantId
            CertificateThumbprint = $powerplatformAppCreds.CertThumbprint
        }

        SecurityCompliance 'SecurityCompliance_Configuration'
        {
            ApplicationId         = $securitycomplianceAppCreds.ApplicationId
            TenantId              = $ConfigurationData.NonNodeData.Environment.TenantId
            CertificateThumbprint = $securitycomplianceAppCreds.CertThumbprint
        }

        SharePoint 'SharePoint_Configuration'
        {
            ApplicationId         = $sharepointAppCreds.ApplicationId
            TenantId              = $ConfigurationData.NonNodeData.Environment.TenantId
            CertificateThumbprint = $sharepointAppCreds.CertThumbprint
        }

        Teams 'Teams_Configuration'
        {
            ApplicationId         = $teamsAppCreds.ApplicationId
            TenantId              = $ConfigurationData.NonNodeData.Environment.TenantId
            CertificateThumbprint = $teamsAppCreds.CertThumbprint
        }
    }
}
