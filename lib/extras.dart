import "package:path/path.dart" as p;
import "package:unorm_dart/unorm_dart.dart" as unorm;

import "media.dart";

/// List of extra formats indicating edited or modified files in various languages.
/// These need to be lowercase.
const List<String> extraFormats = <String>[
  // EN/US - thanks @DalenW
  "-edited",
  "-effects",
  "-smile",
  "-mix",
  // PL
  "-edytowane",
  // DE - thanks @cintx
  "-bearbeitet",
  // NL - thanks @jaapp
  "-bewerkt",
  // JA - thanks @fossamagna
  "-編集済み",
  // IT - thanks @rgstori
  "-modificato",
  // FR - for @palijn's problems <3
  "-modifié",
  // ES - @Sappstal report
  "-ha editado",
  "-editado",
  // CA - @Sappstal report
  "-editat",
  // PT - Portuguese
  "-editado",
  // RU - Russian
  "-отредактировано",
  // ZH - Chinese
  "-已编辑",
  // KO - Korean
  "-편집됨",
  // TR - Turkish
  "-düzenlendi",
  // AR - Arabic
  "-تم التعديل",
  // HI - Hindi
  "-संपादित",
  // VI - Vietnamese
  "-đã chỉnh sửa",
  // TH - Thai
  "-แก้ไขแล้ว",
  // ID - Indonesian
  "-diedit",
  // Add more "edited" flags in more languages if you want.
];

/// Removes any media that match any of the "extra" formats.
/// Returns the count of removed media.
int removeExtras(final List<Media> media) {
  final List<Media> copy = media.toList();
  int count = 0;
  for (final Media m in copy) {
    final String name =
        p.withoutExtension(p.basename(m.firstFile.path)).toLowerCase();
    for (final String extra in extraFormats) {
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
