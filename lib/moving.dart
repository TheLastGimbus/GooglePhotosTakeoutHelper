/// This file contains logic/utils for final act of moving actual files once
/// we have everything grouped, de-duplicated and sorted

import 'dart:io';

import 'package:path/path.dart' as p;

import 'media.dart';
import 'utils.dart';

Stream<int> moveFiles(
  List<Media> allMediaFinal,
  Directory output, {
  required bool copy,
  required bool divideToDates,
  required String albumBehavior,
}) async* {
  var i = 0;
  for (final m in allMediaFinal) {
    final date = m.dateTaken;
    // TODO: Implement albums!!!
    final folder = Directory(
      divideToDates
          ? date == null
              ? p.join(output.path, 'date-unknown')
              : p.join(
                  output.path,
                  '${date.year}',
                  date.month.toString().padLeft(2, '0'),
                )
          : output.path,
    );
    // i think checking vars like this is bit faster than calling fs every time
    if (divideToDates) {
      await folder.create(recursive: true);
    }
    final freeFile = findNotExistingName(
        File(p.join(folder.path, p.basename(m.firstFile.path))));
    // TODO: THIS .FIRSTFILE SHOULD NOT BE USED! JUST FOR TESTING!
    final c = copy
        ? await m.firstFile.copy(freeFile.path)
        : await m.firstFile.rename(freeFile.path);
    var time = m.dateTaken ?? DateTime.now();
    if (Platform.isWindows && time.isBefore(DateTime(1970))) {
      print('WARNING: ${m.firstFile.path} has date $time, which is before 1970 '
          '(not supported on Windows) - will be set to 1970-01-01');
      time = DateTime(1970);
    }
    await c.setLastModified(time);
    // on windows, there is also file creation - but it's not supported by dart
    // i tried this, and kinda works, but is extra slow :(
    // await Process.run('Powershell.exe', ['-command', '(Get-Item "${c.path}").CreationTime=("${time.toLocal().toIso8601String()}")']);
    yield i++;
  }
}
