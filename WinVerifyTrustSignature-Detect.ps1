# tWinVerifyTrustSignature-Detec.ps1  -  Detect Microsoft WinVerifyTrust Signature Validation Vulnerability 

function compareRegistryValue {
    param (
        [string]$path,
        [string]$keyName,
        [string]$value
    )

    $currentValue = (Get-ItemProperty -Path $path -Name $keyName).$keyName

    if ($currentValue -eq $value) {
        return $true
    } else {
        return $false
    }
}

$thirtyTwo = compareRegistryValue -path "HKLM:\Software\Microsoft\Cryptography\Wintrust\Config" -keyName "EnableCertPaddingCheck" -value "1"

if ((Get-WmiObject win32_operatingsystem | select osarchitecture).osarchitecture -eq "64-bit") {
    $sixtyFour = compareRegistryValue -path "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" -keyName "EnableCertPaddingCheck" -value "1"
} else {
    $sixtyFour = $true
}

if ($thirtyTwo -and $sixtyFour) {
    Write-Output "The registry key is set to the expected value."
    exit 0
} else {
    Write-Output "The registry key is not set to the expected value."
    exit 1
}
