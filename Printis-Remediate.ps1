# Remediation Script to uninstall Printix with Logging
$logPath = "C:\Temp\Printix-RemediationLog.txt"

function Uninstall-Printix {
    param (
        [string]$uninstallString
    )

    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallString /quiet /silent /verysilent /norestart" -NoNewWindow -Wait
    if ($?) {
        $message = "Printix uninstallation completed successfully"
        Write-Output $message
        Add-Content -Path $logPath -Value "$(Get-Date) - $message"
    } else {
        $message = "Printix uninstallation failed"
        Write-Output $message
        Add-Content -Path $logPath -Value "$(Get-Date) - $message"
    }
}

$printix = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -Recurse | Where-Object { $_.GetValue("DisplayName") -like "Printix*" }

if ($printix) {
    $uninstallString = $printix.GetValue("UninstallString")
    $message = "Printix is installed, starting uninstallation"
    Write-Output $message
    Add-Content -Path $logPath -Value "$(Get-Date) - $message"
    Uninstall-Printix -uninstallString $uninstallString
} else {
    $message = "Printix is not installed"
    Write-Output $message
    Add-Content -Path $logPath -Value "$(Get-Date) - $message"
}
