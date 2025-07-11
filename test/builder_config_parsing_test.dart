import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:swagger_filter/config.dart';

void main() {
  group('Builder Config Parsing Tests', () {
    test('应该能解析有效的 YAML 配置', () {
      const yamlContent = '''
swaggers:
  - source: "https://api.example.com/swagger.json"
    output: "filtered_api.json"
    include_paths:
      - "/api/v1/users"
      - "/api/v1/auth"
    exclude_paths:
      - "/api/v1/admin"
    include_tags: ["public"]
    exclude_tags: ["internal"]

output_dir: "./test_output"
''';

      final yamlDoc = loadYaml(yamlContent);
      final config = Map<String, dynamic>.from(yamlDoc);
      
      // 验证基本结构
      expect(config['output_dir'], equals('./test_output'));
      expect(config['swaggers'], isA<List>());
      
      final swaggersConfig = config['swaggers'] as List;
      expect(swaggersConfig.length, equals(1));
      
      // 验证swagger源配置
      final swaggerSource = SwaggerSourceConfig.fromMap(
        Map<String, dynamic>.from(swaggersConfig[0])
      );
      
      expect(swaggerSource.source, equals('https://api.example.com/swagger.json'));
      expect(swaggerSource.output, equals('filtered_api.json'));
      expect(swaggerSource.includePaths, contains('/api/v1/users'));
      expect(swaggerSource.includePaths, contains('/api/v1/auth'));
      expect(swaggerSource.excludePaths, contains('/api/v1/admin'));
      expect(swaggerSource.includeTags, contains('public'));
      expect(swaggerSource.excludeTags, contains('internal'));
    });

    test('应该能处理最小化 YAML 配置', () {
      const yamlContent = '''
swaggers:
  - source: "https://api.example.com/swagger.json"
''';

      final yamlDoc = loadYaml(yamlContent);
      final config = Map<String, dynamic>.from(yamlDoc);
      
      final swaggersConfig = config['swaggers'] as List;
      final swaggerSource = SwaggerSourceConfig.fromMap(
        Map<String, dynamic>.from(swaggersConfig[0])
      );
      
      expect(swaggerSource.source, equals('https://api.example.com/swagger.json'));
      expect(swaggerSource.output, isNull);
      expect(swaggerSource.includePaths, isNull);
      expect(swaggerSource.excludePaths, isNull);
      expect(swaggerSource.includeTags, isNull);
      expect(swaggerSource.excludeTags, isNull);
    });

    test('应该能处理多个 swagger 源', () {
      const yamlContent = '''
swaggers:
  - source: "https://api.example.com/v1/swagger.json"
    output: "v1_api.json"
    include_paths: ["/api/v1/users"]
  - source: "https://api.example.com/v2/swagger.json"
    output: "v2_api.json"
    include_paths: ["/api/v2/users"]
  - source: "./local_swagger.yaml"
    output: "local_api.json"
    include_tags: ["local"]

output_dir: "./filtered"
''';

      final yamlDoc = loadYaml(yamlContent);
      final config = Map<String, dynamic>.from(yamlDoc);
      
      final swaggersConfig = config['swaggers'] as List;
      expect(swaggersConfig.length, equals(3));
      
      // 验证第一个源
      final source1 = SwaggerSourceConfig.fromMap(
        Map<String, dynamic>.from(swaggersConfig[0])
      );
      expect(source1.source, equals('https://api.example.com/v1/swagger.json'));
      expect(source1.output, equals('v1_api.json'));
      
      // 验证第二个源
      final source2 = SwaggerSourceConfig.fromMap(
        Map<String, dynamic>.from(swaggersConfig[1])
      );
      expect(source2.source, equals('https://api.example.com/v2/swagger.json'));
      expect(source2.output, equals('v2_api.json'));
      
      // 验证第三个源（本地文件）
      final source3 = SwaggerSourceConfig.fromMap(
        Map<String, dynamic>.from(swaggersConfig[2])
      );
      expect(source3.source, equals('./local_swagger.yaml'));
      expect(source3.output, equals('local_api.json'));
      expect(source3.includeTags, contains('local'));
    });

    test('应该能处理复杂的过滤配置', () {
      const yamlContent = '''
swaggers:
  - source: "https://api.example.com/swagger.json"
    include_paths:
      - "/api/v1/users"
      - "/api/v1/auth/login"
      - "/api/v1/auth/logout"
    exclude_paths:
      - "/api/v1/admin"
      - "/api/v1/internal"
    include_tags:
      - "public"
      - "user"
      - "auth"
    exclude_tags:
      - "admin"
      - "internal"
      - "debug"
''';

      final yamlDoc = loadYaml(yamlContent);
      final config = Map<String, dynamic>.from(yamlDoc);
      
      final swaggersConfig = config['swaggers'] as List;
      final swaggerSource = SwaggerSourceConfig.fromMap(
        Map<String, dynamic>.from(swaggersConfig[0])
      );
      
      expect(swaggerSource.includePaths?.length, equals(3));
      expect(swaggerSource.excludePaths?.length, equals(2));
      expect(swaggerSource.includeTags?.length, equals(3));
      expect(swaggerSource.excludeTags?.length, equals(3));
      
      expect(swaggerSource.includePaths, contains('/api/v1/users'));
      expect(swaggerSource.excludePaths, contains('/api/v1/admin'));
      expect(swaggerSource.includeTags, contains('public'));
      expect(swaggerSource.excludeTags, contains('admin'));
    });

    test('应该处理空配置的情况', () {
      const yamlContent = '''
swaggers: []
output_dir: "./empty"
''';

      final yamlDoc = loadYaml(yamlContent);
      final config = Map<String, dynamic>.from(yamlDoc);
      
      expect(config['output_dir'], equals('./empty'));
      expect(config['swaggers'], isA<List>());
      expect((config['swaggers'] as List).isEmpty, isTrue);
    });

    test('应该处理缺少可选字段的情况', () {
      const yamlContent = '''
swaggers:
  - source: "https://api.example.com/swagger.json"
    include_paths: ["/api/v1/users"]
    # 缺少 output, exclude_paths, include_tags, exclude_tags
''';

      final yamlDoc = loadYaml(yamlContent);
      final config = Map<String, dynamic>.from(yamlDoc);
      
      final swaggersConfig = config['swaggers'] as List;
      final swaggerSource = SwaggerSourceConfig.fromMap(
        Map<String, dynamic>.from(swaggersConfig[0])
      );
      
      expect(swaggerSource.source, equals('https://api.example.com/swagger.json'));
      expect(swaggerSource.includePaths, contains('/api/v1/users'));
      expect(swaggerSource.output, isNull);
      expect(swaggerSource.excludePaths, isNull);
      expect(swaggerSource.includeTags, isNull);
      expect(swaggerSource.excludeTags, isNull);
    });

    test('SwaggerFilterConfig 应该能正确创建', () {
      final swaggerSource = SwaggerSourceConfig(
        source: 'https://api.example.com/swagger.json',
        output: 'test.json',
        includePaths: ['/api/v1/users'],
        excludePaths: ['/api/v1/admin'],
        includeTags: ['public'],
        excludeTags: ['internal'],
      );

      final config = SwaggerFilterConfig(
        swaggers: [swaggerSource],
        outputDir: './test_output',
      );

      expect(config.swaggers.length, equals(1));
      expect(config.outputDir, equals('./test_output'));
      expect(config.swaggers[0].source, equals('https://api.example.com/swagger.json'));
    });
  });
} 