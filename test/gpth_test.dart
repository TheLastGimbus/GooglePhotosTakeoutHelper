import 'dart:convert';
import 'dart:io';

import 'package:gpth/album.dart';
import 'package:gpth/date_extractor.dart';
import 'package:gpth/duplicate.dart';
import 'package:gpth/extras.dart';
import 'package:gpth/folder_classify.dart';
import 'package:gpth/media.dart';
import 'package:gpth/utils.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  /// this is 1x1 green jg image, with exif:
  /// DateTime Original: 2022:12:16 16:06:47
  const greenImgBase64 = """
/9j/4AAQSkZJRgABAQAAAQABAAD/4QC4RXhpZgAATU0AKgAAAAgABQEaAAUAAAABAAAASgEbAAUA
AAABAAAAUgEoAAMAAAABAAEAAAITAAMAAAABAAEAAIdpAAQAAAABAAAAWgAAAAAAAAABAAAAAQAA
AAEAAAABAAWQAAAHAAAABDAyMzKQAwACAAAAFAAAAJyRAQAHAAAABAECAwCgAAAHAAAABDAxMDCg
AQADAAAAAf//AAAAAAAAMjAyMjoxMjoxNiAxNjowNjo0NwD/2wBDAAMCAgICAgMCAgIDAwMDBAYE
BAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQD
BAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ
EBD/wAARCAABAAEDAREAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAAA//EABQQAQAAAAAAAAAA
AAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAI/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAwD
AQACEQMRAD8AIcgXf//Z""";

  final albumDir = Directory('Vacation');
  final imgFileGreen = File('green.jpg');
  final imgFile1 = File('image-edited.jpg');
  final jsonFile1 = File('image-edited.jpg.json');
  // these names are from good old #8 issue...
  final imgFile2 = File('Urlaub in Knaufspesch in der Schneifel (38).JPG');
  final jsonFile2 = File('Urlaub in Knaufspesch in der Schneifel (38).JP.json');
  final imgFile3 = File('Screenshot_2022-10-28-09-31-43-118_com.snapchat.jpg');
  final jsonFile3 = File('Screenshot_2022-10-28-09-31-43-118_com.snapcha.json');
  final imgFile4 = File('simple_file_20200101-edited.jpg');
  final imgFile4_1 = File('simple_file_20200101-edited(1).jpg');
  final jsonFile4 = File('simple_file_20200101.jpg.json');
  final media = [
    Media(imgFile1, dateTaken: DateTime(2020, 9, 1), dateTakenAccuracy: 1),
    Media(imgFile2, dateTaken: DateTime(2020), dateTakenAccuracy: 2),
    Media(imgFile3, dateTaken: DateTime(2022, 10, 28), dateTakenAccuracy: 1),
  ];

  /// Set up test stuff - create test shitty files in wherever pwd is
  /// We don't worry because we'll delete them later
  setUpAll(() {
    albumDir.createSync(recursive: true);
    imgFileGreen.createSync();
    imgFileGreen.writeAsBytesSync(
      base64.decode(greenImgBase64.replaceAll('\n', '')),
    );
    // apparently you don't need to .create() before writing 👍
    imgFile1.writeAsBytesSync([1, 2, 3]); // those two...
    imgFile1.copySync('${albumDir.path}/${basename(imgFile1.path)}');
    imgFile2.writeAsBytesSync([1, 2, 3]); // are actual duplicates
    imgFile3.writeAsBytesSync([3, 2, 1]); // and this one is different
    writeJson(File file, int time) =>
        file.writeAsStringSync('{"photoTakenTime": {"timestamp": "$time"}}');
    writeJson(jsonFile1, 1599078832);
    writeJson(jsonFile2, 1683078832);
    writeJson(jsonFile3, 1666942303);
    writeJson(jsonFile4, 1683074444);
  });

  group('DateTime extractors', () {
    test('test json extractor', () async {
      expect((await jsonExtractor(imgFile1))?.millisecondsSinceEpoch,
          1599078832 * 1000);
      expect((await jsonExtractor(imgFile2))?.millisecondsSinceEpoch,
          1683078832 * 1000);
      expect((await jsonExtractor(imgFile3))?.millisecondsSinceEpoch,
          1666942303 * 1000);
      expect((await jsonExtractor(imgFile4))?.millisecondsSinceEpoch,
          1683074444 * 1000);
      expect((await jsonExtractor(imgFile4_1))?.millisecondsSinceEpoch,
          1683074444 * 1000);
    });
    test('test exif extractor', () async {
      expect(
        (await exifExtractor(imgFileGreen)),
        DateTime.parse('2022-12-16 16:06:47'),
      );
    });
    test('test guess extractor', () async {
      final files = [
        ['Screenshot_20190919-053857_Camera-edited.jpg', '2019-09-19 05:38:57'],
        ['MVIMG_20190215_193501.MP4', '2019-02-15 19:35:01'],
        ['Screenshot_2019-04-16-11-19-37-232_com.jpg', '2019-04-16 11:19:37'],
        ['signal-2020-10-26-163832.jpg', '2020-10-26 16:38:32'],
        ['VID_20220107_113306.mp4', '2022-01-07 11:33:06'],
      ];
      for (final f in files) {
        expect((await guessExtractor(File(f.first))), DateTime.parse(f.last));
      }
    });
  });
  test('test duplicate removal', () {
    expect(removeDuplicates(media), 1);
    expect(media.length, 2);
    expect(media.first.file, imgFile1);
  });
  test('test extras removal', () {
    final m = [Media(imgFile1), Media(imgFile2)];
    expect(removeExtras(m), 1);
    expect(m.length, 1);
  });
  test('test album finding', () {
    expect(findAlbums([albumDir], media), [
      Album('Vacation', [media.first])
    ]);
  });
  group('utils test', () {
    test('test Stream.whereType()', () {
      final stream = Stream.fromIterable([1, 'a', 2, 'b', 3, 'c']);
      expect(stream.whereType<int>(), emitsInOrder([1, 2, 3, emitsDone]));
    });
    test('test Stream<FileSystemEntity>.wherePhotoVideo()', () {
      //    check if stream with random list of files is emitting only photos and videos
      //   use standard formats as jpg and mp4 but also rare ones like 3gp and eps
      final stream = Stream.fromIterable(<FileSystemEntity>[
        File('a.jpg'),
        File('lol.json'),
        File('b.mp4'),
        File('c.3gp'),
        File('e.png'),
        File('f.txt'),
      ]);
      expect(
        // looked like File()'s couldn't compare correctly :/
        stream.wherePhotoVideo().map((event) => event.path),
        emitsInOrder(['a.jpg', 'b.mp4', 'c.3gp', 'e.png', emitsDone]),
      );
    });
    test('test findNotExistingName()', () {
      expect(findNotExistingName(imgFileGreen).path, 'green(1).jpg');
      expect(findNotExistingName(File('not-here.jpg')).path, 'not-here.jpg');
    });
    test('test getDiskFree()', () async {
      expect(await getDiskFree('.'), isNotNull);
    });
    test('test isArchived() and isTrashed() on jsons', () {
      final normalJson = '''{ "title": "example.jpg",
        "photoTakenTime": {"timestamp": "1663252650"},
        "photoLastModifiedTime": {"timestamp": "1673339757"} 
      }''';
      final archivedJson = '''{ "title": "example.jpg",
        "photoTakenTime": {"timestamp": "1663252650"},
        "archived": true,
        "photoLastModifiedTime": {"timestamp": "1673339757"} 
      }''';
      final trashedJson = '''{ "title": "example.jpg",
        "photoTakenTime": {"timestamp": "1663252650"},
        "trashed": true,
        "photoLastModifiedTime": {"timestamp": "1673339757"} 
      }''';
      final albumJson =
          '{"title": "Green", "description": "","access": "protected"}';
      expect(jsonIsArchived(normalJson), false);
      expect(jsonIsTrashed(normalJson), false);
      expect(jsonIsArchived(archivedJson), true);
      expect(jsonIsTrashed(archivedJson), false);
      expect(jsonIsArchived(trashedJson), false);
      expect(jsonIsTrashed(trashedJson), true);
      expect(jsonIsArchived(albumJson), null);
      expect(jsonIsTrashed(albumJson), null);
    });
  });

  /// Delete all shitty files as we promised
  tearDownAll(() {
    albumDir.deleteSync(recursive: true);
    imgFileGreen.deleteSync();
    imgFile1.deleteSync();
    imgFile2.deleteSync();
    imgFile3.deleteSync();
    jsonFile1.deleteSync();
    jsonFile2.deleteSync();
    jsonFile3.deleteSync();
    jsonFile4.deleteSync();
  });
}
