@{
    NonNodeData = @{
        AzureAD            = @{}
        Exchange           = @{}
        Intune             = @{}
        Office365          = @{}
        OneDrive           = @{}
        Planner            = @{}
        PowerPlatform      = @{}
        SecurityCompliance = @{}
        SharePoint         = @{}
        Teams              = @{
            ChannelsPolicies = @(
                @{
                    AllowChannelSharingToExternalUser             = $true
                    AllowPrivateChannelCreation                   = $true
                    AllowSharedChannelCreation                    = $true
                    AllowUserToParticipateInExternalSharedChannel = $true
                    Ensure                                        = "Present"
                    Identity                                      = "Global"
                }
            )
        }
    }
}
