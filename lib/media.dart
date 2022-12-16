import 'dart:io';

import 'package:crypto/crypto.dart';

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
  Digest get hash => _hash ??= sha256.convert(file.readAsBytesSync());

  Media(this.file, {this.dateTaken, this.dateTakenAccuracy});

  @override
  String toString() => 'Media($file, dateTaken: $dateTaken)';
}
