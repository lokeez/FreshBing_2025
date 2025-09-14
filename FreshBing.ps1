# FreshBing_2025.ps1
# PowerShell 7+ required

$PicturesFolder = [Environment]::GetFolderPath("MyPictures")
Write-Host "Resolved Pictures folder: $PicturesFolder"

if (-not (Test-Path $PicturesFolder)) {
    Write-Host "Pictures folder doesn't exist -> creating..."
    try { New-Item -ItemType Directory -Path $PicturesFolder -Force | Out-Null }
    catch { Write-Error "Cannot create Pictures folder: $($_.Exception.GetType().FullName) - $($_.Exception.Message)"; return }
}

$selectedFile = Join-Path $PicturesFolder "background.jpg"
$tempFile = $selectedFile + ".tmp"

# quick write-permission test
try {
    $probe = Join-Path $PicturesFolder ("probe_" + [guid]::NewGuid().ToString() + ".tmp")
    [System.IO.File]::WriteAllText($probe, "ok")  # should create
    Remove-Item $probe -Force
    Write-Host "Write test OK in $PicturesFolder"
}
catch {
    Write-Error "Write test FAILED: $($_.Exception.GetType().FullName) - $($_.Exception.Message)"
    Write-Error "Check permissions, Controlled Folder Access (Windows Security), OneDrive or antivirus."
    return
}

# Bing URL (uk-UA)
$bingUrl = "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=uk-UA"

try {
    $feed = Invoke-RestMethod -Uri $bingUrl -ErrorAction Stop
    $imgUrl = "https://www.bing.com" + $feed.images[0].url
    Write-Host "Image URL: $imgUrl"
}
catch {
    Write-Error "Failed to get Bing feed: $($_.Exception.GetType().FullName) - $($_.Exception.Message)"; return
}

# Try download via HttpClient -> stream copy -> atomic move
$downloadSucceeded = $false
try {
    Write-Host "Downloading (HttpClient) -> $tempFile"
    $client = [System.Net.Http.HttpClient]::new()
    $stream = $client.GetStreamAsync($imgUrl).GetAwaiter().GetResult()

    # open destination temp file for writing (Create, overwrite)
    $fs = [System.IO.File]::Open($tempFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $stream.CopyTo($fs)
    } finally {
        $fs.Close()
        $stream.Close()
        $client.Dispose()
    }

    $fi = Get-Item $tempFile
    Write-Host "Downloaded bytes: $($fi.Length)"
    if ($fi.Length -gt 0) { $downloadSucceeded = $true }
}
catch {
    Write-Warning "HttpClient download failed: $($_.Exception.GetType().FullName) - $($_.Exception.Message)"
    if (Test-Path $tempFile) { Remove-Item $tempFile -ErrorAction SilentlyContinue }
}

# Fallback to Invoke-WebRequest if needed
if (-not $downloadSucceeded) {
    try {
        Write-Host "Fallback: Invoke-WebRequest -> $tempFile"
        Invoke-WebRequest -Uri $imgUrl -OutFile $tempFile -ErrorAction Stop
        $fi = Get-Item $tempFile
        Write-Host "Downloaded bytes (fallback): $($fi.Length)"
        if ($fi.Length -gt 0) { $downloadSucceeded = $true }
    }
    catch {
        Write-Error "Fallback download failed: $($_.Exception.GetType().FullName) - $($_.Exception.Message)"
        if (Test-Path $tempFile) { Remove-Item $tempFile -ErrorAction SilentlyContinue }
        return
    }
}

# Move temp -> final (atomic-ish)
if ($downloadSucceeded) {
    try {
        if (Test-Path $selectedFile) {
            try { Remove-Item $selectedFile -Force -ErrorAction Stop } catch { Write-Warning "Could not remove existing file: $($_.Exception.Message)" }
        }
        Move-Item -Path $tempFile -Destination $selectedFile -Force
        Write-Host "Saved to $selectedFile"
    }
    catch {
        Write-Error "Move to target failed: $($_.Exception.GetType().FullName) - $($_.Exception.Message)"
        if (Test-Path $tempFile) { Remove-Item $tempFile -ErrorAction SilentlyContinue }
        return
    }

    # set wallpaper
    Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

    $SPI_SETDESKWALLPAPER = 0x0014
    $UpdateIniFile = 0x01
    $SendWinIniChange = 0x02

    try {
        [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $selectedFile, $UpdateIniFile -bor $SendWinIniChange) | Out-Null
        Write-Host "✅ Wallpaper updated successfully!"
    }
    catch {
        Write-Warning "Wallpaper set failed: $($_.Exception.GetType().FullName) - $($_.Exception.Message)"
    }
}
