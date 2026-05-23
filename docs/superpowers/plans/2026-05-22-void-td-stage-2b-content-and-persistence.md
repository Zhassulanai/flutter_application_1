# VOID TD — Stage 2b: Content & Persistence

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Turn Stage 2a's single hardcoded level into a real campaign: 3 levels with distinct paths and wave compositions (JSON-driven), a Level Select screen with stars, Victory/Defeat dialogs, an Endless mode on a separate map, and save-and-resume via Hive. All match state — both Campaign and Endless — survives app close, screen lock, and Pause.

**Architecture:**
- Replace `LevelOneConfig` (hardcoded Dart) with `assets/configs/levels/0X.json` for the 3 Campaign levels and `endless_map.json` for Endless. `LevelLoader` parses them into a typed `LevelConfig` Dart struct that `TdGame` consumes via `levelId` (`1`/`2`/`3`/`endless`).
- `PlayerProfile` (already designed in spec) gets a real Hive-backed implementation: stars per level, unlock state, settings; loaded once at app start, saved on every change.
- `MatchSnapshot` is a serialisable image of an in-flight match (lives, gold, currentWave, paletteSelection, list of placed towers/farms with positions+upgrades+totalSpent, current wave's spawn-runner state, accumulated farm-tick fraction). Saved on lifecycle pause + Pause button. Cleared on Victory/Defeat/Quit.
- Main menu shows CONTINUE only when a snapshot exists.

**Tech Stack:**
- All existing Stage 2a deps. Add Hive's typed adapters: `hive_generator: ^2.0.1` + `build_runner: ^2.4.13` (dev_dependencies). Generate `g.dart` files via `flutter pub run build_runner build --delete-conflicting-outputs`.
- New asset directory `assets/configs/` registered in `pubspec.yaml`.

**Spec reference:** [`docs/superpowers/specs/2026-05-21-tower-defense-mvp-design.md`](../specs/2026-05-21-tower-defense-mvp-design.md)

**Key decisions locked in:**
- **Main menu:** CAMPAIGN / ENDLESS / SETTINGS (stub). CONTINUE appears at the top automatically when a saved match exists (highlighted in cyan).
- **Campaign:** 3 levels. Star unlock: any star (>= 1) opens the next level. No star gating yet (deferred to Stage 5).
- **Stars:** ★★★ = 0 lives lost, ★★ = 1–6 lost, ★ = pass with any losses.
- **All 5 towers available from level 1.** No gradual unlock by level.
- **Endless:** one map (long S-zigzag). 20 lives, no campaign-stars metric. Game-over on lives = 0; final record = highest cleared wave. Endless waves auto-generate procedurally with infinitely scaling difficulty (Tank from wave 5, Boss every 10 starting at wave 10).
- **Save & Resume:**
  - Triggers: `AppLifecycleState.paused`/`inactive` (screen lock, app to background), explicit Pause button.
  - Both Campaign and Endless saved identically.
  - Cleared when match ends (Victory/Defeat) or player taps Quit from pause dialog.
  - Loaded automatically into CONTINUE button on main menu — tapping CONTINUE restores the exact moment of the match.
- **No new music/sounds.** Audio is Stage 4.

**Working directory:** `c:\dev\void_td`. Platform Windows. Use `.withValues(alpha: x)`.

---

## File Structure changes

```
c:\dev\void_td\
├── pubspec.yaml                                    // MODIFIED: register assets/configs, add hive_generator dev dep
│
├── assets\configs\
│   ├── levels\
│   │   ├── 01.json                                 // NEW: level 1 (current — formalised as JSON)
│   │   ├── 02.json                                 // NEW: level 2 (S-curve, intro Tank+Swarm)
│   │   └── 03.json                                 // NEW: level 3 (forked path, intro Boss)
│   └── endless_map.json                            // NEW: long S-zigzag for Endless
│
├── lib\
│   ├── data\
│   │   ├── level_one_config.dart                   // DELETED — replaced by level_config.dart + LevelLoader
│   │   ├── level_config.dart                       // NEW: typed LevelConfig + WaveSpec models
│   │   ├── level_loader.dart                       // NEW: JSON → LevelConfig parser, asset cache
│   │   ├── towers_config.dart                      // unchanged
│   │   └── enemies_config.dart                     // unchanged
│   │
│   ├── meta\
│   │   ├── profile\
│   │   │   ├── player_profile.dart                 // NEW: Hive type adapter + struct
│   │   │   └── profile_repo.dart                   // NEW: load/save profile, Riverpod-ready notifier
│   │   └── progress\
│   │       └── stars.dart                          // NEW: pure-Dart helper to compute stars from result
│   │
│   ├── game\
│   │   ├── td_game.dart                            // MODIFIED: take LevelConfig instead of hardcoded grid/waves; emit Victory/Defeat signals; Endless mode hook
│   │   ├── game_screen.dart                        // MODIFIED: take LevelConfig + handle Victory/Defeat dialogs; save snapshot on lifecycle pause and explicit Pause
│   │   └── match\
│   │       ├── match_state.dart                    // unchanged
│   │       ├── hud.dart                            // unchanged
│   │       └── match_snapshot.dart                 // NEW: serialisable image of MatchState + placed towers + wave runner state
│   │
│   ├── ui\
│   │   ├── main_menu\
│   │   │   └── main_menu_screen.dart               // MODIFIED: CONTINUE / CAMPAIGN / ENDLESS / SETTINGS
│   │   ├── level_select\
│   │   │   └── level_select_screen.dart            // NEW: list of 3 levels with stars and lock state
│   │   ├── match\
│   │   │   ├── tower_palette.dart                  // unchanged
│   │   │   ├── tower_upgrade_panel.dart            // unchanged
│   │   │   ├── speed_bar.dart                      // unchanged
│   │   │   ├── budget_dots.dart                    // unchanged
│   │   │   ├── victory_dialog.dart                 // NEW: stars + bonus summary + actions
│   │   │   └── defeat_dialog.dart                  // NEW: retry / quit
│   │   └── shared\
│   │       └── neon_button.dart                    // unchanged
│   │
│   ├── core\theme\                                 // unchanged
│   │
│   └── app.dart                                    // MODIFIED: initialise Hive, load PlayerProfile, register adapters before runApp
│
└── test\
    ├── level_loader_test.dart                      // NEW
    ├── stars_test.dart                             // NEW
    ├── match_snapshot_test.dart                    // NEW
    └── (existing tests unchanged)
```

---

## Task 1: Asset directory + JSON configs for 3 levels and Endless

**Files:**
- Modify: `c:\dev\void_td\pubspec.yaml`
- Create: `c:\dev\void_td\assets\configs\levels\01.json`
- Create: `c:\dev\void_td\assets\configs\levels\02.json`
- Create: `c:\dev\void_td\assets\configs\levels\03.json`
- Create: `c:\dev\void_td\assets\configs\endless_map.json`

### Step 1: Register asset folder in pubspec.yaml

Open `pubspec.yaml`. Find the `flutter:` section near the bottom. Add (or extend) the `assets:` entry:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/configs/levels/
    - assets/configs/
```

(The first line covers level files; the second covers `endless_map.json` at the configs root.)

### Step 2: Create directories

Run (from `c:\dev\void_td`):
```
mkdir assets\configs\levels
```

### Step 3: Create `01.json`

This is the existing level 1 redesigned per TD best-practice (8 waves, one bend, all Grunt+Fast+Swarm, no Tank/Boss). Keep the same shape as `LevelOneConfig`:

```json
{
  "id": 1,
  "name": "FIRST CONTACT",
  "grid": { "cols": 9, "rows": 16, "cellSize": 40 },
  "pathCells": [[2,0],[2,8],[6,8],[6,15]],
  "startingLives": 20,
  "startingGold": 200,
  "passiveIncomePerWave": 10,
  "passiveIncomePerWaveGrowth": 2,
  "waves": [
    { "spawns": [{"type":"grunt","count":5,"gap":1.2}] },
    { "spawns": [{"type":"grunt","count":7,"gap":1.0}] },
    { "spawns": [{"type":"grunt","count":8,"gap":0.9}] },
    { "spawns": [{"type":"fast","count":4,"gap":0.7}] },
    { "spawns": [
        {"type":"grunt","count":4,"gap":1.0},
        {"type":"fast","count":4,"gap":0.7,"after":4.5}
    ] },
    { "spawns": [{"type":"interleave","grunt":6,"fast":4,"gap":0.8}] },
    { "spawns": [{"type":"swarm","count":10,"gap":0.4}] },
    { "spawns": [{"type":"grunt","count":12,"gap":0.7}] }
  ]
}
```

### Step 4: Create `02.json`

Level 2: S-curve (3 turns), 10 waves, introduces Tank (wave 3) and bigger Swarm (wave 5).

```json
{
  "id": 2,
  "name": "SWITCHBACKS",
  "grid": { "cols": 9, "rows": 16, "cellSize": 40 },
  "pathCells": [[4,0],[4,3],[1,3],[1,9],[7,9],[7,12],[4,12],[4,15]],
  "startingLives": 20,
  "startingGold": 250,
  "passiveIncomePerWave": 12,
  "passiveIncomePerWaveGrowth": 2,
  "waves": [
    { "spawns": [{"type":"grunt","count":6,"gap":1.0}] },
    { "spawns": [{"type":"fast","count":6,"gap":0.7}] },
    { "spawns": [{"type":"tank","count":2,"gap":2.5}] },
    { "spawns": [
        {"type":"grunt","count":6,"gap":0.9},
        {"type":"fast","count":3,"gap":0.6,"after":5.5}
    ] },
    { "spawns": [{"type":"swarm","count":15,"gap":0.3}] },
    { "spawns": [
        {"type":"tank","count":1,"gap":0},
        {"type":"grunt","count":8,"gap":0.7,"after":1.0}
    ] },
    { "spawns": [{"type":"interleave","grunt":8,"fast":6,"gap":0.7}] },
    { "spawns": [
        {"type":"fast","count":10,"gap":0.4},
        {"type":"tank","count":2,"gap":2.0,"after":4.5}
    ] },
    { "spawns": [{"type":"swarm","count":20,"gap":0.25}] },
    { "spawns": [
        {"type":"tank","count":3,"gap":1.8},
        {"type":"grunt","count":10,"gap":0.6,"after":1.0}
    ] }
  ]
}
```

### Step 5: Create `03.json`

Level 3: forked path (re-merges), 12 waves, climax = Boss + grunt escort.

```json
{
  "id": 3,
  "name": "BREAKPOINT",
  "grid": { "cols": 9, "rows": 16, "cellSize": 40 },
  "pathCells": [[4,0],[4,5],[1,5],[1,10],[7,10],[7,5],[4,5],[4,15]],
  "startingLives": 20,
  "startingGold": 300,
  "passiveIncomePerWave": 14,
  "passiveIncomePerWaveGrowth": 2,
  "waves": [
    { "spawns": [{"type":"grunt","count":8,"gap":0.9}] },
    { "spawns": [{"type":"fast","count":8,"gap":0.6}] },
    { "spawns": [{"type":"tank","count":2,"gap":2.0}] },
    { "spawns": [{"type":"swarm","count":20,"gap":0.3}] },
    { "spawns": [
        {"type":"grunt","count":6,"gap":0.8},
        {"type":"tank","count":2,"gap":2.0,"after":5.0}
    ] },
    { "spawns": [{"type":"interleave","grunt":10,"fast":6,"gap":0.7}] },
    { "spawns": [
        {"type":"tank","count":3,"gap":1.6},
        {"type":"fast","count":8,"gap":0.5,"after":1.0}
    ] },
    { "spawns": [{"type":"swarm","count":30,"gap":0.22}] },
    { "spawns": [
        {"type":"tank","count":4,"gap":1.5},
        {"type":"grunt","count":12,"gap":0.6,"after":2.0}
    ] },
    { "spawns": [
        {"type":"boss","count":1,"gap":0},
        {"type":"grunt","count":6,"gap":1.0,"after":3.0}
    ] },
    { "spawns": [
        {"type":"interleave","grunt":12,"fast":8,"gap":0.6},
        {"type":"tank","count":2,"gap":2.0,"after":10.0}
    ] },
    { "spawns": [
        {"type":"boss","count":1,"gap":0},
        {"type":"grunt","count":10,"gap":0.5,"after":2.0},
        {"type":"tank","count":2,"gap":1.5,"after":6.0}
    ] }
  ]
}
```

### Step 6: Create `endless_map.json`

Long S-zigzag through 16 rows, 4 turns:
```json
{
  "id": "endless",
  "name": "ENDLESS",
  "grid": { "cols": 9, "rows": 16, "cellSize": 40 },
  "pathCells": [[1,0],[1,3],[7,3],[7,7],[1,7],[1,11],[7,11],[7,15]],
  "startingLives": 20,
  "startingGold": 250,
  "passiveIncomePerWave": 10,
  "passiveIncomePerWaveGrowth": 3
}
```

Endless waves are generated procedurally in code (no `waves` array — handled in Task 5).

### Step 7: Verify the assets are registered

Run:
```
flutter pub get
flutter analyze
```
Expected: no analysis errors. JSON files are just assets; nothing references them yet.

### Step 8: Commit

```
git add pubspec.yaml assets/
git commit -m "feat(data): add JSON configs for 3 Campaign levels + Endless map"
```

---

## Task 2: LevelConfig model + LevelLoader (with TDD)

**Files:**
- Create: `c:\dev\void_td\lib\data\level_config.dart`
- Create: `c:\dev\void_td\lib\data\level_loader.dart`
- Create: `c:\dev\void_td\test\level_loader_test.dart`

### Step 1: Write the failing test

Create `c:\dev\void_td\test\level_loader_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/data/enemies_config.dart';
import 'package:void_td/data/level_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LevelLoader', () {
    test('loads level 1 from assets', () async {
      final cfg = await LevelLoader.loadCampaignLevel(1);
      expect(cfg.id, '1');
      expect(cfg.name, 'FIRST CONTACT');
      expect(cfg.grid.cols, 9);
      expect(cfg.grid.rows, 16);
      expect(cfg.grid.cellSize, 40);
      expect(cfg.startingLives, 20);
      expect(cfg.startingGold, 200);
      expect(cfg.passiveIncomePerWave, 10);
      expect(cfg.passiveIncomePerWaveGrowth, 2);
      expect(cfg.waves.length, 8);
    });

    test('level 1 wave 1: 5 grunts at gap 1.2', () async {
      final cfg = await LevelLoader.loadCampaignLevel(1);
      final w1 = cfg.waves[0];
      expect(w1.length, 5);
      expect(w1[0].type, EnemyType.grunt);
      expect(w1[0].atSec, 0);
      expect(w1[1].atSec, closeTo(1.2, 0.001));
      expect(w1[4].atSec, closeTo(4.8, 0.001));
    });

    test('level 1 wave 7: 10 swarm at gap 0.4', () async {
      final cfg = await LevelLoader.loadCampaignLevel(1);
      final w7 = cfg.waves[6];
      expect(w7.length, 10);
      expect(w7.every((s) => s.type == EnemyType.swarm), isTrue);
      expect(w7[9].atSec, closeTo(3.6, 0.001));
    });

    test('level 3 wave 10 has a boss', () async {
      final cfg = await LevelLoader.loadCampaignLevel(3);
      final w10 = cfg.waves[9];
      expect(w10.any((s) => s.type == EnemyType.boss), isTrue);
    });

    test('loads endless map (no waves array)', () async {
      final cfg = await LevelLoader.loadEndless();
      expect(cfg.id, 'endless');
      expect(cfg.waves, isEmpty);
      expect(cfg.pathPoints.length, 8);
    });

    test('interleave spawn block expands to alternating grunt/fast', () async {
      final cfg = await LevelLoader.loadCampaignLevel(1);
      final w6 = cfg.waves[5]; // 6 grunt + 4 fast interleaved at gap 0.8
      // Order should be: grunt, fast, grunt, fast, grunt, fast, grunt, fast, grunt, grunt
      expect(w6.where((s) => s.type == EnemyType.grunt).length, 6);
      expect(w6.where((s) => s.type == EnemyType.fast).length, 4);
      expect(w6.first.type, EnemyType.grunt);
    });
  });
}
```

### Step 2: Verify it fails

```
flutter test test/level_loader_test.dart
```
Expected: FAIL — `LevelLoader` and `LevelConfig` don't exist.

### Step 3: Create `level_config.dart`

```dart
import 'package:flame/components.dart';
import '../game/grid/grid.dart';
import '../game/waves/wave_runner.dart';

