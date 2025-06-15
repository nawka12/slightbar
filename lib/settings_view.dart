import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:slightbar/settings_service.dart';

const double listItemHeight = 60;

class SettingsView extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  const SettingsView({super.key, required this.onSettingsChanged});

  @override
  State<SettingsView> createState() => SettingsViewState();
}

class SettingsViewState extends State<SettingsView> {
  final SettingsService _settings = SettingsService();
  int _selectedIndex = 0; // For navigating settings items
  int _selectedHotkeyIndex = 0; // For hotkey picker navigation
  final ScrollController _scrollController = ScrollController();
  bool _isEditingModel = false;
  bool _isEditingOpenaiKey = false;
  bool _isEditingAnthropicKey = false;
  bool _isEditingGeminiKey = false;
  bool _isEditingSearxngUrl = false;
  bool _isEditingExcludedDrives = false;
  bool _isShowingHotkeyPicker = false;
  final TextEditingController _modelTextController = TextEditingController();
  final TextEditingController _openaiKeyController = TextEditingController();
  final TextEditingController _anthropicKeyController = TextEditingController();
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _searxngUrlController = TextEditingController();
  final TextEditingController _excludedDrivesController =
      TextEditingController();
  final FocusNode _modelFocusNode = FocusNode();
  final FocusNode _openaiKeyFocusNode = FocusNode();
  final FocusNode _anthropicKeyFocusNode = FocusNode();
  final FocusNode _geminiKeyFocusNode = FocusNode();
  final FocusNode _searxngUrlFocusNode = FocusNode();
  final FocusNode _excludedDrivesFocusNode = FocusNode();

  // This list will hold all the settings widgets
  late List<Widget> _settingsItems;
  late List<Function> _onEnterActions;

  final List<Map<String, dynamic>> _hotkeyOptions = [
    {
      'display': 'Alt + Space',
      'key': 'space',
      'modifiers': ['alt']
    },
    {
      'display': 'Ctrl + Space',
      'key': 'space',
      'modifiers': ['control']
    },
    {
      'display': 'Ctrl + ;',
      'key': 'semicolon',
      'modifiers': ['control']
    },
    {
      'display': 'Ctrl + `',
      'key': 'backquote',
      'modifiers': ['control']
    },
    {
      'display': 'Ctrl + Shift + Space',
      'key': 'space',
      'modifiers': ['control', 'shift']
    },
  ];

  @override
  void initState() {
    super.initState();
    _modelTextController.text = _settings.gemmaModel;
    _openaiKeyController.text = _settings.openaiApiKey;
    _anthropicKeyController.text = _settings.anthropicApiKey;
    _geminiKeyController.text = _settings.geminiApiKey;
    _searxngUrlController.text = _settings.searxngUrl;
    _excludedDrivesController.text = _settings.excludedDrives.join(', ');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _modelTextController.dispose();
    _openaiKeyController.dispose();
    _anthropicKeyController.dispose();
    _geminiKeyController.dispose();
    _searxngUrlController.dispose();
    _excludedDrivesController.dispose();
    _modelFocusNode.dispose();
    _openaiKeyFocusNode.dispose();
    _anthropicKeyFocusNode.dispose();
    _geminiKeyFocusNode.dispose();
    _searxngUrlFocusNode.dispose();
    _excludedDrivesFocusNode.dispose();
    super.dispose();
  }

