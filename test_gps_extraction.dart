import "dart:io";
import "dart:convert";

void main() {
  // Create a sample JSON file with GPS data
  final Map<String, Object> jsonContent = <String, Object>{
    'title': 'Sample Photo',
    'photoTakenTime': <String, String>{
      'timestamp': '1599078832',
      'formatted': 'Sep 2, 2020, 5:00:32 PM UTC'
    },
    'geoData': <String, num>{
      'latitude': 37.7749,
      'longitude': -122.4194,
      'altitude': 0,
      'latitudeSpan': 0.1,
      'longitudeSpan': 0.1
    },
    'geoDataExif': <String, num>{
      'latitude': 37.7749,
      'longitude': -122.4194,
      'altitude': 0,
      'latitudeSpan': 0.1,
      'longitudeSpan': 0.1
    }
  };

  // Write the JSON to a file
  final File jsonFile = File("test_photo.json");
  jsonFile.writeAsStringSync(json.encode(jsonContent));

  print("Created test_photo.json with GPS data:");
  print('Latitude: ${jsonContent['geoData']['latitude']}');
  print('Longitude: ${jsonContent['geoData']['longitude']}');
  print('Altitude: ${jsonContent['geoData']['altitude']}');

  print("\nTo test GPS extraction, you would need to run:");
  print("dart bin/gpth.dart --input . --write-exif");

  print("\nSince Dart is not installed, you can verify the JSON structure:");
  print(json.encode(jsonContent));
}
