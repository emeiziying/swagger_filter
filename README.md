# Swagger Filter

## 功能
- 支持本地/网络swagger批量过滤
- 每个swagger可单独配置包含/排除API
- 输出过滤后的swagger到指定目录
- 支持OpenAPI 2.0/3.0
- 支持build_runner自动生成
- 支持命令行独立运行

## ⚙️ 配置方式

swagger_filter 支持两种配置方式：

### 1. 独立配置文件（推荐）

创建 `swagger_filter.yaml` 配置文件：

```yaml
# swagger_filter.yaml
swaggers:
  - source: "https://api.example.com/swagger.json"
    output: "user_api.json"
    include_paths:
      - "/api/v1/users"
      - "/api/v1/auth"
    exclude_tags: ["admin", "internal"]

output_dir: "./filtered"
```

配置 `build.yaml`：

```yaml
# build.yaml - 仅使用 swagger_filter.yaml 配置文件
targets:
  $default:
    builders:
      swagger_filter: {}
```

### 2. 嵌入式配置（向后兼容）

也可以直接在 `build.yaml` 中配置：

```yaml
targets:
  $default:
    builders:
      swagger_filter:
        options:
          swaggers:  # 必需字段
            - source: "https://api.example.com/swagger.json"
              output: "user_api.json"
              include_paths: ["/api/v1/users", "/api/v1/auth"]
              exclude_tags: ["admin", "internal"]
          output_dir: "./filtered"
```

### 配置优先级

- ✅ **优先使用**：`swagger_filter.yaml` 独立配置文件
- 🔄 **向后兼容**：`build.yaml` 中的 options 配置

**建议使用独立配置文件的原因**：
- 🎯 **更清晰**：配置与构建逻辑分离
- 📝 **IDE支持**：支持 JSON Schema 验证和自动补全
- 🔄 **易维护**：配置变更不影响构建设置
- 📦 **可复用**：配置文件可以在不同项目间共享

## 使用方法

### 1. 命令行运行
```sh
# 使用默认配置文件 swagger_filter.yaml
dart run swagger_filter

# 指定配置文件
dart run swagger_filter --config my_config.yaml
dart run swagger_filter -c my_config.yaml

# 查看帮助
dart run swagger_filter --help
dart run swagger_filter -h
```

### 2. build_runner自动生成
```sh
dart run build_runner build
```
- 生成的swagger文件在`filtered/`目录（可在配置中自定义）

### 3. 配置说明
- `source`：swagger本地路径或网络地址
- `include_paths`/`exclude_paths`：按路径包含/排除API
- `include_tags`/`exclude_tags`：按tag包含/排除API
- `output`：输出文件名（可选，默认与原文件名一致）
- `output_dir`：全局输出目录

### 4. 支持OpenAPI 2.0/3.0
自动识别swagger版本，无需手动区分
- 自动清理无用的tags
- 自动清理无用的components/schemas (3.0)
- 自动清理无用的definitions (2.0)

### 5. 示例输出
```
Loading configuration from: swagger_filter.yaml
Processing 1 swagger source(s)...
[1/1] Processing: ./swaggers/smartOpsPro.json
  ✓ Generated: filtered/smartOpsPro.filtered.json
  ✓ Paths: 1, Tags: 1

✅ Swagger filtering completed!
```

## 🎯 精准路径匹配

swagger_filter 使用**精准匹配**机制，确保路径过滤的准确性：

### 匹配规则

```yaml
include_paths: ["/api/v1"]
```

**✅ 会匹配：**
- `/api/v1` (精确匹配)

**❌ 不会匹配：**
- `/api/v1/users` (子路径不匹配)
- `/api/v1/orders/123` (子路径不匹配)
- `/api/v1-legacy` (避免误匹配)
- `/api/v1.0` (避免误匹配)
- `/apiV1` (避免误匹配)

### 实际示例

假设有以下 API 路径：

```json
{
  "paths": {
    "/users": {...},
    "/users/profile": {...},
    "/user": {...},
    "/users-admin": {...},
    "/api/users": {...}
  }
}
```

使用不同的 `include_paths` 配置：

```yaml
# 示例 1: 只要用户列表API
include_paths: ["/users"]
# ✅ 匹配: /users
# ❌ 不匹配: /users/profile, /user, /users-admin, /api/users

# 示例 2: 包含多个精确路径
include_paths: ["/users", "/users/profile", "/user"]  
# ✅ 匹配: /users, /users/profile, /user
# ❌ 不匹配: /users-admin, /api/users

# 示例 3: API版本控制
include_paths: ["/api/v1", "/api/v1/users", "/api/v1/orders"]
# ✅ 匹配: /api/v1, /api/v1/users, /api/v1/orders
# ❌ 不匹配: /api/v2, /api-docs, /api/v1/products
```

## 🔧 IDE 支持和配置验证

swagger_filter 提供了 JSON Schema 来支持 IDE 自动补全和配置验证。

### 启用 IDE 支持

在你的 `swagger_filter.yaml` 文件顶部添加：

```yaml
# yaml-language-server: $schema=./schema/swagger_filter_schema.json

output_dir: "./filtered"
swaggers:
  - source: "./api.json"
    include_paths: ["/users"]  # IDE 会提供自动补全
```

### IDE 功能

启用 schema 后，支持的 IDE（VS Code、IntelliJ 等）将提供：

- ✅ **自动补全**：字段名称和值的智能提示
- ✅ **实时验证**：拼写错误即时高亮
- ✅ **悬停文档**：字段说明和示例
- ✅ **结构验证**：确保配置格式正确

### Schema 验证规则

