import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'config.dart';
import 'loader.dart';
import 'swagger_filter.dart';
import 'validator.dart';

class SwaggerFilterBuilder implements Builder {
  final BuilderOptions options;
  SwaggerFilterBuilder(this.options);

  @override
  final buildExtensions = const {
    '.dart': ['.swagger_filtered']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    try {
      // 验证配置
      final config = _parseConfig();
      final validation = SwaggerFilterValidator.validateConfig(config);
      
      if (!validation.isValid) {
        for (final error in validation.errors) {
          log.severe('Configuration error: $error');
        }
        throw BuildException('Invalid swagger_filter configuration');
      }
      
      // 显示警告
      for (final warning in validation.warnings) {
        log.warning('Configuration warning: $warning');
      }
      
      log.info('Processing ${config.swaggers.length} swagger source(s)...');
      
      // 处理每个swagger源
      for (int i = 0; i < config.swaggers.length; i++) {
        final swaggerCfg = config.swaggers[i];
        await _processSwaggerSource(swaggerCfg, config.outputDir, i + 1, config.swaggers.length);
      }
      
      log.info('✅ Swagger filtering completed successfully!');
      
    } catch (e) {
      log.severe('Swagger filtering failed: $e');
      rethrow;
    }
  }
  
  SwaggerFilterConfig _parseConfig() {
    final swaggersConfig = options.config['swaggers'] as List?;
    final outputDir = options.config['output_dir'] as String?;
    
    if (swaggersConfig == null || swaggersConfig.isEmpty) {
      throw BuildException(
        'No swaggers configured in build.yaml. Please add swagger sources under options.swaggers'
      );
    }
    
    try {
      final swaggers = swaggersConfig
          .map((swaggerMap) => SwaggerSourceConfig.fromMap(Map.from(swaggerMap)))
          .toList();
      
      return SwaggerFilterConfig(
        swaggers: swaggers,
        outputDir: outputDir,
      );
    } catch (e) {
      throw BuildException('Invalid swagger configuration format: $e');
    }
  }
  
  Future<void> _processSwaggerSource(
    SwaggerSourceConfig swaggerCfg, 
    String? outputDir, 
    int current, 
    int total
  ) async {
    final prefix = '[$current/$total]';
    log.info('$prefix Processing: ${swaggerCfg.source}');
    
    try {
      // 加载swagger
      final swagger = await loadSwaggerFlexible(swaggerCfg.source);
      
      // 验证swagger文档
      final swaggerValidation = SwaggerFilterValidator.validateSwaggerDocument(swagger);
      if (!swaggerValidation.isValid) {
        for (final error in swaggerValidation.errors) {
          log.warning('$prefix Swagger document issue: $error');
        }
      }
      
      // 过滤
      final filtered = filterPathsAdvanced(
        swagger['paths'] as Map<String, dynamic>,
        includePaths: swaggerCfg.includePaths,
        excludePaths: swaggerCfg.excludePaths,
        includeTags: swaggerCfg.includeTags,
        excludeTags: swaggerCfg.excludeTags,
      );
      
      if (filtered.isEmpty) {
        log.warning('$prefix No paths matched the filtering criteria');
        return;
      }
      
      final newSwagger = buildFilteredSwagger(swagger, filtered);
      
      // 生成输出
      final outName = swaggerCfg.output ?? p.basename(swaggerCfg.source);
      final outDir = outputDir ?? 'generated';
      
      // 确保输出目录存在
      await Directory(outDir).create(recursive: true);
      
      final outputPath = p.join(outDir, outName);
      await File(outputPath).writeAsString(
        JsonEncoder.withIndent('  ').convert(newSwagger),
      );
      
      // 统计信息
      final originalPaths = (swagger['paths'] as Map).length;
      final filteredPaths = filtered.length;
      final originalTags = (swagger['tags'] as List?)?.length ?? 0;
      final filteredTags = (newSwagger['tags'] as List?)?.length ?? 0;
      
      log.info('$prefix ✓ Generated: $outputPath');
      log.info('$prefix ✓ Paths: $originalPaths → $filteredPaths, Tags: $originalTags → $filteredTags');
      
    } catch (e, stackTrace) {
      log.severe('$prefix ✗ Error processing ${swaggerCfg.source}: $e');
      log.severe('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// Creates the swagger filter builder
Builder swaggerFilterBuilder(BuilderOptions options) {
  return SwaggerFilterBuilder(options);
}

/// Exception thrown when build configuration is invalid
class BuildException implements Exception {
  final String message;
  BuildException(this.message);
  
  @override
  String toString() => 'BuildException: $message';
} 