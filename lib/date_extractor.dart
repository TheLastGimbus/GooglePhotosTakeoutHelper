import 'dart:io';

export 'date_extractors/exif_extractor.dart';
export 'date_extractors/guess_extractor.dart';
export 'date_extractors/json_extractor.dart';

typedef DateTimeExtractor = Future<DateTime?> Function(File);
