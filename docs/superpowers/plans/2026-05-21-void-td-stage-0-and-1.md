# VOID — Stage 0 & 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new Flutter+Flame project `void_td` with project skeleton (Stage 0) and a playable match skeleton — one tower type shoots one enemy type walking along a fixed path (Stage 1).

**Architecture:** Pragmatic module-per-feature layout (lib/game · lib/meta · lib/ui · lib/data · lib/core). Flame handles the live match; Flutter handles menus; Riverpod connects them. OLED-first true black theme.

**Tech Stack:** Flutter (stable channel), Dart 3.x, Flame 1.x, flutter_riverpod, Hive (added but used later — Stage 1 reads/writes nothing persistent yet).

**Spec reference:** [`docs/superpowers/specs/2026-05-21-tower-defense-mvp-design.md`](../specs/2026-05-21-tower-defense-mvp-design.md)

**Important global decisions (locked in this plan):**
- Project folder: `c:\dev\void_td` (sibling of `flutter_application_1`)
- Dart package name: `void_td`
- App display name in stores: **VOID TD**. In-game title screen still shows the bigger "VOID" wordmark plus "TD" subtitle (less visual noise).
- Any tower can shoot any enemy (no damage immunities in Lean MVP)
- Tests use `flutter_test`. Logic that doesn't need a widget tree lives in pure Dart for fast unit tests.

---

## File Structure

By the end of this plan the following files exist:

```
c:\dev\void_td\
├── pubspec.yaml                              // project manifest, dependencies
├── analysis_options.yaml                     // lints (flutter_lints + a few stricter rules)
├── .gitignore
├── README.md                                 // 1-page project intro
├── android\app\src\main\AndroidManifest.xml  // orientation lock, app label
├── ios\Runner\Info.plist                     // orientation lock, app label
│
├── lib\
│   ├── main.dart                             // entry, ProviderScope, App widget
│   ├── app.dart                              // MaterialApp.router, dark theme, routes
│   │
│   ├── core\
│   │   └── theme\
│   │       ├── colors.dart                   // OLED palette (true black + neons)
│   │       └── app_theme.dart                // ThemeData (dark, monospace numbers)
│   │
│   ├── ui\
│   │   ├── main_menu\
│   │   │   └── main_menu_screen.dart         // PLAY · SETTINGS (stubs)
│   │   └── shared\
│   │       └── neon_button.dart              // reusable OLED-style button
│   │
│   ├── game\
│   │   ├── td_game.dart                      // FlameGame subclass (root)
│   │   ├── game_screen.dart                  // Flutter wrapper around GameWidget
│   │   ├── grid\
│   │   │   ├── grid.dart                     // pure-Dart grid model (cols, rows, cell size)
│   │   │   └── grid_painter.dart             // Flame Component drawing the grid lines
│   │   ├── path\
│   │   │   ├── path_segment.dart             // List<Vector2> + helpers
│   │   │   └── path_renderer.dart            // Flame Component drawing the path
│   │   ├── components\
│   │   │   ├── enemy.dart                    // Enemy PositionComponent
│   │   │   ├── tower.dart                    // Tower PositionComponent
│   │   │   └── projectile.dart               // Projectile PositionComponent
│   │   ├── waves\
│   │   │   └── wave_runner.dart              // spawns enemies for a single fixed wave
│   │   └── match\
│   │       ├── match_state.dart              // pure-Dart MatchState (lives, gold, wave)
│   │       └── hud.dart                      // Flutter overlay HUD widget
│   │
│   └── data\
│       └── level_one_config.dart             // hard-coded Stage 1 level (no JSON yet)
│
└── test\
    ├── grid_test.dart
    ├── path_segment_test.dart
    ├── match_state_test.dart
    └── wave_runner_test.dart
```

Notes:
- Stage 1 deliberately hardcodes level 1 in Dart (`level_one_config.dart`) — JSON configs come in Stage 2.
- Hive, audio, localization, save/resume — **not** in this plan. Stage 4 / later.
- Riverpod is wired (`ProviderScope` + one provider for `MatchStateNotifier`) so we don't have to retrofit later.

---

## Task 1: Create the Flutter project

