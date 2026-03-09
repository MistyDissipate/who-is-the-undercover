# 谁是卧底助手（Uncover Agent）

**版本**：v1.0.1（当前实现同步）  
**最后更新**：2026-03-05  
**状态**：开发中（可用）

---

## 1. 项目简介

这是一款线下聚会用的“谁是卧底”辅助工具，支持：
- 开局参数设置（玩家数/卧底数）
- 词库选择与管理
- 逐人看词
- 投票淘汰与胜负结算
- 问题日志反馈（邮件）

---

## 2. 当前已实现功能

### 2.1 对局流程
- 设置页配置人数与规则后开始游戏
- 主持页逐位查看词汇（默认隐藏，点击显示）
- 投票页选择并确认淘汰
- 自动判定胜负并显示结算
- 支持“再来一局”（沿用本局词库与规则）

### 2.2 规则配置
- 玩家数与卧底数联动约束
- 新增开关：`出局后显示身份`
  - 开启：淘汰后弹窗显示身份，需点击确认
  - 关闭：淘汰后仅提示已出局

### 2.3 词库系统（v1.1 核心）
- 已取消旧的“分类/难度筛选”开局方式
- 改为“词库选择”模式（单选可用词库）
- 默认词库已重组为 3 个分组：
  - `日常`
  - `简单易懂`
  - `大杂烩`
- 新增词库管理页：
  - 启用/停用词库
  - 新建用户词库
  - 编辑用户词库（词条增删改）
  - 导入词库（TOML 优先，兼容 JSON）
  - 导出词库（TOML）

### 2.4 日志与反馈
- 全局异常日志接入（Flutter 框架错误）
- 关键业务行为日志（词库加载、开局、设置变更等）
- 支持用户在设置页发起问题反馈：
  - 选择问题类型
  - 填写问题描述（可为空）
  - 调起邮箱并预填日志正文

### 2.5 移动端体验优化
- 主持页横屏支持滚动，底部按钮可点击
- 横屏时词汇字号自动缩小，减少遮挡

---

## 3. 词库格式说明（TOML）

### 3.1 推荐格式

```toml
name = "我的词库"

[[pairs]]
civilian = "苹果"
undercover = "香蕉"

[[pairs]]
civilian = "猫"
undercover = "狗"
```

### 3.2 兼容说明
- 导入时支持 JSON（历史格式）
- 默认导出为 TOML
- 默认内置词库通过 `assets/wordbanks/index.json` 管理

---

## 4. 项目结构（当前）

```text
lib/
├── main.dart
├── models/
│   └── game_models.dart
├── screens/
│   ├── setup_screen.dart
│   ├── host_screen.dart
│   ├── vote_screen.dart
│   ├── word_bank_manage_screen.dart
│   └── word_bank_edit_screen.dart
├── services/
│   ├── game_service.dart
│   ├── word_pool_service.dart
│   └── issue_report_service.dart
├── utils/
│   └── app_logger.dart
└── widgets/
    └── setup/
        ├── setting_card.dart
        └── counter_setting_card.dart
```

---

## 5. 环境与依赖

### 5.1 环境
- Flutter SDK：`>=3.16.0`（建议）
- Dart SDK：`^3.11.0`

### 5.2 主要依赖
- `google_fonts`
- `shared_preferences`
- `url_launcher`

---

## 6. 本地运行

```bash
flutter pub get
flutter run
```

### 构建
- Android：`flutter build apk --release`
- iOS：`flutter build ios --release`

---

## 7. 已知事项

- 旧分类词库 JSON 已迁移到 `assets/wordbanks/legacy/`，不再作为默认索引来源。
- 导入 TOML 时建议每个词条使用 `[[pairs]]` 段，避免格式歧义。
- 用户反馈邮件依赖设备邮箱客户端可用性。

---

## 8. 下一步建议

- 增加词库导入的可视化校验（逐行错误提示）
- 支持文件选择器导入/导出（而非纯文本粘贴）
- 增加词库去重工具与批量清洗
