import "dart:convert";
import "dart:io";
import 'dart:typed_data';
import "package:crypto/crypto.dart";
import "package:logging/logging.dart";

final Logger _logger = Logger("Hashing");

Future<String> calculateSha256(final File file) async {
  try {
    final Uint8List bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  } catch (e) {
    _logger.severe("Error calculating SHA-256 for ${file.path}: $e");
    rethrow;
  }
}
