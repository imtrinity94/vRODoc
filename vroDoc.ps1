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
    [string]$vroHost = "vro.domain",
    [ValidateScript({
        if ($_ -notmatch '^\d+$' -or [int]$_ -le 0 -or [int]$_ -gt 65535) {
            throw "Port must be a valid port number between 1 and 65535"
        }
        return $true
    })]
    [string]$vroPort = "443",
    [string]$user = "user@domain",
    [string]$pass = "pa$$word",
    [string]$exportPath = "C:\Users\user\",
    [Parameter(Mandatory = $true)]
    [string]$packageName = 'important.actions',
    [bool]$autoFix = $true,
    [bool]$skipChecks = $false
)

#region Initialization

# Function to write colored output to console and log file
function Write-ColorOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow', 'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White')]
        [string]$Color = 'White',
        
        [Parameter(Mandatory=$false)]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory=$false)]
        [switch]$NoLog
    )
    
    # Write to console with color
    $colorMap = @{
        'Black' = 'Black'
        'DarkBlue' = 'DarkBlue'
        'DarkGreen' = 'DarkGreen'
        'DarkCyan' = 'DarkCyan'
        'DarkRed' = 'DarkRed'
        'DarkMagenta' = 'DarkMagenta'
        'DarkYellow' = 'DarkYellow'
        'Gray' = 'Gray'
        'DarkGray' = 'DarkGray'
        'Blue' = 'Blue'
        'Green' = 'Green'
        'Cyan' = 'Cyan'
        'Red' = 'Red'
        'Magenta' = 'Magenta'
        'Yellow' = 'Yellow'
        'White' = 'White'
    }
    
    $hostColor = $colorMap[$Color]
    if (-not $hostColor) { $hostColor = 'White' }
    
    Write-Host $Message -ForegroundColor $hostColor
    
    # Only write to log if not called from Write-Log
    if (-not $NoLog) {
        # Remove ANSI color codes for log
        $logMessage = $Message -replace "`e\[[0-9;]*m"
        
        # Map colors to log levels if not specified
        if ($Level -eq "INFO") {
            switch ($Color) {
                "Green" { $Level = "SUCCESS" }
                "Red" { $Level = "ERROR" }
                "Yellow" { $Level = "WARNING" }
                "Cyan" { $Level = "INFO" }
                "Magenta" { $Level = "INFO" }
            }
        }
        
        # Write to log file directly to avoid circular reference
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $logMessage"
        
        try {
            $logMessage | Out-File -FilePath $script:logFile -Append -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            # If writing to log file fails, just write to console with NoLog to prevent infinite loop
            Write-Host "[WARNING] Failed to write to log file: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Initialize logging
$logDir = Join-Path -Path $PSScriptRoot -ChildPath "Logs"
$script:logFile = Join-Path -Path $logDir -ChildPath "vRODoc_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Create Logs directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Create or clear the log file
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] Logging started" | Out-File -FilePath $logFile -Force -Encoding UTF8

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
        Write-ColorOutput -Message "[!] PowerShell Execution Policy is set to '$effectivePolicy'" -Color "Red"
        Write-ColorOutput -Message "   This script requires a less restrictive execution policy to run." -Color "Yellow"
        Write-ColorOutput -Message "   You can run one of these commands in an elevated (Run as Administrator) PowerShell window:" -Color "Yellow"
        Write-ColorOutput -Message "   1. For current user only (recommended):" -Color "Cyan"
        Write-ColorOutput -Message "      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -Color "White"
        Write-ColorOutput -Message "   2. For all users (requires admin rights):" -Color "Cyan"
        Write-ColorOutput -Message "      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine" -Color "White"
        Write-ColorOutput -Message "`n   After setting the policy, please close and reopen your PowerShell window and try again.`n" -Color "Yellow"
        
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
# Function to get the latest Node.js LTS version download URL
function Get-NodeJsDownloadUrl {
    try {
        Write-Log "Fetching latest Node.js LTS version information..." -Level "INFO"
        $releases = Invoke-RestMethod -Uri "https://nodejs.org/dist/index.json" -UseBasicParsing -ErrorAction Stop
        
        # Get the latest LTS version
        $ltsRelease = $releases | Where-Object { $_.lts -ne $false } | Select-Object -First 1
        
        if ($null -eq $ltsRelease) {
            throw "No LTS version found"
        }
        
        $version = $ltsRelease.version
        $versionNumber = $version.TrimStart('v')
        $architecture = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
        
        $downloadUrl = "https://nodejs.org/dist/$version/node-$versionNumber-$architecture.msi"
        
        Write-Log "Latest LTS version: $version" -Level "INFO"
        Write-Log "Download URL: $downloadUrl" -Level "DEBUG"
        
        return $downloadUrl
    }
    catch {
        $errorMsg = "Failed to fetch Node.js version information: $($_.Exception.Message)"
        Write-Log $errorMsg -Level "ERROR"
        Write-Log "Falling back to default download URL" -Level "WARNING"
        
        # Fallback URL if version detection fails
        $fallbackVersion = "24.4.1"
        $architecture = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
        return "https://nodejs.org/dist/v$fallbackVersion/node-v$fallbackVersion-$architecture.msi"
    }
}

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

# Function to verify Node.js and npm installation
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
        Write-ColorOutput -Message "[!] Error checking Node.js installation: $($_.Exception.Message)" -Color "Red"
        return $false
    }
}