/// Static config for one level (Campaign or Endless).
/// Endless has empty `waves` — its waves are generated procedurally in code.
class LevelConfig {
  final String id;                 // "1", "2", "3", "endless"
  final String name;
  final Grid grid;
  final List<Vector2> pathPoints;
  final int startingLives;
  final int startingGold;
  final double passiveIncomePerWave;
  final double passiveIncomePerWaveGrowth;
  final List<List<EnemySpawn>> waves;

  LevelConfig({
    required this.id,
    required this.name,
    required this.grid,
    required this.pathPoints,
    required this.startingLives,
    required this.startingGold,
    required this.passiveIncomePerWave,
    required this.passiveIncomePerWaveGrowth,
    required this.waves,
  });
}
```

### Step 4: Create `level_loader.dart`

```dart
import 'dart:convert';
import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../game/grid/grid.dart';
import '../game/waves/wave_runner.dart';
import 'enemies_config.dart';
import 'level_config.dart';

class LevelLoader {
  static final Map<String, LevelConfig> _cache = {};

  static Future<LevelConfig> loadCampaignLevel(int id) async {
    final key = 'campaign-$id';
    if (_cache.containsKey(key)) return _cache[key]!;
    final padded = id.toString().padLeft(2, '0');
    final jsonStr = await rootBundle.loadString('assets/configs/levels/$padded.json');
    final cfg = _parse(jsonStr);
    _cache[key] = cfg;
    return cfg;
  }

  static Future<LevelConfig> loadEndless() async {
    const key = 'endless';
    if (_cache.containsKey(key)) return _cache[key]!;
    final jsonStr = await rootBundle.loadString('assets/configs/endless_map.json');
    final cfg = _parse(jsonStr);
    _cache[key] = cfg;
    return cfg;
  }

  static LevelConfig _parse(String jsonStr) {
    final raw = json.decode(jsonStr) as Map<String, dynamic>;
    final gridRaw = raw['grid'] as Map<String, dynamic>;
    final grid = Grid(
      cols: gridRaw['cols'] as int,
      rows: gridRaw['rows'] as int,
      cellSize: (gridRaw['cellSize'] as num).toDouble(),
    );
    final pathPoints = (raw['pathCells'] as List)
        .map((c) {
          final list = c as List;
          final off = grid.cellCenter(list[0] as int, list[1] as int);
          return Vector2(off.dx, off.dy);
        })
        .toList();
    final waves = ((raw['waves'] ?? const []) as List)
        .map((w) => _parseWave((w as Map<String, dynamic>)['spawns'] as List))
        .toList();
    return LevelConfig(
      id: raw['id'].toString(),
      name: raw['name'] as String,
      grid: grid,
      pathPoints: pathPoints,
      startingLives: raw['startingLives'] as int,
      startingGold: raw['startingGold'] as int,
      passiveIncomePerWave: (raw['passiveIncomePerWave'] as num).toDouble(),
      passiveIncomePerWaveGrowth: (raw['passiveIncomePerWaveGrowth'] as num).toDouble(),
      waves: waves,
    );
  }

