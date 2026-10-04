param(
    [string]$Uf2 = "build/artifacts/cannonball_ll.uf2",
    [int]$TimeoutSeconds = 15
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$uf2FullPath = Join-Path $scriptDir $Uf2

if (-not (Test-Path $uf2FullPath)) {
    $uf2FullPath = Resolve-Path $Uf2 -ErrorAction SilentlyContinue
    if (-not (Test-Path $uf2FullPath)) {
        Write-Error "UF2 not found: $Uf2"
        exit 1
    }
}

Write-Host "Target UF2: $uf2FullPath" -ForegroundColor Cyan

# 1. Check if bootloader drive is already present
$vol = Get-Volume | Where-Object { $_.FileSystemLabel -in @('XIAO-SENSE', 'XIAO-BLE', 'NRF52BOOT') -and $_.DriveLetter }
if (-not $vol) {
    # 2. Trigger 1200bps touch via CDC ACM port
    $dev = Get-PnpDevice -PresentOnly -Class Ports | Where-Object { $_.InstanceId -like '*VID_8884&PID_0922*' }
    if ($dev -and $dev.FriendlyName -match '\((COM\d+)\)') {
        $com = $matches[1]
        Write-Host "Detected Cannonball LL on $com. Sending 1200bps touch..." -ForegroundColor Cyan
        try {
            $port = New-Object System.IO.Ports.SerialPort($com, 1200)
            $port.Open()
            Start-Sleep -Milliseconds 100
            $port.Close()
            Write-Host "1200bps touch sent! Waiting for bootloader drive..." -ForegroundColor Green
        } catch {
            Write-Warning "Could not touch serial port: $_"
        }
    } else {
        Write-Warning "Cannonball LL COM port not found. Watching for bootloader drive..."
    }

    # 3. Wait for drive
    $waited = 0
    while ($waited -lt $TimeoutSeconds) {
        Start-Sleep -Milliseconds 500
        $vol = Get-Volume | Where-Object { $_.FileSystemLabel -in @('XIAO-SENSE', 'XIAO-BLE', 'NRF52BOOT') -and $_.DriveLetter }
        if ($vol) {
            break
        }
        $waited++
    }
}

if (-not $vol) {
    Write-Error "Timeout: Bootloader drive not found. Please verify USB connection."
    exit 1
}

$dest = "$($vol.DriveLetter):\"
Write-Host "Found bootloader drive at $dest. Copying firmware..." -ForegroundColor Green
Copy-Item -Path $uf2FullPath -Destination $dest -Force -Verbose
Write-Host "Flash complete! Device rebooting..." -ForegroundColor Green
