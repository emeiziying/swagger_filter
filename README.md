# Swagger Filter

## 功能
- 支持本地/网络swagger批量过滤
- 每个swagger可单独配置包含/排除API
- 输出过滤后的swagger到指定目录
- 支持OpenAPI 2.0/3.0
- 支持build_runner自动生成
- 支持命令行独立运行

## 配置示例（swagger_filter.yaml）
```yaml
swaggers:
  - source: ./swaggers/smartOpsPro.json
    include_paths: ["/workTeam/add", "/user/login"]
    exclude_tags: ["internal"]
    output: smartOpsPro.filtered.json
  - source: https://api.xxx.com/swagger.json
    include_tags: ["public"]
    output: xxx.filtered.json
output_dir: ./filtered
```

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
