# check_markdown_links.ps1
#
# Verifies every relative markdown link in the repo resolves.
# Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File docs\verify\check_markdown_links.ps1
#
# Exits 0 when every link resolves, 1 otherwise.

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $repoRoot
try {
    $files = @(git ls-files '*.md')
    $broken = New-Object System.Collections.Generic.List[string]
    $checked = 0

    foreach ($file in $files) {
        if (-not (Test-Path -LiteralPath $file)) { continue }
        $dir = Split-Path -Parent $file
        if ([string]::IsNullOrEmpty($dir)) { $dir = '.' }

        $text = [System.IO.File]::ReadAllText(
            (Resolve-Path -LiteralPath $file), [System.Text.Encoding]::UTF8)

        foreach ($m in [regex]::Matches($text, '\]\(([^)\s]+)\)')) {
            $target = $m.Groups[1].Value
            # strip an optional title and any anchor
            $target = ($target -split '#')[0]
            if ([string]::IsNullOrWhiteSpace($target)) { continue }
            if ($target -match '^(https?:|mailto:|ftp:|data:)') { continue }

            $checked++
            $decoded = [System.Uri]::UnescapeDataString($target)
            if ($decoded.StartsWith('/')) { $resolved = $decoded.TrimStart('/') }
            else { $resolved = Join-Path $dir $decoded }

            if (-not (Test-Path -LiteralPath $resolved)) {
                $broken.Add(("{0} -> {1}" -f $file, $target))
            }
        }
    }

    Write-Host "Checked $($files.Count) markdown files, $checked relative links."
    if ($broken.Count -eq 0) {
        Write-Host "ALL MARKDOWN LINKS RESOLVE"
        exit 0
    }
    Write-Host ""
    Write-Host "BROKEN LINKS: $($broken.Count)"
    $broken | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }
    exit 1
}
finally { Pop-Location }
