import 'dart:convert';
import 'dart:io';

Future<DateTime?> jsonExtractor(File file) async {
  final jsonFile = _jsonForFile(file);
  if (jsonFile == null) return null;
  try {
    final data = jsonDecode(jsonFile.readAsStringSync());
    final epoch = int.parse(data['photoTakenTime']['timestamp'].toString());
    return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
  } on FormatException catch (_) {
    return null;
  } on NoSuchMethodError catch (_) {
    return null;
  }
}

File? _jsonForFile(File file, [bool goDumb = true]) {
  final correspondingJson = _normalJsonForFile(file);
  if (correspondingJson.existsSync()) {
    return correspondingJson;
  } else if (goDumb) {
    final dumbJson = _dumbJsonForFile(file);
    return dumbJson.existsSync() ? dumbJson : null;
  }
  return null;
}

File _normalJsonForFile(File file) => File('${file.path}.json');

File _dumbJsonForFile(File file) =>
    File('${file.path.substring(0, file.path.length - 5)}.json');
