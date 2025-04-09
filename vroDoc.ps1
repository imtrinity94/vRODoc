<#
.SYNOPSIS
vRODoc - Converts vRO Code directly into JSDoc website with automatic prerequisite checks and fixes.

.DESCRIPTION
This enhanced script performs prerequisite validation before execution and attempts to automatically fix missing dependencies.
It converts vRO Packages into JSDoc documentation by connecting to vRO and creates a searchable HTML documentation site.

.PARAMETER vroHost
The FQDN of vRO host
.PARAMETER vroPort
For 7.x = 8281 and for 8.x = 443 
.PARAMETER user
Username to connect to vroHost
.PARAMETER pass
Password to connect to vroHost
.PARAMETER exportPath
Specify full path of a folder location for all the action to happen.
.PARAMETER packageName
Specify the package name in vroHost which contains the actions to be documented.
.PARAMETER autoFix
Automatically attempt to fix missing prerequisites (default: $true)
.PARAMETER skipChecks
Skip prerequisite checks (not recommended)
#>

Param(
    [string]$vroHost = "vro.domain",
    [string]$vroPort = "443",
    [string]$user = "user@domain",
    [string]$pass = "pa$$word",
    [string]$exportPath = "C:\Users\user\",
    [Parameter(Mandatory = $true)]
    [string]$packageName = 'code.important.actions',
    [bool]$autoFix = $true,
    [bool]$skipChecks = $false
)

#region Initialization
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$script:prereqPassed = $true
$fileName = $packageName + ".package"
$slash = "\"
#endregion

#region Helper Functions
function Write-ColorOutput {
    param(
        [string]$message,
        [string]$color = "White"
    )
    Write-Host $message -ForegroundColor $color
}

