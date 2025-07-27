<#
.SYNOPSIS
vRODoc - Converts vRO Code directly into JSDoc website with automatic prerequisite checks and fixes.

.DESCRIPTION
This enhanced script performs prerequisite validation before execution and attempts to automatically fix missing dependencies.
It converts vRO Packages into JSDoc documentation by connecting to vRO and creates a searchable HTML documentation site.

.PARAMETER vroHost
The FQDN of vRO host
.PARAMETER vroPort
Port to connect to vRO host (default: 443)
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
    [Parameter(Mandatory = $true)]
    [string]$vroHost,
    [ValidateScript({
        if ($_ -notmatch '^\d+$' -or [int]$_ -le 0 -or [int]$_ -gt 65535) {
            throw "Port must be a valid port number between 1 and 65535"
        }
        return $true
    })]
    [string]$vroPort = "443",
    [Parameter(Mandatory = $true)]
    [string]$user,
    [Parameter(Mandatory = $true)]
    [string]$pass,
    [Parameter(Mandatory = $true)]
    [string]$exportPath,
    [Parameter(Mandatory = $true)]
    [string]$packageName,
    [bool]$autoFix = $true,
    [bool]$skipChecks = $false,
    [string]$npmPath = $null
)

# Move log file initialization to the very top
$logDir = Join-Path -Path $PSScriptRoot -ChildPath "Logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$script:logFile = Join-Path -Path $logDir -ChildPath "vRODoc_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Logging started" | Out-File -FilePath $script:logFile -Force -Encoding UTF8

#region Initialization

# Function to write colored output to console and log file
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [string]$Level = "INFO",
        [switch]$NoLog
    )
    $colors = @{
        "Black" = 0;"DarkBlue" = 1;"DarkGreen" = 2;"DarkCyan" = 3;
        "DarkRed" = 4;"DarkMagenta" = 5;"DarkYellow" = 6;"Gray" = 7;
        "DarkGray" = 8;"Blue" = 9;"Green" = 10;"Cyan" = 11;
        "Red" = 12;"Magenta" = 13;"Yellow" = 14;"White" = 15;
    }
    if ($colors.ContainsKey($Color)) {
        Write-Host $Message -ForegroundColor $Color
    } else {
        Write-Host $Message
    }
    if (-not $NoLog) {
        $logMessage = $Message -replace "`e\[[0-9;]*m"
        if ($Level -eq "INFO") {
            switch ($Color) {
                "Green" { $Level = "SUCCESS" }
                "Red" { $Level = "ERROR" }
                "Yellow" { $Level = "WARNING" }
                "Cyan" { $Level = "INFO" }
                "Magenta" { $Level = "INFO" }
            }
        }
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $logMessage"
        try {
            $logMessage | Out-File -FilePath $script:logFile -Append -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            Write-Host "[WARNING] Failed to write to log file: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Function to prompt for mandatory parameters if not provided
function Get-MandatoryParameter {
    param(
        [string]$ParameterName,
        [string]$Description,
        [string]$DefaultValue = "",
        [switch]$IsPassword
    )
    # Use the variable value directly
    $value = Get-Variable -Name $ParameterName -ValueOnly -ErrorAction SilentlyContinue
    $explicitlySet = $PSBoundParameters.ContainsKey($ParameterName)
    if (-not $explicitlySet -and ([string]::IsNullOrWhiteSpace($value))) {
        Write-ColorOutput "`n=== Required Parameter: $ParameterName ===" -color "Cyan"
        Write-ColorOutput "Description: $Description" -color "Yellow"
        if ($DefaultValue -and $DefaultValue -ne "") {
            Write-ColorOutput "Default: $DefaultValue" -color "Gray"
        }
        do {
            if ($IsPassword) {
                $value = Read-Host "Enter $ParameterName" -AsSecureString
                $value = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($value))
            } else {
                $value = Read-Host "Enter $ParameterName"
            }
            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-ColorOutput "Parameter $ParameterName is required. Please enter a value." -color "Red"
            }
        } while ([string]::IsNullOrWhiteSpace($value))
        Set-Variable -Name $ParameterName -Value $value -Scope Global
    }
}

