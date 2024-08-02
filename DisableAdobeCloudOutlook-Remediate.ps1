$regPath = "HKLM:\SOFTWARE\Microsoft\Office\Outlook\AddIns\AdobeAcroOutlook.SendAsLink"
$valueName = "LoadBehavior"

if (Test-Path $regPath) {
    if ((Get-ItemPropertyValue $regPath $valueName -ErrorAction SilentlyContinue) -eq '0') {
        Write-Host "Registry value $valueName already exists."

    } else {
        Set-ItemProperty -Path $regPath -Name $valueName -Value 0 -Type DWORD -Force | Out-Null
        Write-Host "Registry value $valueName added."
    }
} else {
    Write-Host "Registry key $regPath and value $valueName path does not exist and is not required."
}
