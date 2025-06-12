import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:process_run/shell.dart';
import 'package:slightbar/gemma.dart';
import 'package:slightbar/settings_service.dart';
import 'package:slightbar/settings_view.dart';
import 'package:slightbar/about_view.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;
import 'package:open_file/open_file.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:url_launcher/url_launcher.dart';

const double windowWidth = 600;
const double searchBarHeight = 70;
const double listItemHeight = 60;
const int maxResults = 6;
const int maxFileResults = 50;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(windowWidth, searchBarHeight),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final screenSize = primaryDisplay.size;
    final windowSize = await windowManager.getSize();
    final x = (screenSize.width - windowSize.width) / 2;
    final y = screenSize.height * 0.3;
    await windowManager.setPosition(Offset(x, y));
    await windowManager.hide();
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, String> _installedApps = {};
  List<String> _filteredApps = [];
  List<String> _foundFiles = [];
  final TextEditingController _textController = TextEditingController();
  int _selectedIndex = 0;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _gemmaScrollController = ScrollController();
  String _gemmaResponse = '';
  bool _isGemmaLoading = false;
  bool _isShowingSettings = false;
  bool _isShowingAbout = false;
  List<String> _usedTools = [];
  final GlobalKey<SettingsViewState> _settingsViewKey =
      GlobalKey<SettingsViewState>();
  final GlobalKey<AboutViewState> _aboutViewKey = GlobalKey<AboutViewState>();

  @override
  void dispose() {
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _gemmaScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _registerHotKey();
    _textController.addListener(_onSearchChanged);
    _getInstalledApps();
    _resizeWindow();
  }

  /// Helper method to find which display contains the current cursor position
  Future<Display> _getCurrentDisplay() async {
    try {
      final cursorPosition = await screenRetriever.getCursorScreenPoint();
      final allDisplays = await screenRetriever.getAllDisplays();

      // Find the display that contains the cursor position
      for (final display in allDisplays) {
        final bounds = Rect.fromLTWH(
          display.visiblePosition?.dx ?? 0,
          display.visiblePosition?.dy ?? 0,
          display.visibleSize?.width ?? display.size.width,
          display.visibleSize?.height ?? display.size.height,
        );

        if (bounds.contains(cursorPosition)) {
          return display;
        }
      }

      // Fallback to primary display if cursor is not found on any display
      return await screenRetriever.getPrimaryDisplay();
    } catch (e) {
      // Fallback to primary display on any error
      return await screenRetriever.getPrimaryDisplay();
    }
  }

  /// Helper method to position window on the current display
  Future<void> _positionWindowOnCurrentScreen() async {
    final currentDisplay = await _getCurrentDisplay();
    final screenSize = currentDisplay.visibleSize ?? currentDisplay.size;
    final screenPosition = currentDisplay.visiblePosition ?? const Offset(0, 0);
    final windowSize = await windowManager.getSize();

    final x = screenPosition.dx + (screenSize.width - windowSize.width) / 2;
    final y = screenPosition.dy + screenSize.height * 0.3;

    await windowManager.setPosition(Offset(x, y));
  }

  void _handleCommand(String text) {
    final query = text.trim();
    if (query == '!s') {
      setState(() {
        _isShowingSettings = !_isShowingSettings;
        _isShowingAbout = false; // Hide about if settings is shown
        _selectedIndex = 0; // Reset selection
        // Clear other states
        _filteredApps = [];
        _foundFiles = [];
        _gemmaResponse = '';
        _isGemmaLoading = false;
      });
      _textController.clear();
      _resizeWindow();
      return;
    }
    if (query == '!a') {
      setState(() {
        _isShowingAbout = !_isShowingAbout;
        _isShowingSettings = false; // Hide settings if about is shown
        _selectedIndex = 0; // Reset selection
        // Clear other states
        _filteredApps = [];
        _foundFiles = [];
        _gemmaResponse = '';
        _isGemmaLoading = false;
      });
      _textController.clear();
      _resizeWindow();
      return;
    }
  }

  void _onSearchChanged() async {
    final query = _textController.text;

    if (query.trim() == '!s' || query.trim() == '!a') {
      _handleCommand(query);
      return;
    }

    if (query.startsWith('!')) {
      return; // Handled by key event
    }

    // Reset selected index on any change
    setState(() {
      _selectedIndex = 0;
    });

    // Hide settings and about if user types anything else
    if ((_isShowingSettings || _isShowingAbout) && query.isNotEmpty) {
      setState(() {
        _isShowingSettings = false;
        _isShowingAbout = false;
      });
    }

    if (SettingsService().aiEnabled && query.startsWith('?')) {
      // User is typing a Gemma query. Clear results and wait for Enter.
      setState(() {
        _filteredApps = [];
        _foundFiles = [];
        _gemmaResponse = '';
        _isGemmaLoading = false;
      });
      _resizeWindow();
    } else if (!SettingsService().aiEnabled && query.startsWith('?')) {
      setState(() {
        _filteredApps = [];
        _foundFiles = [];
        _gemmaResponse =
            'AI is disabled. You can enable it in settings (`!s`).';
        _isGemmaLoading = false;
        _usedTools.clear();
      });
      _resizeWindow();
    } else {
      // Standard local search logic
      setState(() {
        _gemmaResponse = '';
        _isGemmaLoading = false;
      });
      if (query.length > 2) {
        _filterApps();
        await _searchFiles();
      } else {
        setState(() {
          _filteredApps = [];
          _foundFiles = [];
        });
      }
      _resizeWindow();
    }
  }

  void _filterApps() {
    setState(() {
      _filteredApps = _installedApps.keys
          .where((appName) => appName
              .toLowerCase()
              .contains(_textController.text.toLowerCase()))
          .toList();
    });
  }

  Future<void> _searchFiles() async {
    final String? userProfilePath = Platform.environment['USERPROFILE'];
    final searchQuery = _textController.text;
    var shell = Shell();

    List<String> foundFiles = [];

    if (userProfilePath != null) {
      final List<String> userFoldersToSearch = [
        p.join(userProfilePath, 'Documents'),
        p.join(userProfilePath, 'Downloads'),
        p.join(userProfilePath, 'Desktop'),
        p.join(userProfilePath, 'Pictures'),
        p.join(userProfilePath, 'Music'),
      ];

      final pathsString = userFoldersToSearch
          .where((path) => Directory(path).existsSync())
          .map((d) => "'$d'")
          .join(',');

      if (pathsString.isNotEmpty) {
        final userFolderSearchScript =
            "Get-ChildItem -Path $pathsString -Recurse -File -Filter \"*$searchQuery*\" -ErrorAction SilentlyContinue | Select-Object -First $maxFileResults | ForEach-Object { \$_.FullName }";

        try {
          var results =
              await shell.run('powershell -command "$userFolderSearchScript"');
          if (results.isNotEmpty) {
            foundFiles.addAll(
                results.first.outText.split('\n').where((s) => s.isNotEmpty));
          }
        } on ShellException catch (e) {
          debugPrint('Error searching user folders: $e');
        }
      }
    }

    // Remove duplicates and update state
    setState(() {
      _foundFiles = foundFiles.toSet().toList();
    });
  }

  Future<void> _askGemma(String query) async {
    setState(() {
      _isGemmaLoading = true;
      _gemmaResponse = '';
      _usedTools.clear();
    });
    _resizeWindow(); // Resize for loading indicator

    await for (final chunk
        in GemmaService.askWithToolsStream(query, onToolUsage: (toolMessage) {
      setState(() {
        _gemmaResponse = toolMessage;
        _isGemmaLoading =
            false; // Show the tool message instead of loading spinner
      });
      _resizeWindow();
      _scrollToBottom();
    })) {
      switch (chunk['type']) {
        case 'chunk':
          setState(() {
            _gemmaResponse = chunk['fullResponse'] as String;
            _isGemmaLoading = false;
            // Update used tools if available
            _usedTools = SettingsService().toolsEnabled
                ? chunk['usedTools'] as List<String>
                : [];
          });
          _resizeWindow();
          _scrollToBottom();
          break;

        case 'tool_usage':
          setState(() {
            _gemmaResponse = chunk['content'] as String;
            _isGemmaLoading = false;
          });
          _resizeWindow();
          _scrollToBottom();
          break;

        case 'complete':
        case 'error':
          setState(() {
            _gemmaResponse = chunk['content'] as String;
            _usedTools = SettingsService().toolsEnabled
                ? chunk['usedTools'] as List<String>
                : [];
            _isGemmaLoading = false;
          });
          _resizeWindow();
          _scrollToBottom();
          break;
      }
    }
  }

  void _resizeWindow() {
    const maxVisibleResults = 5;
    final totalResults = _filteredApps.length + _foundFiles.length;
    final displayableResults = min(totalResults, maxResults);
    final visibleResultCount = min(displayableResults, maxVisibleResults);

    double newHeight = searchBarHeight;

    if (_isGemmaLoading) {
      newHeight += listItemHeight * 2; // for loading indicator and some space
    } else if (_gemmaResponse.isNotEmpty) {
      // For AI responses, use a fixed height that allows for scrolling
      // This provides a consistent experience for both short and long responses
      const aiResponseHeight = 400.0;
      newHeight += aiResponseHeight;
    } else if (_isShowingSettings || _isShowingAbout) {
      newHeight = 450; // Fixed height for settings and about
    } else if (displayableResults > 0) {
      newHeight += (visibleResultCount * listItemHeight) + 1; // +1 for divider
    }

    const maxWindowHeight = 600.0;
    windowManager.setSize(Size(windowWidth, min(newHeight, maxWindowHeight)));
  }

  Future<void> _getInstalledApps() async {
    var shell = Shell();
    try {
      var result = await shell.run(
          'powershell -command "Get-StartApps | Select-Object Name, AppID | ConvertTo-Json -Compress"');
      if (result.outText.isNotEmpty) {
        final Map<String, String> apps = {};
        dynamic appsJson;
        try {
          appsJson = jsonDecode(result.outText);
        } catch (e) {
          debugPrint("Error decoding JSON: $e");
          return;
        }

        if (appsJson is! List) {
          appsJson = [appsJson]; // handle single object case
        }

        for (var appInfo in appsJson) {
          if (appInfo['Name'] != null && appInfo['AppID'] != null) {
            final name = appInfo['Name'] as String;
            final appId = appInfo['AppID'] as String;
            if (name.isNotEmpty && appId.isNotEmpty) {
              apps[name] = appId;
            }
          }
        }
        setState(() {
          _installedApps = apps;
        });
      }
    } on ShellException catch (e) {
      // Handle error
      debugPrint('Error getting installed apps: $e');
    }
  }

  void _registerHotKey() async {
    HotKey hotKey = HotKey(
      key: PhysicalKeyboardKey.slash,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (hotKey) async {
        bool isVisible = await windowManager.isVisible();
        if (isVisible) {
          await windowManager.hide();
        } else {
          // Position window on current screen before showing
          await _positionWindowOnCurrentScreen();
          // Show window immediately and refresh apps in the background
          _getInstalledApps();
          await windowManager.show();
          await windowManager.focus();
          _searchFocusNode.requestFocus();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();

    // Determine brightness
    var brightness = MediaQuery.of(context).platformBrightness;
    if (settings.themeMode != ThemeMode.system) {
      brightness = settings.themeMode == ThemeMode.dark
          ? Brightness.dark
          : Brightness.light;
    }
    final isDarkMode = brightness == Brightness.dark;

    // Define theme-based colors
    final containerColor =
        isDarkMode ? Colors.black.withAlpha(204) : Colors.white.withAlpha(204);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.white70 : Colors.black54;
    final dividerColor = isDarkMode ? Colors.white24 : Colors.black12;
    final secondaryTextColor = isDarkMode ? Colors.white : Colors.black;

    final allDisplayResults =
        [..._filteredApps, ..._foundFiles].take(maxResults).toList();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Focus(
          focusNode: _focusNode,
          onKeyEvent: (node, event) => _handleKeyEvent(node, event),
          autofocus: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: TextField(
                        focusNode: _searchFocusNode,
                        controller: _textController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: hintColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    if (allDisplayResults.isNotEmpty ||
                        _gemmaResponse.isNotEmpty ||
                        _isGemmaLoading ||
                        _isShowingSettings ||
                        _isShowingAbout)
                      Divider(height: 1, color: dividerColor),
                    Expanded(
                      child: _isShowingSettings
                          ? SettingsView(
                              key: _settingsViewKey,
                              onSettingsChanged: () => setState(() {}))
                          : _isShowingAbout
                              ? AboutView(key: _aboutViewKey)
                              : _isGemmaLoading
                                  ? Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: secondaryTextColor),
                                      ),
                                    )
                                  : _gemmaResponse.isNotEmpty
                                      ? Scrollbar(
                                          controller: _gemmaScrollController,
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                            controller: _gemmaScrollController,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildToolIcons(
                                                    color: secondaryTextColor),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                      12.0),
                                                  child: MarkdownBody(
                                                    data: _gemmaResponse,
                                                    onTapLink:
                                                        (text, href, title) {
                                                      if (href != null) {
                                                        launchUrl(
                                                            Uri.parse(href));
                                                      }
                                                    },
                                                    styleSheet:
                                                        MarkdownStyleSheet(
                                                      p: TextStyle(
                                                          color: textColor,
                                                          fontSize: 14),
                                                      h1: TextStyle(
                                                          color: textColor,
                                                          fontSize: 24),
                                                      h2: TextStyle(
                                                          color: textColor,
                                                          fontSize: 20),
                                                      strong: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      listBullet: TextStyle(
                                                          color: textColor),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          controller: _scrollController,
                                          itemCount: allDisplayResults.length,
                                          itemBuilder: (context, index) {
                                            final itemPathOrName =
                                                allDisplayResults[index];
                                            final isApp = _installedApps
                                                .containsKey(itemPathOrName);
                                            final isSelected =
                                                index == _selectedIndex;

                                            final titleColor = isSelected
                                                ? Colors.white
                                                : textColor;
                                            final subtitleColor = isSelected
                                                ? Colors.white70
                                                : hintColor;

                                            Widget listItem;
                                            if (isApp) {
                                              listItem = ListTile(
                                                title: Text(
                                                  itemPathOrName,
                                                  style: TextStyle(
                                                      color: titleColor),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                onTap: () {
                                                  _launchApp(itemPathOrName);
                                                  _hideAndClear();
                                                },
                                              );
                                            } else {
                                              listItem = ListTile(
                                                title: Text(
                                                  p.basename(itemPathOrName),
                                                  style: TextStyle(
                                                      color: titleColor),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                subtitle: Text(
                                                  itemPathOrName,
                                                  style: TextStyle(
                                                      color: subtitleColor),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                onTap: () {
                                                  OpenFile.open(itemPathOrName);
                                                  _hideAndClear();
                                                },
                                              );
                                            }

                                            return Container(
                                              height: listItemHeight,
                                              color: isSelected
                                                  ? Colors.blue.withAlpha(128)
                                                  : Colors.transparent,
                                              child: listItem,
                                            );
                                          },
                                        ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _hideAndClear() {
    windowManager.hide();
    _textController.clear();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final query = _textController.text;

    // Always allow escape to close the window
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _hideAndClear();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (query.startsWith('!')) {
        _handleCommand(query);
        return KeyEventResult.handled;
      }

      if (SettingsService().aiEnabled && query.startsWith('?')) {
        final gemmaQuery = query.substring(1).trim();
        if (gemmaQuery.isNotEmpty && !_isGemmaLoading) {
          _askGemma(gemmaQuery);
        }
        return KeyEventResult.handled;
      }

      if (_isShowingSettings) {
        _settingsViewKey.currentState?.handleEnter();
        return KeyEventResult.handled;
      }

      if (_isShowingAbout) {
        _aboutViewKey.currentState?.handleEnter();
        return KeyEventResult.handled;
      }

      // Handle local search result selection
      if (!_isShowingSettings &&
          !_isShowingAbout &&
          !_isGemmaLoading &&
          _gemmaResponse.isEmpty) {
        final allDisplayResults =
            [..._filteredApps, ..._foundFiles].take(maxResults).toList();
        if (_selectedIndex >= 0 && _selectedIndex < allDisplayResults.length) {
          final itemPathOrName = allDisplayResults[_selectedIndex];
          final isApp = _installedApps.containsKey(itemPathOrName);
          if (isApp) {
            _launchApp(itemPathOrName);
          } else {
            OpenFile.open(itemPathOrName);
          }
          _hideAndClear();
          return KeyEventResult.handled;
        }
      }
    }

    // Handle list navigation only for local search results
    if (!_isShowingSettings &&
        !_isShowingAbout &&
        !_isGemmaLoading &&
        _gemmaResponse.isEmpty) {
      final allDisplayResults =
          [..._filteredApps, ..._foundFiles].take(maxResults).toList();

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (allDisplayResults.isNotEmpty) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1) % allDisplayResults.length;
          });
          _scrollToSelected();
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (allDisplayResults.isNotEmpty) {
          setState(() {
            _selectedIndex = (_selectedIndex - 1 + allDisplayResults.length) %
                allDisplayResults.length;
          });
          _scrollToSelected();
        }
        return KeyEventResult.handled;
      }
    }

    if (_isShowingSettings) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _settingsViewKey.currentState?.navigateDown();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _settingsViewKey.currentState?.navigateUp();
        return KeyEventResult.handled;
      }
    }

    if (_isShowingAbout) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _aboutViewKey.currentState?.navigateDown();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _aboutViewKey.currentState?.navigateUp();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _selectedIndex * listItemHeight,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToBottom() {
    // Auto-scroll to bottom for Gemma responses during streaming
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_gemmaScrollController.hasClients) {
        _gemmaScrollController.animateTo(
          _gemmaScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _launchApp(String appName) {
    final appId = _installedApps[appName];
    if (appId != null) {
      var shell = Shell();
      shell.run('powershell -command "explorer.exe shell:appsFolder\\$appId"');
    }
  }

  Widget _buildToolIcons({required Color color}) {
    // Don't show tool icons if AI or tools are disabled, or if no tools were used
    if (!SettingsService().aiEnabled ||
        !SettingsService().toolsEnabled ||
        _usedTools.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> icons = [];

    if (_usedTools.contains('search')) {
      icons.add(Icon(Icons.search, color: color, size: 16));
    }
    if (_usedTools.contains('scrape')) {
      icons.add(Icon(Icons.language, color: color, size: 16));
    }
    if (_usedTools.contains('weather')) {
      icons.add(Icon(Icons.cloud, color: color, size: 16));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ...icons.map((icon) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: icon,
              )),
          Text(
            'Sources used',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
