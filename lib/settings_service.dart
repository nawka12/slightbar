import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider { ollama, openai, anthropic, gemini }

class SettingsService {
  // Singleton pattern to ensure a single instance of the service.
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;

  // In-memory cache for settings
  ThemeMode _themeMode = ThemeMode.system;
  // Provider-specific models
  String _ollamaModel = 'qwen3:8b';
  String _openaiModel = 'gpt-o4-mini';
  String _anthropicModel = 'claude-sonnet-4-20250514';
  String _geminiModel = 'gemini-2.5-flash-preview-05-20';
  bool _aiEnabled = true;
  // Individual tool settings
  bool _webSearchEnabled = true;
  bool _webScrapeEnabled = true;
  bool _weatherEnabled = true;
  bool _prayerTimesEnabled = true;
  String _searxngUrl = 'http://127.0.0.1:8080';
  AiProvider _aiProvider = AiProvider.ollama;
  String _openaiApiKey = '';
  String _anthropicApiKey = '';
  String _geminiApiKey = '';
  List<String> _excludedDrives = [];
  String _hotkeyKey = 'space';
  List<String> _hotkeyModifiers = ['alt'];
  bool _isFirstRun = true;
  bool _indexDrives = false;

  // Public getters
  ThemeMode get themeMode => _themeMode;

  // Return the model for the current provider
  String get gemmaModel {
    switch (_aiProvider) {
      case AiProvider.ollama:
        return _ollamaModel;
      case AiProvider.openai:
        return _openaiModel;
      case AiProvider.anthropic:
        return _anthropicModel;
      case AiProvider.gemini:
        return _geminiModel;
    }
  }

  bool get aiEnabled => _aiEnabled;
  bool get webSearchEnabled => _webSearchEnabled;
  bool get webScrapeEnabled => _webScrapeEnabled;
  bool get weatherEnabled => _weatherEnabled;
  bool get prayerTimesEnabled => _prayerTimesEnabled;
  String get searxngUrl => _searxngUrl;

  // Legacy getter for backward compatibility - returns true if any tool is enabled
  bool get toolsEnabled =>
      _webSearchEnabled ||
      _webScrapeEnabled ||
      _weatherEnabled ||
      _prayerTimesEnabled;

  AiProvider get aiProvider => _aiProvider;
  String get openaiApiKey => _openaiApiKey;
  String get anthropicApiKey => _anthropicApiKey;
  String get geminiApiKey => _geminiApiKey;
  List<String> get excludedDrives => _excludedDrives;
  String get hotkeyKey => _hotkeyKey;
  List<String> get hotkeyModifiers => _hotkeyModifiers;
  bool get isFirstRun => _isFirstRun;
  bool get indexDrives => _indexDrives;

  /// Initializes the service, loading settings from disk.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _isFirstRun = _prefs.getBool('is_first_run') ?? true;

    // Load theme
    final themeString = _prefs.getString('theme') ?? 'System';
    _themeMode = _stringToThemeMode(themeString);

    // Load provider-specific models
    _ollamaModel = _prefs.getString('ollama_model') ?? 'qwen3:8b';
    _openaiModel = _prefs.getString('openai_model') ?? 'gpt-o4-mini';
    _anthropicModel =
        _prefs.getString('anthropic_model') ?? 'claude-sonnet-4-20250514';
    _geminiModel =
        _prefs.getString('gemini_model') ?? 'gemini-2.5-flash-preview-05-20';

    // For backward compatibility, if old gemma_model exists, use it for ollama
    final oldGemmaModel = _prefs.getString('gemma_model');
    if (oldGemmaModel != null && oldGemmaModel.isNotEmpty) {
      _ollamaModel = oldGemmaModel;
      // Save it to the new format and remove the old key
      await _prefs.setString('ollama_model', _ollamaModel);
      await _prefs.remove('gemma_model');
    }