  static List<EnemySpawn> _parseWave(List spawns) {
    final out = <EnemySpawn>[];
    for (final s in spawns) {
      final spec = s as Map<String, dynamic>;
      final type = spec['type'] as String;
      if (type == 'interleave') {
        final grunt = spec['grunt'] as int;
        final fast = spec['fast'] as int;
        final gap = (spec['gap'] as num).toDouble();
        var t = 0.0;
        var gi = 0, fi = 0;
        while (gi < grunt || fi < fast) {
          if (gi < grunt) {
            out.add(EnemySpawn(type: EnemyType.grunt, atSec: t));
            gi++;
            t += gap;
          }
          if (fi < fast) {
            out.add(EnemySpawn(type: EnemyType.fast, atSec: t));
            fi++;
            t += gap * 0.6;
          }
        }
        continue;
      }
      final count = spec['count'] as int;
      final gap = (spec['gap'] as num).toDouble();
      final after = (spec['after'] as num?)?.toDouble() ?? 0;
      final enemyType = _enemyTypeFromString(type);
      for (var i = 0; i < count; i++) {
        out.add(EnemySpawn(type: enemyType, atSec: after + i * gap));
      }
    }
    return out;
  }

  static EnemyType _enemyTypeFromString(String s) {
    switch (s) {
      case 'grunt':
        return EnemyType.grunt;
      case 'fast':
        return EnemyType.fast;
      case 'tank':
        return EnemyType.tank;
      case 'swarm':
        return EnemyType.swarm;
      case 'boss':
        return EnemyType.boss;
      default:
        throw ArgumentError('Unknown enemy type: $s');
    }
  }
}
```

### Step 5: Run tests

```
flutter test test/level_loader_test.dart
```
Expected: all 6 tests pass.

If `closeTo` mismatches happen on the wave-6 interleave order, the test asserts only that the FIRST spawn is grunt and counts match. Adjust the test, not the parser, only if it materially diverges from intent.

### Step 6: Commit

```
git add lib/data/level_config.dart lib/data/level_loader.dart test/level_loader_test.dart
git commit -m "feat(data): LevelConfig model + LevelLoader for JSON-based levels"
```

---

## Task 3: Rewire TdGame to load LevelConfig instead of LevelOneConfig

**Files:**
- Modify: `c:\dev\void_td\lib\game\td_game.dart`
- Delete: `c:\dev\void_td\lib\data\level_one_config.dart`

`TdGame` becomes async-aware: instead of reading static `LevelOneConfig` fields, `onLoad` first awaits `LevelLoader.loadCampaignLevel(levelId)` (or `loadEndless()` for `levelId == 0` / Endless mode) and then sets up the world. Endless mode wave generation is a separate concern (Task 5) — for now, treat Endless as "no waves" (which lets the level skeleton be tested in isolation).

### Step 1: Replace `td_game.dart`

Replace the entire file. The diffs are surgical — only the wave/config-reading bits change. Full new content:

```dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../data/enemies_config.dart';
import '../data/level_config.dart';
import '../data/level_loader.dart';
import '../data/towers_config.dart';
import 'components/cell_highlight.dart';
import 'components/enemy.dart';
import 'components/farm.dart';
import 'components/gold_popup.dart';
import 'components/range_indicator.dart';
import 'components/tower.dart';
import 'grid/grid_painter.dart';
import 'match/match_state.dart';
import 'path/path_renderer.dart';
import 'path/path_segment.dart';
import 'waves/wave_runner.dart';

class TdGame extends FlameGame with DragCallbacks {
  /// Campaign level id (1..N) or 0 for Endless.
  final int levelId;
  final bool isEndless;

  TdGame({this.levelId = 1, this.isEndless = false});

  // Resolved config (loaded in onLoad).
  late LevelConfig _config;
  LevelConfig get config => _config;

  // World setup
  late final PathSegment path;
  late PositionComponent _world;
  late Vector2 _gridOrigin;

  // Match state
  final ValueNotifier<MatchState> stateNotifier =
      ValueNotifier(MatchState(lives: 20, gold: 0));
  MatchState get state => stateNotifier.value;

  // UI selection signals
  final ValueNotifier<TowerType?> paletteSelection = ValueNotifier(null);
  final ValueNotifier<Object?> selectedTower = ValueNotifier(null);

  // Match-end signal: null = ongoing, true = victory, false = defeat.
  final ValueNotifier<bool?> matchOutcome = ValueNotifier(null);

  // Wave control
  late List<List<EnemySpawn>> _waves;
  int _currentWaveIndex = 0;
  WaveRunner? _waveRunner;
  bool _isWaveActive = false;
  double _interWaveDelay = 0;

  // Live enemies & placed
  final List<Enemy> liveEnemies = [];
  final Map<(int, int), Object> _placed = {};
  final Map<Object, int> _totalSpent = {};

  double _farmTickAccumulator = 0;

  // Drag preview (pre-mounted so they render during pause via stepEngine)
  late final CellHighlight _previewHighlight;
  late final RangeIndicator _previewRange;
  late final RangeIndicator _previewSplashRange;
  (int, int)? _previewCell;
  RangeIndicator? _selectionRange;

  TowerType? _externalDragType;

  // Time-scale (for 1×/2×/3× speed)
  double _timeScale = 1.0;
  void setSpeed(int sp) {
    _timeScale = sp.toDouble();
  }
  int get currentSpeed => _timeScale.round();

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    _config = isEndless
        ? await LevelLoader.loadEndless()
        : await LevelLoader.loadCampaignLevel(levelId);
    _waves = _config.waves;

    // Initialise match state with config values.
    stateNotifier.value = MatchState(
      lives: _config.startingLives,
      gold: _config.startingGold,
    );

    final grid = _config.grid;
    path = PathSegment(points: _config.pathPoints);

    final offsetX = (size.x - grid.width) / 2;
    final offsetY = 30.0;
    _world = PositionComponent(position: Vector2(offsetX, offsetY));
    add(_world);
    _world.add(GridPainter(grid: grid));
    _world.add(PathRenderer(path: path));
    _gridOrigin = Vector2(offsetX, offsetY);

    _previewHighlight = CellHighlight(
      worldPos: Vector2.zero(),
      cellSize: grid.cellSize,
      visible: false,
    );
    _previewRange = RangeIndicator(worldPos: Vector2.zero(), radius: 0, visible: false);
    _previewSplashRange = RangeIndicator(
      worldPos: Vector2.zero(),
      radius: 0,
      color: AppColors.magenta,
      visible: false,
    );
    _world.add(_previewHighlight);
    _world.add(_previewRange);
    _world.add(_previewSplashRange);

