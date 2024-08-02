# Set Variables
$Paths = @("$Env:SystemDrive\Windows.old")

# Check if paths exist, if not trigger remediation.
Try {
    ForEach ($Path in $Paths) {
        $PathTest = Test-Path $Path
        If (!($PathTest)){
            Write-host "$Path Not Found"
            Exit 0
        }
    }
    Write-host "All Paths Found"
    Exit 1
}
Catch {
    $ErrorMsg = $_.Exception.Message
    Write-host "Error $ErrorMsg"
    Exit 0
}
