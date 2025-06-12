import 'package:flutter/material.dart';
import 'package:slightbar/settings_service.dart';

class SettingsView extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  const SettingsView({super.key, required this.onSettingsChanged});

  @override
  State<SettingsView> createState() => SettingsViewState();
}

class SettingsViewState extends State<SettingsView> {
  final SettingsService _settings = SettingsService();
  int _selectedIndex = 0; // For navigating settings items
  bool _isEditingModel = false;
  bool _isEditingOpenaiKey = false;
  bool _isEditingAnthropicKey = false;
  bool _isEditingGeminiKey = false;
  bool _isEditingSearxngUrl = false;
  final TextEditingController _modelTextController = TextEditingController();
  final TextEditingController _openaiKeyController = TextEditingController();
  final TextEditingController _anthropicKeyController = TextEditingController();
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _searxngUrlController = TextEditingController();
  final FocusNode _modelFocusNode = FocusNode();
  final FocusNode _openaiKeyFocusNode = FocusNode();
  final FocusNode _anthropicKeyFocusNode = FocusNode();
  final FocusNode _geminiKeyFocusNode = FocusNode();
  final FocusNode _searxngUrlFocusNode = FocusNode();

  // This list will hold all the settings widgets
  late List<Widget> _settingsItems;

  @override
  void initState() {
    super.initState();
    _modelTextController.text = _settings.gemmaModel;
    _openaiKeyController.text = _settings.openaiApiKey;
    _anthropicKeyController.text = _settings.anthropicApiKey;
    _geminiKeyController.text = _settings.geminiApiKey;
    _searxngUrlController.text = _settings.searxngUrl;
  }

  @override
  void dispose() {
    _modelTextController.dispose();
    _openaiKeyController.dispose();
    _anthropicKeyController.dispose();
    _geminiKeyController.dispose();
    _searxngUrlController.dispose();
    _modelFocusNode.dispose();
    _openaiKeyFocusNode.dispose();
    _anthropicKeyFocusNode.dispose();
    _geminiKeyFocusNode.dispose();
    _searxngUrlFocusNode.dispose();
    super.dispose();
  }

  void navigateDown() {
    if (_isEditingModel) {
      _saveModel();
    } else if (_isEditingOpenaiKey) {
      _saveOpenaiKey();
    } else if (_isEditingAnthropicKey) {
      _saveAnthropicKey();
    } else if (_isEditingGeminiKey) {
      _saveGeminiKey();
    } else if (_isEditingSearxngUrl) {
      _saveSearxngUrl();
    }
    setState(() {
      _selectedIndex = (_selectedIndex + 1) % _settingsItems.length;
    });
  }

  void navigateUp() {
    if (_isEditingModel) {
      _saveModel();
    } else if (_isEditingOpenaiKey) {
      _saveOpenaiKey();
    } else if (_isEditingAnthropicKey) {
      _saveAnthropicKey();
    } else if (_isEditingGeminiKey) {
      _saveGeminiKey();
    } else if (_isEditingSearxngUrl) {
      _saveSearxngUrl();
    }
    setState(() {
      _selectedIndex =
          (_selectedIndex - 1 + _settingsItems.length) % _settingsItems.length;
    });
  }

  void handleEnter() {
    if (_isEditingModel) {
      _saveModel();
      return;
    }
    if (_isEditingOpenaiKey) {
      _saveOpenaiKey();
      return;
    }
    if (_isEditingAnthropicKey) {
      _saveAnthropicKey();
      return;
    }
    if (_isEditingGeminiKey) {
      _saveGeminiKey();
      return;
    }

    switch (_selectedIndex) {
      case 0:
        _cycleTheme();
        break;
      case 1:
        _toggleAi();
        break;
      case 2:
        _toggleWebSearch();
        break;
      case 3:
        _toggleWebScrape();
        break;
      case 4:
        _toggleWeather();
        break;
      case 5:
        _cycleAiProvider();
        break;
      case 6:
        // AI Model editing
        setState(() {
          _isEditingModel = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _modelFocusNode.requestFocus();
        });
        break;
      case 7:
        // SearxNG URL editing
        setState(() {
          _isEditingSearxngUrl = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searxngUrlFocusNode.requestFocus();
        });
        break;
      case 8:
        // OpenAI API Key editing
        setState(() {
          _isEditingOpenaiKey = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openaiKeyFocusNode.requestFocus();
        });
        break;
      case 9:
        // Anthropic API Key editing
        setState(() {
          _isEditingAnthropicKey = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _anthropicKeyFocusNode.requestFocus();
        });
        break;
      case 10:
        // Gemini API Key editing
        setState(() {
          _isEditingGeminiKey = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _geminiKeyFocusNode.requestFocus();
        });
        break;
    }
  }

