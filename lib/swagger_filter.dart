import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

/// Loads a swagger/OpenAPI document from a file path.
///
/// Supports both JSON and YAML formats. The format is auto-detected based on
/// file extension (.yaml, .yml for YAML, everything else treated as JSON).
///
/// Example:
/// ```dart
/// final swagger = loadSwagger('api.json');
/// print(swagger['info']['title']);
/// ```
///
/// Throws [FileSystemException] if the file doesn't exist.
/// Throws [FormatException] if the file content is invalid.
Map<String, dynamic> loadSwagger(String path) {
  final content = File(path).readAsStringSync();
  if (path.endsWith('.yaml') || path.endsWith('.yml')) {
    return Map<String, dynamic>.from(loadYaml(content));
  } else {
    return jsonDecode(content) as Map<String, dynamic>;
  }
}

/// Filters swagger paths based on include criteria.
///
/// This is a simple filtering function that supports basic include-only logic.
/// For more advanced filtering with exclude support, use [filterPathsAdvanced].
///
/// Parameters:
/// - [paths]: The paths section from a swagger document
/// - [includePaths]: List of path patterns to include (exact matching only)
/// - [includeTags]: List of tags to include
///
/// Returns a new paths map containing only the filtered paths.
///
/// Example:
/// ```dart
/// final filtered = filterPaths(
///   swagger['paths'],
///   includePaths: ['/api/v1'],
///   includeTags: ['public'],
/// );
/// ```
Map<String, dynamic> filterPaths(
  Map<String, dynamic> paths, {
  List<String>? includePaths,
  List<String>? includeTags,
}) {
  final result = <String, dynamic>{};
  paths.forEach((path, methods) {
    if (includePaths != null && !includePaths.any((p) => path == p)) {
      return;
    }
    // 进一步按 tag 过滤
    final filteredMethods = <String, dynamic>{};
    (methods as Map).forEach((method, op) {
      if (includeTags == null ||
          (op['tags'] as List?)?.any((tag) => includeTags.contains(tag)) ==
              true) {
        filteredMethods[method] = op;
      }
    });
    if (filteredMethods.isNotEmpty) {
      result[path] = filteredMethods;
    }
  });
  return result;
}

/// Advanced filtering function with include/exclude support and priority logic.
///
/// This function provides comprehensive filtering capabilities:
/// - Include patterns take priority over exclude patterns
/// - Both path-based and tag-based filtering
/// - Exact matching for paths
/// - Exact matching for tags
///
/// Priority Logic:
/// 1. If [includePaths] is specified, only check include conditions for paths
/// 2. If [includeTags] is specified, only check include conditions for tags
/// 3. Exclude conditions are only applied when corresponding include conditions are not specified
///
/// Parameters:
/// - [paths]: The paths section from a swagger document
/// - [includePaths]: List of path patterns to include (takes priority)
/// - [excludePaths]: List of path patterns to exclude (ignored if includePaths is set)
/// - [includeTags]: List of tags to include (takes priority)
/// - [excludeTags]: List of tags to exclude (ignored if includeTags is set)
///
/// Example:
/// ```dart
/// // Include only specific paths, exclude sensitive tags
/// final filtered = filterPathsAdvanced(
///   swagger['paths'],
///   includePaths: ['/api/v1', '/public'],
///   excludeTags: ['internal', 'admin'],
/// );
///
/// // Include takes priority - this will include /admin paths despite exclude
/// final filtered2 = filterPathsAdvanced(
///   swagger['paths'],
///   includePaths: ['/admin'],
///   excludePaths: ['/admin'], // This will be ignored
/// );
/// ```
Map<String, dynamic> filterPathsAdvanced(
  Map<String, dynamic> paths, {
  List<String>? includePaths,
  List<String>? excludePaths,
  List<String>? includeTags,
  List<String>? excludeTags,
}) {
  final result = <String, dynamic>{};
  paths.forEach((path, methods) {
    // includePaths优先 - 如果有includePaths，只检查include条件
    if (includePaths != null) {
      if (!includePaths.any((p) => path == p)) {
        return;
      }
    } else if (excludePaths != null && excludePaths.any((p) => path == p)) {
      // 只有在没有includePaths时才检查excludePaths
      return;
    }

    final filteredMethods = <String, dynamic>{};
    (methods as Map).forEach((method, op) {
      // includeTags优先 - 如果有includeTags，只检查include条件
      if (includeTags != null) {
        if (!((op['tags'] as List?)?.any((tag) => includeTags.contains(tag)) ==
            true)) {
          return;
        }
      } else if (excludeTags != null &&
          ((op['tags'] as List?)?.any((tag) => excludeTags.contains(tag)) ==
              true)) {
        // 只有在没有includeTags时才检查excludeTags
        return;
      }
      filteredMethods[method] = op;
    });
    if (filteredMethods.isNotEmpty) {
      result[path] = filteredMethods;
    }
  });
  return result;
}

