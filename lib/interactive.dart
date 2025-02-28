import 'dart:async';
import 'dart:io';

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
