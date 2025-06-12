import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutView extends StatefulWidget {
  const AboutView({super.key});

  @override
  State<AboutView> createState() => AboutViewState();
}

class AboutViewState extends State<AboutView> {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();

  // About information
  static const String appName = 'SlightBar';
  static const String version = '1.0.0';
  static const String buildNumber = '1';
  static const String creator = 'nawka12 (a.k.a KayfaHaarukku)';
  static const String license = 'MIT License';
  static const String githubUrl = 'https://github.com/nawka12/slightbar';

  // Dependencies from pubspec.yaml
  static const List<String> dependencies = [
    'flutter',
    'hotkey_manager: ^0.2.1',
    'file_picker: ^8.0.0+1',
    'window_manager: ^0.3.7',
    'process_run: ^0.13.2',
    'path_provider: ^2.0.11',
    'open_file: ^3.2.1',
    'http: ^1.2.1',
    'url_launcher: ^6.3.1',
    'html: ^0.15.4',
    'flutter_markdown: ^0.7.1',
    'intl: ^0.19.0',
    'shared_preferences: ^2.2.3',
    'cupertino_icons: ^1.0.8',
    'screen_retriever: ^0.1.9',
    'path: ^1.9.0',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Widget> _buildAboutItems() {
    return [
      _buildInfoItem('App Name', appName),
      _buildInfoItem('Version', version),
      _buildInfoItem('Build Number', buildNumber),
      _buildInfoItem('Creator', creator),
      _buildInfoItem('License', license),
      _buildClickableItem('GitHub Repository', githubUrl),
      _buildDependenciesSection(),
    ];
  }

  void navigateDown() {
    const totalItems = 7; // Number of about items
    setState(() {
      _selectedIndex = (_selectedIndex + 1) % totalItems;
    });
    _scrollToSelected();
  }

  void navigateUp() {
    const totalItems = 7; // Number of about items
    setState(() {
      _selectedIndex = (_selectedIndex - 1 + totalItems) % totalItems;
    });
    _scrollToSelected();
  }

  void handleEnter() {
    if (_selectedIndex == 5) {
      // GitHub Repository item
      _launchUrl(githubUrl);
    }
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      const itemHeight = 70.0; // Approximate height of each item
      final targetOffset = _selectedIndex * itemHeight;
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final selectedColor = Colors.blue.withAlpha(128);

    final aboutItems = _buildAboutItems();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: textColor,
              ),
              const SizedBox(height: 8),
              Text(
                'About $appName',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        // About items
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: aboutItems.length,
            itemBuilder: (context, index) {
              final isSelected = index == _selectedIndex;
              return Container(
                color: isSelected ? selectedColor : Colors.transparent,
                child: aboutItems[index],
              );
            },
          ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'Use ↑↓ to navigate • Enter to open links • Esc to close',
            style: TextStyle(
              fontSize: 12,
              color: subtitleColor,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String title, String value) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;

    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(color: subtitleColor),
      ),
      trailing: IconButton(
        icon: Icon(Icons.copy, color: subtitleColor, size: 18),
        onPressed: () => _copyToClipboard(value),
      ),
    );
  }

  Widget _buildClickableItem(String title, String url) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final linkColor = isDarkMode ? Colors.lightBlueAccent : Colors.blue;

    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        url,
        style: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
        ),
      ),
      trailing: Icon(Icons.open_in_new, color: linkColor, size: 18),
      onTap: () => _launchUrl(url),
    );
  }

  Widget _buildDependenciesSection() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;

    return ExpansionTile(
      title: Text(
        'Dependencies',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${dependencies.length} packages',
        style: TextStyle(color: subtitleColor),
      ),
      iconColor: textColor,
      collapsedIconColor: textColor,
      children: dependencies.map((dep) {
        return ListTile(
          dense: true,
          title: Text(
            dep,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.copy, color: subtitleColor, size: 16),
            onPressed: () => _copyToClipboard(dep),
          ),
        );
      }).toList(),
    );
  }
}
