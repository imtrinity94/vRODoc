
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
| vroHost     | vRO server FQDN                                  | vro.domain     |
| vroPort     | vRO port (443 for 8.x, 8281 for 7.x)            | 443            |
| user        | Username for vRO authentication                   | user@domain    |
| pass        | Password for vRO authentication                   | -              |
| exportPath  | Output directory for documentation               | C:\Users\user\ |
| packageName | vRO package name to document                     | -              |
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

![vrodoc_2](https://github.com/user-attachments/assets/bf034c86-01eb-4aef-a1a4-e9cb70bce10f)


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
```
