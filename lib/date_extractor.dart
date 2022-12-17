import 'dart:io';

export 'date_extractors/exif_extractor.dart';
export 'date_extractors/guess_extractor.dart';
export 'date_extractors/json_extractor.dart';

/// Function that can take a file and potentially extract DateTime of it
typedef DateTimeExtractor = Future<DateTime?> Function(File);
