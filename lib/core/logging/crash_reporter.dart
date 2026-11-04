/// Hook deliberately receives only sanitized event identifiers, never errors.
abstract interface class CrashReporter {
  void record(String event);
}

class NoOpCrashReporter implements CrashReporter {
  const NoOpCrashReporter();
  @override
  void record(String event) {}
}
