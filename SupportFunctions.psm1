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
    $output = "[{0}] - {1}{2}" -f $timestamp, $indentation, $Message
    Write-Host $output
}

function Format-Json {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.String]$RawJson,
        [Parameter()]
        [System.String]$IndentString = "`t"
    )

    $indent = 0
    $json = ($rawJson -replace "(\{|\[)[\s]*?(\}|\])", "`$1`$2").Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
    $convJson = $json | ForEach-Object {
        $trimJson = $_.Trim()
        $line = ($IndentString * $indent) + $($trimJson -replace "`":\s+", "`": ")

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
    $returnValue = [Regex]::Replace($returnValue, "(?<![\\])\\u(?<Value>[a-zA-Z0-9]{4})", {
            param($m) ([char]([int]::Parse($m.Groups['Value'].Value, [System.Globalization.NumberStyles]::HexNumber))).ToString()
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
    Write-Log -Message "- Repository URI         : $PackageSourceLocation" -Level $script:level
    Write-Log -Message " "

    if ($PackageSourceLocation -notmatch "www.powershellgallery.com")
    {
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
    $resourceModules = Import-DataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath "DscResources.psd1")
    $reqModules = [System.Collections.HashTable]::new($resourceModules)
    $reqModules.Remove("Microsoft365DSC")
    $resourceModules.GetEnumerator() | Where-Object { $_.Value -match "^$" } | ForEach-Object { $reqModules.Remove($_.Name) }
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
            "" { continue }
            $null { continue }
            latest { continue }
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

    $oldProgressPreference = $progressPreference
    $progressPreference = "SilentlyContinue"

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

    $progressPreference = $oldProgressPreference

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
        $reqModules = Import-DataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath "DscResources.psd1")

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

function Write-Psd
{
    <#
        .Synopsis
        Converts an object into a string so it can be written to PSD file.

        .Description
        This function converts an inputted object into a string so it can be written to a PSD1 file.

        .Example
        Write-Psd -Object $configData

        .Parameter Object
        Specifies the object that needs to be converted to a string.

        .Parameter Depth
        Specifies how deep the recursion should go. The default is 0, which means no recursion.

        .Parameter NoIndent
        Specifies that the output should not be indented.
    #>
    [CmdletBinding()]
    [OutputType()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $Object,

        [Parameter()]
        [System.Int32]
        $Depth = 0,

        [Parameter()]
        [switch]
        $NoIndent
    )

    process
    {
        $indent1 = $script:Indent * $Depth
        if (!$NoIndent)
        {
            $script:Writer.Write($indent1)
        }

        if ($null -eq $Object)
        {
            $script:Writer.WriteLine('$null')
            return
        }

        $type = $Object.GetType()
        switch ([System.Type]::GetTypeCode($type))
        {
            Object
            {
                if ($type -eq [System.Guid] -or $type -eq [System.Version])
                {
                    $script:Writer.WriteLine("'{0}'", $Object)
                    return
                }
                if ($type -eq [System.Management.Automation.SwitchParameter])
                {
                    $script:Writer.WriteLine($(if ($Object)
                            {
                                '$true'
                            }
                            else
                            {
                                '$false'
                            }))
                    return
                }
                if ($type -eq [System.Uri])
                {
                    $script:Writer.WriteLine("'{0}'", $Object.ToString().Replace("'", "''"))
                    return
                }
                if ($script:Depth -and $Depth -ge $script:Depth)
                {
                    $script:Writer.WriteLine("''''")
                    ++$script:Pruned
                    return
                }
                if ($Object -is [System.Collections.IDictionary])
                {
                    if ($Object.Count)
                    {
                        $itemNo = 0
                        $script:Writer.WriteLine('@{')
                        $indent2 = $script:Indent * ($Depth + 1)
                        foreach ($e in $Object.GetEnumerator())
                        {
                            $key = $e.Key
                            $value = $e.Value
                            $keyType = $key.GetType()
                            if ($keyType -eq [string])
                            {
                                if ($key -match '^\w+$' -and $key -match '^\D')
                                {
                                    $script:Writer.Write('{0}{1} = ', $indent2, $key)
                                }
                                else
                                {
                                    $script:Writer.Write("{0}'{1}' = ", $indent2, $key.Replace("'", "''"))
                                }
                            }
                            elseif ($keyType -eq [int])
                            {
                                $script:Writer.Write('{0}{1} = ', $indent2, $key)
                            }
                            elseif ($keyType -eq [long])
                            {
                                $script:Writer.Write('{0}{1}L = ', $indent2, $key)
                            }
                            elseif ($script:Depth)
                            {
                                ++$script:Pruned
                                $script:Writer.Write('{0}item__{1} = ', $indent2, ++$itemNo)
                                $value = New-Object 'System.Collections.Generic.KeyValuePair[object, object]' $key, $value
                            }
                            else
                            {
                                throw "Not supported key type '$($keyType.FullName)'."
                            }
                            Write-Psd -Object $value -Depth ($Depth + 1) -NoIndent
                        }
                        $script:Writer.WriteLine("$indent1}")
                    }
                    else
                    {
                        $script:Writer.WriteLine('@{}')
                    }
                    return
                }
                if ($Object -is [System.Collections.IEnumerable])
                {
                    $script:Writer.Write('@(')
                    $empty = $true
                    foreach ($e in $Object)
                    {
                        if ($empty)
                        {
                            $empty = $false
                            $script:Writer.WriteLine()
                        }
                        Write-Psd -Object $e -Depth ($Depth + 1)
                    }
                    if ($empty)
                    {
                        $script:Writer.WriteLine(')')
                    }
                    else
                    {
                        $script:Writer.WriteLine("$indent1)" )
                    }
                    return
                }
                if ($Object -is [scriptblock])
                {
                    $script:Writer.WriteLine('{{{0}}}', $Object)
                    return
                }
                if ($Object -is [PSCustomObject] -or $script:Depth)
                {
                    $script:Writer.WriteLine('@{')
                    $indent2 = $script:Indent * ($Depth + 1)
                    foreach ($e in $Object.PSObject.Properties)
                    {
                        $key = $e.Name
                        if ($key -match '^\w+$' -and $key -match '^\D')
                        {
                            $script:Writer.Write('{0}{1} = ', $indent2, $key)
                        }
                        else
                        {
                            $script:Writer.Write("{0}'{1}' = ", $indent2, $key.Replace("'", "''"))
                        }
                        Write-Psd -Object $e.Value -Depth ($Depth + 1) -NoIndent
                    }
                    $script:Writer.WriteLine("$indent1}")
                    return
                }
            }
            String
            {
                $script:Writer.WriteLine("'{0}'", $Object.Replace("'", "''"))
                return
            }
            Boolean
            {
                $script:Writer.WriteLine($(if ($Object)
                        {
                            '$true'
                        }
                        else
                        {
                            '$false'
                        }))
                return
            }
            DateTime
            {
                $script:Writer.WriteLine("[DateTime] '{0}'", $Object.ToString('o'))
                return
            }
            Char
            {
                $script:Writer.WriteLine("'{0}'", $Object.Replace("'", "''"))
                return
            }
            DBNull
            {
                $script:Writer.WriteLine('$null')
                return
            }
            default
            {
                if ($type.IsEnum)
                {
                    $script:Writer.WriteLine("'{0}'", $Object)
                }
                else
                {
                    $script:Writer.WriteLine($Object)
                }
                return
            }
        }

        throw "Not supported type '{0}'." -f $type.FullName
    }
}

function ConvertTo-Psd
{
    <#
        .Synopsis
        Converts the inputted object to a hashtable in string format, which can be saved as PSD.

        .Description
        This function converts the inputted object to a string format, which can then be saved to a PSD1 file.

        .Example
        $configData = @{
            Value1 = "String1"
            Value2 = 25
            Value3 = @{
                Value4 = "String2"
                Value5 = 50
            }
            Value6 = @(
                @{
                    Value7 = "String3"
                    Value8 = 75
                }
            )
        }
        $configData | ConvertTo-Psd

        .Parameter InputObject
        The InputObject parameter specified the object that has to be converted into PSD format.

        .Parameter Depth
        The Depth parameter specifies how deep the recursion should go.

        .Parameter Indent
        The Indent parameter is the number of spaces that need to be indented.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Position = 0, ValueFromPipeline = 1)]
        [System.Object]
        $InputObject,

        [Parameter()]
        [System.Int32]
        $Depth,

        [Parameter()]
        [System.String]
        $Indent
    )

    begin
    {
        $objects = [System.Collections.Generic.List[object]]@()
    }

    process
    {
        $objects.Add($InputObject)
    }

    end
    {
        trap
        {
            Invoke-TerminatingError $_
        }

        $script:Depth = $Depth
        $script:Pruned = 0
        $script:Indent = Convert-Indent -Indent $Indent
        $script:Writer = New-Object System.IO.StringWriter
        try
        {
            foreach ($object in $objects)
            {
                Write-Psd -Object $object
            }
            $script:Writer.ToString().TrimEnd()
            if ($script:Pruned)
            {
                Write-Warning "ConvertTo-Psd truncated $script:Pruned objects."
            }
        }
        finally
        {
            $script:Writer = $null
        }
    }
}

function Invoke-TerminatingError
{
    <#
        .Synopsis
        Throws a terminating error.

        .Description
        This function throws a terminating error, which makes sure the code actually stops.

        .Example
        Invoke-TerminatingError

        .Parameter M
        The M parameter is the message that needs to be displayed when the error is thrown.
      #>
    [CmdletBinding()]
    [OutputType()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $M
    )

    process
    {
        $PSCmdlet.ThrowTerminatingError((New-Object System.Management.Automation.ErrorRecord ([Exception]"$M"), $null, 0, $null))
    }
}

function Convert-Indent
{
    <#
        .Synopsis
        Converts a numbered indentation into spaces or tabs

        .Description
        This function converts a numbered indentation into spaces or tabs.

        .Example
        Convert-Ident -Indent 2

        .Parameter Indent
        The Indent parameter is the number of spaces or tabs that need to be returned.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param
    (
        [Parameter()]
        [System.String]
        $Indent
    )

    process
    {
        switch ($Indent)
        {
            ''  { return '    ' }
            '1' { return "`t" }
            '2' { return '  ' }
            '4' { return '    ' }
            '0' { return '' }
        }
        $Indent
    }
}

function Clone-Object
{
    param
    (
        [Parameter()]
        [System.Object]
        $Object
    )

    $memStream = New-Object IO.MemoryStream
    $formatter = New-Object Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $formatter.Serialize($memStream, $Object)
    $memStream.Position = 0
    $formatter.Deserialize($memStream)
}
