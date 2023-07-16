import 'dart:io';
import 'package:gpth/date_extractors/json_extractor.dart';
import "package:path/path.dart" as p;

/// Finds corresponding json file with info and gets 'photoTakenTime' from it
Future<DateTime?> heicVideoExtractor(File file, {bool tryhard = false}) async {
  final fileNameWithoutExtension = p.basenameWithoutExtension(file.path);

  if (fileNameWithoutExtension.startsWith("IMG") &&
      p.extension(file.path).toLowerCase() == ".mp4") {
    final String parentPath = file.parent.path;
    // Is a valid iOS Live Photo video
    return tryGetDateTimeFromPossibleFileExtensions(
        parentPath, fileNameWithoutExtension);
  }

  return null;
}

Future<DateTime?> tryGetDateTimeFromPossibleFileExtensions(
    String parentPath, String fileNameWithoutExtension,
    {bool tryhard = false}) async {
  final possibleFileExtensions = <String>[
    "HEIC",
    "heic",
    "JPG",
    "jpg",
    "JPEG",
    "jpeg"
  ];

  for (final fileExtension in possibleFileExtensions) {
    final String possiblePhotoPath =
        p.join(parentPath, "$fileNameWithoutExtension.$fileExtension");
    final result =
        await jsonExtractor(File(possiblePhotoPath), tryhard: tryhard);

    if (result != null) {
      return result;
    }
  }

  return null;
}
