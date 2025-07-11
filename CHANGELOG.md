# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Support for embedded configuration in build.yaml
- Enhanced error handling and logging

## [1.0.0] - 2024-12-19

### Added
- Initial release
- Support for filtering Swagger/OpenAPI 2.0 and 3.0 documents
- Command line interface with args support
- Build runner integration
- Support for local and remote swagger sources
- Include/exclude filtering by paths and tags
- Automatic cleanup of unused tags, components/schemas, and definitions
- Batch processing of multiple swagger sources
- Flexible output directory and file naming
- YAML configuration support

### Features
- **Multi-source support**: Process multiple swagger files in one configuration
- **Flexible filtering**: Include/exclude by paths, tags, or combinations
- **Auto cleanup**: Remove unused components to minimize output size
- **Dual interface**: Command line tool and build_runner integration
- **Network support**: Load swagger from HTTP/HTTPS URLs
- **Format agnostic**: Support JSON and YAML input/output

## [0.1.0] - 2024-12-19

### Added
- Basic swagger filtering functionality
- Simple path-based filtering
- JSON output support
