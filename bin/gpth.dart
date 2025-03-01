import "dart:io";

import "package:args/args.dart";
import "package:console_bars/console_bars.dart";
import "package:gpth/date_extractor.dart";
import "package:gpth/extras.dart";
import "package:gpth/folder_classify.dart";
import "package:gpth/grouping.dart";
import "package:gpth/interactive.dart" as interactive;
import "package:gpth/media.dart";
import "package:gpth/moving.dart";
import "package:gpth/utils.dart";
import "package:path/path.dart" as p;
import "package:logging/logging.dart";
import "package:gpth/gps_extractor.dart";
import "package:gpth/exif_writer.dart";

final Logger _logger = Logger("GooglePhotosHelper");

// Error messages
const String errorNoInputFolder = 'No --input folder specified :/';
const String errorNoOutputFolder = 'No --output folder specified :/';
const String errorInputFolderNotExist = 'Input folder does not exist :/';
const String errorNoMediaFound = "Couldn't find date for %d photos/videos :/";

const String helpText = '''GooglePhotosTakeoutHelper v$version - The Dart successor

gpth is meant to help you with exporting your photos from Google Photos.

First, go to https://takeout.google.com/ , deselect all and select only Photos.
When ready, download all .zips, and extract them into *one* folder.
(Auto-extracting works only in interactive mode)

Then, run: gpth --input "folder/with/all/takeouts" --output "your/output/folder"
...and gpth will parse and organize all photos into one big chronological folder
''';
const int barWidth = 40;

