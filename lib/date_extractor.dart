import 'dart:io';

export 'date_extractors/exif_extractor.dart';
export 'date_extractors/guess_extractor.dart';
export 'date_extractors/json_extractor.dart';

/// A function type that takes a [File] and potentially extracts a [DateTime] from it.
typedef DateTimeExtractor = Future<DateTime?> Function(File);