# Function to prompt for optional parameters
function Get-OptionalParameter {
    param(
        [string]$ParameterName,
        [string]$Description,
        [string]$DefaultValue = "",
        [string]$ParameterType = "string"
    )
    $value = Get-Variable -Name $ParameterName -ValueOnly -ErrorAction SilentlyContinue
    $explicitlySet = $PSBoundParameters.ContainsKey($ParameterName)
    if (-not $explicitlySet -and ([string]::IsNullOrWhiteSpace($value))) {
        Write-ColorOutput "`n=== Optional Parameter: $ParameterName ===" -color "Cyan"
        Write-ColorOutput "Description: $Description" -color "Yellow"
        Write-ColorOutput "Default: $DefaultValue" -color "Gray"
        $userInput = Read-Host "Enter $ParameterName (press Enter for default)"
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            $userInput = $DefaultValue
        }
        switch ($ParameterType) {
            "int" { $userInput = [int]$userInput }
            "bool" { 
                if ($userInput -eq "true" -or $userInput -eq "1" -or $userInput -eq "yes" -or $userInput -eq "y") {
                    $userInput = $true
                } else {
                    $userInput = $false
                }
            }
        }
        Set-Variable -Name $ParameterName -Value $userInput -Scope Global
    }
}

# Prompt for mandatory parameters if not provided
Get-MandatoryParameter -ParameterName "vroHost" -Description "The FQDN of vRO host (e.g., vro.company.com)"
Get-MandatoryParameter -ParameterName "user" -Description "Username to connect to vroHost (e.g., admin@vsphere.local)"
Get-MandatoryParameter -ParameterName "pass" -Description "Password to connect to vroHost" -IsPassword
Get-MandatoryParameter -ParameterName "exportPath" -Description "Full path of folder location for documentation output (e.g., C:\Documentation)"
Get-MandatoryParameter -ParameterName "packageName" -Description "vRO package name to document (e.g., com.vmware.library.http-rest)"

# Prompt for optional parameters
Get-OptionalParameter -ParameterName "vroPort" -Description "Port to connect to vRO host" -DefaultValue "443" -ParameterType "int"
Get-OptionalParameter -ParameterName "autoFix" -Description "Automatically attempt to fix missing prerequisites" -DefaultValue "true" -ParameterType "bool"
Get-OptionalParameter -ParameterName "skipChecks" -Description "Skip prerequisite checks (not recommended)" -DefaultValue "false" -ParameterType "bool"

# Display parameter summary
Write-ColorOutput "`n=== Parameter Summary ===" -color "Cyan"
Write-ColorOutput "vRO Host: $vroHost" -color "Green"
Write-ColorOutput "vRO Port: $vroPort" -color "Green"
Write-ColorOutput "Username: $user" -color "Green"
Write-ColorOutput "Export Path: $exportPath" -color "Green"
Write-ColorOutput "Package Name: $packageName" -color "Green"
Write-ColorOutput "Auto Fix: $autoFix" -color "Green"
Write-ColorOutput "Skip Checks: $skipChecks" -color "Green"

$confirm = Read-Host "`nDo you want to proceed with these parameters? (y/n)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-ColorOutput "Script execution cancelled by user." -color "Yellow"
    exit 0
}

Write-ColorOutput "`nProceeding with script execution..." -color "Green"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console with color using NoLog to prevent circular reference
    Write-ColorOutput $logMessage -color $Color -NoLog
    
    # Write to log file using Out-File with -Append
    try {
        $logMessage | Out-File -FilePath $script:logFile -Append -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # If writing to log file fails, just write to console with NoLog to prevent infinite loop
        Write-ColorOutput "[WARNING] Failed to write to log file: $($_.Exception.Message)" -color "Yellow" -NoLog
    }
}

