# Claude Code status line script (Windows)
# Reads JSON from stdin and prints a colored status line with usage % and reset countdowns.

$input_data = $null
try {
    $raw = [Console]::In.ReadToEnd()
    $input_data = $raw | ConvertFrom-Json
} catch {
    exit 0
}
if ($null -eq $input_data) { exit 0 }

$ESC = [char]27
$RESET = "$ESC[0m"
$DIM   = "$ESC[38;2;144;144;144m"
$SEP   = "$DIM | $RESET"

function PctColor($pct) {
    if ($pct -ge 80) { "$ESC[31m" }      # red
    elseif ($pct -ge 50) { "$ESC[33m" }  # yellow
    else { "$ESC[32m" }                  # green
}

function FormatDuration([int]$seconds) {
    if ($seconds -le 0) { return $null }
    $days  = [math]::Floor($seconds / 86400)
    $hours = [math]::Floor(($seconds % 86400) / 3600)
    $mins  = [math]::Floor(($seconds % 3600) / 60)
    if ($days  -gt 0) { return "${days}d${hours}h" }
    if ($hours -gt 0) { return "${hours}h${mins}m" }
    return "${mins}m"
}

$now = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$parts = [System.Collections.Generic.List[string]]::new()

# Model — shorten "Opus 4.7 (1M context)" → "Opus 4.7 1M"
$model = $input_data.model.display_name
if (![string]::IsNullOrWhiteSpace($model)) {
    $short = ($model -replace '\((\d+\w?) context\)', '$1') -replace '\s+', ' '
    $parts.Add("$DIM[$short]$RESET")
}

# Rate-limit windows
foreach ($w in @(
    @{ Label = "5h"; Base = $input_data.rate_limits.five_hour },
    @{ Label = "7d"; Base = $input_data.rate_limits.seven_day }
)) {
    $base = $w.Base
    if ($null -eq $base -or $null -eq $base.used_percentage) { continue }
    $pct = [math]::Round($base.used_percentage)
    $color = PctColor $pct
    $seg = "$($w.Label): $color$pct%$RESET"
    if ($null -ne $base.resets_at) {
        $left = FormatDuration ([int]$base.resets_at - $now)
        if ($left) { $seg += " $DIM($left)$RESET" }
    }
    $parts.Add($seg)
}

# Context window
$ctx = $input_data.context_window.used_percentage
if ($null -ne $ctx) {
    $pct = [math]::Round($ctx)
    $parts.Add("ctx: $(PctColor $pct)$pct%$RESET")
}

# Session cost
$cost = $input_data.cost.total_cost_usd
if ($null -ne $cost) {
    $parts.Add("$DIM$('${0:F2}' -f [double]$cost)$RESET")
}

if ($parts.Count -gt 0) {
    Write-Output ($parts -join $SEP)
}
