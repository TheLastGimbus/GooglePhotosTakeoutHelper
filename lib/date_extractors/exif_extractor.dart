import "dart:io";
import "dart:math";
import 'dart:typed_data';

import "package:exif/exif.dart";
import "../utils.dart";
import "package:mime/mime.dart";
import "package:image/image.dart" as img;
import "package:logging/logging.dart";

final Logger _logger = Logger("ExifExtractor");

DateTime? extractDateFromExif(final File file) {
  try {
    final Uint8List bytes = file.readAsBytesSync();
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      _logger.warning("Unsupported image format: ${file.path}");
      return null;
    }
    final exifDate = image.exif.dateTimeOriginal;
    return exifDate ?? file.lastModifiedSync();
  } catch (e) {
    _logger.warning("EXIF extraction failed for ${file.path}: $e");
    return null;
  }
}

/// DateTime from exif data *potentially* hidden within a [file]
///
/// You can try this with *any* file, it either works or not 🤷
Future<DateTime?> exifExtractor(final File file) async {
  // if file is not image or >32MiB - DO NOT crash :D
  if (!(lookupMimeType(file.path)?.startsWith("image/") ?? false) ||
      await file.length() > maxFileSize) {
    return null;
  }
  // NOTE: reading whole file may seem slower than using readExifFromFile
  // but while testing it was actually 2x faster on my pc 0_o
  // i have nvme + btrfs, but still, will leave as is
  final Uint8List bytes = await file.readAsBytes();
  // this returns empty {} if file doesn't have exif so don't worry
  Map<String, IfdTag> tags;
  try {
    tags = await readExifFromBytes(bytes);
  } catch (e) {
    _logger.warning("Failed to read EXIF data from ${file.path}: $e");
    return null;
  }
  String? datetime;
  // try if any of these exists
  datetime ??= tags["Image DateTime"]?.printable;
  datetime ??= tags["EXIF DateTimeOriginal"]?.printable;
  datetime ??= tags["EXIF DateTimeDigitized"]?.printable;
  if (datetime == null) return null;
  // replace all shitty separators that are sometimes met
  datetime = datetime
      .replaceAll("-", ":")
      .replaceAll("/", ":")
      .replaceAll(".", ":")
      .replaceAll("\", ":")
      .replaceAll(": ", ":0");
  if (datetime.length < 19) {
    _logger.warning("Invalid EXIF datetime format in ${file.path}: $datetime");
    return null;
  }
  datetime = datetime
      .substring(0, min(datetime.length, 19))
      .replaceFirst(":", "-") // replace two : year/month to comply with iso
      .replaceFirst(":", "-");
  // now date is like: "1999-06-23 23:55"
  return DateTime.tryParse(datetime);
}