import '../../core/utils/chunking.dart';
import '../../data/repositories/medical_repository.dart';

class KnowledgeIngestionService {
  final MedicalRepository repository;
  final SlidingWindowChunker chunker;
  KnowledgeIngestionService(this.repository, {this.chunker = const SlidingWindowChunker()});

  Future<int> ingestText(String text, {required String sourceName}) async {
    final chunks = chunker.split(text);
    for (final chunk in chunks) {
      await repository.addKnowledge(content: chunk, source: sourceName);
    }
    return chunks.length;
  }
}
