import 'dart:async';
import 'dart:io';

import 'package:file_picker_desktop/file_picker_desktop.dart';
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
    error('Duh, something went wrong with selecting - try again or extract '
        'all your zips manually, and use this script with cli options - '
        'sorry for inconvenience!');
    exit(69);
  }
  if (files.count == 0) {
    error('No files selected - try again :/ exitting for now...');
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
