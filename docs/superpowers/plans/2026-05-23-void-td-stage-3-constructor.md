# VOID TD — Stage 3: Constructor Mode

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Add a third game mode "Constructor" — an empty grid where the player chooses entry and exit on the map edge, then freely builds towers anywhere. Towers act as walls; enemies dynamically find the shortest path via A*. The player cannot fully block the route (last-clear-path validation). Waves are procedurally generated like Endless, with cumulative ramp after every boss. Full save/resume; the construction phase is preserved across app restarts.

**Architecture:**
- New pure-Dart `AStarPathfinder` finds the shortest path on the grid given a set of blocked cells. Reuses the existing `Grid` model.
- New `ConstructorSetupScreen` lets the player pick entry/exit before the match starts (tap two edge cells).
- `TdGame` is extended with a `_constructorMode` flag and a dynamic `_path` that updates on every tower placement/sale. Enemies remember their original path-distance but recompute their `Vector2` each frame from the live path so they follow new routes without teleporting.
- `MatchSnapshot` gains: `entryCell`, `exitCell`, `constructorPhase` ("building" | "active").
- Main menu gets a 5th button CONSTRUCTOR (orange, between ENDLESS and SETTINGS) with its own save slot.

**Tech Stack:** Same as Stage 2b. No new packages.

**Spec reference:** [`docs/superpowers/specs/2026-05-21-tower-defense-mvp-design.md`](../specs/2026-05-21-tower-defense-mvp-design.md)

**Key decisions locked in:**
- **Q1 A:** Entry and exit chosen ONCE in a setup screen before the match. Must be on the map edge (border cells only — top/bottom row or left/right column).
- **Q2 B:** No autostart. Player taps a START WAVES button when ready. After that, waves auto-chain like Endless.
- **Q3 A + ramp:** Reuse `_generateEndlessWave(wave)`; apply a global multiplier `1 + 0.10 × bossesPassed` to enemy HP after each boss is cleared. Bosses spawn every 10 waves.
- **Q4 A:** A persistent path line is rendered from entry to exit. During tower drag-preview, the line updates in real time so the player sees the new route before placing.
- **Q5 A:** When a drag-preview cell would fully block all routes (or would land on entry/exit), the highlight is red; releasing does nothing.
- **Q6 B:** Starting resources: 300 gold, 20 lives.
- **Q7 A:** SELL works with the standard 70% refund. Path re-pathfinds on sale.
- **Q8 A:** Main menu adds CONSTRUCTOR (orange `Color(0xFFFF8C00)`) between ENDLESS and SETTINGS. Constructor uses its own save slot (so a Campaign CONTINUE button and an Endless+Constructor saves can coexist).
- **Q9 A:** Snapshot covers everything including the building phase: entry/exit, phase ("building"/"active"), all placed towers, lives/gold, current wave.

**Working directory:** `c:\dev\void_td`. Platform Windows. Use `.withValues(alpha: x)`.

---

## File Structure changes

```
c:\dev\void_td\lib\
├── core\
│   └── theme\
│       └── colors.dart                                 // MODIFIED: add AppColors.orange
│
├── data\
│   └── constructor_config.dart                         // NEW: starting gold/lives + grid size constants
│
├── game\
│   ├── td_game.dart                                    // MODIFIED: constructor mode, dynamic path, ramp multiplier
│   ├── game_screen.dart                                // MODIFIED: setup screen wiring, START WAVES button, save-slot
│   ├── pathfinding\
│   │   └── astar.dart                                  // NEW: pure-Dart A* on a grid
│   ├── match\
│   │   ├── match_snapshot.dart                         // MODIFIED: entryCell, exitCell, constructorPhase
│   │   └── snapshot_repo.dart                          // MODIFIED: 3 slots (campaign/endless/constructor)
│   ├── components\
│   │   ├── enemy.dart                                  // MODIFIED: re-pathing support (follow live path by progress)
│   │   └── path_marker.dart                            // NEW: entry/exit visual markers
│   └── path\
│       └── path_renderer.dart                          // unchanged — already draws a PathSegment
│
├── ui\
│   ├── main_menu\
│   │   └── main_menu_screen.dart                       // MODIFIED: CONSTRUCTOR 5th button
│   ├── constructor\
│   │   ├── constructor_setup_screen.dart               // NEW: pick entry/exit on grid edges
│   │   └── start_waves_button.dart                     // NEW: prominent START WAVES button
│   └── match\
│       └── (unchanged)
│
└── meta\
    └── (unchanged — Constructor doesn't touch PlayerProfile)
```

Tests:
```
c:\dev\void_td\test\
├── astar_test.dart                                     // NEW: pathfinding correctness + last-path validation
├── match_snapshot_test.dart                            // MODIFIED: add entryCell/exitCell/phase round-trip
└── (existing tests unchanged)
```

---

## Task 1: AStarPathfinder (TDD, pure Dart)

**Files:**
- Create: `c:\dev\void_td\lib\game\pathfinding\astar.dart`
- Create: `c:\dev\void_td\test\astar_test.dart`

The A* takes: grid cols/rows, set of blocked cells, start, goal. Returns a list of `(col, row)` cells forming the shortest path, or `null` if no path exists. 4-direction movement (no diagonals — simpler, more readable visual paths for the player).

### Step 1: Write failing test

