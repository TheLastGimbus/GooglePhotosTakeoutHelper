import 'dart:async';
import 'dart:io';

import 'package:file_picker_desktop/file_picker_desktop.dart';
import 'package:filesize/filesize.dart';
import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

var indeed = false;
final args = <String, dynamic>{};

Future<void> greet() async {
  print('Hi there! This tool will help you to get all of your photos from '
      'Google Takeout to one nice tidy folder\n');
  print('(If any part confuses you, read the guide on:\n'
      'https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper )\n');
}

Future<List<File>> getZips() async {
  print("First, select all .zips from Google Takeout (press enter)");
  stdin.readLineSync();
  final files = await pickFiles(
    dialogTitle: 'Select all Takeout zips:',
    type: FileType.custom,
    allowedExtensions: ['zip', 'tgz'],
    allowMultiple: true,
  );
  if (files == null) {
    error('Duh, something went wrong with selecting - try again!');
    exit(69);
  }
  if (files.count == 0) {
    error('No files selected - try again :/');
    exit(6969);
  }
  if (files.count == 1) {
    print("You selected only one zip - if that's only one you have, it's cool, "
        "but if you have multiple, Ctrl-C to exit gpth, and select them "
        "*all* again (with Ctrl)");
    print('Otherwise, press enter to continue');
    stdin.readLineSync();
  }
  if (!files.files.every((e) =>
      File(e.path!).statSync().type == FileSystemEntityType.file &&
      e.path!.endsWith('.zip'))) {
    print('Files: [${files.files.map((e) => p.basename(e.path!)).join(', ')}]');
    error('Not all files you selected are zips :/ please do this again');
    exit(6969);
  }
  print('Cool!\n');
  return files.files.map((e) => File(e.path!)).toList();
}

Future<Directory> getOutput() async {
  print('Now, select output folder - all photos will be extracted there '
      '(press enter)');
  stdin.readLineSync();
  final dir = await getDirectoryPath(dialogTitle: 'Select output folder:');
  if (dir == null) {
    error('Duh, something went wrong with selecting - try again!');
    exit(69);
  }
  print('Cool!\n');
  return Directory(dir);
}

Future<void> unzip(List<File> zips, Directory dir) async {
  final cumSize = zips.map((e) => e.lengthSync()).reduce((a, b) => a + b);
  print('gpth will now unzip all of that, and then do smart stuff - note that '
      'this will use *${filesize(cumSize)}* - make sure you have that much '
      'available - otherwise, Ctrl-C to exit, unzip manually and use cmd '
      'options');
  print('Press enter to continue');
  stdin.readLineSync();
}
