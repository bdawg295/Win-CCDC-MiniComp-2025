# =========================
#  Mini-Comp Windows Hardening (Uptime-First, Stateless)
#  Roles: IIS (Moon Landing), WINRM (First Olympics), ICMP (Silk Road)
#  Never create users. Never delete users. Never change passwords.
#  Admins: never add; only remove extras from Administrators.
#  Users: enforce keep-list by disabling everyone else.
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference     = 'SilentlyContinue'

# --- Helpers ---
function Read-YesNo($Prompt) {
    while ($true) {
        $a = (Read-Host "$Prompt (Y/N)").ToUpper()
        if ($a -in @('Y','N')) { return $a }
        Write-Host "Enter Y or N."
    }
}
function Get-LocalNames($members) {
    $members | ForEach-Object { if ($_ -match '\\') { $_.Split('\')[-1] } else { $_ } }
}

# --- Admins: de-elevate extras only (no additions) ---
function Invoke-Admins {
    param([string[]]$KeepAdmins)

    if (-not $KeepAdmins -or $KeepAdmins.Count -eq 0) {
        Write-Host "Admins: no keep-list provided; skipping." -ForegroundColor Yellow
        return
    }

    $Keep = ($KeepAdmins + 'Administrator') | Sort-Object -Unique
    Write-Host "`nAdmins keep-list:" -ForegroundColor Yellow
    $Keep | ForEach-Object { "  - $_" }

    if ((Read-YesNo "Proceed to remove extras from Administrators?") -ne 'Y') { return }

    $currentAdmins = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue |
        Where-Object { $_.PrincipalSource -eq 'Local' } |
        Select-Object -ExpandProperty Name | Get-LocalNames

    $extras  = $currentAdmins | Where-Object { $Keep -notcontains $_ }
    $missing = $Keep          | Where-Object { $currentAdmins -notcontains $_ }
    if ($missing) {
        Write-Host "Notice: authorized admins not currently elevated: $($missing -join ', ')" -ForegroundColor Yellow
    }

    foreach ($e in $extras) {
        if ($e -ieq 'Administrator') { continue }
        Write-Host "Removing $e from Administrators (account kept)"
        net localgroup Administrators $e /delete | Out-Null
    }
}

# --- Users: never create or delete; enable kept, disable others ---
function Invoke-Users {
    param([string[]]$KeepUsers)

    if (-not $KeepUsers -or $KeepUsers.Count -eq 0) {
        Write-Host "Users: no keep-list provided; skipping." -ForegroundColor Yellow
        return
    }

    $Keep = $KeepUsers | Sort-Object -Unique
    Write-Host "`nUsers keep-list:" -ForegroundColor Yellow
    $Keep | ForEach-Object { "  - $_" }

    if ((Read-YesNo "Proceed to enable kept users and disable others?") -ne 'Y') { return }

    $current = Get-LocalUser

    foreach ($u in $Keep) {
        $obj = $current | Where-Object { $_.Name -eq $u }
        if ($obj) {
            Enable-LocalUser -Name $u -ErrorAction SilentlyContinue
        } else {
            Write-Host "Notice: $u does not exist; no creation performed." -ForegroundColor Yellow
        }
    }

    foreach ($cu in $current) {
        if ($Keep -notcontains $cu.Name) {
            Write-Host "Disabling non-authorized user: $($cu.Name)"
            Disable-LocalUser -Name $cu.Name -ErrorAction SilentlyContinue
        }
    }
}

# --- Firewall: only open what the role needs ---
function Invoke-Firewall {
    param([ValidateSet('IIS','WINRM','ICMP')] [string]$Role)

    Write-Host "`nFirewall profile: $Role" -ForegroundColor Cyan
    netsh advfirewall set allprofiles state on | Out-Null
    netsh advfirewall firewall add rule name="Allow ICMPv4 Echo In" dir=in action=allow protocol=icmpv4:8,any enable=yes | Out-Null

    switch ($Role) {
        'IIS' {
            New-NetFirewallRule -DisplayName "Allow HTTP In"  -Direction Inbound -Protocol TCP -LocalPort 80  -Action Allow -ErrorAction SilentlyContinue | Out-Null
            New-NetFirewallRule -DisplayName "Allow HTTPS In" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow -ErrorAction SilentlyContinue | Out-Null
        }
        'WINRM' {
            New-NetFirewallRule -DisplayName "Allow WinRM 5985 In" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow -ErrorAction SilentlyContinue | Out-Null
            New-NetFirewallRule -DisplayName "Allow WinRM 5986 In" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow -ErrorAction SilentlyContinue | Out-Null
        }
        'ICMP' { }
    }
}

# --- Services: disable a small safe set; keep role-required services running ---
function Invoke-Services {
    param([ValidateSet('IIS','WINRM','ICMP')] [string]$Role)

    $baselineDisable = @('RemoteRegistry','DiagTrack','SNMP','Telnet','SSDPSRV','upnphost')
    foreach ($s in $baselineDisable) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Host "Disabling $s"
            Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
            Set-Service -Name $s -StartupType Disabled
        }
    }

    switch ($Role) {
        'IIS' {
            $need = @('W3SVC','WAS','HTTP')
            foreach ($n in $need) {
                $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
                if ($svc) {
                    Set-Service -Name $n -StartupType Automatic
                    Start-Service -Name $n -ErrorAction SilentlyContinue
                }
            }
        }
        'WINRM' {
            $svc = Get-Service -Name 'WinRM' -ErrorAction SilentlyContinue
            if ($svc) {
                Set-Service -Name 'WinRM' -StartupType Automatic
                Start-Service -Name 'WinRM' -ErrorAction SilentlyContinue
            }
        }
        'ICMP' { }
    }
}

# --- Entry point ---
function harden {
    param(
        [ValidateSet('IIS','WINRM','ICMP')] [Parameter(Mandatory=$true)] [string]$Role,
        [string[]]$KeepAdmins,
        [string[]]$KeepUsers
    )

    $BTDir = 'C:\BlueTeam'
    if (-not (Test-Path $BTDir)) { New-Item -ItemType Directory -Path $BTDir | Out-Null }
    $LogPath = Join-Path $BTDir 'harden.log'
    try { Stop-Transcript | Out-Null } catch {}
    Start-Transcript -Path $LogPath -Append | Out-Null

    Write-Host @"
==================================
|  Mini-Comp Win Harden (Safe)   |
|  Role: $Role                   |
|  Log:  $LogPath                |
==================================
"@ -ForegroundColor Magenta

    Invoke-Admins   -KeepAdmins $KeepAdmins
    Invoke-Users    -KeepUsers  $KeepUsers
    Invoke-Firewall -Role $Role
    Invoke-Services -Role $Role

    Write-Host "`nDone." -ForegroundColor Green
    try { Stop-Transcript | Out-Null } catch {}
}
