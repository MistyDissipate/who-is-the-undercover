# 谁是卧底助手 MVP 开发文档

**版本**：v1.0.0 (MVP)  
**最后更新**：2026-2-20  
**状态**：开发中

---

## 1. 需求规格说明书

### 1.1 项目背景
一款无需真人主持的聚会游戏辅助工具。用户设置玩家数量和卧底数量后，App自动分配身份和词汇，并通过翻页形式逐一展示给玩家，完全替代传统主持人。

### 1.2 目标用户
聚会组织者、桌游爱好者，希望快速开始游戏且避免主持人“睁眼”带来的剧透。

### 1.3 功能列表（MVP）

| 优先级 | 功能点 | 描述 |
|--------|--------|------|
| **P0** | 游戏设置 | 输入玩家总数（3-12）、卧底数（≥1且<玩家数的一半） |
| **P0** | 词汇库 | 内置至少20组词汇对（平民词-卧底词） |
| **P0** | 身份分配 | 随机选择一组词汇，随机指定卧底，为每位玩家生成词条 |
| **P0** | 玩家翻页查看 | 界面仅显示当前玩家的身份和词汇，通过“下一玩家”按钮切换 |
| **P0** | 游戏重置 | 返回设置页，重新开始 |
| **P1** | 存活管理 | 标记淘汰玩家，自动判断游戏胜负 |
| **P1** | 胜负提示 | 游戏结束时弹出对话框显示胜利方 |
| **P2** | 投票界面 | 列出存活玩家，主持人可手动选择淘汰对象 |

*注：MVP聚焦P0功能，P1/P2可后续迭代。*

### 1.4 业务规则
- 玩家数范围：3-12人（含）。
- 卧底数至少1，且不得超过玩家数的一半（可自定义，但默认校验卧底数 < 玩家数）。
- 平民词与卧底词必须不同，且在某些方面有共通之处（如：电脑-电视）。
- 游戏结束条件：
  - 卧底全部淘汰 → 平民胜利。
  - 存活平民数 ≤ 存活卧底数 → 卧底胜利（可根据实际规则调整）。
- 每次游戏随机选择词汇对，并随机分配卧底身份。

---

## 2. 技术设计文档

### 2.1 技术栈
- **Flutter**：3.16+ (稳定版)
- **状态管理**：Provider (或 Riverpod，根据熟悉程度选择)
- **路由**：go_router (或基础Navigator)
- **本地存储**：shared_preferences (用于后续自定义词库)
- **词汇数据**：JSON文件存放于assets中

### 2.2 数据模型
```dart
// lib/models/game_models.dart

enum GameRole { civilian, undercover }
enum GameStatus { setting, playing, ended }

class Player {
  final int id;            // 玩家编号（1~n）
  String name;             // 显示为“玩家X”
  GameRole role;
  String word;
  bool isAlive;

  Player({
    required this.id,
    required this.name,
    required this.role,
    required this.word,
    this.isAlive = true,
  });
}

class Game {
  List<Player> players;
  int undercoverCount;
  String civilianWord;
  String undercoverWord;
  GameStatus status;

  Game({
    required this.players,
    required this.undercoverCount,
    required this.civilianWord,
    required this.undercoverWord,
    this.status = GameStatus.playing,
  });
}
```

### 2.3 状态管理设计 (Provider)
使用以下Provider管理全局状态：
- `gameProvider`：持有当前`Game`对象。
- `currentPlayerIndexProvider`：当前显示玩家的索引。
- `settingsProvider`：记录最近使用的设置（玩家数、卧底数）。

状态更新流程：
1. 用户在设置页输入并点击“开始游戏”。
2. 调用`GameService.startGame(playerCount, undercoverCount)`生成`Game`对象。
3. 更新`gameProvider`，并跳转到游戏主持页。
4. 点击“下一玩家”时，更新`currentPlayerIndexProvider`。
5. 淘汰玩家时，修改对应`Player.isAlive`，并触发胜负判断。

### 2.4 核心算法：词汇分配

**词汇库结构** (assets/word_pairs.json)：
```json
[
  { "civilian": "苹果", "undercover": "香蕉" },
  { "civilian": "电脑", "undercover": "电视" },
  { "civilian": "可乐", "undercover": "雪碧" }
]
```

**分配逻辑**：
1. 随机选择一组词汇对。
2. 根据卧底数，随机选出指定数量的玩家作为卧底。
3. 为所有玩家赋值：卧底得到`undercoverWord`，平民得到`civilianWord`。
4. 打乱玩家顺序（可选），保证公平。

