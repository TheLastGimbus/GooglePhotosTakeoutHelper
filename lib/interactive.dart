/// This file contains code for interacting with user when launched without
/// arguments => probably with double-click
///
/// Such "interactive mode" was created because people are too dumb to use cmd
/// And I'm too lazy to create GUI <- this line is by Copilot and is true
///
/// Rules for this file functions do...:
/// - ...use sleep() to make thing live and give time to read text
/// - ...decide for themselves how much sleep() they want and where
/// - ...start and end without any extra \n, but can have \n inside
///    - extra \n are added in main file
/// - ...detect when something is wrong (f.e. disk space) and quit whole program
/// - ...are as single-job as it's appropriate - main file calls them one by one
import 'dart:async';
import 'dart:io';

// @Deprecated('Interactive unzipping is suspended for now!')
// import 'package:archive/archive_io.dart';
import 'package:file_picker_desktop/file_picker_desktop.dart';
import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

const albumOptions = {
  'shortcut': '[Recommended] Album folders with shortcuts/symlinks to '
      'original photos. Recommended as it will take the least space, but '
      'may not be portable when moving across systems/computes/phones etc',
  'duplicate-copy': 'Album folders with photos copied into them. '
      'This will work across all systems, but may take wayyy more space!!',
  'json': "Put ALL photos (including Archive and Trash) in one folder and "
      "make a .json file with info about albums. "
      "Use if you're a programmer, or just want to get everything, "
      "ignoring lack of year-folders etc.",
  'nothing': 'Just ignore them and put year-photos into one folder. '
      'WARNING: This ignores Archive/Trash !!!',
};

/// Whether we are, indeed, running interactive (or not)
var indeed = false;

/// Shorthand for Future.delayed
Future<void> sleep(num seconds) =>
    Future.delayed(Duration(milliseconds: (seconds * 1000).toInt()));

void pressEnterToContinue() {
  print('[press enter to continue]');
  stdin.readLineSync();
}

// this can't return null on error because it would be same for blank
// (pure enter) and "fdsfsdafs" - and we want to detect enters
Future<String> askForInt() async => stdin
    .readLineSync()!
    .replaceAll('[', '')
    .replaceAll(']', '')
    .toLowerCase()
    .trim();

Future<void> greet() async {
  print('GooglePhotosTakeoutHelper v$version');
  await sleep(1);
  print('Hi there! This tool will help you to get all of your photos from '
      'Google Takeout to one nice tidy folder\n');
  await sleep(3);
  print('(If any part confuses you, read the guide on:\n'
      'https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper )');
  await sleep(3);
}

/// does not quit explicitly - do it yourself
Future<void> nothingFoundMessage() async {
  print('...oh :(');
  print('...');
  print("I couldn't find any D: reasons for this may be:");
  if (indeed) {
    print(
      "  - you've already ran gpth and it moved all photos to output -\n"
      "    delete the input folder and re-extract the zip",
    );
  }
  print(
    "  - your Takeout doesn't have any \"year folders\" -\n"
    "    visit https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper\n"
    "    again and request new, correct Takeout",
  );
  print('After fixing this, go ahead and try again :)');
}

Future<Directory> getInputDir() async {
  print('Select the directory where you unzipped all your takeout zips');
  print('(Make sure they are merged => there is only one "Takeout" folder!)');
  await sleep(1);
  pressEnterToContinue();
  final dir = await getDirectoryPath(dialogTitle: 'Select unzipped folder:');
  await sleep(1);
  if (dir == null) {
    error('Duh, something went wrong with selecting - try again!');
    return getOutput();
  }
  print('Cool!');
  sleep(1);
  return Directory(dir);
}

/// Asks user for zip files with ui dialogs
@Deprecated('Interactive unzipping is suspended for now!')
Future<List<File>> getZips() async {
  print('First, select all .zips from Google Takeout '
      '(use Ctrl to select multiple)');
  await sleep(2);
  pressEnterToContinue();
  final files = await pickFiles(
    dialogTitle: 'Select all Takeout zips:',
    type: FileType.custom,
    allowedExtensions: ['zip', 'tgz'],
    allowMultiple: true,
  );
  await sleep(1);
  if (files == null) {
    error('Duh, something went wrong with selecting - try again!');
    quit(69);
  }
  if (files.count == 0) {
    error('No files selected - try again :/');
    quit(6969);
  }
  if (files.count == 1) {
    print("You selected only one zip - if that's only one you have, it's cool, "
        "but if you have multiple, Ctrl-C to exit gpth, and select them "
        "*all* again (with Ctrl)");
    await sleep(5);
    pressEnterToContinue();
  }
  if (!files.files.every((e) =>
      File(e.path!).statSync().type == FileSystemEntityType.file &&
      RegExp(r'\.(zip|tgz)$').hasMatch(e.path!))) {
    print('Files: [${files.files.map((e) => p.basename(e.path!)).join(', ')}]');
    error('Not all files you selected are zips :/ please do this again');
    quit(6969);
  }
  // potentially shows user they selected too little ?
  print('Cool! Selected ${files.count} zips => '
      '${filesize(
    files.files
        .map((e) => File(e.path!).statSync().size)
        .reduce((a, b) => a + b),
  )}');
  await sleep(1);
  return files.files.map((e) => File(e.path!)).toList();
}

