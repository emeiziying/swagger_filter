import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:swagger_filter/config.dart';
import 'package:swagger_filter/loader.dart';
import 'package:swagger_filter/swagger_filter.dart';
import 'package:swagger_filter/version.dart';
import 'package:path/path.dart' as p;

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('config',
        abbr: 'c',
        defaultsTo: 'swagger_filter.yaml',
        help: 'Configuration file path')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help information')
    ..addFlag('version',
        abbr: 'v', negatable: false, help: 'Show version information');

  try {
    final results = parser.parse(arguments);

    if (results['version'] as bool) {
      print(getVersionInfo());
      return;
    }

    if (results['help'] as bool) {
      print('Swagger Filter Tool - ${getVersionInfo()}');
      print('Usage: dart run swagger_filter [options]');
      print('');
      print(parser.usage);
      return;
    }

    final configPath = results['config'] as String;

    if (!File(configPath).existsSync()) {
      print('Error: Configuration file "$configPath" not found.');
      print(
          'Please create a configuration file or specify a valid path with --config');
      exit(1);
    }

    print('Loading configuration from: $configPath');
    final config = SwaggerFilterConfig.fromYamlFile(configPath);

    print('Processing ${config.swaggers.length} swagger source(s)...');

    for (int i = 0; i < config.swaggers.length; i++) {
      final swaggerCfg = config.swaggers[i];
      print(
          '[${i + 1}/${config.swaggers.length}] Processing: ${swaggerCfg.source}');

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

        // 输出文件名和路径
        String outName = swaggerCfg.output ?? p.basename(swaggerCfg.source);
        String outDir = config.outputDir ?? 'filtered';
        Directory(outDir).createSync(recursive: true);

        final outputPath = p.join(outDir, outName);
        File(outputPath).writeAsStringSync(
          JsonEncoder.withIndent('  ').convert(newSwagger),
        );

        print('  ✓ Generated: $outputPath');
        print(
            '  ✓ Paths: ${filtered.length}, Tags: ${newSwagger['tags']?.length ?? 0}');
      } catch (e) {
        print('  ✗ Error processing ${swaggerCfg.source}: $e');
      }
    }

    print('');
    print('✅ Swagger filtering completed!');
  } catch (e) {
    print('Error: $e');
    print('');
    print('Usage: dart run swagger_filter [options]');
    print(parser.usage);
    exit(1);
  }
}
