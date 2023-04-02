import 'package:path/path.dart' as p;

import 'media.dart';

const _extraFormats = [
  // EN/US - thanks @DalenW
  '-edited',
  '-effects',
  '-smile',
  '-mix',
  // PL
  '-edytowane',
  // DE - thanks @cintx
  '-bearbeitet',
  // NL - thanks @jaapp
  '-bewerkt',
  // JA - thanks @fossamagna
  '-編集済み',
  // IT - thanks @rgstori
  '-modificato',
  // FR - for @palijn's problems <3
  '-modifié',
  // Add more "edited" flags in more languages if you want.
  // They need to be lowercase.
];

/// Removes any media that match any of "extra" formats
/// Returns count of removed
int removeExtras(List<Media> media) {
  final copy = media.toList();
  var count = 0;
  for (final m in copy) {
    final name = p.withoutExtension(p.basename(m.firstFile.path)).toLowerCase();
    for (final extra in _extraFormats) {
      if (name.endsWith(extra)) {
        media.remove(m);
        count++;
        break;
      }
    }
  }
  return count;
}
