String currencyCode(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final match = RegExp(r'[A-Z]{3}').firstMatch(trimmed);
  if (match != null) return match.group(0)!;
  return trimmed;
}

String currencySymbol(String raw) {
  if (raw.contains('£')) return '£';
  if (raw.contains('\$')) return '\$';
  if (raw.contains('€')) return '€';
  if (raw.contains('¥')) return '¥';
  if (raw.contains('₹')) return '₹';
  final code = currencyCode(raw);
  switch (code) {
    case 'GBP':
      return '£';
    case 'USD':
    case 'AUD':
    case 'CAD':
      return '\$';
    case 'EUR':
      return '€';
    case 'AED':
      return 'AED';
    case 'SAR':
      return 'SAR';
    case 'JPY':
      return '¥';
    case 'INR':
      return '₹';
    default:
      return code;
  }
}

String formatCurrencyAmount(dynamic amount, String currencyRaw) {
  final numVal = (amount is num)
      ? amount
      : (double.tryParse(amount?.toString() ?? '') ?? 0);
  final symbol = currencySymbol(currencyRaw);
  final formatted = numVal.toStringAsFixed(2);
  if (symbol.isEmpty) return formatted;
  if (symbol.length <= 2 ||
      symbol == '\$' ||
      symbol == '£' ||
      symbol == '€' ||
      symbol == '¥' ||
      symbol == '₹') {
    return '$symbol$formatted';
  }
  return '$symbol $formatted';
}
