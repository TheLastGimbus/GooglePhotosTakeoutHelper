/// This file contains logic/utils for final act of moving actual files once
/// we have everything grouped, de-duplicated and sorted

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gpth/interactive.dart' as interactive;
import 'package:gpth/utils.dart';
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
///
/// WARN: Crashes with non-ascii names :(
Future<File> createShortcut(Directory location, File target) async {
  final name = '${p.basename(target.path)}${Platform.isWindows ? '.lnk' : ''}';
  final link = findNotExistingName(File(p.join(location.path, name)));
  // this must be relative to not break when user moves whole folder around:
  // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/232
  final targetRelativePath = p.relative(target.path, from: link.parent.path);
  if (Platform.isWindows) {
    final res = await Process.run(
      'powershell.exe',
      [
        '-ExecutionPolicy',
        'Bypass',
        '-NoLogo',
        '-NonInteractive',
        '-NoProfile',
        '-Command',
        '\$ws = New-Object -ComObject WScript.Shell; '
            '\$s = \$ws.CreateShortcut(\'${link.path}\'); '
            '\$s.TargetPath = \'$targetRelativePath\'; '
            '\$s.Save()',
      ],
    );
    if (res.exitCode != 0) {
      throw 'PowerShell doesnt work :( - '
          'report that to @TheLastGimbus on GitHub:\n\n'
          'https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues\n\n'
          '...or try other album solution\n'
          'sorry for inconvenience :(';
    }
    return File(link.path);
  } else {
    return File((await Link(link.path).create(targetRelativePath)).path);
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
/// Emits number of files that it copied/created/whatever (starting from 1) -
/// use [outputFileCount] function for progress measurement
Stream<int> moveFiles(
  List<Media> allMediaFinal,
  Directory output, {
  required bool copy,
  required bool divideToDates,
  required String albumBehavior,
}) async* {
  assert(interactive.albumOptions.keys.contains(albumBehavior));

  /// used only in 'json' behavior
  /// key = name of main outputted file | value = list of albums it belongs to
  final infoJson = <String, List<String>>{};
  var i = 0;
  for (final m in allMediaFinal) {
    // main file shortcuts will link to
    File? mainFile;

    final nullFirst = albumBehavior == 'json'
        // in 'json' case, we want to copy ALL files (like Archive) as normals
        ? [MapEntry(null, m.files.values.first)]
        // this will put null media first so album shortcuts can link to it
        : m.files.entries
            .sorted((a, b) => (a.key ?? '').compareTo(b.key ?? ''));
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
          file.key?.trim() ?? 'ALL_PHOTOS', // album or all
          date == null
              ? 'date-unknown'
              : divideToDates
                  ? p.join(
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
        try {
          return copy
              ? await file.value.copy(freeFile.path)
              : await file.value.rename(freeFile.path);
        } on FileSystemException {
          print(
            "Uh-uh, it looks like you selected other output drive than\n"
            "input one - gpth can't move files between them. But, you don't have\n"
            "to do this! Gpth *moves* files, so this doesn't take any extra space!\n"
            "Please run again and select different output location <3",
          );
          quit(1);
        }
      }

      if (file.key == null) {
        // if it's just normal "Photos from .." (null) file, just move it
        result = await moveFile();
        mainFile = result;
      } else if (albumBehavior == 'shortcut' && mainFile != null) {
        try {
          result = await createShortcut(folder, mainFile);
        } catch (e) {
          // in case powershell fails/whatever
          print('Creating shortcut for '
              '${p.basename(mainFile.path)} in ${p.basename(folder.path)} '
              'failed :(\n$e\n - copying normal file instead');
          result = await moveFile();
        }
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
      try {
        await result.setLastModified(time);
      } on OSError catch (e) {
        // Sometimes windoza throws error but successes anyway 🙃:
        // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/229#issuecomment-1685085899
        // That's why this is here
        if (e.errorCode != 0) {
          print("WARNING: Can't set modification time on $result: $e");
        }
      } catch (e) {
        print("WARNING: Can't set modification time on $result: $e");
      }

      // one copy/move/whatever - one yield
      yield ++i;

      if (albumBehavior == 'json') {
        infoJson[p.basename(result.path)] =
            m.files.keys.whereNotNull().toList();
      }
    }
    // done with this media - next!
  }
  if (albumBehavior == 'json') {
    await File(p.join(output.path, 'albums-info.json'))
        .writeAsString(jsonEncode(infoJson));
  }
}
