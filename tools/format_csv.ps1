# Column-aligns CSV files in place (pads each cell to its column's widest value).
# DataTables.gd strips cell whitespace, so padded files load identically.
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File tools/format_csv.ps1 docs/crimsonland-clone/weapons.csv
# The docs/ and game/data/ copies must stay identical: format one, then copy it over the other.
# Close Excel first - it locks the file.
param([string[]]$Files)
foreach ($f in $Files) {
  $rows = Import-Csv -LiteralPath $f -Encoding UTF8
  if (-not $rows) { continue }
  $cols = $rows[0].PSObject.Properties.Name
  $table = @()
  $table += ,@($cols | ForEach-Object { $_.Trim() })
  foreach ($r in $rows) {
    $line = @()
    foreach ($c in $cols) {
      $v = [string]$r.$c
      $v = $v.Trim()
      if ($v -match '[^A-Za-z0-9_.-]' -or ($c.Trim() -in @('name','description','special') -and $v -ne '')) { $v = '"' + $v.Replace('"','""') + '"' }
      $line += $v
    }
    $table += ,$line
  }
  $w = @(0) * $cols.Count
  foreach ($t in $table) { for ($i=0; $i -lt $cols.Count; $i++) { if ($t[$i].Length -gt $w[$i]) { $w[$i] = $t[$i].Length } } }
  $out = foreach ($t in $table) {
    $cells = for ($i=0; $i -lt $cols.Count; $i++) { if ($i -lt $cols.Count-1) { $t[$i].PadRight($w[$i]) } else { $t[$i] } }
    ($cells -join ',')
  }
  [IO.File]::WriteAllText((Resolve-Path $f), (($out -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
}
