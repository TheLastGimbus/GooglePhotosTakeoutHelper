import "dart:io";
import "dart:math";

import "package:collection/collection.dart";
import "interactive.dart" as interactive;
import "package:mime/mime.dart";
import "package:path/path.dart" as p;
import "package:proper_filesize/proper_filesize.dart";

import "media.dart";

// remember to bump this
const String version = "3.4.3";

/// max file size to read for exif/hash/anything
const int maxFileSize = 64 * 1024 * 1024;

/// convenient print for errors
void error(final Object? object) => stderr.write("$object\n");

Never quit([final int code = 1]) {
  if (interactive.indeed) {
    print('[gpth ${code != 0 ? 'quitted :(' : 'finished :)'} (code $code) - '
        "press enter to close]");
    stdin.readLineSync();
  }
  exit(code);
}

extension X on Iterable<FileSystemEntity> {
  /// Easy extension allowing you to filter for files that are photo or video
  Iterable<File> wherePhotoVideo() => whereType<File>().where((final File e) {
        final String mime = lookupMimeType(e.path) ?? '';
        return mime.startsWith("image/") ||
            mime.startsWith("video/") ||
            // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/223
            // https://github.com/dart-lang/mime/issues/102
            // 🙃🙃
            mime == "model/vnd.mts";
      });
}

extension Y on Stream<FileSystemEntity> {
  /// Easy extension allowing you to filter for files that are photo or video
  Stream<File> wherePhotoVideo() => whereType<File>().where((final File e) {
        final String mime = lookupMimeType(e.path) ?? '';
        return mime.startsWith("image/") ||
            mime.startsWith("video/") ||
            // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/223
            // https://github.com/dart-lang/mime/issues/102
            // 🙃🙃
            mime == "model/vnd.mts";
      });
}

extension Util on Stream {
  Stream<T> whereType<T>() => where((final e) => e is T).cast<T>();
}

Future<int?> getDiskFree([String? path]) async {
  path ??= Directory.current.path;
  if (Platform.isLinux) {
    return _dfLinux(path);
  } else if (Platform.isWindows) {
    return _dfWindoza(path);
  } else if (Platform.isMacOS) {
    return _dfMcOS(path);
  } else {
    return null;
  }
}

Future<int?> _dfLinux(final String path) async {
  final ProcessResult res = await Process.run("df", <String>["-B1", "--output=avail", path]);
  return res.exitCode != 0
      ? null
      : int.tryParse(
          res.stdout.toString().split("\n").elementAtOrNull(1) ?? "",
          radix: 10, // to be sure
        );
}

Future<int?> _dfWindoza(final String path) async {
  final ProcessResult res = await Process.run("wmic", <String>[
    "LogicalDisk",
    "Where",
    'DeviceID="${p.rootPrefix(p.absolute(path)).replaceAll('\\', '')}"',
    "Get",
    "FreeSpace"
  ]);
  return res.exitCode != 0
      ? null
      : int.tryParse(
          res.stdout.toString().split("\n").elementAtOrNull(1) ?? "",
        );
}

Future<int?> _dfMcOS(final String path) async {
  final ProcessResult res = await Process.run("df", <String>["-k", path]);
  if (res.exitCode != 0) return null;
  final String? line2 = res.stdout.toString().split("\n").elementAtOrNull(1);
  if (line2 == null) return null;
  final List<String> elements = line2.split(" ")..removeWhere((final String e) => e.isEmpty);
  final int? macSays = int.tryParse(
    elements.elementAtOrNull(3) ?? "",
    radix: 10, // to be sure
  );
  return macSays != null ? macSays * 1024 : null;
}

String filesize(final int bytes) => ProperFilesize.generateHumanReadableFilesize(
      bytes,
      decimals: 2,
    );

int outputFileCount(final List<Media> media, final String albumOption) {
  if (<String>["shortcut", "duplicate-copy"].contains(albumOption)) {
    return media.fold(0, (int final prev, final Media e) => prev + e.files.length);
  } else if (albumOption == "json") {
    return media.length;
  } else if (albumOption == "nothing") {
    return media.where((final Media e) => e.files.containsKey(null)).length;
  } else {
    throw ArgumentError.value(albumOption, "albumOption");
  }
}

extension Z on String {
  /// Returns same string if pattern not found
  String replaceLast(final String from, final String to) {
    final int lastIndex = lastIndexOf(from);
    if (lastIndex == -1) return this;
    return replaceRange(lastIndex, lastIndex + from.length, to);
  }
}

String sanitizeFilename(final String name) {
  // Handle null or empty names
  if (name.isEmpty) {
    return 'unnamed_file';
  }

  // Remove reserved characters for Windows/macOS/Linux
  String sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), "_");

  // Replace control characters
  sanitized = sanitized.replaceAll(RegExp(r"[\x00-\x1F]"), "");

  // Replace leading/trailing spaces and dots
  sanitized = sanitized.trim().replaceAll(RegExp(r"^\.+|\.+$"), "");

  // Replace consecutive spaces with a single space
  sanitized = sanitized.replaceAll(RegExp(r"\s+"), " ");

  // Replace problematic characters that might cause issues on some filesystems
  sanitized = sanitized.replaceAll(RegExp(r"[^\w\s.\-()]"), "_");

  // Ensure the filename doesn't start with a dot (hidden file on Unix)
  if (sanitized.startsWith(".")) {
    sanitized = '_$sanitized';
  }

  // Truncate to avoid filesystem limits
  return sanitized.length <= 255 ? sanitized : sanitized.substring(0, 255);
}