void main(final List<String> arguments) async {
  try {
    // Set up logging
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((final LogRecord record) {
      final String level = record.level.name;
      final String message = record.message;
      final Object? error = record.error;
      final StackTrace? stackTrace = record.stackTrace;

      final File logFile = File("gpth.log");
      final String logMessage = '${DateTime.now()} [$level] ${record.loggerName}: $message${error != null ? '\nError: $error' : ''}${stackTrace != null ? '\nStack trace:\n$stackTrace' : ''}\n';

      logFile.writeAsStringSync(logMessage, mode: FileMode.append);

      // Only print warnings and severe errors to console
      if (record.level >= Level.WARNING) {
        stderr.writeln('[$level] ${record.loggerName}: $message${error != null ? '\nError: $error' : ''}');
      }
    });

    final ArgParser parser = ArgParser()
      ..addFlag("help", abbr: "h", negatable: false, help: "Show this help")
      ..addOption("fix", help: "Folder with photos to fix dates")
      ..addFlag("write-exif", negatable: false, help: "Write JSON data (dates, GPS) to EXIF metadata")
      ..addOption("batch-size",
          help: "Number of files to process in parallel for EXIF writing (default: 4)",
          defaultsTo: "4")
      ..addFlag("interactive", abbr: "i", negatable: false, help: "Use interactive mode")
      ..addOption("input", abbr: "I", help: "Input folder with extracted takeouts")
      ..addOption("output", abbr: "O", help: "Output folder for photos")
      ..addOption("albums",
          allowed: interactive.albumOptions.keys.toList(),
          help: "What to do with albums",
          defaultsTo: "shortcut")
      ..addFlag("divide-to-dates",
          help: "Divide output by year/month")
      ..addFlag("skip-extras",
          help: "Skip extra images (edited, effects, etc)")
      ..addFlag("skip-gps",
          help: "Skip GPS data extraction (faster processing)")
      ..addFlag("dry-run",
          help: "Show what would happen without actually moving/copying files")
      ..addFlag("guess-from-name",
          help: "Guess file dates from names", defaultsTo: true)
      ..addFlag("copy", help: "Copy files instead of moving");
    final Map<String, dynamic> args = <String, dynamic>{};
    try {
      final ArgResults res = parser.parse(arguments);
      for (final String key in res.options) {
        args[key] = res[key];
      }
      interactive.indeed =
          args["interactive"] || (res.arguments.isEmpty && stdin.hasTerminal);
    } on FormatException catch (e) {
      // don't print big ass trace
      error("$e");
      quit(2);
    } catch (e) {
      // any other exceptions (args must not be null)
      error("$e");
      quit(100);
    }

    if (args["help"]) {
      print(helpText);
      print(parser.usage);
      return;
    }

    if (interactive.indeed) {
      // greet user
      await interactive.greet();
      print("");
      // ask for everything
      // @Deprecated('Interactive unzipping is suspended for now!')
      // final zips = await interactive.getZips();
      late Directory inDir;
      try {
        inDir = await interactive.getInputDir();
      } catch (e) {
        print('Hmm, interactive selecting input dir crashed... \n'
            "it looks like you're running in headless/on Synology/NAS...\n"
            "If so, you have to use cli options - run 'gpth --help' to see them");
        exit(69);
      }
      print("");
      final Directory out = await interactive.getOutput();
      print("");
      args["divide-to-dates"] = await interactive.askDivideDates();
      print("");
      args["albums"] = await interactive.askAlbums();
      print("");
      args["skip-gps"] = await interactive.askSkipGps();
      print("");

      // @Deprecated('Interactive unzipping is suspended for now!')
      // // calculate approx space required for everything
      // final cumZipsSize = zips.map((e) => e.lengthSync()).reduce((a, b) => a + b);
      // final requiredSpace = (cumZipsSize * 2) + 256 * 1024 * 1024;
      // await interactive.freeSpaceNotice(requiredSpace, out); // and notify this
      // print('');
      //
      // final unzipDir = Directory(p.join(out.path, '.gpth-unzipped'));
      // args['input'] = unzipDir.path;
      args["input"] = inDir.path;
      args["output"] = out.path;
      //
      // await interactive.unzip(zips, unzipDir);
      // print('');
    }

    // elastic list of extractors - can add/remove with cli flags
    // those are in order of reliability -
    // if one fails, only then later ones will be used
    final List<DateTimeExtractor> dateExtractors = <DateTimeExtractor>[
      jsonExtractor,
      exifExtractor,
      if (args["guess-from-name"]) guessExtractor,
      // this is potentially *dangerous* - see:
      // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/175
      (final File f) => jsonExtractor(f, tryhard: true),
    ];

    /// ##### Occasional Fix mode #####

    if (args["fix"] != null) {
      // i was thing if not to move this to outside file, but let's leave for now
      print("========== FIX MODE ==========");
      print("I will go through all files in folder that you gave me");
      print("and try to set each file to correct lastModified value");
      final Directory dir = Directory(args["fix"]);
      if (!await dir.exists()) {
        error("directory to fix doesn't exist :/");
        quit(11);
      }
      int set = 0;
      int notSet = 0;
      await for (final File file in dir.list(recursive: true).wherePhotoVideo()) {
        DateTime? date;
        for (final DateTimeExtractor extractor in dateExtractors) {
          date = await extractor(file);
          if (date != null) {
            try {
              await file.setLastModified(date);
              set++;
            } catch (e) {
              _logger.warning('Failed to set last modified date for ${file.path}: $e');
              notSet++; // Count as not set if we failed to set the date
            }
            break;
          }
        }
        if (date == null) notSet++;
      }
      print("FINISHED!");
      print("$set set✅");
      print("$notSet not set❌");
      return;
    }

    /// ##### Write EXIF mode #####

    if (args["write-exif"]) {
      print("========== WRITE EXIF MODE ==========");
      print("I will go through all files in the input folder");
      print("and try to write JSON data (dates, GPS) to EXIF metadata");

      final Directory inputDir = Directory(args["input"]);
      if (!await inputDir.exists()) {
        error("Input directory doesn't exist :/");
        quit(11);
      }

      int dateSet = 0;
      int gpsSet = 0;
      int failed = 0;

      // Parse batch size with error handling
      var batchSize = 4;
      try {
        batchSize = int.parse(args["batch-size"]);
        if (batchSize < 1) batchSize = 1;
        if (batchSize > 16) {
          print('Warning: Large batch sizes may cause memory issues. Using 16 instead of ${args['batch-size']}');
          batchSize = 16;
        }
      } catch (e) {
        print('Invalid batch size: ${args['batch-size']}. Using default (4)');
        batchSize = 4;
      }

      print("Processing with batch size: $batchSize");

      // Collect all files first
      final List<File> files = <File>[];
      await for (final File file in inputDir.list(recursive: true).wherePhotoVideo()) {
        files.add(file);
      }

      final FillingBar bar = FillingBar(
        total: files.length,
        desc: 'Writing EXIF data',
        width: barWidth,
      );

      // Process in batches
      for (int i = 0; i < files.length; i += batchSize) {
        final int end = (i + batchSize < files.length) ? i + batchSize : files.length;
        final List<File> batch = files.sublist(i, end);

        final List<Map<String, bool>> results = await Future.wait(batch.map((final File file) async {
          final Map<String, bool> result = <String, bool>{"dateSuccess": false, "gpsSuccess": false};

          // Extract date
          DateTime? date;
          for (final DateTimeExtractor extractor in dateExtractors) {
            date = await extractor(file);
            if (date != null) break;
          }

          // Extract GPS data
          final GpsData? gpsData = await extractGpsFromJson(file);

          // Write to EXIF if we have data
          if (date != null) {
            result["dateSuccess"] = await writeDateTimeToExif(file, date);
          }

          if (gpsData != null) {
            result["gpsSuccess"] = await writeGpsToExif(file, gpsData);
          }

          return result;
        }));

        // Update counters
        for (final Map<String, bool> result in results) {
          if (result["dateSuccess"] == true) dateSet++;
          if (result["gpsSuccess"] == true) gpsSet++;
          if (result["dateSuccess"] == false && result["gpsSuccess"] == false) failed++;
          bar.increment();
        }

        // Clear cache after each batch to prevent memory buildup
        clearGpsCache();
      }

      print("FINISHED!");
      print("$dateSet files with date written to EXIF ✅");
      print("$gpsSet files with GPS data written to EXIF ✅");
      print("$failed files failed to write EXIF data ❌");
      return;
    }

    /// ###############################

    /// ##### Parse all options and check if alright #####

    if (args["input"] == null) {
      error(errorNoInputFolder);
      quit(10);
    }
    if (args["output"] == null) {
      error(errorNoOutputFolder);
      quit(10);
    }
    final Directory input = Directory(args["input"]);
    final Directory output = Directory(args["output"]);
    if (!await input.exists()) {
      error(errorInputFolderNotExist);
      quit(11);
    }
    // all of this logic is to prevent user easily blowing output folder
    // by running command two times
    if (await output.exists() &&
        !await output
            .list()
            // allow input folder to be inside output
            .where((final FileSystemEntity e) => p.absolute(e.path) != p.absolute(args["input"]))
            .isEmpty) {
      if (await interactive.askForCleanOutput()) {
        await for (final FileSystemEntity file in output
            .list()
            // delete everything except input folder if there
            .where((final FileSystemEntity e) => p.absolute(e.path) != p.absolute(args["input"]))) {
          await file.delete(recursive: true);
        }
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
    // inside it. This is not Flutter-ish, but it's not Flutter - it's a small
    // simple script, and this the best solution 😎💯

    // Okay, more details on what will happen here:
    // 1. We find *all* media in either year folders or album folders.
    //    Every single file will be a separate [Media] object.
    //    If given [Media] was found in album folder, it will have it noted
    // 2. We [removeDuplicates] - if two files in same/null album have same hash,
    //    one will be removed. Note that there are still duplicates from different
    //    albums left. This is intentional
    // 3. We guess their dates. Functions in [dateExtractors] are used in order
    //    from most to least accurate
    // 4. Now we [findAlbums]. This will analyze [Media] that have same hashes,
    //    and leave just one with all [albums] filled.
    //    final exampleMedia = [
    //      Media('lonePhoto.jpg'),
    //      Media('photo1.jpg, albums=null),
    //      Media('photo1.jpg, albums={Vacation}),
    //      Media('photo1.jpg, albums={Friends}),
    //    ];
    //    findAlbums(exampleMedia);
    //    exampleMedia == [
    //      Media('lonePhoto.jpg'),
    //      Media('photo1.jpg, albums={Vacation, Friends}),
    //    ];
    //

    /// Big global media list that we'll work on
    final List<Media> media = <Media>[];

    /// All "year folders" that we found
    final List<Directory> yearFolders = <Directory>[];

    /// All album folders - that is, folders that were aside yearFolders and were
    /// not matching "Photos from ...." name
    final List<Directory> albumFolders = <Directory>[];

    /// ##### Find literally *all* photos/videos and add to list #####

    print("Okay, running... searching for everything in input folder...");

    // Using recursive=true to find all directories regardless of nesting level
    await for (final Directory d in input.list(recursive: true).whereType<Directory>()) {
      if (isYearFolder(d)) {
        yearFolders.add(d);
      } else if (await isAlbumFolder(d)) {
        albumFolders.add(d);
      }
    }
    for (final Directory f in yearFolders) {
      await for (final File file in f.list().wherePhotoVideo()) {
        media.add(Media(<String?, File>{null: file}));
      }
    }
    for (final Directory a in albumFolders) {
      await for (final File file in a.list().wherePhotoVideo()) {
        media.add(Media(<String?, File>{albumName(a): file}));
      }
    }

    if (media.isEmpty) {
      await interactive.nothingFoundMessage();
      // @Deprecated('Interactive unzipping is suspended for now!')
      // if (interactive.indeed) {
      //   print('([interactive] removing unzipped folder...)');
      //   await input.delete(recursive: true);
      // }
      quit(13);
    }

    /// ##################################################

    /// ##### Find duplicates #####

    print("Finding duplicates...");

    final int countDuplicates = removeDuplicates(media);

    /// ###########################

    /// ##### Potentially skip extras #####

    if (args["skip-extras"]) print('Finding "extra" photos (-edited etc)');
    final int countExtras = args["skip-extras"] ? removeExtras(media) : 0;

    /// ###################################

    // NOTE FOR MYSELF/whatever:
    // I placed extracting dates *after* removing duplicates.
    // Today i thought to myself - shouldn't this be reversed?
    // Finding correct date is our *biggest* priority, and duplicate that we just
    await _processArguments(arguments);
  } catch (e, stackTrace) {
    _logger.severe("Fatal error: $e", stackTrace);
    error("A fatal error occurred. Check the logs for details.");
    quit();
  }
}

Future<void> _processArguments(final List<String> arguments) async {
  final ArgParser parser = ArgParser()
    ..addFlag("help", abbr: "h", negatable: false)
    ..addOption(
      "fix",
      help: "Folder with any photos to fix dates. "
          'This skips whole "GoogleTakeout" procedure.'
          "It is here because gpth has some cool heuristics to determine date "
          "of a photo, and this can be handy in many situations :)",
    )
    ..addFlag("interactive",
        help: "Use interactive mode. Type this in case auto-detection fails, "
            "or you *really* want to combine advanced options with prompts")
    ..addOption("input",
        abbr: "i", help: "Input folder with *all* takeouts *extracted*. ")
    ..addOption("output",
        abbr: "o", help: "Output folder where all photos will land")
    ..addOption(
      "albums",
      help: "What to do about albums?",
      allowed: interactive.albumOptions.keys,
      allowedHelp: interactive.albumOptions,
      defaultsTo: "shortcut",
    )
    ..addFlag("divide-to-dates", help: "Divide output to folders by year/month")
    ..addFlag("skip-extras", help: "Skip extra images (like -edited etc)")
    ..addFlag(
      "guess-from-name",
      help: "Try to guess file dates from their names",
      defaultsTo: true,
    )
    ..addFlag(
      "copy",
      help: 'Copy files instead of moving them.\n'
          'This is usually slower, and uses extra space, '
          "but doesn't break your input folder",
    )
    ..addFlag("dry-run",
        help: "Show what would happen without actually moving/copying files");
  final Map<String, dynamic> args = <String, dynamic>{};
  try {
    final ArgResults res = parser.parse(arguments);
    for (final String key in res.options) {
      args[key] = res[key];
    }
    interactive.indeed =
        args["interactive"] || (res.arguments.isEmpty && stdin.hasTerminal);
  } on FormatException catch (e) {
    // don't print big ass trace
    error("$e");
    quit(2);
  } catch (e) {
    // any other exceptions (args must not be null)
    error("$e");
    quit(100);
  }

  if (args["help"]) {
    print(helpText);
    print(parser.usage);
    return;
  }

  try {
    if (interactive.indeed) {
      // greet user
      await interactive.greet();
      print("");
      // ask for everything
      // @Deprecated('Interactive unzipping is suspended for now!')
      // final zips = await interactive.getZips();
      late Directory inDir;
      try {
        inDir = await interactive.getInputDir();
      } catch (e) {
        print('Hmm, interactive selecting input dir crashed... \n'
            "it looks like you're running in headless/on Synology/NAS...\n"
            "If so, you have to use cli options - run 'gpth --help' to see them");
        exit(69);
      }
      print("");
      final Directory out = await interactive.getOutput();
      print("");
      args["divide-to-dates"] = await interactive.askDivideDates();
      print("");
      args["albums"] = await interactive.askAlbums();
      print("");
      args["skip-gps"] = await interactive.askSkipGps();
      print("");

      // @Deprecated('Interactive unzipping is suspended for now!')
      // // calculate approx space required for everything
      // final cumZipsSize = zips.map((e) => e.lengthSync()).reduce((a, b) => a + b);
      // final requiredSpace = (cumZipsSize * 2) + 256 * 1024 * 1024;
      // await interactive.freeSpaceNotice(requiredSpace, out); // and notify this
      // print('');
      //
      // final unzipDir = Directory(p.join(out.path, '.gpth-unzipped'));
      // args['input'] = unzipDir.path;
      args["input"] = inDir.path;
      args["output"] = out.path;
      //
      // await interactive.unzip(zips, unzipDir);
      // print('');
    }

    // elastic list of extractors - can add/remove with cli flags
    // those are in order of reliability -
    // if one fails, only then later ones will be used
    final List<DateTimeExtractor> dateExtractors = <DateTimeExtractor>[
      jsonExtractor,
      exifExtractor,
      if (args["guess-from-name"]) guessExtractor,
      // this is potentially *dangerous* - see:
      // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/175
      (final File f) => jsonExtractor(f, tryhard: true),
    ];

    /// ##### Occasional Fix mode #####

    if (args["fix"] != null) {
      // i was thing if not to move this to outside file, but let's leave for now
      print("========== FIX MODE ==========");
      print("I will go through all files in folder that you gave me");
      print("and try to set each file to correct lastModified value");
      final Directory dir = Directory(args["fix"]);
      if (!await dir.exists()) {
        error("directory to fix doesn't exist :/");
        quit(11);
      }
      int set = 0;
      int notSet = 0;
      await for (final File file in dir.list(recursive: true).wherePhotoVideo()) {
        DateTime? date;
        for (final DateTimeExtractor extractor in dateExtractors) {
          date = await extractor(file);
          if (date != null) {
            try {
              await file.setLastModified(date);
              set++;
            } catch (e) {
              _logger.warning('Failed to set last modified date for ${file.path}: $e');
              notSet++; // Count as not set if we failed to set the date
            }
            break;
          }
        }
        if (date == null) notSet++;
      }
      print("FINISHED!");
      print("$set set✅");
      print("$notSet not set❌");
      return;
    }

    /// ###############################

    /// ##### Parse all options and check if alright #####

    if (args["input"] == null) {
      error(errorNoInputFolder);
      quit(10);
    }
    if (args["output"] == null) {
      error(errorNoOutputFolder);
      quit(10);
    }
    final Directory input = Directory(args["input"]);
    final Directory output = Directory(args["output"]);
    if (!await input.exists()) {
      error(errorInputFolderNotExist);
      quit(11);
    }
    // all of this logic is to prevent user easily blowing output folder
    // by running command two times
    if (await output.exists() &&
        !await output
            .list()
            // allow input folder to be inside output
            .where((final FileSystemEntity e) => p.absolute(e.path) != p.absolute(args["input"]))
            .isEmpty) {
      if (await interactive.askForCleanOutput()) {
        await for (final FileSystemEntity file in output
            .list()
            // delete everything except input folder if there
            .where((final FileSystemEntity e) => p.absolute(e.path) != p.absolute(args["input"]))) {
          await file.delete(recursive: true);
        }
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
    // inside it. This is not Flutter-ish, but it's not Flutter - it's a small
    // simple script, and this the best solution 😎💯

    // Okay, more details on what will happen here:
    // 1. We find *all* media in either year folders or album folders.
    //    Every single file will be a separate [Media] object.
    //    If given [Media] was found in album folder, it will have it noted
    // 2. We [removeDuplicates] - if two files in same/null album have same hash,
    //    one will be removed. Note that there are still duplicates from different
    //    albums left. This is intentional
    // 3. We guess their dates. Functions in [dateExtractors] are used in order
    //    from most to least accurate
    // 4. Now we [findAlbums]. This will analyze [Media] that have same hashes,
    //    and leave just one with all [albums] filled.
    //    final exampleMedia = [
    //      Media('lonePhoto.jpg'),
    //      Media('photo1.jpg, albums=null),
    //      Media('photo1.jpg, albums={Vacation}),
    //      Media('photo1.jpg, albums={Friends}),
    //    ];
    //    findAlbums(exampleMedia);
    //    exampleMedia == [
    //      Media('lonePhoto.jpg'),
    //      Media('photo1.jpg, albums={Vacation, Friends}),
    //    ];
    //

    /// Big global media list that we'll work on
    final List<Media> media = <Media>[];

    /// All "year folders" that we found
    final List<Directory> yearFolders = <Directory>[];

    /// All album folders - that is, folders that were aside yearFolders and were
    /// not matching "Photos from ...." name
    final List<Directory> albumFolders = <Directory>[];

    /// ##### Find literally *all* photos/videos and add to list #####

    print("Okay, running... searching for everything in input folder...");

    // Using recursive=true to find all directories regardless of nesting level
    await for (final Directory d in input.list(recursive: true).whereType<Directory>()) {
      if (isYearFolder(d)) {
        yearFolders.add(d);
      } else if (await isAlbumFolder(d)) {
        albumFolders.add(d);
      }
    }
    for (final Directory f in yearFolders) {
      await for (final File file in f.list().wherePhotoVideo()) {
        media.add(Media(<String?, File>{null: file}));
      }
    }
    for (final Directory a in albumFolders) {
      await for (final File file in a.list().wherePhotoVideo()) {
        media.add(Media(<String?, File>{albumName(a): file}));
      }
    }

    if (media.isEmpty) {
      await interactive.nothingFoundMessage();
      // @Deprecated('Interactive unzipping is suspended for now!')
      // if (interactive.indeed) {
      //   print('([interactive] removing unzipped folder...)');
      //   await input.delete(recursive: true);
      // }
      quit(13);
    }

    /// ##################################################

    /// ##### Find duplicates #####

    print("Finding duplicates...");

    final int countDuplicates = removeDuplicates(media);

    /// ###########################

    /// ##### Potentially skip extras #####

    if (args["skip-extras"]) print('Finding "extra" photos (-edited etc)');
    final int countExtras = args["skip-extras"] ? removeExtras(media) : 0;

    /// ###################################

    // NOTE FOR MYSELF/whatever:
    // I placed extracting dates *after* removing duplicates.
    // Today i thought to myself - shouldn't this be reversed?
    // Finding correct date is our *biggest* priority, and duplicate that we just
    // removed might have been the chosen one
    //
    // But on the other hand, duplicates must be hash-perfect, so they contain
    // same exifs, and we can just compare length of their names - in 9999% cases,
    // one with shorter name will have json and others will not 🤷
    // ...and we would potentially waste a lot of time searching for all of their
    //    jsons
    // ...so i'm leaving this like that 😎
    //
    // Ps. BUT i've put album merging *after* guess date - notes below

    /// ##### Extracting/predicting dates using given extractors #####

    final FillingBar barExtract = FillingBar(
      total: media.length,
      desc: 'Guessing dates from files',
      width: barWidth,
    );
    for (int i = 0; i < media.length; i++) {
      int q = 0;
      for (final DateTimeExtractor extractor in dateExtractors) {
        final DateTime? date = await extractor(media[i].firstFile);
        if (date != null) {
          media[i].dateTaken = date;
          media[i].dateTakenAccuracy = q;
          barExtract.increment();
          break;
        }
        // increase this every time - indicate the extraction gets more shitty
        q++;
      }
      if (media[i].dateTaken == null) {
        print("\nCan't get date on ${media[i].firstFile.path}");
      }
    }
    print("");

    /// ##############################################################

    /// ##### Extracting GPS data from JSON files #####

    if (!args["skip-gps"]) {
      print("Extracting GPS data from JSON files...");
      final FillingBar barGps = FillingBar(
        total: media.length,
        desc: 'Extracting GPS data',
        width: barWidth,
      );
      int gpsExtracted = 0;
      for (int i = 0; i < media.length; i++) {
        final GpsData? gpsData = await extractGpsFromJson(media[i].firstFile);
        if (gpsData != null) {
          media[i].gpsData = gpsData;
          gpsExtracted++;
        }
        barGps.increment();
      }
      print("GPS data extracted for $gpsExtracted files");
      // Clear the GPS cache to free memory
      clearGpsCache();
      print("");
    } else {
      print("Skipping GPS data extraction (--skip-gps flag used)");
      print("");
    }

    /// ##############################################################

    /// ##### Find albums #####

    // I'm placing merging duplicate Media into albums after guessing date for
    // each one individually, because they are in different folders.
    // This way, we might find JSON metadata in album folders that would be
    // missing in the year folders.

    print("Finding albums (this may take some time, dont worry :) ...");
    findAlbums(media);

    /// #######################

    /// ##### Copy/move files to actual output folder #####

    final FillingBar barCopy = FillingBar(
      total: outputFileCount(media, args["albums"]),
      desc: "${args['copy'] ? 'Copying' : 'Moving'} photos to output folder",
      width: barWidth,
    );

    if (args["dry-run"]) {
      print("DRY RUN MODE: No files will be moved or copied");
      print("Would process ${media.length} files");
      print('Would create ${outputFileCount(media, args['albums'])} output files');

      // Sample of what would happen
      final int sampleSize = media.length > 5 ? 5 : media.length;
      if (sampleSize > 0) {
        print("\nSample of files that would be processed:");
        for (int i = 0; i < sampleSize; i++) {
          final Media m = media[i];
          final String destPath = getDestinationPath(
            m,
            output,
            divideToDates: args["divide-to-dates"],
          );
          print("${m.firstFile.path} -> $destPath");
        }
      }

      print("\nDRY RUN COMPLETED");
    } else {
      await moveFiles(
        media,
        output,
        copy: args["copy"],
        divideToDates: args["divide-to-dates"],
        albumBehavior: args["albums"],
      ).listen((final _) => barCopy.increment()).asFuture();
    }
    print("");

    // @Deprecated('Interactive unzipping is suspended for now!')
    // // remove unzipped folder if was created
    // if (interactive.indeed) {
    //   print('Removing unzipped folder...');
    //   await input.delete(recursive: true);
    // }

    /// ###################################################

    print("=" * barWidth);
    print("DONE! FREEEEEDOOOOM!!!");
    if (countDuplicates > 0) print("Skipped $countDuplicates duplicates");
    if (args["skip-extras"]) print("Skipped $countExtras extras");
    final int countPoop = media.where((Media final e) => e.dateTaken == null).length;
    if (countPoop > 0) {
      print(errorNoMediaFound.replaceFirst("%d", countPoop.toString()));
    }
    print("");
    print(
      "Last thing - I've spent *a ton* of time on this script - \n"
      'if I saved your time and you want to say thanks, you can send me a tip:\n'
      'https://www.paypal.me/TheLastGimbus\n'
      'https://ko-fi.com/thelastgimbus\n'
      'Thank you ❤',
    );
    print("=" * barWidth);
    quit(0);
  } catch (e, stackTrace) {
    _logger.severe("Fatal error: $e", stackTrace);
    error("A fatal error occurred. Check the logs for details.");
    quit();
  }
}
