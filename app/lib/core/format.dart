/// 1234567.5 -> "1 234 568 so'm". Faqat ko'rsatish uchun.
String money(double v) => '${_group(v.round())} so‘m';

String qty(double v) {
  final s = v.toStringAsFixed(3);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

String _group(int n) {
  final neg = n < 0;
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

/// Foydalanuvchi kiritgan sonni o'qiydi (bo'shliqlar, vergul yoki nuqta tozalangan).
double? parseInput(String s) {
  final clean = s
      .trim()
      .replaceAll(' ', '')
      .replaceAll('\u00A0', '')
      .replaceAll("'", '')
      .replaceAll('’', '')
      .replaceAll(',', '.');
  return double.tryParse(clean);
}
