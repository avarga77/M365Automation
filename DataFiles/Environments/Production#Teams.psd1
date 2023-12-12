@{
	NonNodeData = @{
		Environment        = @{
			Name             = 'Production' # Environment name, e.g., 'Production'
			ShortName        = 'PROD' # Environment short name, e.g., 'PROD'
			TenantId         = '?.onmicrosoft.com' # The name of the tenant that belongs to the given environment
			OrganizationName = '?.onmicrosoft.com' # The same as TenantId
		}
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
					EnablePrivateTeamDiscovery = $false
					Ensure                     = "Present"
					Identity                   = "Global"
				}
			)
		}
	}
}
