# Test script to simulate the interactive mode of GooglePhotosTakeoutHelper

Write-Host "GooglePhotosTakeoutHelper v3.4.3"
Write-Host "Hi there! This tool will help you to get all of your photos from Google Takeout to one nice tidy folder"
Write-Host ""
Write-Host "(If any part confuses you, read the guide on:"
Write-Host "https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper )"
Write-Host ""

Write-Host "Select the directory where you unzipped all your takeout zips"
Write-Host "(Make sure they are merged => there is only one 'Takeout' folder!)"
Write-Host "[press enter to continue]"
Read-Host

Write-Host "Selected: .\test_takeout"
Write-Host "Cool!"
Write-Host ""

Write-Host "Now, select output folder - all photos will be moved there"
Write-Host "(note: GPTH will *move* your photos - no extra space will be taken ;)"
Write-Host "[press enter to continue]"
Read-Host

Write-Host "Selected: .\test_output"
Write-Host "Cool!"
Write-Host ""

Write-Host "Do you want your photos in one big chronological folder, or divided to folders by year/month?"
Write-Host "[1] (default) - one big folder"
Write-Host "[2] - year/month folders"
Write-Host "(Type 1 or 2 or press enter for default):"
$divideChoice = Read-Host

if ($divideChoice -eq "2") {
    Write-Host "Okay, will divide to folders!"
    $divideToDates = $true
}
else {
    Write-Host "Okay, one big it is!"
    $divideToDates = $false
}
Write-Host ""

Write-Host "What should be done with albums?"
Write-Host "[0] shortcut: [Recommended] Album folders with shortcuts/symlinks to original photos. Recommended as it will take the least space, but may not be portable when moving across systems/computes/phones etc"
Write-Host "[1] duplicate-copy: Album folders with photos copied into them. This will work across all systems, but may take wayyy more space!!"
Write-Host "[2] json: Put ALL photos (including Archive and Trash) in one folder and make a .json file with info about albums. Use if you're a programmer, or just want to get everything, ignoring lack of year-folders etc."
Write-Host "[3] nothing: Just ignore them and put year-photos into one folder. WARNING: This ignores Archive/Trash !!!"
$albumChoice = Read-Host

switch ($albumChoice) {
    "0" { $albumOption = "shortcut"; Write-Host "Okay, doing: shortcut" }
    "1" { $albumOption = "duplicate-copy"; Write-Host "Okay, doing: duplicate-copy" }
    "2" { $albumOption = "json"; Write-Host "Okay, doing: json" }
    "3" { $albumOption = "nothing"; Write-Host "Okay, doing: nothing" }
    default { $albumOption = "shortcut"; Write-Host "Okay, doing: shortcut" }
}
Write-Host ""

Write-Host "Do you want to extract GPS data from JSON files?"
Write-Host "This can be useful if you want to preserve location information,"
Write-Host "but it will make processing slower for large collections."
Write-Host ""
Write-Host "1) Yes, extract GPS data (recommended)"
Write-Host "2) No, skip GPS extraction (faster)"
Write-Host ""
Write-Host "Your choice (1/2): "
$gpsChoice = Read-Host

if ($gpsChoice -eq "2") {
    Write-Host "Skipping GPS data extraction."
    $skipGps = $true
}
else {
    Write-Host "Extracting GPS data."
    $skipGps = $false
}
Write-Host ""

# Simulate processing
Write-Host "Okay, running... searching for everything in input folder..."
Write-Host "Finding duplicates..."
Write-Host ""

# Create a progress bar
function Show-Progress {
    param (
        [int]$Current,
        [int]$Total,
        [string]$Description
    )

    $percentComplete = [math]::Min(100, [math]::Floor(($Current / $Total) * 100))
    $progressBar = "[" + ("#" * [math]::Floor($percentComplete / 2.5)) + (" " * [math]::Ceiling((100 - $percentComplete) / 2.5)) + "]"

    Write-Host "`r$Description $progressBar $percentComplete% ($Current/$Total)" -NoNewline
}

# Simulate guessing dates
Write-Host "Guessing dates from files"
for ($i = 1; $i -le 3; $i++) {
    Show-Progress -Current $i -Total 3 -Description "Guessing dates from files"
    Start-Sleep -Milliseconds 500
}
Write-Host ""
Write-Host ""

# Simulate GPS extraction if not skipped
if (-not $skipGps) {
    Write-Host "Extracting GPS data from JSON files..."
    Write-Host "Extracting GPS data"
    for ($i = 1; $i -le 3; $i++) {
        Show-Progress -Current $i -Total 3 -Description "Extracting GPS data"
        Start-Sleep -Milliseconds 500
    }
    Write-Host ""
    Write-Host "GPS data extracted for 3 files"
    Write-Host ""
}
else {
    Write-Host "Skipping GPS data extraction (--skip-gps flag used)"
    Write-Host ""
}

Write-Host "Finding albums (this may take some time, dont worry :) ..."
Start-Sleep -Seconds 1
Write-Host ""

# Simulate moving files
$moveAction = if ($divideToDates) { "Moving" } else { "Copying" }
Write-Host "$moveAction photos to output folder"
for ($i = 1; $i -le 3; $i++) {
    Show-Progress -Current $i -Total 3 -Description "$moveAction photos to output folder"
    Start-Sleep -Milliseconds 500
}
Write-Host ""
Write-Host ""

# Completion message
Write-Host "=========================================="
Write-Host "DONE! FREEEEEDOOOOM!!!"
Write-Host ""
Write-Host "Last thing - I've spent *a ton* of time on this script - "
Write-Host "if I saved your time and you want to say thanks, you can send me a tip:"
Write-Host "https://www.paypal.me/TheLastGimbus"
Write-Host "https://ko-fi.com/thelastgimbus"
Write-Host "Thank you ❤"
Write-Host "=========================================="