import 'dart:io';

import 'package:mime/mime.dart';

extension X on Iterable<FileSystemEntity> {
  Iterable<File> wherePhotoVideo() {
    return whereType<File>().where((e) {
      final mime = lookupMimeType(e.path) ?? "";
      return mime.startsWith('image/') || mime.startsWith('video/');
    });
  }
}