    _startNextWave();
    _emitState();
  }

  void _startNextWave() {
    if (_currentWaveIndex >= _waves.length && !isEndless) {
      // Victory: ran out of waves.
      if (matchOutcome.value == null) {
        matchOutcome.value = true;
      }
      return;
    }
    state.nextWave();
    state.applyPassiveIncome(
      baseGold: _config.passiveIncomePerWave,
      growthPerWave: _config.passiveIncomePerWaveGrowth,
    );
    final spec = isEndless
        ? _generateEndlessWave(state.currentWave)
        : _waves[_currentWaveIndex];
    _waveRunner = WaveRunner(spec: spec);
    _isWaveActive = true;
    _emitState();
  }

  /// Procedural Endless wave generator. Wave N has rising counts and scaling
  /// composition: Tank from wave 5, mini-boss every 10. Stage 2b uses simple
  /// linear scaling; Stage 5 can do fancier tuning.
  List<EnemySpawn> _generateEndlessWave(int wave) {
    final out = <EnemySpawn>[];
    final grunts = 5 + wave;
    final fasts = wave >= 3 ? 2 + wave ~/ 2 : 0;
    final tanks = wave >= 5 ? 1 + wave ~/ 4 : 0;
    final swarms = wave >= 4 ? wave * 2 : 0;
    final bosses = wave >= 10 && wave % 10 == 0 ? 1 : 0;
    var t = 0.0;
    final gap = (1.0 - wave * 0.03).clamp(0.3, 1.2);
    for (var i = 0; i < grunts; i++) {
      out.add(EnemySpawn(type: EnemyType.grunt, atSec: t));
      t += gap;
    }
    for (var i = 0; i < fasts; i++) {
      out.add(EnemySpawn(type: EnemyType.fast, atSec: t));
      t += gap * 0.6;
    }
    for (var i = 0; i < tanks; i++) {
      out.add(EnemySpawn(type: EnemyType.tank, atSec: t));
      t += 2.0;
    }
    for (var i = 0; i < swarms; i++) {
      out.add(EnemySpawn(type: EnemyType.swarm, atSec: t));
      t += 0.25;
    }
    for (var i = 0; i < bosses; i++) {
      out.add(EnemySpawn(type: EnemyType.boss, atSec: t));
      t += 3.0;
    }
    return out;
  }

  @override
  void update(double dt) {
    final scaled = dt * _timeScale;
    super.update(scaled);
    if (state.isGameOver) {
      if (matchOutcome.value == null) {
        matchOutcome.value = false;
      }
      return;
    }
    if (matchOutcome.value != null) return;

    if (_isWaveActive && _waveRunner != null) {
      final spawns = _waveRunner!.tick(scaled);
      for (final type in spawns) _spawnEnemy(type);
      if (_waveRunner!.isDone && liveEnemies.isEmpty) {
        _onWaveCleared();
      }
    } else if (_interWaveDelay > 0) {
      _interWaveDelay -= scaled;
      if (_interWaveDelay <= 0) {
        _currentWaveIndex++;
        _startNextWave();
      }
    }

    _farmTickAccumulator += scaled;
    while (_farmTickAccumulator >= 1.0) {
      _farmTickAccumulator -= 1.0;
      final total = _placed.values
          .whereType<Farm>()
          .fold<int>(0, (sum, f) => sum + f.goldPerSec);
      if (total > 0) {
        state.applyFarmTick(total);
        _emitState();
      }
    }

    liveEnemies.removeWhere((e) => e.isRemoved);
  }

  void _spawnEnemy(EnemyType type) {
    final enemy = Enemy(
      type: type,
      stats: EnemiesConfig.statsFor(type),
      path: path,
      onReachedEnd: _onEnemyReachedEnd,
      onKilled: _onEnemyKilled,
    );
    liveEnemies.add(enemy);
    _world.add(enemy);
  }

  void _onWaveCleared() {
    _isWaveActive = false;
    final bonus = state.applyCleanWaveBonus(baseBonus: 20, perWave: 2);
    if (bonus > 0) {
      final centre = _world.position +
          Vector2(_config.grid.width / 2, _config.grid.height / 2);
      add(GoldPopup(worldPos: centre, amount: bonus));
    }
    _interWaveDelay = 2.0;
    _emitState();
  }

  void _onEnemyReachedEnd(Enemy e) {
    state.takeDamage(e.stats.damageToBase);
    _emitState();
  }

  void _onEnemyKilled(Enemy e) {
    state.addGold(e.stats.bounty);
    _emitState();
  }

  int totalFarmIncome() => _placed.values
      .whereType<Farm>()
      .fold<int>(0, (sum, f) => sum + f.goldPerSec);

  // ---------- Drag / palette / selection / upgrade — UNCHANGED FROM STAGE 2A ----------
  // (Same methods as before. Copy them verbatim from current td_game.dart.)
  // Pasted below for completeness.

  Vector2? _dragStartLocal;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (state.isGameOver) return;
    _dragStartLocal = event.localPosition.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (state.isGameOver) {
      _dragStartLocal = null;
      return;
    }
    if (_dragStartLocal != null) {
      final local = (_dragStartLocal! - _gridOrigin);
      final grid = _config.grid;
      final (col, row) = grid.worldToCell(local.x, local.y);
      if (grid.contains(col, row) && _placed.containsKey((col, row))) {
        _selectExisting(col, row);
      } else {
        _clearSelection();
      }
    }
    _dragStartLocal = null;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragStartLocal = null;
  }

  void startExternalDrag(TowerType type, Vector2 localGamePos) {
    _externalDragType = type;
    _clearSelection();
    paletteSelection.value = type;
    _showPreviewExternalAt(localGamePos, type);
    _renderOneFrameIfPaused();
  }

  void updateExternalDrag(Vector2 localGamePos) {
    if (_externalDragType == null) return;
    _showPreviewExternalAt(localGamePos, _externalDragType!);
    _renderOneFrameIfPaused();
  }

  bool endExternalDrag(Vector2 localGamePos) {
    final type = _externalDragType;
    if (type != null) _showPreviewExternalAt(localGamePos, type);
    final cell = _previewCell;
    _externalDragType = null;
    _removePreview();
    if (type == null || cell == null || state.isGameOver) {
      paletteSelection.value = null;
      _renderOneFrameIfPaused();
      return false;
    }
    final (col, row) = cell;
    if (!_canBuildAt(col, row, type)) {
      paletteSelection.value = null;
      _renderOneFrameIfPaused();
      return false;
    }
    _placeAt(col, row, type);
    paletteSelection.value = null;
    return true;
  }

  void cancelExternalDrag() {
    _externalDragType = null;
    _removePreview();
    paletteSelection.value = null;
    _renderOneFrameIfPaused();
  }

  void _renderOneFrameIfPaused() {
    if (!paused) return;
    stepEngine(stepTime: 0);
  }

  void _showPreviewExternalAt(Vector2 localGamePos, TowerType type) {
    final local = localGamePos - _gridOrigin;
    final grid = _config.grid;
    final (col, row) = grid.worldToCell(local.x, local.y);
    if (!grid.contains(col, row)) {
      _removePreview();
      return;
    }
    _previewCell = (col, row);
    final centre = grid.cellCenter(col, row);
    final worldPos = Vector2(centre.dx, centre.dy);
    final mode = _canBuildAt(col, row, type)
        ? CellHighlightMode.buildable
        : CellHighlightMode.blocked;
    _previewHighlight.position = worldPos;
    _previewHighlight.mode = mode;
    _previewHighlight.visible = true;

    final stats = TowersConfig.statsFor(type, branchA: 0, branchB: 0);
    if (stats.range > 0) {
      _previewRange.position = worldPos;
      _previewRange.radius = stats.range;
      _previewRange.color = AppColors.cyan;
      _previewRange.visible = true;
    } else {
      _previewRange.visible = false;
    }

    if (type == TowerType.splash && stats.splashRadius > 0) {
      _previewSplashRange.position = worldPos;
      _previewSplashRange.radius = stats.splashRadius;
      _previewSplashRange.visible = true;
    } else {
      _previewSplashRange.visible = false;
    }
  }

  void _removePreview() {
    _previewHighlight.visible = false;
    _previewRange.visible = false;
    _previewSplashRange.visible = false;
    _previewCell = null;
  }

  int currentBuildCost(TowerType type) {
    if (type != TowerType.farm) return TowersConfig.baseCost(type);
    int best = TowersConfig.baseCost(TowerType.farm);
    for (final f in _placed.values.whereType<Farm>()) {
      final c = TowersConfig.statsFor(
        TowerType.farm,
        branchA: f.branchA,
        branchB: f.branchB,
      ).cost;
      if (c < best) best = c;
    }
    return best;
  }

  bool _canBuildAt(int col, int row, TowerType type) {
    if (_placed.containsKey((col, row))) return false;
    if (_isOnPath(col, row)) return false;
    final cost = currentBuildCost(type);
    if (state.gold < cost) return false;
    return true;
  }

  void _placeAt(int col, int row, TowerType type) {
    final cost = currentBuildCost(type);
    if (!state.spendGold(cost)) return;
    final grid = _config.grid;
    final centre = grid.cellCenter(col, row);
    final worldPos = Vector2(centre.dx, centre.dy);
    final Object placed;
    if (type == TowerType.farm) {
      final f = Farm(worldPos: worldPos);
      _world.add(f);
      placed = f;
    } else {
      final t = Tower(
        type: type,
        worldPos: worldPos,
        enemiesProvider: () => liveEnemies,
      );
      _world.add(t);
      placed = t;
    }
    _placed[(col, row)] = placed;
    _totalSpent[placed] = cost;
    _renderOneFrameIfPaused();
    _emitState();
  }

  void _selectExisting(int col, int row) {
    final obj = _placed[(col, row)];
    if (obj == null) return;
    _clearSelection();
    selectedTower.value = obj;
    Vector2 pos;
    double r;
    if (obj is Tower) {
      pos = obj.position;
      r = obj.range;
    } else if (obj is Farm) {
      pos = obj.position;
      r = 0;
    } else {
      return;
    }
    if (r > 0) {
      _selectionRange = RangeIndicator(
        worldPos: pos,
        radius: r,
        color: const Color(0xFFFFFFFF),
      );
      _world.add(_selectionRange!);
      _renderOneFrameIfPaused();
    }
  }

  void _clearSelection() {
    _selectionRange?.removeFromParent();
    _selectionRange = null;
    selectedTower.value = null;
  }

  bool upgradeSelected({required bool branchA}) {
    final obj = selectedTower.value;
    if (obj is Tower) return _upgradeTower(obj, branchA: branchA);
    if (obj is Farm) return _upgradeFarm(obj, branchA: branchA);
    return false;
  }

  bool _upgradeTower(Tower t, {required bool branchA}) {
    final type = t.type;
    final level = branchA ? t.branchA : t.branchB;
    if (level >= 5) return false;
    if (t.branchA + t.branchB >= 7) return false;
    final cost = TowersConfig.upgradeCost(type, currentLevel: level);
    if (!state.spendGold(cost)) return false;
    if (branchA) {
      t.branchA = level + 1;
    } else {
      t.branchB = level + 1;
    }
    _totalSpent[t] = (_totalSpent[t] ?? 0) + cost;
    _selectionRange?.removeFromParent();
    _selectionRange = RangeIndicator(
      worldPos: t.position,
      radius: t.range,
      color: const Color(0xFFFFFFFF),
    );
    _world.add(_selectionRange!);
    _renderOneFrameIfPaused();
    _emitState();
    return true;
  }

  bool _upgradeFarm(Farm f, {required bool branchA}) {
    final level = branchA ? f.branchA : f.branchB;
    if (level >= 5) return false;
    if (f.branchA + f.branchB >= 7) return false;
    final cost = TowersConfig.upgradeCost(TowerType.farm, currentLevel: level);
    if (!state.spendGold(cost)) return false;
    if (branchA) {
      f.branchA = level + 1;
    } else {
      f.branchB = level + 1;
    }
    _totalSpent[f] = (_totalSpent[f] ?? 0) + cost;
    _emitState();
    return true;
  }

  bool sellSelected() {
    final obj = selectedTower.value;
    if (obj == null) return false;
    final entry = _placed.entries.firstWhere((e) => e.value == obj);
    final refund = ((_totalSpent[obj] ?? 0) * 0.7).round();
    state.addGold(refund);
    _placed.remove(entry.key);
    _totalSpent.remove(obj);
    if (obj is PositionComponent) obj.removeFromParent();
    _clearSelection();
    _emitState();
    return true;
  }

  int totalSpentFor(Object obj) => _totalSpent[obj] ?? 0;

  bool _isOnPath(int col, int row) {
    final grid = _config.grid;
    final centre = grid.cellCenter(col, row);
    final c = Vector2(centre.dx, centre.dy);
    final threshold = grid.cellSize * 0.6;
    for (var i = 1; i < path.points.length; i++) {
      if (_pointToSegmentDistance(c, path.points[i - 1], path.points[i]) <
          threshold) return true;
    }
    return false;
  }

  double _pointToSegmentDistance(Vector2 p, Vector2 a, Vector2 b) {
    final ab = b - a;
    final ap = p - a;
    final ablen2 = ab.length2;
    if (ablen2 == 0) return ap.length;
    final t = (ap.dot(ab) / ablen2).clamp(0.0, 1.0);
    final closest = a + ab * t;
    return (p - closest).length;
  }

  void _emitState() {
    final snap = MatchState(lives: state.lives, gold: state.gold);
    for (var i = 0; i < state.currentWave; i++) {
      snap.nextWave();
    }
    snap.cleanWavesCount = state.cleanWavesCount;
    snap.livesLostThisWave = state.livesLostThisWave;
    stateNotifier.value = snap;
  }
}
```

### Step 2: Delete `level_one_config.dart`

```
del lib\data\level_one_config.dart
```
(Or via `git rm` to track in the commit.)

### Step 3: Verify

```
flutter analyze
```
Expected: errors only in `game_screen.dart` (still imports `LevelOneConfig` if there were leftover refs — should be none, since GameScreen takes a `levelId` parameter that we pass to `TdGame`). Resolve by removing the stale import if present.

Run tests:
```
flutter test
```
The `widget_test.dart` should still pass (it only verifies the main menu's title text). All other tests independent.

### Step 4: Commit

```
git add lib/game/td_game.dart
git rm lib/data/level_one_config.dart
git commit -m "feat(game): TdGame reads LevelConfig via LevelLoader; supports Endless"
```

---

## Task 4: Stars helper + tests

**Files:**
- Create: `c:\dev\void_td\lib\meta\progress\stars.dart`
- Create: `c:\dev\void_td\test\stars_test.dart`

### Step 1: Write failing test

Create `test\stars_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/meta/progress/stars.dart';

