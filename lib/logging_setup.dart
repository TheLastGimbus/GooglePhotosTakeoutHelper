import "package:logging/logging.dart";

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((final LogRecord record) {
    final String errorDetails =
        record.error != null ? " Error: ${record.error}" : "";
    final String stackTraceDetails =
        record.stackTrace != null ? " StackTrace: ${record.stackTrace}" : "";
    print(
        '${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}$errorDetails$stackTraceDetails');
  });
}
