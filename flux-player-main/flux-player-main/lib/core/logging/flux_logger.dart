import 'package:logger/logger.dart';

/// Singleton logger for the whole app.
/// HARD RULE: never use print(); always FluxLogger.instance.
final class FluxLogger {
  FluxLogger._();

  static final FluxLogger instance = FluxLogger._();

  final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, colors: false, printEmojis: false),
  );

  void t(String message) => _logger.t(message);
  void d(String message) => _logger.d(message);
  void i(String message) => _logger.i(message);
  void w(String message, [Object? error]) => _logger.w(message, error: error);
  void e(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
