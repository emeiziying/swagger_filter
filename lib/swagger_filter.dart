import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

/// 读取 swagger 文件（支持 JSON/YAML）
Map<String, dynamic> loadSwagger(String path) {
  final content = File(path).readAsStringSync();
  if (path.endsWith('.yaml') || path.endsWith('.yml')) {
    return Map<String, dynamic>.from(loadYaml(content));
  } else {
    return jsonDecode(content) as Map<String, dynamic>;
  }
}

/// 过滤 paths
Map<String, dynamic> filterPaths(
  Map<String, dynamic> paths, {
  List<String>? includePaths,
  List<String>? includeTags,
}) {
  final result = <String, dynamic>{};
  paths.forEach((path, methods) {
    if (includePaths != null && !includePaths.any((p) => path.contains(p))) {
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

/// 高级过滤 paths，支持include/exclude，include优先
Map<String, dynamic> filterPathsAdvanced(
  Map<String, dynamic> paths, {
  List<String>? includePaths,
  List<String>? excludePaths,
  List<String>? includeTags,
  List<String>? excludeTags,
}) {
  final result = <String, dynamic>{};
  paths.forEach((path, methods) {
    // includePaths优先
    if (includePaths != null && !includePaths.any((p) => path.contains(p))) {
      return;
    }
    if (excludePaths != null && excludePaths.any((p) => path.contains(p))) {
      return;
    }
    final filteredMethods = <String, dynamic>{};
    (methods as Map).forEach((method, op) {
      // includeTags优先
      if (includeTags != null &&
          !((op['tags'] as List?)?.any((tag) => includeTags.contains(tag)) ==
              true)) {
        return;
      }
      if (excludeTags != null &&
          ((op['tags'] as List?)?.any((tag) => excludeTags.contains(tag)) ==
              true)) {
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

/// 组装新 swagger 文档
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
        final newSchemas = <String>{};
        for (final schemaName in usedSchemas) {
          if (schemas.containsKey(schemaName) && !filteredSchemas.containsKey(schemaName)) {
            filteredSchemas[schemaName] = schemas[schemaName];
            findUsedSchemas(schemas[schemaName]);
            newSchemas.addAll(usedSchemas.difference(filteredSchemas.keys.toSet()));
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
      final newDefinitions = <String>{};
      for (final definitionName in usedSchemas) {
        if (definitions.containsKey(definitionName) && !filteredDefinitions.containsKey(definitionName)) {
          filteredDefinitions[definitionName] = definitions[definitionName];
          findUsedSchemas(definitions[definitionName]);
          newDefinitions.addAll(usedSchemas.difference(filteredDefinitions.keys.toSet()));
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

/// 保存为 JSON
void saveSwagger(Map<String, dynamic> swagger, String path) {
  File(path).writeAsStringSync(JsonEncoder.withIndent('  ').convert(swagger));
}
