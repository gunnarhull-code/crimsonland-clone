# Builds rubric.html from template.html plus the two CSVs one folder up.
# Usage (PowerShell, from anywhere): .\build.ps1
# Then publish rubric.html as the artifact (Claude can do this), or open it in a browser.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$docs = Split-Path -Parent $here
$csv = (Get-Content "$docs\upgrade-rubric.csv" -Raw -Encoding UTF8) -replace "`r", ""
$ro  = (Get-Content "$docs\roster-100.csv" -Raw -Encoding UTF8) -replace "`r", ""
$html = (Get-Content "$here\template.html" -Raw -Encoding UTF8).Replace("__CSV__", $csv).Replace("__ROSTER__", $ro)
[IO.File]::WriteAllText("$here\rubric.html", $html, (New-Object Text.UTF8Encoding $false))
Write-Output "Wrote $here\rubric.html"
