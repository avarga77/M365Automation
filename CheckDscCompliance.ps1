#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [System.Boolean]
    $UseMail = $false,

    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [System.String]
    $MailTenantId = "",

    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [System.String]
    $MailAppId = "",

    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [System.String]
    $MailAppSecret = "",

    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [System.String]
    $MailFrom = "",

    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [System.String]
    $MailTo = "",

    [Parameter(Mandatory)]
    [System.Boolean]
    $UseTeams = $false,

    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [System.String]
    $TeamsWebhook = ""
)

######## FUNCTIONS ########

$functionPath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "SupportFunctions.psm1"
try {
    Import-Module -Name $functionPath -ErrorAction Stop
}
catch {
    Write-Host "ERROR: Could not load library 'SupportFunctions.psm1'. $($_.Exception.Message.Trim(".")). Exiting." -ForegroundColor Red
    exit -1
}

######## SCRIPT VARIABLES ########

$workingDirectory = $PSScriptRoot
$encounteredError = $false
$level = 1
$global:progressPreference = "SilentlyContinue"

######## START SCRIPT ########

Write-Log -Message "*********************************************************"
Write-Log -Message "*       Starting Microsoft365DSC Compliance Check       *"
Write-Log -Message "*********************************************************"
Write-Log -Message " "
if ($UseMail -eq $false -and $UseTeams -eq $false) {
    Write-Log -Message "[ERROR] Both UseTeams and UseMail are set to False." -Level $level
    Write-Log -Message "Please configure a notification method before continuing!" -Level $level
    Write-Host "##vso[task.complete result=Failed;]Failed"
    exit 20
}

Write-Log -Message " "
Write-Log -Message "------------------------------------------------------------------"
Write-Log -Message " Checking for presence of Microsoft365DSC module and dependencies"
Write-Log -Message "------------------------------------------------------------------"
Write-Log -Message " "
$null = Install-DSCModule

Write-Log -Message "Checking module dependencies" -Level $level
Update-M365DSCDependencies

Write-Log -Message "Checking outdated module dependencies" -Level $level
Uninstall-M365DSCOutdatedDependencies

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Testing compliance on all environments"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
Write-Log -Message "Processing all MOF files in '$workingDirectory'" -Level $level

$mofFiles = Get-ChildItem -Path $workingDirectory -Filter *.mof -Recurse
Write-Log -Message "- Found $($mofFiles.Count) MOF files" -Level $level

$checkResults = @{}
$level++
foreach ($file in $mofFiles) {
    $envName = Split-Path -Path $file.DirectoryName -Leaf
    Write-Log -Message "Processing environment: $envName" -Level $level

    $checkResults.$envName = @{}

    try {
        $result = Test-DscConfiguration -ReferenceConfiguration $file.FullName -Verbose -ErrorAction Stop

        if ($result.InDesiredState -eq $false) {
            $checkResults.$envName.ErrorCount = $result.ResourcesNotInDesiredState.Count
            $checkResults.$envName.ErroredResources = $result.ResourcesNotInDesiredState.ResourceId -join ", "
        }
        else {
            $checkResults.$envName.ErrorCount = 0
            $checkResults.$envName.ErroredResources = ""
        }
    }
    catch {
        $checkResults.$envName.ErrorCount = 999
        $checkResults.$envName.ErroredResources = $_.Exception.Message
        $encounteredError = $true
        Write-Log -Message "[ERROR] An error occurred during DSC Compliance check: $($_.Exception.Message)" -Level $level
    }
}
$level--

Write-Log -Message " "
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " Creating report"
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
$htmlReport = "<!DOCTYPE html>"
$htmlReport += "<html>"
$htmlReport += "<head>"
$htmlReport += "<title>DSC Compliance Report</title>"
$htmlReport += "<style>table { border: 1px solid black; border-collapse: collapse; } th, td { padding: 10px; text-align:center } th { background-color: #00A4EF; color: white } .failed {background-color: red;} .nocenter {text-align:left;}</style>"
$htmlReport += "</head><body>"

$date = Get-Date -Format "yyyy-MM-dd"
$title = "DSC Compliance Report ({0})" -f $date
$htmlReport += "<H1>$title</H1>"

[System.Threading.Thread]::CurrentThread.CurrentUICulture = "en-US";
[System.Threading.Thread]::CurrentThread.CurrentCulture = "en-US";
$datetime = Get-Date -Format "ddd dd-MM-yyyy HH:mm"
$generatedAt = "Generated at: {0}<br>" -f $datetime
$htmlReport += $generatedAt
$htmlReport += "<br>"

$errorCount = 0
$erroredEnvironment = @()
foreach ($result in $checkResults.GetEnumerator()) {
    if ($result.Value.ErrorCount -gt 0) {
        $errorCount++
        $erroredEnvironment += $result.Key
    }
}

$incompliantEnvs = "Number of incompliant environments: {0}<br>" -f $errorCount
$htmlReport += $incompliantEnvs
$htmlReport += "<br>"

$htmlReport += "<H3>Environments</H3>"

$report = "<table>"
$report += "<tr><th>Environment</th><th>In Desired State</th><th>Error Count</th><th>Details</th></tr>"

foreach ($environment in $checkResults.GetEnumerator()) {
    if ($environment.Value.ErrorCount -gt 0) {
        $report += "<tr><td>{0}</td><td class=failed>False</td><td>{1}</td><td class=nocenter>{2}</td></tr>" -f $environment.Key, $environment.Value.ErrorCount, $environment.Value.ErroredResources
    }
    else {
        $report += "<tr><td>{0}</td><td>True</td><td>0</td><td class=nocenter>-</td></tr>" -f $environment.Key
    }
}
$report += "</table>"
$htmlReport += $report
$htmlReport += "<br>"

