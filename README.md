# OOXX - 圈叉逻辑谜题

纯逻辑推理游戏，在 N×N 棋盘上填入 X 或 O，挑战你的推理能力。

## 游戏规则

1. **数量平衡** — 每行每列中 X 与 O 的数量必须相同
2. **禁止三连** — 横向或纵向不能出现三个连续相同的符号
3. **行列唯一** — 任意两行或两列不能完全相同

深色格为题目给定的线索，点击空格按 `X → O → 空白` 循环切换。

## 三种难度

| 难度 | 棋盘 | 奖励 |
|------|------|------|
| 简单 | 6×6 | +2 分 |
| 中等 | 8×8 | +5 分 |
| 困难 | 10×10 | +7 分 |

## 功能

- 随机生成题目，每次挑战都不同
- 提示系统（消耗 2 积分）
- 自动检查（消耗 1 积分）
- 计时与积分统计
- Material Design 3 界面，支持深色模式

## 技术栈

- **语言**: Java 11
- **构建**: Gradle 9.4.1 + AGP 9.2.1 (Kotlin DSL)
- **最低 SDK**: Android 12 (API 31)
- **目标 SDK**: Android 14 (API 36)
- **UI**: Material 3 + ConstraintLayout
- **核心依赖**: appcompat 1.6.1, material 1.10.0

## 构建运行

用 Android Studio 打开项目，Gradle Sync 后即可运行。

```bash
# 命令行构建
./gradlew assembleDebug

# 安装到设备
./gradlew installDebug
```

## 项目结构

```
OOXX/
├── app/src/main/java/com/example/ooxx/
│   ├── MainActivity.java          # 主游戏界面
│   ├── DifficultyActivity.java    # 难度选择
│   ├── TicTacLogicView.java       # 棋盘自定义 View
│   └── GameProgress.java          # 积分/进度管理
└── app/src/main/res/              # 资源文件
```

## License

MIT
