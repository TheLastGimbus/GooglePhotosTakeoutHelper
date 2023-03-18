/// This file contains utils for determining type of a folder
/// Whether it's a legendary "year folder", album, trash, etc
import 'dart:io';

import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

bool isYearFolder(Directory dir) =>
    p.basename(dir.path).startsWith('Photos from ');

Future<bool> isAlbumFolder(Directory dir) =>
    dir.parent.list().whereType<Directory>().any((e) => isYearFolder(e));
