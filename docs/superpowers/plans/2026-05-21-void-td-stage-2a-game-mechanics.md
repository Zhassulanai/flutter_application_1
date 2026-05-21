# VOID TD — Stage 2a: Game Mechanics Core

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Turn the playable Stage 1 skeleton into a full TD match: 5 tower types each with 2 upgrade branches (budget 7 points), 4 enemy types + 1 boss, full economy (kills + passive per-wave + farms ticking per second + clean-wave bonus), pause + speed control (1×/2×/3×), tower selection panel with upgrades. Still ONE level (the existing level 1 path, slightly redesigned to follow TD best practice).

**Architecture:** Extract per-tower-type stat tables into a `TowersConfig` Dart class with branch upgrade trees. Extract per-enemy-type tables into `EnemiesConfig`. Pure-Dart `MatchState` extended with `farmGoldPerSec`, `cleanWavesCount`, `selectedTowerType`, `selectedPlacedTower`. New Flame components for the bottom palette UI and upgrade panel (rendered as Flutter widgets in the existing HUD area below the game canvas). Match speed control done by writing to `FlameGame.timeScale`. Pause done with `FlameGame.paused`.

**Tech Stack:** Same as Stage 1.5. No new packages.

**Spec reference:** [`docs/superpowers/specs/2026-05-21-tower-defense-mvp-design.md`](../specs/2026-05-21-tower-defense-mvp-design.md)