- `source`: 必须提供，可以是文件路径或 URL
- `include_paths`/`exclude_paths`: 必须以 `/` 开头
- 至少需要提供一个过滤条件（paths 或 tags）
- 数组中的项目必须唯一

### 示例错误提示

```yaml
swaggers:
  - source: "./api.json"
    include_paths: 
      - "users"  # ❌ IDE 会提示：路径必须以 / 开头
```

## ⚡ 性能优化

### build_runner 执行优化

swagger_filter 经过优化，**只处理特定的配置文件**，避免遍历所有项目文件：

- ✅ **精确文件匹配**：只处理 `swagger_filter.yaml`
- ✅ **避免无关文件**：不会扫描所有 `.dart` 或 `.yaml` 文件
- ✅ **快速启动**：减少不必要的文件系统遍历

### 性能对比

| 配置方式 | 扫描文件 | 性能 | 说明 |
|----------|----------|------|------|
| **优化前** | 所有 `.dart` 文件 | ❌ 慢 | 需要检查每个 Dart 文件 |
| **优化后** | 仅 `swagger_filter.yaml` | ✅ 快 | 精确匹配配置文件 |

### 配置要求

为了获得最佳性能，请确保：

1. **使用标准配置文件名**：
   ```
   swagger_filter.yaml  # ← 推荐文件名
   ```

2. **避免分散配置**：
   ```yaml
   # ❌ 不推荐：多个配置文件
   api1_swagger.yaml
   api2_swagger.yaml
   
   # ✅ 推荐：单一配置文件
   swagger_filter.yaml
   ```

3. **正确的项目结构**：
   ```
   your_project/
   ├── swagger_filter.yaml      # ← 配置文件
   ├── build.yaml               # ← build_runner 配置
   └── lib/
       └── main.dart
   ```

## 🔄 与 swagger_dart_code_generator 集成

swagger_filter 通过 `runs_before` 配置自动在 `swagger_dart_code_generator` 之前执行，形成完整的API处理工作流。

### 配置示例

```yaml
# build.yaml
targets:
  $default:
    builders:
      swagger_filter:
        options:
          swaggers:
            - source: "https://api.example.com/swagger.json"
              output: "user_api.json"
              include_paths: ["/api/v1/users", "/api/v1/auth"]
          output_dir: "./swagger_filtered"
      
      swagger_dart_code_generator|swagger:
        options:
          input_folder: "./swagger_filtered"
          output_folder: "./lib/api"
```

```yaml
# swagger_filter.yaml  
output_dir: "./swagger_filtered"
swaggers:  # 必需字段
  - source: "https://api.example.com/swagger.json"
    output: "user_api.json"
    include_paths:
      - "/api/v1/users"
      - "/api/v1/auth"
```

**执行流程**：
1. **swagger_filter** 自动优先执行，读取配置，过滤API → `./swagger_filtered/*.json`
2. **swagger_dart_code_generator** 自动在后执行，读取过滤后的文件 → `./lib/api/*.dart`

**无需手动控制执行顺序** - build_runner 会根据 `runs_before` 配置自动确保正确的执行序列。

### 项目结构

```
your_project/
├── build.yaml                 # build_runner 配置
├── swagger_filter.yaml        # swagger 过滤配置
├── swagger_filtered/           # 过滤后的 swagger 文档
│   ├── user_api.json          # 用户相关API
│   └── product_api.json       # 商品相关API
└── lib/
    └── api/                    # 生成的 Dart 代码
        ├── user_api.dart
        ├── product_api.dart
        └── models/
            ├── user.dart
            └── product.dart
```

### 集成优势

- 🔒 **安全优先**: 只生成需要的API，避免暴露敏感接口
- 📦 **体积优化**: 显著减少生成代码的大小
- 🚀 **性能提升**: 更少的API意味着更快的编译和运行时性能
- 🎯 **模块专注**: 每个API模块只包含相关功能
- 🔄 **自动化**: 配置一次，自动化处理整个工作流  
- ⚡ **执行顺序**: 通过 `runs_before` 自动确保在 swagger_dart_code_generator 之前执行
- 🎯 **零配置顺序**: 无需手动管理构建阶段，build_runner 自动处理依赖关系

## 🛠️ 故障排查

### 常见问题

**Q: 为什么没有生成任何文件？**
A: 检查 `build.yaml` 配置是否正确，确保 swagger_filter 配置存在。

**Q: 路径过滤不起作用？**
A: 记住 `include_paths` 使用精确匹配。`/api/v1` 不会匹配 `/api/v1/users`。

**Q: 看到 "No paths matched filters" 警告？**
A: 检查过滤条件，确保路径格式正确（以 `/` 开头）。

## 发布流程

### 自动化发布（推荐）
1. 进入GitHub仓库的 **Actions** 页面
2. 选择 **CI/CD** workflow
3. 点击 **Run workflow** 按钮
4. 选择版本类型：
   - `patch`: 1.0.0 → 1.0.1 (bug fixes)
   - `minor`: 1.0.0 → 1.1.0 (new features)  
   - `major`: 1.0.0 → 2.0.0 (breaking changes)
5. 点击 **Run workflow**

GitHub Actions会自动：
- 运行测试和代码检查
- 更新版本号（`pubspec.yaml`, `lib/version.dart`, `CHANGELOG.md`）
- 创建git commit和tag
- 创建GitHub Release
- 发布到pub.dev

### 本地开发
```bash
# 安装依赖
dart pub get

# 运行测试
dart test

# 代码格式化
dart format .

# 代码分析
dart analyze
```

---
如需其他高级用法，请联系开发者。
