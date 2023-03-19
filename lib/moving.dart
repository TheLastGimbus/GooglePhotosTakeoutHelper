/// This file contains logic/utils for final act of moving actual files once
/// we have everything grouped, de-duplicated and sorted

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gpth/interactive.dart' as interactive;
import 'package:path/path.dart' as p;

import 'media.dart';

/// This will add (1) add end of file name over and over until file with such
/// name doesn't exist yet. Will leave without "(1)" if is free already
File findNotExistingName(File initialFile) {
  var file = initialFile;
  while (file.existsSync()) {
    file = File('${p.withoutExtension(file.path)}(1)${p.extension(file.path)}');
  }
  return file;
}

/// This will create symlink on unix and shortcut on windoza
///
/// Uses [findNotExistingName] for safety
Future<File> createShortcut(Directory location, File target) async {
  final name = Platform.isWindows
      ? '${p.basenameWithoutExtension(target.path)}.lnk'
      : p.basename(target.path);
  final link = findNotExistingName(File(p.join(location.path, name)));
  if (Platform.isWindows) {
    throw UnimplementedError('TODO: Actually windoza');
  } else {
    return File(
        (await Link(link.path).create(p.canonicalize(target.path))).path);
  }
}

/// Big-ass logic of moving files from input to output
///
/// [allMediaFinal] should be nice, de-duplicated and album-ed etc
///
/// [copy] indicates whether to copy files or move them
///
/// [divideToDates] will divide to dates even inside albums!
///
/// [albumBehavior] must be one of [interactive.albumOptions]
///
/// Emits number of Medias that it did (starting from 1)
Stream<int> moveFiles(
  List<Media> allMediaFinal,
  Directory output, {
  required bool copy,
  required bool divideToDates,
  required String albumBehavior,
}) async* {
  assert(interactive.albumOptions.keys.contains(albumBehavior));
  var i = 0;
  for (final m in allMediaFinal) {
    // main file shortcuts will link to
    File? mainFile;
    // this will put null media first so album shortcuts can link to it
    final nullFirst =
        m.files.entries.sorted((a, b) => (a.key ?? '').compareTo(b.key ?? ''));
    // iterate over all media of file to do something about them
    // ignore non-nulls with 'ignore', copy with 'duplicate-copy',
    // symlink with 'shortcut' etc
    for (final file in nullFirst) {
      // if it's not from year folder and we're doing nothing/json, skip
      if (file.key != null && ['nothing', 'json'].contains(albumBehavior)) {
        continue;
      }
      // now on, logic is shared for nothing+null/shortcut/copy cases
      final date = m.dateTaken;
      final folder = Directory(
        p.join(
          output.path,
          file.key ?? 'ALL_PHOTOS', // album or all
          divideToDates
              ? date == null
                  ? 'date-unknown'
                  : p.join(
                      '${date.year}',
                      date.month.toString().padLeft(2, '0'),
                    )
              : '',
        ),
      );
      // now folder logic is so complex i'll just create it every time 🤷
      await folder.create(recursive: true);

      /// result file/symlink to later change modify time
      File? result;

      /// moves/copies file with safe name
      // it's here because we do this for two cases
      moveFile() async {
        final freeFile = findNotExistingName(
            File(p.join(folder.path, p.basename(file.value.path))));
        return copy
            ? await file.value.copy(freeFile.path)
            : await file.value.rename(freeFile.path);
      }

      if (file.key == null) {
        // if it's just normal "Photos from .." (null) file, just move it
        result = await moveFile();
        mainFile = result;
      } else if (albumBehavior == 'shortcut' && mainFile != null) {
        result = await createShortcut(folder, mainFile);
      } else {
        // else - if we either run duplicate-copy or main file is missing:
        // (this happens with archive/trash/weird situation)
        // just copy it
        result = await moveFile();
      }

      // Done! Now, set the date:

      var time = m.dateTaken ?? DateTime.now();
      if (Platform.isWindows && time.isBefore(DateTime(1970))) {
        print(
            'WARNING: ${m.firstFile.path} has date $time, which is before 1970 '
            '(not supported on Windows) - will be set to 1970-01-01');
        time = DateTime(1970);
      }
      await result.setLastModified(time);
    }
    // done with this media - next!
    yield ++i;
  }
}
