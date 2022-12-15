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

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('input', abbr: 'i', help: 'Input folder', mandatory: true)
    ..addOption('output', abbr: 'o', help: 'Output folder');
  final res = parser.parse(arguments);

  final cliInput = res['input'] as String;

  final input = Directory(cliInput);

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
        final date = extractor(media[i].file);
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
