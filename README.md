# vRODoc - vRO Action Documentation Generator

## Overview
vRODoc is a PowerShell-based tool that automatically generates comprehensive JSDoc documentation from VMware vRealize Orchestrator (vRO) packages. It simplifies the process of documenting vRO actions by creating a searchable HTML documentation site with enhanced interactive features and self-contained deployment capabilities.

## Features
- 🚀 **Interactive Parameter Prompting** - User-friendly prompts for all required parameters
- 🔐 **Secure Authentication** - vRA token-based authentication with password masking
- 📦 **Self-Contained Deployment** - Automatically creates all required configuration files
- 📄 **JSDoc Documentation** - Professional HTML output with Minami theme
- 🌐 **Searchable Interface** - Full-text search and navigation
- ⚡ **Prerequisite Management** - Automatic dependency checking and installation
- 🛡️ **Error Recovery** - Comprehensive error handling and logging
- 🔧 **Remote Deployment Ready** - Works on any Windows system with minimal setup

## Prerequisites
- PowerShell 5.1 or higher
- Node.js 16.x or higher
- Write access to script directory
- Network access to vRO server (port 443 by default)
- vRO 8.x or higher
- Windows OS (tested on Windows 10/11 and Windows Server 2016/2019/2022)

> The script automatically installs missing prerequisites and creates required configuration files.

## Usage

### Interactive Mode (Recommended)
```powershell
.\vroDoc.ps1
```
The script will prompt you for all required parameters with helpful descriptions and examples.

### Command Line Mode
```powershell
.\vroDoc.ps1 -vroHost "vro.company.com" `
             -vroPort "443" `
             -user "admin@vsphere.local" `
             -pass "yourpassword" `
             -exportPath "C:\Documentation" `
             -packageName "com.vmware.library.http-rest" `
             -autoFix $true `
             -skipChecks $false
```

### Parameters

#### Required Parameters
| Parameter    | Description                                      | Example                    |
|-------------|--------------------------------------------------|----------------------------|
| vroHost     | vRA FQDN for embedded vRO                       | vro.company.com           |
| user        | Username for vRA authentication                  | admin@vsphere.local       |
| pass        | Password for vRA authentication                  | (prompted securely)       |
| exportPath  | Output directory for documentation               | C:\Documentation          |
| packageName | vRO package name to document                    | com.vmware.utilities      |

#### Optional Parameters
| Parameter    | Description                                      | Default        |
|-------------|--------------------------------------------------|----------------|
| vroPort     | vRO port (443 for 8.x)                          | 443            |
| autoFix     | Automatically fix missing prerequisites          | true           |
| skipChecks  | Skip prerequisite checks (not recommended)       | false          |

## Interactive Features

### Parameter Prompting
The script now provides an interactive experience:
- **Clear Descriptions**: Each parameter includes helpful descriptions and examples
- **Secure Password Input**: Password is masked during input
- **Validation**: Ensures all required parameters are provided
- **Confirmation**: Shows parameter summary before execution
- **Default Values**: Offers sensible defaults for optional parameters

### Self-Contained Deployment
- **Automatic Configuration**: Creates `package.json`, `jsdoc.config.json`, and `babel.config.json`
- **Local Dependencies**: Installs npm packages in script directory
- **No Manual Setup**: Works on any remote system with minimal prerequisites
- **Error Recovery**: Comprehensive error handling and logging

## Output Structure
```
exportPath/
└── vRODoc Files/
    ├── [Package_Name]/
        ├── Actions/
        │   └── [Category]/
        │        └── action.js
        ├── docs/
        │   └── index.html (main documentation site)
        └── README.md
```

## Installation & Deployment

### Local Installation
1. Download the script and configuration files
2. Ensure Node.js 16+ is installed
3. Run the script interactively or with parameters

### Remote Deployment
1. Copy the script to target system
2. Ensure PowerShell 5.1+ and Node.js 16+ are available
3. Run the script - it will handle all dependencies automatically

### Package Contents
- `vroDoc.ps1` - Main script with interactive features
- `package.json` - npm dependencies (auto-created if missing)
- `jsdoc.config.json` - JSDoc configuration (auto-created if missing)
- `babel.config.json` - Babel transpilation settings (auto-created if missing)
- `README.md` - This documentation

## Demo

### Interactive Parameter Entry
![Interactive prompts for all required parameters](https://github.com/user-attachments/assets/3586588e-271e-42bd-a71d-c29329a06b32)

### Generated Documentation
![Searchable HTML documentation with Minami theme](https://github.com/user-attachments/assets/b901bc0d-e5a3-4e65-8499-bbd1f98012d4)

## Workflow

### Step-by-Step Process
1. **Parameter Collection**: Script prompts for all required parameters
2. **Prerequisite Validation**: Checks and installs missing dependencies
3. **Authentication**: Securely connects to vRO/vRA server
4. **Package Export**: Downloads and extracts vRO package
5. **Content Processing**: Converts vRO actions to JSDoc format
6. **Documentation Generation**: Creates searchable HTML documentation
7. **Output Organization**: Structures documentation for easy navigation

### Error Handling
- **Prerequisite Checks**: Validates all dependencies before execution
- **Network Connectivity**: Tests connection to vRO server
- **Authentication Errors**: Provides clear error messages for auth issues
- **Package Processing**: Handles malformed vRO packages gracefully
- **Logging**: Comprehensive logging for troubleshooting

## Features

### Enhanced User Experience
- **Interactive Prompts**: User-friendly parameter collection
- **Progress Indicators**: Clear feedback during long operations
- **Color-Coded Output**: Easy-to-read console messages
- **Parameter Summary**: Confirmation before execution
- **Secure Input**: Password masking for security

### Self-Healing Capabilities
- **Automatic Dependency Installation**: Installs missing npm packages
- **Configuration File Creation**: Generates required config files
- **Execution Policy Handling**: Guides users through policy changes
- **Network Connectivity Testing**: Validates server connectivity
- **Error Recovery**: Attempts to fix common issues automatically

### Documentation Quality
- **Professional Output**: Beautiful HTML documentation with Minami theme
- **Search Functionality**: Full-text search across all documentation
- **Navigation**: Easy-to-use navigation and breadcrumbs
- **Code Highlighting**: Syntax highlighting for JavaScript code
- **Responsive Design**: Works on desktop and mobile devices

## Troubleshooting

### Common Issues
1. **PowerShell Execution Policy**: Script guides users through policy changes
2. **Node.js Missing**: Provides download link and installation instructions
3. **Network Connectivity**: Tests and reports connection issues
4. **Authentication Errors**: Clear error messages for credential issues
5. **Package Export Failures**: Detailed logging for troubleshooting

### Log Files
- **Location**: `Logs/vRODoc_YYYYMMDD_HHMMSS.log`
- **Content**: Detailed execution logs with timestamps
- **Error Details**: Full error messages and stack traces
- **Debug Information**: Verbose logging for troubleshooting

## Contributing
Contributions are welcome! Please feel free to submit pull requests.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments
- VMware vRealize Orchestrator team
- JSDoc community
- Node.js community
- PowerShell community

## Support
For issues, questions, or contributions, please open an issue in the GitHub repository.

---

**Version**: 2.2.0 (Enhanced with Interactive Features)  
**Last Updated**: July 2025  
Made with ❤️ for the vRO community
