import 'package:collection/collection.dart';
import 'package:gpth/media.dart';
import 'package:path/path.dart' as p;

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
  // group by albums as we will merge those later
  final byAlbum = media.groupListsBy((e) => e.albums?.first);
  for (final album in byAlbum.values) {
    // group files by size
    final bySize = album.groupListsBy((e) => e.size);
    for (final sameSize in bySize.values) {
      // skip if it's a single one
      if (sameSize.length <= 1) continue;
      // ...calculate their full hashes and group by them
      final byHash = sameSize.groupListsBy((e) => e.hash);
      for (final sameHash in byHash.values) {
        // if *now* has any >1 then they must be duplicates
        if (sameHash.length <= 1) continue;
        // sort by best date extraction, then file name length
        // using strings to sort by two values is a sneaky trick i learned at
        // https://stackoverflow.com/questions/55920677/how-to-sort-a-list-based-on-two-values

        // note: we are comparing accurracy here tho we do know that *all*
        // of them have it null - i'm leaving this just for sake
        sameHash.sort((a, b) =>
            '${a.dateTakenAccuracy ?? 999}${p.basename(a.file.path).length}'
                .compareTo(
                    '${b.dateTakenAccuracy ?? 999}${p.basename(b.file.path).length}'));
        // get list of all except first
        for (final e in sameHash.sublist(1)) {
          // remove them from media
          media.remove(e);
          count++;
        }
      }
    }
  }

  return count;
}