/// Asks user for output folder with ui dialogs
Future<Directory> getOutput() async {
  print('Now, select output folder - all photos will be moved there\n'
      '(note: GPTH will *move* your photos - no extra space will be taken ;)');
  await sleep(1);
  pressEnterToContinue();
  final dir = await getDirectoryPath(dialogTitle: 'Select output folder:');
  await sleep(1);
  if (dir == null) {
    error('Duh, something went wrong with selecting - try again!');
    return getOutput();
  }
  print('Cool!');
  sleep(1);
  return Directory(dir);
}

Future<bool> askDivideDates() async {
  print('Do you want your photos in one big chronological folder, '
      'or divided to folders by year/month?');
  print('[1] (default) - one big folder');
  print('[2] - year/month folders');
  print('(Type 1 or 2 or press enter for default):');
  final answer = await askForInt();
  switch (answer) {
    case '1':
    case '':
      print('Okay, one big it is!');
      return false;
    case '2':
      print('Okay, will divide to folders!');
      return true;
    default:
      error('Invalid answer - try again');
      return askDivideDates();
  }
}

Future<String> askAlbums() async {
  print('What should be done with albums?');
  var i = 0;
  for (final entry in albumOptions.entries) {
    print('[${i++}] ${entry.key}: ${entry.value}');
  }
  final answer = int.tryParse(await askForInt());
  if (answer == null || answer < 0 || answer >= albumOptions.length) {
    error('Invalid answer - try again');
    return askAlbums();
  }
  final choice = albumOptions.keys.elementAt(answer);
  print('Okay, doing: $choice');
  return choice;
}

// this is used in cli mode as well
Future<bool> askForCleanOutput() async {
  print('Output folder IS NOT EMPTY! What to do? Type either:');
  print('[1] - delete *all* files inside output folder and continue');
  print('[2] - continue as usual - put output files alongside existing');
  print('[3] - exit program to examine situation yourself');
  final answer = stdin
      .readLineSync()!
      .replaceAll('[', '')
      .replaceAll(']', '')
      .toLowerCase()
      .trim();
  switch (answer) {
    case '1':
      print('Okay, deleting all files inside output folder...');
      return true;
    case '2':
      print('Okay, continuing as usual...');
      return false;
    case '3':
      print('Okay, exiting...');
      quit(0);
    default:
      error('Invalid answer - try again');
      return askForCleanOutput();
  }
}

/// Checks free space on disk and notifies user accordingly
@Deprecated('Interactive unzipping is suspended for now!')
Future<void> freeSpaceNotice(int required, Directory dir) async {
  final freeSpace = await getDiskFree(dir.path);
  if (freeSpace == null) {
    print(
      'Note: everything will take ~${filesize(required)} of disk space - '
      'make sure you have that available on ${dir.path} - otherwise, '
      'Ctrl-C to exit, and make some free space!\n'
      'Or: unzip manually, remove the zips and use gpth with cmd options',
    );
  } else if (freeSpace < required) {
    print(
      '!!! WARNING !!!\n'
      'Whole process requires ${filesize(required)} of space, but you '
      'only have ${filesize(freeSpace)} available on ${dir.path} - \n'
      'Go make some free space!\n'
      '(Or: unzip manually, remove the zips, and use gpth with cmd options)',
    );
    quit(69);
  } else {
    print(
      '(Note: everything will take ~${filesize(required)} of disk space - '
      'you have ${filesize(freeSpace)} free so should be fine :)',
    );
  }
  await sleep(3);
  pressEnterToContinue();
}

/// Unzips all zips to given folder (creates it if needed)
@Deprecated('Interactive unzipping is suspended for now!')
Future<void> unzip(List<File> zips, Directory dir) async {
  throw UnimplementedError();
  // if (await dir.exists()) await dir.delete(recursive: true);
  // await dir.create(recursive: true);
  // print('gpth will now unzip all of that, process it and put everything in '
  //     'the output folder :)');
  // await sleep(1);
  // for (final zip in zips) {
  //   print('Unzipping ${p.basename(zip.path)}...');
  //   try {
  //     await extractFileToDisk(zip.path, dir.path, asyncWrite: true);
  //   } on PathNotFoundException catch (e) {
  //     error('Error while unzipping $zip :(\n$e');
  //     error('');
  //     error('===== This is a known issue ! =====');
  //     error("Looks like unzipping doesn't want to work :(");
  //     error(
  //         "You will have to unzip manually - see 'Running manually' section in README");
  //     error('');
  //     error(
  //         'https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper#running-manually-with-cmd');
  //     error('');
  //     error('===== Sorry for inconvenience =====');
  //   } catch (e) {
  //     error('Error while unzipping $zip :(\n$e');
  //     quit(69);
  //   }
  // }
}
