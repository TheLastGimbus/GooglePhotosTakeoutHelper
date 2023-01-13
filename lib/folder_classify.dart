/// This file contains utils for determining type of a folder
/// Whether it's a legendary "year folder", album, trash, etc
import 'dart:convert';
import 'dart:io';

import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

/// if json indicates that photo was put in archive folder
/// returns null if couldn't determine it (f.e. it's an album json)
bool? jsonIsArchived(String jsonString) {
  try {
    final json = jsonDecode(jsonString);
    if (json['photoTakenTime'] != null) {
      return json['archived'] == true;
    } else {
      return null;
    }
  } catch (e) {
    return null;
  }
}

/// if json indicates that photo was trashed
/// returns null if couldn't determine it (f.e. it's an album json)
bool? jsonIsTrashed(String jsonString) {
  try {
    final json = jsonDecode(jsonString);
    if (json['photoTakenTime'] != null) {
      return json['trashed'] == true;
    } else {
      return null;
    }
  } catch (e) {
    return null;
  }
}

bool isYearFolder(Directory dir) =>
    p.basename(dir.path).startsWith('Photos from ');

Future<bool> isAlbumFolder(Directory dir) =>
    dir.parent.list().whereType<Directory>().any((e) => isYearFolder(e));

// Those two are so complicated because their names are 🥳localized🥳
// Those silly lists are an attempt to sometimes make it faster 👍

const _archiveNames = [
  'Archive', // EN
  'Archiwum', // PL
];

Future<bool> isArchiveFolder(Directory dir) async {
  if (_archiveNames.contains(p.basename(dir.path))) return true;
  var one = false; // there is at least one element (every() is true with empty)
  final logic = await dir
      .list()
      .whereType<File>()
      .where((e) => e.path.endsWith('.json'))
      .every((e) {
    one = true;
    final a = jsonIsArchived(e.readAsStringSync());
    return a != null && a;
  });
  return one && logic;
}

const _trashNames = [
  'Trash', // EN
  'Kosz', // PL
];

Future<bool> isTrashFolder(Directory dir) async {
  if (_trashNames.contains(p.basename(dir.path))) return true;
  var one = false; // there is at least one element (every() is true with empty)
  final logic = await dir
      .list()
      .whereType<File>()
      .where((e) => e.path.endsWith('.json'))
      .every((e) {
    one = true;
    final t = jsonIsTrashed(e.readAsStringSync());
    return t != null && t;
  });
  return one && logic;
}
