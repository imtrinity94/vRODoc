<#
    Author: Mayank Goyal
    Version: 1.0.0
    Description:
    - Create new files *.js from Actions with JSDoc Annotations under .\Actions\*module names*\
#>

#Changing Default UTF-16 LE Encoding to UTF-8 for JSDoc compatibility
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

## Inputs: 
#Element Folder Path after package unziped
$ElementsFolder = $(Write-Host "Path to unzipped vRO Package? (provide full path ex. C:\com.vro.some.module\elements)-- " -NoNewLine -ForegroundColor yellow; Read-Host)
 
# Path to save all new Modules and Actions
$savePath = $(Write-Host "Path to save Actions? (provide full path) -- " -NoNewLine -ForegroundColor yellow; Read-Host)
 
#Ask if Script is being executed on a Mac (for forwards slash vs backslash in folders)
$defaultOSType = 'windows' 
if (!($osType = $(Write-Host "What is your OS Version? [windows|mac] - default: windows -- " -NoNewLine -ForegroundColor yellow; Read-Host))){$osType = $defaultOSType}
$osType = $osType.ToLower()
 
#Set Slash / BackSlash
$slash = "\"
if ($osType -eq 'mac'){$slash = "/"}
 
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
             $memberOf = " * @memberof "+ $catNameFolder
             $actionVersion = " * @version "+ $xmlElm.'dunes-script-module'.version
             if ($xmlElm.'dunes-script-module'.description.'#cdata-section') {
                $description = " * @description" + $xmlElm.'dunes-script-module'.description.'#cdata-section'
             }             
             echo $function >> $actionName
             echo $memberOf >> $actionName
             echo $actionVersion >> $actionName
             echo $decription  >> $actionName
             
             $paramTypes = $xmlElm.'dunes-script-module'.param.t
             $paramNames = $xmlElm.'dunes-script-module'.param.n
             $paramDescriptions = $xmlElm.'dunes-script-module'.param.'#cdata-section'
             For ($i=0; $i -lt $paramTypes.length; $i++) {
                $params = " * @param {" + $paramTypes[$i] + '} ' + $paramNames[$i] + ' ' + $paramDescriptions[$i]
                echo $params >> $actionName
             }
             if ($xmlElm.'dunes-script-module'.'result-type'){
                $return = " * @returns " + $xmlElm.'dunes-script-module'.'result-type'
             }
             echo $return >> $actionName
             echo " */" >> $actionName
             
             # adding funtion and script content
             $functionHeader = "function " + $xmlElm.'dunes-script-module'.name + "("
             $functionHeader += ($paramNames) -join ","
             $functionHeader += ") {"
             echo $functionHeader >> $actionName
             echo $actionScript >> $actionName
             echo "};" >> $actionName
 
             # Copy to final upload location
             mv $actionName $savePath$slash'Actions'$slash$catNameFolder$slash$actionName
 
        }else{
            write-host "Skipping Workflows, Configuration Elements & Resource Elements"
        }
 
    #Go back root level
    cd ..
 
}