Create `test\astar_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/game/pathfinding/astar.dart';

void main() {
  group('AStar', () {
    test('finds a straight horizontal path on empty grid', () {
      final path = AStar.findPath(
        cols: 5,
        rows: 1,
        blocked: const {},
        start: (0, 0),
        goal: (4, 0),
      );
      expect(path, isNotNull);
      expect(path!.length, 5);
      expect(path.first, (0, 0));
      expect(path.last, (4, 0));
    });

    test('finds an L-path on a 3x3 grid with one obstacle', () {
      final path = AStar.findPath(
        cols: 3,
        rows: 3,
        blocked: const {(1, 0), (1, 1)},
        start: (0, 0),
        goal: (2, 0),
      );
      expect(path, isNotNull);
      expect(path!.first, (0, 0));
      expect(path.last, (2, 0));
      // Must NOT pass through any blocked cell.
      for (final cell in path) {
        expect({(1, 0), (1, 1)}.contains(cell), isFalse);
      }
    });

    test('returns null when no path exists', () {
      // Vertical wall splitting a 3x3 grid.
      final path = AStar.findPath(
        cols: 3,
        rows: 3,
        blocked: const {(1, 0), (1, 1), (1, 2)},
        start: (0, 1),
        goal: (2, 1),
      );
      expect(path, isNull);
    });

    test('start cell can equal goal cell — returns single-cell path', () {
      final path = AStar.findPath(
        cols: 3,
        rows: 3,
        blocked: const {},
        start: (1, 1),
        goal: (1, 1),
      );
      expect(path, isNotNull);
      expect(path!.length, 1);
    });

    test('canReach returns false when a single new block severs the only path', () {
      // A corridor of width 1; blocking the middle disconnects it.
      const cols = 5;
      const rows = 1;
      const start = (0, 0);
      const goal = (4, 0);
      expect(AStar.canReach(cols: cols, rows: rows, blocked: const {(2, 0)}, start: start, goal: goal), isFalse);
      // But on a 2-row grid, the same block leaves a detour:
      expect(AStar.canReach(cols: cols, rows: 2, blocked: const {(2, 0)}, start: start, goal: goal), isTrue);
    });

    test('result is the shortest path (Manhattan-optimal on empty grid)', () {
      final path = AStar.findPath(
        cols: 4,
        rows: 4,
        blocked: const {},
        start: (0, 0),
        goal: (3, 3),
      );
      expect(path, isNotNull);
      // Shortest path on a Manhattan grid with no diagonals = 7 cells (incl. endpoints).
      expect(path!.length, 7);
    });
  });
}
```

### Step 2: Verify it fails

```
flutter test test/astar_test.dart
```
Expected: FAIL — `AStar` doesn't exist.

### Step 3: Implement

Create `lib\game\pathfinding\astar.dart`:
```dart
import 'dart:collection';

/// Pure-Dart A* on a 4-connected grid.
class AStar {
  /// Returns the list of cells from `start` to `goal` inclusive, or null if
  /// unreachable. Blocked cells are impassable. Start and goal themselves
  /// must NOT be in `blocked`.
  static List<(int, int)>? findPath({
    required int cols,
    required int rows,
    required Set<(int, int)> blocked,
    required (int, int) start,
    required (int, int) goal,
  }) {
    if (start == goal) return [start];
    if (blocked.contains(start) || blocked.contains(goal)) return null;

    final open = _PriorityQueue();
    final cameFrom = <(int, int), (int, int)>{};
    final gScore = <(int, int), int>{start: 0};
    open.add(start, _heuristic(start, goal));

    while (open.isNotEmpty) {
      final current = open.removeFirst();
      if (current == goal) {
        return _reconstruct(cameFrom, current);
      }
      for (final next in _neighbours(current, cols, rows)) {
        if (blocked.contains(next)) continue;
        final tentativeG = gScore[current]! + 1;
        final existingG = gScore[next];
        if (existingG == null || tentativeG < existingG) {
          cameFrom[next] = current;
          gScore[next] = tentativeG;
          open.add(next, tentativeG + _heuristic(next, goal));
        }
      }
    }
    return null;
  }

  /// True if a path exists from `start` to `goal` avoiding `blocked`.
  static bool canReach({
    required int cols,
    required int rows,
    required Set<(int, int)> blocked,
    required (int, int) start,
    required (int, int) goal,
  }) {
    return findPath(
          cols: cols,
          rows: rows,
          blocked: blocked,
          start: start,
          goal: goal,
        ) !=
        null;
  }

  static int _heuristic((int, int) a, (int, int) b) {
    return (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs();
  }

  static Iterable<(int, int)> _neighbours((int, int) c, int cols, int rows) sync* {
    final (col, row) = c;
    if (col > 0) yield (col - 1, row);
    if (col < cols - 1) yield (col + 1, row);
    if (row > 0) yield (col, row - 1);
    if (row < rows - 1) yield (col, row + 1);
  }

  static List<(int, int)> _reconstruct(
    Map<(int, int), (int, int)> cameFrom,
    (int, int) end,
  ) {
    final out = <(int, int)>[end];
    var cur = end;
    while (cameFrom.containsKey(cur)) {
      cur = cameFrom[cur]!;
      out.add(cur);
    }
    return out.reversed.toList();
  }
}

/// Tiny binary-heap-backed priority queue keyed by (int, int).
class _PriorityQueue {
  final List<_Entry> _heap = [];
  final Map<(int, int), int> _bestF = {};

  bool get isNotEmpty => _heap.isNotEmpty;

  void add((int, int) cell, int f) {
    final existing = _bestF[cell];
    if (existing != null && existing <= f) return; // skip worse
    _bestF[cell] = f;
    _heap.add(_Entry(cell, f));
    _siftUp(_heap.length - 1);
  }

  (int, int) removeFirst() {
    final top = _heap.first.cell;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _siftDown(0);
    }
    return top;
  }

  void _siftUp(int i) {
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_heap[i].f < _heap[parent].f) {
        final tmp = _heap[i];
        _heap[i] = _heap[parent];
        _heap[parent] = tmp;
        i = parent;
      } else {
        break;
      }
    }
  }

  void _siftDown(int i) {
    final n = _heap.length;
    while (true) {
      var smallest = i;
      final l = 2 * i + 1;
      final r = 2 * i + 2;
      if (l < n && _heap[l].f < _heap[smallest].f) smallest = l;
      if (r < n && _heap[r].f < _heap[smallest].f) smallest = r;
      if (smallest == i) break;
      final tmp = _heap[i];
      _heap[i] = _heap[smallest];
      _heap[smallest] = tmp;
      i = smallest;
    }
  }
}

class _Entry {
  final (int, int) cell;
  final int f;
  _Entry(this.cell, this.f);
}
```

Note: `dart:collection` import is unused (we built our own heap). You can remove it if analyzer complains.

### Step 4: Verify

```
flutter test test/astar_test.dart
```
Expected: all 6 tests pass.

If any test fails, debug — tests are authoritative.

### Step 5: Commit

```
git add lib/game/pathfinding/astar.dart test/astar_test.dart
git commit -m "feat(game): A* pathfinding on grid (pure Dart, with tests)"
```

---

## Task 2: Extend MatchSnapshot for Constructor

**Files:**
- Modify: `c:\dev\void_td\lib\game\match\match_snapshot.dart`
- Modify: `c:\dev\void_td\test\match_snapshot_test.dart`

