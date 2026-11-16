<#
.SYNOPSIS
    Upload release baru aplikasi POS ke GitHub Releases (bayufrd/updater-app-pos).

.EXAMPLE
    .\publish-release.ps1 -Version 1.3.1.2 -ZipPath "C:\path\ke\update.zip" -Notes "Perbaikan cetak struk"

.EXAMPLE
    .\publish-release.ps1 -Version 1.3.1.2 -NotesFile ".\RELEASE_NOTES.md" -Mandatory
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$ZipPath = (Join-Path $PSScriptRoot "update.zip"),

    [string]$NotesFile = "",

    [string]$Notes = "",

    [switch]$Mandatory,

    [switch]$NotSupportedRollback,

    [string]$Repo = "bayufrd/updater-app-pos"
)

$ErrorActionPreference = "Stop"

function Resolve-GhExe {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $defaultPath = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path $defaultPath) { return $defaultPath }
    throw "GitHub CLI (gh) tidak ditemukan. Install via: winget install GitHub.cli"
}

$gh = Resolve-GhExe

# Pastikan sudah login
& $gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Belum login ke GitHub CLI. Jalankan terlebih dahulu: gh auth login"
}

# Normalisasi versi & tag (1.3.1.2 -> v1.3.1.2)
$cleanVersion = $Version.Trim().TrimStart("v", "V")
if ($cleanVersion -notmatch '^\d+\.\d+\.\d+\.\d+$') {
    throw "Format versi tidak valid: '$Version'. Gunakan format 4 digit, misalnya 1.3.1.2"
}
$tag = "v$cleanVersion"

if (-not (Test-Path $ZipPath)) {
    throw "File zip tidak ditemukan: $ZipPath"
}

$zipItem = Get-Item $ZipPath
if ($zipItem.Length -lt 1024) {
    throw "File zip terlalu kecil / korup ($($zipItem.Length) bytes): $ZipPath"
}

# Cek apakah tag/release sudah ada
& $gh release view $tag --repo $Repo *> $null
if ($LASTEXITCODE -eq 0) {
    throw "Release $tag sudah ada di $Repo. Gunakan nomor versi baru atau hapus release lama terlebih dahulu."
}

# Siapkan release notes + metadata JSON untuk gaspol-api
$notesContent = ""
if (-not [string]::IsNullOrWhiteSpace($NotesFile)) {
    if (-not (Test-Path $NotesFile)) {
        throw "File notes tidak ditemukan: $NotesFile"
    }
    $notesContent = Get-Content -Path $NotesFile -Raw -Encoding UTF8
} elseif (-not [string]::IsNullOrWhiteSpace($Notes)) {
    $notesContent = $Notes
} else {
    $notesContent = "### Perubahan:`n- Release aplikasi POS versi $cleanVersion"
}

$rollbackAllowed = (-not $NotSupportedRollback.IsPresent)
$metaJson = @{
    mandatory        = [bool]$Mandatory.IsPresent
    rollback_allowed = $rollbackAllowed
} | ConvertTo-Json -Compress

if ($notesContent -notmatch 'release-meta:') {
    $notesContent = $notesContent.TrimEnd() + "`n`n<!-- release-meta: $metaJson -->`n"
}

$tempNotes = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($tempNotes, $notesContent, [System.Text.UTF8Encoding]::new($false))

    Write-Host "Uploading $tag ($($zipItem.Name), $([math]::Round($zipItem.Length / 1MB, 2)) MB) ke $Repo..." -ForegroundColor Cyan
    & $gh release create $tag $zipItem.FullName --repo $Repo --title $tag --notes-file $tempNotes
    if ($LASTEXITCODE -ne 0) {
        throw "Gagal membuat release $tag di GitHub."
    }

    Write-Host "Selesai! Release $tag berhasil dipublikasikan." -ForegroundColor Green
    Write-Host "Link: https://github.com/$Repo/releases/tag/$tag" -ForegroundColor Green
}
finally {
    if (Test-Path $tempNotes) {
        Remove-Item $tempNotes -Force -ErrorAction SilentlyContinue
    }
}
