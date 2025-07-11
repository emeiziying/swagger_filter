import 'package:test/test.dart';
import 'package:swagger_filter/swagger_filter.dart';

void main() {
  group('SwaggerFilter', () {
    final sampleSwagger = {
      'openapi': '3.0.0',
      'info': {'title': 'Test API', 'version': '1.0.0'},
      'paths': {
        '/user': {
          'get': {
            'tags': ['user'],
            'summary': 'Get user',
          },
        },
        '/admin': {
          'post': {
            'tags': ['admin'],
            'summary': 'Admin op',
          },
        },
        '/public': {
          'get': {
            'tags': ['public'],
            'summary': 'Public op',
          },
        },
      },
    };

    test('filter by path', () {
      final filtered = filterPaths(
        sampleSwagger['paths'] as Map<String, dynamic>,
        includePaths: ['/user'],
      );
      expect(filtered.keys, contains('/user'));
      expect(filtered.keys, isNot(contains('/admin')));
    });

    test('filter by tag', () {
      final filtered = filterPaths(
        sampleSwagger['paths'] as Map<String, dynamic>,
        includeTags: ['admin'],
      );
      expect(filtered.keys, contains('/admin'));
      expect(filtered['/admin'], isNotNull);
      expect(filtered['/admin'].keys, contains('post'));
      expect(filtered['/user'], isNull);
    });

    test('filter by path and tag', () {
      final filtered = filterPaths(
        sampleSwagger['paths'] as Map<String, dynamic>,
        includePaths: ['/user', '/admin'],
        includeTags: ['user'],
      );
      expect(filtered.keys, contains('/user'));
      expect(filtered['/user'].keys, contains('get'));
      expect(filtered.keys, isNot(contains('/admin')));
    });
  });

  group('Integration with smartOpsPro.json', () {
    final smartOpsProPath = 'swaggers/smartOpsPro.json';
    late Map<String, dynamic> swagger;

    setUpAll(() {
      swagger = loadSwagger(smartOpsProPath);
    });

    test('extract /workTeam/add API', () {
      final filtered = filterPaths(
        swagger['paths'] as Map<String, dynamic>,
        includePaths: ['/workTeam/add'],
      );
      expect(filtered.keys, contains('/workTeam/add'));
      expect(filtered['/workTeam/add'], isNotNull);
      expect(filtered['/workTeam/add'].keys, contains('post'));
      final newSwagger = buildFilteredSwagger(swagger, filtered);
      expect(newSwagger['paths'].keys, contains('/workTeam/add'));
      expect(newSwagger['paths']['/workTeam/add'].keys, contains('post'));
      // 可选：检查summary
      expect(newSwagger['paths']['/workTeam/add']['post']['summary'], contains('新增'));
    });
  });
}
