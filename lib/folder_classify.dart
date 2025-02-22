/// This file contains utilities for determining the type of a folder.
/// Whether it's a legendary "year folder", album, trash, etc.
import 'dart:io';

import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

/// Checks if the given directory is a "year folder".
/// A "year folder" is named in the format "Photos from YYYY".
bool isYearFolder(Directory dir) {
  final yearFolderPattern = RegExp(r'^Photos from (20|19|18)\d{2}$');
  return yearFolderPattern.hasMatch(p.basename(dir.path));
}

/// Checks if the given directory is an album folder.
/// An album folder is a directory that is a sibling of a "year folder".
Future<bool> isAlbumFolder(Directory dir) async {
  try {
    return await dir.parent
        .list()
        .whereType<Directory>()
        .any((e) => isYearFolder(e));
  } catch (e) {
    print('Error checking if directory is an album folder: $e');
    return false;
  }
}