    // Load AI enabled state
    _aiEnabled = _prefs.getBool('ai_enabled') ?? true;
    // Load individual tool settings
    _webSearchEnabled = _prefs.getBool('web_search_enabled') ?? true;
    _webScrapeEnabled = _prefs.getBool('web_scrape_enabled') ?? true;
    _weatherEnabled = _prefs.getBool('weather_enabled') ?? true;
    _prayerTimesEnabled = _prefs.getBool('prayer_times_enabled') ?? true;
    _searxngUrl = _prefs.getString('searxng_url') ?? 'http://127.0.0.1:8080';

    // For backward compatibility, if old tools_enabled exists, apply it to all tools
    final oldToolsEnabled = _prefs.getBool('tools_enabled');
    if (oldToolsEnabled != null) {
      _webSearchEnabled = oldToolsEnabled;
      _webScrapeEnabled = oldToolsEnabled;
      _weatherEnabled = oldToolsEnabled;
      _prayerTimesEnabled = oldToolsEnabled;
      // Save to new format and remove old key
      await _prefs.setBool('web_search_enabled', _webSearchEnabled);
      await _prefs.setBool('web_scrape_enabled', _webScrapeEnabled);
      await _prefs.setBool('weather_enabled', _weatherEnabled);
      await _prefs.setBool('prayer_times_enabled', _prayerTimesEnabled);
      await _prefs.remove('tools_enabled');
    }

    // Load AI provider
    final providerString = _prefs.getString('ai_provider') ?? 'ollama';
    _aiProvider = _stringToAiProvider(providerString);
    // Load API keys
    _openaiApiKey = _prefs.getString('openai_api_key') ?? '';
    _anthropicApiKey = _prefs.getString('anthropic_api_key') ?? '';
    _geminiApiKey = _prefs.getString('gemini_api_key') ?? '';
    _excludedDrives = _prefs.getStringList('excluded_drives') ?? [];
    _hotkeyKey = _prefs.getString('hotkey_key') ?? 'space';
    _hotkeyModifiers = _prefs.getStringList('hotkey_modifiers') ?? ['alt'];
    _indexDrives = _prefs.getBool('index_drives') ?? false;

