# VOID TD — Stage 1.5: UX polish (cell highlight + tower range preview)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Replace the blind tap-to-place with a press-and-hold preview: while finger is down, the targeted grid cell is highlighted (green = buildable, red = blocked), and a faint range circle previews the tower-to-be. On lift, if the cell is buildable, the tower is placed. Also: tapping an existing tower shows its range circle until the user taps elsewhere.

**Architecture:** Keep TdGame as the orchestrator but extract two new Flame components — `CellHighlight` and `RangeIndicator` — that TdGame mounts/unmounts in response to drag/tap events. Replace `TapCallbacks` with `DragCallbacks` (drag = press-hold-drag-release pattern in Flame). Tower placement happens on `onDragEnd`, not `onDragStart`.

**Tech Stack:** Same as Stage 1 — Flutter + Flame. No new deps.

**Spec reference:** [`docs/superpowers/specs/2026-05-21-tower-defense-mvp-design.md`](../specs/2026-05-21-tower-defense-mvp-design.md)

**Key UX decisions:**
- **Press-and-hold preview (A):** finger down anywhere on the field → highlight current cell + range circle preview. Move finger → highlight follows. Lift on a buildable cell → place tower. Lift outside grid or on a blocked cell → cancel.
- **Range visible at build-time AND when tower selected (E):** before placing, see the future range. After placing, tap the tower to see its range.
- **Color-coded availability (yes):**
  - cyan/green fill — buildable (not on path, not occupied, gold sufficient)
  - red fill — blocked (on path / occupied / not enough gold)
- **Tower selection:** tapping an existing tower selects it (shows range). Tap again or tap elsewhere → deselect.

**Working directory:** `c:\dev\void_td`. Platform Windows; bash and PowerShell available.

---

## File Structure changes

```
c:\dev\void_td\lib\game\
├── td_game.dart                                  // MODIFIED — DragCallbacks + selection state
├── components\
│   ├── tower.dart                                // MODIFIED — knows if selected
│   ├── cell_highlight.dart                       // NEW
│   └── range_indicator.dart                      // NEW
```

No test files added or changed in Stage 1.5 — these are all visual/interaction components; their correctness is verified by manual playtest.

---

## Task 1: CellHighlight component

**Files:**
- Create: `c:\dev\void_td\lib\game\components\cell_highlight.dart`

A square overlay drawn at a grid cell, with a colour mode (buildable/blocked). Mounted by TdGame while a drag is in progress.

- [ ] **Step 1: Implement**

Create `c:\dev\void_td\lib\game\components\cell_highlight.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

enum CellHighlightMode { buildable, blocked }

/// A square overlay snapped to a grid cell, drawn with a 2px border and a
/// translucent fill. Mode controls the colour.
class CellHighlight extends PositionComponent {
  CellHighlightMode mode;

  CellHighlight({
    required Vector2 worldPos,
    required double cellSize,
    this.mode = CellHighlightMode.buildable,
  }) : super(
          position: worldPos.clone(),
          size: Vector2.all(cellSize),
          anchor: Anchor.center,
        );

  @override
  void render(Canvas canvas) {
    final color = mode == CellHighlightMode.buildable
        ? AppColors.green
        : AppColors.red;
    final fill = Paint()..color = color.withValues(alpha: 0.18);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run (from `c:\dev\void_td`):
```
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**
```
git add lib/game/components/cell_highlight.dart
git commit -m "feat(game): add CellHighlight component"
```

---

## Task 2: RangeIndicator component

**Files:**
- Create: `c:\dev\void_td\lib\game\components\range_indicator.dart`

A circle centred on a world point with a configurable radius. Drawn with a 1px dashed neon stroke + a very faint fill. Used for both build-preview and selected-tower display.

- [ ] **Step 1: Implement**

