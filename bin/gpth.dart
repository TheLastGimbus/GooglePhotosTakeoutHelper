import 'dart:io';

import 'package:args/args.dart';
import 'package:console_bars/console_bars.dart';
import 'package:gpth/date_extractor.dart';
import 'package:gpth/duplicate.dart';
import 'package:gpth/extras.dart';
import 'package:gpth/media.dart';
import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

const helpText = """GooglePhotosTakeoutHelper v3.0.0 - The Dart successor

gpth is ment to help you with exporting your photos from Google Photos.

First, go to https://takeout.google.com/ , deselect all and select only Photos.
When ready, download all .zips, and extract them into *one* folder.

Then, run: gpth --input "folder/with/all/takeouts" --output "your/output/folder"
...and gpth will parse and organize all photos into one big chronological folder
""";
const barWidth = 60;

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: 'Print help', negatable: false)
    ..addOption('fix',
        help: 'Folder with any photos to fix dates. '
            'This skips whole "GoogleTakeout" procedure')
    ..addOption('input',
        abbr: 'i', help: 'Input folder with *all* takeouts extracted')
    ..addOption('output',
        abbr: 'o', help: 'Output folder where all photos will land')
    ..addFlag('skip-extras', help: 'Skip extra images (like -edited etc)')
    ..addFlag('guess-from-name',
        help: 'Try to guess file dates from their names')
    ..addFlag('copy',
        help: "Copy files instead of moving them.\n"
            "This is usually slower, and uses extra space, "
            "but doesn't break your input folder");
  late final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    // don't print big ass trace
    error('$e');
    exit(1);
  } catch (e) {
    // any other exceptions (args must not be null)
    error('$e');
    exit(100);
  }

  if (args.arguments.isEmpty) {
    print('GooglePhotosTakeoutHelper v3.0.0');
    print('type --help for more info about usage');
    return;
  }
  if (args['help']) {
    print(helpText);
    print(parser.usage);
    return;
  }

  // elastic list of extractors - can add/remove with cli flags
  // those are in order of reliability -
  // if one fails, only then later ones will be used
  final dateExtractors = <DateTimeExtractor>[
    jsonExtractor,
    exifExtractor,
    if (args['guess-from-name']) guessExtractor,
  ];

  /// ##### Occasional Fix mode #####

  if (args['fix'] != null) {
    // i was thing if not to move this to outside file, but let's leave for now
    print('========== FIX MODE ==========');
    print('I will go through all files in folder that you gave me');
    print('and try to set each file to correct lastModified value');
    final dir = Directory(args['fix']);
    if (!await dir.exists()) {
      error("directory to fix doesn't exist :/");
      exit(11);
    }
    var set = 0;
    var notSet = 0;
    await for (final file in dir.list(recursive: true).wherePhotoVideo()) {
      DateTime? date;
      for (final extractor in dateExtractors) {
        date = await extractor(file);
        if (date != null) {
          await file.setLastModified(date);
          set++;
          break;
        }
      }
      if (date == null) notSet++;
    }
    print('FINISHED!');
    print('$set set✅');
    print('$notSet not set❌');
    return;
  }

  /// ###############################

  /// ##### Parse all options and check if alright #####

  if (!args['copy']) {
    print(
      "WARNING: Script will *move* files from input to output - not *copy* \n"
      "- this is faster, and doesn't use extra space, but will break your \n"
      "input folder (it will be, well, empty)\n"
      "If you want copy instead of move, exit script (ctrl-c) and use --copy flag\n"
      "Otherwise, press enter to agree with that",
    );
    stdin.readLineSync();
  }

  if (args['input'] == null) {
    error("No --input folder specified :/");
    exit(10);
  }
  if (args['output'] == null) {
    error("No --output folder specified :/");
    exit(10);
  }
  final input = Directory(args['input']);
  final output = Directory(args['output']);
  if (!await input.exists()) {
    error("Input folder does not exist :/");
    exit(11);
  }
  // all of this logic is to prevent user easily blowing output folder
  // by running command two times
  if (await output.exists() && !await output.list().isEmpty) {
    print('Output folder exists, and IS NOT EMPTY! What to do? Type either:');
    print('[delete] - delete *all* files inside output folder and continue');
    print('[ignore] - continue as usual - put output files alongside existing');
    print('[cancel] - exit program to examine situation yourself');
    final answer = stdin
        .readLineSync()!
        .replaceAll('[', '')
        .replaceAll(']', '')
        .toLowerCase()
        .trim();
    switch (answer) {
      case 'delete':
        print('Okay, deleting all files inside output folder...');
        await for (final file in output.list()) {
          await file.delete(recursive: true);
        }
        break;
      case 'ignore':
        print('Okay, continuing as usual...');
        break;
      case 'cancel':
        print('Okay, exiting...');
        exit(0);
      default:
        print('Unknown answer, exiting...');
        exit(1);
    }
  }
  await output.create(recursive: true);

  /// ##################################################

  // Okay, time to explain the structure of things here
  // We create a list of Media objects, and fill it with everything we find
  // in "year folders". Then, we play *mutably* with this list - fill Media's
  // with guess DateTime's, remove duplicates from this list.
  //
  // No shitheads, you did not overhear - we *mutate* the whole list and objects
  // inside it. This his not Flutter-ish, but it's not Flutter - it's a small
  // simple script, and this the best solution 😎💯
  /// Big global media list that we'll work on
  final media = <Media>[];

  /// All "year folders" that we found
  final yearFolders = <Directory>[];

  /// All album folders - that is, folders that were aside yearFolders and were
  /// not matching "Photos from ...." name
  final albumFolders = <Directory>[];

  /// ##### Find all photos/videos and add to list #####

  print('Okay, running... searching for everything in input folder...');

  // recursive=true makes it find everything nicely even if user id dumb 😋
  await for (final d in input.list(recursive: true).whereType<Directory>()) {
    isYear(Directory dir) => p.basename(dir.path).startsWith('Photos from ');
    if (isYear(d)) {
      yearFolders.add(d);
    } // if not year but got any year brothers
    else if (await d.parent
        .list()
        .whereType<Directory>()
        .any((e) => isYear(e))) {
      albumFolders.add(d);
    }
  }
  await for (final f in Stream.fromIterable(yearFolders)) {
    await for (final file in f.list().wherePhotoVideo()) {
      media.add(Media(file));
    }
  }

  print('Found ${media.length} photos/videos in input folder');

  /// ##################################################

  /// ##### Extracting/predicting dates using given extractors #####

  final barExtract = FillingBar(
    total: media.length,
    desc: "Guessing dates from files",
    width: barWidth,
  );
  var q = 0;
  for (final extractor in dateExtractors) {
    for (var i = 0; i < media.length; i++) {
      // if already has date then skip
      if (media[i].dateTaken == null) {
        final date = await extractor(media[i].file);
        if (date != null) {
          media[i].dateTaken = date;
          media[i].dateTakenAccuracy = q;
          barExtract.increment();
        }
      }
    }
    // increase this every time - indicate the extraction gets more shitty
    q++;
  }
  print('');

  /// ##############################################################

  /// ##### Find duplicates #####

  // TODO: Check if we even need to print this if it's maybe fast enough
  print('Finding duplicates...');

  final countDuplicates = removeDuplicates(media);

  /// ###########################

  /// ##### Potentially skip extras #####

  if (args['skip-extras']) print('Finding "extra" photos (-edited etc)');
  final countExtras = args['skip-extras'] ? removeExtras(media) : 0;

  /// ###################################

  /// ##### Find albums #####

  // Now, this is awkward...
  // we can find albums without a problem, but we have no idea what
  // to do about it 🤷
  // so just print it now (flex)
  // findAlbums(albumFolders, media).forEach(print);

  /// #######################

  /// ##### Copy/move files to actual output folder #####

  final barCopy = FillingBar(
    total: media.length,
    desc: "${args['copy'] ? 'Coping' : 'Moving'} files to output folder",
    width: 60,
  );
  await for (final m in Stream.fromIterable(media)) {
    final freeFile =
        findNotExistingName(File(p.join(output.path, p.basename(m.file.path))));
    final c = args['copy']
        ? await m.file.copy(freeFile.path)
        : await m.file.rename(freeFile.path);
    await c.setLastModified(m.dateTaken ?? DateTime.now());
    barCopy.increment();
  }
  print('');

  /// ###################################################

  print('DONE! FREEEEEDOOOOM!!!');
  print('Found ${media.length} photos/videos in "${input.path}"');
  print('Left out $countDuplicates duplicates');
  if (args['skip-extras']) print('Left out $countExtras extras');
  print(
    '${args['copy'] ? 'Copied' : 'Moved'} '
    '${media.length - countDuplicates - countExtras} '
    'files to "${output.path}"',
  );
}
