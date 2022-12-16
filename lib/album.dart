import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gpth/utils.dart';
import 'package:path/path.dart';

import 'media.dart';

class Album {
  final String title;
  final List<Media> media;

  const Album(this.title, this.media);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Album &&
        other.title == title &&
        const ListEquality().equals(other.media, media);
  }

  @override
  int get hashCode => title.hashCode ^ const ListEquality().hash(media);

  @override
  String toString() {
    return 'Album($title, $media)';
  }
}

List<Album> findAlbums(List<Directory> albumFolders, List<Media> allMedia) {
  final albums = <Album>[];
  for (final dir in albumFolders) {
    final album = Album(basename(dir.path), []);
    final media = allMedia.toList(); // .copy()
    // add all media from this albumFolder
    for (final f in dir.listSync().wherePhotoVideo()) {
      media.add(Media(f, dateTakenAccuracy: -1));
    }
    // we'll effectively do the same as duplicates
    final bySize = media.groupListsBy((e) => e.size);
    for (final size in bySize.keys) {
      // if have any >1 with same size
      if (bySize[size]!.length > 1) {
        // ...calculate their full hashes and group by them
        final byHash = bySize[size]!.groupListsBy((e) => e.hash);
        for (final hash in byHash.keys) {
          // if *now* has any >1 then they must be ~duplicates~ in album
          if (byHash[hash]!.length > 1) {
            // find best date extraction
            // if dateTakenAccuracy is null, use [q] (that highest now)
            byHash[hash]!.sort((a, b) => (a.dateTakenAccuracy ?? 999)
                .compareTo((b.dateTakenAccuracy ?? 999)));
            // first one will be from album, second it the best one from media
            album.media.add(byHash[hash]![1]);
          }
        }
      }
    }
    albums.add(album);
  }
  return albums;
}
