import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/app.dart';
import 'package:tinda360/services/crash_log.dart';
import 'package:tinda360/services/service_providers.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final crashLog = await CrashLog.open();
  _installErrorHandlers(crashLog);

  runApp(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        appLogProvider.overrideWithValue(crashLog),
        clockProvider.overrideWithValue(const Clock()),
      ],
      child: const App(),
    ),
  );
}

void _installErrorHandlers(CrashLog log) {
  FlutterError.onError = (details) {
    try {
      FlutterError.presentError(details);
      log.error(
        'flutter',
        details.exception,
        details.stack ?? StackTrace.empty,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {}
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      log.error('platform', error, stack);
      if (kDebugMode) debugPrint('$error\n$stack');
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {}
    return true;
  };
}
