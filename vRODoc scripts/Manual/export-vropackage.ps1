# Tested on vRO 8.3 
Param(
  [string]$vroHost="vro.domain",
  [string]$vroPort="443",
  [string]$user="user@domain",
  [string]$pass="********",
  [string]$exportPath="C:\Users\temp",
  [Parameter(Mandatory=$true)]
  [string]$packageName='ALL.ELEMENTS',
  [string]$fileName=$packageName + ".package"
)

#### Make no changes below this line ###############################
# Usage:
# If you run the script with no parameters specified, the default values defined above will be used.
# to run with params, See following example: (Should be all one line)
# NOTE: It is not required to specify name of each parameter, but order will need to match the order in the above params section
# PS C:\> ./export-package.ps1 -vroHost vro6.demo.lab -vroPort 8281 -user vcoadmin -pass vcoadmin -exportPath "c:\hol\" -packageName await-tokens
#
####################################################################

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
#Start-Sleep -s 10

$ret.Content | Set-Content -Path  $exportPath\$fileName -Encoding Byte

write-host "";
write-host "$expPackageURI";
write-host "Exported  to: $exportPath\$fileName";
Rename-Item $exportPath\$fileName $packageName'.zip'
Expand-Archive -LiteralPath $exportPath\$packageName'.zip' -DestinationPath $exportPath\$packageName
write-host "Extracted  to: $exportPath\$packageName";
