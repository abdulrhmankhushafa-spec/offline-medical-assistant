import 'dart:convert';
import 'dart:math';

class VectorService {
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;
    double dot = 0, normA = 0, normB = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0 : dot / denom;
  }

  static List<double> decodeVector(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      final values = (jsonDecode(text) as List).cast<num>();
      return values.map((e) => e.toDouble()).toList();
    } catch (_) {
      return [];
    }
  }

  static List<int> encodeVector(List<double> vector) => utf8.encode(jsonEncode(vector));
}
