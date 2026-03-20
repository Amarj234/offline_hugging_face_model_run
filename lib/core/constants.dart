class AppConstants {
  static const String hfApiBaseUrl = 'https://huggingface.co/api';
  static const String hfModelsUrl = '$hfApiBaseUrl/models';
  
  // Default inference parameters
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 512;
  static const double defaultTopP = 0.9;
  
  // Storage keys
  static const String keyTemperature = 'pref_temperature';
  static const String keyMaxTokens = 'pref_max_tokens';
  static const String keyTopP = 'pref_top_p';
  static const String keySelectedModelPath = 'pref_selected_model_path';
  static const String keyDarkMode = 'pref_dark_mode';

  // Hugging Face GGUF search query
  static const String hfGgufSearchQuery = 'gguf';
}
