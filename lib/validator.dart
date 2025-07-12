import 'dart:io';
import 'dart:core';

import 'config.dart';

/// Validation result containing errors and warnings
class ValidationResult {
  final List<String> errors;
  final List<String> warnings;
  final bool isValid;

  ValidationResult({
    required this.errors,
    required this.warnings,
  }) : isValid = errors.isEmpty;

  ValidationResult.success()
      : errors = const [],
        warnings = const [],
        isValid = true;

  ValidationResult.failure(this.errors, [List<String>? warnings])
      : warnings = warnings ?? const [],
        isValid = errors.isEmpty;

  /// Combine multiple validation results
  ValidationResult operator +(ValidationResult other) {
    return ValidationResult(
      errors: [...errors, ...other.errors],
      warnings: [...warnings, ...other.warnings],
    );
  }
}

/// Comprehensive validator for swagger filter configurations and security
class SwaggerFilterValidator {
  static const int _maxFileSizeBytes = 100 * 1024 * 1024; // 100MB
  static const int _maxUrlLength = 2048;

  /// Validate a complete swagger filter configuration
  static ValidationResult validateConfig(SwaggerFilterConfig config) {
    var result = ValidationResult.success();

    // Validate basic structure
    if (config.swaggers.isEmpty) {
      return ValidationResult.failure(
          ['Configuration must contain at least one swagger source']);
    }

    // Validate each swagger source
    for (int i = 0; i < config.swaggers.length; i++) {
      final sourceResult = validateSwaggerSource(config.swaggers[i], i);
      result = result + sourceResult;
    }

    // Validate output directory
    if (config.outputDir != null) {
      final outputResult = validateOutputDirectory(config.outputDir!);
      result = result + outputResult;
    }

    return result;
  }

  /// Validate a single swagger source configuration
  static ValidationResult validateSwaggerSource(
      SwaggerSourceConfig config, int index) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate source
    final sourceResult = validateSource(config.source);
    errors.addAll(sourceResult.errors.map((e) => 'Source $index: $e'));
    warnings.addAll(sourceResult.warnings.map((w) => 'Source $index: $w'));

    // Validate filter criteria
    final hasIncludePaths = config.includePaths?.isNotEmpty == true;
    final hasExcludePaths = config.excludePaths?.isNotEmpty == true;
    final hasIncludeTags = config.includeTags?.isNotEmpty == true;
    final hasExcludeTags = config.excludeTags?.isNotEmpty == true;

    if (!hasIncludePaths &&
        !hasExcludePaths &&
        !hasIncludeTags &&
        !hasExcludeTags) {
      warnings.add(
          'Source $index: No filtering criteria specified, all paths will be included');
    }

    // Validate output filename
    if (config.output != null) {
      final outputResult = validateOutputFilename(config.output!);
      errors.addAll(outputResult.errors.map((e) => 'Source $index output: $e'));
      warnings
          .addAll(outputResult.warnings.map((w) => 'Source $index output: $w'));
    }

    // Validate path patterns
    if (config.includePaths != null) {
      for (final path in config.includePaths!) {
        if (path.isEmpty) {
          errors.add('Source $index: Empty include path pattern');
        }
        if (path.contains('..')) {
          warnings.add(
              'Source $index: Path pattern "$path" contains "..", this might be overly broad');
        }
      }
    }

    if (config.excludePaths != null) {
      for (final path in config.excludePaths!) {
        if (path.isEmpty) {
          errors.add('Source $index: Empty exclude path pattern');
        }
      }
    }