function Install-JSDoc {
    Write-ColorOutput -Message "JSDoc and required dependencies not found. Attempting to install..." -Color "Yellow"
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
            Write-ColorOutput -Message $errorMsg -Color "Red"
            
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
            Write-ColorOutput -Message $errorMsg -Color "Red"
            return $false
        }
    }
    catch {
        $errorMsg = "Error during JSDoc installation: $($_.Exception.Message)"
        Write-Log $errorMsg -Level "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "DEBUG"
        Write-ColorOutput -Message $errorMsg -Color "Red"
        return $false
    }
}

function Test-PowerShellVersion {
    $minVersion = 5.1
    $currentVersion = $PSVersionTable.PSVersion
    
    if ($currentVersion -ge $minVersion) {
        Write-ColorOutput -Message "[✓] PowerShell $currentVersion detected" -Color "Green"
        return $true
    }
    
    Write-ColorOutput -Message "[!] PowerShell version $currentVersion detected" -Color "Red"
    Write-ColorOutput -Message "    This script requires PowerShell $minVersion or later" -Color "Yellow"
    Write-ColorOutput -Message "    Please update PowerShell from: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell" -Color "Yellow"
    Write-ColorOutput -Message "    Or install Windows Management Framework 5.1 for older Windows versions" -Color "Yellow"
    return $false
}

function Main {
    try {
        # Main script logic here
        $docsPath = Join-Path $savePath "docs"
        
        if (Test-CommandExists "jsdoc") {
            Write-ColorOutput -Message "Documentation generated at: $docsPath" -Color "Green"
            Write-ColorOutput -Message "Open index.html in your browser to view the documentation" -Color "Green"
        }
        else {
            Write-ColorOutput -Message "JSDoc not available. HTML documentation generation skipped." -Color "Red"
        }
        
        Write-ColorOutput -Message "`n=== vRO Documentation Generation Complete ===" -Color "Cyan"
        return 0
    }
    catch {
        $errorMessage = "ERROR: $($_.Exception.Message)"
        $stackTrace = $_.ScriptStackTrace
        Write-Log -Message "`n[!] $errorMessage" -Level "ERROR" -Color "Red"
        Write-Log -Message "Stack Trace: $stackTrace" -Level "ERROR" -Color "DarkYellow"
        Write-Log -Message "Script execution failed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "ERROR" -Color "Red"
        return 1
    }
    finally {
        try {
            # Log script completion and stop transcript
            Write-Log -Message "Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
            Write-Log -Message "Log file: $logFile" -Level "INFO"
            
            # Restore original directory
            Set-Location -Path $originalDirectory
            Write-Log -Message "Restored working directory to: $originalDirectory" -Level "DEBUG"
            
            # Stop transcript if it's running
            try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null }
            catch { }
        }
        catch {
            # If there's an error in the finally block, just write to host
            Write-Host "Error during script cleanup: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Call the Main function and exit with the appropriate status code
exit (Main)
#endregion