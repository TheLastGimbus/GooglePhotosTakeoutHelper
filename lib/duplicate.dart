import 'package:collection/collection.dart';
import 'package:gpth/media.dart';
import 'package:path/path.dart' as p;

/// Removes duplicate media from list of media
/// Uses file size, then sha256 hash to distinct
///
/// Returns count of removed
int removeDuplicates(List<Media> media) {
  var count = 0;
  // group files by size
  final bySize = media.groupListsBy((e) => e.size);
  for (final size in bySize.keys) {
    // if have any >1 with same size
    if (bySize[size]!.length > 1) {
      // ...calculate their full hashes and group by them
      final byHash = bySize[size]!.groupListsBy((e) => e.hash);
      for (final hash in byHash.keys) {
        // if *now* has any >1 then they must be duplicates
        if (byHash[hash]!.length > 1) {
          // sort by best date extraction, then file name length
          // using strings to sort by two values is a sneaky trick i learned at
          // https://stackoverflow.com/questions/55920677/how-to-sort-a-list-based-on-two-values
          byHash[hash]!.sort((a, b) =>
              '${a.dateTakenAccuracy ?? 999}${p.basename(a.file.path).length}'
                  .compareTo(
                      '${b.dateTakenAccuracy ?? 999}${p.basename(b.file.path).length}'));
          // get list of all except first
          for (final e in byHash[hash]!.sublist(1)) {
            // remove them from media
            media.remove(e);
            count++;
          }
        }
      }
    }
  }
  return count;
}
