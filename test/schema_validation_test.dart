import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('JSON Schema Validation Tests', () {
    test('schema file exists and is valid JSON', () {
      final schemaFile = File('schema/swagger_filter_schema.json');
      expect(schemaFile.existsSync(), isTrue, 
        reason: 'JSON Schema file should exist');
      
      final content = schemaFile.readAsStringSync();
      expect(() => jsonDecode(content), returnsNormally,
        reason: 'Schema file should be valid JSON');
      
      final schema = jsonDecode(content);
      expect(schema['\$schema'], isNotNull);
      expect(schema['title'], equals('Swagger Filter Configuration'));
      expect(schema['type'], equals('object'));
    });

    test('example configuration matches schema structure', () {
      final configFile = File('swagger_filter.yaml');
      if (configFile.existsSync()) {
        final content = configFile.readAsStringSync();
        final config = loadYaml(content);
        
        // Basic structure validation
        expect(config, isA<Map>());
        expect(config['swaggers'], isA<List>());
        
        if (config['output_dir'] != null) {
          expect(config['output_dir'], isA<String>());
        }
        
        final swaggers = config['swaggers'] as List;
        for (final swagger in swaggers) {
          expect(swagger, isA<Map>());
          expect(swagger['source'], isA<String>());
          expect(swagger['source'], isNotEmpty);
          
          // Validate path patterns if present
          if (swagger['include_paths'] != null) {
            final paths = swagger['include_paths'] as List;
            for (final path in paths) {
              expect(path, isA<String>());
              expect(path, startsWith('/'), 
                reason: 'Paths should start with /');
            }
          }
          
          if (swagger['exclude_paths'] != null) {
            final paths = swagger['exclude_paths'] as List;
            for (final path in paths) {
              expect(path, isA<String>());
              expect(path, startsWith('/'), 
                reason: 'Paths should start with /');
            }
          }
        }
      }
    });

    test('schema defines all required properties', () {
      final schemaFile = File('schema/swagger_filter_schema.json');
      final schema = jsonDecode(schemaFile.readAsStringSync());
      
      // Check main properties
      expect((schema['properties'] as Map).containsKey('swaggers'), isTrue);
      expect((schema['properties'] as Map).containsKey('output_dir'), isTrue);
      expect(schema['required'], contains('swaggers'));
      
      // Check SwaggerSource definition
      final swaggerSource = schema['definitions']['SwaggerSource'];
      expect(swaggerSource, isNotNull);
      expect((swaggerSource['properties'] as Map).containsKey('source'), isTrue);
      expect((swaggerSource['properties'] as Map).containsKey('include_paths'), isTrue);
      expect((swaggerSource['properties'] as Map).containsKey('exclude_paths'), isTrue);
      expect((swaggerSource['properties'] as Map).containsKey('include_tags'), isTrue);
      expect((swaggerSource['properties'] as Map).containsKey('exclude_tags'), isTrue);
      expect(swaggerSource['required'], contains('source'));
    });

    test('schema provides validation examples', () {
      final schemaFile = File('schema/swagger_filter_schema.json');
      final schema = jsonDecode(schemaFile.readAsStringSync());
      
      expect(schema['examples'], isNotNull);
      expect(schema['examples'], isA<List>());
      expect(schema['examples'].length, greaterThan(0));
      
      final example = schema['examples'][0];
      expect(example['swaggers'], isA<List>());
      expect(example['swaggers'].length, greaterThan(0));
    });

    test('path validation pattern works correctly', () {
      final schemaFile = File('schema/swagger_filter_schema.json');
      final schema = jsonDecode(schemaFile.readAsStringSync());
      
      final pathPattern = schema['definitions']['SwaggerSource']
          ['properties']['include_paths']['items']['pattern'];
      expect(pathPattern, equals('^/.*'));
      
      // Test pattern validation logic
      final validPaths = ['/users', '/api/v1', '/public/health'];
      final invalidPaths = ['users', 'api/v1', 'public'];
      
      final regex = RegExp(pathPattern);
      for (final path in validPaths) {
        expect(regex.hasMatch(path), isTrue, 
          reason: '$path should match pattern');
      }
      
      for (final path in invalidPaths) {
        expect(regex.hasMatch(path), isFalse, 
          reason: '$path should not match pattern');
      }
    });
  });
} 