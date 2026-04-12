class ChineseDateTimeFormatter {
  const ChineseDateTimeFormatter._();

  static String formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final DateTime local = value.toLocal();
    return '${local.year}年${local.month}月${local.day}日 ${_two(local.hour)}:${_two(local.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