**Key decisions locked in:**
- Tower icons (from icon-picker brainstorm): **Basic Shot** = circle outline + filled dot (cyan), **Splash** = 8-ray explosion glyph (magenta), **Sniper** = circle with crosshair (yellow), **Slow** = clock face — circle + 2 lines (purple), **Farm** = circle with `$` (green).
- "+30" gold popup on a clean wave — small cyan text, 1.5s fade-out. NO word "PERFECT", per user's minimalism preference.
- Upgrade budget shown as a row of 7 dots (filled = spent, hollow = remaining). NO text counter.
- 5 towers × 2 branches × 5 levels each, **combined cap of 7 points across both branches** on any single tower.
- Any tower can damage any enemy. Boss has immunity ONLY to the Slow status effect (still takes damage from Slow tower's projectile).
- All 5 towers available from the start of Stage 2a (gradual unlock by level is a Stage 2b concern, not 2a — 2a has one level).

**Layout (portrait):**

```
┌───────────────────────────────┐
│  HUD: WAVE · LIVES · GOLD · ⏸ │   ← existing strip, ⏸ becomes functional
├───────────────────────────────┤
│                               │
│         GAME FIELD            │
│                               │
├───────────────────────────────┤
│  [1×] [2×] [3×]   $ +X/sec    │   ← NEW speed bar + farms income indicator
├───────────────────────────────┤
│  [B][S][Sn][Sl][F]            │   ← NEW palette (when nothing selected)
│        OR                     │
│  Branch A ●●●○○  Branch B ●●○○│   ← OR upgrade panel (when tower selected)
│  ●●●●●○○ budget   SELL $70    │
└───────────────────────────────┘
```

**Working directory:** `c:\dev\void_td`. Platform Windows.

---

## File Structure

```
c:\dev\void_td\lib\
├── data\
│   ├── level_one_config.dart                    // MODIFIED: keep, but reference TowersConfig/EnemiesConfig
│   ├── towers_config.dart                       // NEW: 5 tower types + 2 branches × 5 levels each
│   └── enemies_config.dart                      // NEW: 4 enemy types + boss
│
├── game\
│   ├── td_game.dart                             // MODIFIED: timeScale, paused, palette/selection state, farms tick, perfect-wave bonus
│   ├── match\
│   │   ├── match_state.dart                     // MODIFIED: farmGoldPerSec, cleanWavesCount, lostThisWave
│   │   └── hud.dart                             // MODIFIED: pause button works
│   ├── components\
│   │   ├── tower.dart                           // MODIFIED: type-aware (TowerType enum), branchA/branchB points, recomputed stats
│   │   ├── enemy.dart                           // MODIFIED: EnemyType, slow-status field
│   │   ├── projectile.dart                      // MODIFIED: type-specific behaviour (splash AOE, slow status, sniper crit)
│   │   ├── farm.dart                            // NEW: variant of tower that ticks gold instead of shooting
│   │   ├── tower_icon_painter.dart              // NEW: shared CustomPainter routines for the 5 tower glyphs
│   │   └── gold_popup.dart                      // NEW: +N floating text component
│   └── waves\
│       └── wave_runner.dart                     // MODIFIED: accept full wave spec (List<EnemySpawn>) instead of count+interval
│
└── ui\
    └── match\
        ├── tower_palette.dart                   // NEW: bottom Flutter widget with 5 icons + prices
        ├── tower_upgrade_panel.dart             // NEW: bottom Flutter widget shown when tower selected
        ├── speed_bar.dart                       // NEW: 1×/2×/3× + farm income
        └── budget_dots.dart                     // NEW: row of 7 dots (filled/hollow)
```

Tests:
```
c:\dev\void_td\test\
├── towers_config_test.dart                      // NEW: branch upgrade stats compute correctly
├── match_state_test.dart                        // MODIFIED: farm tick adds gold, perfect-wave bonus
├── wave_runner_test.dart                        // MODIFIED: spec-based scheduling
└── enemy_slow_test.dart                         // NEW: slow status reduces effective speed and boss is immune
```

---

## Task 1: Tower types and config tables

**Files:**
- Create: `c:\dev\void_td\lib\data\towers_config.dart`
- Create: `c:\dev\void_td\test\towers_config_test.dart`

5 towers, each has base stats + 2 branches × 5 levels of additive/multiplicative deltas. Combined point cap per tower = 7 (e.g. 5+2, 4+3, 3+3, etc.) — config does NOT enforce the cap; that's a runtime concern in MatchState/Tower (Task 9).

### Step 1: Write the failing test FIRST

Create `test\towers_config_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/data/towers_config.dart';

void main() {
  group('TowersConfig — Basic Shot', () {
    test('base stats match spec', () {
      final s = TowersConfig.statsFor(TowerType.basic, branchA: 0, branchB: 0);
      expect(s.damage, 10);
      expect(s.range, 120);
      expect(s.fireRatePerSec, 1.0);
      expect(s.projectileSpeed, 300);
      expect(s.cost, 50);
    });

    test('branch A (range+rate) at level 5: +60% range, +100% fire rate', () {
      final s = TowersConfig.statsFor(TowerType.basic, branchA: 5, branchB: 0);
      expect(s.range, closeTo(120 * 1.6, 0.001));
      expect(s.fireRatePerSec, closeTo(2.0, 0.001));
      // damage unchanged
      expect(s.damage, 10);
    });

    test('branch B (crit) at level 5: +50% damage, 25% crit ×2', () {
      final s = TowersConfig.statsFor(TowerType.basic, branchA: 0, branchB: 5);
      expect(s.damage, closeTo(15, 0.001));
      expect(s.critChance, closeTo(0.25, 0.001));
      expect(s.critMultiplier, 2.0);
    });
  });

  group('TowersConfig — Splash', () {
    test('base AOE radius is 40, branch A maxes at 80', () {
      expect(
          TowersConfig.statsFor(TowerType.splash, branchA: 0, branchB: 0)
              .splashRadius,
          40);
      expect(
          TowersConfig.statsFor(TowerType.splash, branchA: 5, branchB: 0)
              .splashRadius,
          80);
    });
    test('branch B applies burn DoT (3 dmg/sec for 3s) at level 5', () {
      final s =
          TowersConfig.statsFor(TowerType.splash, branchA: 0, branchB: 5);
      expect(s.burnDamagePerSec, closeTo(3, 0.001));
      expect(s.burnDurationSec, closeTo(3, 0.001));
    });
  });

  group('TowersConfig — Sniper', () {
    test('base damage 40, range 200, fire rate 0.4/sec', () {
      final s = TowersConfig.statsFor(TowerType.sniper, branchA: 0, branchB: 0);
      expect(s.damage, 40);
      expect(s.range, 200);
      expect(s.fireRatePerSec, closeTo(0.4, 0.001));
    });
    test('branch A armor pierce at level 5 = 1.0 (full pierce)', () {
      final s = TowersConfig.statsFor(TowerType.sniper, branchA: 5, branchB: 0);
      expect(s.armorPierce, closeTo(1.0, 0.001));
    });
  });

  group('TowersConfig — Slow', () {
    test('base slow factor 0.6 (40% slow) for 2s', () {
      final s = TowersConfig.statsFor(TowerType.slow, branchA: 0, branchB: 0);
      expect(s.slowFactor, closeTo(0.6, 0.001));
      expect(s.slowDurationSec, closeTo(2, 0.001));
    });
    test('branch A at level 5 = 95% slow (factor 0.05)', () {
      final s = TowersConfig.statsFor(TowerType.slow, branchA: 5, branchB: 0);
      expect(s.slowFactor, closeTo(0.05, 0.001));
    });
  });

  group('TowersConfig — Farm', () {
    test('base income 5 gold/sec, cost 60', () {
      final s = TowersConfig.statsFor(TowerType.farm, branchA: 0, branchB: 0);
      expect(s.farmGoldPerSec, 5);
      expect(s.cost, 60);
    });
    test('branch A at level 5: 12 gold/sec', () {
      final s = TowersConfig.statsFor(TowerType.farm, branchA: 5, branchB: 0);
      expect(s.farmGoldPerSec, 12);
    });
  });

  group('Upgrade cost ladder', () {
    test('branch upgrades follow 30/50/80/120/180 ladder for Basic Shot', () {
      expect(TowersConfig.upgradeCost(TowerType.basic, currentLevel: 0), 30);
      expect(TowersConfig.upgradeCost(TowerType.basic, currentLevel: 1), 50);
      expect(TowersConfig.upgradeCost(TowerType.basic, currentLevel: 2), 80);
      expect(TowersConfig.upgradeCost(TowerType.basic, currentLevel: 3), 120);
      expect(TowersConfig.upgradeCost(TowerType.basic, currentLevel: 4), 180);
      // already at max: no upgrade available
      expect(() => TowersConfig.upgradeCost(TowerType.basic, currentLevel: 5),
          throwsA(isA<ArgumentError>()));
    });
  });
}
```

### Step 2: Verify the tests fail

Run:
```
flutter test test/towers_config_test.dart
```
Expected: FAIL — TowersConfig and TowerType don't exist yet.

### Step 3: Implement

Create `c:\dev\void_td\lib\data\towers_config.dart`:
```dart
/// Five tower archetypes for VOID TD.
enum TowerType { basic, splash, sniper, slow, farm }

/// Fully-resolved tower stats after branch upgrades are applied.
class TowerStats {
  final int cost;
  final double range;
  final double damage;
  final double fireRatePerSec;
  final double projectileSpeed;

  // Basic branch B (crit)
  final double critChance;       // 0..1
  final double critMultiplier;   // multiplier on damage when crit

  // Splash branches
  final double splashRadius;      // 0 if not splash
  final double burnDamagePerSec;  // 0 if no burn
  final double burnDurationSec;

  // Sniper branches
  final double armorPierce;       // 0..1; 1 ignores armor entirely
  final int chainTargets;         // 0..N extra targets

  // Slow branches
  final double slowFactor;        // multiplier on enemy speed; 1 = no slow
  final double slowDurationSec;
  final double slowAuraRadius;    // 0 if no aura

  // Farm
  final int farmGoldPerSec;       // 0 unless farm

  const TowerStats({
    required this.cost,
    required this.range,
    required this.damage,
    required this.fireRatePerSec,
    required this.projectileSpeed,
    this.critChance = 0,
    this.critMultiplier = 1,
    this.splashRadius = 0,
    this.burnDamagePerSec = 0,
    this.burnDurationSec = 0,
    this.armorPierce = 0,
    this.chainTargets = 0,
    this.slowFactor = 1,
    this.slowDurationSec = 0,
    this.slowAuraRadius = 0,
    this.farmGoldPerSec = 0,
  });
}

/// Tower stat lookup and upgrade cost schedule.
class TowersConfig {
  /// Cost for a single tower of the given type with no upgrades.
  static int baseCost(TowerType type) {
    switch (type) {
      case TowerType.basic:
        return 50;
      case TowerType.splash:
        return 80;
      case TowerType.sniper:
        return 120;
      case TowerType.slow:
        return 150;
      case TowerType.farm:
        return 60;
    }
  }

  /// Cost to upgrade ANY branch from currentLevel (0..4) to currentLevel+1.
  /// Same ladder for all tower types in Stage 2a.
  static int upgradeCost(TowerType type, {required int currentLevel}) {
    const ladder = [30, 50, 80, 120, 180]; // 0->1, 1->2, 2->3, 3->4, 4->5
    if (currentLevel < 0 || currentLevel >= ladder.length) {
      throw ArgumentError('currentLevel must be in 0..4, got $currentLevel');
    }
    return ladder[currentLevel];
  }

  /// Fully-resolved stats for `type` with `branchA` and `branchB` levels (0..5).
  static TowerStats statsFor(
    TowerType type, {
    required int branchA,
    required int branchB,
  }) {
    assert(branchA >= 0 && branchA <= 5);
    assert(branchB >= 0 && branchB <= 5);
    switch (type) {
      case TowerType.basic:
        return _basic(branchA, branchB);
      case TowerType.splash:
        return _splash(branchA, branchB);
      case TowerType.sniper:
        return _sniper(branchA, branchB);
      case TowerType.slow:
        return _slow(branchA, branchB);
      case TowerType.farm:
        return _farm(branchA, branchB);
    }
  }

  // Basic Shot: A = range + fire rate ; B = crit
  static TowerStats _basic(int a, int b) {
    final rangeMult = 1.0 + 0.12 * a;     // +60% at lvl 5
    final rateMult = 1.0 + 0.20 * a;      // +100% at lvl 5
    final dmgMult = 1.0 + 0.10 * b;       // +50% at lvl 5
    final critChance = 0.05 * b;          // 25% at lvl 5
    return TowerStats(
      cost: baseCost(TowerType.basic),
      range: 120 * rangeMult,
      damage: 10 * dmgMult,
      fireRatePerSec: 1.0 * rateMult,
      projectileSpeed: 300,
      critChance: critChance,
      critMultiplier: b > 0 ? 2.0 : 1.0,
    );
  }

  // Splash: A = radius ; B = burn DoT
  static TowerStats _splash(int a, int b) {
    final radius = 40.0 + 8.0 * a;        // 80 at lvl 5
    return TowerStats(
      cost: baseCost(TowerType.splash),
      range: 110,
      damage: 8,
      fireRatePerSec: 0.8,
      projectileSpeed: 260,
      splashRadius: radius,
      burnDamagePerSec: 0.6 * b,          // 3 at lvl 5
      burnDurationSec: b > 0 ? 3.0 : 0,
    );
  }

  // Sniper: A = armor pierce ; B = chain
  static TowerStats _sniper(int a, int b) {
    return TowerStats(
      cost: baseCost(TowerType.sniper),
      range: 200,
      damage: 40,
      fireRatePerSec: 0.4,
      projectileSpeed: 420,
      armorPierce: 0.2 * a,               // 1.0 at lvl 5
      chainTargets: b ~/ 2 + (b > 0 ? 1 : 0),    // 1,2,2,3,3 across 1..5
    );
  }

  // Slow: A = stronger slow ; B = aura
  static TowerStats _slow(int a, int b) {
    return TowerStats(
      cost: baseCost(TowerType.slow),
      range: 140,
      damage: 4,
      fireRatePerSec: 0.8,
      projectileSpeed: 280,
      slowFactor: 0.6 - 0.11 * a,         // 0.05 at lvl 5 (= 95% slow)
      slowDurationSec: 2.0 + 0.4 * a,     // 4 at lvl 5
      slowAuraRadius: b > 0 ? 60.0 + 8.0 * b : 0, // 100 at lvl 5
    );
  }

  // Farm: A = more income ; B = cheaper
  static TowerStats _farm(int a, int b) {
    final income = 5 + a + (a > 2 ? 1 : 0) + (a > 4 ? 1 : 0); // 5,6,7,8,10,12
    final cost = (60 * (1.0 - 0.15 * b)).round();             // 60..15
    return TowerStats(
      cost: cost,
      range: 0,
      damage: 0,
      fireRatePerSec: 0,
      projectileSpeed: 0,
      farmGoldPerSec: income,
    );
  }
}
```

### Step 4: Run tests to verify all pass

Run:
```
flutter test test/towers_config_test.dart
```
Expected: all tests pass. If a stat formula doesn't match the test (e.g. farm level-5 income), adjust the formula until it does. Tests are the source of truth.

### Step 5: Commit

```
git add lib/data/towers_config.dart test/towers_config_test.dart
git commit -m "feat(data): add TowersConfig with 5 types and branch upgrade tables"
```

---

## Task 2: Enemy types and config table

**Files:**
- Create: `c:\dev\void_td\lib\data\enemies_config.dart`

Pure config; no failing test needed (just constants). Tests come in Task 3 (slow status test).

### Step 1: Implement

Create `c:\dev\void_td\lib\data\enemies_config.dart`:
```dart
/// Five enemy archetypes for VOID TD Stage 2a.
enum EnemyType { grunt, fast, tank, swarm, boss }

class EnemyStats {
  final EnemyType type;
  final double hp;
  final double speedPxPerSec;
  final int bounty;
  final int damageToBase;
  final double armor;                 // 0..1 damage reduction
  final bool immuneToSlow;

  const EnemyStats({
    required this.type,
    required this.hp,
    required this.speedPxPerSec,
    required this.bounty,
    required this.damageToBase,
    this.armor = 0,
    this.immuneToSlow = false,
  });
}

class EnemiesConfig {
  static EnemyStats statsFor(EnemyType type) {
    switch (type) {
      case EnemyType.grunt:
        return const EnemyStats(
          type: EnemyType.grunt,
          hp: 50,
          speedPxPerSec: 60,
          bounty: 5,
          damageToBase: 1,
        );
      case EnemyType.fast:
        return const EnemyStats(
          type: EnemyType.fast,
          hp: 25,
          speedPxPerSec: 110,
          bounty: 4,
          damageToBase: 1,
        );
      case EnemyType.tank:
        return const EnemyStats(
          type: EnemyType.tank,
          hp: 250,
          speedPxPerSec: 35,
          bounty: 15,
          damageToBase: 3,
          armor: 0.4,
        );
      case EnemyType.swarm:
        return const EnemyStats(
          type: EnemyType.swarm,
          hp: 10,
          speedPxPerSec: 70,
          bounty: 1,
          damageToBase: 1,
        );
      case EnemyType.boss:
        return const EnemyStats(
          type: EnemyType.boss,
          hp: 1200,
          speedPxPerSec: 30,
          bounty: 100,
          damageToBase: 10,
          armor: 0.3,
          immuneToSlow: true,
        );
    }
  }
}
```

### Step 2: Verify compile

```
flutter analyze
```

### Step 3: Commit

```
git add lib/data/enemies_config.dart
git commit -m "feat(data): add EnemiesConfig with 4 enemies + boss"
```

---

## Task 3: Extend Enemy with type, armor, slow status (with tests)

**Files:**
- Modify: `c:\dev\void_td\lib\game\components\enemy.dart`
- Create: `c:\dev\void_td\test\enemy_slow_test.dart`

`Enemy` becomes type-aware. The slow status is a transient effect: a tower applies `applySlow(factor, duration)`; while active the enemy's effective speed is `baseSpeed * factor`. Boss ignores slow.

### Step 1: Write failing test

Create `test\enemy_slow_test.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/data/enemies_config.dart';
import 'package:void_td/game/components/enemy.dart';
import 'package:void_td/game/path/path_segment.dart';

void main() {
  final straightPath = PathSegment(points: [
    Vector2(0, 0),
    Vector2(600, 0),
  ]);

  Enemy makeEnemy(EnemyType type) {
    final stats = EnemiesConfig.statsFor(type);
    return Enemy(
      type: type,
      stats: stats,
      path: straightPath,
      onReachedEnd: (_) {},
      onKilled: (_) {},
    );
  }

  group('Enemy slow status', () {
    test('grunt with no slow walks at base speed', () {
      final e = makeEnemy(EnemyType.grunt);
      expect(e.effectiveSpeedPxPerSec, EnemiesConfig.statsFor(EnemyType.grunt).speedPxPerSec);
    });

    test('applying 0.5 slow halves the speed', () {
      final e = makeEnemy(EnemyType.grunt);
      e.applySlow(factor: 0.5, durationSec: 2);
      expect(e.effectiveSpeedPxPerSec, EnemiesConfig.statsFor(EnemyType.grunt).speedPxPerSec * 0.5);
    });

    test('slow expires after its duration', () {
      final e = makeEnemy(EnemyType.grunt);
      e.applySlow(factor: 0.5, durationSec: 1);
      e.tickStatus(0.5);
      expect(e.effectiveSpeedPxPerSec, EnemiesConfig.statsFor(EnemyType.grunt).speedPxPerSec * 0.5);
      e.tickStatus(0.6); // total 1.1s past
      expect(e.effectiveSpeedPxPerSec, EnemiesConfig.statsFor(EnemyType.grunt).speedPxPerSec);
    });

    test('boss is immune to slow', () {
      final e = makeEnemy(EnemyType.boss);
      e.applySlow(factor: 0.1, durationSec: 5);
      expect(e.effectiveSpeedPxPerSec, EnemiesConfig.statsFor(EnemyType.boss).speedPxPerSec);
    });

    test('stronger slow overrides weaker; weaker does not override stronger', () {
      final e = makeEnemy(EnemyType.grunt);
      e.applySlow(factor: 0.7, durationSec: 5);
      e.applySlow(factor: 0.3, durationSec: 1); // stronger
      expect(e.effectiveSpeedPxPerSec, EnemiesConfig.statsFor(EnemyType.grunt).speedPxPerSec * 0.3);
      e.tickStatus(1.1); // stronger expired
      expect(e.effectiveSpeedPxPerSec, EnemiesConfig.statsFor(EnemyType.grunt).speedPxPerSec * 0.7);
    });
  });

  group('Enemy damage taking', () {
    test('tank with armor 0.4 takes 6 damage from a 10-damage hit (no pierce)', () {
      final e = makeEnemy(EnemyType.tank);
      e.takeDamage(amount: 10, armorPierce: 0);
      expect(e.hp, 250 - 6);
    });

    test('tank with armor 0.4 takes 8 damage with 0.5 pierce', () {
      // effective armor = 0.4 * (1 - 0.5) = 0.2; damage = 10 * (1 - 0.2) = 8
      final e = makeEnemy(EnemyType.tank);
      e.takeDamage(amount: 10, armorPierce: 0.5);
      expect(e.hp, 250 - 8);
    });

    test('full pierce ignores armor entirely', () {
      final e = makeEnemy(EnemyType.tank);
      e.takeDamage(amount: 10, armorPierce: 1.0);
      expect(e.hp, 250 - 10);
    });
  });
}
```

### Step 2: Verify tests fail

```
flutter test test/enemy_slow_test.dart
```
Expected: FAIL — Enemy doesn't yet have `type`, `stats`, `applySlow`, `tickStatus`, `effectiveSpeedPxPerSec`, parameter named `amount`/`armorPierce` on takeDamage.

### Step 3: Replace `enemy.dart`

Open `c:\dev\void_td\lib\game\components\enemy.dart` and replace its contents:
```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../data/enemies_config.dart';
import '../path/path_segment.dart';

/// Active slow effect on an enemy. Multiple may be queued; the one with the
/// lowest `factor` (= strongest slow) wins while it's still active.
class _SlowEffect {
  final double factor;
  double remainingSec;
  _SlowEffect(this.factor, this.remainingSec);
}

class Enemy extends PositionComponent {
  final EnemyType type;
  final EnemyStats stats;
  final PathSegment path;
  final void Function(Enemy self) onReachedEnd;
  final void Function(Enemy self) onKilled;

  double hp;
  final double maxHp;
  double _distanceTravelled = 0;
  bool _removed = false;

  final List<_SlowEffect> _slows = [];

  // Burn DoT (from Splash B branch).
  double _burnRemainingSec = 0;
  double _burnDamagePerSec = 0;

  Enemy({
    required this.type,
    required this.stats,
    required this.path,
    required this.onReachedEnd,
    required this.onKilled,
  })  : hp = stats.hp,
        maxHp = stats.hp,
        super(size: Vector2.all(_renderSizeFor(type)), anchor: Anchor.center);

  static double _renderSizeFor(EnemyType t) {
    switch (t) {
      case EnemyType.grunt:
      case EnemyType.fast:
        return 12;
      case EnemyType.swarm:
        return 8;
      case EnemyType.tank:
        return 18;
      case EnemyType.boss:
        return 28;
    }
  }

  /// Current effective speed after slow effects.
  double get effectiveSpeedPxPerSec {
    if (stats.immuneToSlow || _slows.isEmpty) return stats.speedPxPerSec;
    final strongest = _slows.map((s) => s.factor).reduce((a, b) => a < b ? a : b);
    return stats.speedPxPerSec * strongest;
  }

  /// Reduce status timers; remove expired effects. Safe to call in tests
  /// without a Flame engine.
  void tickStatus(double dt) {
    for (final s in _slows) {
      s.remainingSec -= dt;
    }
    _slows.removeWhere((s) => s.remainingSec <= 0);
    if (_burnRemainingSec > 0) {
      _burnRemainingSec -= dt;
      // hp drained inside game loop, not in tickStatus, to avoid tests
      // accidentally killing enemies via tickStatus.
    }
  }

  void applySlow({required double factor, required double durationSec}) {
    if (stats.immuneToSlow) return;
    _slows.add(_SlowEffect(factor, durationSec));
  }

  void applyBurn({required double damagePerSec, required double durationSec}) {
    if (durationSec <= _burnRemainingSec) return; // keep the longer one
    _burnRemainingSec = durationSec;
    _burnDamagePerSec = damagePerSec;
  }

  @override
  void onLoad() {
    position = path.positionAt(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_removed) return;
    tickStatus(dt);
    if (_burnRemainingSec > 0) {
      hp -= _burnDamagePerSec * dt;
      if (hp <= 0) {
        _removed = true;
        onKilled(this);
        removeFromParent();
        return;
      }
    }
    _distanceTravelled += effectiveSpeedPxPerSec * dt;
    final progress = (_distanceTravelled / path.totalLength).clamp(0.0, 1.0);
    position = path.positionAt(progress);
    if (progress >= 1.0) {
      _removed = true;
      onReachedEnd(this);
      removeFromParent();
    }
  }

  void takeDamage({required double amount, required double armorPierce}) {
    if (_removed) return;
    final effArmor = stats.armor * (1 - armorPierce.clamp(0.0, 1.0));
    final taken = amount * (1 - effArmor);
    hp -= taken;
    if (hp <= 0) {
      _removed = true;
      onKilled(this);
      removeFromParent();
    }
  }

  Color _baseColor() {
    switch (type) {
      case EnemyType.grunt:
        return AppColors.red;
      case EnemyType.fast:
        return AppColors.yellow;
      case EnemyType.tank:
        return AppColors.purple;
      case EnemyType.swarm:
        return AppColors.red;
      case EnemyType.boss:
        return AppColors.magenta;
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = _baseColor();
    final r = size.x / 2;
    canvas.drawCircle(Offset(r, r), r * 0.85, paint);

    // hp bar
    final barWidth = size.x + 4;
    final barHeight = 2.0;
    final bgRect = Rect.fromLTWH(-2, -8, barWidth, barHeight);
    final fgRect = Rect.fromLTWH(-2, -8, barWidth * (hp / maxHp), barHeight);
    canvas.drawRect(bgRect, Paint()..color = const Color(0xFF3A1A1A));
    canvas.drawRect(fgRect, paint);

    // slow indicator: faint blue ring
    if (_slows.isNotEmpty) {
      final ring = Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(Offset(r, r), r * 0.95, ring);
    }
  }
}
```

### Step 4: Run tests

```
flutter test test/enemy_slow_test.dart
```
Expected: all 8 tests pass.

Also run the full suite once — Stage 1 tests may break because of the changed `takeDamage` signature:
```
flutter test
```

If `wave_runner_test.dart` and others pass but other tests fail because they use the old `takeDamage(double)` form, leave them broken for now — Task 5 modifies the call sites in `Projectile`/`Tower`. We'll re-run after Task 5.

### Step 5: Commit

```
git add lib/game/components/enemy.dart test/enemy_slow_test.dart
git commit -m "feat(game): Enemy supports types, armor, slow status, burn DoT"
```

---

## Task 4: WaveRunner — wave spec scheduling

**Files:**
- Modify: `c:\dev\void_td\lib\game\waves\wave_runner.dart`
- Modify: `c:\dev\void_td\test\wave_runner_test.dart`

Stage 1's `WaveRunner` only spawned one enemy type at a constant interval. Stage 2 needs varied composition: e.g. 5 Grunts spaced 1s apart, then 4 Fast spaced 0.5s after a 2s gap. Model that as a list of `EnemySpawn`s consumed in order.

### Step 1: Replace the test file

Replace `test\wave_runner_test.dart` with:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/data/enemies_config.dart';
import 'package:void_td/game/waves/wave_runner.dart';

void main() {
  group('WaveRunner with spec', () {
    test('emits spawns at the absolute times in the spec', () {
      final w = WaveRunner(spec: [
        const EnemySpawn(type: EnemyType.grunt, atSec: 0),
        const EnemySpawn(type: EnemyType.grunt, atSec: 1),
        const EnemySpawn(type: EnemyType.fast, atSec: 2),
      ]);
      expect(w.tick(0.5), [EnemyType.grunt]);
      expect(w.tick(0.4), []);                       // t=0.9
      expect(w.tick(0.2), [EnemyType.grunt]);        // t=1.1 (>=1.0)
      expect(w.tick(1.0), [EnemyType.fast]);         // t=2.1
      expect(w.isDone, isTrue);
    });

    test('handles simultaneous spawns', () {
      final w = WaveRunner(spec: [
        const EnemySpawn(type: EnemyType.swarm, atSec: 0),
        const EnemySpawn(type: EnemyType.swarm, atSec: 0),
        const EnemySpawn(type: EnemyType.swarm, atSec: 0),
      ]);
      expect(w.tick(0.1), [
        EnemyType.swarm,
        EnemyType.swarm,
        EnemyType.swarm,
      ]);
      expect(w.isDone, isTrue);
    });

    test('isDone false until all spec entries emitted', () {
      final w = WaveRunner(spec: [
        const EnemySpawn(type: EnemyType.grunt, atSec: 0),
        const EnemySpawn(type: EnemyType.grunt, atSec: 5),
      ]);
      expect(w.tick(0), [EnemyType.grunt]);
      expect(w.isDone, isFalse);
      expect(w.tick(5), [EnemyType.grunt]);
      expect(w.isDone, isTrue);
    });
  });
}
```

### Step 2: Verify fail

```
flutter test test/wave_runner_test.dart
```
Expected: FAIL — old signature.

### Step 3: Replace `wave_runner.dart`

Replace `c:\dev\void_td\lib\game\waves\wave_runner.dart`:
```dart
import '../../data/enemies_config.dart';

class EnemySpawn {
  final EnemyType type;
  final double atSec;
  const EnemySpawn({required this.type, required this.atSec});
}

/// Schedules enemy spawns from a static spec. `tick(dt)` returns the list of
/// EnemyTypes to spawn this frame.
class WaveRunner {
  final List<EnemySpawn> spec;
  double _elapsed = 0;
  int _nextIndex = 0;

  WaveRunner({required this.spec});

  bool get isDone => _nextIndex >= spec.length;
  int get remaining => spec.length - _nextIndex;

  List<EnemyType> tick(double dt) {
    if (isDone) return const [];
    _elapsed += dt;
    final spawned = <EnemyType>[];
    while (!isDone && spec[_nextIndex].atSec <= _elapsed) {
      spawned.add(spec[_nextIndex].type);
      _nextIndex++;
    }
    return spawned;
  }
}
```

### Step 4: Run tests

```
flutter test test/wave_runner_test.dart
```
Expected: 3 tests pass.

### Step 5: Commit

```
git add lib/game/waves/wave_runner.dart test/wave_runner_test.dart
git commit -m "feat(game): WaveRunner now consumes a List<EnemySpawn> spec"
```

---

## Task 5: Projectile — type-aware effects (splash AOE, slow status, burn DoT, crit)

**Files:**
- Modify: `c:\dev\void_td\lib\game\components\projectile.dart`

Projectile now carries the TowerType + relevant stats, and on hit applies all appropriate effects.

### Step 1: Replace `projectile.dart`

Open `c:\dev\void_td\lib\game\components\projectile.dart` and replace its contents:
```dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../data/towers_config.dart';
import 'enemy.dart';

class Projectile extends PositionComponent {
  final TowerType ownerType;
  final TowerStats stats;
  final Enemy target;
  final List<Enemy> Function() enemiesProvider;

  bool _spent = false;
  static final _rng = math.Random();

  Projectile({
    required Vector2 start,
    required this.ownerType,
    required this.stats,
    required this.target,
    required this.enemiesProvider,
  }) : super(position: start.clone(), size: Vector2.all(4), anchor: Anchor.center);

  Color get _color {
    switch (ownerType) {
      case TowerType.basic:
        return AppColors.cyan;
      case TowerType.splash:
        return AppColors.magenta;
      case TowerType.sniper:
        return AppColors.yellow;
      case TowerType.slow:
        return AppColors.purple;
      case TowerType.farm:
        return AppColors.green;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_spent) return;
    if (target.isRemoved) {
      _spent = true;
      removeFromParent();
      return;
    }
    final to = target.position - position;
    final dist = to.length;
    final step = stats.projectileSpeed * dt;
    if (step >= dist) {
      _onHit();
      _spent = true;
      removeFromParent();
      return;
    }
    position += to.normalized() * step;
  }

  void _onHit() {
    var damage = stats.damage;
    if (stats.critChance > 0 && _rng.nextDouble() < stats.critChance) {
      damage *= stats.critMultiplier;
    }
    target.takeDamage(amount: damage, armorPierce: stats.armorPierce);

    if (stats.splashRadius > 0) {
      for (final other in enemiesProvider()) {
        if (other == target || other.isRemoved) continue;
        if (other.position.distanceTo(target.position) <= stats.splashRadius) {
          other.takeDamage(amount: damage * 0.6, armorPierce: stats.armorPierce);
          if (stats.burnDamagePerSec > 0) {
            other.applyBurn(
                damagePerSec: stats.burnDamagePerSec,
                durationSec: stats.burnDurationSec);
          }
        }
      }
      if (stats.burnDamagePerSec > 0) {
        target.applyBurn(
            damagePerSec: stats.burnDamagePerSec,
            durationSec: stats.burnDurationSec);
      }
    }

    if (stats.slowFactor < 1) {
      target.applySlow(
          factor: stats.slowFactor, durationSec: stats.slowDurationSec);
    }

    if (stats.chainTargets > 0) {
      final chained = <Enemy>{target};
      var current = target;
      for (var i = 0; i < stats.chainTargets; i++) {
        Enemy? next;
        double bestDist = double.infinity;
        for (final other in enemiesProvider()) {
          if (chained.contains(other) || other.isRemoved) continue;
          final d = other.position.distanceTo(current.position);
          if (d < bestDist && d < 100) {
            bestDist = d;
            next = other;
          }
        }
        if (next == null) break;
        chained.add(next);
        next.takeDamage(
            amount: damage * 0.5, armorPierce: stats.armorPierce);
        current = next;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 2, Paint()..color = _color);
  }
}
```

### Step 2: Verify

```
flutter analyze
```
Expected: `No issues found!` (assuming Tower already passes the new signature — if not, this will fail until Task 6 is done. That's fine; commit Projectile separately and fix Tower next.)

If analyze flags Projectile-only issues, fix them. If it flags errors in `tower.dart` due to the new Projectile constructor signature, do NOT fix Tower in this task — leave it broken; Task 6 rewrites it.

### Step 3: Commit (only projectile.dart)

```
git add lib/game/components/projectile.dart
git commit -m "feat(game): Projectile applies splash/slow/burn/crit/chain effects"
```

---

## Task 6: Tower — type-aware, branch upgrades, recomputed stats

**Files:**
- Modify: `c:\dev\void_td\lib\game\components\tower.dart`
- Create: `c:\dev\void_td\lib\game\components\farm.dart`

`Tower` becomes type-aware. Farms are a separate component that doesn't shoot, only ticks gold (we model it as its own class for clarity). Tower exposes `branchA`, `branchB` (mutable) and a getter `stats` that returns recomputed stats.

### Step 1: Rewrite `tower.dart`

Replace `c:\dev\void_td\lib\game\components\tower.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../data/towers_config.dart';
import 'enemy.dart';
import 'projectile.dart';
import 'tower_icon_painter.dart';

class Tower extends PositionComponent {
  final TowerType type;
  int branchA;
  int branchB;

  final List<Enemy> Function() enemiesProvider;
  double _cooldown = 0;

  Tower({
    required this.type,
    required Vector2 worldPos,
    required this.enemiesProvider,
    this.branchA = 0,
    this.branchB = 0,
  }) : super(position: worldPos.clone(), size: Vector2.all(28), anchor: Anchor.center);

  TowerStats get stats =>
      TowersConfig.statsFor(type, branchA: branchA, branchB: branchB);

  double get range => stats.range;

  @override
  void update(double dt) {
    super.update(dt);
    final s = stats;
    if (s.fireRatePerSec <= 0) return; // non-shooting (farm)
    _cooldown -= dt;
    if (_cooldown > 0) return;

    Enemy? closest;
    double bestDist = double.infinity;
    for (final e in enemiesProvider()) {
      final d = e.position.distanceTo(position);
      if (d <= s.range && d < bestDist) {
        closest = e;
        bestDist = d;
      }
    }
    if (closest == null) return;

    _cooldown = 1.0 / s.fireRatePerSec;
    parent?.add(Projectile(
      start: position,
      ownerType: type,
      stats: s,
      target: closest,
      enemiesProvider: enemiesProvider,
    ));
  }

  @override
  void render(Canvas canvas) {
    TowerIconPainter.paint(canvas, type, size: size);
  }
}
```

### Step 2: Create farm.dart

Create `c:\dev\void_td\lib\game\components\farm.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/towers_config.dart';
import 'tower_icon_painter.dart';

/// Farm "tower": no targeting, just generates gold. The actual income
/// accumulation happens in TdGame (one tick per game-second), so this
/// component is purely visual + state-holder.
class Farm extends PositionComponent {
  int branchA;
  int branchB;

  Farm({
    required Vector2 worldPos,
    this.branchA = 0,
    this.branchB = 0,
  }) : super(position: worldPos.clone(), size: Vector2.all(28), anchor: Anchor.center);

  TowerStats get stats =>
      TowersConfig.statsFor(TowerType.farm, branchA: branchA, branchB: branchB);

  int get goldPerSec => stats.farmGoldPerSec;

  @override
  void render(Canvas canvas) {
    TowerIconPainter.paint(canvas, TowerType.farm, size: size);
  }
}
```

### Step 3: Create tower_icon_painter.dart

Create `c:\dev\void_td\lib\game\components\tower_icon_painter.dart`:
```dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../data/towers_config.dart';

/// Shared CustomPainter logic so the Flame Tower component and the Flutter
/// palette widget render identical glyphs. Selected icons per design:
///   B1  basic   — circle outline + filled center (cyan)
///   S5  splash  — 8-ray explosion (magenta)
///   Sn3 sniper  — circle + crosshair (yellow)
///   Sl3 slow    — clock face: circle + 2 lines (purple)
///   F2  farm    — circle + "$" (green)
class TowerIconPainter {
  /// Paint at canvas origin into a `size` × `size` square.
  static void paint(Canvas canvas, TowerType type, {required Vector2 size}) {
    final s = size.x;
    final color = _colorFor(type);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()..color = color;
    final center = Offset(s / 2, s / 2);

    switch (type) {
      case TowerType.basic:
        canvas.drawCircle(center, s * 0.42, stroke);
        canvas.drawCircle(center, s * 0.18, fill);
        break;
      case TowerType.splash:
        for (var i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4);
          final inner = Offset(center.dx + math.cos(angle) * s * 0.14,
              center.dy + math.sin(angle) * s * 0.14);
          final outer = Offset(center.dx + math.cos(angle) * s * 0.46,
              center.dy + math.sin(angle) * s * 0.46);
          canvas.drawLine(inner, outer, stroke);
        }
        canvas.drawCircle(center, s * 0.10, fill);
        break;
      case TowerType.sniper:
        canvas.drawCircle(center, s * 0.42, stroke);
        // crosshair lines
        final thin = Paint()
          ..color = color
          ..strokeWidth = 0.8;
        canvas.drawLine(Offset(center.dx, center.dy - s * 0.42),
            Offset(center.dx, center.dy + s * 0.42), thin);
        canvas.drawLine(Offset(center.dx - s * 0.42, center.dy),
            Offset(center.dx + s * 0.42, center.dy), thin);
        canvas.drawCircle(center, s * 0.08, fill);
        break;
      case TowerType.slow:
        canvas.drawCircle(center, s * 0.42, stroke);
        // clock hands: 12 -> centre, 3-ish -> centre
        canvas.drawLine(center,
            Offset(center.dx, center.dy - s * 0.32), stroke);
        canvas.drawLine(center,
            Offset(center.dx + s * 0.24, center.dy + s * 0.08), stroke);
        canvas.drawCircle(center, s * 0.05, fill);
        break;
      case TowerType.farm:
        canvas.drawCircle(center, s * 0.42, stroke);
        final textPainter = TextPainter(
          text: TextSpan(
            text: r'$',
            style: TextStyle(
              color: color,
              fontSize: s * 0.45,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(center.dx - textPainter.width / 2,
              center.dy - textPainter.height / 2),
        );
        break;
    }
  }

  static Color _colorFor(TowerType t) {
    switch (t) {
      case TowerType.basic:
        return AppColors.cyan;
      case TowerType.splash:
        return AppColors.magenta;
      case TowerType.sniper:
        return AppColors.yellow;
      case TowerType.slow:
        return AppColors.purple;
      case TowerType.farm:
        return AppColors.green;
    }
  }
}
```

### Step 4: Verify

```
flutter analyze
```
Expected: `No issues found!` — but `td_game.dart` and `level_one_config.dart` will likely fail to compile now because:
1. `Tower(...)` no longer takes `range`, `damage`, `fireRatePerSec`, `projectileSpeed`. It takes `type`.
2. `Enemy(...)` no longer takes `speedPxPerSec` and `hp` separately. It takes `type` and `stats`.
3. `LevelOneConfig` still has those obsolete constants.

We fix all of that in Tasks 7 and 8. For now, expect compile errors in `td_game.dart` — do NOT fix them here.

If analyze prints errors ONLY in `td_game.dart` and `level_one_config.dart`, that's expected. Commit anyway.
If analyze prints errors in the files this task touched (`tower.dart`, `farm.dart`, `tower_icon_painter.dart`), fix them.

### Step 5: Commit

```
git add lib/game/components/tower.dart lib/game/components/farm.dart lib/game/components/tower_icon_painter.dart
git commit -m "feat(game): Tower is type-aware with branch upgrades; add Farm; shared icon painter"
```

---

## Task 7: Update LevelOneConfig and seed wave spec

**Files:**
- Modify: `c:\dev\void_td\lib\data\level_one_config.dart`

Per the TD-design research: level 1 = one bend (not pure straight), 8 waves, Grunt+Fast mix, climaxing with a "boss-feel" wave of 12 Grunts. No Tank, no Boss yet — those debut in level 2/3.

### Step 1: Replace level_one_config.dart

Replace `c:\dev\void_td\lib\data\level_one_config.dart`:
```dart
import 'package:flame/components.dart';
import '../game/grid/grid.dart';
import '../game/waves/wave_runner.dart';
import 'enemies_config.dart';

class LevelOneConfig {
  static const Grid grid = Grid(cols: 9, rows: 16, cellSize: 40);

  /// One bend, top to bottom — teaches "corners = kill zones".
  static List<Vector2> get pathPoints {
    Vector2 c(int col, int row) {
      final o = grid.cellCenter(col, row);
      return Vector2(o.dx, o.dy);
    }
    return [
      c(2, 0),
      c(2, 8),
      c(6, 8),
      c(6, 15),
    ];
  }

  /// 8 waves; HP scaling happens via enemy type, count grows ~10–15% per wave.
  /// All times are relative to the START of the wave.
  static List<List<EnemySpawn>> get waves => [
        // Wave 1: 5 Grunts
        _grunts(count: 5, gap: 1.2),
        // Wave 2: 7 Grunts
        _grunts(count: 7, gap: 1.0),
        // Wave 3: 8 Grunts
        _grunts(count: 8, gap: 0.9),
        // Wave 4: 4 Fast
        _fasts(count: 4, gap: 0.7),
        // Wave 5: 4 Grunts then 4 Fast
        [..._grunts(count: 4, gap: 1.0), ..._fastsOffset(count: 4, gap: 0.7, after: 4.5)],
        // Wave 6: 6 Grunts + 4 Fast mixed (interleaved)
        _interleave(grunt: 6, fast: 4, gap: 0.8),
        // Wave 7: 10 Swarm
        List.generate(10, (i) => EnemySpawn(type: EnemyType.swarm, atSec: i * 0.4)),
        // Wave 8: climax — 12 Grunts packed
        _grunts(count: 12, gap: 0.7),
      ];

  static List<EnemySpawn> _grunts({required int count, required double gap}) =>
      List.generate(count, (i) => EnemySpawn(type: EnemyType.grunt, atSec: i * gap));

  static List<EnemySpawn> _fasts({required int count, required double gap}) =>
      List.generate(count, (i) => EnemySpawn(type: EnemyType.fast, atSec: i * gap));

  static List<EnemySpawn> _fastsOffset(
          {required int count, required double gap, required double after}) =>
      List.generate(count,
          (i) => EnemySpawn(type: EnemyType.fast, atSec: after + i * gap));

  static List<EnemySpawn> _interleave({
    required int grunt,
    required int fast,
    required double gap,
  }) {
    final out = <EnemySpawn>[];
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
    return out;
  }

  static const int startingLives = 20;
  static const int startingGold = 200; // per TD-design research, level 1 = 2 basics + 1 farm
  static const double passiveIncomePerWave = 10;
  static const double passiveIncomePerWaveGrowth = 2; // per wave
}
```

### Step 2: Verify

```
flutter analyze
```
Expected: error only in `td_game.dart`, which still references the deleted constants (basicTowerCost, enemyHp, etc.) — that's expected; Task 8 fixes it.

### Step 3: Commit

```
git add lib/data/level_one_config.dart
git commit -m "feat(data): level 1 redesigned per TD best-practice — 8 waves, one bend"
```

---

## Task 8: Extend MatchState

**Files:**
- Modify: `c:\dev\void_td\lib\game\match\match_state.dart`
- Modify: `c:\dev\void_td\test\match_state_test.dart`

`MatchState` gets:
- `cleanWavesCount` (consecutive waves with no lives lost)
- `livesLostThisWave` (resets on `nextWave`, increments in `takeDamage`)
- methods `applyPassiveIncome(wave)`, `applyFarmTick(income)`, `applyCleanWaveBonus()` returning the bonus integer
- `wasWaveClean()` predicate (no lives lost this wave)

### Step 1: Replace the test file

Replace `c:\dev\void_td\test\match_state_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/game/match/match_state.dart';

void main() {
  group('MatchState basics', () {
    test('starts with the given lives, gold, wave 0', () {
      final s = MatchState(lives: 20, gold: 100);
      expect(s.lives, 20);
      expect(s.gold, 100);
      expect(s.currentWave, 0);
      expect(s.isGameOver, isFalse);
    });

    test('takeDamage clamps at 0 and sets gameOver', () {
      final s = MatchState(lives: 20, gold: 100);
      s.takeDamage(5);
      expect(s.lives, 15);
      s.takeDamage(50);
      expect(s.lives, 0);
      expect(s.isGameOver, isTrue);
    });

    test('addGold and spendGold', () {
      final s = MatchState(lives: 20, gold: 30);
      s.addGold(20);
      expect(s.gold, 50);
      expect(s.spendGold(40), isTrue);
      expect(s.gold, 10);
      expect(s.spendGold(40), isFalse);
      expect(s.gold, 10);
    });

    test('nextWave increments and resets livesLostThisWave', () {
      final s = MatchState(lives: 20, gold: 100);
      s.takeDamage(2);
      expect(s.livesLostThisWave, 2);
      s.nextWave();
      expect(s.currentWave, 1);
      expect(s.livesLostThisWave, 0);
    });
  });

  group('MatchState economy', () {
    test('applyPassiveIncome on wave 1: 10 gold', () {
      final s = MatchState(lives: 20, gold: 100);
      s.nextWave(); // wave 1
      s.applyPassiveIncome(baseGold: 10, growthPerWave: 2);
      expect(s.gold, 110);
    });

    test('applyPassiveIncome on wave 5: 10 + 4*2 = 18', () {
      final s = MatchState(lives: 20, gold: 100);
      for (var i = 0; i < 5; i++) s.nextWave();
      s.applyPassiveIncome(baseGold: 10, growthPerWave: 2);
      expect(s.gold, 118);
    });

    test('applyFarmTick adds gold', () {
      final s = MatchState(lives: 20, gold: 100);
      s.applyFarmTick(7);
      expect(s.gold, 107);
    });
  });

  group('MatchState clean-wave logic', () {
    test('cleanWavesCount increments when a wave ends with no damage', () {
      final s = MatchState(lives: 20, gold: 100);
      s.nextWave(); // wave 1
      expect(s.wasWaveClean(), isTrue);
      final bonus = s.applyCleanWaveBonus(baseBonus: 20, perWave: 2);
      expect(bonus, 22); // 20 + 1*2
      expect(s.gold, 122);
      expect(s.cleanWavesCount, 1);
    });

    test('losing a life resets cleanWavesCount on wave end', () {
      final s = MatchState(lives: 20, gold: 100);
      s.nextWave();
      s.takeDamage(1);
      expect(s.wasWaveClean(), isFalse);
      final bonus = s.applyCleanWaveBonus(baseBonus: 20, perWave: 2);
      expect(bonus, 0);
      expect(s.gold, 100);
      expect(s.cleanWavesCount, 0);
    });
  });
}
```

### Step 2: Verify fail

```
flutter test test/match_state_test.dart
```

### Step 3: Replace `match_state.dart`

Replace `c:\dev\void_td\lib\game\match\match_state.dart`:
```dart
class MatchState {
  int lives;
  int gold;
  int currentWave;

  /// Lives lost during the current wave. Reset on `nextWave`.
  int livesLostThisWave = 0;

  /// Number of consecutive clean waves (no lives lost) ending in `applyCleanWaveBonus`.
  int cleanWavesCount = 0;

  MatchState({required this.lives, required this.gold}) : currentWave = 0;

  bool get isGameOver => lives <= 0;

  void takeDamage(int amount) {
    if (amount <= 0) return;
    lives = (lives - amount).clamp(0, 1 << 31);
    livesLostThisWave += amount;
  }

  void addGold(int amount) {
    gold += amount;
  }

  bool spendGold(int amount) {
    if (gold < amount) return false;
    gold -= amount;
    return true;
  }

  void nextWave() {
    currentWave += 1;
    livesLostThisWave = 0;
  }

  /// Called at the start of each wave.
  void applyPassiveIncome({
    required double baseGold,
    required double growthPerWave,
  }) {
    final n = (baseGold + growthPerWave * (currentWave - 1)).round();
    gold += n;
  }

  /// Called once per real-time second (game-clock seconds, not wall clock).
  void applyFarmTick(int totalFarmGoldPerSec) {
    gold += totalFarmGoldPerSec;
  }

  bool wasWaveClean() => livesLostThisWave == 0;

  /// Called at wave END. Returns the bonus applied (0 if not clean).
  int applyCleanWaveBonus({required int baseBonus, required int perWave}) {
    if (!wasWaveClean()) {
      cleanWavesCount = 0;
      return 0;
    }
    final bonus = baseBonus + perWave * currentWave;
    gold += bonus;
    cleanWavesCount += 1;
    return bonus;
  }
}
```

### Step 4: Run tests

```
flutter test test/match_state_test.dart
```
Expected: all 9 tests pass.

### Step 5: Commit

```
git add lib/game/match/match_state.dart test/match_state_test.dart
git commit -m "feat(game): MatchState — economy hooks, clean-wave bonus, lives-lost-this-wave"
```

---

## Task 9: Gold popup component

**Files:**
- Create: `c:\dev\void_td\lib\game\components\gold_popup.dart`

A floating "+N" text that rises and fades over 1.5s, then removes itself.

### Step 1: Implement

Create `lib\game\components\gold_popup.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class GoldPopup extends Component {
  final Vector2 worldPos;
  final int amount;

  static const double _durationSec = 1.5;
  double _elapsed = 0;

  GoldPopup({required this.worldPos, required this.amount});

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _durationSec) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _elapsed / _durationSec;
    final alpha = (1.0 - t).clamp(0.0, 1.0);
    final dy = -30.0 * t;
    final color = AppColors.cyan.withValues(alpha: alpha);
    final tp = TextPainter(
      text: TextSpan(
        text: '+$amount',
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          shadows: [
            Shadow(color: color, blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas,
        Offset(worldPos.x - tp.width / 2, worldPos.y + dy));
  }
}
```

### Step 2: Verify

```
flutter analyze
```

### Step 3: Commit

```
git add lib/game/components/gold_popup.dart
git commit -m "feat(game): add GoldPopup floating-text component"
```

---

## Task 10: BudgetDots widget

**Files:**
- Create: `c:\dev\void_td\lib\ui\match\budget_dots.dart`

Reusable: row of N dots, first `filled` are solid, the rest are outlined.

### Step 1: Implement

Create `lib\ui\match\budget_dots.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class BudgetDots extends StatelessWidget {
  final int total;
  final int filled;
  final Color color;
  final double size;
  final double gap;

  const BudgetDots({
    super.key,
    required this.total,
    required this.filled,
    this.color = AppColors.cyan,
    this.size = 8,
    this.gap = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return Padding(
          padding: EdgeInsets.only(right: i < total - 1 ? gap : 0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isFilled ? color : Colors.transparent,
              border: Border.all(color: color, width: 1),
              borderRadius: BorderRadius.circular(2),
              boxShadow: isFilled
                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
```

### Step 2: Verify

```
flutter analyze
```

### Step 3: Commit

```
git add lib/ui/match/budget_dots.dart
git commit -m "feat(ui): add BudgetDots widget for upgrade bar"
```

---

## Task 11: TowerPalette and SpeedBar widgets

**Files:**
- Create: `c:\dev\void_td\lib\ui\match\tower_palette.dart`
- Create: `c:\dev\void_td\lib\ui\match\speed_bar.dart`

### Step 1: Implement TowerPalette

Create `lib\ui\match\tower_palette.dart`:
```dart
import 'package:flame/components.dart' as flame;
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../data/towers_config.dart';
import '../../game/components/tower_icon_painter.dart';

class TowerPalette extends StatelessWidget {
  final TowerType? selected;
  final int gold;
  final ValueChanged<TowerType?> onChange;

  const TowerPalette({
    super.key,
    required this.selected,
    required this.gold,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: TowerType.values.map((t) {
          final cost = TowersConfig.baseCost(t);
          final affordable = gold >= cost;
          final isSelected = selected == t;
          return _PaletteItem(
            type: t,
            cost: cost,
            affordable: affordable,
            isSelected: isSelected,
            onTap: () => onChange(isSelected ? null : t),
          );
        }).toList(),
      ),
    );
  }
}

class _PaletteItem extends StatelessWidget {
  final TowerType type;
  final int cost;
  final bool affordable;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaletteItem({
    required this.type,
    required this.cost,
    required this.affordable,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _colorFor(type);
    final borderColor = isSelected
        ? accent
        : (affordable ? AppColors.border : const Color(0xFF2A2A2A));
    return GestureDetector(
      onTap: affordable ? onTap : null,
      child: Container(
        width: 50,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 8)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CustomPaint(painter: _TowerGlyphPainter(type)),
            ),
            const SizedBox(height: 4),
            Text(
              '\$$cost',
              style: TextStyle(
                color: affordable ? AppColors.textSecondary : AppColors.textMuted,
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _colorFor(TowerType t) {
    switch (t) {
      case TowerType.basic:
        return AppColors.cyan;
      case TowerType.splash:
        return AppColors.magenta;
      case TowerType.sniper:
        return AppColors.yellow;
      case TowerType.slow:
        return AppColors.purple;
      case TowerType.farm:
        return AppColors.green;
    }
  }
}

class _TowerGlyphPainter extends CustomPainter {
  final TowerType type;
  _TowerGlyphPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    TowerIconPainter.paint(
      canvas,
      type,
      size: flame.Vector2(size.width, size.height),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
```

### Step 2: Implement SpeedBar

Create `lib\ui\match\speed_bar.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class SpeedBar extends StatelessWidget {
  final int currentSpeed; // 1, 2, or 3
  final int farmIncomePerSec;
  final ValueChanged<int> onChange;

  const SpeedBar({
    super.key,
    required this.currentSpeed,
    required this.farmIncomePerSec,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [1, 2, 3].map((sp) {
              final active = sp == currentSpeed;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onChange(sp),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: active ? AppColors.cyan : AppColors.border,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: active
                          ? [BoxShadow(color: AppColors.cyan.withValues(alpha: 0.4), blurRadius: 6)]
                          : null,
                    ),
                    child: Text(
                      '${sp}×',
                      style: TextStyle(
                        color: active ? AppColors.textPrimary : AppColors.textMuted,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        shadows: active
                            ? [Shadow(color: AppColors.cyan.withValues(alpha: 0.6), blurRadius: 4)]
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Row(
            children: [
              const Text('FARMS',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 8,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace')),
              const SizedBox(width: 6),
              Text(
                '+$farmIncomePerSec/s',
                style: TextStyle(
                  color: AppColors.green,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  shadows: [Shadow(color: AppColors.green.withValues(alpha: 0.6), blurRadius: 4)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### Step 3: Verify

```
flutter analyze
```

### Step 4: Commit

```
git add lib/ui/match/tower_palette.dart lib/ui/match/speed_bar.dart
git commit -m "feat(ui): TowerPalette (5 icons) and SpeedBar (1×/2×/3× + farm income)"
```

---

## Task 12: TowerUpgradePanel widget

**Files:**
- Create: `c:\dev\void_td\lib\ui\match\tower_upgrade_panel.dart`

Shown when a placed tower is selected. Displays:
- Tower glyph + name
- Branch A and B titles + level dots (BudgetDots width 5)
- "+ $cost" tap-target for each branch (disabled if branch maxed or gold insufficient or total budget reached)
- 7-dot budget bar at the bottom
- SELL button on the right (returns 70% of total spent)

### Step 1: Implement

Create `lib\ui\match\tower_upgrade_panel.dart`:
```dart
import 'package:flame/components.dart' as flame;
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../data/towers_config.dart';
import '../../game/components/tower_icon_painter.dart';
import 'budget_dots.dart';

class TowerUpgradePanel extends StatelessWidget {
  final TowerType type;
  final int branchA;
  final int branchB;
  final int gold;
  static const int budgetCap = 7;

  /// Total gold previously spent on this tower (base + upgrades).
  final int totalSpent;

  final VoidCallback onUpgradeA;
  final VoidCallback onUpgradeB;
  final VoidCallback onSell;
  final VoidCallback onClose;

  const TowerUpgradePanel({
    super.key,
    required this.type,
    required this.branchA,
    required this.branchB,
    required this.gold,
    required this.totalSpent,
    required this.onUpgradeA,
    required this.onUpgradeB,
    required this.onSell,
    required this.onClose,
  });

  int get used => branchA + branchB;
  bool get atBudget => used >= budgetCap;

  int? get nextACost {
    if (branchA >= 5) return null;
    return TowersConfig.upgradeCost(type, currentLevel: branchA);
  }

  int? get nextBCost {
    if (branchB >= 5) return null;
    return TowersConfig.upgradeCost(type, currentLevel: branchB);
  }

  bool _canUpgrade(int? cost) =>
      cost != null && !atBudget && gold >= cost;

  String get _typeName {
    switch (type) {
      case TowerType.basic:
        return 'BASIC';
      case TowerType.splash:
        return 'SPLASH';
      case TowerType.sniper:
        return 'SNIPER';
      case TowerType.slow:
        return 'SLOW';
      case TowerType.farm:
        return 'FARM';
    }
  }

  Color get _accent {
    switch (type) {
      case TowerType.basic:
        return AppColors.cyan;
      case TowerType.splash:
        return AppColors.magenta;
      case TowerType.sniper:
        return AppColors.yellow;
      case TowerType.slow:
        return AppColors.purple;
      case TowerType.farm:
        return AppColors.green;
    }
  }

  int get sellRefund => (totalSpent * 0.7).round();

  String get _branchAName {
    switch (type) {
      case TowerType.basic:
        return 'RANGE+RATE';
      case TowerType.splash:
        return 'RADIUS';
      case TowerType.sniper:
        return 'PIERCE';
      case TowerType.slow:
        return 'STRONGER';
      case TowerType.farm:
        return 'INCOME';
    }
  }

  String get _branchBName {
    switch (type) {
      case TowerType.basic:
        return 'CRIT';
      case TowerType.splash:
        return 'BURN';
      case TowerType.sniper:
        return 'CHAIN';
      case TowerType.slow:
        return 'AURA';
      case TowerType.farm:
        return 'CHEAPER';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: _accent, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(painter: _GlyphPainter(type)),
              ),
              const SizedBox(width: 8),
              Text(_typeName,
                  style: TextStyle(
                    color: _accent,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: _accent.withValues(alpha: 0.6), blurRadius: 4)],
                  )),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: AppColors.textSecondary, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _branch(_branchAName, branchA, nextACost, onUpgradeA)),
              const SizedBox(width: 8),
              Expanded(child: _branch(_branchBName, branchB, nextBCost, onUpgradeB)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('BUDGET',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 8,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace')),
              const SizedBox(width: 8),
              BudgetDots(total: budgetCap, filled: used, color: _accent),
              const Spacer(),
              GestureDetector(
                onTap: onSell,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.red, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('SELL  \$$sellRefund',
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 10,
                        letterSpacing: 1,
                        fontFamily: 'monospace',
                        shadows: [Shadow(color: AppColors.red.withValues(alpha: 0.6), blurRadius: 4)],
                      )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _branch(String name, int level, int? nextCost, VoidCallback onTap) {
    final canUpgrade = _canUpgrade(nextCost);
    return GestureDetector(
      onTap: canUpgrade ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.border, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 8,
                    letterSpacing: 1.5,
                    fontFamily: 'monospace')),
            const SizedBox(height: 4),
            BudgetDots(total: 5, filled: level, color: _accent, size: 9),
            const SizedBox(height: 6),
            Text(
              nextCost == null ? 'MAX' : '+ \$$nextCost',
              style: TextStyle(
                color: nextCost == null
                    ? AppColors.textMuted
                    : (canUpgrade ? AppColors.cyan : AppColors.textMuted),
                fontFamily: 'monospace',
                fontSize: 11,
                shadows: canUpgrade
                    ? [Shadow(color: AppColors.cyan.withValues(alpha: 0.5), blurRadius: 4)]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final TowerType type;
  _GlyphPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    TowerIconPainter.paint(canvas, type, size: flame.Vector2(size.width, size.height));
  }

  @override
  bool shouldRepaint(_) => false;
}
```

### Step 2: Verify

```
flutter analyze
```

### Step 3: Commit

```
git add lib/ui/match/tower_upgrade_panel.dart
git commit -m "feat(ui): TowerUpgradePanel with branch upgrades, budget dots, SELL"
```

---

## Task 13: HUD — functional Pause button

**Files:**
- Modify: `c:\dev\void_td\lib\game\match\hud.dart`

Make the existing `II` square a real tap target that calls back into GameScreen.

### Step 1: Replace `hud.dart`

Replace `c:\dev\void_td\lib\game\match\hud.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'match_state.dart';

class Hud extends StatelessWidget {
  final MatchState state;
  final bool isPaused;
  final VoidCallback onPauseTap;

  const Hud({
    super.key,
    required this.state,
    required this.isPaused,
    required this.onPauseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat('WAVE', '${state.currentWave}', AppColors.cyan),
          _divider(),
          _stat('LIVES', '♥ ${state.lives}', AppColors.red),
          _divider(),
          _stat('GOLD', '\$ ${state.gold}', AppColors.yellow),
          _divider(),
          GestureDetector(
            onTap: onPauseTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.cyan, width: 1),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(color: AppColors.cyan.withValues(alpha: 0.4), blurRadius: 4)],
              ),
              child: Text(
                isPaused ? '▶' : 'II',
                style: TextStyle(
                  color: AppColors.cyan,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  shadows: [Shadow(color: AppColors.cyan.withValues(alpha: 0.6), blurRadius: 4)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 8,
                letterSpacing: 1.5,
                fontFamily: 'monospace')),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontFamily: 'monospace',
                shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 6)])),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 24, color: AppColors.border);
}
```

### Step 2: Verify (expect error in GameScreen)

```
flutter analyze
```
Expected: GameScreen no longer compiles (old Hud signature). Task 14 fixes it.

### Step 3: Commit

```
git add lib/game/match/hud.dart
git commit -m "feat(ui): Hud Pause button is now interactive"
```

---

## Task 14: Rewrite TdGame to glue everything together

**Files:**
- Modify: `c:\dev\void_td\lib\game\td_game.dart`

This is the heaviest task. The new TdGame:
- Holds wave list from `LevelOneConfig.waves` + a `_currentWaveIndex`
- Tracks `_isWaveActive` flag; auto-starts wave 1 on load
- Spawns enemies via `WaveRunner` with the current wave's spec
- When the spec is done AND all live enemies are gone → wave ends → apply clean-wave bonus → emit GoldPopup → wait 0.5s → advance `_currentWaveIndex` + nextWave() + applyPassiveIncome + start next WaveRunner
- Manages `selectedPaletteType` (what the player picked from palette) and `selectedTower` (placed tower the player is inspecting)
- DragCallbacks place a Tower or Farm of `selectedPaletteType` (instead of always Basic)
- A short tap (no drag) on a placed tower selects it
- Farm tick: a sub-component that accumulates a 1-second timer and calls `state.applyFarmTick(sumOfAllFarmIncomes)`
- Speed control: writes to `timeScale` so game-clock advances faster (existing Flame property)

### Step 1: Replace `td_game.dart`

Replace `c:\dev\void_td\lib\game\td_game.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../data/enemies_config.dart';
import '../data/level_one_config.dart';
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

/// Top-level game object.
class TdGame extends FlameGame with DragCallbacks {
  // World setup
  late final PathSegment path;
  late PositionComponent _world;
  late Vector2 _gridOrigin;

  // Match state (shared with HUD via stateNotifier)
  final ValueNotifier<MatchState> stateNotifier = ValueNotifier(
    MatchState(
      lives: LevelOneConfig.startingLives,
      gold: LevelOneConfig.startingGold,
    ),
  );
  MatchState get state => stateNotifier.value;

  // UI selection signals
  /// Tower type the player picked from the palette (null = no build mode).
  final ValueNotifier<TowerType?> paletteSelection = ValueNotifier(null);

  /// Existing placed tower currently inspected by the player (for upgrades).
  final ValueNotifier<Object?> selectedTower = ValueNotifier(null); // Tower | Farm

  // Wave control
  late List<List<EnemySpawn>> _waves;
  int _currentWaveIndex = 0;
  WaveRunner? _waveRunner;
  bool _isWaveActive = false;
  double _interWaveDelay = 0;

  // Live enemies & tower bookkeeping
  final List<Enemy> liveEnemies = [];
  final Map<(int, int), Object> _placed = {}; // Tower | Farm
  final Map<Object, int> _totalSpent = {};   // for SELL refund

  // Farm tick
  double _farmTickAccumulator = 0;

  // Drag preview
  CellHighlight? _previewHighlight;
  RangeIndicator? _previewRange;
  (int, int)? _previewCell;
  RangeIndicator? _selectionRange;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    _waves = LevelOneConfig.waves;
    final grid = LevelOneConfig.grid;
    path = PathSegment(points: LevelOneConfig.pathPoints);

    final offsetX = (size.x - grid.width) / 2;
    final offsetY = 30.0;
    _world = PositionComponent(position: Vector2(offsetX, offsetY));
    add(_world);
    _world.add(GridPainter(grid: grid));
    _world.add(PathRenderer(path: path));
    _gridOrigin = Vector2(offsetX, offsetY);

    _startNextWave();
    _emitState();
  }

  void _startNextWave() {
    if (_currentWaveIndex >= _waves.length) {
      // Match completed: do nothing (Stage 2b adds Victory dialog).
      return;
    }
    state.nextWave();
    state.applyPassiveIncome(
      baseGold: LevelOneConfig.passiveIncomePerWave,
      growthPerWave: LevelOneConfig.passiveIncomePerWaveGrowth,
    );
    _waveRunner = WaveRunner(spec: _waves[_currentWaveIndex]);
    _isWaveActive = true;
    _emitState();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state.isGameOver) return;

    // Spawn from current wave runner.
    if (_isWaveActive && _waveRunner != null) {
      final spawns = _waveRunner!.tick(dt);
      for (final type in spawns) {
        _spawnEnemy(type);
      }
      // Wave complete: runner done + no enemies alive.
      if (_waveRunner!.isDone && liveEnemies.isEmpty) {
        _onWaveCleared();
      }
    } else if (_interWaveDelay > 0) {
      _interWaveDelay -= dt;
      if (_interWaveDelay <= 0) {
        _currentWaveIndex++;
        _startNextWave();
      }
    }

    // Farm tick (1 game-second).
    _farmTickAccumulator += dt;
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
          Vector2(LevelOneConfig.grid.width / 2, LevelOneConfig.grid.height / 2);
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

  /// Returns total farm income/sec across all placed farms.
  int totalFarmIncome() => _placed.values
      .whereType<Farm>()
      .fold<int>(0, (sum, f) => sum + f.goldPerSec);

  // ---------------------------------------------------------------------------
  // Drag / placement
  // ---------------------------------------------------------------------------

  Vector2? _dragStartLocal;
  static const double _dragThreshold = 16;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (state.isGameOver) return;
    _dragStartLocal = event.localPosition.clone();
    if (paletteSelection.value != null) {
      _clearSelection();
      _showPreviewAt(event.localPosition);
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (state.isGameOver) return;
    if (paletteSelection.value != null) {
      _showPreviewAt(event.canvasEndPosition);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final cell = _previewCell;
    _removePreview();
    if (state.isGameOver) {
      _dragStartLocal = null;
      return;
    }

    // CASE 1: palette mode — try to place a tower.
    if (paletteSelection.value != null && cell != null) {
      final (col, row) = cell;
      // Don't overwrite existing.
      if (_placed.containsKey((col, row))) {
        _selectExisting(col, row);
      } else if (_canBuildAt(col, row, paletteSelection.value!)) {
        _placeAt(col, row, paletteSelection.value!);
      }
      _dragStartLocal = null;
      return;
    }

    // CASE 2: no palette mode — selection mode. Treat as a tap.
    if (_dragStartLocal != null) {
      final local = (_dragStartLocal! - _gridOrigin);
      final grid = LevelOneConfig.grid;
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
    _removePreview();
    _dragStartLocal = null;
  }

  void _showPreviewAt(Vector2 canvasPos) {
    final local = canvasPos - _gridOrigin;
    final grid = LevelOneConfig.grid;
    final (col, row) = grid.worldToCell(local.x, local.y);
    if (!grid.contains(col, row)) {
      _removePreview();
      return;
    }
    _previewCell = (col, row);

    final type = paletteSelection.value!;
    final centre = grid.cellCenter(col, row);
    final worldPos = Vector2(centre.dx, centre.dy);

    final mode = _canBuildAt(col, row, type)
        ? CellHighlightMode.buildable
        : CellHighlightMode.blocked;

    if (_previewHighlight == null) {
      _previewHighlight =
          CellHighlight(worldPos: worldPos, cellSize: grid.cellSize, mode: mode);
      _world.add(_previewHighlight!);
    } else {
      _previewHighlight!.position = worldPos;
      _previewHighlight!.mode = mode;
    }

    final stats = TowersConfig.statsFor(type, branchA: 0, branchB: 0);
    if (stats.range > 0) {
      if (_previewRange == null) {
        _previewRange = RangeIndicator(worldPos: worldPos, radius: stats.range);
        _world.add(_previewRange!);
      } else {
        _previewRange!.position = worldPos;
        _previewRange!.radius = stats.range;
      }
    } else {
      _previewRange?.removeFromParent();
      _previewRange = null;
    }
  }

  void _removePreview() {
    _previewHighlight?.removeFromParent();
    _previewHighlight = null;
    _previewRange?.removeFromParent();
    _previewRange = null;
    _previewCell = null;
  }

  bool _canBuildAt(int col, int row, TowerType type) {
    if (_placed.containsKey((col, row))) return false;
    if (_isOnPath(col, row)) return false;
    final cost = TowersConfig.baseCost(type);
    if (state.gold < cost) return false;
    return true;
  }

  void _placeAt(int col, int row, TowerType type) {
    final cost = TowersConfig.baseCost(type);
    if (!state.spendGold(cost)) return;
    final grid = LevelOneConfig.grid;
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
      r = 0; // no range for farm
    } else {
      return;
    }
    if (r > 0) {
      _selectionRange =
          RangeIndicator(worldPos: pos, radius: r, color: const Color(0xFFFFFFFF));
      _world.add(_selectionRange!);
    }
  }

  void _clearSelection() {
    _selectionRange?.removeFromParent();
    _selectionRange = null;
    selectedTower.value = null;
  }

  /// Apply an upgrade decision from the panel.
  /// Returns true if applied.
  bool upgradeSelected({required bool branchA}) {
    final t = selectedTower.value;
    if (t is! Tower) return false;
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
    // refresh selection range with new tower range
    _selectionRange?.removeFromParent();
    _selectionRange = RangeIndicator(
      worldPos: t.position,
      radius: t.range,
      color: const Color(0xFFFFFFFF),
    );
    _world.add(_selectionRange!);
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

  // ---------------------------------------------------------------------------
  // Speed / pause
  // ---------------------------------------------------------------------------

  void setSpeed(int speed) {
    timeScale = speed.toDouble();
  }

  int get currentSpeed => timeScale.round();

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

  // ---------------------------------------------------------------------------
  // HUD notify
  // ---------------------------------------------------------------------------

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

### Step 2: Verify

```
flutter analyze
```
Expected: only `game_screen.dart` errors remain (Hud signature changed in Task 13, also speed/palette wiring missing). Task 15 fixes it.

### Step 3: Commit

```
git add lib/game/td_game.dart
git commit -m "feat(game): TdGame supports types, waves, farms, palette/upgrades, speed"
```

---

## Task 15: Rewrite GameScreen to wire the new UI

**Files:**
- Modify: `c:\dev\void_td\lib\game\game_screen.dart`

The screen now has 4 stacked sections (top to bottom): HUD, GameWidget, SpeedBar, then either TowerPalette OR TowerUpgradePanel. The back-gesture pause dialog from earlier still wraps the whole screen.

### Step 1: Replace `game_screen.dart`

Replace `c:\dev\void_td\lib\game\game_screen.dart`:
```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../data/towers_config.dart';
import '../ui/match/speed_bar.dart';
import '../ui/match/tower_palette.dart';
import '../ui/match/tower_upgrade_panel.dart';
import 'components/farm.dart';
import 'components/tower.dart';
import 'match/hud.dart';
import 'td_game.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final TdGame _game = TdGame();
  bool _pauseDialogOpen = false;

  Future<void> _handleBack() async {
    if (_pauseDialogOpen) return;
    _pauseDialogOpen = true;
    final wasPaused = _game.paused;
    _game.paused = true;

    final shouldQuit = await showDialog<bool>(
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
        content: const Text(
          'Quit to main menu?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('RESUME',
                style: TextStyle(color: AppColors.textSecondary, letterSpacing: 2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
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
    if (shouldQuit == true) {
      Navigator.of(context).pop();
    } else {
      _game.paused = wasPaused;
    }
  }

  void _togglePauseFromHud() {
    setState(() {
      _game.paused = !_game.paused;
    });
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
                builder: (_, state, __) => Hud(
                  state: state,
                  isPaused: _game.paused,
                  onPauseTap: _togglePauseFromHud,
                ),
              ),
              Expanded(child: GameWidget(game: _game)),
              ValueListenableBuilder<int>(
                valueListenable: _SpeedNotifier(_game),
                builder: (_, speed, __) {
                  return SpeedBar(
                    currentSpeed: speed,
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
      builder: (_, selected, __) {
        if (selected is Tower) {
          return ValueListenableBuilder(
            valueListenable: _game.stateNotifier,
            builder: (_, state, __) {
              return TowerUpgradePanel(
                type: selected.type,
                branchA: selected.branchA,
                branchB: selected.branchB,
                gold: state.gold,
                totalSpent: _game.totalSpentFor(selected),
                onUpgradeA: () {
                  setState(() => _game.upgradeSelected(branchA: true));
                },
                onUpgradeB: () {
                  setState(() => _game.upgradeSelected(branchA: false));
                },
                onSell: () {
                  setState(() => _game.sellSelected());
                },
                onClose: () {
                  setState(() => _game.selectedTower.value = null);
                },
              );
            },
          );
        }
        if (selected is Farm) {
          return ValueListenableBuilder(
            valueListenable: _game.stateNotifier,
            builder: (_, state, __) {
              return TowerUpgradePanel(
                type: TowerType.farm,
                branchA: selected.branchA,
                branchB: selected.branchB,
                gold: state.gold,
                totalSpent: _game.totalSpentFor(selected),
                onUpgradeA: () {}, // TODO Stage 2b: Farm upgrades
                onUpgradeB: () {},
                onSell: () {
                  setState(() => _game.sellSelected());
                },
                onClose: () {
                  setState(() => _game.selectedTower.value = null);
                },
              );
            },
          );
        }
        // No tower selected: show palette.
        return ValueListenableBuilder(
          valueListenable: _game.paletteSelection,
          builder: (_, picked, __) {
            return ValueListenableBuilder(
              valueListenable: _game.stateNotifier,
              builder: (_, state, __) => TowerPalette(
                selected: picked,
                gold: state.gold,
                onChange: (t) {
                  setState(() => _game.paletteSelection.value = t);
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Lightweight adapter exposing TdGame.currentSpeed as a ValueListenable.
class _SpeedNotifier extends ValueNotifier<int> {
  final TdGame game;
  _SpeedNotifier(this.game) : super(game.currentSpeed);
}
```

> Implementation note: `_SpeedNotifier` doesn't auto-update — that's OK for Stage 2a because `setSpeed` calls `setState()` which rebuilds. Stage 2b can replace this with a proper notifier if needed.

### Step 2: Verify

```
flutter analyze
flutter test
```
Expected: analyze clean, all tests pass (Grid, PathSegment, MatchState, WaveRunner, towers_config, enemy_slow — ~30 tests total).

### Step 3: Commit

```
git add lib/game/game_screen.dart
git commit -m "feat(ui): GameScreen wires HUD, palette, upgrade panel, speed bar"
```

---

## Task 16: Pause-triggered save hook (no Hive yet — just save trigger)

**Files:**
- Modify: `c:\dev\void_td\lib\game\game_screen.dart`

Stage 2a does NOT yet persist anything to disk — Hive integration is Stage 2b. But we add the observer hook so it's ready: on `AppLifecycleState.paused` AND on the explicit Pause button, pausing the FlameGame already happens; we just print a debug log saying "would-save-here". That gives us a verifiable hook to drop the Hive call into next stage.

### Step 1: Add the observer to GameScreen

Edit `c:\dev\void_td\lib\game\game_screen.dart`. Find the class declaration:
```dart
class _GameScreenState extends State<GameScreen> {
```
and change it to also implement `WidgetsBindingObserver`:
```dart
class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
```

Add lifecycle methods after `_pauseDialogOpen = false;` declaration block:
```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _game.paused = true;
      // ignore: avoid_print
      print('[VOID TD] match would be saved here (Stage 2b)');
    }
  }
```

### Step 2: Verify

```
flutter analyze
flutter test
```

### Step 3: Commit

```
git add lib/game/game_screen.dart
git commit -m "chore(game): pause game on app-lifecycle paused; placeholder save hook"
```

---

## Task 17: Final verification + manual playtest

This task is for the human. Do NOT have a subagent run `flutter run`.

### Step 1: Final test pass

```
flutter test
flutter analyze
```
Expected: ~30 tests pass, analyze clean.

### Step 2: Tag

```
git tag stage-2a-mechanics
```

### Step 3: Manual playtest checklist (human)

Run on a real Android device:
```
flutter run
```

Verify:
- HUD shows WAVE / LIVES (20) / GOLD (200) / Pause button on the right.
- Pause button toggles freeze. Animation halts; enemies stop.
- Speed bar below the field has [1×] [2×] [3×]; tapping each makes the game run faster proportionally.
- Speed bar right side shows "FARMS +0/s" initially.
- Tower palette at the bottom shows 5 icons (target / 8-burst / crosshair / clock / $) with prices 50 / 80 / 120 / 150 / 60.
- Tapping a palette icon outlines it in cyan. Tap again to deselect.
- With an icon selected, press-and-hold a buildable cell → green highlight + range circle preview (the radius matches the tower type).
- Lifting on a buildable cell → tower appears, gold drops by the cost.
- Drag onto path or onto an existing tower → highlight red, build refused on lift.
- Tap (no drag) a placed tower → palette switches to upgrade panel:
  - Tower icon + name at top
  - Two branches with names (e.g. "RANGE+RATE" / "CRIT" for Basic Shot), each with 5 dots, each with "+ \$cost" tap target
  - 7-dot BUDGET row at the bottom + SELL button
- Tap a branch upgrade → gold drops, the dot fills, the tower's actual range (and damage etc.) reflects the upgrade (try with Basic Shot Branch A — range should visibly grow on re-selection).
- Cap at 7 total dots: when budget is full, both "+\$" buttons become unselectable (dimmed).
- SELL refunds 70% of total spent.
- "✕" close icon top-right of the panel → back to palette.
- Enemies: red dots (Grunts), yellow dots (Fast), tiny red (Swarm). No Tank or Boss in Level 1 — they're saved for Levels 2 and 3 (Stage 2b).
- Slow tower (purple clock icon): shoots purple projectiles. Enemies hit by a slow projectile gain a faint cyan ring and visibly walk slower.
- Sniper tower (yellow crosshair): big damage, slow fire rate.
- Splash tower (magenta burst): area damage; hit one enemy in a group → multiple lose HP.
- Farm (green $): doesn't shoot; the FARMS counter in the speed bar increments by 5/sec per farm.
- Wave clear → cyan "+22" (or similar) floats up from centre of grid and fades over 1.5s (only on clean waves).
- Lose all lives → game freezes (Stage 2b adds Defeat dialog; for now just nothing happens past lives=0).

### Step 4: Report findings to controller

If everything works, say "Stage 2a verified". If anything's off, list what broke.

---

## Done

After Task 17 verification, Stage 2a is complete. Next plan: **Stage 2b — Match Flow & Persistence:**
- 3 Campaign levels in JSON (level 1 redesigned in Stage 2a; levels 2-3 added in 2b per TD best-practice)
- Level Select screen
- Stars (★/★★/★★★) and unlock chain
- Victory / Defeat dialogs
- Endless mode (one open-field map; choose-from-Campaign-maps in Stage 3)
- Save & Resume via Hive: persist MatchState + tower positions on lifecycle pause / explicit Pause, restore on app launch as "CONTINUE" button on main menu
