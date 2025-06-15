import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

// --- Communication Protocol ---
// Messages from Main to Isolate: {'command': 'shutdown'}
// Messages from Isolate to Main:
//  {'type': 'send_port', 'data': SendPort}
//  {'type': 'status', 'data': 'Indexing status message'}
//  {'type': 'merged_chunk'}
//  {'type': 'complete'}
//  {'type': 'error', 'data': 'Error message'}

/// This is the entry point for the indexing isolate.
/// It will perform all file scanning and indexing operations in the background.
Future<void> startIndexingIsolate(Map<String, dynamic> initialData) async {
  // Isolate setup
  final mainPort = initialData['mainPort'] as SendPort;
  final isolateReceivePort = ReceivePort();
  mainPort.send({'type': 'send_port', 'data': isolateReceivePort.sendPort});

  final String indexFilePath = initialData['indexFilePath'];
  final String tempIndexFilePath = initialData['tempIndexFilePath'];
  final String progressFilePath = initialData['progressFilePath'];
  final String? userProfilePath = initialData['userProfilePath'];
  final String? systemDrive = initialData['systemDrive'];
  final List<String> excludedDrives =
      List<String>.from(initialData['excludedDrives'] ?? []);
  final bool indexDrives = initialData['indexDrives'] as bool? ?? false;

  final runner = _IsolateRunner(
      mainPort,
      indexFilePath,
      tempIndexFilePath,
      progressFilePath,
      userProfilePath,
      systemDrive,
      excludedDrives,
      indexDrives);

  isolateReceivePort.listen((message) {
    if (message is Map) {
      switch (message['command']) {
        case 'shutdown':
          runner.gracefulShutdown().then((_) {
            isolateReceivePort.close();
          });
          break;
        case 'search':
          final String query = message['query'];
          final int requestId = message['requestId'];
          runner.search(query).then((results) {
            mainPort.send({
              'type': 'search_result',
              'data': results,
              'requestId': requestId
            });
          });
          break;
        case 'rebuild':
          if (message['settings'] != null) {
            runner.updateSettings(message['settings'] as Map<String, dynamic>);
          }
          runner.rebuildIndex().then((_) {
            mainPort.send({'type': 'complete'});
          });
          break;
      }
    }
  });

  try {
    final command = initialData['command'] as String;
    if (command == 'rebuild') {
      await runner.rebuildIndex();
      mainPort.send({'type': 'complete'});
    } else if (command == 'resume') {
      await runner.resumeIndexing();
      mainPort.send({'type': 'complete'});
    } else if (command == 'load') {
      await runner.loadIndexForSearch();
      mainPort.send({'type': 'ready_for_search'});
    }
  } catch (e, stacktrace) {
    mainPort.send({
      'type': 'error',
      'data': 'Error in isolate: $e\nStacktrace: $stacktrace'
    });
  }
}

/// A class to encapsulate the state and logic of the indexing process
/// within the isolate, making it easier to manage.
class _IsolateRunner {
  final SendPort mainPort;
  final String indexFilePath;
  final String tempIndexFilePath;
  final String progressFilePath;
  final String? userProfilePath;
  final String? systemDrive;
  List<String> excludedDrives;
  bool indexDrives;

  Map<String, List<String>> _mainIndex = {};
  Map<String, List<String>> _tempIndex = {};

  _IsolateRunner(
      this.mainPort,
      this.indexFilePath,
      this.tempIndexFilePath,
      this.progressFilePath,
      this.userProfilePath,
      this.systemDrive,
      this.excludedDrives,
      this.indexDrives);

  void _sendStatus(String status) {
    mainPort.send({'type': 'status', 'data': status});
  }

  void updateSettings(Map<String, dynamic> newSettings) {
    if (newSettings.containsKey('excludedDrives')) {
      excludedDrives = List<String>.from(newSettings['excludedDrives'] as List);
    }
    if (newSettings.containsKey('indexDrives')) {
      indexDrives = newSettings['indexDrives'] as bool;
    }
  }

  Future<void> loadIndexForSearch() async {
    _sendStatus('Loading index for searching...');
    await _loadIndexFromFile();
    _sendStatus('Index loaded.');
  }

  Future<void> resumeIndexing() async {
    _sendStatus('Resuming indexing...');
    await _loadIndexFromFile();

    final recoveredTemp = await _loadTempIndex();
    if (recoveredTemp != null && recoveredTemp.isNotEmpty) {
      _sendStatus('Recovering data from previous session...');
      _mergeIndexIntoMain(recoveredTemp, _mainIndex);
      await _saveIndexToFile(_mainIndex);
      mainPort.send({'type': 'merged_chunk'});
      await _deleteTempIndex();
    }

    final progress = await _loadProgress();
    if (progress != null) {
      await _continueIndexing(progress);
    } else {
      await rebuildIndex();
    }
  }

