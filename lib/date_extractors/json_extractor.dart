import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gpth/extras.dart' as extras;
import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Finds corresponding json file with info and gets 'photoTakenTime' from it
Future<DateTime?> jsonExtractor(File file, {bool tryhard = false}) async {
  final jsonFile = await _jsonForFile(file, tryhard: tryhard);
  if (jsonFile == null) return null;
  try {
    final data = jsonDecode(await jsonFile.readAsString());
    final epoch = int.parse(data['photoTakenTime']['timestamp'].toString());
    return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
  } on FormatException catch (_) {
    // this is when json is bad
    return null;
  } on FileSystemException catch (_) {
    // this happens for issue #143
    // "Failed to decode data using encoding 'utf-8'"
    // maybe this will self-fix when dart itself support more encodings
    return null;
  } on NoSuchMethodError catch (_) {
    // this is when tags like photoTakenTime aren't there
    return null;
  }
}

Future<File?> _jsonForFile(File file, {required bool tryhard}) async {
  final dir = Directory(p.dirname(file.path));
  var name = p.basename(file.path);
  // will try all methods to strip name to find json
  for (final method in [
    // none
    (String s) => s,
    _shortenName,
    // test: combining this with _shortenName?? which way around?
    _bracketSwap,
    _removeExtra,
    _noExtension,
    // use those two only with tryhard
    // look at https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/175
    // thanks @denouche for reporting this!
    if (tryhard) ...[
      _removeExtraRegex,
      _removeDigit, // most files with '(digit)' have jsons, so it's last
    ]
  ]) {
    final jsonFile = File(p.join(dir.path, '${method(name)}.json'));
    if (await jsonFile.exists()) return jsonFile;
  }
  return null;
}

// if the originally file was uploaded without an extension, 
// (for example, "20030616" (jpg but without ext))
// it's json won't have the extension ("20030616.json"), but the image
// itself (after google proccessed it) - will ("20030616.jpg" tadam)
String _noExtension(String filename) =>
    p.basenameWithoutExtension(File(filename).path);

String _removeDigit(String filename) =>
    filename.replaceAll(RegExp(r'\(\d\)\.'), '.');

/// This removes only strings defined in [extraFormats] list from `extras.dart`,
/// so it's pretty safe
String _removeExtra(String filename) {
  // MacOS uses NFD that doesn't work with our accents 🙃🙃
  // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/pull/247
  filename = unorm.nfc(filename);
  for (final extra in extras.extraFormats) {
    if (filename.contains(extra)) {
      return filename.replaceLast(extra, '');
    }
  }
  return filename;
}

/// this will match:
/// ```
///        '.extension' v  v end of string
/// something-edited(1).jpg
///        extra ^   ^ optional number in '()'
///
/// Result: something.jpg
/// ```
/// so it's *kinda* safe
String _removeExtraRegex(String filename) {
  // MacOS uses NFD that doesn't work with our accents 🙃🙃
  // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/pull/247
  filename = unorm.nfc(filename);
  // include all characters, also with accents
  final matches = RegExp(r'(?<extra>-[A-Za-zÀ-ÖØ-öø-ÿ]+(\(\d\))?)\.\w+$')
      .allMatches(filename);
  if (matches.length == 1) {
    return filename.replaceAll(matches.first.namedGroup('extra')!, '');
  }
  return filename;
}

// this resolves years of bugs and head-scratches 😆
// f.e: https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/8#issuecomment-736539592
String _shortenName(String filename) => '$filename.json'.length > 51
    ? filename.substring(0, 51 - '.json'.length)
    : filename;

// thanks @casualsailo and @denouche for bringing attention!
// https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/188
// and https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/175
// issues helped to discover this
/// Some (actually quite a lot of) files go like:
/// image(11).jpg -> image.jpg(11).json
/// (swapped number in brackets)
///
/// This function does just that, and by my current intuition tells me it's
/// pretty safe to use so I'll put it without the tryHard flag
// note: would be nice if we had some tougher tests for this
String _bracketSwap(String filename) {
  // this is with the dot - more probable that it's just before the extension
  final match = RegExp(r'\(\d+\)\.').allMatches(filename).lastOrNull;
  if (match == null) return filename;
  final bracket = match.group(0)!.replaceAll('.', ''); // remove dot
  // remove only last to avoid errors with filenames like:
  // 'image(3).(2)(3).jpg' <- "(3)." repeats twice
  final withoutBracket = filename.replaceLast(bracket, '');
  return '$withoutBracket$bracket';
}
