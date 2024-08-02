$regPath = "HKLM:\SOFTWARE\Microsoft\Office\Outlook\AddIns\AdobeAcroOutlook.SendAsLink"
$valueName = "LoadBehavior"

if (Test-Path $regPath) {
    if ((Get-ItemPropertyValue $regPath $valueName -ErrorAction SilentlyContinue) -eq '3') {
        Write-Host "Registry value $valueName exists."
        Exit 1
    } else {
        Write-Host "Registry value $valueName does not exist."
    }
} else {
    Write-Host "Registry key $regPath does not exist."
    Exit 0
}