  void _cycleTheme() {
    final currentTheme = _settings.themeMode;
    final newTheme = {
      ThemeMode.system: ThemeMode.light,
      ThemeMode.light: ThemeMode.dark,
      ThemeMode.dark: ThemeMode.system,
    }[currentTheme];
    _settings.setThemeMode(newTheme!);
    widget.onSettingsChanged();
  }

  void _toggleAi() {
    _settings.toggleAiEnabled().then((_) => setState(() {
          widget.onSettingsChanged();
        }));
  }

  void _toggleWebSearch() {
    _settings.toggleWebSearchEnabled().then((_) => setState(() {
          widget.onSettingsChanged();
        }));
  }

  void _toggleWebScrape() {
    _settings.toggleWebScrapeEnabled().then((_) => setState(() {
          widget.onSettingsChanged();
        }));
  }

  void _toggleWeather() {
    _settings.toggleWeatherEnabled().then((_) => setState(() {
          widget.onSettingsChanged();
        }));
  }

  void _cycleAiProvider() {
    final currentProvider = _settings.aiProvider;
    final newProvider = {
      AiProvider.ollama: AiProvider.openai,
      AiProvider.openai: AiProvider.anthropic,
      AiProvider.anthropic: AiProvider.gemini,
      AiProvider.gemini: AiProvider.ollama,
    }[currentProvider];
    _settings.setAiProvider(newProvider!).then((_) => setState(() {
          // Update the model text controller to show the model for the new provider
          _modelTextController.text = _settings.gemmaModel;
          widget.onSettingsChanged();
        }));
  }

  Future<void> _saveModel() async {
    if (_modelTextController.text.isNotEmpty) {
      await _settings.setGemmaModel(_modelTextController.text);
    }
    setState(() {
      _isEditingModel = false;
    });
    widget.onSettingsChanged();
  }

  Future<void> _saveOpenaiKey() async {
    await _settings.setOpenaiApiKey(_openaiKeyController.text);
    setState(() {
      _isEditingOpenaiKey = false;
    });
    widget.onSettingsChanged();
  }

  Future<void> _saveAnthropicKey() async {
    await _settings.setAnthropicApiKey(_anthropicKeyController.text);
    setState(() {
      _isEditingAnthropicKey = false;
    });
    widget.onSettingsChanged();
  }

  Future<void> _saveGeminiKey() async {
    await _settings.setGeminiApiKey(_geminiKeyController.text);
    setState(() {
      _isEditingGeminiKey = false;
    });
    widget.onSettingsChanged();
  }

  Future<void> _saveSearxngUrl() async {
    await _settings.setSearxngUrl(_searxngUrlController.text);
    setState(() {
      _isEditingSearxngUrl = false;
    });
    widget.onSettingsChanged();
  }

  String _getProviderDisplayName(AiProvider provider) {
    switch (provider) {
      case AiProvider.ollama:
        return 'Ollama (Local)';
      case AiProvider.openai:
        return 'OpenAI';
      case AiProvider.anthropic:
        return 'Anthropic';
      case AiProvider.gemini:
        return 'Google Gemini';
    }
  }

  String _getModelLabel() {
    switch (_settings.aiProvider) {
      case AiProvider.ollama:
        return 'Ollama Model';
      case AiProvider.openai:
        return 'OpenAI Model';
      case AiProvider.anthropic:
        return 'Anthropic Model';
      case AiProvider.gemini:
        return 'Gemini Model';
    }
  }

