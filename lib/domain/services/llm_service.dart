import 'package:lib_llama_cpp/lib_llama_cpp.dart';

class LocalLlmService {
  LlamaOpenAIClient? _client;

  bool get isReady => _client != null;

  Future<void> load(String modelPath) async {
    _client = LlamaOpenAIClient(models: {
      'local': LlamaModelConfig(modelPath: modelPath),
    });
  }

  Future<String> generate(String prompt) async {
    final client = _client;
    if (client == null) {
      throw StateError('النموذج المحلي غير محمل.');
    }
    final response = await client.responses.create(model: 'local', input: prompt);
    return response.outputText.trim();
  }

  void dispose() {
    _client = null;
  }
}
