# WinVerifyTrustSignature-Remediate.ps1  -  Remediate Microsoft WinVerifyTrust Signature Validation Vulnerability 

function createRegistryKey {
    param (
        [string]$path
    )

    New-Item -Path $path -Force
}

function setRegistryKey {
    param (
        [string]$path,
        [string]$keyName,
        [string]$value
    )

    Set-ItemProperty -Path $path -Name $keyName -Value $value
}

createRegistryKey -path "HKLM:\Software\Microsoft\Cryptography\Wintrust"
createRegistryKey -path "HKLM:\Software\Microsoft\Cryptography\Wintrust\Config"
setRegistryKey -path "HKLM:\Software\Microsoft\Cryptography\Wintrust\Config" -keyName "EnableCertPaddingCheck" -value "1"

if ((Get-WmiObject win32_operatingsystem | select osarchitecture).osarchitecture -eq "64-bit") {
    createRegistryKey -path "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust"
    createRegistryKey -path "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config"
    setRegistryKey -path "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" -keyName "EnableCertPaddingCheck" -value "1"
}
