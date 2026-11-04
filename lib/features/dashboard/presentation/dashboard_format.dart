String formatInr(num amount, {bool compact = false}) {
  final rounded = amount.round();
  final absolute = rounded.abs();
  if (compact && absolute >= 10000000) {
    return '₹${_trim((rounded / 10000000).toStringAsFixed(1))}Cr';
  }
  if (compact && absolute >= 100000) {
    return '₹${_trim((rounded / 100000).toStringAsFixed(1))}L';
  }
  final digits = absolute.toString();
  final grouped = digits.length <= 3
      ? digits
      : '${digits.substring(0, digits.length - 3).replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (match) => '${match[1]},')},${digits.substring(digits.length - 3)}';
  return '${rounded < 0 ? '-₹' : '₹'}$grouped';
}

String _trim(String value) =>
    value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
