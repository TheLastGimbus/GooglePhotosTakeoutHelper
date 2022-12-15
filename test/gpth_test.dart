import 'dart:io';

import 'package:gpth/album.dart';
import 'package:gpth/datetime_extractors.dart';
import 'package:gpth/duplicate.dart';
import 'package:gpth/media.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  final albumDir = Directory('Vacation');
  final imgFile1 = File('image.jpg');
  final jsonFile1 = File('image.jpg.json');
  final imgFile2 = File('verylongverylong.jpg');
  final jsonFile2 = File('verylongverylon.json');
  final media = [
    Media(imgFile1, dateTaken: DateTime(2020, 9, 1), dateTakenAccuracy: 1),
    Media(imgFile2, dateTaken: DateTime(2020), dateTakenAccuracy: 2),
  ];
  setUpAll(() {
    albumDir.createSync(recursive: true);
    imgFile1.createSync();
    imgFile1.copySync('${albumDir.path}/${basename(imgFile1.path)}');
    imgFile2.createSync();
    jsonFile1.createSync();
    jsonFile1
        .writeAsStringSync('{"photoTakenTime": {"timestamp": "1599078832"}}');
    jsonFile2
        .writeAsStringSync('{"photoTakenTime": {"timestamp": "1683078832"}}');
  });
  test('test json extractor', () {
    expect(jsonExtractor(imgFile1)?.millisecondsSinceEpoch, 1599078832 * 1000);
    expect(jsonExtractor(imgFile2)?.millisecondsSinceEpoch, 1683078832 * 1000);
  });

  test('test duplicate removal', () {
    expect(removeDuplicates(media), 1);
    expect(media.length, 1);
    expect(media.first.file, imgFile1);
  });
  test('test album finding', () {
    expect(findAlbums([albumDir], media), [
      Album('Vacation', [media.first])
    ]);
  });
  tearDownAll(() {
    albumDir.deleteSync(recursive: true);
    imgFile1.deleteSync();
    imgFile2.deleteSync();
    jsonFile1.deleteSync();
    jsonFile2.deleteSync();
  });
}
