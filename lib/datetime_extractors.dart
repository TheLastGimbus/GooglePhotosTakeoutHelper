import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:exif/exif.dart';
import 'package:path/path.dart' as p;

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

// These are thanks to @hheimbuerger <3
final _commonDatetimePatterns = [
  // example: Screenshot_20190919-053857_Camera-edited.jpg
  [
    RegExp(
        r'(?<date>20\d{2}(01|02|03|04|05|06|07|08|09|10|11|12)[0-3]\d-\d{6})'),
    'YYYYMMDD-hhmmss'
  ],
  // example: IMG_20190509_154733-edited.jpg, MVIMG_20190215_193501.MP4, IMG_20190221_112112042_BURST000_COVER_TOP.MP4
  [
    RegExp(
        r'(?<date>20\d{2}(01|02|03|04|05|06|07|08|09|10|11|12)[0-3]\d_\d{6})'),
    'YYYYMMDD_hhmmss',
  ],
  // example: Screenshot_2019-04-16-11-19-37-232_com.google.a.jpg
  [
    RegExp(
        r'(?<date>20\d{2}-(01|02|03|04|05|06|07|08|09|10|11|12)-[0-3]\d-\d{2}-?\d{2}-?\d{2})'),
    'YYYY-MM-DD-hh-mm-ss',
  ],
];

Future<DateTime?> guessExtractor(File file) async {
  for (final pat in _commonDatetimePatterns) {
    // extract date str with regex
    final match = (pat.first as RegExp).firstMatch(p.basename(file.path));
    final dateStr = match?.group(0);
    if (dateStr == null) continue;
    // parse it with given pattern
    final date = FixedDateTimeFormatter(pat.last as String, isUtc: false)
        .tryDecode(dateStr);
    if (date == null) continue;
    return date; // success!
  }
  return null; // none matched
}