# Check execution policy first
try {
    # Get execution policy for all scopes
    $processPolicy = Get-ExecutionPolicy -Scope Process -ErrorAction SilentlyContinue
    $currentUserPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    $localMachinePolicy = Get-ExecutionPolicy -Scope LocalMachine -ErrorAction SilentlyContinue
    
    Write-Log "Current execution policies - Process: $processPolicy, CurrentUser: $currentUserPolicy, LocalMachine: $localMachinePolicy" -Level "DEBUG"
    
    # Check if any policy is too restrictive
    $restrictedPolicies = @('Restricted', 'Undefined')
    $effectivePolicy = if ($processPolicy -ne 'Undefined') { $processPolicy } 
                      elseif ($currentUserPolicy -ne 'Undefined') { $currentUserPolicy }
                      else { $localMachinePolicy }
    
    if ($effectivePolicy -in $restrictedPolicies) {
        Write-ColorOutput "`n[!] PowerShell Execution Policy is set to '$effectivePolicy'" -color "Red"
        Write-ColorOutput "   This script requires a less restrictive execution policy to run." -color "Yellow"
        Write-ColorOutput "   You can run one of these commands in an elevated (Run as Administrator) PowerShell window:" -color "Yellow"
        Write-ColorOutput "   1. For current user only (recommended):" -color "Cyan"
        Write-ColorOutput "      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -color "White"
        Write-ColorOutput "   2. For all users (requires admin rights):" -color "Cyan"
        Write-ColorOutput "      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine" -color "White"
        Write-ColorOutput "`n   After setting the policy, please close and reopen your PowerShell window and try again.`n" -color "Yellow"
        
        $elevate = Read-Host "Would you like to open an elevated PowerShell window to change the execution policy? (y/n)"
        if ($elevate -eq 'y' -or $elevate -eq 'Y') {
            $command = {
                param($policy)
                try {
                    Set-ExecutionPolicy -ExecutionPolicy $policy -Scope CurrentUser -Force -ErrorAction Stop
                    Write-Host "[SUCCESS] Execution policy set to $policy for CurrentUser." -ForegroundColor Green
                }
                catch {
                    Write-Host "[ERROR] Failed to set execution policy: $($_.Exception.Message)" -ForegroundColor Red
                }
                Write-Host "You can now close this window." -ForegroundColor Cyan
                pause
            }
            
            try {
                $process = Start-Process powershell -Verb RunAs -ArgumentList "-NoExit", "-Command", "& {$command} RemoteSigned" -PassThru -ErrorAction Stop
                if ($process) {
                    Write-ColorOutput "`nPlease approve the UAC prompt and run the script again after the execution policy is updated.`n" -color "Yellow"
                }
            }
            catch {
                Write-ColorOutput "Failed to start elevated process: $($_.Exception.Message)" -color "Red"
            }
        }
        exit 1
    }
    else {
        Write-Log "Execution policy check passed. Current policy: $effectivePolicy" -Level "INFO"
    }
}
catch {
    Write-Log "Error checking execution policy: $($_.Exception.Message)" -Level "ERROR"
    Write-ColorOutput "Warning: Could not verify execution policy. The script may not run correctly." -color "Yellow"
}

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$script:prereqPassed = $true
$fileName = $packageName + ".package"
$slash = "\"
# Function to check if Node.js and npm are installed
function Test-NodeJsInstalled {
    [CmdletBinding()]
    param()
    
    try {
        $nodeVersion = (node --version 2>$null).Trim()
        $npmVersion = (npm --version 2>$null).Trim()
        
        if (-not $nodeVersion -or -not $npmVersion) {
            Write-ColorOutput "[!] Node.js and npm are required but not found." -color "Red"
            Write-ColorOutput "    Please install Node.js (includes npm) from https://nodejs.org/" -color "Yellow"
            Write-ColorOutput "    Required version: Node.js 16.0.0 or later" -color "Yellow"
            exit 1
        }
        
        # Extract version numbers (remove 'v' prefix if present)
        $nodeVersion = $nodeVersion -replace '^v', ''
        
        # Compare versions
        $currentVersion = [System.Version]::Parse($nodeVersion)
        $minVersion = [System.Version]::Parse('16.0.0')
        
        if ($currentVersion -lt $minVersion) {
            Write-ColorOutput "[!] Node.js version $nodeVersion is not supported." -color "Red"
            Write-ColorOutput "    Please upgrade to Node.js 16.0.0 or later from https://nodejs.org/" -color "Yellow"
            exit 1
        }
        
        Write-ColorOutput "[✓] Node.js $nodeVersion and npm $npmVersion detected" -color "Green"
        return $true
    }
    catch {
        Write-ColorOutput "[!] Error checking Node.js installation: $($_.Exception.Message)" -color "Red"
        Write-ColorOutput "    Please ensure Node.js and npm are properly installed" -color "Yellow"
        exit 1
    }
}

# Check if Node.js is installed and meets requirements
$nodeCheck = Test-NodeJsInstalled
if (-not $nodeCheck) {
    Write-ColorOutput "[!] Node.js check failed. Exiting script." -color "Red"
    exit 1
}

