import 'dart:io';
import 'package:yaml/yaml.dart';

class SwaggerSourceConfig {
  final String source;
  final List<String>? includePaths;
  final List<String>? excludePaths;
  final List<String>? includeTags;
  final List<String>? excludeTags;
  final String? output;

  SwaggerSourceConfig({
    required this.source,
    this.includePaths,
    this.excludePaths,
    this.includeTags,
    this.excludeTags,
    this.output,
  });

  factory SwaggerSourceConfig.fromMap(Map map) {
    return SwaggerSourceConfig(
      source: map['source'] as String,
      includePaths: (map['include_paths'] as List?)?.cast<String>(),
      excludePaths: (map['exclude_paths'] as List?)?.cast<String>(),
      includeTags: (map['include_tags'] as List?)?.cast<String>(),
      excludeTags: (map['exclude_tags'] as List?)?.cast<String>(),
      output: map['output'] as String?,
    );
  }
}

class SwaggerFilterConfig {
  final List<SwaggerSourceConfig> swaggers;
  final String? outputDir;

  SwaggerFilterConfig({required this.swaggers, this.outputDir});

  factory SwaggerFilterConfig.fromYamlFile(String path) {
    final content = File(path).readAsStringSync();
    final yaml = loadYaml(content);
    final swaggers = (yaml['swaggers'] as List)
        .map((e) => SwaggerSourceConfig.fromMap(Map.from(e)))
        .toList();
    return SwaggerFilterConfig(
      swaggers: swaggers,
      outputDir: yaml['output_dir'] as String?,
    );
  }
} 