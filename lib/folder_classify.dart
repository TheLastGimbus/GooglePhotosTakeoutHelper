/// This file contains utilities for determining the type of a folder.
/// Whether it's a legendary "year folder", album, trash, etc.
import "dart:io";

import "utils.dart";
import "package:path/path.dart" as p;
import "package:logging/logging.dart";

final Logger _logger = Logger("FolderClassify");

/// Checks if the given directory is a "year folder".
/// A "year folder" is named in the format "Photos from YYYY".
bool isYearFolder(final Directory dir) {
  final RegExp yearFolderPattern = RegExp(r"^Photos from (20|19|18)\d{2}$");
  return yearFolderPattern.hasMatch(p.basename(dir.path));
}

/// Checks if the given directory is an album folder.
/// An album folder is a directory that is a sibling of a "year folder".
Future<bool> isAlbumFolder(final Directory dir) async {
  try {
    return await dir.parent.list().whereType<Directory>().any(isYearFolder);
  } catch (e) {
    _logger.warning("Error checking if directory is an album folder: $e");
    return false;
  }
}