  void navigateDown() {
    if (_isShowingHotkeyPicker) {
      setState(() {
        _selectedHotkeyIndex =
            (_selectedHotkeyIndex + 1) % _hotkeyOptions.length;
      });
      _scrollToSelected();
      return;
    }
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
    } else if (_isEditingExcludedDrives) {
      _saveExcludedDrives();
    }
    setState(() {
      _selectedIndex = (_selectedIndex + 1) % _settingsItems.length;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void navigateUp() {
    if (_isShowingHotkeyPicker) {
      setState(() {
        _selectedHotkeyIndex =
            (_selectedHotkeyIndex - 1 + _hotkeyOptions.length) %
                _hotkeyOptions.length;
      });
      _scrollToSelected();
      return;
    }
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
    } else if (_isEditingExcludedDrives) {
      _saveExcludedDrives();
    }
    setState(() {
      _selectedIndex =
          (_selectedIndex - 1 + _settingsItems.length) % _settingsItems.length;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  bool handleEscape() {
    if (_isShowingHotkeyPicker) {
      setState(() {
        _isShowingHotkeyPicker = false;
        _selectedHotkeyIndex = 0;
      });
      return true;
    }
    return false;
  }

  void handleEnter() {
    if (_isShowingHotkeyPicker) {
      _selectHotkey(_hotkeyOptions[_selectedHotkeyIndex]);
      return;
    }
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
    if (_isEditingSearxngUrl) {
      _saveSearxngUrl();
      return;
    }
    if (_isEditingExcludedDrives) {
      _saveExcludedDrives();
      return;
    }

    if (_selectedIndex < _onEnterActions.length) {
      _onEnterActions[_selectedIndex]();
    }
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      final index =
          _isShowingHotkeyPicker ? _selectedHotkeyIndex : _selectedIndex;
      final targetOffset = index * listItemHeight;

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
      );
    }
    widget.onSettingsChanged();
  }

  void _cycleTheme() {
    final currentTheme = _settings.themeMode;
    final newTheme = {
      ThemeMode.system: ThemeMode.light,
      ThemeMode.light: ThemeMode.dark,
      ThemeMode.dark: ThemeMode.system,
    }[currentTheme];
    _settings.setThemeMode(newTheme!).then((_) => setState(() {
          widget.onSettingsChanged();
        }));
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

  void _togglePrayerTimes() {
    _settings.togglePrayerTimesEnabled().then((_) => setState(() {
          widget.onSettingsChanged();
        }));
  }

  void _toggleIndexDrives() {
    _settings.toggleIndexDrives().then((_) {
      setState(() {
        // If the selection is now out of bounds, adjust it.
        if (_selectedIndex >= _settingsItems.length) {
          _selectedIndex = _settingsItems.length - 1;
        }
        widget.onSettingsChanged();
      });
    });
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

  Future<void> _saveExcludedDrives() async {
    final drives = _excludedDrivesController.text
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();
    await _settings.setExcludedDrives(drives);
    setState(() {
      _isEditingExcludedDrives = false;
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
    _buildSettingsItems();

    if (_isShowingHotkeyPicker) {
      return _buildHotkeyPicker();
    }
    // Rebuild the settings items whenever the state changes.
    // This approach is more robust than using placeholders.
    // _settingsItems = _buildSettingsList();

    return ListView.builder(
      controller: _scrollController,
      itemCount: _settingsItems.length,
      itemBuilder: (context, index) {
        return _settingsItems[index];
      },
    );
  }

  void _buildSettingsItems() {
    final items = <Widget>[];
    final onEnterActions = <Function>[];
    int currentIndex = 0;

    void addItem(Widget widget, Function onEnter) {
      items.add(widget);
      onEnterActions.add(onEnter);
      currentIndex++;
    }

    // Theme
    addItem(
        _buildSettingsItem(
          title: 'Theme',
          currentValue: _settings.themeMode.name,
          onTap: _cycleTheme,
          isSelected: _selectedIndex == currentIndex,
        ),
        _cycleTheme);

    // AI Enabled
    addItem(
        _buildSettingsItem(
          title: 'Enable AI',
          currentValue: _settings.aiEnabled ? 'On' : 'Off',
          onTap: _toggleAi,
          isSelected: _selectedIndex == currentIndex,
        ),
        _toggleAi);

    // Web Search
    addItem(
        _buildSettingsItem(
          title: 'Web Search',
          currentValue: _settings.webSearchEnabled ? 'On' : 'Off',
          onTap: _toggleWebSearch,
          isSelected: _selectedIndex == currentIndex,
        ),
        _toggleWebSearch);

    // Web Scrape
    addItem(
        _buildSettingsItem(
          title: 'Web Scrape',
          currentValue: _settings.webScrapeEnabled ? 'On' : 'Off',
          onTap: _toggleWebScrape,
          isSelected: _selectedIndex == currentIndex,
        ),
        _toggleWebScrape);

    // Weather
    addItem(
        _buildSettingsItem(
          title: 'Weather',
          currentValue: _settings.weatherEnabled ? 'On' : 'Off',
          onTap: _toggleWeather,
          isSelected: _selectedIndex == currentIndex,
        ),
        _toggleWeather);

    // Prayer Times
    addItem(
        _buildSettingsItem(
          title: 'Prayer Times',
          currentValue: _settings.prayerTimesEnabled ? 'On' : 'Off',
          onTap: _togglePrayerTimes,
          isSelected: _selectedIndex == currentIndex,
        ),
        _togglePrayerTimes);

    // Hotkey
    void showHotkeyPicker() {
      setState(() {
        _isShowingHotkeyPicker = true;
      });
    }

    addItem(
        _buildSettingsItem(
          title: 'Global Hotkey',
          currentValue: _settings.getHotkeyDisplayString(),
          onTap: showHotkeyPicker,
          isSelected: _selectedIndex == currentIndex,
        ),
        showHotkeyPicker);

    // Index Drives
    addItem(
        _buildSettingsItem(
          title: 'Index Drives (Experimental)',
          currentValue: _settings.indexDrives ? 'On' : 'Off',
          onTap: _toggleIndexDrives,
          isSelected: _selectedIndex == currentIndex,
        ),
        _toggleIndexDrives);

    // Excluded Drives (conditional)
    if (_settings.indexDrives) {
      void editExcludedDrives() {
        setState(() {
          _isEditingExcludedDrives = true;
          _excludedDrivesController.text = _settings.excludedDrives.join(', ');
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _excludedDrivesFocusNode.requestFocus();
        });
      }

      if (_selectedIndex == currentIndex && _isEditingExcludedDrives) {
        addItem(
            _buildEditableTextItem(
              title: 'Excluded Drives',
              controller: _excludedDrivesController,
              focusNode: _excludedDrivesFocusNode,
              isSelected: true,
              onSubmitted: _saveExcludedDrives,
            ),
            _saveExcludedDrives);
      } else {
        addItem(
            _buildSettingsItem(
              title: 'Excluded Drives',
              currentValue: _settings.excludedDrives.join(', ').isEmpty
                  ? 'None'
                  : _settings.excludedDrives.join(', '),
              onTap: editExcludedDrives,
              isSelected: _selectedIndex == currentIndex,
            ),
            editExcludedDrives);
      }
    }

    // AI Provider
    addItem(
        _buildSettingsItem(
          title: 'AI Provider',
          currentValue: _getProviderDisplayName(_settings.aiProvider),
          onTap: _cycleAiProvider,
          isSelected: _selectedIndex == currentIndex,
        ),
        _cycleAiProvider);

    // AI Model
    void editModel() {
      setState(() {
        _isEditingModel = true;
        _modelTextController.text = _settings.gemmaModel;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _modelFocusNode.requestFocus();
      });
    }

    if (_selectedIndex == currentIndex && _isEditingModel) {
      addItem(
          _buildEditableTextItem(
            title: _getModelLabel(),
            controller: _modelTextController,
            focusNode: _modelFocusNode,
            isSelected: true,
            onSubmitted: _saveModel,
          ),
          _saveModel);
    } else {
      addItem(
          _buildSettingsItem(
            title: _getModelLabel(),
            currentValue: _settings.gemmaModel,
            onTap: editModel,
            isSelected: _selectedIndex == currentIndex,
          ),
          editModel);
    }

    // SearxNG URL
    void editSearxngUrl() {
      setState(() {
        _isEditingSearxngUrl = true;
        _searxngUrlController.text = _settings.searxngUrl;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searxngUrlFocusNode.requestFocus();
      });
    }

    if (_selectedIndex == currentIndex && _isEditingSearxngUrl) {
      addItem(
          _buildEditableTextItem(
            title: 'SearxNG URL',
            controller: _searxngUrlController,
            focusNode: _searxngUrlFocusNode,
            isSelected: true,
            onSubmitted: _saveSearxngUrl,
          ),
          _saveSearxngUrl);
    } else {
      addItem(
          _buildSettingsItem(
            title: 'SearxNG URL',
            currentValue: _settings.searxngUrl,
            onTap: editSearxngUrl,
            isSelected: _selectedIndex == currentIndex,
          ),
          editSearxngUrl);
    }

    // OpenAI API Key
    void editOpenaiKey() {
      setState(() {
        _isEditingOpenaiKey = true;
        _openaiKeyController.text = _settings.openaiApiKey;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openaiKeyFocusNode.requestFocus();
      });
    }

    if (_selectedIndex == currentIndex && _isEditingOpenaiKey) {
      addItem(
          _buildEditableTextItem(
            title: 'OpenAI API Key',
            controller: _openaiKeyController,
            focusNode: _openaiKeyFocusNode,
            isSelected: true,
            onSubmitted: _saveOpenaiKey,
            isPassword: true,
          ),
          _saveOpenaiKey);
    } else {
      addItem(
          _buildSettingsItem(
            title: 'OpenAI API Key',
            currentValue: _maskApiKey(_settings.openaiApiKey),
            onTap: editOpenaiKey,
            isSelected: _selectedIndex == currentIndex,
          ),
          editOpenaiKey);
    }

    // Anthropic API Key
    void editAnthropicKey() {
      setState(() {
        _isEditingAnthropicKey = true;
        _anthropicKeyController.text = _settings.anthropicApiKey;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _anthropicKeyFocusNode.requestFocus();
      });
    }

    if (_selectedIndex == currentIndex && _isEditingAnthropicKey) {
      addItem(
          _buildEditableTextItem(
            title: 'Anthropic API Key',
            controller: _anthropicKeyController,
            focusNode: _anthropicKeyFocusNode,
            isSelected: true,
            onSubmitted: _saveAnthropicKey,
            isPassword: true,
          ),
          _saveAnthropicKey);
    } else {
      addItem(
          _buildSettingsItem(
            title: 'Anthropic API Key',
            currentValue: _maskApiKey(_settings.anthropicApiKey),
            onTap: editAnthropicKey,
            isSelected: _selectedIndex == currentIndex,
          ),
          editAnthropicKey);
    }

    // Gemini API Key
    void editGeminiKey() {
      setState(() {
        _isEditingGeminiKey = true;
        _geminiKeyController.text = _settings.geminiApiKey;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _geminiKeyFocusNode.requestFocus();
      });
    }

    if (_selectedIndex == currentIndex && _isEditingGeminiKey) {
      addItem(
          _buildEditableTextItem(
            title: 'Gemini API Key',
            controller: _geminiKeyController,
            focusNode: _geminiKeyFocusNode,
            isSelected: true,
            onSubmitted: _saveGeminiKey,
            isPassword: true,
          ),
          _saveGeminiKey);
    } else {
      addItem(
          _buildSettingsItem(
            title: 'Gemini API Key',
            currentValue: _maskApiKey(_settings.geminiApiKey),
            onTap: editGeminiKey,
            isSelected: _selectedIndex == currentIndex,
          ),
          editGeminiKey);
    }

    _settingsItems = items;
    _onEnterActions = onEnterActions;
  }

  Widget _buildHotkeyPicker() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Column(
      children: [
        SizedBox(
          height: listItemHeight,
          child: ListTile(
            title: Text('Choose Global Hotkey',
                style:
                    TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            trailing: Text('Press ESC to cancel',
                style: TextStyle(color: subtitleColor, fontSize: 12)),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _hotkeyOptions.length,
            itemBuilder: (context, index) {
              final option = _hotkeyOptions[index];
              final isCurrentHotkey = _settings.hotkeyKey == option['key'] &&
                  listEquals(
                      _settings.hotkeyModifiers, option['modifiers'] as List);

              final isSelected = index == _selectedHotkeyIndex;

              return Container(
                height: listItemHeight,
                color: isSelected
                    ? Colors.blue.withAlpha(128)
                    : Colors.transparent,
                child: ListTile(
                  title: Text(option['display'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : textColor,
                      )),
                  trailing: isCurrentHotkey
                      ? Icon(Icons.check,
                          color: isSelected ? Colors.white : Colors.green)
                      : null,
                  onTap: () => _selectHotkey(option),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _selectHotkey(Map<String, dynamic> option) async {
    await _settings.setHotkey(
        option['key'] as String, (option['modifiers'] as List).cast<String>());
    setState(() {
      _isShowingHotkeyPicker = false;
    });
    widget.onSettingsChanged();

    // Show a message about restarting the app
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Hotkey changed! Restart the app for changes to take effect.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
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
      height: listItemHeight,
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
      height: listItemHeight,
      color: isSelected ? Colors.blue.withAlpha(128) : Colors.transparent,
      child: ListTile(
        title: Text(title, style: TextStyle(color: textColor)),
        trailing: Text(currentValue, style: TextStyle(color: subtitleColor)),
        onTap: onTap,
      ),
    );
  }
}