  Future<void> rebuildIndex() async {
    _sendStatus('Preparing to index...');
    _tempIndex.clear();
    _mainIndex.clear();
    await _cleanupTempFiles();
    await _saveIndexToFile(_mainIndex); // Start with a clean index
    mainPort.send({'type': 'merged_chunk'}); // Notify UI to clear old results

    final List<String> pathsToScan = [];
    if (userProfilePath != null) {
      pathsToScan.addAll([
        p.join(userProfilePath!, 'Documents'),
        p.join(userProfilePath!, 'Downloads'),
        p.join(userProfilePath!, 'Desktop'),
        p.join(userProfilePath!, 'Pictures'),
        p.join(userProfilePath!, 'Music'),
      ]);
    }

    if (indexDrives) {
      final List<String> drives = await _getDrives();
      for (final drive in drives) {
        final driveLetter = drive.substring(0, 1);
        if ((systemDrive == null ||
                !drive.toUpperCase().startsWith(systemDrive!.toUpperCase())) &&
            !excludedDrives.contains(driveLetter.toUpperCase())) {
          pathsToScan.add(drive);
        }
      }
    }

    await _saveProgress(pathsToScan, 0);

    for (int i = 0; i < pathsToScan.length; i++) {
      final path = pathsToScan[i];
      final dir = Directory(path);
      if (await dir.exists()) {
        _sendStatus('Indexing: $path (${i + 1}/${pathsToScan.length})');
        await _scanDirectoryResumable(dir, pathsToScan, i, null, 0);

        _mergeIndexIntoMain(_tempIndex, _mainIndex);
        await _saveIndexToFile(_mainIndex);
        mainPort.send({'type': 'merged_chunk'});

        _tempIndex.clear();
        await _saveTempIndex(_tempIndex);
        await _saveProgress(pathsToScan, i + 1);
      }
    }
    await _cleanupTempFiles();
  }

  Future<void> _continueIndexing(Map<String, dynamic> progress) async {
    final allPaths = (progress['allPaths'] as List<dynamic>).cast<String>();
    final currentPathIndex = progress['currentPathIndex'] as int;
    final currentSubPath = progress['currentSubPath'] as String?;
    final currentFileIndex = progress['currentFileIndex'] as int? ?? 0;

    for (int i = currentPathIndex; i < allPaths.length; i++) {
      final path = allPaths[i];
      final dir = Directory(path);
      if (await dir.exists()) {
        _sendStatus('Resuming: $path (${i + 1}/${allPaths.length})');
        _tempIndex.clear();

        if (i == currentPathIndex && currentSubPath != null) {
          await _scanDirectoryResumable(
              dir, allPaths, i, currentSubPath, currentFileIndex);
        } else {
          await _scanDirectoryResumable(dir, allPaths, i, null, 0);
        }

        _mergeIndexIntoMain(_tempIndex, _mainIndex);
        await _saveIndexToFile(_mainIndex);
        mainPort.send({'type': 'merged_chunk'});

        _tempIndex.clear();
        await _saveTempIndex(_tempIndex);
        await _saveProgress(allPaths, i + 1);
      }
    }
    await _cleanupTempFiles();
  }

  Future<void> _scanDirectoryResumable(
      Directory dir,
      List<String> allPaths,
      int currentPathIndex,
      String? resumeFromSubPath,
      int resumeFromFileIndex) async {
    await _scanDirectoryResumableRecursive(dir, allPaths, currentPathIndex,
        resumeFromSubPath, resumeFromFileIndex, 0);
  }

  Future<int> _scanDirectoryResumableRecursive(
      Directory dir,
      List<String> allPaths,
      int currentPathIndex,
      String? resumeFromSubPath,
      int resumeFromFileIndex,
      int fileCounter) async {
    try {
      final entities = await dir.list(followLinks: false).toList();
      bool shouldSkip = resumeFromSubPath != null &&
          dir.path == resumeFromSubPath &&
          fileCounter < resumeFromFileIndex;

      for (final entity in entities) {
        if (entity is File) {
          fileCounter++;
          if (shouldSkip && fileCounter <= resumeFromFileIndex) continue;

          _addFileToIndex(entity.path, _tempIndex);

          if (fileCounter % 100 == 0) {
            await _saveTempIndex(_tempIndex);
            await _saveProgress(allPaths, currentPathIndex,
                currentSubPath: dir.path, currentFileIndex: fileCounter);
          }

          if (fileCounter % 1000 == 0) {
            _mergeIndexIntoMain(_tempIndex, _mainIndex);
            await _saveIndexToFile(_mainIndex);
            mainPort.send({'type': 'merged_chunk'});
            _tempIndex.clear();
            await _saveTempIndex(_tempIndex);
          }
        } else if (entity is Directory) {
          if (!await _isJunctionOrSymlink(entity)) {
            fileCounter = await _scanDirectoryResumableRecursive(
                entity,
                allPaths,
                currentPathIndex,
                resumeFromSubPath,
                resumeFromFileIndex,
                fileCounter);
          }
        }
      }
    } catch (e) {
      // Ignore "Access Denied" errors
    }
    return fileCounter;
  }

