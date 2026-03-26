<#
Unified Legacy App Detection v5
#>

param([switch]$DryRun)

# ===== Logging =====
$AppName  = "UnifiedLegacyDetectionV5"
$RootPath = "C:\ProgramData\IntuneRemediation\$AppName"
if (!(Test-Path $RootPath)) { New-Item -ItemType Directory -Path $RootPath -Force | Out-Null }
$HumanLog = Join-Path $RootPath ("Detect-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")

function Log { param($m) $t=(Get-Date).ToString("s"); Add-Content $HumanLog "[$t] $m"; Write-Host $m }

Log "=== DETECTION START ==="

# ===== Config =====
$Config = @{
    VersionGated = @(
        @{ Name = "Microsoft.GetHelp";            Min = "10.2409.3" }
        @{ Name = "Microsoft.YourPhone";          Min = "1.26011.42.0" }
        @{ Name = "MicrosoftWindows.CrossDevice"; Min = "1.24112.22.0" }
        @{ Name = "Microsoft.Copilot";            Min = "1.25023.101.0" }
    )

    RemoveAll = @(
        "Microsoft.PowerAutomateDesktop",  # PAD (ALL versions removed)
        "Microsoft.OutlookForWindows",     # New Outlook (ALL versions removed)
        "AD2F1837.HPPrinterControl",       # HP Smart (ALL versions removed)
        "Microsoft.MSPaint",
        "Microsoft.MSPaint3D",
        "Microsoft.Microsoft3DViewer"
    )

    TeamsLegacy = @{
        Enabled = $true
        ExcludedProfiles = @("Public","Default","Default User","All Users","WDAGUtilityAccount")
    }
}

# ===== Helpers =====
function Get-AppxState {
    param([string]$Name)
    [pscustomobject]@{
        Name=$Name
        Installed=Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $Name -or $_.Name -like "$Name*" }
        Provisioned=Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $Name }
    }
}

function Detect-RemoveAll {
    param([string]$Name)
    $s = Get-AppxState $Name
    if ($s.Installed -or $s.Provisioned) { Log "$Name → present (remove-all rule)"; return $true }
    return $false
}

function Detect-MinVersion {
    param($Name,$Min)
    $s = Get-AppxState $Name
    $all=@()
    foreach($p in $s.Installed)   { $all+=[version]$p.Version }
    foreach($p in $s.Provisioned) { $all+=[version]$p.Version }
    if($all.Count -eq 0){ return $false }
    foreach($v in $all){ if($v -lt $Min){ Log "$Name outdated ($v < $Min)"; return $true } }
    return $false
}

function Detect-LegacyTeams {
    if (-not $Config.TeamsLegacy.Enabled) { return $false }
    $hit=$false
    foreach($p in Get-ChildItem "C:\Users" -Directory){
        if($p.Name -in $Config.TeamsLegacy.ExcludedProfiles){ continue }
        $root=Join-Path $p.FullName "AppData\Local\Microsoft\Teams"
        if(Test-Path $root){
            $ind=0
            foreach($i in @(".dead","SquirrelSetup","Update.exe","current")){
                if(Test-Path (Join-Path $root $i)){$ind++}
            }
            if($ind -ge 2){
                Log "Legacy Teams found → $($p.Name)"
                $hit=$true
            }
        }
    }
    return $hit
}

# ===== Run Detection =====
$needs=$false

foreach($Item in $Config.RemoveAll){
    if(Detect-RemoveAll $Item){$needs=$true}
}

foreach($rule in $Config.VersionGated){
    if(Detect-MinVersion -Name $rule.Name -Min ([version]$rule.Min)){ $needs=$true }
}

if(Detect-LegacyTeams){ $needs=$true }

Log "=== DETECTION FINISH ==="
if($DryRun){ Log "(DryRun) exit would be $([int]$needs)"; exit 0 }

if($needs){ exit 1 } else { exit 0 }
