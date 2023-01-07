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
    error('Duh, something went wrong with selecting - try again!');
    quit(69);
  }
  if (files!.count == 0) {
    error('No files selected - try again :/');
    quit(6969);
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
    quit(6969);
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
    quit(69);
  }
  print('Cool!\n');
  return Directory(dir!);
}

Future<void> unzip(List<File> zips, Directory dir) async {
  await dir.create(recursive: true);
  final cumZipsSize = zips.map((e) => e.lengthSync()).reduce((a, b) => a + b);
  // *2 because zips+unzipped, +256mb for safety
  final requiredSpace = (cumZipsSize * 2) + 256 * 1024 * 1024;
  final freeSpace = await getDiskFree(dir.path);
  print('gpth will now unzip all of that, and then do smart stuff');
  if (freeSpace == null) {
    print(
      'Note: this will use ~${filesize(requiredSpace)} - '
      'make sure you have that available on ${dir.path} - otherwise, '
      'Ctrl-C to exit, and make some free space!\n'
      'Or: unzip manually, remove the zips and use gpth with cmd options',
    );
  } else if (freeSpace < requiredSpace) {
    print(
      '!!! WARNING !!!\n'
      'Whole process needs ${filesize(requiredSpace)} of space, but you '
      'only have ${filesize(freeSpace)} available on ${dir.path} - \n'
      'Press Ctrl-C to exit and make some free space.\n'
      'Or: unzip manually, remove the zips, and use gpth with cmd options\n'
      '(or, type "i know what i am doing" to continue)',
    );
    if (stdin.readLineSync() != 'i know what i am doing') {
      print('Exiting, go make some free space!');
      quit(69);
    }
  } else {
    print(
      '(Note: this will use ~${filesize(requiredSpace)} of disk space - '
      'you have ${filesize(freeSpace)} free so should be fine :)',
    );
  }
  print('Press enter to continue');
  stdin.readLineSync();
  // TODO: Unzip
}
