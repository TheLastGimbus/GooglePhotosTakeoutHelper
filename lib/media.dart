import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:gpth/utils.dart';

/// Abstract of a *media* - a photo or video
/// Main thing is the [file] - this should not change
///
/// [size] and [hash] getter are here because we can easily cache
///
/// [dateTakenAccuracy] is a number used to compare with other [Media]. When
/// you find a duplicate, use one that has lower [dateTakenAccuracy] number.
/// this and [dateTaken] should either both be null or both filled
class Media {
  /// File with the media
  File file;

  /// Names of the albums this media belongs to
  ///
  /// This is heavily mutated - at first, media from year folders have this
  /// null, and those from albums have one name. Then, they are merged into one
  /// by algos etc.
  Set<String>? albums;

  // cache
  int? _size;

  /// will be used for finding duplicates/albums
  int get size => _size ??= file.lengthSync();

  /// DateTaken from any source
  DateTime? dateTaken;

  /// higher the worse
  int? dateTakenAccuracy;

  //cache
  Digest? _hash;

  /// will be used for finding duplicates/albums
  /// WARNING: Returns same value for files > [maxFileSize]
  Digest get hash => _hash ??= file.lengthSync() > maxFileSize
      ? Digest([0])
      : sha256.convert(file.readAsBytesSync());

  Media(
    this.file, {
    this.albums,
    this.dateTaken,
    this.dateTakenAccuracy,
  });

  @override
  String toString() => 'Media('
      '$file, '
      'dateTaken: $dateTaken'
      '${albums != null ? ', albums: $albums' : ''}'
      ')';
}