Add three optional fields: `entryCell`, `exitCell` (both `(int,int)?`), and `constructorPhase` (`String?` — "building" or "active"). All three null for Campaign/Endless snapshots. Round-trip must preserve them.

### Step 1: Update the test

Add a new test to `test/match_snapshot_test.dart`:
```dart
test('constructor snapshot round-trips entry/exit/phase', () {
  final snap = MatchSnapshot(
    levelId: 0,
    isEndless: false,
    lives: 18,
    gold: 270,
    currentWave: 4,
    cleanWavesCount: 1,
    towers: const [],
    interWaveDelaySec: 0,
    isWaveActive: true,
    currentWaveElapsedSec: 0,
    entryCell: (0, 5),
    exitCell: (8, 10),
    constructorPhase: 'active',
  );
  final restored = MatchSnapshot.fromMap(snap.toMap());
  expect(restored.entryCell, (0, 5));
  expect(restored.exitCell, (8, 10));
  expect(restored.constructorPhase, 'active');
});

test('non-constructor snapshot has null entry/exit/phase', () {
  final snap = MatchSnapshot(
    levelId: 1,
    isEndless: false,
    lives: 20,
    gold: 200,
    currentWave: 1,
    cleanWavesCount: 0,
    towers: const [],
    interWaveDelaySec: 0,
    isWaveActive: true,
    currentWaveElapsedSec: 0,
  );
  final restored = MatchSnapshot.fromMap(snap.toMap());
  expect(restored.entryCell, isNull);
  expect(restored.exitCell, isNull);
  expect(restored.constructorPhase, isNull);
});
```

### Step 2: Update MatchSnapshot

Add the three optional fields to the constructor and `toMap` / `fromMap`. Both `(int,int)` tuples serialise as a two-element list `[col, row]`.

```dart
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

  // Constructor-only (null for Campaign/Endless).
  final (int, int)? entryCell;
  final (int, int)? exitCell;
  final String? constructorPhase; // "building" | "active"

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
    this.entryCell,
    this.exitCell,
    this.constructorPhase,
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
        if (entryCell != null) 'entryCell': [entryCell!.$1, entryCell!.$2],
        if (exitCell != null) 'exitCell': [exitCell!.$1, exitCell!.$2],
        if (constructorPhase != null) 'constructorPhase': constructorPhase,
      };

  static MatchSnapshot fromMap(Map raw) {
    final m = Map<String, dynamic>.from(raw);
    (int, int)? readCell(String key) {
      final v = m[key];
      if (v is List && v.length == 2) return (v[0] as int, v[1] as int);
      return null;
    }
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
      entryCell: readCell('entryCell'),
      exitCell: readCell('exitCell'),
      constructorPhase: m['constructorPhase'] as String?,
    );
  }
}
```

### Step 3: Verify

```
flutter test test/match_snapshot_test.dart
flutter analyze
```
Expected: 4 tests pass (2 existing + 2 new); analyze clean.

### Step 4: Commit

```
git add lib/game/match/match_snapshot.dart test/match_snapshot_test.dart
git commit -m "feat(game): MatchSnapshot carries entryCell/exitCell/constructorPhase"
```

---

## Task 3: Three-slot SnapshotRepo

**Files:**
- Modify: `c:\dev\void_td\lib\game\match\snapshot_repo.dart`

Currently SnapshotRepo has two slots (`campaign` and `endless`). Add a third: `constructor`. Since `isEndless` is a bool, we can't disambiguate "constructor" from "endless" with just that — we need an explicit mode parameter.

### Step 1: Add a `SaveSlot` enum and rewrite the API

Replace `lib\game\match\snapshot_repo.dart`:
```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'match_snapshot.dart';

enum SaveSlot { campaign, endless, constructor }

/// Three-slot snapshot store: Campaign, Endless, Constructor.
/// CONTINUE in the main menu reflects ONLY the Campaign slot. Endless and
/// Constructor snapshots are auto-resumed when the player taps their mode
/// button.
class SnapshotRepo {
  static const _boxName = 'saved_match';

  static String _keyFor(SaveSlot slot) {
    switch (slot) {
      case SaveSlot.campaign:
        return 'campaign';
      case SaveSlot.endless:
        return 'endless';
      case SaveSlot.constructor:
        return 'constructor';
    }
  }

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static MatchSnapshot? load(SaveSlot slot) {
    final box = Hive.box(_boxName);
    final raw = box.get(_keyFor(slot));
    if (raw == null) return null;
    return MatchSnapshot.fromMap(raw as Map);
  }

  static Future<void> save(SaveSlot slot, MatchSnapshot snap) async {
    final box = Hive.box(_boxName);
    await box.put(_keyFor(slot), snap.toMap());
  }

  static Future<void> clear(SaveSlot slot) async {
    final box = Hive.box(_boxName);
    await box.delete(_keyFor(slot));
  }

  static bool exists(SaveSlot slot) {
    final box = Hive.box(_boxName);
    return box.get(_keyFor(slot)) != null;
  }
}
```

### Step 2: Update all call sites

Search for `SnapshotRepo.` usages and update each:
- `lib/ui/main_menu/main_menu_screen.dart`:
  - `SnapshotRepo.exists(isEndless: false)` → `SnapshotRepo.exists(SaveSlot.campaign)`
  - `SnapshotRepo.exists(isEndless: true)` → `SnapshotRepo.exists(SaveSlot.endless)`
  - `SnapshotRepo.load(isEndless: false)` → `SnapshotRepo.load(SaveSlot.campaign)`
- `lib/game/game_screen.dart`:
  - In `_scheduleRestore`: `SnapshotRepo.load(isEndless: widget.isEndless)` — we need to know which slot to load. Add a `SaveSlot` parameter to `GameScreen`. The current `widget.isEndless` is still a boolean; we'll extend `GameScreen` to also know it's "constructor mode" via a new field. For now (this task), add a helper:
    ```dart
    SaveSlot get _slot {
      if (widget.isConstructor) return SaveSlot.constructor;
      if (widget.isEndless) return SaveSlot.endless;
      return SaveSlot.campaign;
    }
    ```
    And add `final bool isConstructor;` to `GameScreen` constructor (default false). This is harmless to existing Campaign/Endless paths. We wire actual Constructor flow in Task 5+.

  - `SnapshotRepo.save(snap)` → `SnapshotRepo.save(_slot, snap)`
  - `SnapshotRepo.clear(isEndless: widget.isEndless)` (both occurrences) → `SnapshotRepo.clear(_slot)`

