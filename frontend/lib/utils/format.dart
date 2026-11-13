/// Short uppercase labels used on mono chips.
class Fmt {
  Fmt._();

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  /// "NOW", "2 MIN", "1 HR", "3 D", "14 NOV".
  static String ago(DateTime t, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(t);
    if (d.inMinutes < 1) return 'NOW';
    if (d.inMinutes < 60) return '${d.inMinutes} MIN';
    if (d.inHours < 24) return '${d.inHours} HR';
    if (d.inDays < 7) return '${d.inDays} D';
    return '${t.day} ${_months[t.month - 1]}';
  }

  /// "TODAY · 21:04", "YESTERDAY", "14 NOV".
  static String when(DateTime t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return 'TODAY · $h:$m';
    }
    if (diff == 1) return 'YESTERDAY';
    return '${t.day} ${_months[t.month - 1]}';
  }

  static String bytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
