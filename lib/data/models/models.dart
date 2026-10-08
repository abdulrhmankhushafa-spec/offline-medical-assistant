class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastUpdated;
  const Conversation({required this.id, required this.title, required this.createdAt, required this.lastUpdated});
}

class Message {
  final String id;
  final String conversationId;
  final String content;
  final String senderType;
  final DateTime timestamp;
  const Message({required this.id, required this.conversationId, required this.content, required this.senderType, required this.timestamp});
  bool get isUser => senderType == 'user';
}

class KnowledgeChunk {
  final String id;
  final String content;
  final String source;
  final DateTime addedDate;
  final double score;
  const KnowledgeChunk({required this.id, required this.content, required this.source, required this.addedDate, this.score = 0});
}