void main() {
  group('starsForResult', () {
    test('0 lives lost = 3 stars', () {
      expect(starsForResult(livesLost: 0), 3);
    });
    test('1 life lost = 2 stars', () {
      expect(starsForResult(livesLost: 1), 2);
    });
    test('6 lives lost = 2 stars (boundary)', () {
      expect(starsForResult(livesLost: 6), 2);
    });
    test('7 lives lost = 1 star', () {
      expect(starsForResult(livesLost: 7), 1);
    });
    test('passing with any losses still gives 1 star', () {
      expect(starsForResult(livesLost: 19), 1);
    });
  });
}
```

### Step 2: Implement

Create `lib\meta\progress\stars.dart`:
```dart
/// 3 stars: no lives lost. 2 stars: 1–6 lost. 1 star: passed with any loss.
/// Caller verifies the level was actually completed (lives > 0 at end).
int starsForResult({required int livesLost}) {
  if (livesLost == 0) return 3;
  if (livesLost <= 6) return 2;
  return 1;
}
```

### Step 3: Verify

```
flutter test test/stars_test.dart
```
Expected: 5 tests pass.

### Step 4: Commit

```
git add lib/meta/progress/stars.dart test/stars_test.dart
git commit -m "feat(meta): stars helper for level results"
```

---

## Task 5: PlayerProfile + Hive integration

**Files:**
- Modify: `c:\dev\void_td\pubspec.yaml`
- Create: `c:\dev\void_td\lib\meta\profile\player_profile.dart`
- Create: `c:\dev\void_td\lib\meta\profile\profile_repo.dart`

`PlayerProfile` holds: per-level stars (`Map<int,int>`), highest endless wave, settings (audio, haptic). For Stage 2b we only use the stars and endless record fields.

### Step 1: Add hive_generator + build_runner dev deps

In `pubspec.yaml`, in `dev_dependencies:`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  hive_generator: ^2.0.1
  build_runner: ^2.4.13
```

Run:
```
flutter pub get
```

### Step 2: Create `player_profile.dart`

```dart
import 'package:hive/hive.dart';

part 'player_profile.g.dart';

@HiveType(typeId: 1)
class PlayerProfile extends HiveObject {
  /// Map of campaign levelId → stars earned (0 if not played, 1..3 if played).
  @HiveField(0)
  Map<int, int> levelStars;

  /// Highest cleared wave in Endless.
  @HiveField(1)
  int endlessHighestWave;

  PlayerProfile({
    Map<int, int>? levelStars,
    this.endlessHighestWave = 0,
  }) : levelStars = levelStars ?? {};

  /// Highest level the player has reached (1 + max(levelStars.keys)).
  /// Any level with stars >= 1 unlocks the next.
  int get highestUnlockedLevel {
    int unlocked = 1;
    levelStars.forEach((id, stars) {
      if (stars >= 1 && id + 1 > unlocked) unlocked = id + 1;
    });
    return unlocked;
  }

  bool isLevelUnlocked(int id) => id <= highestUnlockedLevel;

  /// Save the result of a played level. Keeps the best star count.
  void recordLevelResult(int levelId, int stars) {
    final existing = levelStars[levelId] ?? 0;
    if (stars > existing) levelStars[levelId] = stars;
  }
}
```

### Step 3: Create `profile_repo.dart`

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'player_profile.dart';

class ProfileRepo {
  static const _boxName = 'profile';
  static const _key = 'main';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PlayerProfileAdapter());
    }
    await Hive.openBox<PlayerProfile>(_boxName);
  }

  static PlayerProfile load() {
    final box = Hive.box<PlayerProfile>(_boxName);
    var profile = box.get(_key);
    if (profile == null) {
      profile = PlayerProfile();
      box.put(_key, profile);
    }
    return profile;
  }

  static Future<void> save(PlayerProfile p) async {
    final box = Hive.box<PlayerProfile>(_boxName);
    await box.put(_key, p);
  }
}
```

### Step 4: Generate the Hive adapter

```
flutter pub run build_runner build --delete-conflicting-outputs
```

This creates `lib/meta/profile/player_profile.g.dart`. Verify it exists and contains `PlayerProfileAdapter`.

### Step 5: Verify

```
flutter analyze
```
Expected: no issues.

### Step 6: Commit

```
git add pubspec.yaml pubspec.lock lib/meta/profile/
git commit -m "feat(meta): PlayerProfile + Hive integration"
```

---

## Task 6: MatchSnapshot (save/resume) + tests

**Files:**
- Create: `c:\dev\void_td\lib\game\match\match_snapshot.dart`
- Create: `c:\dev\void_td\test\match_snapshot_test.dart`

`MatchSnapshot` is a serialisable image of an in-flight match. It's a Hive object (typeId 2). On lifecycle pause / Pause button, we capture and save it. On main menu launch, we check whether one exists.

### Step 1: Write failing test (round-trip + readback)

Create `test\match_snapshot_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/data/towers_config.dart';
import 'package:void_td/game/match/match_snapshot.dart';

void main() {
  group('MatchSnapshot', () {
    test('round-trip preserves all fields', () {
      final snap = MatchSnapshot(
        levelId: 2,
        isEndless: false,
        lives: 18,
        gold: 145,
        currentWave: 3,
        cleanWavesCount: 1,
        towers: [
          PlacedTowerSnapshot(
            type: TowerType.basic,
            col: 3,
            row: 4,
            branchA: 2,
            branchB: 1,
            totalSpent: 130,
          ),
          PlacedTowerSnapshot(
            type: TowerType.farm,
            col: 5,
            row: 5,
            branchA: 0,
            branchB: 0,
            totalSpent: 60,
          ),
        ],
        interWaveDelaySec: 1.2,
        isWaveActive: true,
        currentWaveElapsedSec: 4.3,
      );
      final raw = snap.toMap();
      final restored = MatchSnapshot.fromMap(raw);
      expect(restored.levelId, 2);
      expect(restored.lives, 18);
      expect(restored.gold, 145);
      expect(restored.towers.length, 2);
      expect(restored.towers[0].type, TowerType.basic);
      expect(restored.towers[1].type, TowerType.farm);
      expect(restored.towers[0].branchA, 2);
      expect(restored.interWaveDelaySec, closeTo(1.2, 0.001));
      expect(restored.currentWaveElapsedSec, closeTo(4.3, 0.001));
    });

    test('endless snapshot stores isEndless = true', () {
      final snap = MatchSnapshot(
        levelId: 0,
        isEndless: true,
        lives: 20,
        gold: 100,
        currentWave: 15,
        cleanWavesCount: 3,
        towers: [],
        interWaveDelaySec: 0,
        isWaveActive: false,
        currentWaveElapsedSec: 0,
      );
      final raw = snap.toMap();
      final restored = MatchSnapshot.fromMap(raw);
      expect(restored.isEndless, isTrue);
      expect(restored.currentWave, 15);
    });
  });
}
```

### Step 2: Implement

Create `lib\game\match\match_snapshot.dart`:
```dart
import '../../data/towers_config.dart';

/// Lightweight JSON-friendly snapshot of an in-flight match.
/// Stored under a fixed Hive key — at most one snapshot exists at a time.
///
/// We do NOT use Hive type adapters here — instead we store a Map<String,dynamic>
/// in a generic `Hive.box('saved_match')`. That avoids needing another adapter
/// codegen pass for the nested PlacedTowerSnapshot list.
class MatchSnapshot {
  final int levelId;
  final bool isEndless;
  final int lives;
  final int gold;
  final int currentWave;
  final int cleanWavesCount;
  final List<PlacedTowerSnapshot> towers;
  final double interWaveDelaySec;
  final bool isWaveActive;
  final double currentWaveElapsedSec;

