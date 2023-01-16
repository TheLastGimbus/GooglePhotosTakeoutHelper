/// This file contains utils for determining type of a folder
/// Whether it's a legendary "year folder", album, trash, etc
import 'dart:convert';
import 'dart:io';

import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

bool isYearFolder(Directory dir) =>
    p.basename(dir.path).startsWith('Photos from ');

Future<bool> isAlbumFolder(Directory dir) =>
    dir.parent.list().whereType<Directory>().any((e) => isYearFolder(e));

// Those two are so complicated because their names are 🥳localized🥳
// Those silly lists are an attempt to sometimes make it faster 👍

/// Goes through all .json files in given folder, and searches whether
/// all of them have [key] key == true
///
/// You can also pass [helpNames] list - if folder is straight out named
/// one of them, it returns true right away
///
/// This is only used to detect if folder is Archive/Trash
Future<bool> _isXFolder(Directory dir, String key,
    [List<String>? helpNames]) async {
  assert(key == 'archived' || key == 'trashed');
  if (helpNames?.contains(p.basename(dir.path)) ?? false) return true;
  var one = false; // there is at least one element (every() is true with empty)
  final logic = await dir
      .list()
      .whereType<File>()
      .where((e) => e.path.endsWith('.json'))
      .every((e) {
    one = true;
    try {
      final json = jsonDecode(e.readAsStringSync());
      if (json['photoTakenTime'] != null) {
        return json[key] == true;
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }
  });
  return one && logic;
}

const _archiveNames = [
  'Archive', // EN
  'Archiwum', // PL
];

Future<bool> isArchiveFolder(Directory dir) =>
    _isXFolder(dir, 'archived', _archiveNames);

const _trashNames = [
  'Trash', // EN
  'Kosz', // PL
];

Future<bool> isTrashFolder(Directory dir) =>
    _isXFolder(dir, 'trashed', _trashNames);