Create `c:\dev\void_td\lib\game\components\range_indicator.dart`:
```dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Circular range visualisation: faint fill + 1px dashed border in cyan.
class RangeIndicator extends PositionComponent {
  double radius;
  Color color;

  RangeIndicator({
    required Vector2 worldPos,
    required this.radius,
    this.color = AppColors.cyan,
  }) : super(position: worldPos.clone(), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final fill = Paint()..color = color.withValues(alpha: 0.06);
    canvas.drawCircle(Offset.zero, radius, fill);

    // Dashed stroke: approximate with short arcs.
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashArcDeg = 6.0;
    const gapArcDeg = 4.0;
    const totalDeg = 360.0;
    final dashRad = dashArcDeg * math.pi / 180;
    final stepRad = (dashArcDeg + gapArcDeg) * math.pi / 180;
    final steps = (totalDeg / (dashArcDeg + gapArcDeg)).floor();
    for (var i = 0; i < steps; i++) {
      final start = i * stepRad;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        start,
        dashRad,
        false,
        stroke,
      );
    }
  }
}
```

- [ ] **Step 2: Verify**
```
flutter analyze
```

- [ ] **Step 3: Commit**
```
git add lib/game/components/range_indicator.dart
git commit -m "feat(game): add RangeIndicator component"
```

---

## Task 3: Replace TapCallbacks with DragCallbacks in TdGame

**Files:**
- Modify: `c:\dev\void_td\lib\game\td_game.dart`

This is the core behaviour change. We swap `TapCallbacks` for `DragCallbacks` (`onDragStart`, `onDragUpdate`, `onDragEnd`, `onDragCancel`), and handle a "tap" (drag with near-zero distance) inside `onDragEnd`. We also add selection state — a single `Tower? _selectedTower` plus its `RangeIndicator`.

Drag lifecycle:
- `onDragStart` — record initial cell, mount a `CellHighlight` + `RangeIndicator` preview, deselect any selected tower.
- `onDragUpdate` — recompute current cell, reposition the highlight/range, update colour (buildable/blocked).
- `onDragEnd` — if the final cell is buildable AND gold ≥ cost AND the drag was "short" (didn't move outside the grid for long, didn't scroll halfway across), place the tower. Always remove the preview.
- `onDragCancel` — remove the preview, do nothing else.

Tower selection:
- A "tap with no movement" that lands on an existing tower's cell → select that tower (mount a `RangeIndicator` next to it).
- Any other tap or drag → deselect.

- [ ] **Step 1: Replace `td_game.dart` with the new implementation**

