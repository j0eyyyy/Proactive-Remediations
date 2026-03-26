<#
Unified Legacy App Detection v6

Change Summary:
 - Only remove legacy/vulnerable versions of PAD, Copilot, GetHelp, YourPhone, CrossDevice
 - Outlook: keep newest version, remove any legacy duplicates
 - HP Smart removed entirely (obsolete)
 - Paint / 3D Viewer removed entirely (deprecated)
 - Legacy Teams only if Squirrel classic detected
#>

param([switch]$DryRun)

# ===== Logging =====
$AppName  = "UnifiedLegacyDetectionV6"
$RootPath = "C:\ProgramData\IntuneRemediation\$AppName"
if (!(Test-Path $RootPath)) { New-Item -ItemType Directory -Path $RootPath -Force | Out-Null }
$LogFile = Join-Path $RootPath ("Detect-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")

function Log { param($m) $t=(Get-Date).ToString("s"); Add-Content $LogFile "[$t] $m"; Write-Host $m }

Log "=== DETECTION START ==="

# ===== Version Baselines =====
$Baselines = @{
    "Microsoft.PowerAutomateDesktop" = [version]"11.2603.149.0"
    "Microsoft.Copilot"              = [version]"1.25023.101.0"
    "Microsoft.GetHelp"              = [version]"10.2409.3"
    "Microsoft.YourPhone"            = [version]"1.26011.42.0"
    "MicrosoftWindows.CrossDevice"   = [version]"1.24112.22.0"
}

# ===== Hard Remove Apps (obsolete) =====
$RemoveAlways = @(
    "AD2F1837.HPPrinterControl",
    "Microsoft.MSPaint",
    "Microsoft.MSPaint3D",
    "Microsoft.Microsoft3DViewer"
)

# ===== Outlook: keep newest only =====
$OutlookPkg = "Microsoft.OutlookForWindows"

# ===== Helpers =====
function Get-AppxState {
    param([string]$Name)
    [pscustomobject]@{
        Name        = $Name
        Installed   = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $Name -or $_.Name -like "$Name*" }
        Provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $Name }
    }
}

function Detect-VersionGated {
    param([string]$Name,[version]$Min)
    $s = Get-AppxState $Name
    $versions=@()
    foreach($p in $s.Installed){$versions+=[version]$p.Version}
    foreach($p in $s.Provisioned){$versions+=[version]$p.Version}
    if($versions.Count -eq 0){return $false}
    foreach($v in $versions){
        if($v -lt $Min){
            Log "$($Name): legacy detected ($($v) < $($Min))"
            return $true
        }
    }
    return $false
}

function Detect-RemoveAlways {
    param([string]$Name)
    $s = Get-AppxState $Name
    if($s.Installed -or $s.Provisioned){
        Log "$Name is obsolete → remediation required"
        return $true
    }
    return $false
}

function Detect-Outlook {
    $s = Get-AppxState $OutlookPkg
    $versions=@()
    foreach($p in $s.Installed){$versions+=[version]$p.Version}
    foreach($p in $s.Provisioned){
        $versions+=[version]$p.Version
    }
    if($versions.Count -le 1){ return $false }
    $max = ($versions | Sort-Object -Descending | Select-Object -First 1)
    if($versions | Where-Object { $_ -lt $max }){
        Log "Outlook legacy versions detected"
        return $true
    }
    return $false
}

function Detect-LegacyTeams {
    $exclude=@("Public","Default","Default User","All Users","WDAGUtilityAccount")
    $hit=$false
    foreach($p in Get-ChildItem "C:\Users" -Directory){
        if($p.Name -in $exclude){continue}
        $root=Join-Path $p.FullName "AppData\Local\Microsoft\Teams"
        if(Test-Path $root){
            $ind=0
            foreach($i in @(".dead","SquirrelSetup","Update.exe","current")){
                if(Test-Path (Join-Path $root $i)){$ind++}
            }
            if($ind -ge 2){
                Log "Classic Teams detected in profile $($p.Name)"
                $hit=$true
            }
        }
    }
    return $hit
}

# ===== Execute Detection =====
$needs=$false

# Version-gated apps
foreach($k in $Baselines.Keys){
    if(Detect-VersionGated $k $Baselines[$k]){$needs=$true}
}

# Remove-always apps
foreach($n in $RemoveAlways){
    if(Detect-RemoveAlways $n){$needs=$true}
}

# Outlook
if(Detect-Outlook){$needs=$true}

# Classic Teams
if(Detect-LegacyTeams){$needs=$true}

Log "=== DETECTION END ==="
if($DryRun){Log "(DryRun) would exit $([int]$needs)"; exit 0}

if($needs){exit 1}else{exit 0}
