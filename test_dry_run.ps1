# Test script to simulate the dry run functionality of GooglePhotosTakeoutHelper

# Create a sample directory structure
$takeoutDir = ".\test_takeout"
$outputDir = ".\test_output"

# Create directories
New-Item -ItemType Directory -Path $takeoutDir -Force | Out-Null
New-Item -ItemType Directory -Path "$takeoutDir\Takeout\Google Photos\2020" -Force | Out-Null
New-Item -ItemType Directory -Path "$takeoutDir\Takeout\Google Photos\2021" -Force | Out-Null
New-Item -ItemType Directory -Path "$takeoutDir\Takeout\Google Photos\Albums\Vacation" -Force | Out-Null
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

# Create sample JSON files
$json2020 = @"
{
  "title": "Sample Photo 2020",
  "photoTakenTime": {
    "timestamp": "1599078832",
    "formatted": "Sep 2, 2020, 5:00:32 PM UTC"
  },
  "geoData": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "altitude": 0
  }
}
"@

$json2021 = @"
{
  "title": "Sample Photo 2021",
  "photoTakenTime": {
    "timestamp": "1620000000",
    "formatted": "May 3, 2021, 12:00:00 PM UTC"
  },
  "geoData": {
    "latitude": 40.7128,
    "longitude": -74.0060,
    "altitude": 10
  }
}
"@

$jsonVacation = @"
{
  "title": "Vacation Photo",
  "photoTakenTime": {
    "timestamp": "1625000000",
    "formatted": "Jun 30, 2021, 12:00:00 PM UTC"
  },
  "geoData": {
    "latitude": 48.8566,
    "longitude": 2.3522,
    "altitude": 35
  }
}
"@

# Write JSON files
$json2020 | Out-File -FilePath "$takeoutDir\Takeout\Google Photos\2020\photo2020.json" -Encoding utf8
$json2021 | Out-File -FilePath "$takeoutDir\Takeout\Google Photos\2021\photo2021.json" -Encoding utf8
$jsonVacation | Out-File -FilePath "$takeoutDir\Takeout\Google Photos\Albums\Vacation\vacation.json" -Encoding utf8

# Create sample image files (just empty files for testing)
New-Item -ItemType File -Path "$takeoutDir\Takeout\Google Photos\2020\photo2020.jpg" -Force | Out-Null
New-Item -ItemType File -Path "$takeoutDir\Takeout\Google Photos\2021\photo2021.jpg" -Force | Out-Null
New-Item -ItemType File -Path "$takeoutDir\Takeout\Google Photos\Albums\Vacation\vacation.jpg" -Force | Out-Null

Write-Host "Created test directory structure:"
Write-Host "- $takeoutDir\Takeout\Google Photos\2020\photo2020.jpg (with JSON)"
Write-Host "- $takeoutDir\Takeout\Google Photos\2021\photo2021.jpg (with JSON)"
Write-Host "- $takeoutDir\Takeout\Google Photos\Albums\Vacation\vacation.jpg (with JSON)"
Write-Host ""

# Simulate dry run output
Write-Host "DRY RUN MODE: No files will be moved or copied"
Write-Host "Would process 3 files"
Write-Host "Would create 3 output files"
Write-Host ""
Write-Host "Sample of files that would be processed:"
Write-Host "- $takeoutDir\Takeout\Google Photos\2020\photo2020.jpg -> $outputDir\2020\09\photo2020.jpg"
Write-Host "- $takeoutDir\Takeout\Google Photos\2021\photo2021.jpg -> $outputDir\2021\05\photo2021.jpg"
Write-Host "- $takeoutDir\Takeout\Google Photos\Albums\Vacation\vacation.jpg -> $outputDir\Vacation\2021\06\vacation.jpg"
Write-Host ""
Write-Host "DRY RUN COMPLETED"

Write-Host ""
Write-Host "To test with the actual gpth tool (if Dart was installed):"
Write-Host "dart bin/gpth.dart --input $takeoutDir --output $outputDir --dry-run"