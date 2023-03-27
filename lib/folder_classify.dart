/// This file contains utils for determining type of a folder
/// Whether it's a legendary "year folder", album, trash, etc
import 'dart:io';

import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

bool isYearFolder(Directory dir) =>
    RegExp(r'^Photos from (20|19|18)\d{2}$').hasMatch(p.basename(dir.path));

Future<bool> isAlbumFolder(Directory dir) =>
    dir.parent.list().whereType<Directory>().any((e) => isYearFolder(e));
