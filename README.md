
```markdown
# vRODoc - vRO Documentation Generator

## Overview
vRODoc is a PowerShell-based tool that automatically generates comprehensive JSDoc documentation from VMware vRealize Orchestrator (vRO) packages. It simplifies the process of documenting vRO actions by creating a searchable HTML documentation site.

## Features
- 🚀 Automatic prerequisite checking and installation
- 🔐 Secure vRO authentication handling
- 📦 Package extraction and processing
- 📄 JSDoc-compatible documentation generation
- 🌐 Searchable HTML output
- ⚡ Support for both vRO 7.x and 8.x

## Prerequisites
- PowerShell 5.1 or higher
- Node.js
- JSDoc
- Write access to export directory
- Network access to vRO server
- Embedded vRO Setup only
- Works on Windows. Script not tested on Linux.

> The script can automatically install missing prerequisites if `autoFix` is enabled.
```
## Usage
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
![vrodoc_1](https://github.com/user-attachments/assets/3586588e-271e-42bd-a71d-c29329a06b32)

### Parameters
| Parameter    | Description                                      | Default        |
|-------------|--------------------------------------------------|----------------|
| vroHost     | vRA FQDN for embedded vRO                                 | vro.domain     |
| vroPort     | vRO port (443 for 8.x)        | 443            |
| user        | Username for vRA authentication                   | user@domain    |
| pass        | Password for vRA authentication                   | pa$$W0rd              |
| exportPath  | Output directory for documentation               | C:\Users\user\ |
| packageName | vRO package name to document (eg. com.vmware.utilities)                   | -              |
| autoFix     | Automatically fix missing prerequisites          | true           |
| skipChecks  | Skip prerequisite checks (not recommended)       | false          |

## Output Structure
```
exportPath/
└── vRODoc Files/
    ├── [Package_Name]/
        └── Actions/
        |   └── [Category]/
        |        └── action.js
        └── docs/
            └── index.html
```
## Output HTML webpages with JSdoc annotation
![vrodoc_4](https://github.com/user-attachments/assets/b901bc0d-e5a3-4f65-8499-bbd1f98012d4)


## Steps to follow
- Create a package with all the custom actions.
- As script works for embedded vRO, fill all the parameter values either in script or while running the script.
- Wait for the script to successfully complete.
- In the export path, you will find a directory called "vRODoc Files"
- Open vRODoc Files > packageName folder (eg. com.vmware.utilities) > docs > index.html
- In your browser, a page will open up with all your actions in a beautiful JSdoc format. 

## Features
- Automatic prerequisite validation
- Self-healing installation of dependencies
- Secure token-based authentication
- Comprehensive error handling
- Progress indicators
- Clean documentation output

## Contributing
Contributions are welcome! Please feel free to submit pull requests.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments
- VMware vRealize Orchestrator team
- JSDoc community
- Node.js community

## Support
For issues, questions, or contributions, please open an issue in the GitHub repository.

---
Made with ❤️ for the vRO community
