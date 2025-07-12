import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'loader.dart';
import 'swagger_filter.dart';

/// Result of processing a single swagger source
class ProcessResult {
  final String source;
  final String? outputPath;
  final int pathCount;
  final int tagCount;
  final String? error;
  final bool success;

  ProcessResult({
    required this.source,
    this.outputPath,
    this.pathCount = 0,
    this.tagCount = 0,
    this.error,
    required this.success,
  });

  ProcessResult.success({
    required this.source,
    required this.outputPath,
    required this.pathCount,
    required this.tagCount,
  })  : success = true,
        error = null;

  ProcessResult.failure({
    required this.source,
    required this.error,
  })  : success = false,
        outputPath = null,
        pathCount = 0,
        tagCount = 0;
}

/// Configuration for processing options
class ProcessingOptions {
  final bool concurrent;
  final int maxConcurrency;
  final bool verbose;
  final bool dryRun;
  final Duration? timeout;

  const ProcessingOptions({
    this.concurrent = true,
    this.maxConcurrency = 4,
    this.verbose = false,
    this.dryRun = false,
    this.timeout,
  });
}

/// High-performance processor for multiple swagger sources
class SwaggerProcessor {
  final ProcessingOptions options;
  final void Function(String)? onProgress;

  SwaggerProcessor({
    this.options = const ProcessingOptions(),
    this.onProgress,
  });

  /// Process multiple swagger sources with optional concurrency
  Future<List<ProcessResult>> processAll(
    SwaggerFilterConfig config,
  ) async {
    if (options.concurrent && config.swaggers.length > 1) {
      return _processConcurrent(config);
    } else {
      return _processSequential(config);
    }
  }

  /// Process single swagger source
  Future<ProcessResult> processSingle(
    SwaggerSourceConfig swaggerConfig,
    String? outputDir,
  ) async {
    try {
      onProgress?.call('Loading: ${swaggerConfig.source}');

      final swagger = await _loadWithTimeout(swaggerConfig.source);

      onProgress?.call('Filtering: ${swaggerConfig.source}');
      final filtered = filterPathsAdvanced(
        swagger['paths'] as Map<String, dynamic>,
        includePaths: swaggerConfig.includePaths,
        excludePaths: swaggerConfig.excludePaths,
        includeTags: swaggerConfig.includeTags,
        excludeTags: swaggerConfig.excludeTags,
      );

      final newSwagger = buildFilteredSwagger(swagger, filtered);

      if (options.dryRun) {
        return ProcessResult.success(
          source: swaggerConfig.source,
          outputPath: '[DRY-RUN]',
          pathCount: filtered.length,
          tagCount: (newSwagger['tags'] as List?)?.length ?? 0,
        );
      }

      // Generate output
      final outName = swaggerConfig.output ?? p.basename(swaggerConfig.source);
      final outDir = outputDir ?? 'filtered';
      await Directory(outDir).create(recursive: true);

      final outputPath = p.join(outDir, outName);
      await File(outputPath).writeAsString(
        _formatOutput(newSwagger),
      );

      return ProcessResult.success(
        source: swaggerConfig.source,
        outputPath: outputPath,
        pathCount: filtered.length,
        tagCount: (newSwagger['tags'] as List?)?.length ?? 0,
      );
    } catch (e) {
      return ProcessResult.failure(
        source: swaggerConfig.source,
        error: e.toString(),
      );
    }
  }

  Future<List<ProcessResult>> _processConcurrent(
    SwaggerFilterConfig config,
  ) async {
    final semaphore = Semaphore(options.maxConcurrency);
    final futures = config.swaggers.map((swaggerConfig) async {
      await semaphore.acquire();
      try {
        return await processSingle(swaggerConfig, config.outputDir);
      } finally {
        semaphore.release();
      }
    });

    return await Future.wait(futures);
  }

  Future<List<ProcessResult>> _processSequential(
    SwaggerFilterConfig config,
  ) async {
    final results = <ProcessResult>[];
    for (final swaggerConfig in config.swaggers) {
      final result = await processSingle(swaggerConfig, config.outputDir);
      results.add(result);
    }
    return results;
  }

  Future<Map<String, dynamic>> _loadWithTimeout(String source) async {
    final future = loadSwaggerFlexible(source);
    if (options.timeout != null) {
      return await future.timeout(options.timeout!);
    }
    return await future;
  }

  String _formatOutput(Map<String, dynamic> swagger) {
    // For now, just JSON with indentation
    // Could be extended to support YAML output
    return JsonEncoder.withIndent('  ').convert(swagger);
  }
}

/// Simple semaphore for controlling concurrency
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}
