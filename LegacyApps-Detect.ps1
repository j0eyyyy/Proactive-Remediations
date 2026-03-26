<#
Unified Legacy App Detection
Date: 2026-03-26

Detects:
 - Power Automate Desktop (keep highest version)
 - GetHelp minimum version
 - YourPhone minimum version
 - CrossDevice minimum version
 - MSPaint / Paint3D / 3DViewer (presence-only)
 - Legacy Teams (classic Squirrel install)
 - HPPrinterControl (keep highest version)

Exit Codes:
 0 = No remediation needed
 1 = Remediation required
#>

param(
    [switch]$DryRun
)

# ============================================================
# LOGGING SETUP
# ============================================================
$AppName  = "UnifiedLegacyDetection"
$RootPath = "C:\ProgramData\IntuneRemediation\$AppName"

if (!(Test-Path $RootPath)) {
    New-Item -ItemType Directory -Path $RootPath -Force | Out-Null
}

$HumanLog = Join-Path $RootPath ("Human-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")

function Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("s")
    Add-Content -LiteralPath $HumanLog -Value "[$ts] $Message"
    Write-Host $Message -ForegroundColor Cyan
}

Log "=== UNIFIED DETECTION START ==="


# ============================================================
# GLOBAL CONFIGURATION (CLEAN ASCII ONLY)
# ============================================================
$Config = @{
    VersionGated = @(
        @{ Name = "Microsoft.GetHelp";            Min = "10.2409.3" }
        @{ Name = "Microsoft.YourPhone";          Min = "1.26011.42.0" }
        @{ Name = "MicrosoftWindows.CrossDevice"; Min = "1.24112.22.0" }
    )

    PresenceOnly = @(
        "Microsoft.MSPaint",
        "Microsoft.MSPaint3D",
        "Microsoft.Microsoft3DViewer"
    )

    PAD = @{
        Name    = "Microsoft.PowerAutomateDesktop"
        Enabled = $true
    }

    HPPrinterControl = @{
        Name    = "AD2F1837.HPPrinterControl"
        Enabled = $true
    }

    TeamsLegacy = @{
        Enabled          = $true
        ExcludedProfiles = @("Public","Default","Default User","All Users","WDAGUtilityAccount")
    }
}


# ============================================================
# HELPERS
# ============================================================
function Get-AppxState {
    param([string]$Name)

    $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -eq $Name -or $_.Name -like "$Name*" }

    $provisioned = Get-AppxProvisionedPackage -Online |
                   Where-Object { $_.DisplayName -eq $Name }

    return [pscustomobject]@{
        Name        = $Name
        Installed   = $installed
        Provisioned = $provisioned
    }
}

function Compare-Version {
    param([array]$Versions)
    if (-not $Versions -or $Versions.Count -eq 0) { return $null }
    return ($Versions | Sort-Object -Descending | Select-Object -First 1)
}


# ============================================================
# DETECTORS
# ============================================================
function Detect-PAD {
    if (-not $Config.PAD.Enabled) { return $false }

    $Name = $Config.PAD.Name
    Log "Checking PAD ($Name)"

    $state = Get-AppxState -Name $Name
    $versions = @()

    foreach ($p in $state.Installed)   { $versions += [version]$p.Version }
    foreach ($p in $state.Provisioned) { $versions += [version]$p.Version }

    if ($versions.Count -eq 0) {
        Log "PAD not present"
        return $false
    }

    $keep = Compare-Version $versions
    Log "PAD highest version: $keep"

    if ($versions | Where-Object { $_ -lt $keep }) {
        Log "Legacy PAD versions found → remediation needed"
        return $true
    }

    return $false
}

function Detect-AppMinVersion {
    param([string]$Name, [version]$Min)

    $state = Get-AppxState -Name $Name
    $versions = @()

    foreach ($p in $state.Installed)   { $versions += [version]$p.Version }
    foreach ($p in $state.Provisioned) { $versions += [version]$p.Version }

    if ($versions.Count -eq 0) { return $false }

    foreach ($v in $versions) {
        if ($v -lt $Min) {
            Log "$Name version $v < minimum $Min → FAIL"
            return $true
        }
    }

    return $false
}

function Detect-PresenceOnly {
    param([string]$Name)

    $state = Get-AppxState -Name $Name
    if ($state.Installed -or $state.Provisioned) {
        Log "$Name present → FAIL"
        return $true
    }
    return $false
}

function Detect-LegacyTeams {
    if (-not $Config.TeamsLegacy.Enabled) { return $false }

    $LegacyFound = $false
    Log "Checking Legacy Teams footprints..."

    $Profiles = Get-ChildItem "C:\Users" -Directory |
                Where-Object { $_.Name -notin $Config.TeamsLegacy.ExcludedProfiles }

    foreach ($Profile in $Profiles) {
        $Root = $Profile.FullName
        $Teams = Join-Path $Root "AppData\Local\Microsoft\Teams"

        if (!(Test-Path $Teams)) { continue }

        $Indicators = 0
        if (Test-Path "$Teams\.dead")      { $Indicators++ }
        if (Test-Path "$Teams\SquirrelSetup") { $Indicators++ }
        if (Test-Path "$Teams\Update.exe") { $Indicators++ }
        if (Test-Path "$Teams\current")    { $Indicators++ }

        if ($Indicators -ge 2) {
            Log "Legacy Teams → detected in profile $($Profile.Name)"
            $LegacyFound = $true
        }
    }

    return $LegacyFound
}

function Detect-HPPrinterControl {
    if (-not $Config.HPPrinterControl.Enabled) { return $false }

    $Name = $Config.HPPrinterControl.Name
    $state = Get-AppxState -Name $Name

    $versions = @()
    foreach ($p in $state.Installed)   { $versions += [version]$p.Version }
    foreach ($p in $state.Provisioned) { $versions += [version]$p.Version }

    if ($versions.Count -eq 0) { return $false }

    $keep = Compare-Version $versions
    if ($versions | Where-Object { $_ -lt $keep }) {
        Log "Legacy HPPrinterControl versions detected"
        return $true
    }

    return $false
}


# ============================================================
# MAIN DETECTION ENGINE
# ============================================================
$Results = @()

# PAD
$Results += [pscustomobject]@{ Component = "PAD"; Result = Detect-PAD }

# Version-gated apps
foreach ($rule in $Config.VersionGated) {
    $Results += [pscustomobject]@{
        Component = $rule.Name
        Result    = Detect-AppMinVersion -Name $rule.Name -Min ([version]$rule.Min)
    }
}

# Presence-only apps
foreach ($name in $Config.PresenceOnly) {
    $Results += [pscustomobject]@{
        Component = $name
        Result    = Detect-PresenceOnly -Name $name
    }
}

# Legacy Teams
$Results += [pscustomobject]@{
    Component = "LegacyTeams"
    Result    = Detect-LegacyTeams
}

# HP Printer Control
$Results += [pscustomobject]@{
    Component = "HPPrinterControl"
    Result    = Detect-HPPrinterControl
}

# ============================================================
# FINAL RESULT
# ============================================================
$NeedsRemediation = ($Results.Result -contains $true)

Log "=== SUMMARY ==="
foreach ($r in $Results) {
    Log "[$($r.Component)] → $($r.Result)"
}

if ($DryRun) {
    Log "DRY RUN MODE: exit code would have been $([int]$NeedsRemediation)"
    exit 0
}

if ($NeedsRemediation) {
    Log "❌ Remediation required"
    exit 1
}

Log "✅ No remediation required"
exit 0
