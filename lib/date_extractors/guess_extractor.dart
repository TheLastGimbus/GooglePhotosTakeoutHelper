import 'dart:io';

import 'package:convert/convert.dart';
import 'package:path/path.dart' as p;

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
