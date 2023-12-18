[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)]
	[System.Collections.Hashtable]$ConfigData
)

Describe "Check if Config Data contains certain nodes" {
	It "Check AllNodes" {
		$ConfigData.ContainsKey("AllNodes") | Should -Be $true
	}

	It "Check NonNodeData" {
		$ConfigData.ContainsKey("NonNodeData") | Should -Be $true
	}

	It "Check NonNodeData\Environment" {
		$ConfigData.NonNodeData.ContainsKey("Environment") | Should -Be $true
	}

	It "Check NonNodeData\Environment\Name" {
		$ConfigData.NonNodeData.Environment.ContainsKey("Name") | Should -Be $true
	}

	It "Check NonNodeData\Environment\ShortName" {
		$ConfigData.NonNodeData.Environment.ContainsKey("ShortName") | Should -Be $true
	}

	It "Check NonNodeData\Environment\TenantId" {
		$ConfigData.NonNodeData.Environment.ContainsKey("TenantId") | Should -Be $true
		$ConfigData.NonNodeData.Environment.TenantId -match "\w+\.onmicrosoft\.com" | Should -Be $true
	}

	It "Check NonNodeData\Environment\OrganizationName" {
		$ConfigData.NonNodeData.Environment.ContainsKey("OrganizationName") | Should -Be $true
	}

	It "Check NonNodeData\AppCredentials" {
		$ConfigData.NonNodeData.ContainsKey("AppCredentials") | Should -Be $true
	}

	It "Check NonNodeData\AzureAD" {
		$ConfigData.NonNodeData.ContainsKey("AzureAD") | Should -Be $true
	}

	It "Check NonNodeData\Exchange" {
		$ConfigData.NonNodeData.ContainsKey("Exchange") | Should -Be $true
	}

	It "Check NonNodeData\Intune" {
		$ConfigData.NonNodeData.ContainsKey("Intune") | Should -Be $true
	}

	It "Check NonNodeData\Office365" {
		$ConfigData.NonNodeData.ContainsKey("Office365") | Should -Be $true
	}

	It "Check NonNodeData\OneDrive" {
		$ConfigData.NonNodeData.ContainsKey("OneDrive") | Should -Be $true
	}

	It "Check NonNodeData\Planner" {
		$ConfigData.NonNodeData.ContainsKey("Planner") | Should -Be $true
	}

	It "Check NonNodeData\PowerPlatform" {
		$ConfigData.NonNodeData.ContainsKey("PowerPlatform") | Should -Be $true
	}

	It "Check NonNodeData\SecurityCompliance" {
		$ConfigData.NonNodeData.ContainsKey("SecurityCompliance") | Should -Be $true
	}

	It "Check NonNodeData\SharePoint" {
		$ConfigData.NonNodeData.ContainsKey("SharePoint") | Should -Be $true
	}

	It "Check NonNodeData\Teams" {
		$ConfigData.NonNodeData.ContainsKey("Teams") | Should -Be $true
	}
}