**Files:**
- Create: `c:\dev\void_td\` (whole project via `flutter create`)
- Verify: `c:\dev\void_td\pubspec.yaml`

- [ ] **Step 1: Verify Flutter is installed and on stable channel**

Run (PowerShell):
```
flutter --version
```
Expected: prints Flutter version (3.x+) and channel `stable`. If not stable: `flutter channel stable && flutter upgrade`.

- [ ] **Step 2: Create the project**

Run (PowerShell, from `c:\dev`):
```
flutter create --org com.void.td --project-name void_td --platforms=android,ios void_td
```
Expected: directory `c:\dev\void_td\` is created with the standard Flutter scaffold. No errors.

- [ ] **Step 3: Smoke-build to make sure the scaffold compiles**

Run (PowerShell, from `c:\dev\void_td`):
```
flutter pub get
flutter analyze
```
Expected: `No issues found!` (or only info-level notices).

- [ ] **Step 4: Initialize git and make first commit**

Run (PowerShell, from `c:\dev\void_td`):
```
git init
git add .
git commit -m "chore: initial flutter scaffold"
```
Expected: commit created on `main` (or `master` depending on git default — leave as-is).

---

## Task 2: Lock orientation to portrait and rename app to VOID

**Files:**
- Modify: `c:\dev\void_td\android\app\src\main\AndroidManifest.xml`
- Modify: `c:\dev\void_td\ios\Runner\Info.plist`
- Modify: `c:\dev\void_td\lib\main.dart`

- [ ] **Step 1: Lock Android orientation and rename label**

Open `android\app\src\main\AndroidManifest.xml`. Find the `<activity>` tag for `.MainActivity` and:

1. Change `android:label="void_td"` to `android:label="VOID TD"`.
2. Add `android:screenOrientation="portrait"` to the same `<activity>` tag.

The activity tag should look like:
```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:taskAffinity=""
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize"
    android:screenOrientation="portrait"
    android:label="VOID">
```

- [ ] **Step 2: Lock iOS orientation and rename label**

Open `ios\Runner\Info.plist`. Find `UISupportedInterfaceOrientations` and replace its array with only portrait:
```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
</array>
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
</array>
```
Find `CFBundleDisplayName` (or `CFBundleName`) — set the string to `VOID TD`.

- [ ] **Step 3: Also lock orientation at runtime via SystemChrome (defence in depth)**

Replace `lib\main.dart` with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const VoidApp());
}

class VoidApp extends StatelessWidget {
  const VoidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'VOID TD',
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('VOID', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run analyze, then commit**

Run:
```
flutter analyze
```
Expected: `No issues found!`

Commit:
```
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist lib/main.dart
git commit -m "chore: lock portrait orientation and rename app to VOID"
```

---

## Task 3: Add dependencies (flame, riverpod, hive)

**Files:**
- Modify: `c:\dev\void_td\pubspec.yaml`

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Open `pubspec.yaml`. Find the `dependencies:` section (already has `flutter:` and `cupertino_icons:`) and add:
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flame: ^1.18.0
  flutter_riverpod: ^2.5.1
  hive: ^2.2.3
  hive_flutter: ^1.1.0
```

In `dev_dependencies:` make sure these exist (add `hive_generator` and `build_runner` if missing):
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

(We are **not** adding hive_generator yet — no type adapters in Stage 1.)

- [ ] **Step 2: Install packages**

Run:
```
flutter pub get
```
Expected: all packages resolve and download. If a version is wrong, run `flutter pub upgrade --major-versions flame flutter_riverpod hive hive_flutter` and pin whatever resolves.

- [ ] **Step 3: Verify it still compiles**

Run:
```
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```
git add pubspec.yaml pubspec.lock
git commit -m "chore: add flame, riverpod, hive dependencies"
```

---

## Task 4: Add OLED color palette

**Files:**
- Create: `c:\dev\void_td\lib\core\theme\colors.dart`
- Create: `c:\dev\void_td\lib\core\theme\app_theme.dart`

- [ ] **Step 1: Create the color palette**

Create `lib\core\theme\colors.dart` with exact OLED values from the spec:
```dart
import 'package:flutter/material.dart';

/// OLED-first palette. Background is always true black (#000).
/// Accents are neon: cyan = info/Basic, magenta = Splash, yellow = gold/Sniper,
/// purple = Slow/talents, green = farms/income, red = lives/danger.
class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color border = Color(0xFF1A3A5A);

  static const Color cyan = Color(0xFF00D4FF);
  static const Color magenta = Color(0xFFFF6B9D);
  static const Color yellow = Color(0xFFFFD93D);
  static const Color purple = Color(0xFF9D4EDD);
  static const Color green = Color(0xFF44FFAA);
  static const Color red = Color(0xFFFF3B3B);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted = Color(0xFF555555);
}
```

- [ ] **Step 2: Create the ThemeData**

Create `lib\core\theme\app_theme.dart`:
```dart
import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.background,
        primary: AppColors.cyan,
        secondary: AppColors.magenta,
        error: AppColors.red,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),
      useMaterial3: true,
    );
  }
}
```

- [ ] **Step 3: Wire the theme into main**

Open `lib\main.dart`. Replace its body with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ProviderScope(child: VoidApp()));
}
```