# Continue with the rest of the script
Write-Log "Node.js check completed successfully" -Level "INFO"
Write-Log "Continuing with script execution..." -Level "DEBUG"
#endregion

Write-Log "Loading helper functions..." -Level "DEBUG"
#region Helper Functions
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



function Install-JSDoc {
    Write-ColorOutput "JSDoc and required dependencies not found. Attempting to install..." -color "Yellow"
    $npmLogFile = "$logDir\npm_install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    try {
        # Install JSDoc, Minami theme, and required Babel plugins
        Write-Log "Installing JSDoc, Minami theme, and dependencies..." -Level "INFO"
        $packages = @(
            "jsdoc",
            "minami",
            "@babel/core",
            "@babel/preset-env",
            "@babel/plugin-proposal-pipeline-operator",
            "@babel/plugin-proposal-class-properties",
            "@babel/plugin-proposal-optional-chaining",
            "@babel/plugin-proposal-nullish-coalescing-operator"
        )
        
        $packageList = $packages -join " "
        Write-Log "Running: npm install -g $packageList" -Level "DEBUG"
        
        $process = Start-Process -FilePath "npm" -ArgumentList "install -g $packageList" -NoNewWindow -PassThru -RedirectStandardOutput $npmLogFile -RedirectStandardError "$npmLogFile.error" -Wait
        
        if ($process.ExitCode -ne 0) {
            $errorMsg = "Failed to install JSDoc dependencies. Check $npmLogFile for details."
            Write-Log $errorMsg -Level "ERROR"
            Write-ColorOutput $errorMsg -color "Red"
            
            # Log the last few lines of the error log
            if (Test-Path "$npmLogFile.error") {
                $lastErrors = Get-Content "$npmLogFile.error" -Tail 20 -ErrorAction SilentlyContinue
                if ($lastErrors) {
                    Write-Log "=== Last 20 lines of npm error output ===" -Level "ERROR"
                    $lastErrors | ForEach-Object { Write-Log $_ -Level "ERROR" }
                }
            }
            
            return $false
        }
        
        # Verify installation
        $jsdocVersion = jsdoc --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $jsdocVersion) {
            $successMsg = "JSDoc $jsdocVersion and dependencies installed successfully"
            Write-Log $successMsg -Level "SUCCESS"
            Write-ColorOutput $successMsg -color "Green"
            
            # Verify Minami theme is installed
            $minamiPath = npm root -g
            $minamiPath = Join-Path $minamiPath "minami"
            if (Test-Path $minamiPath) {
                Write-Log "Minami theme installed successfully at $minamiPath" -Level "INFO"
            } else {
                Write-Log "Warning: Minami theme installation may have failed. Path not found: $minamiPath" -Level "WARNING"
            }
            
            return $true
        } else {
            $errorMsg = "JSDoc installation verification failed. Check $npmLogFile for details."
            Write-Log $errorMsg -Level "ERROR"
            Write-ColorOutput $errorMsg -color "Red"
            return $false
        }
    }
    catch {
        $errorMsg = "Error during JSDoc installation: $($_.Exception.Message)"
        Write-Log $errorMsg -Level "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "DEBUG"
        Write-ColorOutput $errorMsg -color "Red"
        return $false
    }
}