Also update `lib/game/match/snapshot_repo.dart` callers in tests if any — none currently exist (snapshot tests use `MatchSnapshot` directly).

### Step 3: Verify

```
flutter analyze
flutter test
```
Expected: clean analyze, all tests pass (number depends on prior state).

### Step 4: Commit

```
git add lib/game/match/snapshot_repo.dart lib/ui/main_menu/main_menu_screen.dart lib/game/game_screen.dart
git commit -m "feat(game): three-slot SnapshotRepo (campaign/endless/constructor)"
```

---

## Task 4: Add AppColors.orange + ConstructorConfig

**Files:**
- Modify: `c:\dev\void_td\lib\core\theme\colors.dart`
- Create: `c:\dev\void_td\lib\data\constructor_config.dart`

### Step 1: Add orange color

In `colors.dart`, add to AppColors:
```dart
static const Color orange = Color(0xFFFF8C00);
```

### Step 2: Create constructor_config.dart

```dart
import '../game/grid/grid.dart';

/// Static constants for Constructor mode. Grid matches Campaign/Endless so the
/// game canvas layout is consistent. No path JSON — entry/exit are chosen by
/// the player at runtime.
class ConstructorConfig {
  static const Grid grid = Grid(cols: 9, rows: 16, cellSize: 40);
  static const int startingLives = 20;
  static const int startingGold = 300;
  static const double passiveIncomePerWave = 10;
  static const double passiveIncomePerWaveGrowth = 3;
  static const String name = 'CONSTRUCTOR';
  static const String id = 'constructor';
}
```

### Step 3: Verify

```
flutter analyze
```

### Step 4: Commit

```
git add lib/core/theme/colors.dart lib/data/constructor_config.dart
git commit -m "feat(data): add AppColors.orange + ConstructorConfig"
```

---

## Task 5: Path marker component + dynamic path renderer integration

**Files:**
- Create: `c:\dev\void_td\lib\game\components\path_marker.dart`

Entry/exit are drawn as small filled circles with a glow, sized like a tower icon, with cyan for entry and red for exit (gameplay-wise they're "spawn" and "leak point" — color encodes danger gradient).

### Step 1: Implement

```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum PathMarkerKind { entry, exit }

class PathMarker extends PositionComponent {
  PathMarkerKind kind;
  bool visible;

  PathMarker({
    required Vector2 worldPos,
    required this.kind,
    this.visible = true,
  }) : super(position: worldPos.clone(), size: Vector2.all(28), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final color = kind == PathMarkerKind.entry
        ? const Color(0xFF00D4FF) // cyan
        : const Color(0xFFFF3B3B); // red
    final r = size.x / 2;
    final centre = Offset(r, r);
    final fill = Paint()..color = color.withValues(alpha: 0.25);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(centre, r * 0.9, fill);
    canvas.drawCircle(centre, r * 0.9, stroke);
    // inner dot
    canvas.drawCircle(centre, r * 0.25, Paint()..color = color);
  }
}
```

### Step 2: Verify

```
flutter analyze
```

### Step 3: Commit

```
git add lib/game/components/path_marker.dart
git commit -m "feat(game): PathMarker component for Constructor entry/exit"
```

---

## Task 6: TdGame Constructor mode (dynamic path, ramp multiplier, START WAVES gate)

**Files:**
- Modify: `c:\dev\void_td\lib\game\td_game.dart`

This is the central change. We extend TdGame to support Constructor mode without breaking Campaign/Endless.

### Behavioural changes

1. **Constructor flag.** New ctor param `bool isConstructor`. Mutually exclusive with `isEndless`.
2. **Entry/exit.** When `isConstructor`, `onLoad` uses `ConstructorConfig` instead of loading from JSON. The level config has no path; path is rebuilt dynamically from entry → exit.
3. **Dynamic path.** New private state: `(int,int)? _entryCell, _exitCell`, `bool _wavesStarted = false` (gate), `List<(int,int)>? _currentPathCells` (cached A* result). When a tower is placed/sold, rerun A* and rebuild the `path` PathSegment.
4. **Enemy re-pathing.** Enemies remember `pathProgress` (already exposed via getter). When the path changes mid-flight, we re-issue them onto the new path while preserving roughly the same progress fraction. Add an internal method `_rebindEnemiesToPath()`.
5. **Validation.** `_canBuildAt(col, row, type)` in constructor mode additionally checks: if (a) cell equals entry or exit → false; (b) `AStar.canReach` with this new cell added to blocked set → false otherwise true.
6. **Wave start.** In constructor mode, `onLoad` does NOT call `_startNextWave()`. Instead `_wavesStarted` stays false. A new public method `startWaves()` flips it true and calls `_startNextWave()`.
7. **Boss ramp.** After clearing each boss wave (wave % 10 == 0, in endless+constructor), increment `_bossesPassed` and apply `1.0 + 0.10 * _bossesPassed` HP multiplier to subsequently spawned enemies. Add a method on Enemy to scale `hp`/`maxHp` at spawn time.

### Step 1: Add Constructor-related fields and methods

Open `lib\game\td_game.dart`. Make these targeted changes (do NOT rewrite the whole file — too risky):

**a) Constructor signature:**
```dart
TdGame({this.levelId = 1, this.isEndless = false, this.isConstructor = false});

// New field:
final bool isConstructor;
```

**b) Add imports:**
```dart
import '../data/constructor_config.dart';
import 'pathfinding/astar.dart';
import 'components/path_marker.dart';
```

**c) Add state fields near other private state:**
```dart
// Constructor-only state.
(int, int)? _entryCell;
(int, int)? _exitCell;
bool _wavesStarted = false;
bool get wavesStarted => _wavesStarted;
late final PathMarker _entryMarker;
late final PathMarker _exitMarker;
List<(int, int)>? _currentPathCells;
int _bossesPassed = 0;

/// Tracks which enemies have already been HP-scaled by the current boss ramp,
/// so we don't double-scale across rebinds.
final Set<Enemy> _enemiesScaledThisGame = {};
```

**d) Modify `onLoad`:** the existing onLoad has a hardcoded asset-loaded LevelConfig. Branch on `isConstructor`:

