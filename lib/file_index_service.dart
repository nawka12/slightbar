import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:slightbar/indexing_isolate.dart';
import 'package:slightbar/settings_service.dart';

class FileIndexService {
  // Singleton instance
  FileIndexService._privateConstructor();
  static final FileIndexService instance =
      FileIndexService._privateConstructor();

  static const String _indexFileName = 'file_index.jsonl';
  static const String _tempIndexFileName = 'file_index.tmp.json';
  static const String _progressFileName = 'index_progress.json';

  bool _isIndexing = false;
  String? _indexFilePath;
  String? _tempIndexFilePath;
  String? _progressFilePath;

  final indexingStatusNotifier = ValueNotifier<String>('');

  Isolate? _indexingIsolate;
  SendPort? _isolateSendPort;
  final _mainReceivePort = ReceivePort();

  int _searchRequestId = 0;
  final Map<int, Completer<List<String>>> _searchCompleters = {};
  Completer<void>? _shutdownCompleter;

  bool get isIndexing => _isIndexing;

  Future<void> init() async {
    final supportDir = await getApplicationSupportDirectory();
    _indexFilePath = p.join(supportDir.path, _indexFileName);
    _tempIndexFilePath = p.join(supportDir.path, _tempIndexFileName);
    _progressFilePath = p.join(supportDir.path, _progressFileName);

    _mainReceivePort.listen(_handleIsolateMessage);

    // The old recovery logic is now handled inside the isolate.
    // We just need to check if we should resume.
    if (await _hasIncompleteIndexing()) {
      debugPrint(
          'Found incomplete indexing session, resuming in background...');
      _resumeIndexing();
    } else if (SettingsService().isFirstRun) {
      debugPrint('No index found, building in background...');
      rebuildIndex();
      SettingsService().isFirstRun = false;
    } else {
      // If there's an index and no need to resume, just spawn the isolate
      // to handle searches by loading the existing index.
      await _spawnIsolate({'command': 'load'});
    }
  }

  void _handleIsolateMessage(dynamic message) {
    if (message is Map) {
      switch (message['type']) {
        case 'status':
          if (message['data'] is String) {
            final status = message['data'] as String;
            indexingStatusNotifier.value = status;
            if (status == 'Index loaded.') {
              Future.delayed(const Duration(seconds: 3), () {
                if (indexingStatusNotifier.value == 'Index loaded.') {
                  indexingStatusNotifier.value = '';
                }
              });
            }
          }
          break;
        case 'complete':
          _isIndexing = false;
          indexingStatusNotifier.value = 'Indexing complete!';
          debugPrint('Main thread received indexing completion notice.');
          Future.delayed(const Duration(seconds: 3), () {
            if (indexingStatusNotifier.value == 'Indexing complete!') {
              indexingStatusNotifier.value = '';
            }
          });
          // _shutdownIsolate(); // The isolate should persist to handle searches.
          break;
        case 'merged_chunk':
          debugPrint(
              'Main thread received notice of a merged chunk. The index is updated in the background.');
          break;
        case 'send_port':
          _isolateSendPort = message['data'];
          break;
        case 'error':
          _isIndexing = false;
          indexingStatusNotifier.value = 'Indexing error!';
          debugPrint('Error from isolate: ${message['data']}');
          _shutdownIsolate();
          break;
        case 'search_result':
          final int requestId = message['requestId'];
          final List<String> results = List<String>.from(message['data']);
          _searchCompleters[requestId]?.complete(results);
          _searchCompleters.remove(requestId);
          break;
        case 'ready_for_search':
          debugPrint('Isolate is ready for search requests.');
          break;
        case 'shutdown_complete':
          _shutdownCompleter?.complete();
          _shutdownIsolate();
          debugPrint('Isolate confirmed shutdown. Main thread can now exit.');
          break;
      }
    }
  }

  Future<void> _spawnIsolate(Map<String, dynamic> initialCommand) async {
    if (_indexingIsolate != null) {
      debugPrint('Isolate is already running.');
      return;
    }

    final initialData = {
      'mainPort': _mainReceivePort.sendPort,
      'indexFilePath': _indexFilePath,
      'tempIndexFilePath': _tempIndexFilePath,
      'progressFilePath': _progressFilePath,
      'userProfilePath': Platform.environment['USERPROFILE'],
      'systemDrive': Platform.environment['SystemDrive'],
      'excludedDrives': SettingsService().excludedDrives,
      'indexDrives': SettingsService().indexDrives,
    }..addAll(initialCommand);

    try {
      _indexingIsolate = await Isolate.spawn(startIndexingIsolate, initialData);
      debugPrint('Indexing isolate spawned.');
    } catch (e) {
      debugPrint('Failed to spawn isolate: $e');
      _isIndexing = false;
      indexingStatusNotifier.value = '';
    }
  }

  Future<void> rebuildIndex() async {
    if (_isIndexing) return;
    _isIndexing = true;
    indexingStatusNotifier.value = 'Preparing to index...';
    if (_isolateSendPort != null) {
      final settings = {
        'excludedDrives': SettingsService().excludedDrives,
        'indexDrives': SettingsService().indexDrives,
      };
      _isolateSendPort!.send({'command': 'rebuild', 'settings': settings});
    } else {
      await _spawnIsolate({'command': 'rebuild'});
    }
  }

  Future<void> _resumeIndexing() async {
    if (_isIndexing) return;
    _isIndexing = true;
    indexingStatusNotifier.value = 'Resuming indexing...';
    await _spawnIsolate({'command': 'resume'});
  }

  Future<bool> _hasIncompleteIndexing() async {
    if (_progressFilePath == null) return false;
    final progressFile = File(_progressFilePath!);
    return await progressFile.exists();
  }

  Future<void> gracefulShutdown() async {
    if (_isolateSendPort != null) {
      _shutdownCompleter = Completer<void>();
      _isolateSendPort!.send({'command': 'shutdown'});
      debugPrint(
          'Sent shutdown command to isolate. Waiting for confirmation...');

      // Wait for completion or timeout
      try {
        await _shutdownCompleter!.future.timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Graceful shutdown timed out or failed. Forcing exit.');
        _shutdownIsolate();
      }
    } else {
      _shutdownIsolate(); // Clean up if port was never established
    }
  }

  void _shutdownIsolate() {
    _indexingIsolate?.kill(priority: Isolate.immediate);
    _indexingIsolate = null;
    _isolateSendPort = null;
    debugPrint('Indexing isolate shut down.');
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
  }

  Future<List<String>> search(String query) async {
    if (_isolateSendPort == null || query.isEmpty) {
      return [];
    }

    final completer = Completer<List<String>>();
    final requestId = _searchRequestId++;
    _searchCompleters[requestId] = completer;

    _isolateSendPort!.send({
      'command': 'search',
      'query': query,
      'requestId': requestId,
    });

    // Timeout to prevent waiting forever if the isolate dies
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      _searchCompleters.remove(requestId);
      return []; // Return empty list on timeout
    });
  }
}
