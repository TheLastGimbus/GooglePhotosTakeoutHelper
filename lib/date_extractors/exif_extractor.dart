import 'dart:io';
import 'dart:math';

import 'package:exif/exif.dart';
import 'package:gpth/utils.dart';
import 'package:mime/mime.dart';

/// DateTime from exif data *potentially* hidden within a [file]
///
/// You can try this with *any* file, it either works or not 🤷
Future<DateTime?> exifExtractor(File file) async {
  // if file is not image or >32MiB - DO NOT crash :D
  if (!(lookupMimeType(file.path)?.startsWith('image/') ?? false) ||
      await file.length() > maxFileSize) {
    return null;
  }
  // NOTE: reading whole file may seem slower than using readExifFromFile
  // but while testing it was actually 2x faster on my pc 0_o
  // i have nvme + btrfs, but still, will leave as is
  final bytes = await file.readAsBytes();
  // this returns empty {} if file doesn't have exif so don't worry
  final tags = await readExifFromBytes(bytes);
  String? datetime;
  // try if any of these exists
  datetime ??= tags['Image DateTime']?.printable;
  datetime ??= tags['EXIF DateTimeOriginal']?.printable;
  datetime ??= tags['EXIF DateTimeDigitized']?.printable;
  if (datetime == null) return null;
  // replace all shitty separators that are sometimes met
  datetime = datetime
      .replaceAll('-', ':')
      .replaceAll('/', ':')
      .replaceAll('.', ':')
      .replaceAll('\\', ':')
      .replaceAll(': ', ':0')
      .substring(0, min(datetime.length, 19))
      .replaceFirst(':', '-') // replace two : year/month to comply with iso
      .replaceFirst(':', '-');
  // now date is like: "1999-06-23 23:55"
  return DateTime.tryParse(datetime);
}
