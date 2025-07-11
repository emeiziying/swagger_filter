# Builder 命名机制详解

## 🎯 为什么有的只需要一个名称，有的需要两个？

### **情况1: swagger_dart_code_generator - 只需一个名称**

```yaml
targets:
  $default:
    builders:
      swagger_dart_code_generator:  # ✅ 只需要一个
        options:
          input_folder: "lib/swaggers"
```

**原因：自动发现机制**

`swagger_dart_code_generator` 使用了 build_runner 的**自动发现机制**：

1. **包级别注册**: 当你在 `pubspec.yaml` 中添加这个包时：
   ```yaml
   dev_dependencies:
     swagger_dart_code_generator: ^3.0.3
   ```

2. **自动注册**: build_runner 自动扫描依赖包，找到已注册的 builder

3. **默认映射**: 包名直接映射到 builder 名称

---

### **情况2: swagger_filter - 需要两个名称**

```yaml
targets:
  $default:
    builders:
      swagger_filter|swagger_filter:  # ⚠️ 必须明确指定
        options:
          swaggers: [...]
```

**原因：明确引用机制**

`swagger_filter` 使用了**明确引用格式**：

```
package_name|builder_name
     ↑            ↑
   包名称      构建器名称
```

## 🔧 两种机制的技术差异

### **机制1: 自动发现 (Auto-discovery)**

```dart
// swagger_dart_code_generator 包的内部结构
// 在包的 build.yaml 中自动注册
builders:
  swagger_dart_code_generator:  # 默认builder
    import: "package:swagger_dart_code_generator/builder.dart"
    builder_factories: ["swaggerDartCodeGeneratorBuilder"]
    auto_apply: dependents  # 自动应用到依赖项目
```

**使用时：**
```yaml
# build_runner 自动找到注册的 builder
swagger_dart_code_generator:  # 直接使用包名
  options: ...
```

### **机制2: 明确引用 (Explicit Reference)**

```dart
// swagger_filter 包的 build.yaml
builders:
  swagger_filter:  # builder 名称
    import: "package:swagger_filter/builder.dart"
    builder_factories: ["swaggerFilterBuilder"]
    auto_apply: none  # 不自动应用，需要明确引用
```

**使用时：**
```yaml
# 必须明确指定 package|builder
swagger_filter|swagger_filter:  # package_name|builder_name
  options: ...
```

## 📊 对比总结

| 特性 | swagger_dart_code_generator | swagger_filter |
|------|----------------------------|----------------|
| **引用格式** | `swagger_dart_code_generator` | `swagger_filter\|swagger_filter` |
| **发现机制** | 自动发现 | 明确引用 |
| **配置复杂度** | 简单 | 稍复杂 |
| **灵活性** | 有限 | 更高 |
| **多builder支持** | 不太好 | 很好 |

## 🤔 为什么 swagger_filter 选择明确引用？

### **优势：**

1. **多Builder支持**: 一个包可以有多个不同的builder
   ```yaml
   swagger_filter|swagger_filter:    # 过滤功能
   swagger_filter|swagger_generator: # 代码生成功能
   swagger_filter|swagger_validator: # 验证功能
   ```

2. **避免命名冲突**: 不同包可以有同名builder
   ```yaml
   package_a|json_builder:  # A包的json构建器
   package_b|json_builder:  # B包的json构建器
   ```

3. **明确控制**: 用户明确知道在使用哪个包的哪个builder

4. **版本兼容**: 更容易处理不同版本的兼容性

### **劣势：**

1. **配置复杂**: 需要记住 `package|builder` 格式
2. **学习曲线**: 新用户可能困惑

## 🎯 实际示例对比

### **swagger_dart_code_generator 风格**
```yaml
targets:
  $default:
    builders:
      # 简单直接
      swagger_dart_code_generator:
        options:
          input_folder: "lib/swaggers"
          output_folder: "lib/generated"
          
      # 其他自动发现的builder
      json_serializable:
        options:
          # json_serializable配置
          
      chopper_generator:
        options:
          # chopper配置
```

### **swagger_filter 风格**
```yaml
targets:
  $default:
    builders:
      # 明确引用
      swagger_filter|swagger_filter:
        options:
          swaggers: [...]
          
      # 如果将来有多个builder
      swagger_filter|code_generator:
        options:
          # 代码生成配置
          
      swagger_filter|validator:
        options:
          # 验证配置
```

## 🚀 选择建议

### **选择自动发现 (一个名称) 当：**
- 包只有一个主要功能
- 希望简化用户配置
- 目标是快速上手

### **选择明确引用 (两个名称) 当：**
- 包有多个不同功能的builder
- 需要避免命名冲突
- 希望给用户更多控制权
- 长期维护和扩展性更重要

---

**总结**: `swagger_dart_code_generator` 优先简单性，`swagger_filter` 优先灵活性和可扩展性。两种方式都是有效的，只是设计哲学不同！ 