/// Builds a complete filtered swagger document with automatic cleanup.
///
/// This function takes the original swagger document and filtered paths,
/// then creates a new swagger document with:
/// - Only the filtered paths
/// - Only tags that are actually used in the filtered paths
/// - Only schemas/definitions that are referenced (with recursive dependency resolution)
///
/// The function automatically detects OpenAPI version:
/// - OpenAPI 3.0+: Cleans up components/schemas
/// - OpenAPI 2.0: Cleans up definitions
///
/// Parameters:
/// - [swagger]: The complete original swagger document
/// - [filteredPaths]: The filtered paths (typically from [filterPaths] or [filterPathsAdvanced])
///
/// Returns a new swagger document with unused elements removed.
///
/// Example:
/// ```dart
/// final swagger = loadSwagger('api.json');
/// final filtered = filterPathsAdvanced(swagger['paths'], includePaths: ['/users']);
/// final cleanSwagger = buildFilteredSwagger(swagger, filtered);
///
/// // cleanSwagger now contains only:
/// // - paths starting with '/users'
/// // - tags used by those paths
/// // - schemas referenced by those paths (recursively)
/// ```
Map<String, dynamic> buildFilteredSwagger(
  Map<String, dynamic> swagger,
  Map<String, dynamic> filteredPaths,
) {
  // 收集使用到的tags
  final usedTags = <String>{};
  filteredPaths.forEach((path, methods) {
    (methods as Map).forEach((method, operation) {
      final tags = operation['tags'] as List?;
      if (tags != null) {
        usedTags.addAll(tags.cast<String>());
      }
    });
  });

  // 收集使用到的schemas/definitions
  final usedSchemas = <String>{};
  void findUsedSchemas(dynamic obj) {
    if (obj is Map) {
      obj.forEach((key, value) {
        if (key == '\$ref' && value is String) {
          final ref = value;
          // OpenAPI 3.0: "#/components/schemas/SchemaName"
          if (ref.startsWith('#/components/schemas/')) {
            usedSchemas.add(ref.split('/').last);
          }
          // OpenAPI 2.0: "#/definitions/SchemaName"
          else if (ref.startsWith('#/definitions/')) {
            usedSchemas.add(ref.split('/').last);
          }
        } else {
          findUsedSchemas(value);
        }
      });
    } else if (obj is List) {
      for (var item in obj) {
        findUsedSchemas(item);
      }
    }
  }

  findUsedSchemas(filteredPaths);

  // 构建新swagger
  final result = Map<String, dynamic>.from(swagger);
  result['paths'] = filteredPaths;

  // 过滤tags
  if (swagger['tags'] != null) {
    final filteredTags = (swagger['tags'] as List)
        .where((tag) => usedTags.contains(tag['name']))
        .toList();
    result['tags'] = filteredTags;
  }

  // 过滤OpenAPI 3.0 components/schemas
  if (swagger['components'] != null) {
    final components = Map<String, dynamic>.from(swagger['components']);
    if (components['schemas'] != null) {
      final schemas = Map<String, dynamic>.from(components['schemas']);
      final filteredSchemas = <String, dynamic>{};

      // 递归收集依赖的schema
      void collectDependentSchemas() {
        final currentSchemas = List<String>.from(usedSchemas);
        final newSchemas = <String>{};
        for (final schemaName in currentSchemas) {
          if (schemas.containsKey(schemaName) &&
              !filteredSchemas.containsKey(schemaName)) {
            filteredSchemas[schemaName] = schemas[schemaName];
            findUsedSchemas(schemas[schemaName]);
            newSchemas
                .addAll(usedSchemas.difference(filteredSchemas.keys.toSet()));
          }
        }
        if (newSchemas.isNotEmpty) {
          collectDependentSchemas();
        }
      }

      collectDependentSchemas();
      components['schemas'] = filteredSchemas;
      result['components'] = components;
    }
  }

  // 过滤OpenAPI 2.0 definitions
  if (swagger['definitions'] != null) {
    final definitions = Map<String, dynamic>.from(swagger['definitions']);
    final filteredDefinitions = <String, dynamic>{};

    // 递归收集依赖的definition
    void collectDependentDefinitions() {
      final currentDefinitions = List<String>.from(usedSchemas);
      final newDefinitions = <String>{};
      for (final definitionName in currentDefinitions) {
        if (definitions.containsKey(definitionName) &&
            !filteredDefinitions.containsKey(definitionName)) {
          filteredDefinitions[definitionName] = definitions[definitionName];
          findUsedSchemas(definitions[definitionName]);
          newDefinitions
              .addAll(usedSchemas.difference(filteredDefinitions.keys.toSet()));
        }
      }
      if (newDefinitions.isNotEmpty) {
        collectDependentDefinitions();
      }
    }

    collectDependentDefinitions();
    result['definitions'] = filteredDefinitions;
  }

  return result;
}

/// Saves a swagger document to a JSON file with pretty formatting.
///
/// The output is formatted with 2-space indentation for readability.
///
/// Parameters:
/// - [swagger]: The swagger document to save
/// - [path]: The file path where to save the document
///
/// Example:
/// ```dart
/// final swagger = {'openapi': '3.0.0', 'info': {'title': 'API'}};
/// saveSwagger(swagger, 'output/api.json');
/// ```
///
/// Throws [FileSystemException] if the file cannot be written.
void saveSwagger(Map<String, dynamic> swagger, String path) {
  File(path).writeAsStringSync(JsonEncoder.withIndent('  ').convert(swagger));
}