  String _maskApiKey(String key) {
    if (key.isEmpty) return 'Not set';
    if (key.length <= 8) return '*' * key.length;
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the settings items whenever the state changes
    _settingsItems = [
      _buildSettingsItem(
        title: 'Theme',
        currentValue: _settings.themeMode.name,
        onTap: _cycleTheme,
        isSelected: _selectedIndex == 0,
      ),
      _buildSettingsItem(
        title: 'Enable AI',
        currentValue: _settings.aiEnabled ? 'On' : 'Off',
        onTap: _toggleAi,
        isSelected: _selectedIndex == 1,
      ),
      _buildSettingsItem(
        title: 'Web Search',
        currentValue: _settings.webSearchEnabled ? 'On' : 'Off',
        onTap: _toggleWebSearch,
        isSelected: _selectedIndex == 2,
      ),
      _buildSettingsItem(
        title: 'Web Scrape',
        currentValue: _settings.webScrapeEnabled ? 'On' : 'Off',
        onTap: _toggleWebScrape,
        isSelected: _selectedIndex == 3,
      ),
      _buildSettingsItem(
        title: 'Weather',
        currentValue: _settings.weatherEnabled ? 'On' : 'Off',
        onTap: _toggleWeather,
        isSelected: _selectedIndex == 4,
      ),
      _buildSettingsItem(
        title: 'AI Provider',
        currentValue: _getProviderDisplayName(_settings.aiProvider),
        onTap: _cycleAiProvider,
        isSelected: _selectedIndex == 5,
      ),
      const SizedBox.shrink(), // Placeholder for the model setting widget
      const SizedBox.shrink(), // Placeholder for SearxNG URL widget
      const SizedBox.shrink(), // Placeholder for OpenAI key widget
      const SizedBox.shrink(), // Placeholder for Anthropic key widget
      const SizedBox.shrink(), // Placeholder for Gemini key widget
    ];

    // Handle model setting widget
    bool isModelSelected = _selectedIndex == 6;
    Widget modelSettingWidget;
    if (isModelSelected && _isEditingModel) {
      modelSettingWidget = _buildEditableTextItem(
        title: _getModelLabel(),
        controller: _modelTextController,
        focusNode: _modelFocusNode,
        isSelected: isModelSelected,
        onSubmitted: _saveModel,
      );
    } else {
      modelSettingWidget = _buildSettingsItem(
        title: _getModelLabel(),
        currentValue: _settings.gemmaModel,
        onTap: () {
          setState(() {
            _selectedIndex = 6;
            _isEditingModel = true;
            _modelTextController.text = _settings.gemmaModel;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _modelFocusNode.requestFocus();
          });
        },
        isSelected: isModelSelected,
      );
    }
    _settingsItems[6] = modelSettingWidget;

    // Handle SearxNG URL setting widget
    bool isSearxngUrlSelected = _selectedIndex == 7;
    Widget searxngUrlWidget;
    if (isSearxngUrlSelected && _isEditingSearxngUrl) {
      searxngUrlWidget = _buildEditableTextItem(
        title: 'SearxNG URL',
        controller: _searxngUrlController,
        focusNode: _searxngUrlFocusNode,
        isSelected: isSearxngUrlSelected,
        onSubmitted: _saveSearxngUrl,
      );
    } else {
      searxngUrlWidget = _buildSettingsItem(
        title: 'SearxNG URL',
        currentValue: _settings.searxngUrl,
        onTap: () {
          setState(() {
            _selectedIndex = 7;
            _isEditingSearxngUrl = true;
            _searxngUrlController.text = _settings.searxngUrl;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _searxngUrlFocusNode.requestFocus();
          });
        },
        isSelected: isSearxngUrlSelected,
      );
    }
    _settingsItems[7] = searxngUrlWidget;

    // Handle OpenAI API Key widget
    bool isOpenaiKeySelected = _selectedIndex == 8;
    Widget openaiKeyWidget;
    if (isOpenaiKeySelected && _isEditingOpenaiKey) {
      openaiKeyWidget = _buildEditableTextItem(
        title: 'OpenAI API Key',
        controller: _openaiKeyController,
        focusNode: _openaiKeyFocusNode,
        isSelected: isOpenaiKeySelected,
        onSubmitted: _saveOpenaiKey,
        isPassword: true,
      );
    } else {
      openaiKeyWidget = _buildSettingsItem(
        title: 'OpenAI API Key',
        currentValue: _maskApiKey(_settings.openaiApiKey),
        onTap: () {
          setState(() {
            _selectedIndex = 8;
            _isEditingOpenaiKey = true;
            _openaiKeyController.text = _settings.openaiApiKey;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openaiKeyFocusNode.requestFocus();
          });
        },
        isSelected: isOpenaiKeySelected,
      );
    }
    _settingsItems[8] = openaiKeyWidget;

    // Handle Anthropic API Key widget
    bool isAnthropicKeySelected = _selectedIndex == 9;
    Widget anthropicKeyWidget;
    if (isAnthropicKeySelected && _isEditingAnthropicKey) {
      anthropicKeyWidget = _buildEditableTextItem(
        title: 'Anthropic API Key',
        controller: _anthropicKeyController,
        focusNode: _anthropicKeyFocusNode,
        isSelected: isAnthropicKeySelected,
        onSubmitted: _saveAnthropicKey,
        isPassword: true,
      );
    } else {
      anthropicKeyWidget = _buildSettingsItem(
        title: 'Anthropic API Key',
        currentValue: _maskApiKey(_settings.anthropicApiKey),
        onTap: () {
          setState(() {
            _selectedIndex = 9;
            _isEditingAnthropicKey = true;
            _anthropicKeyController.text = _settings.anthropicApiKey;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _anthropicKeyFocusNode.requestFocus();
          });
        },
        isSelected: isAnthropicKeySelected,
      );
    }
    _settingsItems[9] = anthropicKeyWidget;

    // Handle Gemini API Key widget
    bool isGeminiKeySelected = _selectedIndex == 10;
    Widget geminiKeyWidget;
    if (isGeminiKeySelected && _isEditingGeminiKey) {
      geminiKeyWidget = _buildEditableTextItem(
        title: 'Gemini API Key',
        controller: _geminiKeyController,
        focusNode: _geminiKeyFocusNode,
        isSelected: isGeminiKeySelected,
        onSubmitted: _saveGeminiKey,
        isPassword: true,
      );
    } else {
      geminiKeyWidget = _buildSettingsItem(
        title: 'Gemini API Key',
        currentValue: _maskApiKey(_settings.geminiApiKey),
        onTap: () {
          setState(() {
            _selectedIndex = 10;
            _isEditingGeminiKey = true;
            _geminiKeyController.text = _settings.geminiApiKey;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _geminiKeyFocusNode.requestFocus();
          });
        },
        isSelected: isGeminiKeySelected,
      );
    }
    _settingsItems[10] = geminiKeyWidget;

    return ListView.builder(
      itemCount: _settingsItems.length,
      itemBuilder: (context, index) {
        return _settingsItems[index];
      },
    );
  }

  Widget _buildEditableTextItem({
    required String title,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isSelected,
    required VoidCallback onSubmitted,
    bool isPassword = false,
  }) {
    return Container(
      color: isSelected ? Colors.blue.withAlpha(128) : Colors.transparent,
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: SizedBox(
          width: 180,
          height: 30,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            obscureText: isPassword,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white)),
              contentPadding: EdgeInsets.only(bottom: 10),
            ),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required String title,
    required String currentValue,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black);
    final subtitleColor = isSelected
        ? Colors.white70
        : (isDarkMode ? Colors.white70 : Colors.black54);

    return Container(
      color: isSelected ? Colors.blue.withAlpha(128) : Colors.transparent,
      child: ListTile(
        title: Text(title, style: TextStyle(color: textColor)),
        trailing: Text(currentValue, style: TextStyle(color: subtitleColor)),
        onTap: onTap,
      ),
    );
  }
}
