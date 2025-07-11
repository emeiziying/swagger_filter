import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'config.dart';
import 'loader.dart';
import 'swagger_filter.dart';

class SwaggerFilterBuilder implements Builder {
  final BuilderOptions options;
  SwaggerFilterBuilder(this.options);

  @override
  final buildExtensions = const {
    '.dart': ['.swagger_filtered']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    // 从BuilderOptions读取配置
    final swaggersConfig = options.config['swaggers'] as List?;
    final outputDir = options.config['output_dir'] as String? ?? 'filtered';
    
    if (swaggersConfig == null || swaggersConfig.isEmpty) {
      log.warning('No swaggers configured in build.yaml');
      return;
    }
    
    for (final swaggerMap in swaggersConfig) {
      final swaggerCfg = SwaggerSourceConfig.fromMap(Map.from(swaggerMap));
      
      try {
        final swagger = await loadSwaggerFlexible(swaggerCfg.source);
        final filtered = filterPathsAdvanced(
          swagger['paths'] as Map<String, dynamic>,
          includePaths: swaggerCfg.includePaths,
          excludePaths: swaggerCfg.excludePaths,
          includeTags: swaggerCfg.includeTags,
          excludeTags: swaggerCfg.excludeTags,
        );
        final newSwagger = buildFilteredSwagger(swagger, filtered);
        
        // 输出文件名
        String outName = swaggerCfg.output ?? p.basename(swaggerCfg.source);
        Directory(outputDir).createSync(recursive: true);
        File(p.join(outputDir, outName)).writeAsStringSync(
          JsonEncoder.withIndent('  ').convert(newSwagger),
        );
        
        log.info('Generated: ${p.join(outputDir, outName)}');
      } catch (e) {
        log.severe('Error processing ${swaggerCfg.source}: $e');
      }
    }
  }
}

Builder swaggerFilterBuilder(BuilderOptions options) {
  return SwaggerFilterBuilder(options);
} 