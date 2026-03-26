<#
Unified Legacy App Remediation
Date: 2026-03-26

Remediates:
 - Power Automate Desktop (remove older versions)
 - GetHelp (remove completely)
 - YourPhone (remove completely)
 - CrossDevice (remove completely)
 - MSPaint / Paint3D / 3DViewer (remove completely)
 - Legacy Teams classic per-user (remove Squirrel install)
 - HPPrinterControl (remove older versions)

Exit Codes:
 0 = Successful remediation (or nothing to do)
 1 = Remediation attempted but errors occurred (Intune will retry)
#>

# ============================================================
# LOGGING SETUP
# ============================================================
$AppName  = "UnifiedLegacyRemediation"
$RootPath = "C:\ProgramData\IntuneRemediation\$AppName"

if (!(Test-Path $RootPath)) {
    New-Item -ItemType Directory -Path $RootPath -Force | Out-Null
}

$LogFile = Join-Path $RootPath ("Remediate-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")

function Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("s")
    Add-Content -LiteralPath $LogFile -Value "[$ts] $Message"
    Write-Host $Message -ForegroundColor Yellow
}

Log "=== UNIFIED REMEDIATION START ==="

$RemediationErrors = $false

# ============================================================
# UTILITY FUNCTIONS
# ============================================================
function Try-Remove-Appx {
    param(
        [string]$Name
    )
    try {
        $pkgs = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $Name -or $_.Name -like "$Name*" }
        foreach ($p in $pkgs) {
            Log "Removing AppX package: $($p.PackageFullName)"
            Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Continue
        }
    }
    catch {
        Log "ERROR removing AppX for $Name : $($_.Exception.Message)"
        $global:RemediationErrors = $true
    }

    # Provisioned
    try {
        $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $Name }
        foreach ($p in $prov) {
            Log "Removing provisioned package: $($p.PackageName)"
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Continue
        }
    }
    catch {
        Log "ERROR removing provisioned AppX for $Name : $($_.Exception.Message)"
        $global:RemediationErrors = $true
    }
}

function Try-Remove-Path {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            Log "Removing path: $Path"
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Continue
        }
    }
    catch {
        Log "ERROR removing $Path : $($_.Exception.Message)"
        $global:RemediationErrors = $true
    }
}

# ============================================================
# 1. POWER AUTOMATE DESKTOP
# ============================================================
Log "--- Remediating Power Automate Desktop (PAD) ---"

$padName = "Microsoft.PowerAutomateDesktop"

$padInstalled = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "$padName*" }
$padProv      = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $padName }

$padVersions = @()
foreach ($p in $padInstalled) { $padVersions += [version]$p.Version }
foreach ($p in $padProv)      { $padVersions += [version]$p.Version }

if ($padVersions.Count -gt 0) {
    $keep = ($padVersions | Sort-Object -Descending | Select-Object -First 1)

    foreach ($p in $padInstalled) {
        if ([version]$p.Version -lt $keep) {
            Log "Removing legacy PAD version: $($p.Version)"
            Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Continue
        }
    }

    foreach ($p in $padProv) {
        if ([version]$p.Version -lt $keep) {
            Log "Removing legacy PAD provisioned version: $($p.Version)"
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Continue
        }
    }
}
else {
    Log "PAD not installed — nothing to remove"
}

# ============================================================
# 2. VERSION-GATED APPS (Remove Completely)
# ============================================================
$VersionApps = @(
    "Microsoft.GetHelp",
    "Microsoft.YourPhone",
    "MicrosoftWindows.CrossDevice"
)

foreach ($name in $VersionApps) {
    Log "--- Removing version-gated app: $name ---"
    Try-Remove-Appx -Name $name
}

# ============================================================
# 3. PRESENCE-ONLY APPS
# ============================================================
$PresenceOnly = @(
    "Microsoft.MSPaint",
    "Microsoft.MSPaint3D",
    "Microsoft.Microsoft3DViewer"
)

foreach ($name in $PresenceOnly) {
    Log "--- Removing presence-only app: $name ---"
    Try-Remove-Appx -Name $name
}

# ============================================================
# 4. LEGACY TEAMS (CLASSIC PER-USER)
# ============================================================
Log "--- Removing Legacy Teams Classic ---"

$ExcludedProfiles = @("Public","Default","Default User","All Users","WDAGUtilityAccount")

$Profiles = Get-ChildItem "C:\Users" -Directory |
            Where-Object { $_.Name -notin $ExcludedProfiles }

foreach ($Profile in $Profiles) {
    $UserRoot = $Profile.FullName
    $TeamsRoot = Join-Path $UserRoot "AppData\Local\Microsoft\Teams"

    if (Test-Path $TeamsRoot) {
        Log "Cleaning Teams Classic for: $($Profile.Name)"

        # Remove Squirrel artifacts safely
        Try-Remove-Path "$TeamsRoot\current"
        Try-Remove-Path "$TeamsRoot\SquirrelSetup"
        Try-Remove-Path "$TeamsRoot\.dead"
        Try-Remove-Path "$TeamsRoot\Update.exe"
        Try-Remove-Path $TeamsRoot
    }
}

# ============================================================
# 5. HP PRINTER CONTROL
# ============================================================
Log "--- Remediating HP Printer Control ---"

$hpName = "AD2F1837.HPPrinterControl"
$hpInstalled = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $hpName -or $_.Name -like "$hpName*" }
$hpProv      = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $hpName }

$hpVersions = @()
foreach ($p in $hpInstalled) { $hpVersions += [version]$p.Version }
foreach ($p in $hpProv)      { $hpVersions += [version]$p.Version }

if ($hpVersions.Count -gt 0) {
    $keep = ($hpVersions | Sort-Object -Descending | Select-Object -First 1)

    foreach ($p in $hpInstalled) {
        if ([version]$p.Version -lt $keep) {
            Log "Removing legacy HPPrinterControl installed version: $($p.Version)"
            Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Continue
        }
    }

    foreach ($p in $hpProv) {
        if ([version]$p.Version -lt $keep) {
            Log "Removing legacy HPPrinterControl provisioned version: $($p.Version)"
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Continue
        }
    }
}
else {
    Log "HP Printer Control not installed"
}

# ============================================================
# FINAL STATUS
# ============================================================
if ($RemediationErrors) {
    Log "❌ Remediation completed with errors"
    exit 1
}

Log "✅ Remediation completed successfully"
exit 0