    return ValidationResult(errors: errors, warnings: warnings);
  }

  /// Validate a source URL or file path
  static ValidationResult validateSource(String source) {
    if (source.isEmpty) {
      return ValidationResult.failure(['Source cannot be empty']);
    }

    // Check if it's a URL
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return _validateUrl(source);
    } else {
      return _validateFilePath(source);
    }
  }

  static ValidationResult _validateUrl(String url) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check URL length
    if (url.length > _maxUrlLength) {
      errors.add('URL too long (${url.length} > $_maxUrlLength characters)');
    }

    // Parse URL
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      return ValidationResult.failure(['Invalid URL format: $e']);
    }

    // Security checks
    if (uri.scheme == 'http') {
      warnings.add(
          'Using HTTP instead of HTTPS - data will be transmitted unencrypted');
    }

    // Check for localhost/private IPs (potential SSRF)
    if (uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host.startsWith('192.168.') ||
        uri.host.startsWith('10.') ||
        uri.host.startsWith('172.16.') ||
        uri.host.startsWith('172.17.') ||
        uri.host.startsWith('172.18.') ||
        uri.host.startsWith('172.19.') ||
        uri.host.startsWith('172.2') ||
        uri.host.startsWith('172.30.') ||
        uri.host.startsWith('172.31.')) {
      warnings
          .add('URL points to private/local network - ensure this is intended');
    }

    return ValidationResult(errors: errors, warnings: warnings);
  }

  static ValidationResult _validateFilePath(String path) {
    final errors = <String>[];
    final warnings = <String>[];

    // Security: Check for path traversal
    if (path.contains('..')) {
      errors
          .add('Path contains ".." which could lead to path traversal attacks');
    }

    // Check if file exists
    final file = File(path);
    if (!file.existsSync()) {
      errors.add('File does not exist: $path');
      return ValidationResult(errors: errors, warnings: warnings);
    }

    // Check file size
    final fileSize = file.lengthSync();
    if (fileSize > _maxFileSizeBytes) {
      final sizeMB = (fileSize / 1024 / 1024).toStringAsFixed(1);
      warnings.add('File is very large (${sizeMB}MB) - processing may be slow');
    }

    // Check file extension
    if (!path.toLowerCase().endsWith('.json') &&
        !path.toLowerCase().endsWith('.yaml') &&
        !path.toLowerCase().endsWith('.yml')) {
      warnings.add(
          'File extension suggests it may not be a swagger/OpenAPI document');
    }

    return ValidationResult(errors: errors, warnings: warnings);
  }

  /// Validate output directory
  static ValidationResult validateOutputDirectory(String outputDir) {
    final errors = <String>[];
    final warnings = <String>[];

    // Security: Check for path traversal
    if (outputDir.contains('..')) {
      errors.add(
          'Output directory contains ".." which could lead to path traversal');
    }

    // Check if directory can be created
    try {
      final dir = Directory(outputDir);
      if (!dir.existsSync()) {
        // Try to create it
        dir.createSync(recursive: true);
        warnings.add('Created output directory: $outputDir');
      } else {
        // Check if writable
        final testFile = File('$outputDir/.write_test');
        testFile.writeAsStringSync('test');
        testFile.deleteSync();
      }
    } catch (e) {
      errors.add('Cannot write to output directory: $e');
    }

    return ValidationResult(errors: errors, warnings: warnings);
  }

  /// Validate output filename
  static ValidationResult validateOutputFilename(String filename) {
    final errors = <String>[];
    final warnings = <String>[];

    if (filename.isEmpty) {
      return ValidationResult.failure(['Output filename cannot be empty']);
    }

    // Check for invalid characters
    final invalidChars = ['<', '>', ':', '"', '|', '?', '*'];
    for (final char in invalidChars) {
      if (filename.contains(char)) {
        errors.add('Filename contains invalid character: $char');
      }
    }

    // Security: Check for path traversal in filename
    if (filename.contains('/') || filename.contains('\\')) {
      errors.add('Filename should not contain path separators');
    }

    return ValidationResult(errors: errors, warnings: warnings);
  }

  /// Validate that a swagger document is structurally correct
  static ValidationResult validateSwaggerDocument(
      Map<String, dynamic> swagger) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check required fields
    if (!swagger.containsKey('info')) {
      errors.add('Swagger document missing required "info" section');
    }

    if (!swagger.containsKey('paths')) {
      errors.add('Swagger document missing required "paths" section');
    }

    // Check version
    if (swagger.containsKey('openapi')) {
      final version = swagger['openapi'] as String?;
      if (version == null) {
        errors.add('OpenAPI version must be a string');
      } else if (!version.startsWith('3.')) {
        warnings.add(
            'OpenAPI version $version - only 3.x has been thoroughly tested');
      }
    } else if (swagger.containsKey('swagger')) {
      final version = swagger['swagger'] as String?;
      if (version == null) {
        errors.add('Swagger version must be a string');
      } else if (version != '2.0') {
        warnings.add(
            'Swagger version $version - only 2.0 has been thoroughly tested');
      }
    } else {
      errors.add('Document must specify either "openapi" or "swagger" version');
    }

    return ValidationResult(errors: errors, warnings: warnings);
  }
}