Find the line `_config = isEndless ? await LevelLoader.loadEndless() : await LevelLoader.loadCampaignLevel(levelId);` and replace it with:
```dart
if (isConstructor) {
  _config = LevelConfig(
    id: ConstructorConfig.id,
    name: ConstructorConfig.name,
    grid: ConstructorConfig.grid,
    pathPoints: [Vector2.zero(), Vector2(0, 1)], // placeholder; replaced by dynamic path
    startingLives: ConstructorConfig.startingLives,
    startingGold: ConstructorConfig.startingGold,
    passiveIncomePerWave: ConstructorConfig.passiveIncomePerWave,
    passiveIncomePerWaveGrowth: ConstructorConfig.passiveIncomePerWaveGrowth,
    waves: const [],
  );
} else {
  _config = isEndless
      ? await LevelLoader.loadEndless()
      : await LevelLoader.loadCampaignLevel(levelId);
}
_waves = _config.waves;
```

Further in `onLoad`, replace the line that builds `path = PathSegment(points: _config.pathPoints);` and the subsequent world setup so that for constructor mode, path is null until `_recomputePath()` is called:

```dart
final grid = _config.grid;
final offsetX = (size.x - grid.width) / 2;
final offsetY = 30.0;
_world = PositionComponent(position: Vector2(offsetX, offsetY));
add(_world);
_world.add(GridPainter(grid: grid));
_gridOrigin = Vector2(offsetX, offsetY);

if (isConstructor) {
  // Dummy path until entry/exit set externally.
  path = PathSegment(points: [Vector2.zero(), Vector2(0, 1)]);
} else {
  path = PathSegment(points: _config.pathPoints);
  _world.add(PathRenderer(path: path));
}

_pathRenderer = isConstructor
    ? PathRenderer(path: path) // mutable, re-added after each recompute
    : null;
if (_pathRenderer != null) _world.add(_pathRenderer!);

// Add the pre-mounted entry/exit markers (invisible until setEntryExit called).
_entryMarker = PathMarker(
  worldPos: Vector2.zero(),
  kind: PathMarkerKind.entry,
  visible: false,
);
_exitMarker = PathMarker(
  worldPos: Vector2.zero(),
  kind: PathMarkerKind.exit,
  visible: false,
);
_world.add(_entryMarker);
_world.add(_exitMarker);

// Pre-mounted preview overlays (unchanged).
// ... (existing pre-mounted _previewHighlight, _previewRange, _previewSplashRange)

// Initial match state.
stateNotifier.value = MatchState(
  lives: _config.startingLives,
  gold: _config.startingGold,
);

if (!isConstructor) {
  _startNextWave();
}
_emitState();
```

Add field for renderer reference:
```dart
PathRenderer? _pathRenderer;
```

> **Implementation note:** the existing render line `_world.add(PathRenderer(path: path));` creates a renderer bound to the original path object. For constructor mode we want to **swap** the path. Two options:
> 1. Make `PathSegment` mutable (rebuild points in place + update cumulative). Cleaner.
> 2. Recreate `PathRenderer` and `PathSegment` together on each recompute.
>
> Option 1 is easier. Add a `void rebuild(List<Vector2> newPoints)` method to PathSegment. Then `_pathRenderer` just keeps rendering the same instance.

Add `rebuild` to `lib\game\path\path_segment.dart`:
```dart
void rebuild(List<Vector2> newPoints) {
  assert(newPoints.length >= 2);
  points
    ..clear()
    ..addAll(newPoints);
  _cumulative = List<double>.filled(points.length, 0);
  double sum = 0;
  for (var i = 1; i < points.length; i++) {
    sum += points[i - 1].distanceTo(points[i]);
    _cumulative[i] = sum;
  }
  totalLength = sum;
}
```
This requires `_cumulative` and `totalLength` to become non-final. Make `points` a regular `final List<Vector2>` (kept mutable so we can `clear()`), and `_cumulative` / `totalLength` become `late` non-final.

Open `lib/game/path/path_segment.dart` and:
- Change `final List<Vector2> points;` → keep as is (List is mutable by default; we just clear and re-add).
- Change `late final List<double> _cumulative;` → `late List<double> _cumulative;`
- Change `late final double totalLength;` → `late double totalLength;`
- Add the `rebuild` method.

This is the only invasive change outside td_game.dart.

**e) Add `setEntryExit` + `_recomputePath` + `startWaves` methods:**

```dart
void setEntryExit({required (int, int) entry, required (int, int) exit}) {
  _entryCell = entry;
  _exitCell = exit;
  final grid = _config.grid;
  final eCentre = grid.cellCenter(entry.$1, entry.$2);
  final xCentre = grid.cellCenter(exit.$1, exit.$2);
  _entryMarker.position = Vector2(eCentre.dx, eCentre.dy);
  _entryMarker.visible = true;
  _exitMarker.position = Vector2(xCentre.dx, xCentre.dy);
  _exitMarker.visible = true;
  _recomputePath();
  _renderOneFrameIfPaused();
}

/// Recomputes A* path from entry to exit, treating all placed towers/farms as
/// blocked. Updates the PathSegment in place. Returns true if a path exists.
bool _recomputePath() {
  if (_entryCell == null || _exitCell == null) return false;
  final grid = _config.grid;
  final blocked = _placed.keys.toSet();
  final cells = AStar.findPath(
    cols: grid.cols,
    rows: grid.rows,
    blocked: blocked,
    start: _entryCell!,
    goal: _exitCell!,
  );
  if (cells == null) return false;
  _currentPathCells = cells;
  final newPoints = cells.map((c) {
    final o = grid.cellCenter(c.$1, c.$2);
    return Vector2(o.dx, o.dy);
  }).toList();
  path.rebuild(newPoints);
  // Re-bind live enemies to the new path (preserve progress).
  _rebindEnemiesToPath();
  return true;
}

void _rebindEnemiesToPath() {
  // Each enemy's _distanceTravelled becomes relative to the new totalLength.
  // We preserve normalised progress so enemies don't teleport.
  for (final e in liveEnemies) {
    if (e.isRemoved) continue;
    final p = e.pathProgress;
    e.rebindTo(path, progress: p);
  }
}

void startWaves() {
  if (!isConstructor || _wavesStarted) return;
  if (_entryCell == null || _exitCell == null) return;
  _wavesStarted = true;
  _startNextWave();
  _renderOneFrameIfPaused();
}
```

**f) Modify `_canBuildAt` to use AStar in constructor mode:**

