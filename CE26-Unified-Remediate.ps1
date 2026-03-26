<#
Unified Legacy App Remediation v5
#>

# ===== Logging =====
$AppName="UnifiedLegacyRemediationV5"
$Root="C:\ProgramData\IntuneRemediation\$AppName"
if(!(Test-Path $Root)){New-Item -ItemType Directory -Path $Root -Force|Out-Null}
$Log=Join-Path $Root ("Remediate-"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log")

function Log($m){ $t=(Get-Date).ToString("s"); Add-Content $Log "[$t] $m"; Write-Host $m -ForegroundColor Yellow }

Log "=== REMEDIATION START ==="
$Err=$false

# ===== Utilities =====
function Remove-Appx-All {
    param($Name)
    try{
        foreach($p in Get-AppxPackage -AllUsers | ? {$_.Name -eq $Name -or $_.Name -like "$Name*"}){
            Log "Removing AppX: $($p.PackageFullName)"
            Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Continue
        }
        foreach($p in Get-AppxProvisionedPackage -Online | ? {$_.DisplayName -eq $Name}){
            Log "Removing provisioned: $($p.PackageName)"
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Continue
        }
    }catch{ Log "Error removing $Name → $($_.Exception.Message)"; $global:Err=$true }
}

function Remove-TeamsClassic {
    $exclude=@("Public","Default","Default User","All Users","WDAGUtilityAccount")
    foreach($p in Get-ChildItem "C:\Users" -Directory){
        if($p.Name -in $exclude){continue}
        $r=Join-Path $p.FullName "AppData\Local\Microsoft\Teams"
        if(Test-Path $r){
            Log "Removing Teams Classic for $($p.Name)"
            Remove-Item $r -Recurse -Force -ErrorAction Continue
        }
    }
}

# ===== REMEDIATION TARGET LISTS =====
$RemoveAll = @(
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.OutlookForWindows",
    "AD2F1837.HPPrinterControl",
    "Microsoft.MSPaint",
    "Microsoft.MSPaint3D",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.GetHelp",
    "Microsoft.YourPhone",
    "MicrosoftWindows.CrossDevice",
    "Microsoft.Copilot"
)

# ===== Execute Removals =====
foreach($n in $RemoveAll){ Remove-Appx-All $n }

Remove-TeamsClassic

Log "=== REMEDIATION FINISH ==="

if($Err){ exit 1 } else { exit 0 }
