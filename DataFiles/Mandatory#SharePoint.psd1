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
		SharePoint         = @{
			TenantSettings = @{
				Ensure                     = "Present"
				LegacyAuthProtocolsEnabled = $false
			}
		}
		Teams              = @{}
	}
}