Find existing `_canBuildAt`. Replace with:
```dart
bool _canBuildAt(int col, int row, TowerType type) {
  if (_placed.containsKey((col, row))) return false;
  if (isConstructor) {
    if ((col, row) == _entryCell) return false;
    if ((col, row) == _exitCell) return false;
    if (_entryCell != null && _exitCell != null) {
      final wouldBlock = {..._placed.keys, (col, row)};
      final reachable = AStar.canReach(
        cols: _config.grid.cols,
        rows: _config.grid.rows,
        blocked: wouldBlock,
        start: _entryCell!,
        goal: _exitCell!,
      );
      if (!reachable) return false;
    }
  } else {
    if (_isOnPath(col, row)) return false;
  }
  final cost = currentBuildCost(type);
  if (state.gold < cost) return false;
  return true;
}
```

**g) Hook path recomputation into `_placeAt` and `sellSelected`:**

After `_placed[(col, row)] = placed;` in `_placeAt`, add:
```dart
if (isConstructor) _recomputePath();
```
Similarly, in `sellSelected()`, after the existing remove from `_placed`, before `_emitState();`, add:
```dart
if (isConstructor) _recomputePath();
```

**h) Boss ramp:**

In `_spawnEnemy(EnemyType type)`, after creating the Enemy, apply the multiplier:
```dart
if (_bossesPassed > 0 && !_enemiesScaledThisGame.contains(enemy)) {
  final mult = 1.0 + 0.10 * _bossesPassed;
  enemy.scaleHp(mult);
  _enemiesScaledThisGame.add(enemy);
}
```

In `_onWaveCleared` (or near it), if (isEndless || isConstructor) and the wave just finished was a multiple of 10, increment:
```dart
if ((isEndless || isConstructor) && state.currentWave > 0 && state.currentWave % 10 == 0) {
  _bossesPassed++;
}
```

> **Note:** the simpler logic — increment whenever a boss was actually spawned and killed — is hard to track from outside. Going by "wave % 10 == 0" is good enough: bosses spawn on those waves in Endless, and the player either kills them or loses.

### Step 2: Add `Enemy.scaleHp` and `Enemy.rebindTo`

Open `lib\game\components\enemy.dart` and add two public methods:
```dart
void scaleHp(double mult) {
  hp = (hp * mult).clamp(1, 1 << 31);
  // maxHp is final — for visual hp bar we use a separate scaled max.
  // Easiest: change maxHp from `final double` to `double` (non-final).
}

/// Re-bind to a new (in-place rebuilt) PathSegment, preserving normalised progress.
void rebindTo(PathSegment newPath, {required double progress}) {
  // path is final; for this to work, change it from `final` to mutable.
  // We replace the field, and recompute _distanceTravelled.
  _path = newPath;
  _distanceTravelled = progress.clamp(0.0, 1.0) * newPath.totalLength;
}
```

This requires changing two fields in Enemy:
- `final PathSegment path;` → either `PathSegment _path; PathSegment get path => _path;` with a setter, OR keep public `path` non-final.
- `final double maxHp;` → drop `final`.

Pick the simpler: make `path` and `maxHp` both non-final mutable fields. Update the constructor accordingly.

Make sure `pathProgress` getter still returns `(_distanceTravelled / path.totalLength).clamp(0.0, 1.0)` and uses the (now) live `path` field.

### Step 3: Verify

```
flutter analyze
flutter test
```
Expected: clean analyze. All tests pass (60+ existing + the new astar/snapshot tests from prior tasks).

If you encounter "field `path` is final and cannot be assigned", apply the field-mutability change above.

If `match_snapshot_test.dart` fails compilation because `currentWaveElapsedSec` is required but Constructor test omits — check; we added defaults but the snapshot ctor still requires it. Constructor tests pass `0`.

### Step 4: Commit

```
git add lib/game/td_game.dart lib/game/components/enemy.dart lib/game/path/path_segment.dart
git commit -m "feat(game): Constructor mode in TdGame — dynamic path, A* validation, boss ramp"
```

---

## Task 7: ConstructorSetupScreen (entry/exit picker)

**Files:**
- Create: `c:\dev\void_td\lib\ui\constructor\constructor_setup_screen.dart`

A Flutter screen showing the grid (no Flame here — just a CustomPainter for the grid and tappable cells). Player taps an edge cell → it becomes ENTRY (cyan); taps another edge cell → becomes EXIT (red). Tap START on an active "BEGIN" button → push `GameScreen(isConstructor: true)` with entry/exit pre-set via an internal mechanism.

For simplicity, the screen returns `(entry, exit)` via Navigator.pop, then MainMenu pushes GameScreen with those coordinates. We'll add `initialEntry`/`initialExit` parameters to GameScreen.

### Step 1: Create the screen