Open `c:\dev\void_td\lib\game\td_game.dart` and replace its contents with:
```dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../data/level_one_config.dart';
import 'components/cell_highlight.dart';
import 'components/enemy.dart';
import 'components/range_indicator.dart';
import 'components/tower.dart';
import 'grid/grid_painter.dart';
import 'match/match_state.dart';
import 'path/path_renderer.dart';
import 'path/path_segment.dart';
import 'waves/wave_runner.dart';

class TdGame extends FlameGame with DragCallbacks {
  late final PathSegment path;
  late final WaveRunner wave;
  final List<Enemy> liveEnemies = [];
  final Map<(int, int), Tower> towersByCell = {};

  /// Drives the Flutter HUD.
  final ValueNotifier<MatchState> stateNotifier = ValueNotifier(
    MatchState(
      lives: LevelOneConfig.startingLives,
      gold: LevelOneConfig.startingGold,
    ),
  );

  MatchState get state => stateNotifier.value;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  late Vector2 _gridOrigin;
  late PositionComponent _world;

  // Live drag-preview state.
  CellHighlight? _previewHighlight;
  RangeIndicator? _previewRange;
  (int, int)? _previewCell;

  // Tower selection state.
  Tower? _selectedTower;
  RangeIndicator? _selectionRange;

  @override
  Future<void> onLoad() async {
    final grid = LevelOneConfig.grid;
    path = PathSegment(points: LevelOneConfig.pathPoints);
    wave = WaveRunner(
      count: LevelOneConfig.waveEnemyCount,
      spawnInterval: LevelOneConfig.waveSpawnDelaySec,
      startDelay: LevelOneConfig.waveStartDelaySec,
    );

    final offsetX = (size.x - grid.width) / 2;
    final offsetY = 80.0;
    _world = PositionComponent(position: Vector2(offsetX, offsetY));
    add(_world);
    _world.add(GridPainter(grid: grid));
    _world.add(PathRenderer(path: path));

    _gridOrigin = Vector2(offsetX, offsetY);

    state.nextWave();
    _notifyStateChanged();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state.isGameOver) return;

    final toSpawn = wave.tick(dt);
    for (var i = 0; i < toSpawn; i++) {
      final enemy = Enemy(
        path: path,
        speedPxPerSec: LevelOneConfig.enemySpeedPxPerSec,
        hp: LevelOneConfig.enemyHp,
        onReachedEnd: _onEnemyReachedEnd,
        onKilled: _onEnemyKilled,
      );
      liveEnemies.add(enemy);
      _world.add(enemy);
    }

    liveEnemies.removeWhere((e) => e.isRemoved);
  }

  void _onEnemyReachedEnd(Enemy e) {
    state.takeDamage(LevelOneConfig.enemyDamageToBase);
    _notifyStateChanged();
  }

  void _onEnemyKilled(Enemy e) {
    state.addGold(LevelOneConfig.enemyBounty);
    _notifyStateChanged();
  }

  void _notifyStateChanged() {
    final snap = MatchState(lives: state.lives, gold: state.gold);
    for (var i = 0; i < state.currentWave; i++) {
      snap.nextWave();
    }
    stateNotifier.value = snap;
  }

  // ---------------------------------------------------------------------------
  // Drag / tap handling
  // ---------------------------------------------------------------------------

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (state.isGameOver) return;
    _clearSelection();
    _showPreviewAt(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (state.isGameOver) return;
    _showPreviewAt(event.canvasEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final cell = _previewCell;
    _removePreview();
    if (state.isGameOver) return;
    if (cell == null) return;

    final (col, row) = cell;
    // If this cell already has a tower, treat the gesture as a selection.
    final existing = towersByCell[(col, row)];
    if (existing != null) {
      _selectTower(existing);
      return;
    }

    if (!_canBuildAt(col, row)) return;
    _placeTowerAt(col, row);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _removePreview();
  }

  // ---------------------------------------------------------------------------
  // Preview helpers
  // ---------------------------------------------------------------------------

  void _showPreviewAt(Vector2 canvasPos) {
    final local = canvasPos - _gridOrigin;
    final grid = LevelOneConfig.grid;
    final (col, row) = grid.worldToCell(local.x, local.y);

    if (!grid.contains(col, row)) {
      _removePreview();
      return;
    }
    _previewCell = (col, row);

    final centre = grid.cellCenter(col, row);
    final worldPos = Vector2(centre.dx, centre.dy);

    final buildable = _canBuildAt(col, row);
    final mode = buildable
        ? CellHighlightMode.buildable
        : CellHighlightMode.blocked;

    if (_previewHighlight == null) {
      _previewHighlight = CellHighlight(
        worldPos: worldPos,
        cellSize: grid.cellSize,
        mode: mode,
      );
      _world.add(_previewHighlight!);
    } else {
      _previewHighlight!.position = worldPos;
      _previewHighlight!.mode = mode;
    }

    if (_previewRange == null) {
      _previewRange = RangeIndicator(
        worldPos: worldPos,
        radius: LevelOneConfig.basicTowerRange,
      );
      _world.add(_previewRange!);
    } else {
      _previewRange!.position = worldPos;
    }
  }

  void _removePreview() {
    _previewHighlight?.removeFromParent();
    _previewHighlight = null;
    _previewRange?.removeFromParent();
    _previewRange = null;
    _previewCell = null;
  }

  bool _canBuildAt(int col, int row) {
    if (towersByCell.containsKey((col, row))) return false;
    if (_isOnPath(col, row)) return false;
    if (state.gold < LevelOneConfig.basicTowerCost) return false;
    return true;
  }

  void _placeTowerAt(int col, int row) {
    if (!state.spendGold(LevelOneConfig.basicTowerCost)) return;
    final grid = LevelOneConfig.grid;
    final centre = grid.cellCenter(col, row);
    final tower = Tower(
      worldPos: Vector2(centre.dx, centre.dy),
      range: LevelOneConfig.basicTowerRange,
      damage: LevelOneConfig.basicTowerDamage,
      fireRatePerSec: LevelOneConfig.basicTowerFireRatePerSec,
      projectileSpeed: LevelOneConfig.basicProjectileSpeed,
      enemiesProvider: () => liveEnemies,
    );
    towersByCell[(col, row)] = tower;
    _world.add(tower);
    _notifyStateChanged();
  }

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  void _selectTower(Tower tower) {
    _clearSelection();
    _selectedTower = tower;
    _selectionRange = RangeIndicator(
      worldPos: tower.position,
      radius: tower.range,
      color: const Color(0xFFFFFFFF),
    );
    _world.add(_selectionRange!);
  }

  void _clearSelection() {
    _selectionRange?.removeFromParent();
    _selectionRange = null;
    _selectedTower = null;
  }

  // ---------------------------------------------------------------------------
  // Path geometry
  // ---------------------------------------------------------------------------

  bool _isOnPath(int col, int row) {
    final grid = LevelOneConfig.grid;
    final centre = grid.cellCenter(col, row);
    final c = Vector2(centre.dx, centre.dy);
    final threshold = grid.cellSize * 0.6;
    for (var i = 1; i < path.points.length; i++) {
      if (_pointToSegmentDistance(c, path.points[i - 1], path.points[i]) <
          threshold) {
        return true;
      }
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
}
```

