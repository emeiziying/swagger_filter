import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:swagger_filter/swagger_filter.dart';
import 'package:swagger_filter/config.dart';

void main() {
  group('Basic Filtering Tests', () {
    final sampleOpenAPI3 = {
      'openapi': '3.0.0',
      'info': {'title': 'Test API', 'version': '1.0.0'},
      'paths': {
        '/user/profile': {
          'get': {
            'tags': ['user'],
            'summary': 'Get user profile',
            'parameters': [
              {
                'name': 'id',
                'in': 'path',
                'schema': {'\$ref': '#/components/schemas/UserId'}
              }
            ],
            'responses': {
              '200': {
                'content': {
                  'application/json': {
                    'schema': {'\$ref': '#/components/schemas/User'}
                  }
                }
              }
            }
          },
        },
        '/admin/users': {
          'post': {
            'tags': ['admin'],
            'summary': 'Create user',
            'requestBody': {
              'content': {
                'application/json': {
                  'schema': {'\$ref': '#/components/schemas/CreateUser'}
                }
              }
            }
          },
        },
        '/public/health': {
          'get': {
            'tags': ['public'],
            'summary': 'Health check',
          },
        },
      },
      'components': {
        'schemas': {
          'User': {
            'type': 'object',
            'properties': {
              'id': {'\$ref': '#/components/schemas/UserId'},
              'name': {'type': 'string'},
              'profile': {'\$ref': '#/components/schemas/UserProfile'}
            }
          },
          'UserId': {'type': 'string'},
          'UserProfile': {
            'type': 'object',
            'properties': {
              'bio': {'type': 'string'},
              'settings': {'\$ref': '#/components/schemas/UserSettings'}
            }
          },
          'UserSettings': {
            'type': 'object',
            'properties': {'theme': {'type': 'string'}}
          },
          'CreateUser': {
            'type': 'object',
            'properties': {'name': {'type': 'string'}}
          },
          'UnusedSchema': {'type': 'object'}
        }
      },
      'tags': [
        {'name': 'user', 'description': 'User operations'},
        {'name': 'admin', 'description': 'Admin operations'},
        {'name': 'public', 'description': 'Public operations'},
        {'name': 'unused', 'description': 'Unused tag'}
      ]
    };

    

         test('filterPaths - by includePaths only', () {
       final filtered = filterPaths(
         sampleOpenAPI3['paths'] as Map<String, dynamic>,
         includePaths: ['/user/profile'],
       );
       expect(filtered.keys, contains('/user/profile'));
       expect(filtered.keys, hasLength(1));
     });

    test('filterPaths - by includeTags only', () {
      final filtered = filterPaths(
        sampleOpenAPI3['paths'] as Map<String, dynamic>,
        includeTags: ['admin', 'public'],
      );
      expect(filtered.keys, containsAll(['/admin/users', '/public/health']));
      expect(filtered.keys, hasLength(2));
    });

    test('filterPaths - mixed path and tag filtering', () {
      final filtered = filterPaths(
        sampleOpenAPI3['paths'] as Map<String, dynamic>,
        includePaths: ['/user/profile', '/admin/users'],
        includeTags: ['user'],
      );
      expect(filtered.keys, contains('/user/profile'));
      expect(filtered.keys, isNot(contains('/admin/users')));
      expect(filtered.keys, hasLength(1));
    });

         test('filterPathsAdvanced - include priority over exclude', () {
       final filtered = filterPathsAdvanced(
         sampleOpenAPI3['paths'] as Map<String, dynamic>,
         includePaths: ['/user/profile'],
         excludePaths: ['/user/profile'], // should be ignored due to include priority
       );
       expect(filtered.keys, contains('/user/profile'));
       expect(filtered.keys, hasLength(1));
     });

    test('filterPathsAdvanced - exclude paths', () {
      final filtered = filterPathsAdvanced(
        sampleOpenAPI3['paths'] as Map<String, dynamic>,
        excludePaths: ['/admin/users'],
      );
      expect(filtered.keys, containsAll(['/user/profile', '/public/health']));
      expect(filtered.keys, isNot(contains('/admin/users')));
      expect(filtered.keys, hasLength(2));
    });

    test('filterPathsAdvanced - exclude tags', () {
      final filtered = filterPathsAdvanced(
        sampleOpenAPI3['paths'] as Map<String, dynamic>,
        excludeTags: ['admin'],
      );
      expect(filtered.keys, containsAll(['/user/profile', '/public/health']));
      expect(filtered.keys, isNot(contains('/admin/users')));
      expect(filtered.keys, hasLength(2));
    });

    test('filterPathsAdvanced - complex include/exclude logic', () {
      final filtered = filterPathsAdvanced(
        sampleOpenAPI3['paths'] as Map<String, dynamic>,
        includeTags: ['user', 'public'],
        excludePaths: ['/public/health'],
      );
      expect(filtered.keys, contains('/user/profile'));
      expect(filtered.keys, isNot(contains('/public/health')));
      expect(filtered.keys, hasLength(1));
    });
  });

  group('精准路径匹配测试', () {
    test('精确路径匹配', () {
      final paths = {
        '/users': {'get': {'summary': 'Get users'}},
        '/users/123': {'get': {'summary': 'Get user by ID'}},
        '/user': {'get': {'summary': 'Get current user'}},
        '/users-admin': {'get': {'summary': 'Admin users'}},
      };

      // 精确匹配 "/users" 应该只匹配 "/users"
      final filtered = filterPathsAdvanced(
        paths,
        includePaths: ['/users'],
      );

      expect(filtered.keys, contains('/users'));
      expect(filtered.keys, isNot(contains('/users/123')));
      expect(filtered.keys, isNot(contains('/user')));
      expect(filtered.keys, isNot(contains('/users-admin')));
    });

    test('精确匹配验证', () {
      final paths = {
        '/api': {'get': {'summary': 'API root'}},
        '/api/v1/users': {'get': {'summary': 'V1 users'}},
        '/api/v2/users': {'get': {'summary': 'V2 users'}},
        '/api-docs': {'get': {'summary': 'API docs'}},
        '/apikey': {'get': {'summary': 'API key'}},
      };

      // "/api" 应该只匹配 "/api"，不匹配子路径
      final filtered = filterPathsAdvanced(
        paths,
        includePaths: ['/api'],
      );

      expect(filtered.keys, contains('/api'));
      expect(filtered.keys, isNot(contains('/api/v1/users')));
      expect(filtered.keys, isNot(contains('/api/v2/users')));
      expect(filtered.keys, isNot(contains('/api-docs')));
      expect(filtered.keys, isNot(contains('/apikey')));
    });

    test('多个精准路径匹配', () {
      final paths = {
        '/users': {'get': {'summary': 'Users'}},
        '/users/profile': {'get': {'summary': 'User profile'}},
        '/admin': {'get': {'summary': 'Admin'}},
        '/admin/users': {'get': {'summary': 'Admin users'}},
        '/public': {'get': {'summary': 'Public'}},
        '/public-api': {'get': {'summary': 'Public API'}},
      };

      final filtered = filterPathsAdvanced(
        paths,
        includePaths: ['/users', '/admin'],
      );

      expect(filtered.keys, containsAll(['/users', '/admin']));
      expect(filtered.keys, isNot(contains('/users/profile')));
      expect(filtered.keys, isNot(contains('/admin/users')));
      expect(filtered.keys, isNot(contains('/public')));
      expect(filtered.keys, isNot(contains('/public-api')));
    });

    test('根路径匹配', () {
      final paths = {
        '/': {'get': {'summary': 'Root'}},
        '/health': {'get': {'summary': 'Health check'}},
        '/api': {'get': {'summary': 'API'}},
      };

      // 根路径应该只匹配 "/"
      final filtered = filterPathsAdvanced(
        paths,
        includePaths: ['/'],
      );

      expect(filtered.keys, contains('/'));
      expect(filtered.keys, isNot(contains('/health')));
      expect(filtered.keys, isNot(contains('/api')));
    });

    test('exclude路径精准匹配', () {
      final paths = {
        '/users': {'get': {'summary': 'Users'}},
        '/users/admin': {'get': {'summary': 'User admin'}},
        '/admin': {'get': {'summary': 'Admin'}},
        '/admin/config': {'get': {'summary': 'Admin config'}},
        '/admins': {'get': {'summary': 'Admins list'}},
      };

      // 排除 "/admin" 应该只排除 "/admin"
      final filtered = filterPathsAdvanced(
        paths,
        excludePaths: ['/admin'],
      );

      expect(filtered.keys, containsAll(['/users', '/users/admin', '/admin/config', '/admins']));
      expect(filtered.keys, isNot(contains('/admin')));
    });
  });

  group('Swagger Building and Schema Cleanup Tests', () {
    final testSwagger = {
      'openapi': '3.0.0',
      'info': {'title': 'Test API', 'version': '1.0.0'},
      'paths': {
        '/users': {
          'get': {
            'tags': ['user'],
            'responses': {
              '200': {
                'content': {
                  'application/json': {
                    'schema': {'\$ref': '#/components/schemas/User'}
                  }
                }
              }
            }
          },
        },
      },
      'components': {
        'schemas': {
          'User': {
            'type': 'object',
            'properties': {
              'profile': {'\$ref': '#/components/schemas/UserProfile'}
            }
          },
          'UserProfile': {
            'type': 'object',
            'properties': {
              'settings': {'\$ref': '#/components/schemas/UserSettings'}
            }
          },
          'UserSettings': {
            'type': 'object',
            'properties': {'theme': {'type': 'string'}}
          },
          'UnusedSchema': {'type': 'object'},
          'AnotherUnused': {'type': 'object'}
        }
      },
      'tags': [
        {'name': 'user'},
        {'name': 'admin'},
        {'name': 'unused'}
      ]
    };

         test('buildFilteredSwagger - OpenAPI 3.0 schema cleanup', () {
       final filteredPaths = {
         '/users': (testSwagger['paths'] as Map<String, dynamic>)['/users']
       };
      final result = buildFilteredSwagger(testSwagger, filteredPaths);
      
      // Check paths
      expect(result['paths'].keys, contains('/users'));
      
      // Check tags cleanup
      expect(result['tags'], hasLength(1));
      expect(result['tags'][0]['name'], equals('user'));
      
      // Check schema cleanup - should include User, UserProfile, UserSettings but not unused ones
      final schemas = result['components']['schemas'] as Map;
      expect(schemas.keys, containsAll(['User', 'UserProfile', 'UserSettings']));
      expect(schemas.keys, isNot(contains('UnusedSchema')));
      expect(schemas.keys, isNot(contains('AnotherUnused')));
      expect(schemas.keys, hasLength(3));
    });

    test('buildFilteredSwagger - OpenAPI 2.0 definitions cleanup', () {
      final swagger2 = {
        'swagger': '2.0',
        'info': {'title': 'Test API', 'version': '1.0.0'},
        'paths': {
          '/users': {
            'get': {
              'tags': ['user'],
              'responses': {
                '200': {
                  'schema': {'\$ref': '#/definitions/User'}
                }
              }
            },
          },
        },
        'definitions': {
          'User': {
            'type': 'object',
            'properties': {
              'profile': {'\$ref': '#/definitions/UserProfile'}
            }
          },
          'UserProfile': {'type': 'object'},
          'UnusedDef': {'type': 'object'}
        },
        'tags': [
          {'name': 'user'},
          {'name': 'unused'}
        ]
      };

             final filteredPaths = {
         '/users': (swagger2['paths'] as Map<String, dynamic>)['/users']
       };
      final result = buildFilteredSwagger(swagger2, filteredPaths);
      
      // Check definitions cleanup
      final definitions = result['definitions'] as Map;
      expect(definitions.keys, containsAll(['User', 'UserProfile']));
      expect(definitions.keys, isNot(contains('UnusedDef')));
      expect(definitions.keys, hasLength(2));
    });

    test('buildFilteredSwagger - empty filtered paths', () {
      final result = buildFilteredSwagger(testSwagger, {});
      
      expect(result['paths'], isEmpty);
      expect(result['tags'], isEmpty);
      
      if (result['components'] != null) {
        final schemas = result['components']['schemas'] as Map?;
        expect(schemas, isEmpty);
      }
    });
  });

  group('File Loading Tests', () {
         test('loadSwagger - JSON file', () {
       final swagger = loadSwagger('test/test_swagger.json');
       expect(swagger, isNotEmpty);
       expect(swagger.keys, contains('paths'));
       expect(swagger.keys, contains('info'));
     });

    test('loadSwagger - file not found', () {
      expect(
        () => loadSwagger('nonexistent.json'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('Configuration Tests', () {
    test('SwaggerSourceConfig.fromMap - full config', () {
      final map = {
        'source': './test.json',
        'include_paths': ['/api/v1'],
        'exclude_paths': ['/internal'],
        'include_tags': ['public'],
        'exclude_tags': ['private'],
        'output': 'filtered.json'
      };
      
      final config = SwaggerSourceConfig.fromMap(map);
      expect(config.source, equals('./test.json'));
      expect(config.includePaths, equals(['/api/v1']));
      expect(config.excludePaths, equals(['/internal']));
      expect(config.includeTags, equals(['public']));
      expect(config.excludeTags, equals(['private']));
      expect(config.output, equals('filtered.json'));
    });

    test('SwaggerSourceConfig.fromMap - minimal config', () {
      final map = {'source': './test.json'};
      final config = SwaggerSourceConfig.fromMap(map);
      
      expect(config.source, equals('./test.json'));
      expect(config.includePaths, isNull);
      expect(config.excludePaths, isNull);
      expect(config.includeTags, isNull);
      expect(config.excludeTags, isNull);
      expect(config.output, isNull);
    });

    test('SwaggerFilterConfig.fromYamlFile', () {
      // Create a temporary test config file
      final testConfigFile = File('test_config.yaml');
      testConfigFile.writeAsStringSync('''
swaggers:
  - source: ./test1.json
    include_paths: ["/api"]
    output: test1.filtered.json
  - source: ./test2.json
    include_tags: ["public"]
output_dir: ./filtered_test
''');

      try {
        final config = SwaggerFilterConfig.fromYamlFile('test_config.yaml');
        
        expect(config.swaggers, hasLength(2));
        expect(config.outputDir, equals('./filtered_test'));
        
        expect(config.swaggers[0].source, equals('./test1.json'));
        expect(config.swaggers[0].includePaths, equals(['/api']));
        expect(config.swaggers[0].output, equals('test1.filtered.json'));
        
        expect(config.swaggers[1].source, equals('./test2.json'));
        expect(config.swaggers[1].includeTags, equals(['public']));
      } finally {
        testConfigFile.deleteSync();
      }
    });
  });

  group('File Operations Tests', () {
    test('saveSwagger - creates valid JSON', () {
      final testSwagger = {
        'openapi': '3.0.0',
        'info': {'title': 'Test', 'version': '1.0.0'},
        'paths': {}
      };
      
      final testFile = File('test_output.json');
      
      try {
        saveSwagger(testSwagger, 'test_output.json');
        
        expect(testFile.existsSync(), isTrue);
        final content = testFile.readAsStringSync();
        final parsed = jsonDecode(content);
        
        expect(parsed['openapi'], equals('3.0.0'));
        expect(parsed['info']['title'], equals('Test'));
      } finally {
        if (testFile.existsSync()) {
          testFile.deleteSync();
        }
      }
    });
  });

     group('Integration Tests with Real Swagger', () {
     final testSwaggerPath = 'test/test_swagger.json';
     late Map<String, dynamic> swagger;

     setUpAll(() {
       swagger = loadSwagger(testSwaggerPath);
     });

    test('extract specific API - /workTeam/add', () {
      final filtered = filterPathsAdvanced(
        swagger['paths'] as Map<String, dynamic>,
        includePaths: ['/workTeam/add'],
      );
      
      expect(filtered.keys, contains('/workTeam/add'));
      expect(filtered['/workTeam/add'], isNotNull);
      expect(filtered['/workTeam/add'].keys, contains('post'));
      
      final newSwagger = buildFilteredSwagger(swagger, filtered);
      expect(newSwagger['paths'].keys, contains('/workTeam/add'));
      expect(newSwagger['paths']['/workTeam/add'].keys, contains('post'));
      
      // Check that the operation details are preserved
      final operation = newSwagger['paths']['/workTeam/add']['post'];
      expect(operation['summary'], isNotNull);
      expect(operation['summary'], contains('新增'));
    });

    test('filter by multiple paths', () {
      final filtered = filterPathsAdvanced(
        swagger['paths'] as Map<String, dynamic>,
        includePaths: ['/workTeam/add', '/user/login'],
      );
      
      expect(filtered.keys.length, greaterThanOrEqualTo(1));
      expect(filtered.keys, contains('/workTeam/add'));
    });

    test('exclude sensitive endpoints', () {
      final allPaths = swagger['paths'] as Map<String, dynamic>;
      
      // 找到实际存在的路径进行精确排除测试
      final pathsToExclude = allPaths.keys.where((path) => 
        path.contains('admin') || path.contains('internal') || path.contains('debug')
      ).toList();
      
      if (pathsToExclude.isNotEmpty) {
        final filtered = filterPathsAdvanced(
          allPaths,
          excludePaths: pathsToExclude,
        );
        
        // Should have fewer paths than original
        expect(filtered.keys.length, lessThan(allPaths.keys.length));
        
        // Should not contain any of the excluded paths
        for (final excludedPath in pathsToExclude) {
          expect(filtered.keys, isNot(contains(excludedPath)));
        }
      } else {
        // If no admin/internal/debug paths exist, just verify exclusion works
        final filtered = filterPathsAdvanced(
          allPaths,
          excludePaths: ['/nonexistent'],
        );
        expect(filtered.keys.length, equals(allPaths.keys.length));
      }
    });

    test('full workflow - filter and save', () {
      final filtered = filterPathsAdvanced(
        swagger['paths'] as Map<String, dynamic>,
        includePaths: ['/workTeam/add'],  // 使用精确的路径
      );
      
      final newSwagger = buildFilteredSwagger(swagger, filtered);
      final outputFile = File('test_filtered_output.json');
      
      try {
        saveSwagger(newSwagger, outputFile.path);
        
        expect(outputFile.existsSync(), isTrue);
        
        // Verify the saved file can be loaded back
        final reloaded = loadSwagger(outputFile.path);
        expect(reloaded['paths'], isNotEmpty);
        expect(reloaded['info'], equals(swagger['info']));
        
      } finally {
        if (outputFile.existsSync()) {
          outputFile.deleteSync();
        }
      }
    });
  });

  group('Error Handling Tests', () {
    test('filterPaths - handles empty paths', () {
      final result = filterPaths({}, includePaths: ['/test']);
      expect(result, isEmpty);
    });

    test('filterPaths - handles null parameters', () {
      final samplePaths = {
        '/test': {
          'get': {'tags': ['test']}
        }
      };
      
      final result = filterPaths(samplePaths);
      expect(result, equals(samplePaths));
    });

    test('buildFilteredSwagger - handles missing components', () {
      final minimalSwagger = {
        'openapi': '3.0.0',
        'info': {'title': 'Test', 'version': '1.0.0'},
        'paths': {'/test': {}}
      };
      
      final result = buildFilteredSwagger(minimalSwagger, {});
      expect(result['openapi'], equals('3.0.0'));
      expect(result['paths'], isEmpty);
    });

    test('buildFilteredSwagger - handles missing tags', () {
      final swaggerWithoutTags = {
        'openapi': '3.0.0',
        'info': {'title': 'Test', 'version': '1.0.0'},
        'paths': {
          '/test': {
            'get': {'summary': 'Test'}
          }
        }
      };
      
             final filteredPaths = {'/test': (swaggerWithoutTags['paths'] as Map<String, dynamic>)['/test']};
      final result = buildFilteredSwagger(swaggerWithoutTags, filteredPaths);
      
      expect(result['paths'], equals(filteredPaths));
      expect(result.containsKey('tags'), isFalse);
    });
  });
}