  MatchSnapshot({
    required this.levelId,
    required this.isEndless,
    required this.lives,
    required this.gold,
    required this.currentWave,
    required this.cleanWavesCount,
    required this.towers,
    required this.interWaveDelaySec,
    required this.isWaveActive,
    required this.currentWaveElapsedSec,
  });

  Map<String, dynamic> toMap() => {
        'levelId': levelId,
        'isEndless': isEndless,
        'lives': lives,
        'gold': gold,
        'currentWave': currentWave,
        'cleanWavesCount': cleanWavesCount,
        'towers': towers.map((t) => t.toMap()).toList(),
        'interWaveDelaySec': interWaveDelaySec,
        'isWaveActive': isWaveActive,
        'currentWaveElapsedSec': currentWaveElapsedSec,
      };

  static MatchSnapshot fromMap(Map raw) {
    final m = Map<String, dynamic>.from(raw);
    return MatchSnapshot(
      levelId: m['levelId'] as int,
      isEndless: m['isEndless'] as bool,
      lives: m['lives'] as int,
      gold: m['gold'] as int,
      currentWave: m['currentWave'] as int,
      cleanWavesCount: m['cleanWavesCount'] as int,
      towers: (m['towers'] as List)
          .map((t) => PlacedTowerSnapshot.fromMap(t as Map))
          .toList(),
      interWaveDelaySec: (m['interWaveDelaySec'] as num).toDouble(),
      isWaveActive: m['isWaveActive'] as bool,
      currentWaveElapsedSec: (m['currentWaveElapsedSec'] as num).toDouble(),
    );
  }
}

class PlacedTowerSnapshot {
  final TowerType type;
  final int col;
  final int row;
  final int branchA;
  final int branchB;
  final int totalSpent;

