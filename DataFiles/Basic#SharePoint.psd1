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
				ApplyAppEnforcedRestrictionsToAdHocRecipients = $true
				CommentsOnSitePagesDisabled                   = $false
				ConditionalAccessPolicy                       = "AllowLimitedAccess"
				Ensure                                        = "Present"
				FilePickerExternalImageSearchEnabled          = $true
				HideSyncButtonOnTeamSite                      = $false
				LegacyAuthProtocolsEnabled                    = $true
				MarkNewFilesSensitiveByDefault                = "AllowExternalSharing"
				NotificationsInSharePointEnabled              = $true
				OfficeClientADALDisabled                      = $false
				OwnerAnonymousNotification                    = $true
				PublicCdnAllowedFileTypes                     = "CSS,EOT,GIF,ICO,JPEG,JPG,JS,MAP,PNG,SVG,TTF,WOFF"
				PublicCdnEnabled                              = $false
				SearchResolveExactEmailOrUPN                  = $false
				UseFindPeopleInPeoplePicker                   = $false
				UsePersistentCookiesForExplorerView           = $false
				UserVoiceForFeedbackEnabled                   = $true
			}
		}
		Teams              = @{}
	}
}
