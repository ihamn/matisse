# Backup script for matisse OTA workspace
$workspace = "C:\Users\Administrator\Desktop\matisse-ota_full-OS2.0.6.0.ULKCNXM-user-14.0-4853637358"
$output = "C:\Users\Administrator\Desktop\matisse_backup_essentials.zip"

# Remove old backup if exists
if (Test-Path $output) {
    Remove-Item $output -Force
}

$items = @()

# All Python scripts
Get-ChildItem "$workspace\*.py" | ForEach-Object { $items += $_.FullName }

# Markdown docs
Get-ChildItem "$workspace\*.md" | ForEach-Object { $items += $_.FullName }

# Key extracted files
$extracted = "$workspace\extracted"
@(
    "kernel.Image",
    "kernel.gz",
    "kernel.raw.gz",
    "boot_final.img",
    "vendor_boot_full.img",
    "system.img"
) | ForEach-Object {
    $p = Join-Path $extracted $_
    if (Test-Path $p) { $items += $p }
}

# Auxiliary files
@(
    "payload_properties.txt",
    "apex_info.pb",
    "care_map.pb"
) | ForEach-Object {
    $p = Join-Path $workspace $_
    if (Test-Path $p) { $items += $p }
}

# IonStack directory if exists
$ionstack = Join-Path $workspace "IonStack"
if (Test-Path $ionstack) { $items += $ionstack }

# CyberMeowfia directory if exists
$cyber = Join-Path $workspace "CyberMeowfia"
if (Test-Path $cyber) { $items += $cyber }

Write-Host "Files to backup: $($items.Count)"
foreach ($item in $items) {
    Write-Host "  $item"
}

Write-Host "Creating archive..."
Compress-Archive -Path $items -DestinationPath $output -CompressionLevel Optimal -Force

if (Test-Path $output) {
    $size = (Get-Item $output).Length
    Write-Host "Backup created: $output"
    Write-Host "Size: $([math]::Round($size/1024/1024, 1)) MB"
} else {
    Write-Host "ERROR: Failed to create backup"
}