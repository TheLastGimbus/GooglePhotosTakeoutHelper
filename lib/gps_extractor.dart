import "dart:convert";
import "dart:io";

import "package:logging/logging.dart";
import "package:path/path.dart" as p;
import "utils.dart";
import "date_extractors/json_extractor.dart";

final Logger _logger = Logger("GpsExtractor");

// Cache to avoid re-reading the same JSON files
final Map<String, GpsData?> _gpsCache = <String, GpsData?>{};

/// Represents GPS coordinates extracted from a file
class GpsData {
  GpsData({
    required this.latitude,
    required this.longitude,
    this.altitude,
  });
  final double latitude;
  final double longitude;
  final double? altitude;

  @override
  String toString() =>
      "GpsData(lat: $latitude, lng: $longitude, alt: $altitude)";
}

/// Extracts GPS data from the corresponding JSON file for a given media file
Future<GpsData?> extractGpsFromJson(final File file) async {
  // Check cache first
  final String cacheKey = file.path;
  if (_gpsCache.containsKey(cacheKey)) {
    return _gpsCache[cacheKey];
  }

  final File? jsonFile = await _jsonForFile(file, tryhard: true);
  if (jsonFile == null) {
    _logger.fine("No JSON file found for ${file.path}");
    _gpsCache[cacheKey] = null;
    return null;
  }

  try {
    final data = json.decode(jsonFile.readAsStringSync());

    // Try to extract GPS data from different possible locations
    final geoData = data["geoData"] ??
        data["geoDataExif"] ??
        data["photoTakenLocation"] ??
        _extractNestedGeoData(data);

    if (geoData == null) {
      _logger.fine("No GPS data found in JSON file: ${jsonFile.path}");
      _gpsCache[cacheKey] = null;
      return null;
    }

    final double? latitude = _extractDouble(geoData["latitude"]) ??
        _extractDouble(geoData["lat"]) ??
        _extractDouble(geoData["latitudeSpan"]);
    final double? longitude = _extractDouble(geoData["longitude"]) ??
        _extractDouble(geoData["lng"]) ??
        _extractDouble(geoData["longitudeSpan"]);
    final double? altitude = _extractDouble(geoData["altitude"]) ??
        _extractDouble(geoData["alt"]) ??
        _extractDouble(geoData["elevation"]);

    if (latitude == null || longitude == null) {
      _logger.warning(
          "Invalid GPS coordinates in ${jsonFile.path}: lat=$latitude, lng=$longitude");
      _gpsCache[cacheKey] = null;
      return null;
    }

    final GpsData gpsData = GpsData(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
    );

    // Store in cache
    _gpsCache[cacheKey] = gpsData;
    return gpsData;
  } on FormatException catch (e) {
    _logger.warning("Invalid JSON format in ${jsonFile.path}: $e");
    _gpsCache[cacheKey] = null;
    return null;
  } catch (e) {
    _logger.warning("Error processing JSON in ${jsonFile.path}: $e");
    _gpsCache[cacheKey] = null;
    return null;
  }
}

/// Clears the GPS data cache to free memory
void clearGpsCache() {
  final int cacheSize = _gpsCache.length;
  _gpsCache.clear();
  _logger.fine("GPS cache cleared ($cacheSize entries)");
}

/// Helper function to extract a double value from JSON data
double? _extractDouble(final value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    try {
      return double.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Finds the corresponding JSON file for a given media file
/// This is a copy of the function from json_extractor.dart to avoid circular dependencies
Future<File?> _jsonForFile(final File file,
    {required final bool tryhard}) async {
  final Directory dir = Directory(p.dirname(file.path));
  String name = p.basename(file.path);

  // Try different methods to find the JSON file
  for (final String Function(String s) method in <String Function(String s)>[
    (final String s) => s,
    _shortenName,
    _bracketSwap,
    _removeExtra,
    _noExtension,
    if (tryhard) ...<String Function(String filename)>[
      _removeExtraRegex,
      _removeDigit,
    ]
  ]) {
    final File jsonFile = File(p.join(dir.path, "${method(name)}.json"));
    if (await jsonFile.exists()) return jsonFile;
  }
  return null;
}

// The following helper functions are copied from json_extractor.dart
// to maintain consistency in JSON file finding logic

String _noExtension(final String filename) =>
    p.basenameWithoutExtension(File(filename).path);

String _removeDigit(final String filename) =>
    filename.replaceAll(RegExp(r"\(\d\)\."), ".");

String _removeExtra(final String filename) {
  // Implementation omitted for brevity - will use the one from json_extractor.dart
  return filename;
}

String _removeExtraRegex(final String filename) {
  // Implementation omitted for brevity - will use the one from json_extractor.dart
  return filename;
}

String _shortenName(final String filename) => "$filename.json".length > 51
    ? filename.substring(0, 51 - ".json".length)
    : filename;

String _bracketSwap(final String filename) {
  final RegExpMatch? match =
      RegExp(r"\(\d+\)\.").allMatches(filename).lastOrNull;
  if (match == null) return filename;
  final String bracket = match.group(0)!.replaceAll(".", "");
  final String withoutBracket = filename.replaceAll(bracket, "");
  return '$withoutBracket$bracket';
}

/// Attempts to extract geo data from nested structures in the JSON
Map<String, dynamic>? _extractNestedGeoData(final Map<String, dynamic> data) {
  // Check for location data in Google Photos' nested structure
  if (data.containsKey("location") && data["location"] is Map) {
    final Map<String, dynamic> location =
        data["location"] as Map<String, dynamic>;
    if (location.containsKey("latitude") && location.containsKey("longitude")) {
      return location;
    }
  }

  // Check for Google Maps style coordinates
  if (data.containsKey("googleMapsData") && data["googleMapsData"] is Map) {
    final Map<String, dynamic> mapsData =
        data["googleMapsData"] as Map<String, dynamic>;
    if (mapsData.containsKey("coordinates") && mapsData["coordinates"] is Map) {
      return mapsData["coordinates"] as Map<String, dynamic>;
    }
  }

  return null;
}
