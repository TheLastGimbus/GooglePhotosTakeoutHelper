import 'dart:ffi';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gpth/interactive.dart' as interactive;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:proper_filesize/proper_filesize.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'media.dart';

// remember to bump this
const version = '3.4.3';

/// max file size to read for exif/hash/anything
const maxFileSize = 64 * 1024 * 1024;

/// convenient print for errors
void error(Object? object) => stderr.write('$object\n');

Never quit([int code = 1]) {
  if (interactive.indeed) {
    print('[gpth ${code != 0 ? 'quitted :(' : 'finished :)'} (code $code) - '
        'press enter to close]');
    stdin.readLineSync();
  }
  exit(code);
}

extension X on Iterable<FileSystemEntity> {
  /// Easy extension allowing you to filter for files that are photo or video
  Iterable<File> wherePhotoVideo() => whereType<File>().where((e) {
        final mime = lookupMimeType(e.path) ?? "";
        return mime.startsWith('image/') ||
            mime.startsWith('video/') ||
            // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/223
            // https://github.com/dart-lang/mime/issues/102
            // 🙃🙃
            mime == 'model/vnd.mts';
      });
}

extension Y on Stream<FileSystemEntity> {
  /// Easy extension allowing you to filter for files that are photo or video
  Stream<File> wherePhotoVideo() => whereType<File>().where((e) {
        final mime = lookupMimeType(e.path) ?? "";
        return mime.startsWith('image/') ||
            mime.startsWith('video/') ||
            // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/223
            // https://github.com/dart-lang/mime/issues/102
            // 🙃🙃
            mime == 'model/vnd.mts';
      });
}

extension Util on Stream {
  Stream<T> whereType<T>() => where((e) => e is T).cast<T>();
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

Future<int?> _dfLinux(String path) async {
  final res = await Process.run('df', ['-B1', '--output=avail', path]);
  return res.exitCode != 0
      ? null
      : int.tryParse(
          res.stdout.toString().split('\n').elementAtOrNull(1) ?? '',
          radix: 10, // to be sure
        );
}

Future<int?> _dfWindoza(String path) async {
  final res = await Process.run('wmic', [
    'LogicalDisk',
    'Where',
    'DeviceID="${p.rootPrefix(p.absolute(path)).replaceAll('\\', '')}"',
    'Get',
    'FreeSpace'
  ]);
  return res.exitCode != 0
      ? null
      : int.tryParse(
          res.stdout.toString().split('\n').elementAtOrNull(1) ?? '',
        );
}

Future<int?> _dfMcOS(String path) async {
  final res = await Process.run('df', ['-k', path]);
  if (res.exitCode != 0) return null;
  final line2 = res.stdout.toString().split('\n').elementAtOrNull(1);
  if (line2 == null) return null;
  final elements = line2.split(' ')..removeWhere((e) => e.isEmpty);
  final macSays = int.tryParse(
    elements.elementAtOrNull(3) ?? '',
    radix: 10, // to be sure
  );
  return macSays != null ? macSays * 1024 : null;
}

String filesize(int bytes) => ProperFilesize.generateHumanReadableFilesize(
      bytes,
      base: Bases.Binary,
      decimals: 2,
    );

int outputFileCount(List<Media> media, String albumOption) {
  if (['shortcut', 'duplicate-copy'].contains(albumOption)) {
    return media.fold(0, (prev, e) => prev + e.files.length);
  } else if (albumOption == 'json') {
    return media.length;
  } else if (albumOption == 'nothing') {
    return media.where((e) => e.files.containsKey(null)).length;
  } else {
    throw ArgumentError.value(albumOption, 'albumOption');
  }
}

extension Z on String {
  /// Returns same string if pattern not found
  String replaceLast(String from, String to) {
    final lastIndex = lastIndexOf(from);
    if (lastIndex == -1) return this;
    return replaceRange(lastIndex, lastIndex + from.length, to);
  }
}

void createShortcutWin(String shortcutPath, String targetPath) {
  Pointer<COMObject>? shellLink;
  Pointer<COMObject>? persistFile;
  Pointer<Utf16>? shortcutPathPtr;
  try {
      // Initialize the COM library on the current thread
    final hrInit = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hrInit)) {
      throw ('Error initializing COM: $hrInit');
    }

    shellLink = calloc<COMObject>();

    // Create IShellLink instance
    final hr = CoCreateInstance(
        GUIDFromString(CLSID_ShellLink).cast<GUID>(),
        nullptr,
        CLSCTX_INPROC_SERVER,
        GUIDFromString(IID_IShellLink).cast<GUID>(),
        shellLink.cast());

    if (FAILED(hr)) {
      throw ('Error creating IShellLink instance: $hr');
    }

    final shellLinkPtr = IShellLink(shellLink);
    shellLinkPtr.SetPath(targetPath.toNativeUtf16().cast());

    // Saving shortcut
    persistFile = calloc<COMObject>();
    final hrPersistFile = shellLinkPtr.QueryInterface(
        GUIDFromString(IID_IPersistFile).cast<GUID>(),
        persistFile.cast());
    if (FAILED(hrPersistFile)) {
      throw ('Error obtaining IPersistFile: $hrPersistFile');
    }
    final persistFilePtr = IPersistFile(persistFile);
    shortcutPathPtr = shortcutPath.toNativeUtf16();
    final hrSave = persistFilePtr.Save(shortcutPathPtr.cast(), TRUE);

    if (FAILED(hrSave)) {
      throw ('Error trying to save shortcut: $hrSave');
    } 
  } finally {
    // Free memory
    if (shortcutPathPtr != null) {
      free(shortcutPathPtr);
    }
    if (persistFile != null) {
      IPersistFile(persistFile).Release();
      free(persistFile);
    }
    if (shellLink != null) {
      IShellLink(shellLink).Release();
      free(shellLink);
    }
    CoUninitialize();
  }
}
