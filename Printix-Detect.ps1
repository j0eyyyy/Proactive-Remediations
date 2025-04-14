# Detection Script for Printix with Logging
$logPath = "C:\Temp\Printix-DetectionLog.txt"
$printix = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -Recurse | Where-Object { $_.GetValue("DisplayName") -like "Printix*" }

if ($printix) {
    $message = "Printix is installed"
    Write-Output $message
    Add-Content -Path $logPath -Value "$(Get-Date) - $message"
    exit 1
} else {
    $message = "Printix is not installed"
    Write-Output $message
    Add-Content -Path $logPath -Value "$(Get-Date) - $message"
    exit 0
}