Create `lib\app.dart`:
```dart
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'ui/main_menu/main_menu_screen.dart';

class VoidApp extends StatelessWidget {
  const VoidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VOID TD',
      theme: AppTheme.dark,
      home: const MainMenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

(`MainMenuScreen` doesn't exist yet — we create it in Task 5. `flutter analyze` will fail until then; that's fine.)

- [ ] **Step 4: Commit**

```
git add lib/core/theme/colors.dart lib/core/theme/app_theme.dart lib/main.dart lib/app.dart
git commit -m "feat(core): add OLED theme and color palette"
```

---

## Task 5: Add MainMenuScreen and NeonButton

**Files:**
- Create: `c:\dev\void_td\lib\ui\shared\neon_button.dart`
- Create: `c:\dev\void_td\lib\ui\main_menu\main_menu_screen.dart`

- [ ] **Step 1: Create reusable NeonButton**

Create `lib\ui\shared\neon_button.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// OLED-style button: true black fill, 1px neon border, glowing label.
class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fg = enabled ? color : AppColors.textMuted;
    return Material(
      color: AppColors.background,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: fg, width: 1),
            borderRadius: BorderRadius.circular(6),
            boxShadow: enabled
                ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8)]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 16,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create MainMenuScreen with PLAY and SETTINGS stubs**