  PlacedTowerSnapshot({
    required this.type,
    required this.col,
    required this.row,
    required this.branchA,
    required this.branchB,
    required this.totalSpent,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'col': col,
        'row': row,
        'branchA': branchA,
        'branchB': branchB,
        'totalSpent': totalSpent,
      };

  static PlacedTowerSnapshot fromMap(Map raw) {
    final m = Map<String, dynamic>.from(raw);
    return PlacedTowerSnapshot(
      type: TowerType.values.firstWhere((t) => t.name == m['type']),
      col: m['col'] as int,
      row: m['row'] as int,
      branchA: m['branchA'] as int,
      branchB: m['branchB'] as int,
      totalSpent: m['totalSpent'] as int,
    );
  }
}
```

### Step 3: Verify

```
flutter test test/match_snapshot_test.dart
```
Expected: 2 tests pass.

### Step 4: Commit

```
git add lib/game/match/match_snapshot.dart test/match_snapshot_test.dart
git commit -m "feat(game): MatchSnapshot for save/resume"
```

---

## Task 7: SnapshotRepo + TdGame snapshot/restore

**Files:**
- Create: `c:\dev\void_td\lib\game\match\snapshot_repo.dart`
- Modify: `c:\dev\void_td\lib\game\td_game.dart`

### Step 1: Create `snapshot_repo.dart`

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'match_snapshot.dart';

class SnapshotRepo {
  static const _boxName = 'saved_match';
  static const _key = 'current';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static MatchSnapshot? load() {
    final box = Hive.box(_boxName);
    final raw = box.get(_key);
    if (raw == null) return null;
    return MatchSnapshot.fromMap(raw as Map);
  }

  static Future<void> save(MatchSnapshot snap) async {
    final box = Hive.box(_boxName);
    await box.put(_key, snap.toMap());
  }

  static Future<void> clear() async {
    final box = Hive.box(_boxName);
    await box.delete(_key);
  }

  static bool exists() {
    final box = Hive.box(_boxName);
    return box.get(_key) != null;
  }
}
```

### Step 2: Add `takeSnapshot()` to `TdGame`

In `td_game.dart`, add a method that captures current state:

```dart
MatchSnapshot takeSnapshot() {
  // We need to know each placed object's cell. The _placed map keys are (col,row).
  final towers = <PlacedTowerSnapshot>[];
  _placed.forEach((cell, obj) {
    final (col, row) = cell;
    if (obj is Tower) {
      towers.add(PlacedTowerSnapshot(
        type: obj.type,
        col: col,
        row: row,
        branchA: obj.branchA,
        branchB: obj.branchB,
        totalSpent: _totalSpent[obj] ?? 0,
      ));
    } else if (obj is Farm) {
      towers.add(PlacedTowerSnapshot(
        type: TowerType.farm,
        col: col,
        row: row,
        branchA: obj.branchA,
        branchB: obj.branchB,
        totalSpent: _totalSpent[obj] ?? 0,
      ));
    }
  });
  return MatchSnapshot(
    levelId: levelId,
    isEndless: isEndless,
    lives: state.lives,
    gold: state.gold,
    currentWave: state.currentWave,
    cleanWavesCount: state.cleanWavesCount,
    towers: towers,
    interWaveDelaySec: _interWaveDelay,
    isWaveActive: _isWaveActive,
    currentWaveElapsedSec: 0, // re-derived on restore; see note below
  );
}
```

Imports to add at the top of `td_game.dart`:
```dart
import 'match/match_snapshot.dart';
```

> **Restore-fidelity note for Stage 2b:** we don't restore the WaveRunner's exact `_elapsed` (Flame `WaveRunner` doesn't expose it, and tracking it externally adds plumbing). Acceptable behaviour for MVP: on restore, the current wave **restarts from t=0** but the wave index, lives, gold, and tower layout are preserved. From a player POV they "lose progress within the wave" but the strategic state is identical. We document this and revisit in Stage 5 if needed.

Add a `restoreFromSnapshot(MatchSnapshot snap)` method that hydrates fields after `onLoad`:

```dart
Future<void> restoreFromSnapshot(MatchSnapshot snap) async {
  // Pre-condition: onLoad has completed and we're on the same levelId/mode.
  // Set match state.
  stateNotifier.value = MatchState(lives: snap.lives, gold: snap.gold);
  for (var i = 0; i < snap.currentWave; i++) state.nextWave();
  state.cleanWavesCount = snap.cleanWavesCount;

  // Wave runner: jump _currentWaveIndex back so the next _startNextWave matches.
  _currentWaveIndex = snap.currentWave > 0 ? snap.currentWave - 1 : 0;
  // Cancel the wave that onLoad started — it was the wrong index.
  _waveRunner = null;
  _isWaveActive = false;

  // Restart the correct wave.
  if (!snap.isEndless && _currentWaveIndex >= _waves.length) {
    matchOutcome.value = true;
    _emitState();
    return;
  }
  final spec = isEndless
      ? _generateEndlessWave(state.currentWave)
      : _waves[_currentWaveIndex];
  _waveRunner = WaveRunner(spec: spec);
  _isWaveActive = snap.isWaveActive;
  _interWaveDelay = snap.interWaveDelaySec;

  // Restore placed towers and farms.
  final grid = _config.grid;
  for (final t in snap.towers) {
    final centre = grid.cellCenter(t.col, t.row);
    final worldPos = Vector2(centre.dx, centre.dy);
    final Object placed;
    if (t.type == TowerType.farm) {
      final f = Farm(
        worldPos: worldPos,
        branchA: t.branchA,
        branchB: t.branchB,
      );
      _world.add(f);
      placed = f;
    } else {
      final tw = Tower(
        type: t.type,
        worldPos: worldPos,
        enemiesProvider: () => liveEnemies,
        branchA: t.branchA,
        branchB: t.branchB,
      );
      _world.add(tw);
      placed = tw;
    }
    _placed[(t.col, t.row)] = placed;
    _totalSpent[placed] = t.totalSpent;
  }
  _renderOneFrameIfPaused();
  _emitState();
}
```

### Step 3: Verify

```
flutter analyze
flutter test
```
Expected: no issues. Tests still pass.

### Step 4: Commit

```
git add lib/game/match/snapshot_repo.dart lib/game/td_game.dart
git commit -m "feat(game): SnapshotRepo + TdGame takeSnapshot/restoreFromSnapshot"
```

---

## Task 8: Initialize Hive in app startup

**Files:**
- Modify: `c:\dev\void_td\lib\app.dart`
- Modify: `c:\dev\void_td\lib\main.dart`

### Step 1: Initialise Hive boxes before runApp

In `main.dart`, change:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'meta/profile/profile_repo.dart';
import 'game/match/snapshot_repo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await ProfileRepo.init();
  await SnapshotRepo.init();
  runApp(const ProviderScope(child: VoidApp()));
}
```

### Step 2: Verify

```
flutter analyze
flutter run --debug -d <your-device>
```
The app should launch as before; nothing visibly changes yet — Task 9 wires the menu.

(Skip `flutter run` for the subagent — just analyze + tests.)

### Step 3: Commit

```
git add lib/main.dart
git commit -m "chore: initialise Hive boxes before runApp"
```

---

## Task 9: Main menu — CAMPAIGN / ENDLESS / SETTINGS + CONTINUE

**Files:**
- Modify: `c:\dev\void_td\lib\ui\main_menu\main_menu_screen.dart`
- Create: `c:\dev\void_td\lib\ui\level_select\level_select_screen.dart`

### Step 1: Replace main menu

Replace `lib\ui\main_menu\main_menu_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';
import '../../game/game_screen.dart';
import '../../game/match/snapshot_repo.dart';
import '../level_select/level_select_screen.dart';
import '../shared/neon_button.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});
  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          'EXIT VOID TD?',
          style: TextStyle(
            color: AppColors.cyan,
            fontSize: 18,
            letterSpacing: 4,
            shadows: [Shadow(color: AppColors.cyan.withValues(alpha: 0.6), blurRadius: 8)],
          ),
        ),
        content: const Text(
          'Do you really want to close the app?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.textSecondary, letterSpacing: 2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('EXIT',
                style: TextStyle(
                  color: AppColors.red,
                  letterSpacing: 2,
                  shadows: [Shadow(color: AppColors.red.withValues(alpha: 0.6), blurRadius: 6)],
                )),
          ),
        ],
      ),
    );
    if (shouldExit == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasSaved = SnapshotRepo.exists();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'VOID',
                  style: TextStyle(
                    color: AppColors.cyan,
                    fontSize: 64,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 16,
                    shadows: [Shadow(color: AppColors.cyan.withValues(alpha: 0.6), blurRadius: 16)],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'TD',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 64),
                if (hasSaved) ...[
                  NeonButton(
                    label: 'CONTINUE',
                    color: AppColors.green,
                    onPressed: () async {
                      final snap = SnapshotRepo.load();
                      if (snap == null || !mounted) return;
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GameScreen(
                          levelId: snap.isEndless ? 0 : snap.levelId,
                          isEndless: snap.isEndless,
                          restoreFromSavedSnapshot: true,
                        ),
                      ));
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                NeonButton(
                  label: 'CAMPAIGN',
                  color: AppColors.cyan,
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const LevelSelectScreen(),
                    ));
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                NeonButton(
                  label: 'ENDLESS',
                  color: AppColors.magenta,
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const GameScreen(
                        levelId: 0,
                        isEndless: true,
                      ),
                    ));
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                NeonButton(
                  label: 'SETTINGS',
                  color: AppColors.purple,
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

(Note: `GameScreen` needs new parameters `isEndless` and `restoreFromSavedSnapshot`. Task 10 adds them.)

### Step 2: Create Level Select

Create `lib\ui\level_select\level_select_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../game/game_screen.dart';
import '../../meta/profile/profile_repo.dart';
import '../shared/neon_button.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});
  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  static const _totalLevels = 3;

  @override
  Widget build(BuildContext context) {
    final profile = ProfileRepo.load();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'CAMPAIGN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.cyan,
                  fontSize: 22,
                  letterSpacing: 6,
                  shadows: [Shadow(color: AppColors.cyan.withValues(alpha: 0.6), blurRadius: 8)],
                ),
              ),
              const SizedBox(height: 32),
              ...List.generate(_totalLevels, (i) {
                final id = i + 1;
                final unlocked = profile.isLevelUnlocked(id);
                final stars = profile.levelStars[id] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _LevelTile(
                    id: id,
                    unlocked: unlocked,
                    stars: stars,
                    onTap: unlocked
                        ? () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => GameScreen(levelId: id),
                            ));
                            if (mounted) setState(() {});
                          }
                        : null,
                  ),
                );
              }),
              const Spacer(),
              NeonButton(
                label: 'BACK',
                color: AppColors.textSecondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int id;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.id,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? AppColors.cyan : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(6),
          boxShadow: unlocked
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL $id',
              style: TextStyle(
                color: color,
                fontSize: 16,
                letterSpacing: 4,
                fontFamily: 'monospace',
                shadows: unlocked
                    ? [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]
                    : null,
              ),
            ),
            Row(
              children: List.generate(3, (i) {
                final filled = i < stars;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: filled ? AppColors.yellow : AppColors.textMuted,
                    size: 18,
                    shadows: filled
                        ? [Shadow(color: AppColors.yellow.withValues(alpha: 0.6), blurRadius: 6)]
                        : null,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 3: Verify

```
flutter analyze
```
Expected: errors only in `game_screen.dart` until Task 10 (new params `isEndless`, `restoreFromSavedSnapshot`).

### Step 4: Commit (after Task 10's wiring, to keep `analyze` clean — for now leave uncommitted)

We'll batch this with Task 10 since they're tied.

---

## Task 10: GameScreen — isEndless, restore from snapshot, Victory/Defeat

**Files:**
- Modify: `c:\dev\void_td\lib\game\game_screen.dart`
- Create: `c:\dev\void_td\lib\ui\match\victory_dialog.dart`
- Create: `c:\dev\void_td\lib\ui\match\defeat_dialog.dart`

### Step 1: Create Victory dialog

`lib\ui\match\victory_dialog.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class VictoryDialog extends StatelessWidget {
  final int stars;
  final int livesRemaining;
  final VoidCallback onRetry;
  final VoidCallback onQuit;
  final VoidCallback? onNext;

  const VictoryDialog({
    super.key,
    required this.stars,
    required this.livesRemaining,
    required this.onRetry,
    required this.onQuit,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.green, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      title: Text(
        'VICTORY',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.green,
          fontSize: 22,
          letterSpacing: 6,
          shadows: [Shadow(color: AppColors.green.withValues(alpha: 0.6), blurRadius: 8)],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i < stars;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: filled ? AppColors.yellow : AppColors.textMuted,
                  size: 32,
                  shadows: filled
                      ? [Shadow(color: AppColors.yellow.withValues(alpha: 0.6), blurRadius: 8)]
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            'LIVES REMAINING  $livesRemaining',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: onQuit,
          child: const Text('QUIT', style: TextStyle(color: AppColors.textSecondary, letterSpacing: 2)),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('RETRY',
              style: TextStyle(
                color: AppColors.yellow,
                letterSpacing: 2,
                shadows: [Shadow(color: AppColors.yellow.withValues(alpha: 0.6), blurRadius: 6)],
              )),
        ),
        if (onNext != null)
          TextButton(
            onPressed: onNext,
            child: Text('NEXT',
                style: TextStyle(
                  color: AppColors.cyan,
                  letterSpacing: 2,
                  shadows: [Shadow(color: AppColors.cyan.withValues(alpha: 0.6), blurRadius: 6)],
                )),
          ),
      ],
    );
  }
}
```

### Step 2: Create Defeat dialog

`lib\ui\match\defeat_dialog.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class DefeatDialog extends StatelessWidget {
  final int wavesReached;
  final bool isEndless;
  final int? endlessHighScore;
  final VoidCallback onRetry;
  final VoidCallback onQuit;

  const DefeatDialog({
    super.key,
    required this.wavesReached,
    required this.isEndless,
    required this.endlessHighScore,
    required this.onRetry,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.red, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      title: Text(
        'DEFEAT',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.red,
          fontSize: 22,
          letterSpacing: 6,
          shadows: [Shadow(color: AppColors.red.withValues(alpha: 0.6), blurRadius: 8)],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEndless) ...[
            Text(
              'WAVES SURVIVED',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$wavesReached',
              style: TextStyle(
                color: AppColors.cyan,
                fontSize: 32,
                fontFamily: 'monospace',
                shadows: [Shadow(color: AppColors.cyan.withValues(alpha: 0.6), blurRadius: 8)],
              ),
            ),
            if (endlessHighScore != null) ...[
              const SizedBox(height: 12),
              Text(
                'BEST  $endlessHighScore',
                style: const TextStyle(
                  color: AppColors.yellow,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ] else
            const Text(
              'The base has fallen.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: onQuit,
          child: const Text('QUIT', style: TextStyle(color: AppColors.textSecondary, letterSpacing: 2)),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('RETRY',
              style: TextStyle(
                color: AppColors.yellow,
                letterSpacing: 2,
                shadows: [Shadow(color: AppColors.yellow.withValues(alpha: 0.6), blurRadius: 6)],
              )),
        ),
      ],
    );
  }
}
```

### Step 3: Update `GameScreen`

Replace `lib\game\game_screen.dart`:
```dart
import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../data/towers_config.dart';
import '../meta/profile/player_profile.dart';
import '../meta/profile/profile_repo.dart';
import '../meta/progress/stars.dart';
import '../ui/match/defeat_dialog.dart';
import '../ui/match/speed_bar.dart';
import '../ui/match/tower_palette.dart';
import '../ui/match/tower_upgrade_panel.dart';
import '../ui/match/victory_dialog.dart';
import 'components/farm.dart';
import 'components/tower.dart';
import 'match/hud.dart';
import 'match/snapshot_repo.dart';
import 'td_game.dart';

class GameScreen extends StatefulWidget {
  final int levelId;
  final bool isEndless;
  final bool restoreFromSavedSnapshot;
  const GameScreen({
    super.key,
    this.levelId = 1,
    this.isEndless = false,
    this.restoreFromSavedSnapshot = false,
  });
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late TdGame _game;
  bool _pauseDialogOpen = false;
  bool _resultDialogShown = false;
  final GlobalKey _gameKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = TdGame(levelId: widget.levelId, isEndless: widget.isEndless);
    _game.matchOutcome.addListener(_onOutcomeChanged);
    if (widget.restoreFromSavedSnapshot) {
      _scheduleRestore();
    }
  }

  void _scheduleRestore() {
    // Game loads asynchronously; wait for onLoad to finish, then restore.
    Future.microtask(() async {
      while (_game.loaded.value == false) {
        await Future.delayed(const Duration(milliseconds: 16));
      }
      final snap = SnapshotRepo.load();
      if (snap == null) return;
      await _game.restoreFromSnapshot(snap);
    });
  }

  @override
  void dispose() {
    _game.matchOutcome.removeListener(_onOutcomeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      _game.paused = true;
      _saveSnapshot();
    }
  }

  Future<void> _saveSnapshot() async {
    if (_game.matchOutcome.value != null) return; // match ended; no snapshot
    final snap = _game.takeSnapshot();
    await SnapshotRepo.save(snap);
  }

  Vector2? _globalToGameLocal(Offset global) {
    final box = _gameKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(global);
    if (local.dx < 0 || local.dy < 0 || local.dx > box.size.width || local.dy > box.size.height) {
      return null;
    }
    return Vector2(local.dx, local.dy);
  }

  void _onOutcomeChanged() {
    if (_resultDialogShown) return;
    final outcome = _game.matchOutcome.value;
    if (outcome == null) return;
    _resultDialogShown = true;
    SnapshotRepo.clear();
    if (outcome == true) {
      _showVictory();
    } else {
      _showDefeat();
    }
  }

  Future<void> _showVictory() async {
    final livesLost = _game.config.startingLives - _game.state.lives;
    final stars = starsForResult(livesLost: livesLost);
    final profile = ProfileRepo.load();
    if (!widget.isEndless) {
      profile.recordLevelResult(widget.levelId, stars);
      await ProfileRepo.save(profile);
    }
    final hasNext = !widget.isEndless && widget.levelId < 3;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => VictoryDialog(
        stars: stars,
        livesRemaining: _game.state.lives,
        onQuit: () {
          Navigator.pop(ctx);
          if (mounted) Navigator.pop(context);
        },
        onRetry: () {
          Navigator.pop(ctx);
          _restart();
        },
        onNext: hasNext
            ? () {
                Navigator.pop(ctx);
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameScreen(levelId: widget.levelId + 1),
                  ),
                );
              }
            : null,
      ),
    );
  }

  Future<void> _showDefeat() async {
    final profile = ProfileRepo.load();
    int? hi;
    if (widget.isEndless) {
      final reached = _game.state.currentWave;
      if (reached > profile.endlessHighestWave) {
        profile.endlessHighestWave = reached;
        await ProfileRepo.save(profile);
      }
      hi = profile.endlessHighestWave;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => DefeatDialog(
        wavesReached: _game.state.currentWave,
        isEndless: widget.isEndless,
        endlessHighScore: hi,
        onQuit: () {
          Navigator.pop(ctx);
          if (mounted) Navigator.pop(context);
        },
        onRetry: () {
          Navigator.pop(ctx);
          _restart();
        },
      ),
    );
  }

  void _restart() {
    final levelId = widget.levelId;
    final isEndless = widget.isEndless;
    setState(() {
      _game.matchOutcome.removeListener(_onOutcomeChanged);
      _game = TdGame(levelId: levelId, isEndless: isEndless);
      _game.matchOutcome.addListener(_onOutcomeChanged);
      _resultDialogShown = false;
    });
  }

  Future<void> _handleBack() async {
    if (_pauseDialogOpen) return;
    _pauseDialogOpen = true;
    final wasPaused = _game.paused;
    _game.paused = true;
    await _saveSnapshot();

    final choice = await showDialog<_PauseChoice>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text('PAUSED',
            style: TextStyle(
              color: AppColors.cyan,
              fontSize: 18,
              letterSpacing: 4,
              shadows: [Shadow(color: AppColors.cyan.withValues(alpha: 0.6), blurRadius: 8)],
            )),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _PauseChoice.resume),
            child: const Text('RESUME', style: TextStyle(color: AppColors.textSecondary, letterSpacing: 2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _PauseChoice.restart),
            child: Text('RESTART',
                style: TextStyle(
                  color: AppColors.yellow,
                  letterSpacing: 2,
                  shadows: [Shadow(color: AppColors.yellow.withValues(alpha: 0.6), blurRadius: 6)],
                )),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _PauseChoice.quit),
            child: Text('QUIT',
                style: TextStyle(
                  color: AppColors.red,
                  letterSpacing: 2,
                  shadows: [Shadow(color: AppColors.red.withValues(alpha: 0.6), blurRadius: 6)],
                )),
          ),
        ],
      ),
    );
    _pauseDialogOpen = false;
    if (!mounted) return;
    switch (choice) {
      case _PauseChoice.quit:
        await SnapshotRepo.clear();
        Navigator.of(context).pop();
        break;
      case _PauseChoice.restart:
        await SnapshotRepo.clear();
        _restart();
        break;
      case _PauseChoice.resume:
      case null:
        _game.paused = wasPaused;
        break;
    }
  }

  void _togglePauseFromHud() {
    setState(() {
      _game.paused = !_game.paused;
    });
    if (_game.paused) _saveSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              ValueListenableBuilder(
                valueListenable: _game.stateNotifier,
                builder: (_, state, child) => Hud(
                  state: state,
                  isPaused: _game.paused,
                  onPauseTap: _togglePauseFromHud,
                ),
              ),
              Expanded(child: KeyedSubtree(key: _gameKey, child: GameWidget(game: _game))),
              ValueListenableBuilder(
                valueListenable: _game.stateNotifier,
                builder: (_, state, child) {
                  return SpeedBar(
                    currentSpeed: _game.currentSpeed,
                    farmIncomePerSec: _game.totalFarmIncome(),
                    onChange: (s) {
                      setState(() => _game.setSpeed(s));
                    },
                  );
                },
              ),
              _bottomPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomPanel() {
    return ValueListenableBuilder(
      valueListenable: _game.selectedTower,
      builder: (_, selected, child) {
        if (selected is Tower) {
          return ValueListenableBuilder(
            valueListenable: _game.stateNotifier,
            builder: (_, state, child) {
              return TowerUpgradePanel(
                type: selected.type,
                branchA: selected.branchA,
                branchB: selected.branchB,
                gold: state.gold,
                totalSpent: _game.totalSpentFor(selected),
                onUpgradeA: () => setState(() => _game.upgradeSelected(branchA: true)),
                onUpgradeB: () => setState(() => _game.upgradeSelected(branchA: false)),
                onSell: () => setState(() => _game.sellSelected()),
                onClose: () => setState(() => _game.selectedTower.value = null),
              );
            },
          );
        }
        if (selected is Farm) {
          return ValueListenableBuilder(
            valueListenable: _game.stateNotifier,
            builder: (_, state, child) {
              return TowerUpgradePanel(
                type: TowerType.farm,
                branchA: selected.branchA,
                branchB: selected.branchB,
                gold: state.gold,
                totalSpent: _game.totalSpentFor(selected),
                onUpgradeA: () => setState(() => _game.upgradeSelected(branchA: true)),
                onUpgradeB: () => setState(() => _game.upgradeSelected(branchA: false)),
                onSell: () => setState(() => _game.sellSelected()),
                onClose: () => setState(() => _game.selectedTower.value = null),
              );
            },
          );
        }
        return ValueListenableBuilder(
          valueListenable: _game.stateNotifier,
          builder: (_, state, child) => TowerPalette(
            gold: state.gold,
            costFor: _game.currentBuildCost,
            onDragStart: (type, gp) {
              final local = _globalToGameLocal(gp);
              _game.startExternalDrag(type, local ?? Vector2(-9999, -9999));
            },
            onDragUpdate: (gp) {
              final local = _globalToGameLocal(gp);
              _game.updateExternalDrag(local ?? Vector2(-9999, -9999));
            },
            onDragEnd: (gp) {
              final local = _globalToGameLocal(gp);
              if (local == null) {
                _game.cancelExternalDrag();
              } else {
                _game.endExternalDrag(local);
              }
            },
            onDragCancel: _game.cancelExternalDrag,
          ),
        );
      },
    );
  }
}

