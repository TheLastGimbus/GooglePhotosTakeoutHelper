import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

Future<String> calculateSha256(File file) async {
  try {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  } catch (e) {
    print('Error calculating SHA-256 for ${file.path}: $e');
    rethrow;
  }
}