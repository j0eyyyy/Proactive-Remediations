<#
Unified Legacy App Remediation v6

 - Only remove legacy versions of PAD / Outlook / Copilot / YourPhone / CrossDevice / GetHelp
 - HP Smart, Paint, Paint3D, 3DViewer removed completely
 - Classic Teams removed safely per-user
#>

# ===== Logging =====
$AppName="UnifiedLegacyRemediationV6"
$Root="C:\ProgramData\IntuneRemediation\$AppName"
if(!(Test-Path $Root)){New-Item -ItemType Directory -Path $Root -Force|Out-Null}
$Log=Join-Path $Root ("Remediate-"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log")

function Log($m){ $t=(Get-Date).ToString("s"); Add-Content $Log "[$t] $m"; Write-Host $m -ForegroundColor Yellow }

Log "=== REMEDIATION START ==="

$Err=$false

# ===== Version Baselines =====
$Baselines = @{
    "Microsoft.PowerAutomateDesktop" = [version]"11.2603.149.0"
    "Microsoft.Copilot"              = [version]"1.25023.101.0"
    "Microsoft.GetHelp"              = [version]"10.2409.3"
    "Microsoft.YourPhone"            = [version]"1.26011.42.0"
    "MicrosoftWindows.CrossDevice"   = [version]"1.24112.22.0"
}

$RemoveAlways = @(
    "AD2F1837.HPPrinterControl",
    "Microsoft.MSPaint",
    "Microsoft.MSPaint3D",
    "Microsoft.Microsoft3DViewer"
)

$OutlookPkg="Microsoft.OutlookForWindows"

# ===== Helpers =====
function Remove-Appx-Package {
    param($pkg)
    try{
        Log "Removing AppX: $($pkg.PackageFullName)"
        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Continue
    }catch{ Log "ERROR removing $($pkg.PackageFullName): $($_.Exception.Message)"; $global:Err=$true }
}

function Remove-Provisioned {
    param($p)
    try{
        Log "Removing provisioned: $($p.PackageName)"
        Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Continue
    }catch{ Log "ERROR removing provisioned $($p.PackageName): $($_.Exception.Message)"; $global:Err=$true }
}

function Remove-LegacyVersions {
    param([string]$Name,[version]$Min)

    $installed = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $Name -or $_.Name -like "$Name*" }
    $prov      = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $Name }

    foreach($p in $installed){
        $v=[version]$p.Version
        if($v -lt $Min){ Remove-Appx-Package $p }
    }
    foreach($p in $prov){
        $v=[version]$p.Version
        if($v -lt $Min){ Remove-Provisioned $p }
    }
}

function Remove-AllVersions {
    param([string]$Name)
    $installed = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $Name -or $_.Name -like "$Name*" }
    $prov      = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $Name }
    foreach($p in $installed){ Remove-Appx-Package $p }
    foreach($p in $prov){ Remove-Provisioned $p }
}

function Remove-Outlook-Legacy {
    $installed = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $OutlookPkg }
    $prov      = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $OutlookPkg }

    $versions=@()
    foreach($p in $installed){$versions+=[version]$p.Version}
    foreach($p in $prov){$versions+=[version]$p.Version}

    if($versions.Count -le 1){return}

    $max = ($versions | Sort-Object -Descending | Select-Object -First 1)

    foreach($p in $installed){
        if([version]$p.Version -lt $max){ Remove-Appx-Package $p }
    }
    foreach($p in $prov){
        if([version]$p.Version -lt $max){ Remove-Provisioned $p }
    }
}

function Remove-TeamsClassic {
    $exclude=@("Public","Default","Default User","All Users","WDAGUtilityAccount")
    foreach($p in Get-ChildItem "C:\Users" -Directory){
        if($p.Name -in $exclude){continue}
        $root=Join-Path $p.FullName "AppData\Local\Microsoft\Teams"
        if(Test-Path $root){
            Log "Removing Classic Teams → $($p.Name)"
            try{Remove-Item $root -Recurse -Force -ErrorAction Continue}catch{}
        }
    }
}

# ===== Apply Remediation =====

# Version-gated
foreach($k in $Baselines.Keys){
    Remove-LegacyVersions -Name $k -Min $Baselines[$k]
}

# Hard-remove apps
foreach($n in $RemoveAlways){
    Remove-AllVersions $n
}

# Outlook (remove legacy only)
Remove-Outlook-Legacy

# Classic Teams
Remove-TeamsClassic

# CentraStage intentionally excluded

Log "=== REMEDIATION END ==="

if($Err){ exit 1 } else { exit 0 }