  Future<void> gracefulShutdown() async {
    _sendStatus('Shutting down gracefully...');
    if (_tempIndex.isNotEmpty) {
      _mergeIndexIntoMain(_tempIndex, _mainIndex);
      await _saveIndexToFile(_mainIndex);
      // No need to send merged_chunk, app is closing
    }
    // Delete the temp file, but KEEP the progress file so we can resume.
    await _deleteTempIndex();
    mainPort.send({'type': 'shutdown_complete'});
  }

  // --- Utility and File I/O Methods ---

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
  }

  void _addFileToIndex(String path, Map<String, List<String>> index) {
    final basename = p.basename(path);
    final normalized = _normalize(basename);
    (index[normalized] ??= []).add(path);
  }

  void _mergeIndexIntoMain(
      Map<String, List<String>> source, Map<String, List<String>> target) {
    for (final key in source.keys) {
      if (target.containsKey(key)) {
        final existingPaths = target[key]!.toSet();
        existingPaths.addAll(source[key]!);
        target[key] = existingPaths.toList();
      } else {
        target[key] = List.from(source[key]!);
      }
    }
  }

  Future<void> _loadIndexFromFile() async {
    _mainIndex.clear();
    final file = File(indexFilePath);
    if (!await file.exists()) return;

    final lines =
        file.openRead().transform(utf8.decoder).transform(const LineSplitter());
    try {
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final entry = jsonDecode(line) as Map<String, dynamic>;
        final key = entry['key'] as String;
        final paths = List<String>.from(entry['paths'] as List);
        (_mainIndex[key] ??= []).addAll(paths);
      }
    } catch (e) {
      // Corrupt or old format. Delete it.
      debugPrint(
          'Could not read index file, it may be corrupt or an old format. Deleting it.');
      _mainIndex.clear();
      try {
        await file.delete();
      } catch (_) {
        // ignore if deletion fails
      }
    }
  }

  Future<Map<String, List<String>>?> _loadTempIndex() async {
    try {
      final file = File(tempIndexFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          return decoded.map(
              (key, value) => MapEntry(key, List<String>.from(value as List)));
        }
      }
    } catch (e) {
      await _deleteTempIndex();
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadProgress() async {
    try {
      final file = File(progressFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          return jsonDecode(content) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  Future<void> _saveIndexToFile(Map<String, List<String>> index) async {
    try {
      final tempFile = File('$indexFilePath.new');
      await tempFile.parent.create(recursive: true);
      final sink = tempFile.openWrite();
      for (final entry in index.entries) {
        final line = jsonEncode({'key': entry.key, 'paths': entry.value});
        sink.writeln(line);
      }
      await sink.flush();
      await sink.close();

      // Atomic rename to replace the old file
      await tempFile.rename(indexFilePath);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _saveTempIndex(Map<String, List<String>> index) async {
    try {
      final file = File(tempIndexFilePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(index));
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _saveProgress(List<String> allPaths, int currentPathIndex,
      {String? currentSubPath, int currentFileIndex = 0}) async {
    try {
      final progressData = {
        'allPaths': allPaths,
        'currentPathIndex': currentPathIndex,
        'currentSubPath': currentSubPath,
        'currentFileIndex': currentFileIndex,
        'timestamp': DateTime.now().toIso8601String(),
      };
      final tempFile = File('$progressFilePath.new');
      await tempFile.parent.create(recursive: true);
      await tempFile.writeAsString(jsonEncode(progressData));

      // Atomic rename to replace the old file
      await tempFile.rename(progressFilePath);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _deleteTempIndex() async {
    try {
      final tempFile = File(tempIndexFilePath);
      if (await tempFile.exists()) await tempFile.delete();
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _cleanupTempFiles() async {
    await _deleteTempIndex();
    try {
      final progressFile = File(progressFilePath);
      if (await progressFile.exists()) await progressFile.delete();
    } catch (e) {
      // Ignore
    }
  }

  Future<bool> _isJunctionOrSymlink(Directory dir) async {
    try {
      final result =
          await Process.run('fsutil', ['reparsepoint', 'query', dir.path]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> _getDrives() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run('wmic', ['logicaldisk', 'get', 'name']);
      if (result.exitCode == 0) {
        return (result.stdout as String)
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.endsWith(':'))
            .map((line) => '$line\\')
            .toList();
      }
    } catch (e) {
      // Fallback
    }
    try {
      final result = await Process.run('fsutil', ['fsinfo', 'drives']);
      if (result.exitCode == 0) {
        return (result.stdout as String)
            .split(' ')
            .where((s) => s.contains(':\\'))
            .map((s) => s.trim())
            .toList();
      }
    } catch (e) {
      // Ignore
    }
    return [];
  }

  Future<List<String>> search(String query) async {
    if (query.isEmpty) {
      return [];
    }
    final normalizedQuery = _normalize(query);
    final Set<String> results = {};

    // Search items that are in memory.
    final allInMemoryItems = {..._mainIndex, ..._tempIndex};
    for (final key in allInMemoryItems.keys) {
      if (key.contains(normalizedQuery)) {
        results.addAll(allInMemoryItems[key]!);
      }
    }

    return results.toList();
  }
}
