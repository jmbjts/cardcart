$ErrorActionPreference = "Stop"
$RepoDir = "C:\Users\Joan\Downloads\YYT SCRAPER"
$LogFile = "$RepoDir\scrape_log.txt"

function Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

Log "=== Scrape started ==="
Set-Location $RepoDir

# Pull latest from GitHub first to avoid push conflicts
Log "Pulling latest from GitHub..."
git pull --ff-only
if ($LASTEXITCODE -ne 0) { Log "ERROR: git pull failed"; exit 1 }

# Read URLs from yyt.txt, strip blank lines
$urls = @(Get-Content yyt.txt | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
Log "Scraping $($urls.Count) URLs..."

# Run the scraper
python yuyu_scraper.py --out yuyu_cards_new.csv --exact-names names_exact.csv --names names.csv $urls
if ($LASTEXITCODE -ne 0) { Log "ERROR: scraper exited with code $LASTEXITCODE"; exit 1 }

# Validate output
if (-not (Test-Path yuyu_cards_new.csv)) {
    Log "ERROR: scraper produced no output file"
    exit 1
}

$lines = (Get-Content yuyu_cards_new.csv).Count
Log "Output file has $lines lines (including header)"

if ($lines -le 1) {
    Log "No data rows found - aborting, existing CSV unchanged"
    Remove-Item -Force yuyu_cards_new.csv
    exit 1
}

# Replace live CSV
Move-Item -Force yuyu_cards_new.csv yuyu_cards_latest.csv
Log "yuyu_cards_latest.csv updated"

# Write metadata
$count  = $lines - 1
$date   = Get-Date -Format "yyyy-MM-dd"
$time   = (Get-Date).ToUniversalTime().ToString("HH:mm") + " UTC"
$meta   = "{`"updated`":`"$date`",`"time`":`"$time`",`"count`":$count}"
Set-Content meta.json -Value $meta -Encoding UTF8
Log "meta.json updated (count=$count)"

# Commit and push
git add yuyu_cards_latest.csv meta.json
git diff --staged --quiet
if ($LASTEXITCODE -eq 0) {
    Log "No changes to commit (data unchanged)"
} else {
    git -c user.name="scraper-bot" -c user.email="scraper-bot@local" commit -m "data: update cards $date"
    git push
    if ($LASTEXITCODE -ne 0) { Log "ERROR: git push failed"; exit 1 }
    Log "Pushed to GitHub successfully"
}

Log "=== Scrape complete ==="
