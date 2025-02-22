/// This file contains functions for removing duplicates and detecting albums.
/// The logic for these functions is very similar and they share code.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gpth/media.dart';
import 'package:path/path.dart' as p;

extension Group on Iterable<Media> {
  /// Groups your media into a map where the key is something that they share
  /// and the value is the list of those media that are the same.
  ///
  /// The key may be "245820998bytes", where there was no other file of the same size
  /// (no need to calculate hash), or hash.toString'ed where the hash was calculated.
  ///
  /// Groups may be 1-length, where the element was unique, or n-length where there
  /// were duplicates.
  Map<String, List<Media>> groupIdentical() {
    final output = <String, List<Media>>{};
    // Group files by size - can't have the same hash with different sizes
    for (final sameSize in groupListsBy((e) => e.size).entries) {
      // Just add with "...bytes" key if there's only one
      if (sameSize.value.length <= 1) {
        output['${sameSize.key}bytes'] = sameSize.value;
      } else {
        // Calculate their full hashes and group by them
        output.addAll(sameSize.value.groupListsBy((e) => e.hash.toString()));
      }
    }
    return output;
  }
}

/// Removes duplicate media from the list of media.
/// This is meant to be used *early*, and it's aware of un-merged albums.
/// Meaning, it will leave duplicated files if they have different
/// [Media.albums] values.
///
/// Uses file size, then sha256 hash to distinguish duplicates.
/// Returns the count of removed duplicates.
int removeDuplicates(List<Media> media) {
  var count = 0;
  final byAlbum = media
      // Group by albums as we will merge those later
      // (to *not* compare hashes between albums)
      .groupListsBy((e) => e.files.keys.first)
      .values
      // Group by hash
      .map((albumGroup) => albumGroup.groupIdentical().values);
  // We don't care about album organization now - flatten
  final Iterable<List<Media>> hashGroups = byAlbum.flattened;
  for (final group in hashGroups) {
    // Sort by best date extraction, then file name length
    // Using strings to sort by two values is a sneaky trick I learned at
    // https://stackoverflow.com/questions/55920677/how-to-sort-a-list-based-on-two-values

    // Note: we are comparing accuracy here though we do know that *all*
    // of them have it null - I'm leaving this just for the sake of completeness
    group.sort((a, b) =>
        '${a.dateTakenAccuracy ?? 999}${p.basename(a.firstFile.path).length}'
            .compareTo(
                '${b.dateTakenAccuracy ?? 999}${p.basename(b.firstFile.path).length}'));
    // Get list of all except the first
    for (final e in group.sublist(1)) {
      // Remove them from media
      media.remove(e);
      count++;
    }
  }

  return count;
}

/// Returns the name of the album from the directory.
String albumName(Directory albumDir) => p.basename(albumDir.path);

/// This will analyze [allMedia], find which files are hash-same, and merge
/// all of them into a single [Media] object with all album names they had.
void findAlbums(List<Media> allMedia) {
  for (final group in allMedia.groupIdentical().values) {
    if (group.length <= 1) continue; // Then this isn't a group
    // Now, we have [group] list that contains actual duplicates:

    final allFiles = group.fold(
      <String?, File>{},
      (allFiles, e) => allFiles..addAll(e.files),
    );
    // Sort by best date extraction
    group.sort((a, b) =>
        (a.dateTakenAccuracy ?? 999).compareTo((b.dateTakenAccuracy ?? 999)));
    // Remove original duplicates
    for (final e in group) {
      allMedia.remove(e);
    }
    // Set the first (best) one complete album list
    group.first.files = allFiles;
    // Add our one, precious ✨perfect✨ one
    allMedia.add(group.first);
  }
}
