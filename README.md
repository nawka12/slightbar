# SlightBar: Your Universal Search and Command Bar

SlightBar is a sleek and powerful universal search and command bar for Windows. Built with Flutter, it provides lightning-fast access to your applications, files, and AI-powered assistance with just a few keystrokes.

## ✨ Features

### 🔍 **Local Search & Indexing**
- **Application Search**: Quickly find and launch installed Windows applications.
- **Fast File Search**: Uses a background indexing service running in an isolate for near-instant file searches with zero UI blocking.
- **Multi-Drive Support**: Indexes user folders and all connected drives with intelligent recovery from interrupted sessions.
- **Smart Navigation**: Use arrow keys to navigate results, Enter to launch.
- **Background Processing**: All file indexing happens in a separate isolate, keeping the UI responsive at all times.

### 🤖 **AI Assistant** 
Start your query with `?` to access powerful AI capabilities:
- **Multiple AI Providers**: 
  - **Ollama** (Local LLMs) - Default: `qwen3:8b` *(Local installation required)*
  - **OpenAI** - Default: `gpt-o4-mini`
  - **Anthropic Claude** - Default: `claude-sonnet-4-20250514`
  - **Google Gemini** - Default: `gemini-2.5-flash-preview-05-20`
- **Web Search**: Get up-to-date information from the internet.
- **Web Scraping**: Extract content from web pages.
- **Weather Forecasts**: Check weather for any city.
- **Prayer Times**: Get daily Islamic prayer times for any city and country via the [Aladhan API](https://aladhan.com/prayer-times-api).
- **General Q&A**: Ask questions and get intelligent responses.

### ⚙️ **Configuration & Customization**
- **Global Hotkey**: Activate from anywhere with `Alt + Space` (Changeable in Settings).
- **Settings Panel**: Type `!s` to configure the application.
- **About View**: Type `!a` to view app information.
- **Commands**:
    - `!reindex`: Manually trigger a full re-scan of your files.
- **Theme Support**: Light, Dark, or System themes.
- **Granular Tool Control**: Enable/disable individual AI tools, including prayer times.
- **Drive Exclusion**: Exclude specific drives from indexing to improve performance.
- **Custom Models**: Configure different models for each AI provider.
- **API Key Management**: Secure storage of API keys for cloud providers.

### 🎯 **Platform Support**
- **Primary**: Windows 10/11
- **Architecture**: Universal Windows Platform support
- **Distribution**: Automated installer with Inno Setup

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** (3.6.1 or later) - [Installation Guide](https://docs.flutter.dev/get-started/install)
- **Windows 10/11** with development tools enabled

### Installation Options

#### Option 1: Pre-built Installer (Recommended)
1. Download the latest `SlightbarSetup.exe` from releases
2. Run the installer and follow the setup wizard
3. Launch SlightBar from Start Menu or Desktop shortcut

#### Option 2: Build from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/nawka12/slightbar.git
   ```

2. **Navigate to the project directory:**
   ```bash
   cd slightbar
   ```

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run for the first time:**
   The first time you run the app, it will begin indexing your files in the background using a dedicated isolate. This ensures the UI remains responsive while indexing proceeds. You can continue to use the app for application search and AI commands while indexing is in progress.
   ```bash
   flutter run -d windows
   ```

   Or build for release:
   ```bash
   flutter build windows --release
   ```

5. **Build installer (Optional):**
   ```bash
   build_installer.bat
   ```

## 📖 Usage Guide

### Basic Commands

| Command | Action |
|---------|--------|
| `Ctrl + /` | Show/Hide SlightBar |
| `text` | Search for applications and indexed files |
| `?query` | Ask AI assistant |
| `!s` | Open Settings |
| `!a` | Open About view |
| `!reindex`| Trigger a full file re-index |
| `Esc` | Hide SlightBar |
| `↑/↓` | Navigate results |
| `Enter` | Launch selected item |

### AI Assistant Examples

```
?What's the weather in New York?
?Search for Flutter documentation
?Prayer times in London, UK
?Explain quantum computing
?What's the latest news about AI?
```

### Settings Configuration

Access settings with `!s` to configure:

- **Theme**: Switch between Light, Dark, or System themes.
- **AI Tools**: Enable/disable web search, scraping, weather, and prayer times.
- **Excluded Drives**: Provide a comma-separated list of drive letters to exclude from indexing (e.g., `D, E`).
- **AI Provider**: Choose between Ollama, OpenAI, Anthropic, or Gemini.
- **AI Models**: Customize models for each provider.
- **API Keys**: Set up keys for cloud AI providers.
- **SearxNG URL**: Configure your self-hosted search instance.

## ⚠️ Experimental Features & Important Notes

- **Multi-Drive Indexing**: The feature to index non-system drives is **highly experimental and can be very slow**, especially on drives with a large number of files or a large Master File Table (MFT).
- **`!reindex` Command**: Use the `!reindex` command with caution. It triggers a full re-scan of all included drives, which can be resource-intensive and take a significant amount of time. It is recommended to let the initial indexing complete and only use this command if absolutely necessary.
- **Initial Index**: The file index is stored in `%APPDATA%\slightbar\file_index.jsonl` with progress tracking and recovery capabilities for interrupted sessions.
- **Background Processing**: All file operations run in isolates to maintain UI responsiveness during heavy indexing operations.

## 🔧 AI Tools Setup

### Ollama (Local AI Provider)

**Important**: Ollama requires local installation and only works with locally hosted models. 

To use Ollama with SlightBar:
1. **Install Ollama**: Download from [ollama.ai](https://ollama.ai)
2. **Pull the default model**: Run `ollama pull qwen3:8b` in your terminal
3. **Verify installation**: Ensure Ollama is running locally on the default port

Ollama provides privacy-focused AI processing entirely on your machine without requiring internet connectivity or API keys.

### SearXNG (Required for Web Tools)

The web search and scraping features require a locally running [SearXNG](https://github.com/searxng/searxng-docker) instance for privacy and reliability.

**Quick Setup with Docker:**
```bash
git clone https://github.com/searxng/searxng-docker.git
cd searxng-docker
docker-compose up -d
```

SearXNG will be available at `http://127.0.0.1:8080` (default configuration).

### API Keys for Cloud Providers

1. **OpenAI**: Get your API key from [OpenAI Platform](https://platform.openai.com/)
2. **Anthropic**: Get your API key from [Anthropic Console](https://console.anthropic.com/)
3. **Google Gemini**: Get your API key from [Google AI Studio](https://aistudio.google.com/apikey)

Enter these in Settings (`!s`) for the respective providers.

## 🏗️ Development

### Project Structure

```
lib/
├── main.dart                 # Main application entry point with UI logic
├── gemma.dart                # AI assistant logic and tool integration
├── file_index_service.dart   # File indexing service coordination
├── indexing_isolate.dart     # Background file indexing isolate implementation
├── settings_service.dart     # Settings management and persistence
├── settings_view.dart        # Settings UI
└── about_view.dart           # About/info view
```

### Key Dependencies

- `flutter`: UI framework
- `hotkey_manager`: Global hotkey support
- `window_manager`: Window positioning and behavior
- `shared_preferences`: Settings persistence
- `path_provider`: Finding local file paths
- `http`: API communication
- `flutter_markdown`: AI response formatting
- `screen_retriever`: Multi-monitor support

### Build Process

1. **Development Build:**
   ```bash
   flutter run -d windows
   ```

2. **Release Build:**
   ```bash
   flutter build windows --release
   ```

3. **Create Installer:**
   ```bash
   build_installer.bat
   ```
   *Requires Inno Setup to be installed*

## 🚀 Distribution

The project includes automated installer generation using Inno Setup:

- **Installer Script**: `installer_script.iss`
- **Build Script**: `build_installer.bat`
- **Output**: `installer_output/SlightbarSetup.exe`

The installer handles:
- Installation to Program Files
- Desktop shortcut creation (optional)
- Start Menu integration
- Proper uninstallation support

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

- Additional AI providers
- New AI tools and capabilities
- Search optimizations for large datasets
- UI/UX enhancements
- Performance optimizations
- Cross-platform support

Please feel free to submit issues and pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔄 Version

**Current Version**: 1.0.0+1

---

**Privacy Note**: SlightBar prioritizes your privacy by using self-hosted SearXNG for web search and storing all settings locally. API keys for cloud providers are stored securely on your device and never shared. The file index is also stored locally and is not transmitted anywhere.
