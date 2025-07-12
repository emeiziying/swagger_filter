import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'config.dart';
import 'loader.dart';
import 'swagger_filter.dart';
import 'validator.dart';

class SwaggerFilterBuilder implements Builder {
  final BuilderOptions options;
  SwaggerFilterBuilder(this.options);

  @override
  final buildExtensions = const {
    r'$lib$': ['.json']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    // 只处理特定的配置文件
    final inputFile = buildStep.inputId.path;

    if (!_isSwaggerFilterConfig(inputFile)) {
      return;
    }

    try {
      // 从YAML文件或build options读取配置
      final config = await _parseConfigFromInput(buildStep);

      // 如果没有配置，跳过处理
      if (config == null) {
        log.fine('swagger_filter: No configuration found, skipping processing');
        return;
      }

      final validation = SwaggerFilterValidator.validateConfig(config);

      if (!validation.isValid) {
        for (final error in validation.errors) {
          log.severe('swagger_filter: Configuration error: $error');
        }
        throw BuildException('Invalid swagger_filter configuration');
      }

      // 显示警告
      for (final warning in validation.warnings) {
        log.warning('swagger_filter: $warning');
      }

      // 处理每个swagger源
      for (int i = 0; i < config.swaggers.length; i++) {
        final swaggerCfg = config.swaggers[i];
        await _processSwaggerSource(
            swaggerCfg, config.outputDir, i + 1, config.swaggers.length);
      }
    } catch (e, stackTrace) {
      log.severe('swagger_filter: Build failed: $e');
      log.fine('swagger_filter: Stack trace: $stackTrace');
      rethrow;
    }
  }

  bool _isSwaggerFilterConfig(String filePath) {
    // 处理 lib 目录的触发
    return filePath.endsWith(r'$lib$');
  }

  Future<SwaggerFilterConfig?> _parseConfigFromInput(BuildStep buildStep) async {
    // 首先尝试查找 swagger_filter.yaml 文件
    try {
      final yamlAssetId =
          AssetId(buildStep.inputId.package, 'swagger_filter.yaml');
      if (await buildStep.canRead(yamlAssetId)) {
        final yamlContent = await buildStep.readAsString(yamlAssetId);
        return await _parseConfigFromYamlContent(yamlContent);
      }
    } catch (e) {
      log.fine('swagger_filter: Error reading swagger_filter.yaml: $e');
    }

    // 如果没有 swagger_filter.yaml，从 build options 读取配置
    return _parseConfigFromBuildOptions();
  }

  Future<SwaggerFilterConfig> _parseConfigFromYamlContent(
      String yamlContent) async {
    final yamlDoc = loadYaml(yamlContent);

    if (yamlDoc == null) {
      throw BuildException('swagger_filter.yaml is empty or invalid');
    }

    final Map<String, dynamic> config = Map<String, dynamic>.from(yamlDoc);

    final swaggersConfig = config['swaggers'] as List?;
    final outputDir = config['output_dir'] as String?;

    if (swaggersConfig == null || swaggersConfig.isEmpty) {
      throw BuildException(
          'No swaggers configured in swagger_filter.yaml. Please add swagger sources under swaggers');
    }

    try {
      final swaggers = swaggersConfig
          .map((swaggerMap) => SwaggerSourceConfig.fromMap(
              Map<String, dynamic>.from(swaggerMap)))
          .toList();

      return SwaggerFilterConfig(
        swaggers: swaggers,
        outputDir: outputDir,
      );
    } catch (e) {
      throw BuildException(
          'Invalid swagger configuration format in swagger_filter.yaml: $e');
    }
  }

  SwaggerFilterConfig? _parseConfigFromBuildOptions() {
    final swaggersConfig = options.config['swaggers'] as List?;
    final outputDir = options.config['output_dir'] as String?;

    if (swaggersConfig == null || swaggersConfig.isEmpty) {
      // 在开发模式下，如果没有配置就跳过处理，不抛出异常
      log.fine('swagger_filter: No swaggers configured in build.yaml, skipping processing');
      return null;
    }

    try {
      final swaggers = swaggersConfig
          .map(
              (swaggerMap) => SwaggerSourceConfig.fromMap(Map.from(swaggerMap)))
          .toList();

      return SwaggerFilterConfig(
        swaggers: swaggers,
        outputDir: outputDir,
      );
    } catch (e) {
      throw BuildException('Invalid swagger configuration format: $e');
    }
  }

  Future<void> _processSwaggerSource(SwaggerSourceConfig swaggerCfg,
      String? outputDir, int current, int total) async {
    final prefix = '[$current/$total]';

    try {
      // 加载swagger
      final swagger = await loadSwaggerFlexible(swaggerCfg.source);

      // 验证swagger文档
      final swaggerValidation =
          SwaggerFilterValidator.validateSwaggerDocument(swagger);
      if (!swaggerValidation.isValid) {
        for (final error in swaggerValidation.errors) {
          log.warning('swagger_filter: $prefix $error');
        }
      }

      // 过滤
      final originalPaths = swagger['paths'] as Map<String, dynamic>;
      final filtered = filterPathsAdvanced(
        swagger['paths'] as Map<String, dynamic>,
        includePaths: swaggerCfg.includePaths,
        excludePaths: swaggerCfg.excludePaths,
        includeTags: swaggerCfg.includeTags,
        excludeTags: swaggerCfg.excludeTags,
      );

      log.info(
          'swagger_filter: $prefix ${swaggerCfg.source} → ${originalPaths.length} → ${filtered.length} paths');

      if (filtered.isEmpty) {
        log.warning(
            'swagger_filter: $prefix No paths matched filters for ${swaggerCfg.source}');
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

      log.info('swagger_filter: $prefix Generated $outputPath');
    } catch (e, stackTrace) {
      log.severe(
          'swagger_filter: $prefix Error processing ${swaggerCfg.source}: $e');
      log.fine('swagger_filter: $prefix Stack trace: $stackTrace');
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
