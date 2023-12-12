function Write-Log {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[System.String]
		$Message,

		[Parameter()]
		[System.Int32]
		$Level = 0
	)

	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$indentation = "  " * $Level
	$output = "[{0}] {1}{2}" -f $timestamp, $indentation, $Message
	Write-Host $output
}

function Format-Json {
	[cmdletbinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[System.String]$RawJson,
		[Parameter()]
		[System.String]$IndentString = "`t"
	)

	$indent = 0
	$json = ($rawJson -replace "(\{|\[)[\s]*?(\}|\])","`$1`$2").Split([System.Environment]::NewLine,[System.StringSplitOptions]::RemoveEmptyEntries)
	$convJson = $json | ForEach-Object {
		$trimJson = $_.Trim()
		$line = ($IndentString * $indent) + $($trimJson -replace "`":\s+","`": ")

		if ($trimJson -match "[^\{\[,]$") {
			# This line doesn't end with '{', '[' or ',', decrement the indentation level
			$indent--
		}

		if ($trimJson -match "^[\{\[]|[\{\[]$") {
			# This line starts or ends with '[' or '{', increment the indentation level
			$indent++
		}
		$line
	}
	$returnValue = $convJson -join [System.Environment]::NewLine
	$returnValue = [Regex]::Replace($returnValue,"(?<![\\])\\u(?<Value>[a-zA-Z0-9]{4})", {
			param($m) ([char]([int]::Parse($m.Groups['Value'].Value,[System.Globalization.NumberStyles]::HexNumber))).ToString()
		}
	)
	return $returnValue
}

function Import-DataFile {
	<#
	.Synopsis
	Imports a PowerShell data file of unlimited size as hash table

	.Description
	Imports a PowerShell data file of unlimited size as hash table

	.Parameter Path
	The path to the file being imported. Wildcards are allowed but only the first matching file is imported.

	.Example
	Import-DataFile -Path 'C:\PathToDataFile\DataFile.psd1'
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[System.String]
		$Path
	)

	$content = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
	$scriptBlock = [Scriptblock]::Create($content)
	$dataFileAsHash = $scriptBlock.InvokeReturnAsIs()

	return $dataFileAsHash
}

function Install-GenericModules {
	<#
	.Synopsis
	Installs all generic Microsoft365DSC supporting modules from PSGallery or a custom NuGet repository

	.Description
	This function installs the latest versions of all supporting Microsoft365DSC generic modules
	from PSGallery or a custom NuGet package feed, except for the M365DSC.CompositeResources module, where
	it installs the latest version that corresponds the given Microsoft365DSC module version.

	.Parameter PackageSourceLocation
	The URI of the NuGet repository where the generic modules are published. It defaults to the URI of PSGallery.

	.Parameter PATToken
	The Personal Access Token that is granted at least read access to the custom NuGet repository

	.Parameter Version
	The version of the Microsoft365DSC module that is being used

	.Example
	Install-GenericModules -Version '1.23.1115.1'

	Install-GenericModules -PackageSourceLocation 'https://pkgs.dev.azure.com/Organization/Project/_packaging/Feed/nuget/v2' -PATToken 'abcd123' -Version '1.23.1115.1'
	#>
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[AllowNull()]
		[AllowEmptyString()]
		[System.String]
		$PackageSourceLocation = (Get-PSRepository -Name PSGallery).SourceLocation,

		[Parameter()]
		[AllowNull()]
		[AllowEmptyString()]
		[System.String]
		$PATToken,

		[Parameter(Mandatory)]
		[System.String]
		$Version
	)
	if ($null -eq $PackageSourceLocation -or $PackageSourceLocation -eq "") {
		$PackageSourceLocation = (Get-PSRepository -Name PSGallery).SourceLocation
	}

	$script:level++
	Write-Log -Message "Summary:" -Level $script:level
	Write-Log -Message "- Microsoft365DSC Version: $Version" -Level $script:level
	Write-Log -Message "- Repository URI:          $PackageSourceLocation" -Level $script:level
	Write-Log -Message " "

	if ($PackageSourceLocation -notmatch "www.powershellgallery.com") {
		Write-Log -Message "Registering generic package feed as PSRepository" -Level $script:level
		$repositoryName = "M365DSC_Generic_Modules"

		if ($PATToken) {
			$credsAzureDevopsServices = New-Object System.Management.Automation.PSCredential("USERNAME", ($PATToken | ConvertTo-SecureString -AsPlainText -Force))
			$parameters = @{
				Name         = $repositoryName
				Location     = $PackageSourceLocation
				ProviderName = "PowerShellGet"
				Trusted      = $true
				Credential   = $credsAzureDevopsServices
			}
		}
		else {
			$parameters = @{
				Name         = $repositoryName
				Location     = $PackageSourceLocation
				ProviderName = "PowerShellGet"
				Trusted      = $true
			}
		}

		$registeredRepos = Get-PSRepository
		if ($registeredRepos -contains $repositoryName) {
			$script:level++
			Write-Log -Message "The repository '$repositoryName' is already registered. Skipping registration." -Level $script:level
			$script:level--
		}
		else {
			Register-PackageSource @parameters
		}
	}
	else {
		$repositoryName = "PSGallery"
	}

	Write-Log -Message "Querying required generic modules" -Level $script:level
	$resourceModules = Import-DataFile -Path (Join-Path -Path $workingDirectory -ChildPath "DscResources.psd1")
	$reqModules = [System.Collections.HashTable]::new($resourceModules)
	$reqModules.Remove("Microsoft365DSC")
	$resourceModules.GetEnumerator() | Where-Object {$_.Value -match "^$"} | ForEach-Object {$reqModules.Remove($_.Name)}
	Write-Log -Message "- Found $($reqModules.Keys.Count) required generic module(s):" -Level $script:level
	Out-Default -InputObject $reqModules

	$script:level++
	$genericModules = @()
	foreach ($moduleName in $reqModules.Keys) {
		$moduleVersion = $reqModules.$moduleName

		$parameters = @{
			Name        = $moduleName
			Repository  = $repositoryName
			ErrorAction = "Ignore"
		}
		if ($PATToken) {
			$parameters.Add("Credential", $credsAzureDevopsServices)
		}
		switch ($moduleVersion) {
			"" {continue}
			$null {continue}
			latest {continue}
			latestMatchingMicrosoft365DSC {
				$parameters.Add("MinimumVersion", ("{0}00" -f $Version))
				$parameters.Add("MaximumVersion", ("{0}99" -f $Version))
			}
			Default {
				$parameters.Add("RequiredVersion", $moduleVersion)
			}
		}

		Write-Log -Message "Querying module '$($parameters.Name)'" -Level $script:level
		$matchingModule = Find-Module @parameters
		if ($matchingModule) {
			Write-Log -Message "- Found module '$($parameters.Name) v$($matchingModule.Version.ToString())'" -Level $script:level
			$genericModules += $matchingModule
		}
		else {
			Write-Log -Message "- [ERROR] Can't find the '$($parameters.Name)' module matching the specified version: '$moduleVersion'." -Level $script:level
		}
	}
	$script:level--
	
	if ($genericModules.Count -ne $reqModules.Keys.Count) {
		Write-Log -Message "[ERROR] Couldn't find one or more required generic modules specified in DscResources.psd1. Exiting!" -Level $script:level
		Write-Host "##vso[task.complete result=Failed;]Failed"
		exit -1
	}

	Write-Log -Message "Installing required generic modules" -Level $script:level
	$script:level++
	foreach ($module in $genericModules) {
		Write-Log -Message "Installing module '$($module.Name) v$($module.Version.ToString())'" -Level $script:level
		$parameters = @{
			Name            = $module.Name
			RequiredVersion = $module.Version.ToString()
			Repository      = $repositoryName
			Scope           = "AllUsers"
			AllowClobber    = $true
			Force           = $true
			WarningAction   = "Ignore"
		}
		if ($PATToken) {
			$parameters.Add("Credential", $credsAzureDevopsServices)
		}

		try {
			Install-Module @parameters
			Write-Log -Message "Uninstalling obsolete versions of module '$($module.Name)'" -Level $script:level
			Get-InstalledModule -Name $module.Name -AllVersions | Where-Object {$_.Version -ne $module.Version} | Uninstall-Module -Force
		}
		catch {
			Write-Log -Message "$($_.Exception.Message.Trim("."))." -Level $script:level
		}
	}
	$script:level--
	
	if ($repositoryName -ne "PSGallery") {
		Write-Log -Message "Unregistering PSRepository" -Level $script:level
		Unregister-PSRepository -Name $repositoryName
	}
	$script:level--
}

function Initialize-PSGallery {
	$script:level++
	Write-Log -Message "Checking PowerShellGet presence and version" -Level $script:level
	Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$psGetModule = Get-Module -Name "PowerShellGet" -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
	if ($psGetModule.Version -lt [System.Version]"2.2.4.0") {
		$script:level++
		Write-Log -Message "Installing PowerShellGet" -Level $script:level
		$null = Install-Module -Name "PowerShellGet" -Scope AllUsers -SkipPublisherCheck -Force
		$script:level--
	}
	$script:level--
}

function Install-DSCModule {
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[System.String]
		$Version
	)

	$script:level++
	Write-Log -Message "Checking Microsoft365DSC versions" -Level $script:level
	if ($Version) {
		$reqVersion = $Version
	}
	else {
		$reqModules = Import-DataFile -Path (Join-Path -Path $workingDirectory -ChildPath "DscResources.psd1")

		if (-not $reqModules.ContainsKey("Microsoft365DSC")) {
			Write-Log -Message "[ERROR] Unable to find Microsoft365DSC in DscResources.psd1. Exiting!" -Level $script:level
			Write-Host "##vso[task.complete result=Failed;]Failed"
			exit 10
		}
		else {
			$reqVersion = $reqModules.Microsoft365DSC
		}
	}
	$localModule = Get-Module -Name Microsoft365DSC -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1

	Write-Log -Message "- Required version : $reqVersion" -Level $script:level
	Write-Log -Message "- Installed version: $($localModule.Version)" -Level $script:level

	if ($localModule.Version -ne $reqVersion) {
		if ($null -ne $localModule) {
			Write-Log -Message "Incorrect version installed. Removing current module." -Level $script:level
			$m365ModulePath = Join-Path -Path "$($env:ProgramFiles)\WindowsPowerShell\Modules" -ChildPath "Microsoft365DSC"
			Remove-Item -Path $m365ModulePath -Force -Recurse -ErrorAction SilentlyContinue
		}

		Initialize-PSGallery

		Write-Log -Message "Installing Microsoft365DSC v$reqVersion" -Level $script:level
		$null = Install-Module -Name "Microsoft365DSC" -RequiredVersion $reqVersion -Scope AllUsers
	}
	else {
		Write-Log -Message "Correct version installed, continuing." -Level $script:level
	}
	$script:level--

	return $reqVersion
}