```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../data/constructor_config.dart';
import '../shared/neon_button.dart';

/// Picks entry and exit on the grid edges. Returns ((entry), (exit)) via Navigator.pop,
/// or null if cancelled.
class ConstructorSetupScreen extends StatefulWidget {
  const ConstructorSetupScreen({super.key});
  @override
  State<ConstructorSetupScreen> createState() => _ConstructorSetupScreenState();
}

class _ConstructorSetupScreenState extends State<ConstructorSetupScreen> {
  (int, int)? _entry;
  (int, int)? _exit;

  bool _isEdge(int col, int row) {
    final g = ConstructorConfig.grid;
    return col == 0 || col == g.cols - 1 || row == 0 || row == g.rows - 1;
  }

  void _tapCell(int col, int row) {
    if (!_isEdge(col, row)) return;
    setState(() {
      if (_entry == null) {
        _entry = (col, row);
      } else if (_exit == null && (col, row) != _entry) {
        _exit = (col, row);
      } else if ((col, row) == _entry) {
        _entry = _exit;
        _exit = null;
      } else if ((col, row) == _exit) {
        _exit = null;
      } else {
        // Both set; reset and start over with this as entry.
        _entry = (col, row);
        _exit = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = ConstructorConfig.grid;
    final canStart = _entry != null && _exit != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              'CONSTRUCTOR',
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 22,
                letterSpacing: 6,
                shadows: [Shadow(color: AppColors.orange.withValues(alpha: 0.6), blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _entry == null
                  ? 'TAP EDGE CELL FOR ENTRY'
                  : _exit == null
                      ? 'TAP EDGE CELL FOR EXIT'
                      : 'READY',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: g.cols / g.rows,
                  child: LayoutBuilder(builder: (context, box) {
                    final cellSize = box.maxWidth / g.cols;
                    return GestureDetector(
                      onTapUp: (d) {
                        final col = (d.localPosition.dx / cellSize).floor();
                        final row = (d.localPosition.dy / cellSize).floor();
                        if (col >= 0 && col < g.cols && row >= 0 && row < g.rows) {
                          _tapCell(col, row);
                        }
                      },
                      child: CustomPaint(
                        painter: _GridPainter(
                          cols: g.cols,
                          rows: g.rows,
                          cellSize: cellSize,
                          entry: _entry,
                          exit: _exit,
                        ),
                        size: Size(box.maxWidth, box.maxHeight),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: NeonButton(
                      label: 'BACK',
                      color: AppColors.textSecondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeonButton(
                      label: 'BEGIN',
                      color: AppColors.orange,
                      onPressed: canStart
                          ? () => Navigator.of(context).pop((_entry!, _exit!))
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final int cols;
  final int rows;
  final double cellSize;
  final (int, int)? entry;
  final (int, int)? exit;

  _GridPainter({
    required this.cols,
    required this.rows,
    required this.cellSize,
    required this.entry,
    required this.exit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    for (var c = 0; c <= cols; c++) {
      final x = c * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, rows * cellSize), linePaint);
    }
    for (var r = 0; r <= rows; r++) {
      final y = r * cellSize;
      canvas.drawLine(Offset(0, y), Offset(cols * cellSize, y), linePaint);
    }
    // Highlight edge cells faintly so player sees where they can tap.
    final edgePaint = Paint()
      ..color = AppColors.orange.withValues(alpha: 0.08);
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        final isEdge = c == 0 || c == cols - 1 || r == 0 || r == rows - 1;
        if (!isEdge) continue;
        canvas.drawRect(
          Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
          edgePaint,
        );
      }
    }
    // Entry/exit markers.
    if (entry != null) _drawMarker(canvas, entry!, AppColors.cyan);
    if (exit != null) _drawMarker(canvas, exit!, AppColors.red);
  }

  void _drawMarker(Canvas canvas, (int, int) cell, Color color) {
    final centre = Offset(
      cell.$1 * cellSize + cellSize / 2,
      cell.$2 * cellSize + cellSize / 2,
    );
    final r = cellSize * 0.42;
    final fill = Paint()..color = color.withValues(alpha: 0.3);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(centre, r, fill);
    canvas.drawCircle(centre, r, stroke);
    canvas.drawCircle(centre, r * 0.3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.entry != entry || oldDelegate.exit != exit;
}
```

### Step 2: Verify

```
flutter analyze
```

### Step 3: Commit

```
git add lib/ui/constructor/constructor_setup_screen.dart
git commit -m "feat(ui): ConstructorSetupScreen for entry/exit selection"
```

---

## Task 8: GameScreen accepts entry/exit + START WAVES button

**Files:**
- Modify: `c:\dev\void_td\lib\game\game_screen.dart`
- Create: `c:\dev\void_td\lib\ui\constructor\start_waves_button.dart`

### Step 1: START WAVES floating button

`lib\ui\constructor\start_waves_button.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class StartWavesButton extends StatelessWidget {
  final VoidCallback onTap;
  const StartWavesButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.orange, width: 1.5),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: AppColors.orange.withValues(alpha: 0.45), blurRadius: 10),
          ],
        ),
        child: Text(
          '▶  START WAVES',
          style: TextStyle(
            color: AppColors.orange,
            fontSize: 13,
            letterSpacing: 3,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: AppColors.orange.withValues(alpha: 0.6), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}
```

### Step 2: Update `game_screen.dart`

Add to `GameScreen`:
- Constructor params: `final bool isConstructor`, `final (int,int)? initialEntry`, `final (int,int)? initialExit`. All default null/false.

In `_GameScreenState.initState()`, replace the line that creates the game:
```dart
_game = TdGame(
  levelId: widget.levelId,
  isEndless: widget.isEndless,
  isConstructor: widget.isConstructor,
);
```

After `_game.matchOutcome.addListener(_onOutcomeChanged);`, if constructor mode AND initial entry/exit provided AND no snapshot restore, schedule a microtask to call setEntryExit once the game is loaded:
```dart
if (widget.isConstructor && widget.initialEntry != null && widget.initialExit != null && !widget.restoreFromSavedSnapshot) {
  Future.microtask(() async {
    while (!_game.isLoaded) {
      await Future.delayed(const Duration(milliseconds: 16));
    }
    _game.setEntryExit(entry: widget.initialEntry!, exit: widget.initialExit!);
  });
}
```

