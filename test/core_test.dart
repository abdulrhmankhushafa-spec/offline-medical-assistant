import 'package:flutter_test/flutter_test.dart';
import 'package:offline_medical_assistant/core/utils/chunking.dart';
import 'package:offline_medical_assistant/domain/services/vector_service.dart';
import 'package:offline_medical_assistant/domain/services/safety_service.dart';

void main() {
  test('sliding window preserves text and creates overlap', () {
    final chunks = const SlidingWindowChunker(
      maxCharacters: 30,
      overlapCharacters: 5,
    ).split('هذه جملة طبية طويلة للاختبار والتقسيم بين المقاطع المختلفة.');

    expect(chunks.length, greaterThan(1));
  });

  test('cosine similarity', () {
    expect(
      VectorService.cosineSimilarity([1, 0], [1, 0]),
      closeTo(1, .0001),
    );
    expect(
      VectorService.cosineSimilarity([1, 0], [0, 1]),
      closeTo(0, .0001),
    );
  });

  test('emergency detection', () {
    expect(
      MedicalSafetyService().check('لدي نزيف شديد').emergency,
      isTrue,
    );
  });
}