**关键代码示例**：
```dart
List<Player> assignWords(int playerCount, int undercoverCount) {
  // 加载词库
  final wordPair = _randomWordPair();
  final civilianWord = wordPair['civilian'];
  final undercoverWord = wordPair['undercover'];

  // 创建玩家列表
  List<Player> players = List.generate(playerCount, (index) {
    return Player(id: index + 1, name: '玩家${index+1}');
  });

  // 随机选卧底
  final undercoverIndices = <int>{};
  while (undercoverIndices.length < undercoverCount) {
    undercoverIndices.add(Random().nextInt(playerCount));
  }

  // 分配词汇
  for (int i = 0; i < players.length; i++) {
    if (undercoverIndices.contains(i)) {
      players[i].role = GameRole.undercover;
      players[i].word = undercoverWord;
    } else {
      players[i].role = GameRole.civilian;
      players[i].word = civilianWord;
    }
  }
  return players;
}
```

---

## 3. UI/UX设计文档

### 3.1 游戏状态机图
![](./uml/state/state_diagram.png "")

### 3.2 设置页设计
- 顶部标题：“谁是卧底助手”
- 两个输入框：
  - 玩家数：数字键盘，默认8，范围4-12。
  - 卧底数：数字键盘，默认2，范围1-（玩家数-1）。
- 开始按钮：居中，点击后校验输入，若通过则跳转。

### 3.3 游戏主持页设计
- **顶部状态栏**：显示“存活人数：X/Y”和当前玩家序号（如“玩家3”）。
- **中央卡片**：
  - 大号字体显示词汇（如“苹果”）。
  - 下方小字显示身份（平民/卧底），并用不同底色区分（平民绿，卧底红）。
- **底部按钮**：
  - “下一玩家”：查看下一个存活玩家，若已到最后则提示“已看完”。
  - “淘汰玩家”（可选）：点击后弹出列表选择要淘汰的玩家。
  - “结束游戏”：手动结束并查看结果。

### 3.4 交互细节
- 切换玩家时，卡片应有淡入淡出或滑动动画。
- 淘汰玩家后，自动跳转到下一个存活玩家。
- 游戏结束时弹出对话框，展示胜利阵营和所有玩家身份（可选）。

---

## 4. 开发与测试指南

### 4.1 环境配置
- Flutter SDK: >=3.16.0
- IDE: Trae / VS Code
- 依赖库（在`pubspec.yaml`中添加）：
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  go_router: ^13.0.0
  shared_preferences: ^2.2.2
```

### 4.2 目录结构
```
lib/
├── main.dart
├── models/
│   └── game_models.dart
├── providers/
│   ├── game_provider.dart
│   └── settings_provider.dart
├── screens/
│   ├── setup_screen.dart
│   ├── host_screen.dart
│   └── vote_screen.dart (可选)
├── widgets/
│   ├── player_card.dart
│   └── status_bar.dart
├── services/
│   └── game_service.dart (词汇分配、胜负判断)
├── utils/
│   └── constants.dart (如词汇库路径)
└── data/
    └── word_pairs.json
```

### 4.3 测试用例

| 测试场景 | 输入 | 预期结果 |
|----------|------|----------|
| TC01 正常启动 | 玩家数8，卧底2 | 生成8个玩家，其中2个卧底词相同，6个平民词相同 |
| TC02 边界值 | 玩家数4，卧底1 | 生成4个玩家，1卧底，3平民 |
| TC03 非法输入 | 玩家数3，卧底2 | 点击开始提示“卧底数不能超过玩家数-1” |
| TC04 卧底胜利 | 3人局，1卧底，淘汰1平民 | 剩余1平民1卧底，应提示卧底胜利 |
| TC05 平民胜利 | 3人局，1卧底，淘汰卧底 | 剩余2平民，应提示平民胜利 |
| TC06 翻页循环 | 5玩家存活3，点击下一玩家 | 依次显示3个存活玩家，最后回到第一个 |

### 4.4 构建与发布
- **Android**：`flutter build apk --release`
- **iOS**：`flutter build ios --release` (需Xcode配置)
- 应用名称：“谁是卧底助手”
- 图标：自行设计或使用占位图

---

## 5. 后续迭代规划
- **v1.1**：自定义词汇（增删改查）、暗黑模式。
- **v1.2**：白板身份、游戏计时器。
- **v1.3**：在线匹配（扩展为联网版）。
