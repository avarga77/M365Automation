#Requires -Modules Pester

try {
    $functionsModule = Join-Path -Path $PSScriptRoot -ChildPath "TestSupportFunctions.psm1"
    Import-Module -Name $functionsModule -ErrorAction Stop
}
catch {
    Write-Host "ERROR: Could not load library 'TestSupportFunctions.psm1'. $($_.Exception.Message.Trim(".")). Exiting." -ForegroundColor Red
    exit -1
}

try {
    $mainFunctionsModule = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "SupportFunctions.psm1"
    Import-Module -Name $mainFunctionsModule -ErrorAction Stop
}
catch {
    Write-Host "ERROR: Could not load library 'SupportFunctions.psm1'. $($_.Exception.Message.Trim(".")). Exiting." -ForegroundColor Red
    exit -1
}

$Params = [ordered]@{
    Path = (Join-Path -Path $PSScriptRoot -ChildPath "QA\QualityAssurance.Tests.ps1")
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
