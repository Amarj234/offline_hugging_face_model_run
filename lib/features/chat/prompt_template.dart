enum PromptFormat {
  plain,
  phi3,
  llama3,
  chatml,
}

class PromptTemplate {
  final PromptFormat format;

  const PromptTemplate(this.format);

  static PromptFormat detectFormat(String? fileName) {
    if (fileName == null) return PromptFormat.plain;
    final lowerName = fileName.toLowerCase();
    if (lowerName.contains('phi-3')) return PromptFormat.phi3;
    if (lowerName.contains('llama-3')) return PromptFormat.llama3;
    if (lowerName.contains('qwen') || lowerName.contains('mistral') || lowerName.contains('chatml')) return PromptFormat.chatml;
    return PromptFormat.plain;
  }

  String formatPrompt(String userMessage, {String? systemPrompt}) {
    final system = systemPrompt ?? "AI Assistant.";
    
    switch (format) {
      case PromptFormat.phi3:
        return "<|system|>\n$system<|end|>\n<|user|>\n$userMessage<|end|>\n<|assistant|>\n";
      case PromptFormat.llama3:
        return "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n$system<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n$userMessage<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n";
      case PromptFormat.chatml:
        return "<|im_start|>system\n$system<|im_end|>\n<|im_start|>user\n$userMessage<|im_end|>\n<|im_start|>assistant\n";
      case PromptFormat.plain:
        return "$userMessage";
    }
  }

  List<String> get stopSequences {
    switch (format) {
      case PromptFormat.phi3:
        return ["<|end|>", "<|assistant|>", "<|user|>"];
      case PromptFormat.llama3:
        return ["<|eot_id|>", "<|start_header_id|>", "<|end_header_id|>"];
      case PromptFormat.chatml:
        return ["<|im_end|>", "<|im_start|>"];
      case PromptFormat.plain:
        return [];
    }
  }
}
