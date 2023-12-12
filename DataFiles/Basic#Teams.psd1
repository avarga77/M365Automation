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
					AllowOrgWideTeamCreation   = $true
					EnablePrivateTeamDiscovery = $true
					Ensure                     = "Present"
					Identity                   = "Global"
				}
			)
		}
	}
}
