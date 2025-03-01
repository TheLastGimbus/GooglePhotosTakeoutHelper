import "dart:io";
import "dart:math";
import 'dart:typed_data';

import "package:exif/exif.dart";
import "gps_extractor.dart";
import "utils.dart";
import "package:image/image.dart" as img;
import "package:logging/logging.dart";
import "package:mime/mime.dart";

final Logger _logger = Logger("ExifWriter");

/// Writes GPS data to the EXIF metadata of an image file
/// Returns true if successful, false otherwise
Future<bool> writeGpsToExif(final File file, final GpsData gpsData) async {
  // Check if file is an image and not too large
  if (!(lookupMimeType(file.path)?.startsWith("image/") ?? false) ||
      await file.length() > maxFileSize) {
    _logger.warning("File is not an image or too large: ${file.path}");
    return false;
  }

  try {
    // Read the image
    final Uint8List bytes = await file.readAsBytes();
    final img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      _logger.warning("Failed to decode image: ${file.path}");
      return false;
    }

    // Create EXIF data if it doesn't exist
    image.exif ??= img.ExifData();

    // Convert decimal degrees to degrees, minutes, seconds format
    final String latRef = gpsData.latitude >= 0 ? "N" : "S";
    final String lngRef = gpsData.longitude >= 0 ? "E" : "W";

    final double latAbs = gpsData.latitude.abs();
    final double lngAbs = gpsData.longitude.abs();

    final int latDeg = latAbs.floor();
    final int latMin = ((latAbs - latDeg) * 60).floor();
    final double latSec = ((latAbs - latDeg - latMin / 60) * 3600).toDouble();

    final int lngDeg = lngAbs.floor();
    final int lngMin = ((lngAbs - lngDeg) * 60).floor();
    final double lngSec = ((lngAbs - lngDeg - lngMin / 60) * 3600).toDouble();

    // Set GPS data in EXIF
    image.exif.gpsLatitudeRef = latRef;
    image.exif.gpsLatitude = <double>[
      latDeg.toDouble(),
      latMin.toDouble(),
      latSec
    ];

    image.exif.gpsLongitudeRef = lngRef;
    image.exif.gpsLongitude = <double>[
      lngDeg.toDouble(),
      lngMin.toDouble(),
      lngSec
    ];

    if (gpsData.altitude != null) {
      image.exif.gpsAltitudeRef =
          gpsData.altitude! >= 0 ? 0 : 1; // 0 = above sea level, 1 = below
      image.exif.gpsAltitude = gpsData.altitude!.abs();
    }

    // Write the image back to the file
    final Uint8List? encodedImage = img.encodeNamedImage(file.path, image);
    if (encodedImage == null) {
      _logger.warning("Failed to encode image: ${file.path}");
      return false;
    }

    await file.writeAsBytes(encodedImage);
    _logger.info("Successfully wrote GPS data to ${file.path}");
    return true;
  } catch (e) {
    _logger.severe("Error writing GPS data to ${file.path}: $e");
    return false;
  }
}

/// Writes date/time to the EXIF metadata of an image file
/// Returns true if successful, false otherwise
Future<bool> writeDateTimeToExif(
    final File file, final DateTime dateTime) async {
  // Check if file is an image and not too large
  if (!(lookupMimeType(file.path)?.startsWith("image/") ?? false) ||
      await file.length() > maxFileSize) {
    _logger.warning("File is not an image or too large: ${file.path}");
    return false;
  }

  try {
    // Read the image
    final Uint8List bytes = await file.readAsBytes();
    final img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      _logger.warning("Failed to decode image: ${file.path}");
      return false;
    }

    // Create EXIF data if it doesn't exist
    image.exif ??= img.ExifData();

    // Format the date/time string (YYYY:MM:DD HH:MM:SS)
    final String dateTimeStr =
        '${dateTime.year}:${dateTime.month.toString().padLeft(2, '0')}:${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

    // Set date/time in EXIF
    image.exif.dateTimeOriginal = dateTimeStr;
    image.exif.dateTimeDigitized = dateTimeStr;
    image.exif.dateTime = dateTimeStr;

    // Write the image back to the file
    final Uint8List? encodedImage = img.encodeNamedImage(file.path, image);
    if (encodedImage == null) {
      _logger.warning("Failed to encode image: ${file.path}");
      return false;
    }

    await file.writeAsBytes(encodedImage);
    _logger.info("Successfully wrote date/time data to ${file.path}");
    return true;
  } catch (e) {
    _logger.severe("Error writing date/time data to ${file.path}: $e");
    return false;
  }
}
