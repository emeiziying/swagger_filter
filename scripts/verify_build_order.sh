#!/bin/bash

# 验证 swagger_filter 在 swagger_dart_code_generator 之前执行
# 文件: scripts/verify_build_order.sh

echo "🔍 验证 build_runner 执行顺序..."
echo ""

# 检查 build.yaml 配置
if grep -q "runs_before.*swagger_dart_code_generator" build.yaml; then
    echo "✅ build.yaml: 发现 runs_before 配置"
    echo "   swagger_filter 将在 swagger_dart_code_generator 之前执行"
else
    echo "❌ build.yaml: 未找到 runs_before 配置"
    echo "   建议添加: runs_before: [\"swagger_dart_code_generator\"]"
fi

echo ""

# 检查 build_extensions 配置
if grep -q "swagger_filter.yaml.*swagger_filtered" build.yaml; then
    echo "✅ build_extensions: 配置正确"
    echo "   只处理 swagger_filter.yaml 文件"
else
    echo "❌ build_extensions: 配置可能有问题"
fi

echo ""

# 检查配置文件是否存在
if [ -f "swagger_filter.yaml" ]; then
    echo "✅ swagger_filter.yaml: 配置文件存在"
    echo "   Builder将从此文件读取配置（推荐方式）"
else
    echo "⚠️  swagger_filter.yaml: 配置文件不存在"
    echo "   Builder将从 build.yaml 的 options 读取配置（向后兼容）"
fi

echo ""

# 检查配置方式
if grep -q "options:" build.yaml; then
    echo "ℹ️  build.yaml: 发现嵌入式配置"
    echo "   如果存在 swagger_filter.yaml，将优先使用独立配置文件"
else
    echo "ℹ️  build.yaml: 未发现嵌入式配置"
    echo "   需要创建 swagger_filter.yaml 配置文件"
fi

echo ""
echo "🎯 推荐的完整工作流:"
echo "1. 创建 swagger_filter.yaml 配置文件"
echo "2. 配置 build.yaml 启用两个 builder"
echo "3. 运行: dart run build_runner build"
echo "4. swagger_filter 先执行 → 生成过滤后的文档"
echo "5. swagger_dart_code_generator 后执行 → 生成 Dart 代码"
echo ""
echo "📁 期望的文件结构:"
echo "project/"
echo "├── build.yaml"
echo "├── swagger_filter.yaml"
echo "├── swagger_filtered/          # swagger_filter 输出"
echo "│   └── *.json"
echo "└── lib/api/                   # swagger_dart_code_generator 输出"
echo "    ├── *.dart"
echo "    └── models/"
echo ""
echo "🔄 这样确保了正确的处理顺序: 过滤 → 生成代码" 