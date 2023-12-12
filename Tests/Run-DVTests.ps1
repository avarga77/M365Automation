#Requires -Modules Pester

[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)]
	[System.Collections.Hashtable]$ConfigData
)

$Params = [ordered]@{
	Path = (Join-Path -Path $PSScriptRoot -ChildPath "QA\DataValidation.Tests.ps1")
	Data = @{
		ConfigData = $ConfigData
	}
}

$Container = New-PesterContainer @Params

$Configuration = [PesterConfiguration]@{
	Run    = @{
		Container = $Container
		PassThru  = $true
	}
	Output = @{
		Verbosity = "Detailed"
	}
}

$result = Invoke-Pester -Configuration $Configuration

return $result
