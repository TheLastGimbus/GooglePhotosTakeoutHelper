import 'package:path/path.dart' as p;
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'media.dart';

const extraFormats = [
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
  // ES - @Sappstal report
  '-ha editado',
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
    for (final extra in extraFormats) {
      // MacOS uses NFD that doesn't work with our accents 🙃🙃
      // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/pull/247
      if (unorm.nfc(name).endsWith(extra)) {
        media.remove(m);
        count++;
        break;
      }
    }
  }
  return count;
}