- [ ] **Step 2: Verify it compiles**
```
flutter analyze
```
Expected: `No issues found!`

If analyze flags `DragUpdateEvent.canvasEndPosition` as not found, the Flame version may use a different property — try `event.localEndPosition` or `event.localStartPosition + event.localDelta`. Pick whichever exists and is in canvas/local space, and report which one you used.

- [ ] **Step 3: Re-run tests just to make sure nothing else broke**
```
flutter test
```
Expected: all 20 tests still pass (none of them touched TdGame directly).

- [ ] **Step 4: Commit**
```
git add lib/game/td_game.dart
git commit -m "feat(game): press-and-hold tower placement with cell+range preview"
```

---

## Task 4: Manual playtest gate

This task is for the **human**, not for any subagent. Do not auto-mark it complete.

- [ ] **Step 1: Run the game on a connected Android device**

From `c:\dev\void_td`:
```
flutter run
```

- [ ] **Step 2: Verify the new UX (by hand)**

The human checks:
- Tap-and-hold an empty cell → a coloured square highlights the cell and a faint range circle appears centred on it.
- Drag the finger across the grid → highlight + range track the finger.
- Drag onto the path or onto an existing tower → highlight turns red, range stays visible but the tower can't be placed.
- Lift on a green (buildable) cell → tower appears, gold drops by 50.
- Lift on a red (blocked) cell → nothing happens, gold unchanged.
- Lift outside the grid → nothing happens.
- Tap (no drag) on an existing tower → a white range circle appears around it. Tap elsewhere or on another tower → previous selection clears, new one shows.
- All previous behaviour (enemies spawning, towers shooting, gold/lives counters) still works.

- [ ] **Step 3: Report findings to controller**

Once verified — say "Stage 1.5 verified" or list any issues so they can be fixed.

---

## Self-Review (controller checklist before final commit)

After Task 3 commits, controller should self-check:

- All three files (`cell_highlight.dart`, `range_indicator.dart`, `td_game.dart`) committed?
- `flutter analyze` clean across the whole project?
- `flutter test` shows 20/20 still passing?
- No code from earlier stages was inadvertently broken (Enemy/Projectile/Tower unchanged; Tower's API is read-only via the `range` field, which already existed)?

## Done

After Task 4 verification, Stage 1.5 is complete. Next: **Stage 2** — 5 towers × 2 branches, 4 enemy types + boss, full economy with farms ticking every second, pause/speed controls, save & resume via Hive.
