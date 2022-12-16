import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:exif/exif.dart';

typedef DateTimeExtractor = Future<DateTime?> Function(File);

Future<DateTime?> jsonExtractor(File file) async {
  final jsonFile = _jsonForFile(file);
  if (jsonFile == null) return null;
  try {
    final data = jsonDecode(jsonFile.readAsStringSync());
    final epoch = int.parse(data['photoTakenTime']['timestamp'].toString());
    return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
  } on FormatException catch (_) {
    return null;
  } on NoSuchMethodError catch (_) {
    return null;
  }
}

File? _jsonForFile(File file, [bool goDumb = true]) {
  final correspondingJson = _normalJsonForFile(file);
  if (correspondingJson.existsSync()) {
    return correspondingJson;
  } else if (goDumb) {
    final dumbJson = _dumbJsonForFile(file);
    return dumbJson.existsSync() ? dumbJson : null;
  }
  return null;
}

File _normalJsonForFile(File file) => File('${file.path}.json');

File _dumbJsonForFile(File file) =>
    File('${file.path.substring(0, file.path.length - 5)}.json');

Future<DateTime?> exifExtractor(File file) async {
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
