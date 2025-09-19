import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:gpth/date_extractors/json_extractor.dart';

void main() {
  group('Supplemental Metadata JSON Support', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gpth_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> createTestFiles(String imageName, String jsonSuffix, int timestamp) async {
      // Create test image file
      final imageFile = File(p.join(tempDir.path, imageName));
      await imageFile.writeAsString('test image content');

      // Create test JSON file with supplemental metadata suffix
      final jsonFile = File(p.join(tempDir.path, '$imageName$jsonSuffix'));
      final jsonContent = {
        'photoTakenTime': {
          'timestamp': timestamp.toString(),
        },
      };
      await jsonFile.writeAsString(jsonEncode(jsonContent));
    }

    test('should find full supplemental-metadata.json files', () async {
      await createTestFiles(
        'Photo0001.jpg',
        '.supplemental-metadata.json',
        1609459200, // 2021-01-01 00:00:00 UTC
      );

      final imageFile = File(p.join(tempDir.path, 'Photo0001.jpg'));
      final result = await jsonExtractor(imageFile);

      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, equals(1609459200000));
    });

    test('should find truncated .s.json files', () async {
      await createTestFiles(
        'Screenshot_20230417-090608_Call settings.jpg',
        '.s.json',
        1681718768, // 2023-04-17 09:06:08 UTC
      );

      final imageFile = File(p.join(tempDir.path, 'Screenshot_20230417-090608_Call settings.jpg'));
      final result = await jsonExtractor(imageFile);

      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, equals(1681718768000));
    });

    test('should find truncated .supple.json files', () async {
      await createTestFiles(
        'Screenshot_20230814-203649_Telegram.jpg',
        '.supple.json',
        1692044209, // 2023-08-14 20:36:49 UTC
      );

      final imageFile = File(p.join(tempDir.path, 'Screenshot_20230814-203649_Telegram.jpg'));
      final result = await jsonExtractor(imageFile);

      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, equals(1692044209000));
    });

    test('should find truncated .suppleme.json files', () async {
      await createTestFiles(
        'Screenshot_20230506-010055_Chrome.jpg',
        '.suppleme.json',
        1683338455, // 2023-05-06 01:00:55 UTC
      );

      final imageFile = File(p.join(tempDir.path, 'Screenshot_20230506-010055_Chrome.jpg'));
      final result = await jsonExtractor(imageFile);

      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, equals(1683338455000));
    });

    test('should still find regular .json files (backward compatibility)', () async {
      await createTestFiles(
        'OldPhoto.jpg',
        '.json',
        1577836800, // 2020-01-01 00:00:00 UTC
      );

      final imageFile = File(p.join(tempDir.path, 'OldPhoto.jpg'));
      final result = await jsonExtractor(imageFile);

      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, equals(1577836800000));
    });

    test('should prefer supplemental-metadata over regular json when both exist', () async {
      // Create image
      final imageFile = File(p.join(tempDir.path, 'Photo.jpg'));
      await imageFile.writeAsString('test image content');

      // Create regular .json with one timestamp
      final regularJson = File(p.join(tempDir.path, 'Photo.jpg.json'));
      await regularJson.writeAsString(jsonEncode({
        'photoTakenTime': {'timestamp': '1000000000'},
      }));

      // Create supplemental-metadata.json with different timestamp
      final supplementalJson = File(p.join(tempDir.path, 'Photo.jpg.supplemental-metadata.json'));
      await supplementalJson.writeAsString(jsonEncode({
        'photoTakenTime': {'timestamp': '2000000000'},
      }));

      final result = await jsonExtractor(imageFile);

      // Should use the supplemental-metadata timestamp (2000000000)
      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, equals(2000000000000));
    });

    test('should handle files without json metadata', () async {
      final imageFile = File(p.join(tempDir.path, 'NoMetadata.jpg'));
      await imageFile.writeAsString('test image content');

      final result = await jsonExtractor(imageFile);

      expect(result, isNull);
    });
  });
}