$Uptime= get-computerinfo | Select-Object OSUptime 
if ($Uptime.OsUptime.Days -ge 5){
    Write-Output "Device has not rebooted in $($Uptime.OsUptime.Days) days, notify user to reboot"
    Exit 1
}else {
    Write-Output "Device has rebooted $($Uptime.OsUptime.Days) days ago, all good"
    Exit 0
}