function Test-CommandExists {
    param($command)
    try {
        if (Get-Command $command -ErrorAction SilentlyContinue) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Install-NodeJS {
    Write-ColorOutput "Node.js not found. Attempting to install..." -color "Yellow"
    try {
        # Download and install Node.js LTS
        $nodeInstaller = "$env:TEMP\nodejs.msi"
        Invoke-WebRequest "https://nodejs.org/dist/v18.16.0/node-v18.16.0-x64.msi" -OutFile $nodeInstaller
        Start-Process msiexec.exe -ArgumentList "/i", "$nodeInstaller", "/quiet", "/norestart" -Wait
        Remove-Item $nodeInstaller -Force
        Write-ColorOutput "Node.js installed successfully" -color "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Failed to install Node.js automatically. Please install manually from https://nodejs.org/" -color "Red"
        return $false
    }
}

function Install-JSDoc {
    Write-ColorOutput "JSDoc not found. Attempting to install..." -color "Yellow"
    try {
        npm install -g jsdoc
        Write-ColorOutput "JSDoc installed successfully" -color "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Failed to install JSDoc. Please run 'npm install -g jsdoc' manually" -color "Red"
        return $false
    }
}

function Test-PowerShellVersion {
    $minVersion = 5.1
    $currentVersion = $PSVersionTable.PSVersion
    
    if ($currentVersion -ge $minVersion) {
        return $true
    }
    
    Write-ColorOutput "PowerShell version $currentVersion detected. Minimum required version is $minVersion." -color "Red"
    
    if ($autoFix) {
        Write-ColorOutput "Attempting to update PowerShell..." -color "Yellow"
        try {
            # Different update methods for different Windows versions
            if ($env:OS -eq "Windows_NT") {
                if ((Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2).State -eq "Disabled") {
                    Enable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart
                }
                
                # Check for Windows Management Framework 5.1
                $wmfUrl = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win8.1AndW2K12R2-KB3191564-x64.msu"
                $wmfInstaller = "$env:TEMP\WMF5.1.msu"
                
                if (-not (Test-Path $wmfInstaller)) {
                    Invoke-WebRequest $wmfUrl -OutFile $wmfInstaller
                }
                
                Start-Process "wusa.exe" -ArgumentList $wmfInstaller, "/quiet", "/norestart" -Wait
                Write-ColorOutput "PowerShell update initiated. A restart may be required." -color "Yellow"
            }
        }
        catch {
            Write-ColorOutput "Automatic PowerShell update failed. Please update manually." -color "Red"
        }
    }
    
    return $false
}

function Test-ExportPath {
    param($path)
    try {
        if (-not (Test-Path $path)) {
            Write-ColorOutput "Export path does not exist. Creating directory..." -color "Yellow"
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
        
        # Test write access
        $testFile = Join-Path $path "testfile.tmp"
        [System.IO.File]::WriteAllText($testFile, "test")
        Remove-Item $testFile -Force
        return $true
    }
    catch {
        Write-ColorOutput "Cannot write to export path: $path" -color "Red"
        return $false
    }
}

function Test-InternetConnection {
    try {
        $response = Invoke-WebRequest "https://nodejs.org" -Method Head -UseBasicParsing -TimeoutSec 10
        return $true
    }
    catch {
        Write-ColorOutput "Internet connection test failed. Some automatic fixes may not work." -color "Yellow"
        return $false
    }
}

function Test-Prerequisites {
    Write-ColorOutput "`n=== Checking Prerequisites ===" -color "Cyan"
    
    $allPassed = $true
    
    # Check PowerShell version
    if (-not (Test-PowerShellVersion)) {
        $allPassed = $false
        Write-ColorOutput "[X] PowerShell version too old" -color "Red"
    }
    else {
        Write-ColorOutput "[✓] PowerShell version OK" -color "Green"
    }
    
    # Check Node.js
    if (-not (Test-CommandExists "node")) {
        $allPassed = $false
        Write-ColorOutput "[X] Node.js not found" -color "Red"
        
        if ($autoFix -and (Test-InternetConnection)) {
            if (Install-NodeJS) {
                $allPassed = $true
                Write-ColorOutput "[✓] Node.js installed successfully" -color "Green"
            }
        }
    }
    else {
        Write-ColorOutput "[✓] Node.js found" -color "Green"
    }
    
    # Check JSDoc
    if (-not (Test-CommandExists "jsdoc")) {
        $allPassed = $false
        Write-ColorOutput "[X] JSDoc not found" -color "Red"
        
        if ($autoFix -and (Test-InternetConnection)) {
            if (Install-JSDoc) {
                $allPassed = $true
                Write-ColorOutput "[✓] JSDoc installed successfully" -color "Green"
            }
        }
    }
    else {
        Write-ColorOutput "[✓] JSDoc found" -color "Green"
    }
    
    # Check export path
    if (-not (Test-ExportPath $exportPath)) {
        $allPassed = $false
        Write-ColorOutput "[X] Export path issue" -color "Red"
    }
    else {
        Write-ColorOutput "[✓] Export path OK" -color "Green"
    }
    
    return $allPassed
}
#endregion

#region Main Script Execution
try {
    Write-ColorOutput "`nvRODoc - Automated vRO Documentation Generator" -color "Magenta"
    Write-ColorOutput "Version 2.2.0 (Enhanced with Prerequisite Checks)`n" -color "Cyan"
    
    # Skip checks if requested
    if (-not $skipChecks) {
        $script:prereqPassed = Test-Prerequisites
    }
    else {
        Write-ColorOutput "Prerequisite checks skipped by user request" -color "Yellow"
        $script:prereqPassed = $true
    }
    
    if (-not $script:prereqPassed) {
        Write-ColorOutput "`n[!] Prerequisite checks failed. Some features may not work." -color "Red"
        $confirmation = Read-Host "Continue anyway? (y/n)"
        if ($confirmation -ne 'y') {
            exit 1
        }
    }
    
    # Proceed with main script functionality
    Write-ColorOutput "`n=== Starting vRO Documentation Generation ===" -color "Cyan"
    
    # Increase timeout for web requests
    [System.Net.ServicePointManager]::MaxServicePointIdleTime = 30000

    function ConvertTo-Base64($string) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($string)
        $encoded = [System.Convert]::ToBase64String($bytes)
        return $encoded
    }

    # New function to get vRA token with simplified SSL handling
    function Get-VraToken {
        param(
            [string]$vraHost = $vroHost,
            [string]$username = $user,
            [string]$password = $pass
        )
        
        Write-ColorOutput "Obtaining vRA authentication token..." -color "Yellow"
        
        try {
            # Prepare authentication request
            $authUrl = "https://$vraHost/csp/gateway/am/api/login"
            Write-ColorOutput "Auth URL: $authUrl" -color "Cyan"
            
            # Set up headers
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            
            # Prepare request body
            $body = @{
                username = $username
                password = $password
            } | ConvertTo-Json
            
            $authParams = @{
                Uri = $authUrl
                Method = "POST"
                Headers = $headers
                Body = $body
                UseBasicParsing = $true
                TimeoutSec = 60
                SkipCertificateCheck = $true
            }
            
            # Request token with better error handling
            try {
                Write-ColorOutput "Sending authentication request..." -color "Yellow"
                $response = Invoke-RestMethod @authParams -ErrorAction Stop
                
                # Debug response
                Write-ColorOutput "Response received. Checking content..." -color "Yellow"
                $response | ConvertTo-Json | Write-ColorOutput -color "Cyan"
                
                if ($response.cspAuthToken) {
                    Write-ColorOutput "Successfully obtained vRA token" -color "Green"
                    return $response.cspAuthToken
                }
                else {
                    throw "Failed to obtain token from response"
                }
            }
            catch {
                Write-ColorOutput "Error: $($_.Exception.Message)" -color "Red"
                if ($_.ErrorDetails) {
                    Write-ColorOutput "Error Details: $($_.ErrorDetails)" -color "Red"
                }
                throw
            }
        }
        catch {
            Write-ColorOutput "Error obtaining vRA token: $($_.Exception.Message)" -color "Red"
            throw "Authentication with vRA failed. Please check credentials and connectivity."
        }
    }

    # Get vRA token
    $token = Get-VraToken
    
    # Use bearer token with additional headers
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $token")
    $headers.Add("Accept", "application/zip")
    $headers.Add("Cookie", "JSESSIONID=3CEE0E72A60FCB93090EDB0781FE6882")

    # Create vRODoc Files directory if it doesn't exist
    $mainFolder = Join-Path $exportPath "vRODoc Files"
    if (-not (Test-Path $mainFolder)) {
        New-Item -ItemType Directory -Path $mainFolder -Force | Out-Null
    }
    
    # Export package from vRO with enhanced error handling
    Write-ColorOutput "Exporting package from vRO..." -color "Yellow"
    $expPackageURI = "https://$($vroHost):$($vroPort)/vco/api/packages/$($packageName)?exportConfigurationAttributeValues=true&exportGlobalTags=true&exportVersionHistory=true&exportConfigSecureStringAttributeValues=false&allowedOperations=vef&exportExtensionData=false"
    
    try {
        # Use more parameters for better control
        $webRequestParams = @{
            Uri = $expPackageURI
            Headers = $headers
            Method = "Get"
            UseBasicParsing = $true
            TimeoutSec = 120
            SkipCertificateCheck = $true
            OutFile = "$mainFolder\$fileName"
        }
        
        Invoke-RestMethod @webRequestParams
        
        if (Test-Path "$mainFolder\$fileName") {
            Write-ColorOutput "Package exported to: $mainFolder\$fileName" -color "Green"
        }
        else {
            throw "Failed to save the package file"
        }
    }
    catch {
        Write-ColorOutput "Error connecting to vRO server: $($_.Exception.Message)" -color "Red"
        Write-ColorOutput "Checking connectivity to $vroHost..." -color "Yellow"
        
        # Test basic connectivity
        try {
            Test-NetConnection -ComputerName $vroHost -Port $vroPort -InformationLevel Quiet
            Write-ColorOutput "Network connectivity to $vroHost on port $vroPort is available." -color "Green"
        }
        catch {
            Write-ColorOutput "Cannot connect to $vroHost on port $vroPort. Please check network connectivity." -color "Red"
        }
        
        throw "Failed to export package from vRO. Please check server details and credentials."
    }

    # Extract package
    $packageFolder = Join-Path $mainFolder $packageName
    Write-ColorOutput "Extracting package..." -color "Yellow"
    Expand-Archive -LiteralPath "$mainFolder\$fileName" -DestinationPath $packageFolder -Force
    Write-ColorOutput "Package extracted to: $packageFolder" -color "Green"

    # Clean up zip file
    Remove-Item "$mainFolder\$fileName" -Force
    Write-ColorOutput "Cleaned up package zip file" -color "Green"

    # Update paths for processing
    $ElementsFolder = Join-Path $packageFolder "elements"
    $savePath = $packageFolder

    if (-not (Test-Path $ElementsFolder)) {
        throw "Elements folder not found in the exported package. Export may have failed."
    }

    Write-ColorOutput "Processing vRO elements..." -color "Yellow"
    cd $ElementsFolder
    $dir = Get-ChildItem $ElementsFolder | Where-Object { $_.PSISContainer }

    foreach ($d in $dir) {
        cd $d
        
        # Get module information
        [xml]$xmlElm = Get-Content -Path .\categories -ErrorAction SilentlyContinue
        if ($xmlElm -and $xmlElm.categories) {
            $catNameFolder = $xmlElm.categories.category.name.'#cdata-section'
            Write-ColorOutput "Processing module: $catNameFolder" -color "Cyan"
        }

        [xml]$xmlElm = Get-Content -Path .\info -ErrorAction SilentlyContinue
        $elementType = $xmlElm.properties.entry.'#text'

        # Process Script Modules
        if ($elementType -contains "ScriptModule") {
            # Create module folder
            $modulePath = $savePath + $slash + 'Actions' + $slash + $catNameFolder
            if (-not (Test-Path $modulePath)) {
                New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
            }

            # Get action details
            [xml]$xmlElm = Get-Content -Path .\data -ErrorAction SilentlyContinue
            if (-not $xmlElm -or -not $xmlElm.'dunes-script-module') {
                Write-ColorOutput "  [!] Invalid script module format in $($d.Name)" -color "Red"
                continue
            }

            $actionName = $xmlElm.'dunes-script-module'.name + ".js"
            $actionParams = $xmlElm.'dunes-script-module'.param
            $actionScript = $xmlElm.'dunes-script-module'.script.'#cdata-section'

            # Create JSDoc formatted file
            $jsContent = @"
/**
 * @function $($xmlElm.'dunes-script-module'.name)
 * @version $($xmlElm.'dunes-script-module'.version)
"@

            # Add description only if it exists
            if ($xmlElm.'dunes-script-module'.description.'#cdata-section') {
                $jsContent += @"

 * @description $($xmlElm.'dunes-script-module'.description.'#cdata-section')
"@
            }

            # Add parameters
            foreach ($param in $actionParams) {
                $jsContent += @"

 * @param {$($param.t)} $($param.n) $($param.'#cdata-section')
"@
            }

            # Add return type if exists
            if ($xmlElm.'dunes-script-module'.'result-type') {
                $jsContent += @"

 * @returns {$($xmlElm.'dunes-script-module'.'result-type')}
"@
            }

            $jsContent += @"
            
 */
function $($xmlElm.'dunes-script-module'.name)($(($actionParams.n) -join ', ')) {
$($actionScript -replace "(?m)^", "`t")
}
"@

            # Save the file
            $jsContent | Out-File -FilePath (Join-Path $modulePath $actionName) -Encoding utf8
            Write-ColorOutput "  Generated: $actionName" -color "Green"
        }
        else {
            Write-ColorOutput "  Skipping non-ScriptModule element: $($d.Name)" -color "Gray"
        }

        cd ..
    }

    # Generate JSDoc documentation
    Write-ColorOutput "`nGenerating HTML documentation with JSDoc..." -color "Yellow"
    $jsdocPath = Join-Path $savePath "Actions"
    $docsPath = Join-Path $savePath "docs"
    
    if (Test-CommandExists "jsdoc") {
        jsdoc --recurse $jsdocPath -d $docsPath
        Write-ColorOutput "Documentation generated at: $docsPath" -color "Green"
        Write-ColorOutput "Open index.html in your browser to view the documentation" -color "Green"
    }
    else {
        Write-ColorOutput "JSDoc not available. HTML documentation generation skipped." -color "Red"
    }
    
    Write-ColorOutput "`n=== vRO Documentation Generation Complete ===" -color "Cyan"
}
catch {
    Write-ColorOutput "`n[!] ERROR: $($_.Exception.Message)" -color "Red"
    Write-ColorOutput "Stack Trace: $($_.ScriptStackTrace)" -color "DarkYellow"
    exit 1
}
finally {
    # Clean up if needed
}
#endregion
