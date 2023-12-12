BeforeDiscovery {
	$dataFilesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\DataFiles"

	# If there is no DataFiles folder, exit.
	if (-not (Test-Path -Path $dataFilesPath)) {
		Write-Error "DataFiles path not found!"
		return
	}

	$dataFiles = @(Get-ChildItem -Path $dataFilesPath -Filter "*.psd1" -Recurse)

	$dataFilesToTest = @()

	foreach ($datafile in $dataFiles) {
		$dataFilesToTest += @{
			DataFile                = $dataFile.FullName
			DataFileDescriptiveName = Join-Path -Path (Split-Path $dataFile.Directory -Leaf) -ChildPath (Split-Path $dataFile -Leaf)
		}
	}
}

Describe "Check if all data files are valid" {
	It "Import of data file <DataFileDescriptiveName> is successful" -TestCases $dataFilesToTest {
		$data = Import-DataFile -Path $DataFile 
		$data | Should -Not -BeNullOrEmpty
	}
}

Describe "Check DSC Composite Resources in module M365DSC.CompositeResources" {
	BeforeAll {
		$configModule = Get-Module -Name M365DSC.CompositeResources -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
		$moduleFolder = Split-Path -Path $configModule.Path -Parent
		$resourcesInModule = Get-ChildItem -Path (Join-Path -Path $moduleFolder -ChildPath "DSCResources") -Directory
		$resourcesFoundByDSC = Get-DscResource -Module "M365DSC.CompositeResources"
	}

	It "Number of resources in module should match number of resources found by DSC" {
		$resourcesFoundByDSC.Count | Should -Be $resourcesInModule.Count
	}
}
