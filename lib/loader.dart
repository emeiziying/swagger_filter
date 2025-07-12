import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> loadSwaggerFlexible(String pathOrUrl) async {
  String content;
  if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
    final response = await http.get(Uri.parse(pathOrUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load swagger from $pathOrUrl');
    }
    content = response.body;
  } else {
    content = File(pathOrUrl).readAsStringSync();
  }
  if (pathOrUrl.endsWith('.yaml') || pathOrUrl.endsWith('.yml')) {
    return Map<String, dynamic>.from(loadYaml(content));
  } else {
    // 尝试json解析，失败则尝试yaml
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return Map<String, dynamic>.from(loadYaml(content));
    }
  }
}
