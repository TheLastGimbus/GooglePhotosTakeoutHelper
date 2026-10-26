/// This file contains utils for determining type of a folder
/// Whether it's a legendary "year folder", album, trash, etc
import 'dart:io';

import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

// \s also matches non-breaking and other Unicode spaces, which some
// Takeout exports use between "from" and the year (#473)
bool isYearFolder(Directory dir) =>
    RegExp(r'^Photos from\s(20|19|18)\d{2}$').hasMatch(p.basename(dir.path));

Future<bool> isAlbumFolder(Directory dir) =>
    dir.parent.list().whereType<Directory>().any((e) => isYearFolder(e));