    // If it's the first run, it means the settings file was likely empty.
    // We should write the default values we just loaded into memory back to disk.
    if (_isFirstRun) {
      await _prefs.setString('theme', _themeModeToString(_themeMode));
      await _prefs.setString('ollama_model', _ollamaModel);
      await _prefs.setString('openai_model', _openaiModel);
      await _prefs.setString('anthropic_model', _anthropicModel);
      await _prefs.setString('gemini_model', _geminiModel);
      await _prefs.setBool('ai_enabled', _aiEnabled);
      await _prefs.setBool('web_search_enabled', _webSearchEnabled);
      await _prefs.setBool('web_scrape_enabled', _webScrapeEnabled);
      await _prefs.setBool('weather_enabled', _weatherEnabled);
      await _prefs.setBool('prayer_times_enabled', _prayerTimesEnabled);
      await _prefs.setString('searxng_url', _searxngUrl);
      await _prefs.setString('ai_provider', _aiProviderToString(_aiProvider));
      await _prefs.setString('openai_api_key', _openaiApiKey);
      await _prefs.setString('anthropic_api_key', _anthropicApiKey);
      await _prefs.setString('gemini_api_key', _geminiApiKey);
      await _prefs.setStringList('excluded_drives', _excludedDrives);
      await _prefs.setString('hotkey_key', _hotkeyKey);
      await _prefs.setStringList('hotkey_modifiers', _hotkeyModifiers);
      await _prefs.setBool('index_drives', _indexDrives);
    }
  }

  /// Updates and saves the theme mode.
  Future<void> setThemeMode(ThemeMode theme) async {
    _themeMode = theme;
    await _prefs.setString('theme', _themeModeToString(theme));
  }

  /// Updates and saves the model for the current provider.
  Future<void> setGemmaModel(String model) async {
    switch (_aiProvider) {
      case AiProvider.ollama:
        _ollamaModel = model;
        await _prefs.setString('ollama_model', model);
        break;
      case AiProvider.openai:
        _openaiModel = model;
        await _prefs.setString('openai_model', model);
        break;
      case AiProvider.anthropic:
        _anthropicModel = model;
        await _prefs.setString('anthropic_model', model);
        break;
      case AiProvider.gemini:
        _geminiModel = model;
        await _prefs.setString('gemini_model', model);
        break;
    }
  }

  /// Toggles the AI feature on/off.
  Future<void> toggleAiEnabled() async {
    _aiEnabled = !_aiEnabled;
    await _prefs.setBool('ai_enabled', _aiEnabled);
  }

  /// Toggles web search tool on/off.
  Future<void> toggleWebSearchEnabled() async {
    _webSearchEnabled = !_webSearchEnabled;
    await _prefs.setBool('web_search_enabled', _webSearchEnabled);
  }

  /// Toggles web scrape tool on/off.
  Future<void> toggleWebScrapeEnabled() async {
    _webScrapeEnabled = !_webScrapeEnabled;
    await _prefs.setBool('web_scrape_enabled', _webScrapeEnabled);
  }

  /// Toggles weather tool on/off.
  Future<void> toggleWeatherEnabled() async {
    _weatherEnabled = !_weatherEnabled;
    await _prefs.setBool('weather_enabled', _weatherEnabled);
  }

  /// Toggles prayer times tool on/off.
  Future<void> togglePrayerTimesEnabled() async {
    _prayerTimesEnabled = !_prayerTimesEnabled;
    await _prefs.setBool('prayer_times_enabled', _prayerTimesEnabled);
  }

  /// Sets the SearxNG URL.
  Future<void> setSearxngUrl(String url) async {
    _searxngUrl = url;
    await _prefs.setString('searxng_url', url);
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

  /// Sets the Gemini API key.
  Future<void> setGeminiApiKey(String key) async {
    _geminiApiKey = key;
    await _prefs.setString('gemini_api_key', key);
  }

  /// Sets the excluded drives.
  Future<void> setExcludedDrives(List<String> drives) async {
    _excludedDrives = drives;
    await _prefs.setStringList('excluded_drives', drives);
  }

  /// Sets the hotkey configuration.
  Future<void> setHotkey(String key, List<String> modifiers) async {
    _hotkeyKey = key;
    _hotkeyModifiers = modifiers;
    await _prefs.setString('hotkey_key', key);
    await _prefs.setStringList('hotkey_modifiers', modifiers);
  }

  /// Toggles drive indexing.
  Future<void> toggleIndexDrives() async {
    _indexDrives = !_indexDrives;
    await _prefs.setBool('index_drives', _indexDrives);
  }

  /// Sets the isFirstRun flag.
  set isFirstRun(bool value) {
    _isFirstRun = value;
    _prefs.setBool('is_first_run', value);
  }

  /// Gets a formatted hotkey string for display.
  String getHotkeyDisplayString() {
    final modifierNames = _hotkeyModifiers.map((mod) {
      switch (mod.toLowerCase()) {
        case 'control':
          return 'Ctrl';
        case 'alt':
          return 'Alt';
        case 'shift':
          return 'Shift';
        case 'meta':
          return 'Win';
        default:
          return mod;
      }
    }).join(' + ');

    final keyName = _formatKeyName(_hotkeyKey);

    return modifierNames.isNotEmpty ? '$modifierNames + $keyName' : keyName;
  }

  String _formatKeyName(String key) {
    switch (key.toLowerCase()) {
      case 'space':
        return 'Space';
      case 'slash':
        return '/';
      case 'semicolon':
        return ';';
      case 'backquote':
        return '`';
      case 'enter':
        return 'Enter';
      case 'tab':
        return 'Tab';
      case 'escape':
        return 'Esc';
      default:
        return key.toUpperCase();
    }
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
      case 'gemini':
        return AiProvider.gemini;
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
      case AiProvider.gemini:
        return 'gemini';
      case AiProvider.ollama:
        return 'ollama';
    }
  }
}
