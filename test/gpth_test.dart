import "dart:convert";
import "dart:io";

import "package:collection/collection.dart";
import "package:gpth/date_extractor.dart";
import "package:gpth/extras.dart";
import "package:gpth/folder_classify.dart";
import "package:gpth/grouping.dart";
import "package:gpth/media.dart";
import "package:gpth/moving.dart";
import "package:gpth/utils.dart";
import "package:path/path.dart";
import "package:test/test.dart";

void main() {
  /// this is 1x1 green jpg image, with exif:
  /// DateTime Original: 2022:12:16 16:06:47
  const String greenImgBase64 = '''
/9j/4AAQSkZJRgABAQAAAQABAAD/4QC4RXhpZgAATU0AKgAAAAgABQEaAAUAAAABAAAASgEbAAUA
AAABAAAAUgEoAAMAAAABAAEAAAITAAMAAAABAAEAAIdpAAQAAAABAAAAWgAAAAAAAAABAAAAAQAA
AAEAAAABAAWQAAAHAAAABDAyMzKQAwACAAAAFAAAAJyRAQAHAAAABAECAwCgAAAHAAAABDAxMDCg
AQADAAAAAf//AAAAAAAAMjAyMjoxMjoxNiAxNjowNjo0NwD/2wBDAAMCAgICAgMCAgIDAwMDBAYE
BAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQD
BAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ
EBD/wAARCAABAAEDAREAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAAA//EABQQAQAAAAAAAAAA
AAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAI/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAwD
AQACEQMRAD8AIcgXf//Z''';

  final Directory albumDir = Directory("Vacation");
  final File imgFileGreen = File("green.jpg");
  final File imgFile1 = File("image-edited.jpg");
  final File jsonFile1 = File("image-edited.jpg.json");
  // these names are from good old #8 issue...
  final File imgFile2 = File("Urlaub in Knaufspesch in der Schneifel (38).JPG");
  final File jsonFile2 = File("Urlaub in Knaufspesch in der Schneifel (38).JP.json");
  final File imgFile3 = File("Screenshot_2022-10-28-09-31-43-118_com.snapchat.jpg");
  final File jsonFile3 = File("Screenshot_2022-10-28-09-31-43-118_com.snapcha.json");
  final File imgFile4 = File("simple_file_20200101-edited.jpg");
  final File imgFile4_1 = File("simple_file_20200101-edited(1).jpg");
  final File jsonFile4 = File("simple_file_20200101.jpg.json");
  final File imgFile5 = File("img_(87).(vacation stuff).lol(87).jpg");
  final File jsonFile5 = File("img_(87).(vacation stuff).lol.jpg(87).json");
  final File imgFile6 = File("IMG-20150125-WA0003-modifié.jpg");
  final File imgFile6_1 = File("IMG-20150125-WA0003-modifié(1).jpg");
  final File jsonFile6 = File("IMG-20150125-WA0003.jpg.json");
  final List<Media> media = <Media>[
    Media(<String?, File>{null: imgFile1},
        dateTaken: DateTime(2020, 9), dateTakenAccuracy: 1),
    Media(
      <String?, File>{albumName(albumDir): imgFile1},
      dateTaken: DateTime(2022, 9),
      dateTakenAccuracy: 2,
    ),
    Media(<String?, File>{null: imgFile2}, dateTaken: DateTime(2020), dateTakenAccuracy: 2),
    Media(<String?, File>{null: imgFile3},
        dateTaken: DateTime(2022, 10, 28), dateTakenAccuracy: 1),
    Media(<String?, File>{null: imgFile4}), // these two...
    // ...are duplicates
    Media(<String?, File>{null: imgFile4_1}, dateTaken: DateTime(2019), dateTakenAccuracy: 3),
    Media(<String?, File>{null: imgFile5}, dateTaken: DateTime(2020), dateTakenAccuracy: 1),
    Media(<String?, File>{null: imgFile6}, dateTaken: DateTime(2015), dateTakenAccuracy: 1),
    Media(<String?, File>{null: imgFile6_1}, dateTaken: DateTime(2015), dateTakenAccuracy: 1),
  ];

  /// Set up test stuff - create test files in the current directory
  setUpAll(() {
    albumDir.createSync(recursive: true);
    imgFileGreen.createSync();
    imgFileGreen.writeAsBytesSync(
      base64.decode(greenImgBase64.replaceAll("\n", "")),
    );
    // apparently you don't need to .create() before writing 👍
    imgFile1.writeAsBytesSync(<int>[0, 1, 2]);
    imgFile1.copySync("${albumDir.path}/${basename(imgFile1.path)}");
    imgFile2.writeAsBytesSync(<int>[3, 4, 5]);
    imgFile3.writeAsBytesSync(<int>[6, 7, 8]);
    imgFile4.writeAsBytesSync(<int>[9, 10, 11]); // these two...
    imgFile4_1.writeAsBytesSync(<int>[9, 10, 11]); // ...are duplicates
    imgFile5.writeAsBytesSync(<int>[12, 13, 14]);
    imgFile6.writeAsBytesSync(<int>[15, 16, 17]);
    imgFile6_1.writeAsBytesSync(<int>[18, 19, 20]);
    void writeJson(final File file, final int time) =>
        file.writeAsStringSync('{"photoTakenTime": {"timestamp": "$time"}}');
    writeJson(jsonFile1, 1599078832);
    writeJson(jsonFile2, 1683078832);
    writeJson(jsonFile3, 1666942303);
    writeJson(jsonFile4, 1683074444);
    writeJson(jsonFile5, 1680289442);
    writeJson(jsonFile6, 1422183600);
  });

  test("EXIF date extraction", () {
    final File testFile = File("test_data/image_with_exif.jpg");
    expect(extractDateFromExif(testFile), DateTime(2023, 1));
  });

  test("Filename date guessing", () {
    expect(guessDateFromFilename("IMG_20230101_123456.jpg"), DateTime(2023, 1, 1, 12, 34, 56));
  });

  group("DateTime extractors", () {
    test("json", () async {
      expect((await jsonExtractor(imgFile1))?.millisecondsSinceEpoch,
          1599078832 * 1000);
      expect((await jsonExtractor(imgFile2))?.millisecondsSinceEpoch,
          1683078832 * 1000);
      expect((await jsonExtractor(imgFile3))?.millisecondsSinceEpoch,
          1666942303 * 1000);
      // They *should* fail without tryhard
      // See b38efb5d / #175
      expect(
        (await jsonExtractor(imgFile4))?.millisecondsSinceEpoch,
        1683074444 * 1000,
      );
      expect((await jsonExtractor(imgFile4_1))?.millisecondsSinceEpoch, null);
      // Should work *with* tryhard
      expect(
        (await jsonExtractor(imgFile4, tryhard: true))?.millisecondsSinceEpoch,
        1683074444 * 1000,
      );
      expect(
        (await jsonExtractor(imgFile4_1, tryhard: true))
            ?.millisecondsSinceEpoch,
        1683074444 * 1000,
      );
      expect(
        (await jsonExtractor(imgFile5))?.millisecondsSinceEpoch,
        1680289442 * 1000,
      );
      expect(
        (await jsonExtractor(imgFile6))?.millisecondsSinceEpoch,
        1422183600 * 1000,
      );
      expect(
        (await jsonExtractor(imgFile6_1))
            ?.millisecondsSinceEpoch,
        null,
      );
      expect(
        (await jsonExtractor(imgFile6_1, tryhard: true))
            ?.millisecondsSinceEpoch,
        1422183600 * 1000,
      );
    });
    test("exif", () async {
      expect(
        await exifExtractor(imgFileGreen),
        DateTime.parse("2022-12-16 16:06:47"),
      );
    });
    test("guess", () async {
      final List<List<String>> files = <List<String>>[
        <String>["Screenshot_20190919-053857_Camera-edited.jpg", "2019-09-19 05:38:57"],
        <String>["MVIMG_20190215_193501.MP4", "2019-02-15 19:35:01"],
        <String>["Screenshot_2019-04-16-11-19-37-232_com.jpg", "2019-04-16 11:19:37"],
        <String>["signal-2020-10-26-163832.jpg", "2020-10-26 16:38:32"],
        <String>["VID_20220107_113306.mp4", "2022-01-07 11:33:06"],
        <String>["00004XTR_00004_BURST20190216172030.jpg", "2019-02-16 17:20:30"],
        <String>["00055IMG_00055_BURST20190216172030_COVER.jpg", "2019-02-16 17:20:30"],
        <String>["2016_01_30_11_49_15.mp4", "2016-01-30 11:49:15"],
        <String>["201801261147521000.jpg", "2018-01-26 11:47:52"],
        <String>["IMG_1_BURST20160623205107_COVER.jpg", "2016-06-23 20:51:07"],
        <String>["IMG_1_BURST20160520195318.jpg", "2016-05-20 19:53:18"],
        <String>["1990_06_16_07_30_00.jpg", "1990-06-16 07:30:00"],
        <String>["1869_12_30_16_59_57.jpg", "1869-12-30 16:59:57"],
      ];
      for (final List<String> f in files) {
        expect(await guessExtractor(File(f.first)), DateTime.parse(f.last));
      }
    });
  });
  test("Duplicate removal", () {
    expect(removeDuplicates(media), 1);
    expect(media.length, 8);
    expect(media.firstWhereOrNull((final Media e) => e.firstFile == imgFile4), null);
  });
  test("Extras removal", () {
    final List<Media> m = <Media>[
      Media(<String?, File>{null: imgFile1}),
      Media(<String?, File>{null: imgFile2}),
    ];
    expect(removeExtras(m), 1);
    expect(m.length, 1);
  });
  test("Album finding", () {
    // sadly, this will still modify [media] some, but won't delete anything
    final List<Media> copy = media.toList();
    removeDuplicates(copy);

    final int countBefore = copy.length;
    findAlbums(copy);
    expect(countBefore - copy.length, 1);

    final Media albumed = copy.firstWhere((final Media e) => e.files.length > 1);
    expect(albumed.files.keys, <String?>[null, "Vacation"]);
    expect(albumed.dateTaken, media[0].dateTaken);
    expect(albumed.dateTaken == media[1].dateTaken, false); // be sure
    expect(copy.where((final Media e) => e.files.length > 1).length, 1);
    // fails because Dart is no Rust :/
    // expect(media.where((e) => e.albums != null).length, 1);
  });
  group("Utils", () {
    test("Stream.whereType()", () {
      final Stream<Object> stream = Stream.fromIterable(<Object>[1, "a", 2, "b", 3, "c"]);
      expect(stream.whereType<int>(), emitsInOrder(<>[1, 2, 3, emitsDone]));
    });
    test("Stream<FileSystemEntity>.wherePhotoVideo()", () {
      //    check if stream with random list of files is emitting only photos and videos
      //   use standard formats as jpg and mp4 but also rare ones like 3gp and eps
      final Stream<FileSystemEntity> stream = Stream.fromIterable(<FileSystemEntity>[
        File("a.jpg"),
        File("lol.json"),
        File("b.mp4"),
        File("c.3gp"),
        File("e.png"),
        File("f.txt"),
      ]);
      expect(
        // looked like File()'s couldn't compare correctly :/
        stream.wherePhotoVideo().map((final File event) => event.path),
        emitsInOrder(<>["a.jpg", "b.mp4", "c.3gp", "e.png", emitsDone]),
      );
    });
    test("findNotExistingName()", () {
      expect(findNotExistingName(imgFileGreen).path, "green(1).jpg");
      expect(findNotExistingName(File("not-here.jpg")).path, "not-here.jpg");
    });
    test("getDiskFree()", () async {
      expect(await getDiskFree("."), isNotNull);
    });
  });
  group("folder_classify", () {
    final List<Directory> dirs = <Directory>[
      Directory("./Photos from 2025"),
      Directory("./Photos from 1969"),
      Directory("./Photos from vacation"),
      Directory("/tmp/very-random-omg"),
    ];
    setUpAll(() async {
      for (Directory d in dirs) {
        await d.create();
      }
    });
    test("is year/album folder", () async {
      expect(isYearFolder(dirs[0]), true);
      expect(isYearFolder(dirs[1]), true);
      expect(isYearFolder(dirs[2]), false);
      expect(await isAlbumFolder(dirs[2]), true);
      expect(await isAlbumFolder(dirs[3]), false);
    });
    tearDownAll(() async {
      for (Directory d in dirs) {
        await d.delete();
      }
    });
  });

  /// This is complicated, thus those test are not bullet-proof
  group("Moving logic", () {
    final Directory output = Directory(join(Directory.systemTemp.path, "testy-output"));
    setUp(() async {
      await output.create();
      removeDuplicates(media);
      findAlbums(media);
    });
    test("shortcut", () async {
      await moveFiles(
        media,
        output,
        copy: true,
        divideToDates: false,
        albumBehavior: "shortcut",
      ).toList();
      final Set<FileSystemEntity> outputted =
          await output.list(recursive: true, followLinks: false).toSet();
      // 2 folders + media + 1 album-ed shortcut
      expect(outputted.length, 2 + media.length + 1);
      expect(outputted.whereType<Link>().length, 1);
      expect(
        outputted.whereType<Directory>().map((final Directory e) => basename(e.path)).toSet(),
        <String>{"ALL_PHOTOS", "Vacation"},
      );
    });
    test("nothing", () async {
      await moveFiles(
        media,
        output,
        copy: true,
        divideToDates: false,
        albumBehavior: "nothing",
      ).toList();
      final Set<FileSystemEntity> outputted =
          await output.list(recursive: true, followLinks: false).toSet();
      // 1 folder + media
      expect(outputted.length, 1 + media.length);
      expect(outputted.whereType<Link>().length, 0);
      expect(outputted.whereType<Directory>().length, 1);
      expect(
        outputted.whereType<Directory>().map((final Directory e) => basename(e.path)).toSet(),
        <String>{"ALL_PHOTOS"},
      );
    });
    test("duplicate-copy", () async {
      await moveFiles(
        media,
        output,
        copy: true,
        divideToDates: false,
        albumBehavior: "duplicate-copy",
      ).toList();
      final Set<FileSystemEntity> outputted =
          await output.list(recursive: true, followLinks: false).toSet();
      // 2 folders + media + 1 album-ed copy
      expect(outputted.length, 2 + media.length + 1);
      expect(outputted.whereType<Link>().length, 0);
      expect(outputted.whereType<Directory>().length, 2);
      expect(outputted.whereType<File>().length, media.length + 1);
      expect(
        const UnorderedIterableEquality<String>().equals(
          outputted.whereType<File>().map((final File e) => basename(e.path)),
          <String>[
            'image-edited.jpg',
            'image-edited.jpg', // two times
            'Screenshot_2022-10-28-09-31-43-118_com.snapchat.jpg',
            'simple_file_20200101-edited(1).jpg',
            'Urlaub in Knaufspesch in der Schneifel (38).JPG',
            'img_(87).(vacation stuff).lol(87).jpg',
            'IMG-20150125-WA0003-modifié.jpg',
            'IMG-20150125-WA0003-modifié(1).jpg',
          ],
        ),
        true,
      );
      expect(
        outputted.whereType<Directory>().map((final Directory e) => basename(e.path)).toSet(),
        <String>{"ALL_PHOTOS", "Vacation"},
      );
    });
    test("json", () async {
      await moveFiles(
        media,
        output,
        copy: true,
        divideToDates: false,
        albumBehavior: "json",
      ).toList();
      final Set<FileSystemEntity> outputted =
          await output.list(recursive: true, followLinks: false).toSet();
      // 1 folder + media + 1 json
      expect(outputted.length, 1 + media.length + 1);
      expect(outputted.whereType<Link>().length, 0);
      expect(outputted.whereType<Directory>().length, 1);
      expect(outputted.whereType<File>().length, media.length + 1);
      expect(
        const UnorderedIterableEquality<String>().equals(
          outputted.whereType<File>().map((final File e) => basename(e.path)),
          <String>[
            'image-edited.jpg',
            'Screenshot_2022-10-28-09-31-43-118_com.snapchat.jpg',
            'simple_file_20200101-edited(1).jpg',
            'Urlaub in Knaufspesch in der Schneifel (38).JPG',
            'albums-info.json',
            'img_(87).(vacation stuff).lol(87).jpg',
            'IMG-20150125-WA0003-modifié.jpg',
            'IMG-20150125-WA0003-modifié(1).jpg',
          ],
        ),
        true,
      );
      expect(
        outputted.whereType<Directory>().map((final Directory e) => basename(e.path)).toSet(),
        <String>{"ALL_PHOTOS"},
      );
    });
    tearDown(() async => output.delete(recursive: true));
  });

  /// Delete all test files as we promised
  tearDownAll(() {
    albumDir.deleteSync(recursive: true);
    imgFileGreen.deleteSync();
    imgFile1.deleteSync();
    imgFile2.deleteSync();
    imgFile3.deleteSync();
    imgFile4.deleteSync();
    imgFile4_1.deleteSync();
    imgFile5.deleteSync();
    imgFile6.deleteSync();
    imgFile6_1.deleteSync();
    jsonFile1.deleteSync();
    jsonFile2.deleteSync();
    jsonFile3.deleteSync();
    jsonFile4.deleteSync();
    jsonFile5.deleteSync();
    jsonFile6.deleteSync();
  });
}
