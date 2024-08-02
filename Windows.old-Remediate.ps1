$Folder2Remove = "Windows.old"
$FolderPath = "C:\"
$ShortcutsOnClient = Get-ChildItem $FolderPath

try{
    $($ShortcutsOnClient | Where-Object -FilterScript {$_.Name -in $Folder2Remove }) | Remove-Item -Force
    Write-Host "Unwanted folder(s) removed."
}catch{
    Write-Error "Error removing folder(s)"
}
