import 'dart:io';

import 'package:args/args.dart';
import 'package:gpth/album.dart';
import 'package:gpth/datetime_extractors.dart';
import 'package:gpth/duplicate.dart';
import 'package:gpth/media.dart';
import 'package:gpth/utils.dart';
import 'package:path/path.dart';

// elastic list of extractors - can add/remove more in future
// for example, with cli flags
// those are in order of reliability
// if one fails, only then later ones will be used
final List<DateTimeExtractor> dateExtractors = [
  jsonExtractor,
];

const helpText = """GooglePhotosTakeoutHelper v3.0.0 - The Dart successor

gpth is ment to help you with exporting your photos from Google Photos.

First, go to https://takeout.google.com/ , deselect all and select only Photos.
When ready, download all .zips, and extract them into *one* folder.

Then, run: gpth --input "folder/with/all/takeouts" --output "your/output/folder"
...and gpth will parse and organize all photos into one big chronological folder
""";

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: 'Print help', negatable: false)
    ..addOption('fix',
        help: 'Folder with any photos to fix dates. '
            'This skips whole "GoogleTakeout" procedure')
    ..addOption('input',
        abbr: 'i', help: 'Input folder with *all* takeouts extracted')
    ..addOption('output',
        abbr: 'o', help: 'Output folder where all photos will land');
  late final ArgResults res;
  try {
    res = parser.parse(arguments);
  } on FormatException catch (e) {
    // don't print big ass trace
    error('$e');
    exit(1);
  } catch (e) {
    // any other exceptions (res must not be null)
    error('$e');
    exit(100);
  }

  if (res.arguments.isEmpty) {
    print('GooglePhotosTakeoutHelper v3.0.0');
    print('type --help for more info about usage');
    return;
  }

  if (res['help']) {
    print(helpText);
    print(parser.usage);
    return;
  }

  if (res['fix'] != null) {
    print('FIX MODE');
    // TODO: fix mode
    return;
  }

  // TODO: check args and run
  if (res['input'] == null) {
    error("No --input folder specified :/");
    exit(10);
  }
  final input = Directory(res['input']);
  if (!input.existsSync()) {
    error("Input folder does not exist :/");
    exit(11);
  }

  final media = <Media>[];

  final yearFolders = <Directory>[];
  final albumFolders = <Directory>[];

  /// ##### Find all photos/videos and add to list #####
  for (final f in input.listSync().whereType<Directory>()) {
    if (basename(f.path).startsWith('Photos from ')) {
      yearFolders.add(f);
    } else {
      albumFolders.add(f);
    }
  }
  for (final f in yearFolders) {
    for (final file in f.listSync().wherePhotoVideo()) {
      media.add(Media(file));
    }
  }

  /// ##################################################

  /// ##### Extracting/predicting dates using given extractors #####
  var q = 0;
  for (final extractor in dateExtractors) {
    for (var i = 0; i < media.length; i++) {
      // if already has date then skip
      if (media[i].dateTaken == null) {
        final date = await extractor(media[i].file);
        if (date != null) {
          media[i].dateTaken = date;
          media[i].dateTakenAccuracy = q;
        }
      }
    }
    // increase this every time - indicate the extraction gets more shitty
    q++;
  }

  /// ##############################################################

  /// ##### Find duplicates #####

  removeDuplicates(media);

  /// ###########################

  /// ##### Find albums #####

  // Now, this is akward...
  // we can find albums without a problem, but we have no idea what
  // to do about it 🤷
  // so just print it now (flex)
  print(findAlbums(albumFolders, media));

  /// #######################

  print(media);
}