$htmlReport += "</body></html>"


Write-Log -Message "Report created!" -Level $level

if ($UseMail) {
    Write-Log -Message " "
    Write-Log -Message "-----------------------------------------------------"
    Write-Log -Message " Sending report via email"
    Write-Log -Message "-----------------------------------------------------"
    Write-Log -Message " "

    Write-Log -Message "Full HTML report:" -Level $level
    $level++
    Write-Log -Message $htmlReport -Level $level
    Write-Log -Message " "

    # Construct URI and body needed for authentication
    Write-Log -Message "Retrieving Authentication Token" -Level $level
    $uri = "https://login.microsoftonline.com/$MailTenantId/oauth2/v2.0/token"
    $body = @{
        client_id     = $MailAppId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $MailAppSecret
        grant_type    = "client_credentials"
    }

    $tokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing

    # Unpack Access Token
    $token = ($tokenRequest.Content | ConvertFrom-Json).access_token
    $Headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $token"
    }

    # Create message body and properties and send
    Write-Log -Message "Creating email object" -Level $level
    $MessageParams = @{
        "URI"         = "https://graph.microsoft.com/v1.0/users/$MailFrom/sendMail"
        "Headers"     = $Headers
        "Method"      = "POST"
        "ContentType" = "application/json"
        "Body"        = (@{
                "message" = @{
                    "subject"      = "DSC Compliance Report ($date)"
                    "body"         = @{
                        "contentType" = "HTML"
                        "content"     = $htmlReport
                    }
                    "toRecipients" = @(
                        @{
                            "emailAddress" = @{"address" = $MailTo }
                        }
                    )
                }
            } | ConvertTo-Json -Depth 6 | Format-Json)
    }

    try {
        Write-Log -Message "Trying to send mail" -Level $level
        Invoke-RestMethod @Messageparams
        $level--
        Write-Log -Message "Report sent!" -Level $level
    }
    catch {
        Write-Log -Message "[ERROR] Error while sending email message: $($_.Exception.Message)" -Level $level
        Write-Log -Message "        Make sure you have configured the App Credentials and the From / To email addresses correctly!" -Level $level
        $encounteredError = $true
        $level--
    }
}

if ($UseTeams) {
    # Documentation for Teams Message Card: https://docs.microsoft.com/en-us/microsoftteams/platform/task-modules-and-cards/cards/cards-reference#example-of-an-office-365-connector-card

    Write-Log -Message " "
    Write-Log -Message "-----------------------------------------------------"
    Write-Log -Message " Sending report via Teams"
    Write-Log -Message "-----------------------------------------------------"
    Write-Log -Message " "

    Write-Log -Message "Teams HTML message:" -Level $level
    $level++
    Write-Log -Message $report -Level $level
    Write-Log -Message " "

    if ($errorCount -gt 0) {
        # An error occurred during a check
        $themeColor = "FF0000"
        $activityTitle = "Check(s) failed!"
        $imageUrl = "https://cdn.pixabay.com/photo/2012/04/12/13/15/red-29985_1280.png"
    }
    else {
        # All checks succeeded
        $themeColor = "0078D7"
        $activityTitle = "All checks passed!"
        $imageUrl = "https://cdn.pixabay.com/photo/2016/03/31/14/37/check-mark-1292787_1280.png"
    }

    $JSONBody = [PSCustomObject][Ordered]@{
        "@type"      = "MessageCard"
        "@context"   = "http://schema.org/extensions"
        "summary"    = $title
        "themeColor" = $themeColor
        "title"      = $title
        "sections"   = @(
            [PSCustomObject][Ordered]@{
                "activityTitle"    = $activityTitle
                "activitySubtitle" = $generatedAt
                "activityText"     = $incompliantEnvs
                "activityImage"    = $imageUrl
            },
            [PSCustomObject][Ordered]@{
                "title" = "Details"
                "text"  = $report
            }
        )
    }

    $TeamMessageBody = ConvertTo-Json $JSONBody

    $parameters = @{
        "URI"         = $TeamsWebhook
        "Method"      = "POST"
        "Body"        = $TeamMessageBody
        "ContentType" = "application/json"
    }

    try {
        Write-Log -Message "Trying to send Teams message" -Level $level
        $restResult = Invoke-RestMethod @parameters
        if ($restResult -isnot [PSCustomObject] -or $restResult.isSuccessStatusCode -eq $false) {
            Write-Log -Message "[ERROR] Error while sending Teams message:" -Level $level
            Write-Log -Message $restResult -Level $level
            $encounteredError = $true
            $level--
        }
        else {
            $level--
            Write-Log -Message "Report sent!" -Level $level
        }
    }
    catch {
        Write-Log -Message "[ERROR] Error while sending Teams message: $($_.Exception.Message)" -Level $level
        $encounteredError = $true
        $level--
    }
}

Write-Log -Message "---------------------------------------------------------"
if ($encounteredError -eq $false -and $errorCount -eq 0) {
    Write-Log -Message " RESULT: Compliance check succeeded!"
}
else {
    Write-Log -Message " RESULT: Compliance check failed!"
    Write-Log -Message " Issues found during compliance check!" -Level $level
    Write-Log -Message " Make sure you correct all issues and try again." -Level $level
    if ($errorCount -gt 0) {
        Write-Log -Message " "
        Write-Log -Message " Environments with errors: $($errorCount) ($($erroredEnvironment -join ", "))" -Level $level
    }
    Write-Host "##vso[task.complete result=Failed;]Failed"
}
Write-Log -Message "---------------------------------------------------------"
Write-Log -Message " "
Write-Log -Message "*********************************************************"
Write-Log -Message "*       Finished Microsoft365DSC Compliance Check       *"
Write-Log -Message "*********************************************************"
Write-Log -Message " "
