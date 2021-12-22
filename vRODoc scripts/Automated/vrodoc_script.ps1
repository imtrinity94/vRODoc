<#
    Author: Mayank Goyal
    Version: 2.1.0
    Last Updated: 22nd Dec 2021
    Description: Create new files *.js directly from vRO. It consumes a package name which should exist in vRO with all the Actions you wanted to document and creates .js files with JSDoc Annotations under $exportPath\$packageName\Actions\*module names*\ and converted .html files under $exportPath\$packageName\docs
    How to run: ./vrodoc_script.ps1 -vroHost vro.domain -vroPort 443 -user user@domain -pass pa$$word -exportPath "c:\users\user" -packageName com.package.name
    Notes: If you run the script with no parameters specified, the default values defined below will be used.
    Requires: nodejs and jsdoc module installed
#>

Param(
  [string]$vroHost="vro.domain",
  [string]$vroPort="443",
  [string]$user="user@domain",
  [string]$pass="pa$$word",
  [string]$exportPath="C:\Users\user\",
  [Parameter(Mandatory=$true)]
  [string]$packageName='code.important.actions',
  [string]$fileName=$packageName + ".package"
)

######################### Showdown ###############################

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function ConvertTo-Base64($string) {
   $bytes  = [System.Text.Encoding]::UTF8.GetBytes($string);
   $encoded = [System.Convert]::ToBase64String($bytes); 

   return $encoded;
}

$vcoUrl = "https://$($vroHost):$($vroPort)/vco/api";

# Authentication token
$token = ConvertTo-Base64("$($user):$($pass)");
$auth = "Basic $($token)";

$headers = @{"Authorization"= $auth;'Accept'='Application/zip'; 'Accept-Encoding'='gzip, deflate'; };
$expPackageURI = "https://$($vroHost):$($vroPort)/vco/api/packages/$($packageName)/?exportConfigurationAttributeValues=true";
$ret = Invoke-WebRequest -uri $expPackageURI -Headers $headers -ContentType "application/zip;charset=utf-8" -Method Get

$ret.Content | Set-Content -Path  $exportPath\$fileName -Encoding Byte

write-host "";
write-host "$expPackageURI";
write-host "Exported  to: $exportPath\$fileName";
Rename-Item $exportPath\$fileName $packageName'.zip'
Expand-Archive -LiteralPath $exportPath\$packageName'.zip' -DestinationPath $exportPath\$packageName
write-host "Extracted  to: $exportPath\$packageName";

#Changing Default UTF-16 LE Encoding to UTF-8 for JSDoc compatibility. You can also change jsdoc config to consume UTF-16 .js files
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

## Inputs: 
#Element Folder Path after package unzipped
$ElementsFolder = $exportPath+'\'+$packageName+'\elements'
 
# Path to save all new Modules and Actions
$savePath = $exportPath+'\'+$packageName

#Set Slash
$slash = "\"

# Enter the folder path
cd $ElementsFolder
 
$dir = dir $ElementsFolder | ?{$_.PSISContainer}
foreach ($d in $dir){
    # Enter subfolder path
    cd $d
     
    ## Do Tasks copying from Element folder and formatting to javascript with Parameters commented/scripts to .js
 
    #Get the categories file to determine vRO Module
        Select-Xml -Path .\categories -XPath 'categories'
        [xml]$xmlElm = Get-Content -Path .\categories
        #this getthe action name
        $catNameFolder = $xmlElm.categories.category.name.'#cdata-section'
        write-host "Module name: " $catNameFolder
 
        [xml]$xmlElm = Get-Content -Path .\info
        $elementType = $xmlElm.properties.entry.'#text'
     
        #Get the Actions
        if ($elementType -contains "ScriptModule") {
 
            ## if module contains space or more than 1 categorie  = It's a  workflow Folder or Configuration Element type 
             #Create module folder
             if ($osType -eq 'mac'){
                mkdir -p $savePath$slash'Actions'$slash$catNameFolder
             } else {
                mkdir $savePath$slash'Actions'$slash$catNameFolder
             }
              
             #Get the data file to determine vRO Action
             Select-Xml -Path .\data -XPath 'dunes-script-module/script'
             [xml]$xmlElm = Get-Content -Path .\data
 
             #this get the action name
             $actionName = $xmlElm.'dunes-script-module'.name
             $actionName = $actionName+".js"
 
             # This returns all parameters
             $actionParams = $xmlElm.'dunes-script-module'.param
 
             #This return all script part
             $actionScript = $xmlElm.'dunes-script-module'.script.'#cdata-section'
 
             # creating file javascript
             New-Item -Name  $actionName -ItemType File
 
             # adding Metadata in JSDoc Style
             echo "/**" >> $actionName
             #echo " * @author Mayank Goyal [mayankgoyalmax@gmail.com]" >> $actionName
             $function = " * @function "+ $xmlElm.'dunes-script-module'.name
             #$memberOf = " * @memberof "+ $catNameFolder
             $actionVersion = " * @version "+ $xmlElm.'dunes-script-module'.version
             if ($xmlElm.'dunes-script-module'.description.'#cdata-section') {
                $description = " * @description" + $xmlElm.'dunes-script-module'.description.'#cdata-section'
             }             
             echo $function >> $actionName
             # echo $memberOf >> $actionName not showing up actions under global - not usable
             echo $actionVersion >> $actionName
             echo $decription  >> $actionName
             $params = $xmlElm.'dunes-script-module'.param
             $paramTypes = $params.t
             $paramNames = $params.n
             $paramDescriptions = $params.'#cdata-section'
	     foreach ($param in $params) {
			$params = " * @param {" + $param.t + '} ' + $param.n + ' ' + $param.'#cdata-section'
			echo $params >> $actionName
	     }
             if ($xmlElm.'dunes-script-module'.'result-type'){
                $return = " * @returns {" + $xmlElm.'dunes-script-module'.'result-type' + "}"
             }
             echo $return >> $actionName
             echo " */" >> $actionName
             
             # adding function and script content
             $functionHeader = "function " + $xmlElm.'dunes-script-module'.name + "("
             $functionHeader += ($paramNames) -join ","
             $functionHeader += ") {"
             echo $functionHeader >> $actionName
			 if ($actionScript) {
				foreach ($line in $actionScript.split([System.Environment]::NewLine)) {
					echo `t$line >> $actionName
				}
			 }
             ##echo `t$actionScript >> $actionName
             echo "};" >> $actionName
 
             # Copy to final upload location
             mv -ErrorAction SilentlyContinue $actionName $savePath$slash'Actions'$slash$catNameFolder$slash$actionName 
 
        }else{
            write-host "Skipping Workflows, Configuration Elements & Resource Elements"
        }
 
    #Go back root level
    cd ..
 
}

jsdoc --recurse $savePath$slash'Actions' -d $savePath$slash'docs'
write-host "Actions(.js) converted to .html at  $savePath\docs";
