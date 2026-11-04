import 'offer.dart';

/// A normalized window. Endpoints remain available for faithful display.
class ScheduleWindow {
  const ScheduleWindow(this.start, this.end, this.allDay);
  final int start;
  final int end;
  final bool allDay;
  String get key => allDay ? 'all-day' : '$start:$end';
}

class MergedSchedule {
  MergedSchedule(
    this.type,
    this.window, {
    Set<int> days = const {},
    this.dayOfMonth,
    this.specificDate,
    required List<ScheduleRule> sources,
  }) : days = Set.unmodifiable(days),
       sources = List.unmodifiable(sources);
  final String type;
  final ScheduleWindow window;
  final Set<int> days;
  final int? dayOfMonth;
  final DateTime? specificDate;
  final List<ScheduleRule> sources;
}

class ScheduleSummary {
  ScheduleSummary(List<MergedSchedule> schedules, this.hasDiagnostics)
    : schedules = List.unmodifiable(schedules);
  final List<MergedSchedule> schedules;
  final bool hasDiagnostics;
}

/// Deduplicates identity and semantics, retaining every contributing raw source.
abstract final class OfferSchedules {
  static int? seconds(String? value) {
    if (value == null || !RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(value)) {
      return null;
    }
    final pieces = value.split(':').map(int.parse).toList();
    if (pieces[0] > 23 ||
        pieces[1] > 59 ||
        (pieces.length == 3 && pieces[2] > 59)) {
      return null;
    }
    return pieces[0] * 3600 +
        pieces[1] * 60 +
        (pieces.length == 3 ? pieces[2] : 0);
  }

  static ScheduleWindow? window(ScheduleRule rule) {
    final start = seconds(rule.startTime);
    final end = seconds(rule.endTime);
    if (start == null || end == null || start == end) return null;
    final duration = (end - start) % 86400;
    if (duration == 86399) return ScheduleWindow(start, end, true);
    if (duration < 60) return null;
    return ScheduleWindow(start, end, false);
  }

  static ScheduleSummary merge(Iterable<ScheduleRule> rules) {
    final groups = <String, List<ScheduleRule>>{};
    final seen = <int, String>{};
    var diagnostics = false;
    for (final rule in rules) {
      if (!const {
        'ALWAYS',
        'WEEKLY',
        'MONTHLY',
        'DATE',
      }.contains(rule.scheduleType)) {
        diagnostics = true;
        continue;
      }
      final normalized = window(rule);
      final day = rule.dayOfWeek;
      final monthDay = rule.dayOfMonth;
      if (normalized == null ||
          (rule.scheduleType == 'WEEKLY' &&
              (day == null || day < 1 || day > 7)) ||
          (rule.scheduleType == 'MONTHLY' &&
              (monthDay == null || monthDay < 1 || monthDay > 31)) ||
          (rule.scheduleType == 'DATE' && rule.specificDate == null)) {
        diagnostics = true;
        continue;
      }
      final discriminator = switch (rule.scheduleType) {
        'WEEKLY' => '$day',
        'MONTHLY' => '$monthDay',
        'DATE' => '${rule.specificDate}',
        _ => '',
      };
      final identity = '${rule.scheduleType}:${normalized.key}:$discriminator';
      final old = seen[rule.id];
      if (old != null && old != identity) {
        diagnostics = true;
        continue;
      }
      seen[rule.id] = identity;
      final group = rule.scheduleType == 'WEEKLY'
          ? 'WEEKLY:${normalized.key}'
          : identity;
      groups.putIfAbsent(group, () => []).add(rule);
    }
    final merged = <MergedSchedule>[];
    for (final sources in groups.values) {
      final first = sources.first;
      final normalized = window(first);
      if (normalized == null) continue;
      final days =
          sources
              .map((rule) => rule.dayOfWeek)
              .whereType<int>()
              .toSet()
              .toList()
            ..sort();
      merged.add(
        MergedSchedule(
          first.scheduleType,
          normalized,
          days: days.toSet(),
          dayOfMonth: first.dayOfMonth,
          specificDate: first.specificDate,
          sources: sources,
        ),
      );
    }
    return ScheduleSummary(merged, diagnostics);
  }
}
