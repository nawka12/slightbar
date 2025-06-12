# SlightBar: Your Universal Search and Command Bar

SlightBar is a sleek and powerful universal search and command bar for Windows. Built with Flutter, it provides lightning-fast access to your applications, files, and AI-powered assistance with just a few keystrokes.

## ✨ Features

### 🔍 **Local Search**
- **Application Search**: Quickly find and launch installed Windows applications
- **File Search**: Search for files across your system
- **Smart Navigation**: Use arrow keys to navigate results, Enter to launch

### 🤖 **AI Assistant** 
Start your query with `?` to access powerful AI capabilities:
- **Multiple AI Providers**: 
  - **Ollama** (Local LLMs) - Default: `qwen3:8b` *(Local installation required)*
  - **OpenAI** - Default: `gpt-o4-mini`
  - **Anthropic Claude** - Default: `claude-sonnet-4-20250514`
  - **Google Gemini** - Default: `gemini-2.5-flash-preview-05-20`
- **Web Search**: Get up-to-date information from the internet
- **Web Scraping**: Extract content from web pages
- **Weather Forecasts**: Check weather for any city
- **General Q&A**: Ask questions and get intelligent responses

### ⚙️ **Configuration & Customization**
- **Global Hotkey**: Activate from anywhere with `Ctrl + /`
- **Settings Panel**: Type `!s` to configure the application
- **About View**: Type `!a` to view app information
- **Theme Support**: Light, Dark, or System themes
- **Granular Tool Control**: Enable/disable individual AI tools
- **Custom Models**: Configure different models for each AI provider
- **API Key Management**: Secure storage of API keys for cloud providers

### 🎯 **Platform Support**
- **Primary**: Windows 10/11
- **Architecture**: Universal Windows Platform support

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** (3.6.1 or later) - [Installation Guide](https://docs.flutter.dev/get-started/install)
- **Windows 10/11** with development tools enabled

### Installation

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

4. **Build and run:**
   ```bash
   flutter run -d windows
   ```

   Or build for release:
   ```bash
   flutter build windows --release
   ```

## 📖 Usage Guide

### Basic Commands

| Command | Action |
|---------|--------|
| `Ctrl + /` | Show/Hide SlightBar |
| `text` | Search for applications and files |
| `?query` | Ask AI assistant |
| `!s` | Open Settings |
| `!a` | Open About view |
| `Esc` | Hide SlightBar |
| `↑/↓` | Navigate results |
| `Enter` | Launch selected item |

### AI Assistant Examples

```
?What's the weather in New York?
?Search for Flutter documentation
?Explain quantum computing
?What's the latest news about AI?
```

### Settings Configuration

Access settings with `!s` to configure:

- **Theme**: Switch between Light, Dark, or System themes
- **AI Provider**: Choose between Ollama, OpenAI, Anthropic, or Gemini
- **AI Models**: Customize models for each provider
- **AI Tools**: Enable/disable web search, scraping, and weather
- **API Keys**: Set up keys for cloud AI providers
- **SearxNG URL**: Configure your self-hosted search instance

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
3. **Google Gemini**: Get your API key from [Google AI Studio](https://makersuite.google.com/)

Enter these in Settings (`!s`) for the respective providers.

## 🏗️ Development

### Project Structure

```
lib/
├── main.dart              # Main application entry point
├── settings_service.dart  # Settings management and persistence
├── settings_view.dart     # Settings UI
├── about_view.dart        # About/info view
└── gemma.dart            # AI assistant logic and tool integration
```

### Key Dependencies

- `flutter`: UI framework
- `hotkey_manager`: Global hotkey support
- `window_manager`: Window positioning and behavior
- `shared_preferences`: Settings persistence
- `http`: API communication
- `flutter_markdown`: AI response formatting

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

- Additional AI providers
- New AI tools and capabilities
- Cross-platform support (macOS, Linux)
- UI/UX enhancements
- Performance optimizations

Please feel free to submit issues and pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔄 Version

**Current Version**: 1.0.0+1

---

**Privacy Note**: SlightBar prioritizes your privacy by using self-hosted SearXNG for web search and storing all settings locally. API keys for cloud providers are stored securely on your device and never shared.