For the START WAVES button overlay: in the `Stack` (we'll add one inside the Scaffold body if not present), place the button bottom-center of the game canvas area when `_game.isConstructor && !_game.wavesStarted`. Since `_game.wavesStarted` is a plain bool field (no notifier), wrap the button area in a `ValueListenableBuilder` listening to a new notifier OR just `setState` ourselves when calling `startWaves`. Simpler: add a `ValueNotifier<bool> wavesStartedNotifier` on TdGame, flip it inside `startWaves()`. Update the matching field declaration in TdGame.

Add in TdGame:
```dart
final ValueNotifier<bool> wavesStartedNotifier = ValueNotifier(false);
```
And in `startWaves()`: `wavesStartedNotifier.value = true;` after `_wavesStarted = true;`.

When restoring a Constructor snapshot in `restoreFromSnapshot`, if phase == "active" set both `_wavesStarted = true` and `wavesStartedNotifier.value = true`.

In GameScreen build, wrap the existing GameWidget cell in a Stack:
```dart
Expanded(
  child: KeyedSubtree(
    key: _gameKey,
    child: Stack(
      children: [
        GameWidget(game: _game),
        if (widget.isConstructor)
          ValueListenableBuilder<bool>(
            valueListenable: _game.wavesStartedNotifier,
            builder: (_, started, __) {
              if (started) return const SizedBox.shrink();
              return Positioned(
                left: 0, right: 0, bottom: 12,
                child: Center(
                  child: StartWavesButton(onTap: () {
                    _game.startWaves();
                  }),
                ),
              );
            },
          ),
      ],
    ),
  ),
),
```

Import `import '../ui/constructor/start_waves_button.dart';`.

### Step 3: Update `takeSnapshot` and `restoreFromSnapshot` in TdGame

In `takeSnapshot()`, add the constructor fields:
```dart
return MatchSnapshot(
  // ... existing fields
  entryCell: isConstructor ? _entryCell : null,
  exitCell: isConstructor ? _exitCell : null,
  constructorPhase: isConstructor ? (_wavesStarted ? 'active' : 'building') : null,
);
```

In `restoreFromSnapshot(MatchSnapshot snap)`, BEFORE the existing wave-restoration logic, handle constructor restore:
```dart
if (isConstructor && snap.entryCell != null && snap.exitCell != null) {
  setEntryExit(entry: snap.entryCell!, exit: snap.exitCell!);
  if (snap.constructorPhase == 'active') {
    _wavesStarted = true;
    wavesStartedNotifier.value = true;
  } else {
    // Still in building phase — stay paused at wave 0, no spawn.
    _wavesStarted = false;
    wavesStartedNotifier.value = false;
    // Override the wave-restart logic later.
  }
}
```

If `_wavesStarted` is false (still in building phase), DON'T run the wave restart block. Wrap the existing `final spec = isEndless ? _generateEndlessWave(state.currentWave) : _waves[_currentWaveIndex]; _waveRunner = WaveRunner(spec: spec); _isWaveActive = snap.isWaveActive; _interWaveDelay = snap.interWaveDelaySec;` in `if (!isConstructor || _wavesStarted) { ... }`.

After restoring towers, the snapshot's saved towers will have made cells blocked, so `_recomputePath` should be called once for constructor mode:
```dart
if (isConstructor) _recomputePath();
```
at the end of `restoreFromSnapshot`.

### Step 4: Verify

```
flutter analyze
flutter test
```
Expected: clean analyze, all tests pass. If `widget.initialEntry` triggers `unused_element` because no caller yet, MainMenu's wiring in Task 9 fixes that. If analyze is otherwise clean, commit.

### Step 5: Commit

```
git add lib/ui/constructor/start_waves_button.dart lib/game/game_screen.dart lib/game/td_game.dart
git commit -m "feat(game): GameScreen Constructor wiring — setEntryExit, START WAVES, snapshot restore"
```

---

## Task 9: MainMenu — add CONSTRUCTOR button

**Files:**
- Modify: `c:\dev\void_td\lib\ui\main_menu\main_menu_screen.dart`

### Step 1: Add CONSTRUCTOR button + slot helper

In `_MainMenuScreenState`, add (next to `_hasCampaignSave`/`_hasEndlessSave`):
```dart
bool _hasConstructorSave() {
  try {
    return SnapshotRepo.exists(SaveSlot.constructor);
  } catch (_) {
    return false;
  }
}
```

Update the existing helpers to use the new enum:
```dart
bool _hasCampaignSave() {
  try {
    return SnapshotRepo.exists(SaveSlot.campaign);
  } catch (_) {
    return false;
  }
}

bool _hasEndlessSave() {
  try {
    return SnapshotRepo.exists(SaveSlot.endless);
  } catch (_) {
    return false;
  }
}
```

Add `import '../../game/match/snapshot_repo.dart';` if not already; also add an import for `SaveSlot` (it's in the same file).
Add `import '../constructor/constructor_setup_screen.dart';`.

In `build`, compute `final hasConstructorSave = _hasConstructorSave();`.

Insert a CONSTRUCTOR button between ENDLESS and SETTINGS:
```dart
NeonButton(
  label: 'CONSTRUCTOR',
  color: AppColors.orange,
  onPressed: () async {
    if (hasConstructorSave) {
      // Auto-resume.
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const GameScreen(
          levelId: 0,
          isConstructor: true,
          restoreFromSavedSnapshot: true,
        ),
      ));
    } else {
      // Pick entry/exit first.
      final picked = await Navigator.of(context).push<((int, int), (int, int))>(
        MaterialPageRoute(builder: (_) => const ConstructorSetupScreen()),
      );
      if (picked == null || !mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GameScreen(
          levelId: 0,
          isConstructor: true,
          initialEntry: picked.$1,
          initialExit: picked.$2,
        ),
      ));
    }
    if (mounted) setState(() {});
  },
),
const SizedBox(height: 16),
```

### Step 2: Update CONTINUE button to use SaveSlot

Existing CONTINUE uses `SnapshotRepo.load(isEndless: false)` — change to `SnapshotRepo.load(SaveSlot.campaign)`. Same for ENDLESS button's `restoreFromSavedSnapshot: hasEndlessSave` — keep as is (boolean), GameScreen translates internally via its `_slot` getter.

### Step 3: Verify

```
flutter analyze
flutter test
```

### Step 4: Commit

```
git add lib/ui/main_menu/main_menu_screen.dart
git commit -m "feat(ui): MainMenu CONSTRUCTOR button with auto-resume / setup picker"
```

---

## Task 10: Final verification + tag + push

### Step 1: Full test pass

```
flutter test
flutter analyze
```
Expected: clean. All previous tests pass + ~6 new AStar tests + 2 new MatchSnapshot tests.

### Step 2: Tag and push

```
git tag stage-3-constructor
git push origin main --tags
```

### Step 3: Manual playtest (user)

User instructions:
- Pull and `flutter run` on Android
- From main menu, tap CONSTRUCTOR (orange)
- Setup screen: tap an edge cell → entry (cyan); tap another edge cell → exit (red); BEGIN
- Empty grid with entry + exit + dynamic path drawn between them
- Drag a tower from palette → path updates as you move; red highlight on cells that would fully block
- After placing 2-3 towers, tap START WAVES (orange button at bottom of canvas) → waves start
- Sell a tower mid-wave → enemies re-route on the fly
- Pause / Quit → CONSTRUCTOR save slot retained; on return, tap CONSTRUCTOR → resumes exact state
- Survive boss waves → enemies become progressively tougher (1.1× HP per boss cleared)

---

## Self-Review (controller before user playtest)

- 9 commits made, one per logical task?
- analyze clean, all tests pass?
- AStar tests cover empty grid / obstacle / unreachable / single-cell / canReach?
- MatchSnapshot tests include constructor round-trip?
- TdGame doesn't break Campaign/Endless — verify by running existing tests (level_loader_test, etc.)?
- MainMenu shows 5 buttons (or 6 if CONTINUE is present) without overflow on portrait?

## Done

After Task 10 verification, Stage 3 is complete. The game now has all three modes from the spec. Next: Stage 4 (Polish — audio, haptic, localization, balance pass).
