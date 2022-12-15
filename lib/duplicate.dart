import 'package:collection/collection.dart';
import 'package:gpth/media.dart';

/// Removes duplicate media from list of media
/// Uses sha256 hash to distinct
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
          // find best date extraction
          // if dateTakenAccuracy is null, use [q] (that highest now)
          byHash[hash]!.sort((a, b) => (a.dateTakenAccuracy ?? 999)
              .compareTo((b.dateTakenAccuracy ?? 999)));
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
