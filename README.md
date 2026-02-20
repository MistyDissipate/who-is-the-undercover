# 谁是卧底助手 开发文档（与当前实现同步）

**版本**：v1.0.1  
**最后更新**：2026-2-20  
**状态**：开发中（文档已按现代码同步）

---

## 1. 当前实现概览

### 1.1 项目背景
这是一款线下聚会用的“谁是卧底”辅助工具。应用负责完成词库抽取、身份分配、逐人看词、投票淘汰与胜负结算。

### 1.2 已实现功能（按代码现状）

| 优先级 | 功能点 | 当前实现状态 |
|--------|--------|--------------|
| **P0** | 游戏设置 | ✅ 通过加减按钮设置玩家数和卧底数 |
| **P0** | 词库加载 | ✅ 支持 `assets/wordbanks/index.json` 分词库；失败时回退 `assets/word_pairs.json` |
| **P0** | 分类与难度筛选 | ✅ 设置页可读取启用分类；可开关“按难度筛选” |
| **P0** | 身份与词汇分配 | ✅ 随机词对 + 随机卧底索引 |
| **P0** | 逐人看词流程 | ✅ 主持页逐位展示，先隐藏词汇，点击后再进入下一位 |
| **P1** | 投票淘汰 | ✅ 投票页按存活玩家单选淘汰，带二次确认 |
| **P1** | 胜负判定与结算 | ✅ 自动判定并弹窗展示全员身份/词汇 |
| **P1** | 忘词回看 | ✅ 投票页可选存活玩家回看词汇 |

### 1.3 业务规则（当前实现）
- 玩家数通过上下限联动约束，实际最小值受卧底数影响：`minPlayers = undercoverNum * 2 + 1`。
- 全局玩家上限：`12`。
- 卧底数下限：`1`；上限：`ceil(playerNum / 2) - 1`。
- `GameService` 校验：`undercoverCount` 必须在 `1..playerCount-1`。
- 胜负条件：
  - 存活卧底数为 0：平民胜利。
  - 存活平民数 <= 存活卧底数：卧底胜利。

---

## 2. 技术设计（当前实现）

### 2.1 技术栈
- Flutter（Material）
- 路由：`MaterialApp + Navigator`
- 状态管理：页面内 `StatefulWidget + setState`（尚未接入 Provider/Riverpod）
- 词库：本地 JSON（assets）

### 2.2 代码结构（实际存在）
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
  - 玩家数：数字键盘，默认4，最少3，最多12。
  - 卧底数：数字键盘，默认1，最少1，最多小于玩家数目的一半。
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
├── screens/
│   ├── setup_screen.dart
│   ├── host_screen.dart
│   └── vote_screen.dart
└── services/
    ├── game_service.dart
    └── word_pool_service.dart
```

### 2.3 数据模型
```dart
enum GameRole { civilian, undercover }

class Player {
  final int id;
  final String name;
  final GameRole role;
  final String word;
  bool isAlive;
  Player copy();
}
```

> 说明：当前代码中**没有** `Game` 聚合对象与 `GameStatus` 枚举，游戏流程由各页面状态直接驱动。

### 2.4 词库与分配逻辑
1. `WordPoolService.loadWordBankOptions()` 读取 `assets/wordbanks/index.json`。
2. 若分词库可用，合并所有 `enabled` 文件并去重词对；否则回退旧格式 `assets/word_pairs.json`。
3. `GameService.createPlayersFromWordPool()`：
   - 随机取一组词对；
   - 生成 `playerCount` 个平民；
   - 随机挑选 `undercoverCount` 个索引替换为卧底词。

---

## 3. UI/UX（按当前页面行为）

### 3.1 设置页（`SetupScreen`）
- AppBar 标题：`游戏设置`。
- 卡片内容：项目标题、词库加载状态、启用分类提示。
- 难度筛选：`Switch + ChoiceChip`，开启后仅使用选定难度。
- 玩家数/卧底数：使用加减按钮计数器，不是文本输入框。
- 底部固定按钮：`开始游戏`，进入 `HostScreen`。

### 3.2 主持页（`HostScreen`）
- AppBar 标题：`查看词汇`。
- 初始状态：异步加载玩家；失败时显示错误和“重试”。
- 主流程：
  1. 显示“当前玩家：玩家X”；
  2. 词汇区域默认显示 `???`；
  3. 点击 `点击查看词汇` 后才显示真实词；
  4. 点击 `确认，下一位` 进入下一位，并再次隐藏词汇；
  5. 最后一位按钮变为 `开始游戏`，进入 `VoteScreen`。
- 当已到最后且继续下一位时，会提示：`所有玩家都已查看词汇`。

> 说明：当前主持页**不显示身份标签、不显示存活人数、不可直接淘汰玩家**；淘汰逻辑在投票页。

### 3.3 投票页（`VoteScreen`）
- AppBar 标题：`投票淘汰`，右上角提供 `忘词回看`。
- 主体为存活玩家单选列表（已淘汰玩家不显示）。
- 点击 `淘汰选中玩家` 会二次确认，再更新 `isAlive`。
- 触发胜负后弹出结算：
  - 显示胜利方；
  - 展示所有玩家身份、词汇、存活状态；
  - 支持 `返回首页` / `再来一局`。

### 3.4 UML 图（已同步）
- 状态图：![](./uml/state/state_diagram.png)
- 活动图：![](./uml/activity/activity_diagram.png)
- 时序图：![](./uml/sequence/sequence_diagram.png)

---

## 4. 开发与测试指南（同步版）

### 4.1 推荐测试点

| 编号 | 场景 | 输入 | 预期 |
|------|------|------|------|
| TC01 | 正常开局 | 玩家8，卧底2 | 成功进入主持页，逐位可查看词汇 |
| TC02 | 参数联动下限 | 卧底2时调玩家数 | 玩家最小值自动变为5 |
| TC03 | 词库筛选 | 开启难度筛选并选难度 | 可正常开局，词对来自对应难度 |
| TC04 | 主持页流程 | 点击查看词汇后下一位 | 下一位词汇重新隐藏为`???` |
| TC05 | 卧底胜利 | 存活平民数<=存活卧底数 | 弹出“卧底胜利！”结算框 |
| TC06 | 平民胜利 | 所有卧底被淘汰 | 弹出“平民胜利！”结算框 |
| TC07 | 忘词回看 | 投票页点击忘词回看 | 仅可选存活玩家并查看其词汇 |

### 4.2 构建命令
- Android：`flutter build apk --release`
- iOS：`flutter build ios --release`（需 Xcode）

---

## 5. 已知差异与后续发展
- 文档已与当前代码同步，重点修正了“主持页设计”描述。
- `再来一局` 当前会按人数重开，但不会继承上局分类/难度筛选（可作为下一步优化点）。
