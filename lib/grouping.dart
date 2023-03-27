/// This files contains functions for removing duplicates and detecting albums
///
/// That's because their logic looks very similar and they share code

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gpth/media.dart';
import 'package:path/path.dart' as p;

extension Group on Iterable<Media> {
  /// This groups your media into map where key is something that they share
  /// and value is the List of those media are the same
  ///
  /// Key may be "245820998bytes", where there was no other file same size
  /// (no need to calculate hash), or hash.toSting'ed where hash was calculated
  ///
  /// Groups may be 1-lenght, where element was unique, or n-lenght where there
  /// were duplicates
  Map<String, List<Media>> groupIdentical() {
    final output = <String, List<Media>>{};
    // group files by size - can't have same hash with diff size
    // ignore: unnecessary_this
    for (final sameSize in this.groupListsBy((e) => e.size).entries) {
      // just add with "...bytes" key if just one
      if (sameSize.value.length <= 1) {
        output['${sameSize.key}bytes'] = sameSize.value;
      } else {
        // ...calculate their full hashes and group by them
        output.addAll(sameSize.value.groupListsBy((e) => e.hash.toString()));
      }
    }
    return output;
  }
}

/// Removes duplicate media from list of media
///
/// This is ment to be used *early*, and it's aware of un-merged albums.
/// Meaning, it will leave duplicated files if they have different
/// [Media.albums] value
///
/// Uses file size, then sha256 hash to distinct
///
/// Returns count of removed
int removeDuplicates(List<Media> media) {
  var count = 0;
  final byAlbum = media
      // group by albums as we will merge those later
      // (to *not* compare hashes between albums)
      .groupListsBy((e) => e.files.keys.first)
      .values
      // group by hash
      .map((albumGroup) => albumGroup.groupIdentical().values);
  // we don't care about album organization now - flatten
  final Iterable<List<Media>> hashGroups = byAlbum.flattened;
  for (final group in hashGroups) {
    // sort by best date extraction, then file name length
    // using strings to sort by two values is a sneaky trick i learned at
    // https://stackoverflow.com/questions/55920677/how-to-sort-a-list-based-on-two-values

    // note: we are comparing accuracy here tho we do know that *all*
    // of them have it null - i'm leaving this just for sake
    group.sort((a, b) =>
        '${a.dateTakenAccuracy ?? 999}${p.basename(a.firstFile.path).length}'
            .compareTo(
                '${b.dateTakenAccuracy ?? 999}${p.basename(b.firstFile.path).length}'));
    // get list of all except first
    for (final e in group.sublist(1)) {
      // remove them from media
      media.remove(e);
      count++;
    }
  }

  return count;
}

String albumName(Directory albumDir) => p.basename(albumDir.path);

/// This will analyze [allMedia], find which files are hash-same, and merge
/// all of them into single [Media] object with all album names they had
void findAlbums(List<Media> allMedia) {
  for (final group in allMedia.groupIdentical().values) {
    if (group.length <= 1) continue; // then this isn't a group
    // now, we have [group] list that contains actual sauce:

    final allFiles = group.fold(
      <String?, File>{},
      (allFiles, e) => allFiles..addAll(e.files),
    );
    // sort by best date extraction
    group.sort((a, b) =>
        (a.dateTakenAccuracy ?? 999).compareTo((b.dateTakenAccuracy ?? 999)));
    // remove original dirty ones
    for (final e in group) {
      allMedia.remove(e);
    }
    // set the first (best) one complete album list
    group.first.files = allFiles;
    // add our one, precious ✨perfect✨ one
    allMedia.add(group.first);
  }
}
