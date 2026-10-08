import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/database/database_helper.dart';
import '../../data/repositories/medical_repository.dart';
import '../../domain/services/llm_service.dart';
import '../../domain/services/safety_service.dart';

final databaseProvider = Provider((ref) => DatabaseHelper.instance);
final medicalRepositoryProvider = Provider((ref) => MedicalRepository(ref.watch(databaseProvider)));
final safetyProvider = Provider((ref) => MedicalSafetyService());
final llmProvider = Provider((ref) => LocalLlmService());

class ChatState {
  final List<Map<String, String>> messages;
  final bool busy;
  final String? error;
  final String? conversationId;
  const ChatState({this.messages = const [], this.busy = false, this.error, this.conversationId});
  ChatState copyWith({List<Map<String, String>>? messages, bool? busy, String? error, String? conversationId}) => ChatState(messages: messages ?? this.messages, busy: busy ?? this.busy, error: error, conversationId: conversationId ?? this.conversationId);
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);

class ChatController extends Notifier<ChatState> {
  late final MedicalRepository repo;
  late final MedicalSafetyService safety;
  late final LocalLlmService llm;

  @override
  ChatState build() {
    repo = ref.watch(medicalRepositoryProvider);
    safety = ref.watch(safetyProvider);
    llm = ref.watch(llmProvider);
    return const ChatState();
  }

  Future<void> send(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.busy) return;
    final conversationId = state.conversationId ?? await repo.createConversation(text.length > 40 ? '${text.substring(0, 40)}...' : text);
    final current = [...state.messages, {'role': 'user', 'content': text}];
    state = state.copyWith(messages: current, busy: true, conversationId: conversationId);
    await repo.addMessage(conversationId: conversationId, content: text, senderType: 'user');

    final check = safety.check(text);
    if (check.emergency) {
      final response = safety.emergencyMessage();
      final updated = [...current, {'role': 'system', 'content': response}];
      state = state.copyWith(messages: updated, busy: false);
      await repo.addMessage(conversationId: conversationId, content: response, senderType: 'system');
      return;
    }

    try {
      final context = await repo.hybridSearch(text, limit: 6);
      final contextText = context.map((e) => '[${e.source}] ${e.content}').join('\n\n');
      final prompt = '''أنت مساعد طبي محلي. لا تقدم تشخيصاً مؤكداً ولا تستبدل الطبيب. استخدم السياق الطبي المرفق فقط عند توفره، واذكر بوضوح عندما تكون المعلومات غير كافية.\n\nالسياق:\n$contextText\n\nسؤال المستخدم:\n$text\n\nأجب بالعربية بشكل واضح ومختصر.''';

      String response;
      if (llm.isReady) {
        response = await llm.generate(prompt);
      } else {
        response = 'تمت معالجة السؤال محلياً، لكن نموذج GGUF لم يتم تحميله بعد. أضف نموذجاً محلياً من الإعدادات لتفعيل التوليد الذكي.';
      }
      final updated = [...current, {'role': 'assistant', 'content': response}];
      state = state.copyWith(messages: updated, busy: false);
      await repo.addMessage(conversationId: conversationId, content: response, senderType: 'ai');
    } catch (e) {
      state = state.copyWith(busy: false, error: 'تعذر إكمال المعالجة المحلية: $e');
    }
  }

  Future<void> loadDefaultModel() async {
    final dir = await getApplicationDocumentsDirectory();
    final model = File('${dir.path}/models/medical.gguf');
    if (await model.exists()) await llm.load(model.path);
  }
}
