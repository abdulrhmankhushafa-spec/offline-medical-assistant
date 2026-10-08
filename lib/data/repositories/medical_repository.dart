import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/models.dart';
import '../../domain/services/vector_service.dart';

class MedicalRepository {
  final DatabaseHelper dbHelper;
  final Uuid _uuid = const Uuid();
  MedicalRepository(this.dbHelper);

  Future<String> createConversation(String title) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    await db.insert('conversations', {'id': id, 'title': title.trim().isEmpty ? 'محادثة جديدة' : title.trim(), 'created_at': now, 'last_updated': now});
    return id;
  }

  Future<void> addMessage({required String conversationId, required String content, required String senderType}) async {
    final db = await dbHelper.database;
    await db.insert('messages', {'id': _uuid.v4(), 'conversation_id': conversationId, 'content': content, 'sender_type': senderType, 'timestamp': DateTime.now().toIso8601String()});
    await db.update('conversations', {'last_updated': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [conversationId]);
  }

  Future<List<Message>> messages(String conversationId) async {
    final db = await dbHelper.database;
    final rows = await db.query('messages', where: 'conversation_id = ?', whereArgs: [conversationId], orderBy: 'timestamp ASC');
    return rows.map((r) => Message(id: r['id'] as String, conversationId: r['conversation_id'] as String, content: r['content'] as String, senderType: r['sender_type'] as String, timestamp: DateTime.parse(r['timestamp'] as String))).toList();
  }

  Future<void> addKnowledge({required String content, required String source}) async {
    final db = await dbHelper.database;
    await db.insert('medical_knowledge', {'id': _uuid.v4(), 'content_chunk': content, 'source_name': source, 'added_date': DateTime.now().toIso8601String()});
  }

  Future<void> addEmbedding({required String chunkId, required List<double> vector}) async {
    final db = await dbHelper.database;
    await db.insert('embeddings', {'id': _uuid.v4(), 'chunk_id': chunkId, 'vector_data': VectorService.encodeVector(vector), 'dimensions': vector.length});
  }

  Future<List<KnowledgeChunk>> searchFts(String query, {int limit = 8}) async {
    final db = await dbHelper.database;
    try {
      final rows = await db.rawQuery('''
        SELECT k.id, k.content_chunk, k.source_name, k.added_date, bm25(medical_knowledge_fts) AS score
        FROM medical_knowledge_fts f
        JOIN medical_knowledge k ON k.rowid = f.rowid
        WHERE medical_knowledge_fts MATCH ?
        ORDER BY bm25(medical_knowledge_fts)
        LIMIT ?
      ''', [_ftsQuery(query), limit]);
      return rows.map((r) => KnowledgeChunk(id: r['id'] as String, content: r['content_chunk'] as String, source: r['source_name'] as String, addedDate: DateTime.parse(r['added_date'] as String), score: (r['score'] as num?)?.toDouble() ?? 0)).toList();
    } catch (_) {
      final rows = await db.query('medical_knowledge', where: 'content_chunk LIKE ?', whereArgs: ['%${query.replaceAll('%', '')}%'], limit: limit);
      return rows.map((r) => KnowledgeChunk(id: r['id'] as String, content: r['content_chunk'] as String, source: r['source_name'] as String, addedDate: DateTime.parse(r['added_date'] as String))).toList();
    }
  }

  String _ftsQuery(String input) {
    final tokens = input.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ').split(RegExp(r'\s+')).where((e) => e.length > 1).take(12).map((e) => '"${e.replaceAll('"', '')}"').toList();
    return tokens.isEmpty ? '""' : tokens.join(' OR ');
  }

  Future<List<KnowledgeChunk>> semanticSearch(List<double> queryVector, {int limit = 8}) async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT e.chunk_id, e.vector_data, k.content_chunk, k.source_name, k.added_date
      FROM embeddings e JOIN medical_knowledge k ON k.id = e.chunk_id
    ''');
    final scored = <KnowledgeChunk>[];
    for (final r in rows) {
      final vector = VectorService.decodeVector((r['vector_data'] as List<int>?) ?? <int>[]);
      final score = VectorService.cosineSimilarity(queryVector, vector);
      scored.add(KnowledgeChunk(id: r['chunk_id'] as String, content: r['content_chunk'] as String, source: r['source_name'] as String, addedDate: DateTime.parse(r['added_date'] as String), score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  Future<List<KnowledgeChunk>> hybridSearch(String query, {List<double>? queryVector, int limit = 8}) async {
    final lexical = await searchFts(query, limit: limit * 2);
    final semantic = queryVector == null ? <KnowledgeChunk>[] : await semanticSearch(queryVector, limit: limit * 2);
    final scores = <String, double>{};
    final items = <String, KnowledgeChunk>{};
    for (var i = 0; i < lexical.length; i++) {
      items[lexical[i].id] = lexical[i];
      scores[lexical[i].id] = (scores[lexical[i].id] ?? 0) + 1.0 / (60 + i + 1);
    }
    for (var i = 0; i < semantic.length; i++) {
      items[semantic[i].id] = semantic[i];
      scores[semantic[i].id] = (scores[semantic[i].id] ?? 0) + 1.0 / (60 + i + 1);
    }
    final ranked = items.keys.toList()..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    return ranked.take(limit).map((id) {
      final item = items[id]!;
      return KnowledgeChunk(id: item.id, content: item.content, source: item.source, addedDate: item.addedDate, score: scores[id] ?? 0);
    }).toList();
  }
}