function Test-PowerShellVersion {
    $minVersion = 5.1
    $currentVersion = $PSVersionTable.PSVersion
    
    if ($currentVersion -ge $minVersion) {
        Write-ColorOutput "[✓] PowerShell $currentVersion detected" -color "Green"
        return $true
    }
    
    Write-ColorOutput "[!] PowerShell version $currentVersion detected" -color "Red"
    Write-ColorOutput "    This script requires PowerShell $minVersion or later" -color "Yellow"
    Write-ColorOutput "    Please update PowerShell from: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell" -color "Yellow"
    Write-ColorOutput "    Or install Windows Management Framework 5.1 for older Windows versions" -color "Yellow"
    exit 1
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
    Write-ColorOutput "`n=== Checking Other Prerequisites ===" -color "Cyan"
    
    $allPassed = $true
    
    try {
        # Check PowerShell version
        if (-not (Test-PowerShellVersion)) {
            $allPassed = $false
            Write-ColorOutput "[X] PowerShell version too old" -color "Red"
        }
        else {
            Write-ColorOutput "[✓] PowerShell version OK" -color "Green"
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
    catch {
        Write-Log "Error in prerequisite checks: $($_.Exception.Message)" -Level "ERROR" -Color "Red"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR" -Color "DarkYellow"
        return $false
    }
}

# Function to convert string to Base64 encoding
function ConvertTo-Base64($string) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($string)
    $encoded = [System.Convert]::ToBase64String($bytes)
    return $encoded
}

# Function to get vRA token with simplified SSL handling
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
#endregion

#region Main Script Execution

# Save the original working directory
$originalDirectory = Get-Location

try {
    # Log script start
    Write-Log "vRODoc - Automated vRO Documentation Generator" -Color "Magenta" -Level "INFO"
    Write-Log "Original working directory: $originalDirectory" -Level "DEBUG"
    Write-Log "Version 2.2.0 (Enhanced with Logging)" -Color "Cyan" -Level "INFO"
    Write-Log "Log file: $script:logFile" -Level "INFO"
    Write-Log "Script started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
    Write-Log "Command line: $($MyInvocation.Line)" -Level "DEBUG"
    Write-ColorOutput "Version 2.2.0 (Enhanced with Prerequisite Checks)`n" -color "Cyan"
    
    # Check for Node.js first - this will exit if not found
    Write-ColorOutput "=== Checking Prerequisites ===" -color "Cyan"
    $nodeCheck = Test-NodeJsInstalled
    if (-not $nodeCheck) {
        Write-ColorOutput "[X] Node.js check failed. Exiting script." -color "Red"
        exit 1
    }
    
    # If we get here, Node.js check passed
    Write-ColorOutput "[✓] Node.js check passed" -color "Green"
    
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
    $queryParams = @{
        exportConfigurationAttributeValues = 'true'
        exportGlobalTags = 'true'
        exportVersionHistory = 'true'
        exportConfigSecureStringAttributeValues = 'false'
        allowedOperations = 'vef'
        exportExtensionData = 'false'
    }
    $queryString = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&'
    $expPackageURI = "https://$($vroHost):$($vroPort)/vco/api/packages/$([System.Web.HttpUtility]::UrlEncode($packageName))?$queryString"
    
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
$($actionScript -replace "(?m)^", "")
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

    # Generate JSDoc documentation with Minami theme
    Write-ColorOutput "`nGenerating HTML documentation with JSDoc and Minami theme..." -color "Yellow"
    $configPath = Join-Path $PSScriptRoot "jsdoc.config.json"
    $jsdocLogFile = "$logDir\jsdoc_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    Write-Log "Starting JSDoc generation with Minami theme and config: $configPath" -Level "INFO"
    Write-Log "Source directory: $savePath" -Level "INFO"
    Write-Log "Output directory: $savePath\docs" -Level "INFO"
    
    # Create a README.md if it doesn't exist
    $readmePath = Join-Path $savePath "README.md"
    if (-not (Test-Path $readmePath)) {
        @"
# $packageName Documentation

This documentation was automatically generated from the vRO package: **$packageName**

## Overview

Documentation for all actions and workflows in the $packageName package.

## Search

Use the search box in the top-right corner to quickly find documentation.

## Navigation

- **Classes**: Documentation for all action classes
- **Modules**: Grouped by action categories
- **Tutorials**: Additional documentation and guides

## Generating Documentation

This documentation can be regenerated using the vRODoc PowerShell script.

## Last Generated

$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@ | Out-File -FilePath $readmePath -Encoding utf8
        
        Write-Log "Created README.md at $readmePath" -Level "INFO"
    }
    
    # Ensure node_modules exists and install dependencies if needed
    $nodeModulesPath = Join-Path $PSScriptRoot "node_modules"
    if (-not (Test-Path $nodeModulesPath)) {
        Write-ColorOutput "Preparing to install required npm packages..." -color "Cyan"

        # Improved npm path detection
        if ($null -eq $npmPath -or $npmPath -eq "") {
            $npmPath = (Get-Command npm -ErrorAction SilentlyContinue).Source
            if (-not $npmPath) {
                $possibleNpmPaths = @(
                    "$env:ProgramFiles\nodejs\npm.cmd",
                    "$env:ProgramFiles\nodejs\npm.ps1",
                    "$env:USERPROFILE\AppData\Roaming\npm\npm.cmd"
                )
                $npmPath = $possibleNpmPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
            }
        }
        Write-ColorOutput "DEBUG: Detected npm path: $npmPath" -color "Yellow"
        if (-not $npmPath -or -not (Test-Path $npmPath)) {
            Write-ColorOutput "npm was not found automatically. Please enter the full path to npm (e.g., C:\\Program Files\\nodejs\\npm.cmd):" -color "Red"
            $npmPath = Read-Host "Enter npm path"
            if (-not (Test-Path $npmPath)) {
                Write-ColorOutput "ERROR: npm not found at the specified path. Please ensure Node.js and npm are installed and try again." -color "Red"
                exit 1
            }
        }
        Write-ColorOutput "Using npm at: $npmPath" -color "Green"

        # Ensure package.json exists in the script directory
        $packageJsonPath = Join-Path $PSScriptRoot "package.json"
        if (-not (Test-Path $packageJsonPath)) {
            Write-ColorOutput "Creating package.json in script directory..." -color "Yellow"
            @{
                name = "vrodoc-temp"
                version = "1.0.0"
                description = "Temporary package for vRODoc dependencies"
                private = $true
                dependencies = @{
                    "jsdoc" = "^4.0.2"
                    "minami" = "^1.2.3"
                    "@babel/core" = "^7.22.10"
                    "@babel/preset-env" = "^7.22.10"
                    "@babel/plugin-proposal-pipeline-operator" = "^7.18.10"
                    "@babel/plugin-proposal-class-properties" = "^7.18.6"
                    "@babel/plugin-proposal-private-methods" = "^7.18.6"
                    "taffydb" = "^2.7.3"
                }
            } | ConvertTo-Json -Depth 10 | Out-File -FilePath $packageJsonPath -Encoding utf8 -Force
        }
        
        # Ensure jsdoc.config.json exists in the script directory
        $jsdocConfigPath = Join-Path $PSScriptRoot "jsdoc.config.json"
        if (-not (Test-Path $jsdocConfigPath)) {
            Write-ColorOutput "Creating jsdoc.config.json in script directory..." -color "Yellow"
            @{
                tags = @{
                    allowUnknownTags = @("date")
                    dictionaries = @("jsdoc", "closure")
                }
                plugins = @("plugins/markdown")
                markdown = @{
                    excludeTags = @("example")
                    hardwrap = $true
                    idInHeadings = $true
                }
                sourceType = "script"
                ecmaVersion = 5
                commonjs = $true
                source = @{
                    includePattern = ".+\\.js(doc|x)?$"
                    excludePattern = "(^|\\/|\\\\)_|node_modules"
                }
                templates = @{
                    cleverLinks = $false
                    monospaceLinks = $false
                    default = @{
                        outputSourceFiles = $true
                        includeDate = $false
                        useLongnameInNav = $true
                    }
                    systemName = "vRO Documentation"
                    footer = ""
                    copyright = "vRO Documentation"
                    navType = "vertical"
                    theme = "minami"
                    linenums = $true
                    collapseSymbols = $false
                    inverseNav = $true
                    outputSourcePath = $true
                    dateFormat = "ddd MMM Do YYYY"
                    syntaxTheme = "default"
                    search = $true
                }
                opts = @{
                    encoding = "utf8"
                    private = $false
                    recurse = $true
                    template = "./node_modules/minami"
                    destination = "./docs/"
                    readme = "./README.md"
                }
                minami = @{
                    static = $true
                    searchConfig = @{
                        highlightTerms = $true
                        fuzzy = $true
                        minLength = 3
                        maxResults = 10
                    }
                    meta = @{
                        title = "vRO Documentation"
                        description = "Automatically generated documentation for vRO JavaScript actions"
                        keyword = "vRO, VCF, Aria, Orchestrator, Documentation, VCF Operations Orchestrator"
                    }
                    nav = @(
                        @{
                            title = "Home"
                            url = "index.html"
                        },
                        @{
                            title = "Tutorials"
                            url = "tutorials.html"
                        }
                    )
                    stylesheets = @("./css/custom.css")
                    scripts = @("./js/custom.js")
                }
                babel = @{
                    babelrc = $false
                    configFile = "./babel.config.json"
                }
            } | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsdocConfigPath -Encoding utf8 -Force
        }
        
        # Ensure babel.config.json exists in the script directory
        $babelConfigPath = Join-Path $PSScriptRoot "babel.config.json"
        if (-not (Test-Path $babelConfigPath)) {
            Write-ColorOutput "Creating babel.config.json in script directory..." -color "Yellow"
            @{
                presets = @(
                    @(
                        "@babel/preset-env",
                        @{
                            targets = @{
                                esmodules = $false
                                rhino = "1.7.4"
                            }
                            modules = "commonjs"
                            useBuiltIns = $false
                            shippedProposals = $false
                            forceAllTransforms = $true
                            loose = $true
                        }
                    )
                )
                plugins = @(
                    @(
                        "@babel/plugin-proposal-pipeline-operator",
                        @{ proposal = "hack"; topicToken = "#" }
                    ),
                    "@babel/plugin-transform-parameters",
                    "@babel/plugin-transform-shorthand-properties",
                    "@babel/plugin-transform-member-expression-literals",
                    "@babel/plugin-transform-property-literals",
                    @(
                        "@babel/plugin-proposal-class-properties",
                        @{ loose = $true }
                    ),
                    @(
                        "@babel/plugin-proposal-private-methods",
                        @{ loose = $true }
                    )
                )
                parserOpts = @{
                    allowReturnOutsideFunction = $true
                    allowSuperOutsideMethod = $true
                    allowUndeclaredExports = $true
                    errorRecovery = $true
                }
                generatorOpts = @{
                    compact = $false
                    minified = $false
                    comments = $true
                }
                sourceMaps = $false
            } | ConvertTo-Json -Depth 10 | Out-File -FilePath $babelConfigPath -Encoding utf8 -Force
        }
        
        # Change to script directory for npm install
        $originalWorkingDir = Get-Location
        Set-Location -Path $PSScriptRoot
        
        try {
            Write-ColorOutput "Installing npm packages in: $PSScriptRoot" -color "Cyan"
            
            # Try different installation methods
            $success = $false
            $attempts = @(
                { & $npmPath install --no-fund --no-audit --no-progress --prefer-offline },
                { & cmd.exe /c "`"$npmPath`" install --no-fund --no-audit --no-progress --prefer-offline" },
                { Start-Process -FilePath $npmPath -ArgumentList "install --no-fund --no-audit --no-progress --prefer-offline" -NoNewWindow -Wait -WorkingDirectory $PSScriptRoot -PassThru }
            )
            
            foreach ($attempt in $attempts) {
                try {
                    Write-ColorOutput "Attempting to install packages using: $($attempt.ToString())" -color "Cyan"
                    $process = Invoke-Command $attempt
                    
                    if (($process -and $process.ExitCode -eq 0) -or $?) {
                        $success = $true
                        break
                    }
                }
                catch {
                    Write-ColorOutput "Attempt failed: $($_.Exception.Message)" -color "Yellow"
                }
            }
            
            if (-not $success) {
                $manualCmds = @"

[!] Automatic package installation failed. Please run these commands manually:

1. Open PowerShell as Administrator
2. Run these commands:

Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
cd "$PSScriptRoot"
npm install --no-fund --no-audit --no-progress --prefer-offline

If you still encounter issues, try:
1. Delete the 'node_modules' folder (if exists)
2. Delete 'package-lock.json' (if exists)
3. Run the commands above again
"@
                Write-ColorOutput $manualCmds -color "Red"
                exit 1
            }
            
            # Verify installation
            if (-not (Test-Path $nodeModulesPath)) {
                throw "Package installation failed. 'node_modules' directory not found after installation."
            }
            
            Write-ColorOutput "npm packages installed successfully in: $PSScriptRoot" -color "Green"
        }
        finally {
            # Restore original working directory
            Set-Location -Path $originalWorkingDir
        }
    }
    
    # Use local node_modules JSDoc
    $jsdocPath = Join-Path $PSScriptRoot "node_modules\.bin\jsdoc.cmd"
    if (-not (Test-Path $jsdocPath)) {
        throw "JSDoc not found. Please ensure npm packages are installed correctly in $PSScriptRoot"
    }
    
    # Ensure config path is in script directory
    $configPath = Join-Path $PSScriptRoot "jsdoc.config.json"
    if (-not (Test-Path $configPath)) {
        throw "JSDoc config not found at: $configPath"
    }
    
    # Create a temporary directory for JSDoc output
    $tempJsdocDir = Join-Path $env:TEMP "vrodoc-jsdoc-$(Get-Date -Format 'yyyyMMddHHmmss')"
    New-Item -ItemType Directory -Path $tempJsdocDir -Force | Out-Null
    
    # Change to script directory for JSDoc execution
    $originalWorkingDir = Get-Location
    Set-Location -Path $PSScriptRoot
    
    try {
        Write-ColorOutput "Executing JSDoc from: $PSScriptRoot" -color "Cyan"
        Write-ColorOutput "Source directory: $savePath" -color "Cyan"
        Write-ColorOutput "Output directory: $savePath\docs" -color "Cyan"
        $jsdocCommand = "-c `"$configPath`" -r `"$savePath`" -d `"$savePath\docs`" --verbose"
        Write-Log "Executing: $jsdocPath $jsdocCommand" -Level "DEBUG"
        $process = Start-Process -FilePath $jsdocPath -ArgumentList $jsdocCommand -NoNewWindow -PassThru -WorkingDirectory $PSScriptRoot -Wait
        $docsPath = Join-Path $savePath "docs"
        $docFiles = @()
        if (Test-Path $docsPath) {
            $docFiles = Get-ChildItem -Path $docsPath -Recurse -File -ErrorAction SilentlyContinue
        }
        if ($process.ExitCode -eq 0) {
            $successMsg = "[SUCCESS] JSDoc documentation generated successfully in $savePath\docs"
            Write-Log $successMsg -Level "SUCCESS"
            Write-ColorOutput $successMsg -color "Green"
            Write-Log "Generated $($docFiles.Count) documentation files" -Level "INFO"
        } else {
            $warningMsg = "[WARNING] JSDoc completed with errors. Some files could not be parsed."
            Write-Log $warningMsg -Level "WARNING"
            Write-ColorOutput $warningMsg -color "Yellow"
            Write-ColorOutput "Please check the error log for details. Your documentation may be partially generated." -color "Yellow"
            if ($docFiles.Count -gt 0) {
                Write-ColorOutput "[INFO] Some documentation was generated at: $docsPath" -color "Green"
            } else {
                Write-ColorOutput "[ERROR] No documentation was generated." -color "Red"
            }
        }
    }
    catch {
        $errorMsg = "[ERROR] Exception during JSDoc generation: $($_.Exception.Message)"
        Write-Log $errorMsg -Level "ERROR"
        Write-ColorOutput $errorMsg -color "Red"
    }
    finally {
        # Restore original working directory
        Set-Location -Path $originalWorkingDir
    }
    $docsPath = Join-Path $savePath "docs"
    if (Test-CommandExists "jsdoc" -and (Test-Path $docsPath)) {
        Write-ColorOutput "Documentation generated at: $docsPath" -color "Green"
        Write-ColorOutput "Open index.html in your browser to view the documentation" -color "Green"
    } else {
        Write-ColorOutput "JSDoc not available or documentation directory missing. HTML documentation generation skipped." -color "Red"
    }
    Write-ColorOutput "\n=== vRO Documentation Generation Complete ===" -color "Cyan"
    Write-ColorOutput "[INFO] Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -color "Cyan"
    if (Test-Path $docsPath -and (Get-ChildItem -Path $docsPath -Recurse -File -ErrorAction SilentlyContinue).Count -gt 0) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    $errorMessage = "ERROR: $($_.Exception.Message)"
    $stackTrace = $_.ScriptStackTrace
    Write-Log "`n[!] $errorMessage" -Level "ERROR" -Color "Red"
    Write-Log "Stack Trace: $stackTrace" -Level "ERROR" -Color "DarkYellow"
    Write-Log "Script execution failed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "ERROR" -Color "Red"
    exit 1
}
finally {
    try {
        # Log script completion and stop transcript
        Write-Log "Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
        Write-Log "Log file: $script:logFile" -Level "INFO"
        
        # Restore original directory
        Set-Location -Path $originalDirectory
        Write-Log "Restored working directory to: $originalDirectory" -Level "DEBUG"
        
        # Stop transcript if it's running
        try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null }
        catch { }
    }
    catch {
        # If there's an error in the finally block, just write to host
        Write-Host "Error during script cleanup: $($_.Exception.Message)" -ForegroundColor Red
    }
}
#endregion