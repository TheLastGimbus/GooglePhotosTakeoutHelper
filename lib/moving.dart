import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gpth/interactive.dart' as interactive;
import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

import 'media.dart';

File findNotExistingName(File initialFile) {
  var file = initialFile;
  while (file.existsSync()) {
    file = File('${p.withoutExtension(file.path)}(1)${p.extension(file.path)}');
  }
  return file;
}

Future<File> createShortcut(Directory location, File target) async {
  final name = '${p.basename(target.path)}${Platform.isWindows ? '.lnk' : ''}';
  final link = findNotExistingName(File(p.join(location.path, name)));
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

Stream<int> moveFiles(
  List<Media> allMediaFinal,
  Directory output, {
  required bool copy,
  required bool divideToDates,
  required String albumBehavior,
}) async* {
  assert(interactive.albumOptions.keys.contains(albumBehavior));

  final infoJson = <String, List<String>>{};
  var i = 0;
  for (final m in allMediaFinal) {
    File? mainFile;

    final nullFirst = albumBehavior == 'json'
        ? [MapEntry(null, m.files.values.first)]
        : m.files.entries
            .sorted((a, b) => (a.key ?? '').compareTo(b.key ?? ''));
    for (final file in nullFirst) {
      if (file.key != null && ['nothing', 'json'].contains(albumBehavior)) {
        continue;
      }
      final date = m.dateTaken;
      final folder = Directory(
        p.join(
          output.path,
          file.key?.trim() ?? 'ALL_PHOTOS',
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
      await folder.create(recursive: true);

      File? result;

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
        result = await moveFile();
        mainFile = result;
      } else if (albumBehavior == 'shortcut' && mainFile != null) {
        try {
          result = await createShortcut(folder, mainFile);
        } catch (e) {
          print('Creating shortcut for '
              '${p.basename(mainFile.path)} in ${p.basename(folder.path)} '
              'failed :(\n$e\n - copying normal file instead');
          result = await moveFile();
        }
      } else {
        result = await moveFile();
      }

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
        if (e.errorCode != 0) {
          print("WARNING: Can't set modification time on $result: $e");
        }
      } catch (e) {
        print("WARNING: Can't set modification time on $result: $e");
      }

      yield ++i;

      if (albumBehavior == 'json') {
        infoJson[p.basename(result.path)] =
            m.files.keys.whereNotNull().toList();
      }
    }
  }
  if (albumBehavior == 'json') {
    await File(p.join(output.path, 'albums-info.json'))
        .writeAsString(jsonEncode(infoJson));
  }
}
