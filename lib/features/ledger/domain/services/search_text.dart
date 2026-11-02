/// Search normalization shared by the query rule and the local index
/// (RN-17), so "deposito" finds "Depósito" and "pix" finds "PIX".
abstract final class SearchText {
  static const minLength = 2;
  static const maxLength = 50;

  /// Lower-case, accent-free and whitespace-collapsed version of [input].
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Normalized search term, or `null` when it is too short to search
  /// (RN-17). Input longer than [maxLength] is truncated.
  static String? toTerm(String raw) {
    var normalized = normalize(raw);
    if (normalized.length > maxLength) {
      normalized = normalized.substring(0, maxLength).trimRight();
    }
    return normalized.length < minLength ? null : normalized;
  }

  static const _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ç': 'c', 'ñ': 'n',
  };
}
