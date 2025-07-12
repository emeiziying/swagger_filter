# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2024-12-19

### 🔧 Bug Fixes
- Fixed CI/CD pipeline failures due to missing swagger configuration
- Resolved Dart analyzer issues (unused methods, constructor optimizations)
- Fixed code formatting compliance with dart format
- Enhanced builder to gracefully handle missing configurations instead of throwing exceptions

### 🚀 Improvements
- Added automatic code formatting with Git pre-commit hooks
- Improved error handling and logging messages
- Enhanced builder stability for CI/CD environments
- Better configuration validation and fallback handling

### 🛠️ Developer Experience
- Automatic code formatting on commit via pre-commit hooks
- Better error messages when configuration is missing
- Cleaner codebase with resolved lint issues
- Improved CI/CD reliability

### 📝 Code Quality
- Removed unused private methods
- Optimized constructors with super parameters
- Fixed string interpolation formatting
- Enhanced null safety handling

## [1.0.1] - 2024-12-19

### 🎯 精准路径匹配改进
- **BREAKING CHANGE**: 将路径匹配从子字符串匹配改为精确匹配
- 只支持精确匹配 (`/api/v1` 仅匹配 `/api/v1`，不匹配子路径)
- 避免误匹配 (`/api/v1` 不会匹配 `/api/v1/users` 或 `/api/v1-legacy`)
- 需要明确指定每个要包含的路径
- 新增全面的精确匹配测试用例

### 🔧 构建配置优化
- 修改 `build_extensions` 从 `.dart` 改为 `.yaml`
- 输出文件扩展名改为 `.swagger_filtered.json`
- 避免为每个 Dart 文件生成无用的输出文件

### ✅ JSON Schema 验证支持
- 新增 `schema/swagger_filter_schema.json` 配置文件 Schema
- 支持 IDE 自动补全和实时验证
- 路径格式验证（必须以 `/` 开头）
- 字段类型检查和约束验证
- 提供丰富的文档和示例
- 新增 Schema 验证测试用例

### 📝 文档更新
- 添加精准路径匹配说明和示例
- 新增 IDE 支持和配置验证章节
- 更新 API 文档中的匹配算法描述
- 添加 Schema 使用指南

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
