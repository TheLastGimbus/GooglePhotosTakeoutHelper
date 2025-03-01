import "dart:io";
import 'dart:typed_data';

import "package:crypto/crypto.dart";
import "utils.dart";
import "package:logging/logging.dart";
import "gps_extractor.dart";

final Logger _logger = Logger("Media");

/// Abstract of a *media* - a photo or video.
/// Main thing is the [file] - this should not change.
///
/// [size] and [hash] getter are here because we can easily cache.
///
/// [dateTakenAccuracy] is a number used to compare with other [Media]. When
/// you find a duplicate, use one that has lower [dateTakenAccuracy] number.
/// This and [dateTaken] should either both be null or both filled.
class Media {

  Media(
    this.files, {
    this.dateTaken,
    this.dateTakenAccuracy,
    this.gpsData,
  });
  /// First file with media, used in early stage when albums are not merged.
  ///
  /// BE AWARE OF HOW YOU USE IT.
  File get firstFile => files.values.first;

  /// Map between albums and files of same given media.
  ///
  /// This is heavily mutated - at first, media from year folders have this
  /// with single null key, and those from albums have one name.
  /// Then, they are merged into one by algorithms etc.
  ///
  /// At the end of the script, this will have *all* locations of given media,
  /// so that we can safely:
  /// ```dart
  /// // photo.runtimeType == Media;
  /// photo.files[null].move('output/one-big/');  // null is for year folders
  /// photo.files[<album_name>].move('output/albums/<album_name>/');
  /// ```
  Map<String?, File> files;

  // Cache for size
  int? _size;

  /// Will be used for finding duplicates/albums.
  int get size => _size ??= firstFile.lengthSync();

  /// DateTaken from any source.
  DateTime? dateTaken;

  /// Higher the worse.
  int? dateTakenAccuracy;

  /// GPS coordinates data from JSON or EXIF
  GpsData? gpsData;

  // Cache for hash
  Digest? _hash;

  /// Will be used for finding duplicates/albums.
  /// WARNING: Returns same value for files > [maxFileSize].
  Digest get hash {
    if (_hash != null) return _hash!;

    final int fileSize = firstFile.lengthSync();
    if (fileSize > maxFileSize) {
      // For large files, use a combination of file size and first/last block hash
      // to reduce the chance of false duplicates
      try {
        final RandomAccessFile file = firstFile.openSync();
        final Uint8List firstBlock = file.readSync(4096); // Read first 4KB

        // Read last 4KB if file is large enough
        if (fileSize > 8192) {
          try {
            file.setPositionSync(fileSize - 4096);
            final Uint8List lastBlock = file.readSync(4096);
            file.closeSync();

            // Combine file size with hash of first and last blocks
            final List<int> combinedBytes = <int>[...firstBlock, ...lastBlock];
            _hash = sha256.convert(combinedBytes);
            return _hash!;
          } catch (e) {
            // If reading the last block fails, just use the first block
            file.closeSync();
            _logger.warning("Failed to read last block of ${firstFile.path}: $e");
            _hash = sha256.convert(firstBlock);
            return _hash!;
          }
        }

        file.closeSync();
        _hash = sha256.convert(firstBlock);
        return _hash!;
      } catch (e) {
        // Fallback to default hash if reading fails
        _logger.severe("Failed to calculate hash for ${firstFile.path}: $e");
        _hash = Digest(<int>[0]);
        return _hash!;
      }
    }

    try {
      // For smaller files, read the entire file
      _hash = sha256.convert(firstFile.readAsBytesSync());
      return _hash!;
    } catch (e) {
      _logger.severe("Failed to calculate hash for ${firstFile.path}: $e");
      _hash = Digest(<int>[0]);
      return _hash!;
    }
  }

  @override
  String toString() => "Media("
      "$firstFile, "
      "dateTaken: $dateTaken"
      '${gpsData != null ? ', gpsData: $gpsData' : ''}'
      '${files.keys.length > 1 ? ', albums: ${files.keys}' : ''}'
      ")";
}

/// Utility function to create a Media object from a single file.
Future<Media> createMediaFromFile(final File file) async {
  final Map<Null, File> files = <Null, File>{null: file};
  return Media(files);
}

/// Utility function to create a Media object from a list of files.
Future<Media> createMediaFromFiles(final List<File> files) async {
  final Map<dynamic, File> fileMap = <, File>{for (File file in files) p.basename(file.path): file};
  return Media(fileMap);
}
