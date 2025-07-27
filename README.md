# vRODoc - Aria Automation Orchestrator Documentation Generator

## Overview
vRODoc is a PowerShell-based tool (Version 3.0) that automatically generates comprehensive JSDoc documentation from VMware Aria Automation Orchestrator (formerly vRealize Orchestrator or vRO) packages which contains JavaScript actions. It simplifies the process of documenting actions by creating a searchable HTML documentation site with enhanced interactive features and self-contained deployment capabilities.

## Features
- **Automated Documentation**: Generates JSDoc documentation directly from Aria Automation Orchestrator actions inside a package.
- **Prerequisite Auto-Fix**: Automatically checks for and attempts to fix missing prerequisites like Node.js and npm.
- **Interactive HTML Output**: Creates a searchable and navigable HTML documentation site.
- **Self-Contained Deployment**: All generated documentation and necessary assets are bundled for easy sharing.
- **Enhanced Error Handling**: Provides clear error messages and logging for troubleshooting.
- **Customizable**: Uses JSDoc and Babel configurations for flexible documentation generation.

## Prerequisites
To run vRODoc, ensure your system meets the following requirements:
- Windows OS (tested on Windows 10/11 and Windows Server 2016/2019/2022)
- PowerShell 5.1 or higher
- Node.js 16.x or higher
- Write access to script directory
- Network access to Aria Automation Orchestrator server (port 443 by default)
- Aria Automation Orchestrator 8.x or higher

## Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/your-repo/vRODoc.git
cd vRODoc
```

### 2. Run the Script
Open PowerShell and navigate to the `vRODoc` directory. Execute the script:

```powershell
.\vroDoc.ps1
```

The script will guide you through the necessary parameters. Alternatively, you can provide parameters directly:

```powershell
.\vroDoc.ps1 -vroHost "aao.company.com" `
            -vroPort "443" `
            -user "admin@vsphere.local" `
            -pass "YourPassword" `
            -exportPath "C:\Documentation" `
            -packageName "com.vmware.library.http-rest" `
            -autoFix $true `
            -skipChecks $false
```

### Parameters

#### Mandatory Parameters
| Parameter    | Description                                      | Example                    |
|--------------|--------------------------------------------------|----------------------------|
| `vroHost`    | FQDN for Aria Automation Orchestrator           | `aao.company.com`          |
| `user`       | Username for Aria Automation Orchestrator authentication | `admin@vsphere.local`      |
| `pass`       | Password for Aria Automation Orchestrator authentication | (prompted securely)        |
| `exportPath` | Output directory for documentation               | `C:\Documentation`        |
| `packageName`| Aria Automation Orchestrator package name to document | `com.vmware.utilities`     |

#### Optional Parameters
| Parameter    | Description                                      | Default        |
|--------------|--------------------------------------------------|----------------|
| `vroPort`    | Aria Automation Orchestrator port (443 for 8.x) | `443`          |
| `autoFix`    | Automatically fix missing prerequisites          | `true`         |
| `skipChecks` | Skip prerequisite checks (not recommended)       | `false`        |

## How it Works
vRODoc automates the documentation process through the following steps:

1.  **Parameter Collection**: Script prompts for all required parameters or accepts them via command line.
2.  **Prerequisite Validation**: Checks and installs missing dependencies like Node.js and JSDoc.
3.  **Authentication**: Securely connects to Aria Automation Orchestrator server.
4.  **Package Export**: Downloads and extracts the specified Aria Automation Orchestrator package.
5.  **Content Processing**: Converts Aria Automation Orchestrator actions (JavaScript) to a JSDoc-compatible format.
6.  **Documentation Generation**: Uses JSDoc to create a searchable HTML documentation site.
7.  **Output Organization**: Structures the generated documentation for easy navigation.
8.  **Cleanup**: Restores the environment and logs completion.

### Error Handling
-   **Prerequisite Checks**: Validates all dependencies before execution.
-   **Network Connectivity**: Tests connection to Aria Automation Orchestrator server.
-   **Authentication Errors**: Provides clear error messages for authentication issues.
-   **Package Processing**: Handles malformed Aria Automation Orchestrator packages gracefully.
-   **Logging**: Comprehensive logging for troubleshooting.

## Project Structure
```
vRODoc/
├── .github/                  # GitHub Actions workflows
│   └── workflows/
│       └── static.yml        # Workflow for static analysis
├── LICENSE                   # Project license
├── README.md                 # This README file
├── babel.config.json         # Babel configuration for JSDoc
├── jsdoc.config.json         # JSDoc configuration
├── package.json              # Node.js project metadata and dependencies
├── structure.md              # Detailed script structure analysis
└── vroDoc.ps1                # Main PowerShell script
```

## Troubleshooting
-   **`ParserError`**: Ensure your PowerShell execution policy allows script execution. Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` in an elevated PowerShell.
-   **Node.js/npm issues**: The script attempts to auto-fix. If issues persist, manually install Node.js from [nodejs.org](https://nodejs.org/).
-   **Connectivity issues**: Verify `vroHost` and `vroPort` are correct and that your machine can reach the Aria Automation Orchestrator server.
-   **Log Files**: Check the `Logs/vRODoc_YYYYMMDD_HHMMSS.log` file for detailed error messages.

## Contributing
Contributions are welcome! Please feel free to submit issues or pull requests.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Version**: 3.0
**Last Updated**: July 2025
Made with ❤️ for the Aria Automation Orchestrator community