Create `lib\ui\main_menu\main_menu_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../game/game_screen.dart';
import '../shared/neon_button.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  shadows: [
                    Shadow(color: AppColors.cyan.withOpacity(0.6), blurRadius: 16),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'TD',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 64),
              NeonButton(
                label: 'PLAY',
                color: AppColors.cyan,
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const GameScreen(),
                  ));
                },
              ),
              const SizedBox(height: 16),
              NeonButton(
                label: 'SETTINGS',
                color: AppColors.purple,
                onPressed: null, // stub
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

(`GameScreen` doesn't exist yet — we create an empty stub in Task 6.)

- [ ] **Step 3: Create empty GameScreen stub so the project builds**

Create `lib\game\game_screen.dart` with a placeholder so analyze passes — we'll fill it in Task 7:
```dart
import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text('Match goes here', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, analyze, commit**

Run:
```
flutter analyze
```
Expected: `No issues found!`

Optionally `flutter run` on an Android device or emulator and confirm: black background, white "VOID" title, PLAY button (cyan glow), SETTINGS button (purple, disabled). PLAY navigates to a black screen with "Match goes here". Back button returns to menu.

Commit:
```
git add lib/ui/shared/neon_button.dart lib/ui/main_menu/main_menu_screen.dart lib/game/game_screen.dart
git commit -m "feat(ui): add main menu with PLAY and SETTINGS stubs"
```

---

## Stage 0 complete. From here: Stage 1 — playable match skeleton.

---

## Task 6: Pure-Dart Grid model with tests

**Files:**
- Create: `c:\dev\void_td\lib\game\grid\grid.dart`
- Create: `c:\dev\void_td\test\grid_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test\grid_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/game/grid/grid.dart';

void main() {
  group('Grid', () {
    test('cellCenter returns center of the (col,row) cell in world coordinates', () {
      final grid = Grid(cols: 6, rows: 10, cellSize: 40);
      final c = grid.cellCenter(0, 0);
      expect(c.dx, 20);
      expect(c.dy, 20);

      final c2 = grid.cellCenter(2, 3);
      expect(c2.dx, 100);   // 2*40 + 20
      expect(c2.dy, 140);   // 3*40 + 20
    });

    test('worldToCell returns the (col,row) for a world point', () {
      final grid = Grid(cols: 6, rows: 10, cellSize: 40);
      expect(grid.worldToCell(0, 0), (0, 0));
      expect(grid.worldToCell(45, 35), (1, 0));
      expect(grid.worldToCell(239, 399), (5, 9));
    });

    test('contains returns false for out-of-bounds cells', () {
      final grid = Grid(cols: 6, rows: 10, cellSize: 40);
      expect(grid.contains(0, 0), isTrue);
      expect(grid.contains(5, 9), isTrue);
      expect(grid.contains(-1, 0), isFalse);
      expect(grid.contains(6, 0), isFalse);
      expect(grid.contains(0, 10), isFalse);
    });

    test('size returns total world dimensions', () {
      final grid = Grid(cols: 6, rows: 10, cellSize: 40);
      expect(grid.width, 240);
      expect(grid.height, 400);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```
flutter test test/grid_test.dart
```
Expected: FAIL — `Grid` class not defined.

- [ ] **Step 3: Implement Grid**

Create `lib\game\grid\grid.dart`:
```dart
import 'dart:ui';

/// Square grid in world coordinates. Pure Dart, no Flutter/Flame deps.
class Grid {
  final int cols;
  final int rows;
  final double cellSize;

  const Grid({
    required this.cols,
    required this.rows,
    required this.cellSize,
  });

  double get width => cols * cellSize;
  double get height => rows * cellSize;

  /// World-space center of cell (col,row).
  Offset cellCenter(int col, int row) {
    return Offset(col * cellSize + cellSize / 2, row * cellSize + cellSize / 2);
  }

  /// (col,row) for a world point.
  (int, int) worldToCell(double x, double y) {
    return ((x / cellSize).floor(), (y / cellSize).floor());
  }

  bool contains(int col, int row) =>
      col >= 0 && col < cols && row >= 0 && row < rows;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```
flutter test test/grid_test.dart
```
Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

```
git add lib/game/grid/grid.dart test/grid_test.dart
git commit -m "feat(game): add Grid model with tests"
```

---

## Task 7: PathSegment with tests

**Files:**
- Create: `c:\dev\void_td\lib\game\path\path_segment.dart`
- Create: `c:\dev\void_td\test\path_segment_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test\path_segment_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:void_td/game/path/path_segment.dart';

void main() {
  group('PathSegment', () {
    // Simple L-shape: (0,0) -> (100,0) -> (100,100). totalLength = 200.
    final path = PathSegment(points: [
      Vector2(0, 0),
      Vector2(100, 0),
      Vector2(100, 100),
    ]);

    test('totalLength sums segment lengths', () {
      expect(path.totalLength, 200);
    });

    test('positionAt(0) returns the first point', () {
      final p = path.positionAt(0);
      expect(p.x, 0);
      expect(p.y, 0);
    });

    test('positionAt(1) returns the last point', () {
      final p = path.positionAt(1);
      expect(p.x, 100);
      expect(p.y, 100);
    });

    test('positionAt(0.5) returns the midpoint of the path (end of first segment)', () {
      final p = path.positionAt(0.5);
      expect(p.x, 100);
      expect(p.y, 0);
    });

    test('positionAt(0.25) is halfway along the first segment', () {
      final p = path.positionAt(0.25);
      expect(p.x, 50);
      expect(p.y, 0);
    });

    test('positionAt(0.75) is halfway along the second segment', () {
      final p = path.positionAt(0.75);
      expect(p.x, 100);
      expect(p.y, 50);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```
flutter test test/path_segment_test.dart
```
Expected: FAIL — `PathSegment` not defined.

- [ ] **Step 3: Implement PathSegment**

Create `lib\game\path\path_segment.dart`:
```dart
import 'package:flame/components.dart';

/// A piecewise-linear path through a list of world-space points.
/// Pure logic — no rendering.
class PathSegment {
  final List<Vector2> points;
  late final List<double> _cumulative;
  late final double totalLength;

  PathSegment({required this.points}) {
    assert(points.length >= 2, 'Path must have at least 2 points');
    _cumulative = List<double>.filled(points.length, 0);
    double sum = 0;
    for (var i = 1; i < points.length; i++) {
      sum += points[i - 1].distanceTo(points[i]);
      _cumulative[i] = sum;
    }
    totalLength = sum;
  }

  /// Returns world position at normalised progress [0..1].
  Vector2 positionAt(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    final target = clamped * totalLength;
    for (var i = 1; i < points.length; i++) {
      if (_cumulative[i] >= target) {
        final segLen = _cumulative[i] - _cumulative[i - 1];
        final t = segLen == 0 ? 0.0 : (target - _cumulative[i - 1]) / segLen;
        return points[i - 1] + (points[i] - points[i - 1]) * t;
      }
    }
    return points.last.clone();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```
flutter test test/path_segment_test.dart
```
Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```
git add lib/game/path/path_segment.dart test/path_segment_test.dart
git commit -m "feat(game): add PathSegment with progress-based position"
```

---

## Task 8: MatchState with tests

**Files:**
- Create: `c:\dev\void_td\lib\game\match\match_state.dart`
- Create: `c:\dev\void_td\test\match_state_test.dart`

This is the pure-Dart core of match logic: lives, gold, wave counter. No Flame, no widgets. Stage 1 only uses `lives`, `gold`, `currentWave`, but we set up the shape now so later stages just extend it.

- [ ] **Step 1: Write the failing test**

Create `test\match_state_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/game/match/match_state.dart';

void main() {
  group('MatchState', () {
    test('starts with given values', () {
      final s = MatchState(lives: 20, gold: 100);
      expect(s.lives, 20);
      expect(s.gold, 100);
      expect(s.currentWave, 0);
      expect(s.isGameOver, isFalse);
    });

    test('takeDamage reduces lives and never below zero', () {
      final s = MatchState(lives: 20, gold: 100);
      s.takeDamage(5);
      expect(s.lives, 15);
      s.takeDamage(50);
      expect(s.lives, 0);
      expect(s.isGameOver, isTrue);
    });

    test('addGold increases gold; spendGold decreases', () {
      final s = MatchState(lives: 20, gold: 100);
      s.addGold(25);
      expect(s.gold, 125);
      expect(s.spendGold(50), isTrue);
      expect(s.gold, 75);
    });

    test('spendGold refuses when not enough', () {
      final s = MatchState(lives: 20, gold: 30);
      expect(s.spendGold(50), isFalse);
      expect(s.gold, 30);
    });

    test('nextWave increments wave counter', () {
      final s = MatchState(lives: 20, gold: 100);
      s.nextWave();
      expect(s.currentWave, 1);
      s.nextWave();
      expect(s.currentWave, 2);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```
flutter test test/match_state_test.dart
```
Expected: FAIL — `MatchState` not defined.

- [ ] **Step 3: Implement MatchState**

Create `lib\game\match\match_state.dart`:
```dart
/// Pure-Dart state of a live match. No Flame, no widgets.
/// Mutated by game systems; observed by HUD via Riverpod in later tasks.
class MatchState {
  int lives;
  int gold;
  int currentWave;

  MatchState({required this.lives, required this.gold}) : currentWave = 0;

  bool get isGameOver => lives <= 0;

  void takeDamage(int amount) {
    lives = (lives - amount).clamp(0, 1 << 31);
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
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```
flutter test test/match_state_test.dart
```
Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```
git add lib/game/match/match_state.dart test/match_state_test.dart
git commit -m "feat(game): add MatchState core (lives, gold, wave)"
```

---

## Task 9: Hardcoded level config for Stage 1

**Files:**
- Create: `c:\dev\void_td\lib\data\level_one_config.dart`

The Stage 1 level is one fixed S-shaped path on a 9×16 grid, one wave of 10 Grunt enemies spawning 1 per second.

- [ ] **Step 1: Create the config**

Create `lib\data\level_one_config.dart`:
```dart
import 'package:flame/components.dart';
import '../game/grid/grid.dart';

class LevelOneConfig {
  static const Grid grid = Grid(cols: 9, rows: 16, cellSize: 40);

  /// World-space waypoints, top-to-bottom S-curve.
  /// Computed from the grid: enters at top-center, zig-zags, exits at bottom-center.
  static List<Vector2> get pathPoints {
    Vector2 c(int col, int row) {
      final o = grid.cellCenter(col, row);
      return Vector2(o.dx, o.dy);
    }
    // ignore: prefer_const_constructors
    return [
      c(4, 0),
      c(4, 3),
      c(1, 3),
      c(1, 7),
      c(7, 7),
      c(7, 11),
      c(4, 11),
      c(4, 15),
    ];
  }

  /// Stage 1 has one wave: 10 grunts, 1 second apart, starting after 1s.
  static const int waveEnemyCount = 10;
  static const double waveSpawnDelaySec = 1.0;
  static const double waveStartDelaySec = 1.0;

  /// Stage 1 starting resources.
  static const int startingLives = 20;
  static const int startingGold = 100;

  /// One enemy type in Stage 1.
  static const double enemyHp = 50;
  static const double enemySpeedPxPerSec = 60;
  static const int enemyBounty = 5;
  static const int enemyDamageToBase = 1;

  /// One tower type in Stage 1 (Basic Shot).
  static const int basicTowerCost = 50;
  static const double basicTowerRange = 120;
  static const double basicTowerDamage = 10;
  static const double basicTowerFireRatePerSec = 1.0;
  static const double basicProjectileSpeed = 300;
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```
git add lib/data/level_one_config.dart
git commit -m "feat(data): add hardcoded level 1 config"
```

---

## Task 10: Enemy component

**Files:**
- Create: `c:\dev\void_td\lib\game\components\enemy.dart`

- [ ] **Step 1: Implement Enemy**

Create `lib\game\components\enemy.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../path/path_segment.dart';

/// Stage 1 enemy: red dot that walks along a path. When it reaches the end
/// it calls onReachedEnd; when its hp reaches 0 it calls onKilled.
class Enemy extends PositionComponent {
  final PathSegment path;
  final double speedPxPerSec;
  final void Function(Enemy self) onReachedEnd;
  final void Function(Enemy self) onKilled;

  double hp;
  final double maxHp;
  double _distanceTravelled = 0;
  bool _removed = false;

  Enemy({
    required this.path,
    required this.speedPxPerSec,
    required this.hp,
    required this.onReachedEnd,
    required this.onKilled,
  })  : maxHp = hp,
        super(size: Vector2.all(12), anchor: Anchor.center);

  @override
  void onLoad() {
    position = path.positionAt(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_removed) return;
    _distanceTravelled += speedPxPerSec * dt;
    final progress = (_distanceTravelled / path.totalLength).clamp(0.0, 1.0);
    position = path.positionAt(progress);
    if (progress >= 1.0) {
      _removed = true;
      onReachedEnd(this);
      removeFromParent();
    }
  }

  void takeDamage(double amount) {
    if (_removed) return;
    hp -= amount;
    if (hp <= 0) {
      _removed = true;
      onKilled(this);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = AppColors.red;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 6, paint);
    // hp bar
    final barWidth = 16.0;
    final barHeight = 2.0;
    final bgRect = Rect.fromLTWH(-2, -8, barWidth, barHeight);
    final fgRect = Rect.fromLTWH(-2, -8, barWidth * (hp / maxHp), barHeight);
    canvas.drawRect(bgRect, Paint()..color = const Color(0xFF3A1A1A));
    canvas.drawRect(fgRect, paint);
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```
git add lib/game/components/enemy.dart
git commit -m "feat(game): add Enemy component"
```

---

## Task 11: Projectile component

**Files:**
- Create: `c:\dev\void_td\lib\game\components\projectile.dart`

- [ ] **Step 1: Implement Projectile**

Create `lib\game\components\projectile.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'enemy.dart';

/// Tracks a target Enemy and deals damage on contact.
class Projectile extends PositionComponent {
  final Enemy target;
  final double speed;
  final double damage;
  bool _spent = false;

  Projectile({
    required Vector2 start,
    required this.target,
    required this.speed,
    required this.damage,
  }) : super(position: start.clone(), size: Vector2.all(4), anchor: Anchor.center);

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
    final step = speed * dt;
    if (step >= dist) {
      target.takeDamage(damage);
      _spent = true;
      removeFromParent();
      return;
    }
    position += to.normalized() * step;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = AppColors.cyan;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 2, paint);
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```
git add lib/game/components/projectile.dart
git commit -m "feat(game): add Projectile component"
```

---

## Task 12: Tower component

**Files:**
- Create: `c:\dev\void_td\lib\game\components\tower.dart`

The Stage 1 tower:
- Is placed on a grid cell.
- Each `update`, finds the nearest enemy within range and shoots at it at fire-rate intervals.
- Spawns Projectile components into the parent (the FlameGame world).

- [ ] **Step 1: Implement Tower**

Create `lib\game\components\tower.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'enemy.dart';
import 'projectile.dart';

class Tower extends PositionComponent {
  final double range;
  final double damage;
  final double fireRatePerSec;
  final double projectileSpeed;

  /// Provides the current live enemies. Injected from the game.
  final List<Enemy> Function() enemiesProvider;

  double _cooldown = 0;

  Tower({
    required Vector2 worldPos,
    required this.range,
    required this.damage,
    required this.fireRatePerSec,
    required this.projectileSpeed,
    required this.enemiesProvider,
  }) : super(position: worldPos.clone(), size: Vector2.all(28), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _cooldown -= dt;
    if (_cooldown > 0) return;

    Enemy? closest;
    double bestDist = double.infinity;
    for (final e in enemiesProvider()) {
      final d = e.position.distanceTo(position);
      if (d <= range && d < bestDist) {
        closest = e;
        bestDist = d;
      }
    }
    if (closest == null) return;

    _cooldown = 1.0 / fireRatePerSec;
    parent?.add(Projectile(
      start: position,
      target: closest,
      speed: projectileSpeed,
      damage: damage,
    ));
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = AppColors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, 12, paint);
    canvas.drawCircle(center, 5, Paint()..color = AppColors.cyan);
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```
git add lib/game/components/tower.dart
git commit -m "feat(game): add Tower component"
```

---

## Task 13: WaveRunner with tests

**Files:**
- Create: `c:\dev\void_td\lib\game\waves\wave_runner.dart`
- Create: `c:\dev\void_td\test\wave_runner_test.dart`

WaveRunner is pure logic: given (count, delayBetween, startDelay), it tells the caller how many enemies to spawn given an elapsed time `dt`. The actual `Enemy` creation lives in the game class.

- [ ] **Step 1: Write the failing test**

Create `test\wave_runner_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/game/waves/wave_runner.dart';

void main() {
  group('WaveRunner', () {
    test('spawns nothing before startDelay', () {
      final w = WaveRunner(count: 5, spawnInterval: 1.0, startDelay: 2.0);
      expect(w.tick(0.5), 0);
      expect(w.tick(1.0), 0);
      expect(w.remaining, 5);
    });

    test('spawns one as soon as startDelay elapses', () {
      final w = WaveRunner(count: 5, spawnInterval: 1.0, startDelay: 1.0);
      expect(w.tick(1.0), 1);
      expect(w.remaining, 4);
    });

    test('spawns at the configured interval', () {
      final w = WaveRunner(count: 5, spawnInterval: 1.0, startDelay: 0);
      expect(w.tick(0.5), 1);   // first spawn at t=0
      expect(w.tick(0.4), 0);   // t=0.9
      expect(w.tick(0.2), 1);   // t=1.1 - 1s past first
      expect(w.tick(2.0), 2);   // t=3.1 - two more
    });

    test('stops after count is reached', () {
      final w = WaveRunner(count: 2, spawnInterval: 0.5, startDelay: 0);
      expect(w.tick(0.5), 1);
      expect(w.tick(0.5), 1);
      expect(w.remaining, 0);
      expect(w.tick(10.0), 0);
      expect(w.isDone, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```
flutter test test/wave_runner_test.dart
```
Expected: FAIL — `WaveRunner` not defined.

- [ ] **Step 3: Implement WaveRunner**

Create `lib\game\waves\wave_runner.dart`:
```dart
/// Stateless-ish spawn scheduler: call tick(dt) every frame; returns
/// how many enemies to spawn this frame.
class WaveRunner {
  final int count;
  final double spawnInterval;
  final double startDelay;

  int _spawned = 0;
  double _elapsed = 0;

  WaveRunner({
    required this.count,
    required this.spawnInterval,
    required this.startDelay,
  });

  int get remaining => count - _spawned;
  bool get isDone => _spawned >= count;

  int tick(double dt) {
    if (isDone) return 0;
    _elapsed += dt;
    if (_elapsed < startDelay) return 0;

    int spawnsThisTick = 0;
    while (!isDone) {
      final dueAt = startDelay + _spawned * spawnInterval;
      if (_elapsed >= dueAt) {
        _spawned += 1;
        spawnsThisTick += 1;
      } else {
        break;
      }
    }
    return spawnsThisTick;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```
flutter test test/wave_runner_test.dart
```
Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

```
git add lib/game/waves/wave_runner.dart test/wave_runner_test.dart
git commit -m "feat(game): add WaveRunner spawn scheduler with tests"
```

---

## Task 14: Grid and path renderers (visual feedback)

**Files:**
- Create: `c:\dev\void_td\lib\game\grid\grid_painter.dart`
- Create: `c:\dev\void_td\lib\game\path\path_renderer.dart`

- [ ] **Step 1: Implement GridPainter (Flame Component)**

Create `lib\game\grid\grid_painter.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'grid.dart';

class GridPainter extends Component {
  final Grid grid;
  GridPainter({required this.grid});

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.2)
      ..strokeWidth = 0.5;
    for (var c = 0; c <= grid.cols; c++) {
      final x = c * grid.cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, grid.height), paint);
    }
    for (var r = 0; r <= grid.rows; r++) {
      final y = r * grid.cellSize;
      canvas.drawLine(Offset(0, y), Offset(grid.width, y), paint);
    }
  }
}
```

- [ ] **Step 2: Implement PathRenderer (Flame Component)**

Create `lib\game\path\path_renderer.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'path_segment.dart';

class PathRenderer extends Component {
  final PathSegment path;
  PathRenderer({required this.path});

  @override
  void render(Canvas canvas) {
    final wide = Paint()
      ..color = AppColors.border.withOpacity(0.35)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final dashed = Paint()
      ..color = AppColors.cyan.withOpacity(0.4)
      ..strokeWidth = 0.8;

    for (var i = 1; i < path.points.length; i++) {
      final a = path.points[i - 1];
      final b = path.points[i];
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), wide);
      _drawDashedLine(canvas, Offset(a.x, a.y), Offset(b.x, b.y), dashed);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0;
    const gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double drawn = 0;
    while (drawn < total) {
      final segEnd = drawn + dash;
      final p1 = a + dir * drawn;
      final p2 = a + dir * (segEnd > total ? total : segEnd);
      canvas.drawLine(p1, p2, paint);
      drawn = segEnd + gap;
    }
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run:
```
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```
git add lib/game/grid/grid_painter.dart lib/game/path/path_renderer.dart
git commit -m "feat(game): add grid and path renderers"
```

---

## Task 15: TdGame — the FlameGame root

**Files:**
- Create: `c:\dev\void_td\lib\game\td_game.dart`

`TdGame` is the FlameGame. It:
- Loads grid + path renderers.
- Holds `MatchState`.
- Runs the wave: spawns Enemy components on cue.
- Maintains a list of live enemies (for towers to target).
- Handles tap on empty grid cell → places a Basic tower if gold ≥ cost.
- Calls back to the Flutter HUD when state changes (via a `ValueNotifier`).

- [ ] **Step 1: Implement TdGame**

Create `lib\game\td_game.dart`:
```dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../data/level_one_config.dart';
import 'components/enemy.dart';
import 'components/tower.dart';
import 'grid/grid_painter.dart';
import 'match/match_state.dart';
import 'path/path_renderer.dart';
import 'path/path_segment.dart';
import 'waves/wave_runner.dart';

class TdGame extends FlameGame with TapCallbacks {
  late final PathSegment path;
  late final WaveRunner wave;
  final List<Enemy> liveEnemies = [];
  final Set<(int, int)> occupiedCells = {};

  /// Drives the Flutter HUD. listenable.value is the current state snapshot.
  final ValueNotifier<MatchState> stateNotifier = ValueNotifier(
    MatchState(
      lives: LevelOneConfig.startingLives,
      gold: LevelOneConfig.startingGold,
    ),
  );

  MatchState get state => stateNotifier.value;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    final grid = LevelOneConfig.grid;
    path = PathSegment(points: LevelOneConfig.pathPoints);
    wave = WaveRunner(
      count: LevelOneConfig.waveEnemyCount,
      spawnInterval: LevelOneConfig.waveSpawnDelaySec,
      startDelay: LevelOneConfig.waveStartDelaySec,
    );

    // Centre the grid horizontally in the canvas.
    final offsetX = (size.x - grid.width) / 2;
    final offsetY = 80.0;
    final world = PositionComponent(position: Vector2(offsetX, offsetY));
    add(world);
    world.add(GridPainter(grid: grid));
    world.add(PathRenderer(path: path));

    // Keep references for tap-to-place math.
    _gridOrigin = Vector2(offsetX, offsetY);
    _world = world;

    state.nextWave(); // we're on wave 1
    stateNotifier.value = state; // trigger HUD refresh
  }

  late final Vector2 _gridOrigin;
  late final PositionComponent _world;

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

    // prune corpses from liveEnemies
    liveEnemies.removeWhere((e) => e.isRemoved);
  }

  void _onEnemyReachedEnd(Enemy e) {
    state.takeDamage(LevelOneConfig.enemyDamageToBase);
    stateNotifier.value = MatchState(lives: state.lives, gold: state.gold)
      ..currentWave = state.currentWave;
  }

  void _onEnemyKilled(Enemy e) {
    state.addGold(LevelOneConfig.enemyBounty);
    stateNotifier.value = MatchState(lives: state.lives, gold: state.gold)
      ..currentWave = state.currentWave;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (state.isGameOver) return;
    final local = event.localPosition - _gridOrigin;
    final grid = LevelOneConfig.grid;
    final (col, row) = grid.worldToCell(local.x, local.y);
    if (!grid.contains(col, row)) return;
    if (occupiedCells.contains((col, row))) return;
    if (_isOnPath(col, row)) return;
    if (!state.spendGold(LevelOneConfig.basicTowerCost)) return;

    final centre = grid.cellCenter(col, row);
    final tower = Tower(
      worldPos: Vector2(centre.dx, centre.dy),
      range: LevelOneConfig.basicTowerRange,
      damage: LevelOneConfig.basicTowerDamage,
      fireRatePerSec: LevelOneConfig.basicTowerFireRatePerSec,
      projectileSpeed: LevelOneConfig.basicProjectileSpeed,
      enemiesProvider: () => liveEnemies,
    );
    occupiedCells.add((col, row));
    _world.add(tower);
    stateNotifier.value = MatchState(lives: state.lives, gold: state.gold)
      ..currentWave = state.currentWave;
  }

  /// True if any path segment passes within half a cell of (col,row) centre.
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

Run:
```
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```
git add lib/game/td_game.dart
git commit -m "feat(game): add TdGame root with tap-to-place tower"
```

---

## Task 16: HUD widget and GameScreen wiring

**Files:**
- Create: `c:\dev\void_td\lib\game\match\hud.dart`
- Modify: `c:\dev\void_td\lib\game\game_screen.dart`

- [ ] **Step 1: Implement Hud**

Create `lib\game\match\hud.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'match_state.dart';

class Hud extends StatelessWidget {
  final MatchState state;
  const Hud({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
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
                shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 6)])),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 24,
        color: AppColors.border,
      );
}
```

- [ ] **Step 2: Wire GameScreen to TdGame and HUD**

Replace `lib\game\game_screen.dart` with:
```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import 'match/hud.dart';
import 'td_game.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final TdGame _game = TdGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder(
              valueListenable: _game.stateNotifier,
              builder: (_, state, __) => Hud(state: state),
            ),
            Expanded(child: GameWidget(game: _game)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run:
```
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 4: Run on a real device or emulator**

Run:
```
flutter run
```
Expected:
- Black screen, "VOID" main menu with PLAY and SETTINGS.
- Tap PLAY → black screen with HUD on top (WAVE 1 · LIVES 20 · GOLD 100) and grid + S-shaped path below.
- After 1 second, red dots start spawning at the top and walking along the path to the bottom.
- Tap an empty cell next to the path → cyan circle tower appears, gold drops to 50.
- Tower starts firing cyan dots at enemies. When an enemy dies, gold += 5. When one reaches the bottom, lives -= 1.
- After 10 enemies have walked through, the wave stops spawning.

- [ ] **Step 5: Commit**

```
git add lib/game/match/hud.dart lib/game/game_screen.dart
git commit -m "feat(game): wire HUD, TdGame and tap-to-place into GameScreen"
```

---

## Task 17: Run all tests and analyze before wrapping up

- [ ] **Step 1: Run the full test suite**

Run:
```
flutter test
```
Expected: all tests in `test/` pass (4 files, ~19 tests total). No failures.

- [ ] **Step 2: Run analyze across the project**

Run:
```
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Final commit — tag end of Stage 1**

If there are uncommitted changes (e.g. small fixups during testing), commit them first, then tag:
```
git status
git tag stage-1-skeleton
```

- [ ] **Step 4: Sanity README**

Create `c:\dev\void_td\README.md`:
```markdown
# VOID TD

Minimalist OLED-first Tower Defense for Android & iOS. Built with Flutter + Flame.

## Status

Stage 1 (playable skeleton): one tower type, one enemy type, one fixed-path level.

See `docs/superpowers/specs/2026-05-21-tower-defense-mvp-design.md` (in the parent
`flutter_application_1` workspace) for the full design.

## Run

```
flutter pub get
flutter run
```

## Test

```
flutter test
```
```

Commit:
```
git add README.md
git commit -m "docs: add Stage 1 README"
```

---

## Done

After Task 17 you have:
- A `void_td` Flutter project (portrait-locked, OLED theme).
- A working main menu screen.
- A playable level 1 skeleton: tap to place a Basic tower, fights one wave of Grunts on a fixed S-path.
- Unit tests for grid, path, match state, and wave scheduling.
- A clean git history of small commits.

**Next plan (separate file):** Stage 2 — all 5 towers, 4+1 enemies, upgrade branches, full economy (passive + farms tick + clean-wave bonus), pause + speed control, save & resume via Hive.
