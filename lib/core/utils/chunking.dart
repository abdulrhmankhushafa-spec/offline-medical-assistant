class SlidingWindowChunker {
  final int maxCharacters;
  final int overlapCharacters;
  const SlidingWindowChunker({this.maxCharacters = 1200, this.overlapCharacters = 180});

  List<String> split(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return [];
    if (maxCharacters <= overlapCharacters) throw ArgumentError('maxCharacters must be greater than overlapCharacters');

    final result = <String>[];
    var start = 0;
    while (start < normalized.length) {
      var end = (start + maxCharacters).clamp(0, normalized.length);
      if (end < normalized.length) {
        final candidates = [
          normalized.lastIndexOf('،', end),
          normalized.lastIndexOf('.', end),
          normalized.lastIndexOf(' ', end),
        ].where((x) => x > start + (maxCharacters * .55)).toList();
        if (candidates.isNotEmpty) end = candidates.reduce((a, b) => a > b ? a : b);
      }
      final chunk = normalized.substring(start, end).trim();
      if (chunk.isNotEmpty) result.add(chunk);
      if (end >= normalized.length) break;
      start = (end - overlapCharacters).clamp(0, normalized.length - 1);
    }
    return result;
  }
}
