import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider { ollama, openai, anthropic }

class SettingsService {
  // Singleton pattern to ensure a single instance of the service.
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;

  // In-memory cache for settings
  ThemeMode _themeMode = ThemeMode.system;
  String _gemmaModel = 'gemma3:12b';
  bool _aiEnabled = true;
  bool _toolsEnabled = true;
  AiProvider _aiProvider = AiProvider.ollama;
  String _openaiApiKey = '';
  String _anthropicApiKey = '';

  // Public getters
  ThemeMode get themeMode => _themeMode;
  String get gemmaModel => _gemmaModel;
  bool get aiEnabled => _aiEnabled;
  bool get toolsEnabled => _toolsEnabled;
  AiProvider get aiProvider => _aiProvider;
  String get openaiApiKey => _openaiApiKey;
  String get anthropicApiKey => _anthropicApiKey;

  /// Initializes the service, loading settings from disk.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Load theme
    final themeString = _prefs.getString('theme') ?? 'System';
    _themeMode = _stringToThemeMode(themeString);
    // Load Gemma model
    _gemmaModel = _prefs.getString('gemma_model') ?? 'gemma3:12b';
    // Load AI enabled state
    _aiEnabled = _prefs.getBool('ai_enabled') ?? true;
    // Load tools enabled state
    _toolsEnabled = _prefs.getBool('tools_enabled') ?? true;
    // Load AI provider
    final providerString = _prefs.getString('ai_provider') ?? 'ollama';
    _aiProvider = _stringToAiProvider(providerString);
    // Load API keys
    _openaiApiKey = _prefs.getString('openai_api_key') ?? '';
    _anthropicApiKey = _prefs.getString('anthropic_api_key') ?? '';
  }

  /// Updates and saves the theme mode.
  Future<void> setThemeMode(ThemeMode theme) async {
    _themeMode = theme;
    await _prefs.setString('theme', _themeModeToString(theme));
  }

  /// Updates and saves the Gemma model name.
  Future<void> setGemmaModel(String model) async {
    _gemmaModel = model;
    await _prefs.setString('gemma_model', model);
  }

  /// Toggles the AI feature on/off.
  Future<void> toggleAiEnabled() async {
    _aiEnabled = !_aiEnabled;
    await _prefs.setBool('ai_enabled', _aiEnabled);
  }

  /// Toggles the tools feature on/off.
  Future<void> toggleToolsEnabled() async {
    _toolsEnabled = !_toolsEnabled;
    await _prefs.setBool('tools_enabled', _toolsEnabled);
  }

  /// Sets the AI provider.
  Future<void> setAiProvider(AiProvider provider) async {
    _aiProvider = provider;
    await _prefs.setString('ai_provider', _aiProviderToString(provider));
  }

  /// Sets the OpenAI API key.
  Future<void> setOpenaiApiKey(String key) async {
    _openaiApiKey = key;
    await _prefs.setString('openai_api_key', key);
  }

  /// Sets the Anthropic API key.
  Future<void> setAnthropicApiKey(String key) async {
    _anthropicApiKey = key;
    await _prefs.setString('anthropic_api_key', key);
  }

  ThemeMode _stringToThemeMode(String theme) {
    switch (theme) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode theme) {
    switch (theme) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  AiProvider _stringToAiProvider(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return AiProvider.openai;
      case 'anthropic':
        return AiProvider.anthropic;
      default:
        return AiProvider.ollama;
    }
  }

  String _aiProviderToString(AiProvider provider) {
    switch (provider) {
      case AiProvider.openai:
        return 'openai';
      case AiProvider.anthropic:
        return 'anthropic';
      case AiProvider.ollama:
        return 'ollama';
    }
  }
}