enum _PauseChoice { resume, restart, quit }
```

### Step 4: Verify

```
flutter analyze
flutter test
```
Expected: clean. All tests pass.

If `_game.loaded.value` does not exist in FlameGame (need to check Flame 1.37) — fall back to a custom flag:

```dart
// In TdGame, add: bool isLoaded = false;
// At end of onLoad: isLoaded = true;
// In _scheduleRestore loop check `_game.isLoaded` instead.
```

If you need this adaptation, do it.

### Step 5: Commit (final, all together)

```
git add lib/ui/main_menu/main_menu_screen.dart lib/ui/level_select/ lib/ui/match/victory_dialog.dart lib/ui/match/defeat_dialog.dart lib/game/game_screen.dart
git commit -m "feat(ui): main menu CONTINUE/CAMPAIGN/ENDLESS, level select, victory/defeat dialogs, snapshot save/restore"
```

---

## Task 11: Final tests, tag, push

### Step 1: Full test + analyze

```
flutter test
flutter analyze
```
Both must be clean. Expected ~50 tests pass.

### Step 2: Tag and push

```
git tag stage-2b-content
git push origin main --tags
```

### Step 3: Hand off to user for playtest

Tell the user:
- Pull and run `flutter run` on Android
- Verify: main menu has CAMPAIGN / ENDLESS / SETTINGS (no CONTINUE yet)
- Play level 1, win/lose, verify Victory/Defeat dialogs
- Level Select shows ★ after a level is passed
- Level 2 unlocks after level 1 completion
- Endless works and tracks high score
- Pause / Restart / Quit work
- Quit during a match, return to menu → CONTINUE appears in green
- Tap CONTINUE → match resumes with same lives/gold/wave/towers (current-wave timer restarts, that's expected)

---

## Done

After Task 11, Stage 2b is complete. We have full Campaign + Endless + persistence.

**Next plan: Stage 3.** Three big pieces (per memory notes):
1. **Constructor mode** — third game mode with player-defined entry/exit, A* pathfinding, "cannot fully block path" validation
2. **Endless map select** — choose from any cleared Campaign map
3. More level content (we keep Campaign at fixed-path; maze nature moves entirely into Constructor)

Before Stage 3 we'll brainstorm Constructor in detail (UX of placing entry/exit, what happens when path becomes invalid mid-match, A* perf budget).
