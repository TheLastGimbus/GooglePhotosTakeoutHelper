import 'package:logging/logging.dart';

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final errorDetails = record.error != null ? ' Error: ${record.error}' : '';
    final stackTraceDetails = record.stackTrace != null ? ' StackTrace: ${record.stackTrace}' : '';
    print('${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}$errorDetails$stackTraceDetails');
  });
}