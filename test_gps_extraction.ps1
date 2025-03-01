# Test script to simulate the GPS data extraction functionality of GooglePhotosTakeoutHelper

# Function to extract GPS data from JSON
function Extract-GpsData {
    param (
        [string]$JsonFilePath
    )

    $jsonContent = Get-Content $JsonFilePath -Raw | ConvertFrom-Json

    # Try to extract GPS data from different possible locations
    $geoData = $null

    if ($jsonContent.geoData) {
        $geoData = $jsonContent.geoData
    }
    elseif ($jsonContent.geoDataExif) {
        $geoData = $jsonContent.geoDataExif
    }
    elseif ($jsonContent.photoTakenLocation) {
        $geoData = $jsonContent.photoTakenLocation
    }
    elseif ($jsonContent.location) {
        $geoData = $jsonContent.location
    }
    elseif ($jsonContent.googleMapsData -and $jsonContent.googleMapsData.coordinates) {
        $geoData = $jsonContent.googleMapsData.coordinates
    }

    if ($geoData) {
        $latitude = $null
        $longitude = $null
        $altitude = $null

        # Try different property names for latitude
        if ($geoData.latitude -ne $null) {
            $latitude = $geoData.latitude
        }
        elseif ($geoData.lat -ne $null) {
            $latitude = $geoData.lat
        }
        elseif ($geoData.latitudeSpan -ne $null) {
            $latitude = $geoData.latitudeSpan
        }

        # Try different property names for longitude
        if ($geoData.longitude -ne $null) {
            $longitude = $geoData.longitude
        }
        elseif ($geoData.lng -ne $null) {
            $longitude = $geoData.lng
        }
        elseif ($geoData.longitudeSpan -ne $null) {
            $longitude = $geoData.longitudeSpan
        }

        # Try different property names for altitude
        if ($geoData.altitude -ne $null) {
            $altitude = $geoData.altitude
        }
        elseif ($geoData.alt -ne $null) {
            $altitude = $geoData.alt
        }
        elseif ($geoData.elevation -ne $null) {
            $altitude = $geoData.elevation
        }

        return @{
            Latitude  = $latitude
            Longitude = $longitude
            Altitude  = $altitude
        }
    }

    return $null
}

# Test with the sample files created by test_dry_run.ps1
$jsonFiles = @(
    ".\test_takeout\Takeout\Google Photos\2020\photo2020.json",
    ".\test_takeout\Takeout\Google Photos\2021\photo2021.json",
    ".\test_takeout\Takeout\Google Photos\Albums\Vacation\vacation.json"
)

Write-Host "Testing GPS data extraction from JSON files:"
Write-Host ""

foreach ($jsonFile in $jsonFiles) {
    Write-Host "Processing $jsonFile..."
    $gpsData = Extract-GpsData -JsonFilePath $jsonFile

    if ($gpsData) {
        Write-Host "  GPS data found:"
        Write-Host "  - Latitude: $($gpsData.Latitude)"
        Write-Host "  - Longitude: $($gpsData.Longitude)"
        Write-Host "  - Altitude: $($gpsData.Altitude)"
    }
    else {
        Write-Host "  No GPS data found."
    }
    Write-Host ""
}

Write-Host "GPS data extraction test completed."
Write-Host ""
Write-Host "To test with the actual gpth tool (if Dart was installed):"
Write-Host "dart bin/gpth.dart --input .\test_takeout --write-exif"