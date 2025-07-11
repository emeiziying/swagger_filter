# build.yaml 配置故障排查指南

## 🚨 常见配置错误

### 1. Builder引用格式错误

**❌ 错误配置:**
```yaml
targets:
  $default:
    builders:
      swagger_filter:  # 缺少包名前缀
        # ...
```

**✅ 正确配置:**
```yaml
targets:
  $default:
    builders:
      swagger_filter|swagger_filter:  # package_name|builder_name
        # ...
```

### 2. 配置层级错误

**❌ 错误配置:**
```yaml
targets:
  $default:
    builders:
      swagger_filter|swagger_filter:
        output_dir: "lib/swaggers"  # 直接在builder下配置
        swaggers: [...]
```

**✅ 正确配置:**
```yaml
targets:
  $default:
    builders:
      swagger_filter|swagger_filter:
        options:  # 必须在options下
          output_dir: "lib/swaggers"
          swaggers: [...]
```

### 3. 输出目录问题

**⚠️ 不推荐:**
```yaml
output_dir: "lib/swaggers"  # 会被Git追踪，可能导致冲突
```

**✅ 推荐:**
```yaml
output_dir: "generated/swaggers"  # 独立的生成目录
# 记得在 .gitignore 中添加 generated/
```

## 📋 完整的正确配置示例

### 基础配置
```yaml
targets:
  $default:
    sources:
      - lib/**
      - $package$
    builders:
      swagger_filter|swagger_filter:
        enabled: true
        options:
          output_dir: "generated/swaggers"
          swaggers:
            - source: "https://api.example.com/swagger.json"
              include_paths: ["/api/v1"]
              output: "example_api.json"
```

### 高级配置
```yaml
targets:
  $default:
    sources:
      - lib/**
      - swaggers/**
      - $package$
    builders:
      swagger_filter|swagger_filter:
        enabled: true
        # 可选：仅在特定条件下运行
        generate_for: 
          - lib/**.dart
        options:
          output_dir: "generated/swaggers"
          swaggers:
            # 本地文件
            - source: "swaggers/main_api.json"
              include_tags: ["public", "user"]
              exclude_paths: ["/internal", "/debug"]
              output: "main_api_filtered.json"
            
            # 远程URL
            - source: "https://petstore.swagger.io/v2/swagger.json"
              include_paths: ["/pet", "/store"]
              exclude_tags: ["admin"]
              output: "petstore_filtered.json"
            
            # 最小配置（包含所有API）
            - source: "https://api.github.com/swagger.json"
              output: "github_api.json"

# 可选：自定义builder设置
builders:
  swagger_filter:
    import: "package:swagger_filter/builder.dart"
    builder_factories: ["swaggerFilterBuilder"]
    build_extensions: {".dart": [".swagger_filtered"]}
    auto_apply: root_package
    build_to: source
```

## 🔧 运行和调试

### 1. 运行Build Runner
```bash
# 清理并构建
flutter packages pub run build_runner clean
flutter packages pub run build_runner build

# 监听模式（开发时使用）
flutter packages pub run build_runner watch

# 详细输出（调试时使用）
flutter packages pub run build_runner build --verbose

# 删除冲突文件
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### 2. 常见错误消息

**错误:** `No builder named 'swagger_filter' was found`
```bash
解决方案:
1. 确保已添加依赖: flutter pub add swagger_filter
2. 检查builder引用格式: swagger_filter|swagger_filter
3. 运行: flutter pub get
```

**错误:** `Configuration error: No swaggers configured`
```yaml
解决方案: 确保配置在正确位置
targets:
  $default:
    builders:
      swagger_filter|swagger_filter:
        options:  # 必须有这一层
          swaggers: [...]
```

**错误:** `Invalid swagger configuration format`
```yaml
解决方案: 检查YAML语法
swaggers:
  - source: "https://..."  # 注意缩进
    include_paths: ["/api"]  # 使用列表格式
```

### 3. 调试技巧

**启用详细日志:**
```yaml
targets:
  $default:
    builders:
      swagger_filter|swagger_filter:
        options:
          # 添加调试选项（如果支持）
          verbose: true
          swaggers: [...]
```

**检查生成的文件:**
```bash
# 查看输出目录
ls -la generated/swaggers/

# 验证JSON格式
cat generated/swaggers/your_file.json | jq '.'
```

## 📁 项目文件结构建议

```
your_flutter_project/
├── lib/
│   ├── main.dart
│   └── ...
├── swaggers/           # 可选：本地swagger文件
│   ├── api_v1.json
│   └── api_v2.yaml
├── generated/          # 构建输出（添加到.gitignore）
│   └── swaggers/
│       ├── api_v1_filtered.json
│       └── api_v2_filtered.json
├── build.yaml          # 构建配置
├── pubspec.yaml
└── .gitignore          # 包含 generated/
```

## 🎯 .gitignore 配置

确保在 `.gitignore` 中添加：
```gitignore
# Generated files
generated/
*.swagger_filtered

# Build outputs
build/
.dart_tool/
```

## 🚀 性能优化

### 1. 条件构建
```yaml
targets:
  $default:
    builders:
      swagger_filter|swagger_filter:
        # 仅在特定文件变化时运行
        generate_for:
          - swaggers/**
          - build.yaml
```

### 2. 缓存优化
```bash
# 利用build_runner缓存
flutter packages pub run build_runner build --use-tracking-cache
```

## 📞 获取帮助

如果遇到问题：

1. **检查依赖版本**: 确保使用最新版本的swagger_filter
2. **查看日志**: 使用 `--verbose` 标志获取详细信息
3. **验证配置**: 使用YAML验证器检查语法
4. **清理重建**: 尝试 `clean` 然后重新构建
5. **参考示例**: 查看 `example_configs/` 目录中的配置示例

---

*最后更新: 2024-12-19* 