$savePath = $(Write-Host "Where are your Actions(.js)? (provide full path) -- " -NoNewLine -ForegroundColor yellow; Read-Host)
#Set Slash
$slash = "\"
jsdoc --recurse $savePath$slash'Actions' -d $savePath$slash'docs'
write-host "Actions(.js) converted to .html at  $savePath\docs";
