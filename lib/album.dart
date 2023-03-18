import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart';

import 'media.dart';

String albumName(Directory albumDir) => basename(albumDir.path);

/// This will analyze [allMedia], find which files are hash-same, and merge
/// all of them into single [Media] object with all album names they had
void findAlbums(List<Media> allMedia) {
  // same as with duplicates - group by size then hash
  for (final sameSize in allMedia.groupListsBy((e) => e.size).values) {
    if (sameSize.length <= 1) continue;
    final byHash = sameSize.groupListsBy((e) => e.hash);
    for (final sameHash in byHash.values) {
      if (sameHash.length <= 1) continue;
      // now, we have [sameHash] list that contains actual sauce:

      // fold all their album names to single list
      final allAlbumNames = sameHash.fold(
        <String>{},
        (allNames, e) => {...allNames, ...(e.albums ?? {})},
      );
      // sort by best date extraction
      sameHash.sort((a, b) =>
          (a.dateTakenAccuracy ?? 999).compareTo((b.dateTakenAccuracy ?? 999)));
      // remove original dirty ones
      for (final e in sameHash) {
        allMedia.remove(e);
      }
      // set the first (best) one complete album list
      sameHash.first.albums = allAlbumNames;
      // add our one, precious ✨perfect✨ one
      allMedia.add(sameHash.first);
    }
  }
}
