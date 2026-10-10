String money(num value) {
  final negative = value < 0;
  var abs = value.abs();
  var whole = abs.floor();
  var cents = ((abs - whole) * 100).round();
  if (cents == 100) {
    whole += 1;
    cents = 0;
  }
  final tail = cents == 0
      ? ''
      : cents % 10 == 0
          ? '.${cents ~/ 10}'
          : '.${cents.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}\$${_withCommas(whole)}$tail';
}

String signedMoney(num value) {
  if (value > 0) return '+${money(value)}';
  if (value < 0) return money(value);
  return money(0);
}

String signedPercent(double? value) {
  if (value == null) return '—';
  final points = (value * 100).round();
  if (points > 0) return '+$points%';
  return '$points%';
}

String count(num value) => _withCommas(value.round());

String _withCommas(int whole) {
  final digits = whole.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
