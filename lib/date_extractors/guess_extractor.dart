import "dart:io";

import "package:convert/convert.dart";
import "package:path/path.dart" as p;
import "package:logging/logging.dart";

final Logger _logger = Logger("GuessExtractor");

// These are thanks to @hheimbuerger <3
final List<List<Pattern>> _commonDatetimePatterns = <List<Pattern>>[
  // example: Screenshot_20190919-053857_Camera-edited.jpg
  <Pattern>[
    RegExp(
        r"(?<date>(20|19|18)\d{2}(01|02|03|04|05|06|07|08|09|10|11|12)[0-3]\d-\d{6})"),
    "yyyyMMdd-HHmmss"
  ],
  // example: IMG_20190509_154733-edited.jpg, MVIMG_20190215_193501.MP4, IMG_20190221_112112042_BURST000_COVER_TOP.MP4
  <Pattern>[
    RegExp(
        r"(?<date>(20|19|18)\d{2}(01|02|03|04|05|06|07|08|09|10|11|12)[0-3]\d_\d{6})"),
    "yyyyMMdd_HHmmss",
  ],
  // example: Screenshot_2019-04-16-11-19-37-232_com.google.a.jpg
  <Pattern>[
    RegExp(
        r"(?<date>(20|19|18)\d{2}-(01|02|03|04|05|06|07|08|09|10|11|12)-[0-3]\d-\d{2}-\d{2}-\d{2})"),
    "yyyy-MM-dd-HH-mm-ss",
  ],
  // example: signal-2020-10-26-163832.jpg
  <Pattern>[
    RegExp(
        r"(?<date>(20|19|18)\d{2}-(01|02|03|04|05|06|07|08|09|10|11|12)-[0-3]\d-\d{6})"),
    "yyyy-MM-dd-HHmmss",
  ],
  // Those two are thanks to @matt-boris <3
  // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/commit/e0d9ee3e71def69d74eba7cf5ec204672924726d
  // example: 00004XTR_00004_BURST20190216172030.jpg, 201801261147521000.jpg, IMG_1_BURST20160520195318.jpg
  <Pattern>[
    RegExp(
        r"(?<date>(20|19|18)\d{2}(01|02|03|04|05|06|07|08|09|10|11|12)[0-3]\d{7})"),
    "yyyyMMddHHmmss",
  ],
  // example: 2016_01_30_11_49_15.mp4
  <Pattern>[
    RegExp(
        r"(?<date>(20|19|18)\d{2}_(01|02|03|04|05|06|07|08|09|10|11|12)_[0-3]\d_\d{2}_\d{2}_\d{2})"),
    "yyyy_MM_dd_HH_mm_ss",
  ],
];

final RegExp _dateRegex = RegExp(
    // Match YYYY-MM-DD or YYYYMMDD followed by optional separator and HHMMSS
    // More robust pattern that handles various date formats
    r"(20\d{2}|19\d{2})[-_]?([0-1]\d)[-_]?([0-3]\d)(?:[-_]?([0-2]\d)[-_]?([0-5]\d)[-_]?([0-5]\d))?");

DateTime? guessDateFromFilename(final String filename) {
  final RegExpMatch? match = _dateRegex.firstMatch(filename);
  if (match == null) return null;

  try {
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);

    // Validate date components
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      _logger.fine("Invalid date components in filename: $filename");
      return null;
    }

    // Check if time components exist
    if (match.group(4) != null &&
        match.group(5) != null &&
        match.group(6) != null) {
      final int hour = int.parse(match.group(4)!);
      final int minute = int.parse(match.group(5)!);
      final int second = int.parse(match.group(6)!);

      // Validate time components
      if (hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59 ||
          second < 0 ||
          second > 59) {
        _logger.fine("Invalid time components in filename: $filename");
        return null;
      }

      return DateTime(year, month, day, hour, minute, second);
    }

    // If no time components, use midnight
    return DateTime(year, month, day);
  } catch (e) {
    _logger.warning("Failed to parse date from filename: $filename - $e");
    return null;
  }
}

/// Guesses DateTime from [file]s name
/// - for example Screenshot_20190919-053857.jpg - we can guess this 😎
Future<DateTime?> guessExtractor(final File file) async {
  final DateTime? guessedDate = guessDateFromFilename(p.basename(file.path));
  if (guessedDate != null) return guessedDate;

  for (final List<Pattern> pat in _commonDatetimePatterns) {
    // extract date str with regex
    final RegExpMatch? match =
        (pat.first as RegExp).firstMatch(p.basename(file.path));
    final String? dateStr = match?.group(0);
    if (dateStr == null) continue;
    // parse it with given pattern
    DateTime? date;
    try {
      date = FixedDateTimeFormatter(pat.last as String, isUtc: false)
          .tryDecode(dateStr);
    } on RangeError catch (_) {}
    if (date == null) continue;
    return date; // success!
  }
  return null; // none matched
}
