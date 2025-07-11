/// Custom exceptions for swagger_filter package
library swagger_filter.exceptions;

/// Base exception for all swagger_filter related errors
abstract class SwaggerFilterException implements Exception {
  final String message;
  final dynamic cause;
  
  const SwaggerFilterException(this.message, [this.cause]);
  
  @override
  String toString() => 'SwaggerFilterException: $message';
}

/// Exception thrown when configuration is invalid
class ConfigurationException extends SwaggerFilterException {
  const ConfigurationException(String message, [dynamic cause]) 
      : super(message, cause);
  
  @override
  String toString() => 'ConfigurationException: $message';
}

/// Exception thrown when swagger file cannot be loaded
class SwaggerLoadException extends SwaggerFilterException {
  final String source;
  
  const SwaggerLoadException(this.source, String message, [dynamic cause]) 
      : super(message, cause);
  
  @override
  String toString() => 'SwaggerLoadException: Failed to load $source - $message';
}

/// Exception thrown when filtering operation fails
class FilterException extends SwaggerFilterException {
  const FilterException(String message, [dynamic cause]) 
      : super(message, cause);
  
  @override
  String toString() => 'FilterException: $message';
}

/// Exception thrown when output operation fails
class OutputException extends SwaggerFilterException {
  final String outputPath;
  
  const OutputException(this.outputPath, String message, [dynamic cause]) 
      : super(message, cause);
  
  @override
  String toString() => 'OutputException: Failed to write $outputPath - $message';
} 