# VOID TD — Stage 4 (Polish: Audio + Locale + Haptic + Settings) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add audio (10 SFX + 6 music tracks), localization infrastructure with EN as source and KK/RU as TODO stubs, haptic feedback service, and a full Settings screen with audio sliders / haptic toggle / reduce-effects toggle / language radios / credits.

**Architecture:** Three new services (`AudioService`, `HapticService`, `SettingsController`) sit in `lib/audio/`, `lib/haptics/`, `lib/settings/`. SettingsController (Riverpod StateNotifier) is the single source of truth, persisted via Hive. AudioService subscribes to volume changes; HapticService gates calls on `hapticOn`. All UI strings move to `app_en.arb` via `flutter gen-l10n` codegen. Settings screen reachable from main menu and in-game pause dialog.

**Tech Stack:** Flutter 3.x + Flame 1.37, `flame_audio` (added), `flutter_localizations` + `intl` (added), Riverpod 2.x, Hive 2.x. Repo: `c:\dev\void_td` (not the workspace root).

**Spec:** `docs/superpowers/specs/2026-05-24-void-td-stage-4-polish-design.md`

---

## File Structure

**Created:**
- `assets/audio/sfx/` — 10 .wav files (downloaded in Task 17)
- `assets/audio/music/` — 6 .ogg files (downloaded in Task 17)
- `assets/audio/CREDITS.md` — CC-BY attributions
- `lib/audio/sfx_ids.dart` — `enum SfxId`
- `lib/audio/music_ids.dart` — `enum MusicId`
- `lib/audio/audio_service.dart` — playback facade
- `lib/haptics/haptic_service.dart` — gated wrapper
- `lib/settings/settings.dart` — immutable `Settings` model
- `lib/settings/settings_repo.dart` — Hive persistence
- `lib/settings/settings_controller.dart` — Riverpod StateNotifier
- `lib/l10n/app_en.arb` — source of truth (~50 keys)
- `lib/l10n/app_kk.arb` — TODO stubs
- `lib/l10n/app_ru.arb` — TODO stubs
- `lib/ui/settings/settings_screen.dart`
- `lib/ui/settings/neon_slider.dart`
- `lib/ui/settings/neon_toggle.dart`
- `lib/ui/settings/credits_screen.dart`
- `l10n.yaml` (project root)
- `test/audio_service_test.dart`
- `test/haptic_service_test.dart`
- `test/settings_repo_test.dart`
- `test/settings_controller_test.dart`
- `test/settings_screen_test.dart`

**Modified:**
- `pubspec.yaml` — add `flame_audio`, `intl`, `flutter_localizations`, `generate: true`, asset paths
- `lib/main.dart` — init `AudioService`, `SettingsRepo`, load settings into controller
- `lib/app.dart` — wire `localizationsDelegates`, `supportedLocales`, dynamic `locale`
- `lib/game/td_game.dart` — fire SFX from `_placeAt`, `_startNextWave`, `_onWaveCleared`, `_onEnemyReachedEnd`, `sellSelected`, `_upgradeTower`, `_upgradeFarm`
- `lib/game/components/projectile.dart` — fire `hit` SFX from `_onHit` (with throttle)
- `lib/game/game_screen.dart` — fire victory/defeat SFX + haptic; pause/resume music on lifecycle; trigger music change on init; haptic on leak
- `lib/ui/main_menu/main_menu_screen.dart` — enable SETTINGS button, navigate to `SettingsScreen`; trigger menu music on init
- `lib/ui/shared/neon_button.dart` — emit `uiClick` SFX + `light` haptic in `onPressed` wrapper
- `lib/game/components/enemy.dart` — read `EffectsConfig.reduced` for burn/slow render
- All UI files with hardcoded strings — replace with `AppLocalizations.of(context)!.<key>`

---

## Task 1: Add new package dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Run `flutter pub add` to add packages with resolved versions**

```bash
cd c:/dev/void_td
flutter pub add flame_audio intl
flutter pub add flutter_localizations --sdk=flutter
```

Expected: `pubspec.yaml` now contains `flame_audio: ^X.Y.Z`, `intl: ^X.Y.Z`, `flutter_localizations: { sdk: flutter }`. `flutter pub get` runs automatically.

- [ ] **Step 2: Enable `generate: true` and add asset folders in pubspec.yaml**

Open `pubspec.yaml`, find the `flutter:` section near the bottom, modify it to look like this (preserve any existing `uses-material-design`, `assets`, `fonts` entries; add `generate: true` and the audio asset lines):

```yaml
flutter:
  generate: true
  uses-material-design: true
  assets:
    - assets/configs/
    - assets/configs/levels/
    - assets/audio/sfx/
    - assets/audio/music/
    - assets/audio/CREDITS.md
```

(If `assets/configs/` lines don't exist yet, leave them out — only add the audio lines.)

- [ ] **Step 3: Verify the build still works**

Run: `cd c:/dev/void_td && flutter pub get && flutter analyze`
Expected: `No issues found!` (the audio asset paths don't exist yet but that's fine — pubspec validation doesn't check existence).

- [ ] **Step 4: Commit**

```bash
cd c:/dev/void_td
git add pubspec.yaml pubspec.lock
git commit -m "feat(stage4): add flame_audio, intl, flutter_localizations deps"
```

---

## Task 2: Create Settings model

**Files:**
- Create: `c:/dev/void_td/lib/settings/settings.dart`

- [ ] **Step 1: Write the failing test**

Create `c:/dev/void_td/test/settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/settings/settings.dart';

void main() {
  group('Settings', () {
    test('defaults', () {
      const s = Settings.defaults();
      expect(s.sfxVolume, 0.45);
      expect(s.musicVolume, 0.60);
      expect(s.hapticOn, true);
      expect(s.reduceEffects, false);
      expect(s.localeCode, null);
    });

    test('copyWith overrides only specified fields', () {
      const s = Settings.defaults();
      final s2 = s.copyWith(sfxVolume: 0.8, hapticOn: false);
      expect(s2.sfxVolume, 0.8);
      expect(s2.hapticOn, false);
      expect(s2.musicVolume, 0.60); // unchanged
      expect(s2.localeCode, null);  // unchanged
    });

    test('toMap / fromMap round-trip', () {
      const s = Settings(
        sfxVolume: 0.3, musicVolume: 0.7, hapticOn: false,
        reduceEffects: true, localeCode: 'ru');
      final restored = Settings.fromMap(s.toMap());
      expect(restored.sfxVolume, 0.3);
      expect(restored.musicVolume, 0.7);
      expect(restored.hapticOn, false);
      expect(restored.reduceEffects, true);
      expect(restored.localeCode, 'ru');
    });

    test('fromMap handles missing fields with defaults', () {
      final s = Settings.fromMap({});
      expect(s.sfxVolume, 0.45);
      expect(s.musicVolume, 0.60);
      expect(s.hapticOn, true);
      expect(s.reduceEffects, false);
      expect(s.localeCode, null);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd c:/dev/void_td && flutter test test/settings_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:void_td/settings/settings.dart'"

- [ ] **Step 3: Create the Settings class**

Create `c:/dev/void_td/lib/settings/settings.dart`:

```dart
/// Immutable user-controlled app settings. Persisted via SettingsRepo.
class Settings {
  final double sfxVolume;    // 0..1
  final double musicVolume;  // 0..1
  final bool hapticOn;
  final bool reduceEffects;
  /// null = follow system locale; otherwise one of 'en' | 'kk' | 'ru'.
  final String? localeCode;

  const Settings({
    required this.sfxVolume,
    required this.musicVolume,
    required this.hapticOn,
    required this.reduceEffects,
    required this.localeCode,
  });

  const Settings.defaults()
      : sfxVolume = 0.45,
        musicVolume = 0.60,
        hapticOn = true,
        reduceEffects = false,
        localeCode = null;

  Settings copyWith({
    double? sfxVolume,
    double? musicVolume,
    bool? hapticOn,
    bool? reduceEffects,
    Object? localeCode = _sentinel, // sentinel so we can pass explicit null
  }) {
    return Settings(
      sfxVolume: sfxVolume ?? this.sfxVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      hapticOn: hapticOn ?? this.hapticOn,
      reduceEffects: reduceEffects ?? this.reduceEffects,
      localeCode: identical(localeCode, _sentinel)
          ? this.localeCode
          : localeCode as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'sfxVolume': sfxVolume,
        'musicVolume': musicVolume,
        'hapticOn': hapticOn,
        'reduceEffects': reduceEffects,
        if (localeCode != null) 'localeCode': localeCode,
      };

  static Settings fromMap(Map raw) {
    const d = Settings.defaults();
    final m = Map<String, dynamic>.from(raw);
    return Settings(
      sfxVolume: (m['sfxVolume'] as num?)?.toDouble() ?? d.sfxVolume,
      musicVolume: (m['musicVolume'] as num?)?.toDouble() ?? d.musicVolume,
      hapticOn: m['hapticOn'] as bool? ?? d.hapticOn,
      reduceEffects: m['reduceEffects'] as bool? ?? d.reduceEffects,
      localeCode: m['localeCode'] as String?,
    );
  }
}

const Object _sentinel = Object();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd c:/dev/void_td && flutter test test/settings_test.dart`
Expected: PASS, all 4 tests.

- [ ] **Step 5: Commit**

```bash
cd c:/dev/void_td
git add lib/settings/settings.dart test/settings_test.dart
git commit -m "feat(settings): add Settings model with defaults and round-trip"
```

---

## Task 3: Create SettingsRepo (Hive persistence)

**Files:**
- Create: `c:/dev/void_td/lib/settings/settings_repo.dart`
- Create: `c:/dev/void_td/test/settings_repo_test.dart`

- [ ] **Step 1: Write the failing test**

Create `c:/dev/void_td/test/settings_repo_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:void_td/settings/settings.dart';
import 'package:void_td/settings/settings_repo.dart';
import 'dart:io';

class _FakePathProvider extends PathProviderPlatform {
  final String tmp;
  _FakePathProvider(this.tmp);
  @override
  Future<String?> getApplicationDocumentsPath() async => tmp;
  @override
  Future<String?> getTemporaryPath() async => tmp;
  @override
  Future<String?> getApplicationSupportPath() async => tmp;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('void_td_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    Hive.init(tmp.path);
    await SettingsRepo.init();
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(SettingsRepo.boxName);
    await tmp.delete(recursive: true);
  });

  test('load returns defaults when no save exists', () {
    final s = SettingsRepo.load();
    expect(s.sfxVolume, 0.45);
    expect(s.musicVolume, 0.60);
    expect(s.hapticOn, true);
  });

  test('save then load returns identical settings', () async {
    const s = Settings(
      sfxVolume: 0.2, musicVolume: 0.9, hapticOn: false,
      reduceEffects: true, localeCode: 'kk');
    await SettingsRepo.save(s);
    final restored = SettingsRepo.load();
    expect(restored.sfxVolume, 0.2);
    expect(restored.musicVolume, 0.9);
    expect(restored.hapticOn, false);
    expect(restored.reduceEffects, true);
    expect(restored.localeCode, 'kk');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd c:/dev/void_td && flutter test test/settings_repo_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:void_td/settings/settings_repo.dart'"

- [ ] **Step 3: Implement SettingsRepo**

Create `c:/dev/void_td/lib/settings/settings_repo.dart`:

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'settings.dart';

/// Hive-backed persistence for Settings. Single key 'current' in box 'settings'.
class SettingsRepo {
  static const boxName = 'settings';
  static const _key = 'current';
  static Box? _box;

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      _box = await Hive.openBox(boxName);
    } else {
      _box = Hive.box(boxName);
    }
  }

  static Settings load() {
    final raw = _box?.get(_key);
    if (raw is Map) return Settings.fromMap(raw);
    return const Settings.defaults();
  }

  static Future<void> save(Settings s) async {
    await _box?.put(_key, s.toMap());
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd c:/dev/void_td && flutter test test/settings_repo_test.dart`
Expected: PASS, both tests.

- [ ] **Step 5: Commit**

```bash
cd c:/dev/void_td
git add lib/settings/settings_repo.dart test/settings_repo_test.dart
git commit -m "feat(settings): add Hive-backed SettingsRepo with round-trip persistence"
```

---

## Task 4: Create SettingsController (Riverpod StateNotifier)

**Files:**
- Create: `c:/dev/void_td/lib/settings/settings_controller.dart`
- Create: `c:/dev/void_td/test/settings_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `c:/dev/void_td/test/settings_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:void_td/settings/settings.dart';
import 'package:void_td/settings/settings_controller.dart';
import 'package:void_td/settings/settings_repo.dart';
import 'dart:io';

class _FakePathProvider extends PathProviderPlatform {
  final String tmp;
  _FakePathProvider(this.tmp);
  @override
  Future<String?> getApplicationDocumentsPath() async => tmp;
  @override
  Future<String?> getTemporaryPath() async => tmp;
  @override
  Future<String?> getApplicationSupportPath() async => tmp;
}

void main() {
  late Directory tmp;
  late ProviderContainer container;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('void_td_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    Hive.init(tmp.path);
    await SettingsRepo.init();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteBoxFromDisk(SettingsRepo.boxName);
    await tmp.delete(recursive: true);
  });

  test('initial state matches repo (defaults when empty)', () {
    final s = container.read(settingsControllerProvider);
    expect(s.sfxVolume, 0.45);
  });

  test('setSfxVolume updates state and persists', () async {
    container.read(settingsControllerProvider.notifier).setSfxVolume(0.8);
    expect(container.read(settingsControllerProvider).sfxVolume, 0.8);
    // Reload from disk
    final reloaded = SettingsRepo.load();
    expect(reloaded.sfxVolume, 0.8);
  });

  test('setHapticOn toggles', () {
    container.read(settingsControllerProvider.notifier).setHapticOn(false);
    expect(container.read(settingsControllerProvider).hapticOn, false);
  });

  test('setLocale to "ru"', () {
    container.read(settingsControllerProvider.notifier).setLocale('ru');
    expect(container.read(settingsControllerProvider).localeCode, 'ru');
  });

  test('setLocale to null clears override', () {
    container.read(settingsControllerProvider.notifier).setLocale('ru');
    container.read(settingsControllerProvider.notifier).setLocale(null);
    expect(container.read(settingsControllerProvider).localeCode, null);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd c:/dev/void_td && flutter test test/settings_controller_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:void_td/settings/settings_controller.dart'"

- [ ] **Step 3: Implement SettingsController**

Create `c:/dev/void_td/lib/settings/settings_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings.dart';
import 'settings_repo.dart';

/// Single source of truth for app settings. Reads initial state from
/// SettingsRepo (which must be initialised before the container is created).
/// Every setter persists to Hive before notifying listeners.
class SettingsController extends StateNotifier<Settings> {
  SettingsController() : super(SettingsRepo.load());

  void setSfxVolume(double v) {
    state = state.copyWith(sfxVolume: v.clamp(0.0, 1.0));
    SettingsRepo.save(state);
  }

  void setMusicVolume(double v) {
    state = state.copyWith(musicVolume: v.clamp(0.0, 1.0));
    SettingsRepo.save(state);
  }

  void setHapticOn(bool on) {
    state = state.copyWith(hapticOn: on);
    SettingsRepo.save(state);
  }

  void setReduceEffects(bool on) {
    state = state.copyWith(reduceEffects: on);
    SettingsRepo.save(state);
  }

  void setLocale(String? code) {
    state = state.copyWith(localeCode: code);
    SettingsRepo.save(state);
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, Settings>(
        (ref) => SettingsController());
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd c:/dev/void_td && flutter test test/settings_controller_test.dart`
Expected: PASS, all 5 tests.

- [ ] **Step 5: Commit**

```bash
cd c:/dev/void_td
git add lib/settings/settings_controller.dart test/settings_controller_test.dart
git commit -m "feat(settings): add Riverpod SettingsController with persistence"
```

---

## Task 5: Create HapticService

**Files:**
- Create: `c:/dev/void_td/lib/haptics/haptic_service.dart`
- Create: `c:/dev/void_td/test/haptic_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `c:/dev/void_td/test/haptic_service_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/haptics/haptic_service.dart';

void main() {
  late List<String> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String? ?? '');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('triggers when hapticOn=true', () {
    final svc = HapticService(() => true);
    svc.trigger(HapticKind.light);
    expect(calls, isNotEmpty);
  });

  test('no-op when hapticOn=false', () {
    final svc = HapticService(() => false);
    svc.trigger(HapticKind.light);
    svc.trigger(HapticKind.heavy);
    expect(calls, isEmpty);
  });

  test('different kinds map to different platform feedback', () {
    final svc = HapticService(() => true);
    svc.trigger(HapticKind.light);
    svc.trigger(HapticKind.medium);
    svc.trigger(HapticKind.heavy);
    expect(calls.length, 3);
    expect(calls[0], contains('Light'));
    expect(calls[1], contains('Medium'));
    expect(calls[2], contains('Heavy'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd c:/dev/void_td && flutter test test/haptic_service_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:void_td/haptics/haptic_service.dart'"

- [ ] **Step 3: Implement HapticService**

Create `c:/dev/void_td/lib/haptics/haptic_service.dart`:

```dart
import 'package:flutter/services.dart';

enum HapticKind { light, medium, heavy }

/// Vibration wrapper. Reads the on/off flag through a callback so a single
/// instance can stay valid across Riverpod state changes without rebuilding.
class HapticService {
  final bool Function() _isEnabled;

  HapticService(this._isEnabled);

  void trigger(HapticKind kind) {
    if (!_isEnabled()) return;
    switch (kind) {
      case HapticKind.light:
        HapticFeedback.lightImpact();
        break;
      case HapticKind.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticKind.heavy:
        HapticFeedback.heavyImpact();
        break;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd c:/dev/void_td && flutter test test/haptic_service_test.dart`
Expected: PASS, all 3 tests.

- [ ] **Step 5: Commit**

```bash
cd c:/dev/void_td
git add lib/haptics/haptic_service.dart test/haptic_service_test.dart
git commit -m "feat(haptics): add HapticService with gated trigger by settings flag"
```

---

## Task 6: Create SfxId / MusicId enums

**Files:**
- Create: `c:/dev/void_td/lib/audio/sfx_ids.dart`
- Create: `c:/dev/void_td/lib/audio/music_ids.dart`

- [ ] **Step 1: Create SfxId enum**

Create `c:/dev/void_td/lib/audio/sfx_ids.dart`:

```dart
/// Identifier for an SFX clip. The string value is the filename
/// (without 'sfx/' prefix) under assets/audio/sfx/.
enum SfxId {
  hit('hit.wav'),
  place('place.wav'),
  upgrade('upgrade.wav'),
  sell('sell.wav'),
  leak('leak.wav'),
  waveStart('wave_start.wav'),
  waveClear('wave_clear.wav'),
  uiClick('ui_click.wav'),
  victory('victory.wav'),
  defeat('defeat.wav');

  final String file;
  const SfxId(this.file);
}
```

- [ ] **Step 2: Create MusicId enum**

Create `c:/dev/void_td/lib/audio/music_ids.dart`:

```dart
/// Identifier for a music track. The string value is the filename
/// (without 'music/' prefix) under assets/audio/music/.
enum MusicId {
  menu('menu.ogg'),
  campaign('campaign.ogg'),
  endless('endless.ogg'),
  constructor('constructor.ogg'),
  victoryLoop('victory_loop.ogg'),
  defeatLoop('defeat_loop.ogg');

  final String file;
  const MusicId(this.file);
}
```

- [ ] **Step 3: Verify analyze passes**

Run: `cd c:/dev/void_td && flutter analyze lib/audio/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
cd c:/dev/void_td
git add lib/audio/sfx_ids.dart lib/audio/music_ids.dart
git commit -m "feat(audio): add SfxId and MusicId enums mapping to asset filenames"
```

---

## Task 7: Create AudioService with throttling

**Files:**
- Create: `c:/dev/void_td/lib/audio/audio_service.dart`
- Create: `c:/dev/void_td/test/audio_service_test.dart`

- [ ] **Step 1: Write the failing test for throttling logic**

Create `c:/dev/void_td/test/audio_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_td/audio/audio_service.dart';
import 'package:void_td/audio/sfx_ids.dart';

void main() {
  group('AudioService.shouldPlay (throttling)', () {
    test('first call always passes', () {
      final svc = AudioService.forTesting();
      expect(svc.shouldPlay(SfxId.hit, atMs: 0), true);
    });

    test('second call within throttle window is blocked', () {
      final svc = AudioService.forTesting();
      svc.shouldPlay(SfxId.hit, atMs: 0);
      expect(svc.shouldPlay(SfxId.hit, atMs: 25), false);
    });

    test('second call after throttle window passes', () {
      final svc = AudioService.forTesting();
      svc.shouldPlay(SfxId.hit, atMs: 0);
      expect(svc.shouldPlay(SfxId.hit, atMs: 60), true);
    });

    test('different SfxIds are throttled independently', () {
      final svc = AudioService.forTesting();
      svc.shouldPlay(SfxId.hit, atMs: 0);
      expect(svc.shouldPlay(SfxId.place, atMs: 0), true);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd c:/dev/void_td && flutter test test/audio_service_test.dart`
Expected: FAIL with import error.

- [ ] **Step 3: Implement AudioService**

Create `c:/dev/void_td/lib/audio/audio_service.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flame_audio/flame_audio.dart';
import 'music_ids.dart';
import 'sfx_ids.dart';

/// Single-instance facade over FlameAudio + a long-lived music AudioPlayer.
/// Volumes are applied live: SFX volume to each new play; music to the
/// running track instantly.
class AudioService {
  static const _sfxThrottleMs = 50;

  double _sfxVolume = 0.45;
  double _musicVolume = 0.60;
  final Map<SfxId, int> _lastPlayedAtMs = {};
  AudioPlayer? _musicPlayer;
  MusicId? _currentMusic;
  bool _initialized = false;

  AudioService();

  /// Test-only constructor that skips disk preload.
  AudioService.forTesting() : _initialized = true;

  Future<void> init() async {
    if (_initialized) return;
    // Preload all SFX so first play has no disk-read jank.
    await FlameAudio.audioCache.loadAll(
      SfxId.values.map((s) => 'sfx/${s.file}').toList(),
    );
    _initialized = true;
  }

  void setSfxVolume(double v) => _sfxVolume = v.clamp(0.0, 1.0);

  void setMusicVolume(double v) {
    _musicVolume = v.clamp(0.0, 1.0);
    _musicPlayer?.setVolume(_musicVolume);
  }

  /// Returns true if the SFX should actually play given the throttle window.
  /// Public so it can be unit-tested without audio setup. Mutates the
  /// per-id last-played timestamp.
  bool shouldPlay(SfxId id, {int? atMs}) {
    final now = atMs ?? DateTime.now().millisecondsSinceEpoch;
    final last = _lastPlayedAtMs[id];
    if (last != null && now - last < _sfxThrottleMs) return false;
    _lastPlayedAtMs[id] = now;
    return true;
  }

  Future<void> playSfx(SfxId id) async {
    if (!_initialized) return;
    if (!shouldPlay(id)) return;
    await FlameAudio.play('sfx/${id.file}', volume: _sfxVolume);
  }

  Future<void> playMusic(MusicId id, {bool loop = true}) async {
    if (_currentMusic == id && _musicPlayer != null) return;
    await stopMusic();
    final player = AudioPlayer();
    await player.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release);
    await player.setVolume(_musicVolume);
    await player.play(AssetSource('audio/music/${id.file}'));
    _musicPlayer = player;
    _currentMusic = id;
  }

  Future<void> stopMusic() async {
    await _musicPlayer?.stop();
    await _musicPlayer?.dispose();
    _musicPlayer = null;
    _currentMusic = null;
  }

  Future<void> pauseMusic() async => _musicPlayer?.pause();
  Future<void> resumeMusic() async => _musicPlayer?.resume();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd c:/dev/void_td && flutter test test/audio_service_test.dart`
Expected: PASS, all 4 tests.

- [ ] **Step 5: Commit**

```bash
cd c:/dev/void_td
git add lib/audio/audio_service.dart test/audio_service_test.dart
git commit -m "feat(audio): add AudioService with SFX throttling and music transitions"
```

---

## Task 8: Create silent stub WAV asset (fallback for missing SFX)

**Files:**
- Create: `c:/dev/void_td/assets/audio/sfx/silent_50ms.wav`
- Create: `c:/dev/void_td/assets/audio/CREDITS.md`

- [ ] **Step 1: Create the silent WAV (50ms of silence, 44.1kHz mono 16-bit)**

Run (PowerShell — generates a 4456-byte WAV with RIFF header + 2205 zero samples):

```powershell
$bytes = [byte[]]::new(44 + 4410)
# RIFF header
[byte[]][char[]]'RIFF' | ForEach-Object { $i = 0 } { $bytes[$i++] = $_ }
$bytes[4..7] = [BitConverter]::GetBytes(36 + 4410)
[byte[]][char[]]'WAVE' | ForEach-Object { $i = 8 } { $bytes[$i++] = $_ }
# fmt chunk
[byte[]][char[]]'fmt ' | ForEach-Object { $i = 12 } { $bytes[$i++] = $_ }
$bytes[16..19] = [BitConverter]::GetBytes([int]16)        # fmt size
$bytes[20..21] = [BitConverter]::GetBytes([short]1)       # PCM
$bytes[22..23] = [BitConverter]::GetBytes([short]1)       # mono
$bytes[24..27] = [BitConverter]::GetBytes([int]44100)
$bytes[28..31] = [BitConverter]::GetBytes([int]88200)     # byte rate
$bytes[32..33] = [BitConverter]::GetBytes([short]2)       # block align
$bytes[34..35] = [BitConverter]::GetBytes([short]16)      # bits/sample
# data chunk
[byte[]][char[]]'data' | ForEach-Object { $i = 36 } { $bytes[$i++] = $_ }
$bytes[40..43] = [BitConverter]::GetBytes([int]4410)
[System.IO.File]::WriteAllBytes('c:\dev\void_td\assets\audio\sfx\silent_50ms.wav', $bytes)
```

(If the PowerShell snippet is finicky, use any audio tool — Audacity → "Generate silence 0.05s" → export 44.1kHz mono PCM WAV — and save to the same path.)

- [ ] **Step 2: Create CREDITS.md template**

Create `c:/dev/void_td/assets/audio/CREDITS.md`:

```markdown
# VOID TD — Audio Credits

All audio assets are licensed under Creative Commons. CC0 entries
require no attribution; CC-BY entries are credited below.

## SFX

| File              | Author | License | Source |
| ---               | ---    | ---     | ---    |
| hit.wav           | TBD    | TBD     | TBD    |
| place.wav         | TBD    | TBD     | TBD    |
| upgrade.wav       | TBD    | TBD     | TBD    |
| sell.wav          | TBD    | TBD     | TBD    |
| leak.wav          | TBD    | TBD     | TBD    |
| wave_start.wav    | TBD    | TBD     | TBD    |
| wave_clear.wav    | TBD    | TBD     | TBD    |
| ui_click.wav      | TBD    | TBD     | TBD    |
| victory.wav       | TBD    | TBD     | TBD    |
| defeat.wav        | TBD    | TBD     | TBD    |
| silent_50ms.wav   | —      | n/a     | generated (fallback) |

## Music

| File              | Author | License | Source |
| ---               | ---    | ---     | ---    |
| menu.ogg          | TBD    | TBD     | TBD    |
| campaign.ogg      | TBD    | TBD     | TBD    |
| endless.ogg       | TBD    | TBD     | TBD    |
| constructor.ogg   | TBD    | TBD     | TBD    |
| victory_loop.ogg  | TBD    | TBD     | TBD    |
| defeat_loop.ogg   | TBD    | TBD     | TBD    |

The TBD entries are filled in by Task 17 (asset acquisition).
```

- [ ] **Step 3: Create stub WAV files for all SFX (copies of silent_50ms.wav so app boots)**

Run (Git Bash):

```bash
cd c:/dev/void_td/assets/audio/sfx
for f in hit place upgrade sell leak wave_start wave_clear ui_click victory defeat; do
  cp silent_50ms.wav "${f}.wav"
done
ls -la *.wav
```

Expected: 11 WAV files (10 stubs + silent_50ms.wav), each ~4.4 KB.

- [ ] **Step 4: Create stub OGG files for music (we use silent WAVs renamed to .ogg as placeholders — audioplayers will fail-silent if format mismatches, but app boots; real OGGs come in Task 17)**

Actually, audioplayers will throw on non-OGG content with .ogg extension. To stay safe, also create empty placeholder OGGs that fail gracefully — easier: defer music wiring tolerance to AudioService and just leave music folder empty for now. Update AudioService to swallow play errors:

Modify `c:/dev/void_td/lib/audio/audio_service.dart`, wrap `player.play(...)` in try/catch:

```dart
  Future<void> playMusic(MusicId id, {bool loop = true}) async {
    if (_currentMusic == id && _musicPlayer != null) return;
    await stopMusic();
    final player = AudioPlayer();
    await player.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release);
    await player.setVolume(_musicVolume);
    try {
      await player.play(AssetSource('audio/music/${id.file}'));
      _musicPlayer = player;
      _currentMusic = id;
    } catch (e) {
      // Missing or bad-format track — swallow so the game keeps running.
      // Task 17 fills in real tracks.
      await player.dispose();
    }
  }
```

- [ ] **Step 5: Verify the app builds with the stubs**

Run: `cd c:/dev/void_td && flutter pub get && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd c:/dev/void_td
git add assets/audio/ lib/audio/audio_service.dart
git commit -m "feat(audio): add silent stub SFX assets + CREDITS.md template"
```

---

## Task 9: Wire AudioService + SettingsController + HapticService into app init

**Files:**
- Modify: `c:/dev/void_td/lib/main.dart`
- Modify: `c:/dev/void_td/lib/app.dart`

- [ ] **Step 1: Read current main.dart to know exact starting state**

Run: `cd c:/dev/void_td && cat lib/main.dart`
Expected output: existing main.dart with ProfileRepo.init() and SnapshotRepo.init().

- [ ] **Step 2: Modify main.dart to init SettingsRepo and create AudioService/HapticService providers**

Replace `c:/dev/void_td/lib/main.dart` content with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'audio/audio_service.dart';
import 'game/match/snapshot_repo.dart';
import 'haptics/haptic_service.dart';
import 'meta/profile/profile_repo.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_repo.dart';

/// Single AudioService instance. Provided to the widget tree via Riverpod
/// so widgets and the Flame game can both reach it.
final audioServiceProvider = Provider<AudioService>((ref) {
  throw UnimplementedError('overridden in main()');
});

/// HapticService that reads the current settings.hapticOn flag each call.
final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(() => ref.read(settingsControllerProvider).hapticOn);
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await ProfileRepo.init();
  await SnapshotRepo.init();
  await SettingsRepo.init();

  final audio = AudioService();
  // Init audio AFTER first frame to avoid colliding with build pass.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    audio.init();
  });

  runApp(
    ProviderScope(
      overrides: [
        audioServiceProvider.overrideWithValue(audio),
      ],
      child: const VoidApp(),
    ),
  );
}
```

- [ ] **Step 3: Verify analyze passes**

Run: `cd c:/dev/void_td && flutter analyze lib/main.dart`
Expected: `No issues found!` (app.dart will be updated next).

- [ ] **Step 4: Subscribe AudioService to volume changes**

We need AudioService volumes to follow SettingsController. Easiest: add a listener inside `VoidApp` build via `ref.listen`. But first inspect app.dart:

Run: `cd c:/dev/void_td && cat lib/app.dart`

If `VoidApp` is a `StatelessWidget`, convert it to `ConsumerWidget` and add the listen. Replace `c:/dev/void_td/lib/app.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/colors.dart';
import 'main.dart' show audioServiceProvider;
import 'settings/settings_controller.dart';
import 'ui/main_menu/main_menu_screen.dart';

class VoidApp extends ConsumerWidget {
  const VoidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep AudioService volumes in sync with settings.
    final settings = ref.watch(settingsControllerProvider);
    final audio = ref.read(audioServiceProvider);
    audio.setSfxVolume(settings.sfxVolume);
    audio.setMusicVolume(settings.musicVolume);

    return MaterialApp(
      title: 'VOID TD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}
```

(If your existing `app.dart` has different theme/title/home wiring, keep that — only swap the StatelessWidget → ConsumerWidget and add the 4 lines that read settings + apply volumes.)

- [ ] **Step 5: Verify everything compiles**

Run: `cd c:/dev/void_td && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Run existing tests to ensure nothing broke**

Run: `cd c:/dev/void_td && flutter test`
Expected: All tests pass (existing 64 + new tests from Tasks 2-7 = 76).

- [ ] **Step 7: Commit**

```bash
cd c:/dev/void_td
git add lib/main.dart lib/app.dart
git commit -m "feat(audio): init AudioService/SettingsRepo on app boot, sync volumes via Riverpod"
```

---

## Task 10: Fire SFX from gameplay events in TdGame

**Files:**
- Modify: `c:/dev/void_td/lib/game/td_game.dart`

- [ ] **Step 1: Add AudioService field to TdGame**

Open `c:/dev/void_td/lib/game/td_game.dart`. Add import near the top with the other imports:

```dart
import '../audio/audio_service.dart';
import '../audio/sfx_ids.dart';
```

Add a field to TdGame (right after `final bool isConstructor;`):

```dart
  /// Injected so the Flame game can fire SFX without reaching into Riverpod.
  AudioService? audio;
```

Make it optional+nullable so existing tests that construct TdGame directly don't break.

- [ ] **Step 2: Add SFX calls at each gameplay event**

In the same file, find these methods and add SFX calls:

In `_placeAt` (right before `_emitState()` at the end):
```dart
    audio?.playSfx(SfxId.place);
```

In `_upgradeTower` (right before `return true;`):
```dart
    audio?.playSfx(SfxId.upgrade);
```

In `_upgradeFarm` (right before `return true;`):
```dart
    audio?.playSfx(SfxId.upgrade);
```

In `sellSelected` (right before `return true;`):
```dart
    audio?.playSfx(SfxId.sell);
```

In `_startNextWave` (right before `_emitState();` at the end):
```dart
    audio?.playSfx(SfxId.waveStart);
```

In `_onWaveCleared` (right before `_emitState();` at the end):
```dart
    audio?.playSfx(SfxId.waveClear);
```

In `_onEnemyReachedEnd` (right before `_emitState();`):
```dart
    audio?.playSfx(SfxId.leak);
```

- [ ] **Step 3: Wire AudioService into TdGame from GameScreen**

Open `c:/dev/void_td/lib/game/game_screen.dart`. Convert `_GameScreenState` to access Riverpod (it's already a `State<GameScreen>`; switch to `ConsumerState`).

At the top of game_screen.dart:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/audio_service.dart';
import '../audio/music_ids.dart';
import '../audio/sfx_ids.dart';
import '../haptics/haptic_service.dart';
import '../main.dart' show audioServiceProvider, hapticServiceProvider;
```

Change `class GameScreen extends StatefulWidget` to `class GameScreen extends ConsumerStatefulWidget` and `_GameScreenState extends State<GameScreen>` to `_GameScreenState extends ConsumerState<GameScreen>`. Also update `State<GameScreen> createState()` to `ConsumerState<GameScreen> createState()`.

In `initState()`, after `_game = TdGame(...)`, add:
```dart
    _game.audio = ref.read(audioServiceProvider);
```

- [ ] **Step 4: Verify analyze passes**

Run: `cd c:/dev/void_td && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Run tests**

Run: `cd c:/dev/void_td && flutter test`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
cd c:/dev/void_td
git add lib/game/td_game.dart lib/game/game_screen.dart
git commit -m "feat(audio): fire SFX from gameplay events (place/upgrade/sell/wave/leak)"
```

---

## Task 11: Fire `hit` SFX from Projectile + add music transitions

**Files:**
- Modify: `c:/dev/void_td/lib/game/components/projectile.dart`
- Modify: `c:/dev/void_td/lib/game/game_screen.dart`
- Modify: `c:/dev/void_td/lib/ui/main_menu/main_menu_screen.dart`

- [ ] **Step 1: Wire AudioService into Projectile via TdGame parent**

In `c:/dev/void_td/lib/game/components/projectile.dart`, locate `_onHit` method. Add at the top of `_onHit` (after the existing damage application):

```dart
    // Throttled inside AudioService — high-pierce/chain shots won't machine-gun.
    (findGame() as TdGame?)?.audio?.playSfx(SfxId.hit);
```

You'll need imports if not already present:
```dart
import '../../audio/sfx_ids.dart';
import '../td_game.dart';
```

- [ ] **Step 2: Add music transitions in GameScreen.initState**

In `c:/dev/void_td/lib/game/game_screen.dart`, inside `initState()`, after `_game.audio = ref.read(audioServiceProvider);`:

```dart
    // Switch music to the mode-appropriate track.
    final audio = ref.read(audioServiceProvider);
    if (widget.isConstructor) {
      audio.playMusic(MusicId.constructor);
    } else if (widget.isEndless) {
      audio.playMusic(MusicId.endless);
    } else {
      audio.playMusic(MusicId.campaign);
    }
```

- [ ] **Step 3: Add lifecycle music pause/resume**

In `didChangeAppLifecycleState`, modify to also pause/resume music:

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final audio = ref.read(audioServiceProvider);
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      _game.paused = true;
      _saveSnapshot();
      audio.pauseMusic();
    } else if (s == AppLifecycleState.resumed) {
      audio.resumeMusic();
    }
  }
```

- [ ] **Step 4: Fire victory/defeat SFX + switch music**

In `_showVictory`, right at the start (before the `final livesLost` line):
```dart
    final audio = ref.read(audioServiceProvider);
    audio.playSfx(SfxId.victory);
    audio.playMusic(MusicId.victoryLoop);
```

In `_showDefeat`, right at the start:
```dart
    final audio = ref.read(audioServiceProvider);
    audio.playSfx(SfxId.defeat);
    audio.playMusic(MusicId.defeatLoop);
```

- [ ] **Step 5: Switch main menu music in MainMenuScreen.initState**

Open `c:/dev/void_td/lib/ui/main_menu/main_menu_screen.dart`. Convert to `ConsumerStatefulWidget` if not already.

Add imports:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../audio/music_ids.dart';
import '../../main.dart' show audioServiceProvider;
```

Add `initState`:
```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(audioServiceProvider).playMusic(MusicId.menu);
    });
  }
```

(post-frame so we don't kick off audio during the first build pass.)

- [ ] **Step 6: Verify analyze + tests pass**

Run: `cd c:/dev/void_td && flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
cd c:/dev/void_td
git add lib/game/components/projectile.dart lib/game/game_screen.dart lib/ui/main_menu/main_menu_screen.dart
git commit -m "feat(audio): fire hit SFX, switch music per screen, pause music on lifecycle"
```

---

## Task 12: Wire haptic feedback into UI events

**Files:**
- Modify: `c:/dev/void_td/lib/ui/shared/neon_button.dart`
- Modify: `c:/dev/void_td/lib/game/td_game.dart`
- Modify: `c:/dev/void_td/lib/game/game_screen.dart`

- [ ] **Step 1: NeonButton fires uiClick SFX + light haptic on press**

Open `c:/dev/void_td/lib/ui/shared/neon_button.dart`. Convert to `ConsumerWidget`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../audio/sfx_ids.dart';
import '../../core/theme/colors.dart';
import '../../haptics/haptic_service.dart';
import '../../main.dart' show audioServiceProvider, hapticServiceProvider;

class NeonButton extends ConsumerWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double? width;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.cyan,
    this.width,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = onPressed != null;
    final fg = enabled ? color : AppColors.textMuted;
    return Material(
      color: AppColors.background,
      child: InkWell(
        onTap: enabled
            ? () {
                ref.read(audioServiceProvider).playSfx(SfxId.uiClick);
                ref.read(hapticServiceProvider).trigger(HapticKind.light);
                onPressed!();
              }
            : null,
        child: Container(
          width: width,
          alignment: width != null ? Alignment.center : null,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: fg, width: 1),
            borderRadius: BorderRadius.circular(6),
            boxShadow: enabled
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: 16,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
              shadows: enabled
                  ? [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 8)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Inject HapticService into TdGame for placement haptic**

Open `c:/dev/void_td/lib/game/td_game.dart`. Add the field next to the `audio` field:

```dart
  HapticService? haptics;
```

Add import:
```dart
import '../haptics/haptic_service.dart';
```

In `_placeAt` (right after `audio?.playSfx(SfxId.place);`):
```dart
    haptics?.trigger(HapticKind.light);
```

In `_onEnemyReachedEnd` (right after `audio?.playSfx(SfxId.leak);`):
```dart
    haptics?.trigger(HapticKind.heavy);
```

- [ ] **Step 3: Wire HapticService in GameScreen.initState**

In `c:/dev/void_td/lib/game/game_screen.dart` `initState`, after `_game.audio = ref.read(audioServiceProvider);`:

```dart
    _game.haptics = ref.read(hapticServiceProvider);
```

- [ ] **Step 4: Add heavy haptic on Victory/Defeat dialog show**

In `_showVictory` after the SFX play:
```dart
    ref.read(hapticServiceProvider).trigger(HapticKind.heavy);
```

In `_showDefeat` after the SFX play:
```dart
    ref.read(hapticServiceProvider).trigger(HapticKind.heavy);
```

- [ ] **Step 5: Verify analyze + tests pass**

Run: `cd c:/dev/void_td && flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
cd c:/dev/void_td
git add lib/ui/shared/neon_button.dart lib/game/td_game.dart lib/game/game_screen.dart
git commit -m "feat(haptics): wire haptic feedback into button press, placement, leak, victory, defeat"
```

---

## Task 13: Set up l10n infrastructure + extract EN strings

**Files:**
- Create: `c:/dev/void_td/l10n.yaml`
- Create: `c:/dev/void_td/lib/l10n/app_en.arb`
- Create: `c:/dev/void_td/lib/l10n/app_kk.arb`
- Create: `c:/dev/void_td/lib/l10n/app_ru.arb`
- Modify: `c:/dev/void_td/lib/app.dart`

- [ ] **Step 1: Create l10n.yaml in project root**

Create `c:/dev/void_td/l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

- [ ] **Step 2: Create lib/l10n/app_en.arb with all strings**

Create `c:/dev/void_td/lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",

  "titleVoid": "VOID",
  "titleTd": "TD",
  "btnContinue": "CONTINUE",
  "btnCampaign": "CAMPAIGN",
  "btnEndless": "ENDLESS",
  "btnConstructor": "CONSTRUCTOR",
  "btnSettings": "SETTINGS",
  "dialogExitTitle": "EXIT VOID TD?",
  "dialogExitBody": "Do you really want to close the app?",
  "btnCancel": "CANCEL",
  "btnExit": "EXIT",

  "labelWave": "WAVE",
  "labelLives": "LIVES",
  "labelGold": "GOLD",
  "labelFarms": "FARMS",

  "titleConstructor": "CONSTRUCTOR",
  "promptTapExit": "TAP EDGE CELL FOR EXIT",
  "promptTapEntry": "TAP EDGE CELL FOR ENTRY",
  "promptReady": "READY",
  "btnBack": "BACK",
  "btnBegin": "BEGIN",
  "btnStartWaves": "▶  START WAVES",

  "titlePaused": "PAUSED",
  "btnResume": "RESUME",
  "btnRestart": "RESTART",
  "btnQuit": "QUIT",

  "titleVictory": "VICTORY",
  "labelLivesLeft": "{lives} LIVES LEFT",
  "@labelLivesLeft": {
    "placeholders": { "lives": { "type": "int" } }
  },
  "btnRetry": "RETRY",
  "btnNext": "NEXT",

  "titleDefeat": "DEFEAT",
  "labelWavesReached": "WAVES REACHED",
  "labelHighScore": "HIGH SCORE",

  "towerBasic": "BASIC",
  "towerSplash": "SPLASH",
  "towerSniper": "SNIPER",
  "towerSlow": "SLOW",
  "towerFarm": "FARM",

  "branchBasicA": "RANGE+RATE",
  "branchBasicB": "CRIT",
  "branchSplashA": "RADIUS",
  "branchSplashB": "BURN",
  "branchSniperA": "PIERCE",
  "branchSniperB": "CHAIN",
  "branchSlowA": "STRONGER",
  "branchSlowB": "AURA",
  "branchFarmA": "INCOME",
  "branchFarmB": "CHEAPER",
  "labelBudget": "BUDGET",
  "btnSellWithRefund": "SELL  ${refund}",
  "@btnSellWithRefund": {
    "placeholders": { "refund": { "type": "int" } }
  },
  "labelMax": "MAX",
  "labelDmgAndRate": "DMG {dmg}  ·  {rate}/S",
  "@labelDmgAndRate": {
    "placeholders": {
      "dmg": { "type": "String" },
      "rate": { "type": "String" }
    }
  },
  "labelFarmIncomePerSec": "+{n} G/S",
  "@labelFarmIncomePerSec": {
    "placeholders": { "n": { "type": "int" } }
  },
  "labelFarmsRate": "+{n}/s",
  "@labelFarmsRate": {
    "placeholders": { "n": { "type": "int" } }
  },

  "titleSettings": "SETTINGS",
  "sectionAudio": "AUDIO",
  "labelSfxVolume": "SFX VOLUME",
  "labelMusicVolume": "MUSIC VOLUME",
  "sectionGameplay": "GAMEPLAY",
  "labelHaptic": "HAPTIC FEEDBACK",
  "labelReduceEffects": "REDUCE EFFECTS",
  "sectionLanguage": "LANGUAGE",
  "labelLangEn": "ENGLISH",
  "labelLangKk": "ҚАЗАҚША",
  "labelLangRu": "РУССКИЙ",
  "labelComingSoon": "(coming soon)",
  "sectionAbout": "ABOUT",
  "labelVersion": "VOID TD v{v}",
  "@labelVersion": {
    "placeholders": { "v": { "type": "String" } }
  },
  "btnCredits": "CREDITS"
}
```

- [ ] **Step 3: Create app_kk.arb and app_ru.arb as TODO stubs**

Create `c:/dev/void_td/lib/l10n/app_kk.arb`:

```json
{
  "@@locale": "kk",
  "@@x-translator-note": "TODO: translate to Kazakh in Stage 5. Missing keys fall back to EN."
}
```

Create `c:/dev/void_td/lib/l10n/app_ru.arb`:

```json
{
  "@@locale": "ru",
  "@@x-translator-note": "TODO: translate to Russian in Stage 5. Missing keys fall back to EN."
}
```

- [ ] **Step 4: Run gen-l10n to generate the delegate**

Run: `cd c:/dev/void_td && flutter gen-l10n`
Expected: creates `.dart_tool/flutter_gen/gen_l10n/app_localizations.dart` (auto-generated). No errors.

- [ ] **Step 5: Wire localizations in app.dart**

Modify `c:/dev/void_td/lib/app.dart` — add imports and update `MaterialApp`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/colors.dart';
import 'main.dart' show audioServiceProvider;
import 'settings/settings_controller.dart';
import 'ui/main_menu/main_menu_screen.dart';

class VoidApp extends ConsumerWidget {
  const VoidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final audio = ref.read(audioServiceProvider);
    audio.setSfxVolume(settings.sfxVolume);
    audio.setMusicVolume(settings.musicVolume);

    return MaterialApp(
      title: 'VOID TD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: settings.localeCode != null ? Locale(settings.localeCode!) : null,
      home: const MainMenuScreen(),
    );
  }
}
```

- [ ] **Step 6: Verify analyze + flutter test pass**

Run: `cd c:/dev/void_td && flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
cd c:/dev/void_td
git add l10n.yaml lib/l10n/ lib/app.dart
git commit -m "feat(l10n): set up flutter_localizations with EN source + KK/RU stubs"
```

---

## Task 14: Migrate all hardcoded UI strings to AppLocalizations

**Files:**
- Modify: every file in `lib/ui/` that has hardcoded strings
- Modify: `lib/game/match/hud.dart`
- Modify: `lib/ui/match/tower_palette.dart`
- Modify: `lib/ui/match/tower_upgrade_panel.dart`
- Modify: `lib/ui/match/speed_bar.dart`
- Modify: `lib/ui/match/victory_dialog.dart`
- Modify: `lib/ui/match/defeat_dialog.dart`
- Modify: `lib/ui/main_menu/main_menu_screen.dart`
- Modify: `lib/ui/constructor/constructor_setup_screen.dart`
- Modify: `lib/ui/constructor/start_waves_button.dart`
- Modify: `lib/game/game_screen.dart` (pause dialog strings)

- [ ] **Step 1: Add localization helper extension**

Create `c:/dev/void_td/lib/l10n/l10n.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Shorthand: `S(context).btnContinue` instead of `AppLocalizations.of(context)!.btnContinue`.
AppLocalizations S(BuildContext context) => AppLocalizations.of(context)!;
```

- [ ] **Step 2: Migrate main_menu_screen.dart**

In `lib/ui/main_menu/main_menu_screen.dart`, add import: `import '../../l10n/l10n.dart';`

Replace every hardcoded button label and dialog string. Examples:
- `'VOID'` → `S(context).titleVoid`
- `'TD'` → `S(context).titleTd`
- `'CONTINUE'` → `S(context).btnContinue`
- `'CAMPAIGN'` → `S(context).btnCampaign`
- `'ENDLESS'` → `S(context).btnEndless`
- `'CONSTRUCTOR'` → `S(context).btnConstructor`
- `'SETTINGS'` → `S(context).btnSettings`
- `'EXIT VOID TD?'` → `S(context).dialogExitTitle`
- `'Do you really want to close the app?'` → `S(context).dialogExitBody`
- `'CANCEL'` → `S(context).btnCancel`
- `'EXIT'` → `S(context).btnExit`

- [ ] **Step 3: Migrate hud.dart**

Add import: `import '../../l10n/l10n.dart';`

Find usages of `'WAVE'`, `'LIVES'`, `'GOLD'`. In the `_stat` calls inside `build`:
- `'WAVE'` → `S(context).labelWave`
- `'LIVES'` → `S(context).labelLives`
- `'GOLD'` → `S(context).labelGold`

(Pass `context` into `_stat` helper — modify signature: `Widget _stat(BuildContext context, String label, ...)`.)

- [ ] **Step 4: Migrate constructor_setup_screen.dart**

Add import: `import '../../l10n/l10n.dart';`

- `'CONSTRUCTOR'` → `S(context).titleConstructor`
- `'TAP EDGE CELL FOR EXIT'` → `S(context).promptTapExit`
- `'TAP EDGE CELL FOR ENTRY'` → `S(context).promptTapEntry`
- `'READY'` → `S(context).promptReady`
- `'BACK'` → `S(context).btnBack`
- `'BEGIN'` → `S(context).btnBegin`

- [ ] **Step 5: Migrate start_waves_button.dart**

Convert to `StatelessWidget` that takes `BuildContext` for localization (it already does — just add the import and replace the literal):

- `'▶  START WAVES'` → `S(context).btnStartWaves`

- [ ] **Step 6: Migrate pause dialog in game_screen.dart**

In `_handleBack`, change literals inside the showDialog builder:
- `'PAUSED'` → `S(context).titlePaused`
- `'RESUME'` → `S(context).btnResume`
- `'RESTART'` → `S(context).btnRestart`
- `'QUIT'` → `S(context).btnQuit`

- [ ] **Step 7: Migrate victory_dialog.dart and defeat_dialog.dart**

In victory_dialog.dart:
- `'VICTORY'` → `S(context).titleVictory`
- `'RETRY'` → `S(context).btnRetry`
- `'NEXT'` → `S(context).btnNext`
- `'QUIT'` → `S(context).btnQuit`
- `'$lives LIVES LEFT'` style → `S(context).labelLivesLeft(lives)`

In defeat_dialog.dart:
- `'DEFEAT'` → `S(context).titleDefeat`
- `'WAVES REACHED'` → `S(context).labelWavesReached`
- `'HIGH SCORE'` → `S(context).labelHighScore`
- `'RETRY'` → `S(context).btnRetry`
- `'QUIT'` → `S(context).btnQuit`

- [ ] **Step 8: Migrate tower_palette.dart**

The `_nameFor` helper currently returns hardcoded strings. Replace its call sites:

Change `_nameFor(widget.type)` in the Text widget to a context-aware lookup. Add an instance method:

```dart
String _nameFor(BuildContext context, TowerType t) {
  switch (t) {
    case TowerType.basic: return S(context).towerBasic;
    case TowerType.splash: return S(context).towerSplash;
    case TowerType.sniper: return S(context).towerSniper;
    case TowerType.slow: return S(context).towerSlow;
    case TowerType.farm: return S(context).towerFarm;
  }
}
```

And call it as `_nameFor(context, widget.type)`.

Add import: `import '../../l10n/l10n.dart';`

- [ ] **Step 9: Migrate tower_upgrade_panel.dart**

Add import: `import '../../l10n/l10n.dart';`

Replace tower-name and branch-name getters with context-aware versions:

The existing `_typeName`, `_branchAName`, `_branchBName` getters reference `type` only. Convert each into a method taking `context`:

```dart
String _typeName(BuildContext context) {
  switch (type) {
    case TowerType.basic: return S(context).towerBasic;
    case TowerType.splash: return S(context).towerSplash;
    case TowerType.sniper: return S(context).towerSniper;
    case TowerType.slow: return S(context).towerSlow;
    case TowerType.farm: return S(context).towerFarm;
  }
}

String _branchAName(BuildContext context) {
  switch (type) {
    case TowerType.basic: return S(context).branchBasicA;
    case TowerType.splash: return S(context).branchSplashA;
    case TowerType.sniper: return S(context).branchSniperA;
    case TowerType.slow: return S(context).branchSlowA;
    case TowerType.farm: return S(context).branchFarmA;
  }
}

String _branchBName(BuildContext context) {
  switch (type) {
    case TowerType.basic: return S(context).branchBasicB;
    case TowerType.splash: return S(context).branchSplashB;
    case TowerType.sniper: return S(context).branchSniperB;
    case TowerType.slow: return S(context).branchSlowB;
    case TowerType.farm: return S(context).branchFarmB;
  }
}

String _statsLineFor(BuildContext context) {
  final stats = TowersConfig.statsFor(type, branchA: branchA, branchB: branchB);
  if (type == TowerType.farm) {
    return S(context).labelFarmIncomePerSec(stats.farmGoldPerSec);
  }
  final dmg = stats.damage.toStringAsFixed(stats.damage >= 10 ? 0 : 1);
  final rate = stats.fireRatePerSec.toStringAsFixed(1);
  return S(context).labelDmgAndRate(dmg, rate);
}
```

Update build() call sites to pass `context` (e.g. `_typeName(context)` instead of `_typeName`).

Also replace:
- `'BUDGET'` → `S(context).labelBudget`
- `'MAX'` → `S(context).labelMax`
- `'SELL  \$$sellRefund'` → `S(context).btnSellWithRefund(sellRefund)`

- [ ] **Step 10: Migrate speed_bar.dart**

Add import: `import '../../l10n/l10n.dart';`

- `'FARMS'` → `S(context).labelFarms`
- `'+$farmIncomePerSec/s'` → `S(context).labelFarmsRate(farmIncomePerSec)`

- [ ] **Step 11: Update existing widget tests for new string lookup**

Run: `cd c:/dev/void_td && flutter test test/widget_test.dart`
Expected: probably fails because the test looks for raw text. Open `test/widget_test.dart` and check assertions — the existing test for main menu finds `'VOID'`, `'CAMPAIGN'`, etc. literally. These literals are still present (in `app_en.arb`), so as long as the test wraps the app in `MaterialApp` with English locale (which it does via the existing `VoidApp` wrapper), the test should still pass.

If a test fails with "Could not find AppLocalizations.of(context)", wrap test widgets in:

```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: <widget under test>,
)
```

- [ ] **Step 12: Verify analyze + tests pass**

Run: `cd c:/dev/void_td && flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 13: Commit**

```bash
cd c:/dev/void_td
git add lib/
git commit -m "feat(l10n): migrate all UI strings to AppLocalizations (EN source)"
```

---

## Task 15: Build Settings UI components (NeonSlider, NeonToggle)

**Files:**
- Create: `c:/dev/void_td/lib/ui/settings/neon_slider.dart`
- Create: `c:/dev/void_td/lib/ui/settings/neon_toggle.dart`

- [ ] **Step 1: Create NeonSlider**

Create `c:/dev/void_td/lib/ui/settings/neon_slider.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Styled slider with cyan track + glow. Value range 0..1.
/// Calls onChangeEnd at release (use this for SFX preview).
class NeonSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color color;

  const NeonSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.color = AppColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: AppColors.border,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.3),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: color,
              fontFamily: 'monospace',
              fontSize: 11,
              shadows: [Shadow(color: color.withValues(alpha: 0.85), blurRadius: 6)],
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Create NeonToggle**

Create `c:/dev/void_td/lib/ui/settings/neon_toggle.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Styled switch: cyan glow when ON, dim border when OFF.
class NeonToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;

  const NeonToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.color = AppColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: color,
      activeTrackColor: color.withValues(alpha: 0.4),
      inactiveThumbColor: AppColors.textMuted,
      inactiveTrackColor: AppColors.border,
    );
  }
}
```

- [ ] **Step 3: Verify analyze passes**

Run: `cd c:/dev/void_td && flutter analyze lib/ui/settings/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
cd c:/dev/void_td
git add lib/ui/settings/neon_slider.dart lib/ui/settings/neon_toggle.dart
git commit -m "feat(settings): add NeonSlider and NeonToggle widgets"
```

---

## Task 16: Build SettingsScreen and CreditsScreen

**Files:**
- Create: `c:/dev/void_td/lib/ui/settings/settings_screen.dart`
- Create: `c:/dev/void_td/lib/ui/settings/credits_screen.dart`
- Create: `c:/dev/void_td/test/settings_screen_test.dart`
- Modify: `c:/dev/void_td/lib/ui/main_menu/main_menu_screen.dart` (enable SETTINGS button)

- [ ] **Step 1: Create CreditsScreen**

Create `c:/dev/void_td/lib/ui/settings/credits_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/theme/colors.dart';
import '../../l10n/l10n.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.cyan,
        title: Text(S(context).btnCredits,
            style: const TextStyle(
              color: AppColors.cyan,
              fontFamily: 'monospace',
              letterSpacing: 3,
            )),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString('assets/audio/CREDITS.md'),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.cyan),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                snap.data!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create SettingsScreen**

Create `c:/dev/void_td/lib/ui/settings/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../audio/sfx_ids.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n.dart';
import '../../main.dart' show audioServiceProvider;
import '../../settings/settings_controller.dart';
import 'credits_screen.dart';
import 'neon_slider.dart';
import 'neon_toggle.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final audio = ref.read(audioServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.cyan,
        title: Text(S(context).titleSettings,
            style: const TextStyle(
              color: AppColors.cyan,
              fontFamily: 'monospace',
              letterSpacing: 4,
            )),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(S(context).sectionAudio),
            _label(S(context).labelSfxVolume),
            NeonSlider(
              value: settings.sfxVolume,
              onChanged: (v) {
                ctrl.setSfxVolume(v);
                audio.setSfxVolume(v);
              },
              onChangeEnd: (_) => audio.playSfx(SfxId.uiClick),
            ),
            const SizedBox(height: 12),
            _label(S(context).labelMusicVolume),
            NeonSlider(
              value: settings.musicVolume,
              onChanged: (v) {
                ctrl.setMusicVolume(v);
                audio.setMusicVolume(v);
              },
            ),
            const SizedBox(height: 24),
            _section(S(context).sectionGameplay),
            _toggleRow(
              context,
              S(context).labelHaptic,
              settings.hapticOn,
              ctrl.setHapticOn,
            ),
            const SizedBox(height: 8),
            _toggleRow(
              context,
              S(context).labelReduceEffects,
              settings.reduceEffects,
              ctrl.setReduceEffects,
            ),
            const SizedBox(height: 24),
            _section(S(context).sectionLanguage),
            _langRow(context, ctrl, S(context).labelLangEn, 'en',
                enabled: true, current: settings.localeCode ?? 'en'),
            _langRow(context, ctrl, S(context).labelLangKk, 'kk',
                enabled: false, current: settings.localeCode ?? 'en'),
            _langRow(context, ctrl, S(context).labelLangRu, 'ru',
                enabled: false, current: settings.localeCode ?? 'en'),
            const SizedBox(height: 24),
            _section(S(context).sectionAbout),
            const SizedBox(height: 8),
            Text(S(context).labelVersion('1.0.0'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                )),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreditsScreen()),
              ),
              child: Text(
                '> ${S(context).btnCredits}',
                style: TextStyle(
                  color: AppColors.cyan,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  shadows: [Shadow(color: AppColors.cyan.withValues(alpha: 0.85), blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.cyan,
            fontFamily: 'monospace',
            fontSize: 12,
            letterSpacing: 3,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: AppColors.cyan.withValues(alpha: 0.85), blurRadius: 6)],
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'monospace',
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _toggleRow(
      BuildContext context, String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 1.5,
            )),
        NeonToggle(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _langRow(BuildContext context, SettingsController ctrl, String label, String code,
      {required bool enabled, required String current}) {
    final selected = current == code;
    return InkWell(
      onTap: enabled ? () => ctrl.setLocale(code) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: enabled ? AppColors.cyan : AppColors.textMuted,
              size: 16,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.textSecondary : AppColors.textMuted,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            if (!enabled) ...[
              const SizedBox(width: 8),
              Text(
                S(context).labelComingSoon,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Enable SETTINGS button in main menu**

Open `c:/dev/void_td/lib/ui/main_menu/main_menu_screen.dart`. Find the `SETTINGS` NeonButton (currently `onPressed: null`). Replace:

```dart
                const NeonButton(
                  label: 'SETTINGS',
                  color: AppColors.purple,
                  width: _menuButtonWidth,
                  onPressed: null,
                ),
```

With (note: also localize the label here per Task 14):

```dart
                NeonButton(
                  label: S(context).btnSettings,
                  color: AppColors.purple,
                  width: _menuButtonWidth,
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ));
                  },
                ),
```

Add import: `import '../settings/settings_screen.dart';`

- [ ] **Step 4: Write widget test for SettingsScreen**

Create `c:/dev/void_td/test/settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:void_td/audio/audio_service.dart';
import 'package:void_td/main.dart' show audioServiceProvider;
import 'package:void_td/settings/settings_controller.dart';
import 'package:void_td/settings/settings_repo.dart';
import 'package:void_td/ui/settings/settings_screen.dart';
import 'dart:io';

class _FakePathProvider extends PathProviderPlatform {
  final String tmp;
  _FakePathProvider(this.tmp);
  @override Future<String?> getApplicationDocumentsPath() async => tmp;
  @override Future<String?> getTemporaryPath() async => tmp;
  @override Future<String?> getApplicationSupportPath() async => tmp;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('void_td_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    Hive.init(tmp.path);
    await SettingsRepo.init();
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(SettingsRepo.boxName);
    await tmp.delete(recursive: true);
  });

  Widget _harness({required Widget child}) => ProviderScope(
        overrides: [
          audioServiceProvider.overrideWithValue(AudioService.forTesting()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  testWidgets('renders all sections', (tester) async {
    await tester.pumpWidget(_harness(child: const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('AUDIO'), findsOneWidget);
    expect(find.text('GAMEPLAY'), findsOneWidget);
    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
  });

  testWidgets('toggling haptic updates SettingsController', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(_harness(
      child: Consumer(builder: (ctx, ref, _) {
        container = ProviderScope.containerOf(ctx);
        return const SettingsScreen();
      }),
    ));
    await tester.pumpAndSettle();
    expect(container.read(settingsControllerProvider).hapticOn, true);
    final switchWidget = find.byType(Switch).first;
    await tester.tap(switchWidget);
    await tester.pumpAndSettle();
    expect(container.read(settingsControllerProvider).hapticOn, false);
  });
}
```

- [ ] **Step 5: Run test**

Run: `cd c:/dev/void_td && flutter test test/settings_screen_test.dart`
Expected: PASS, both tests.

- [ ] **Step 6: Verify full analyze + test suite**

Run: `cd c:/dev/void_td && flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
cd c:/dev/void_td
git add lib/ui/settings/ lib/ui/main_menu/main_menu_screen.dart test/settings_screen_test.dart
git commit -m "feat(settings): SettingsScreen with sliders/toggles/lang/credits; wire SETTINGS button"
```

---

## Task 17: Acquire real audio assets

This task does NOT involve coding. The implementer (or user) downloads files and places them in `assets/audio/{sfx,music}/`. The SFX-throttling, SettingsController, and SettingsScreen are already exercised by automated tests, so this task is just about file replacement.

**Sources to use (preferring CC0 → CC-BY 4.0):**
- https://opengameart.org/ (search "ambient" / "chillout" / "sci-fi UI")
- https://freesound.org/ (filter by CC0)

**SFX shopping list (with character notes):**

| File              | Character | Suggested search |
| ---               | ---       | --- |
| `hit.wav`         | short tick/impact ~80ms, neutral tone, no reverb | "laser hit" / "blip impact" |
| `place.wav`       | confident click ~100ms, slight bass | "ui place" / "build click" |
| `upgrade.wav`     | rising glissando ~250ms | "ui upgrade" / "level up" |
| `sell.wav`        | coin/chime ~200ms | "coin sell" / "cash register" |
| `leak.wav`        | low descending tone ~400ms (loss feel) | "ui error" / "fail short" |
| `wave_start.wav`  | low drone swell ~700ms | "wave start" / "sci-fi drone" |
| `wave_clear.wav`  | bright ping ~300ms (success) | "ui success" / "achievement short" |
| `ui_click.wav`    | crisp click ~50ms | "ui click" / "menu select" |
| `victory.wav`     | uplifting sting ~1.5s | "victory sting" / "win short" |
| `defeat.wav`      | descending fail ~1.5s | "defeat sting" / "game over short" |

**Music shopping list:**

| File              | Character | Suggested search |
| ---               | ---       | --- |
| `menu.ogg`        | calm chillout/ambient loop, 60-90 BPM, ~2 min | "ambient loop" / "chillout loop" |
| `campaign.ogg`    | slightly more energetic, still chill | "synthwave chill" / "future ambient" |
| `endless.ogg`     | drone/atmospheric, looping | "dark ambient loop" |
| `constructor.ogg` | minimal, contemplative | "minimal techno" / "ambient piano" |
| `victory_loop.ogg`| bright uplifting loop ~30s | "uplifting ambient" |
| `defeat_loop.ogg` | melancholic loop ~30s | "sad piano loop" |

- [ ] **Step 1: Download each SFX**

For each row in the SFX table:
1. Search source sites with suggested terms
2. Pick a CC0 (preferred) or CC-BY 4.0 file matching the character notes
3. Convert to 44.1 kHz mono 16-bit WAV (use Audacity: File → Export → WAV)
4. Save as `c:/dev/void_td/assets/audio/sfx/<filename>.wav`, replacing the stub
5. Record the source URL, author, and license

If no good match found within 5 minutes for a specific SFX: keep the silent stub, mark `MISSING` in CREDITS.md, move on.

- [ ] **Step 2: Download each music track**

Same process for music — but save as OGG Vorbis (`.ogg`). Loop-friendly tracks preferred.

- [ ] **Step 3: Fill in CREDITS.md**

Replace TBD entries with real `Author`, `License`, `Source` columns. Example:
```markdown
| place.wav | NenadSimic | CC0 | https://opengameart.org/content/click-sounds |
```

- [ ] **Step 4: Verify assets load on device**

Run: `cd c:/dev/void_td && flutter run`
- Tap CAMPAIGN → menu music should fade out, campaign music plays
- Tap a tower in palette → place SFX plays when you drop on the grid
- Wait for a wave to start → wave_start SFX
- Win/lose the level → victory/defeat SFX + music swap

- [ ] **Step 5: Commit audio assets**

```bash
cd c:/dev/void_td
git add assets/audio/
git commit -m "feat(audio): add real SFX + music assets with CREDITS attribution"
```

---

## Task 18: Hook `EffectsConfig.reduced` into existing visuals

**Files:**
- Create: `c:/dev/void_td/lib/settings/effects_config.dart`
- Modify: `c:/dev/void_td/lib/settings/settings_controller.dart`
- Modify: `c:/dev/void_td/lib/game/components/enemy.dart`

- [ ] **Step 1: Create EffectsConfig**

Create `c:/dev/void_td/lib/settings/effects_config.dart`:

```dart
/// Global, read-only flag updated by SettingsController whenever the user
/// flips the "Reduce Effects" toggle. Components read it synchronously
/// during render — no listener needed.
class EffectsConfig {
  static bool reduced = false;
}
```

- [ ] **Step 2: Update SettingsController to set the flag**

In `c:/dev/void_td/lib/settings/settings_controller.dart`, modify `setReduceEffects`:

```dart
  void setReduceEffects(bool on) {
    state = state.copyWith(reduceEffects: on);
    EffectsConfig.reduced = on;
    SettingsRepo.save(state);
  }
```

Also set in constructor (so initial value propagates):
```dart
  SettingsController() : super(SettingsRepo.load()) {
    EffectsConfig.reduced = state.reduceEffects;
  }
```

Add import: `import 'effects_config.dart';`

- [ ] **Step 3: Hook into Enemy render**

Open `c:/dev/void_td/lib/game/components/enemy.dart`. Find the burn-flicker animation (likely uses `math.sin(_renderTimeAcc * 12)` or similar) and the slow pulse-ring. Wrap each in a conditional:

Add import: `import '../../settings/effects_config.dart';`

For burn flicker — replace something like:
```dart
final flicker = math.sin(_renderTimeAcc * 12) * 0.5 + 0.5;
final burnColor = AppColors.orange.withValues(alpha: 0.4 + flicker * 0.4);
```

With:
```dart
final double flicker;
if (EffectsConfig.reduced) {
  flicker = 0.5;  // static mid-value, no animation
} else {
  flicker = math.sin(_renderTimeAcc * 12) * 0.5 + 0.5;
}
final burnColor = AppColors.orange.withValues(alpha: 0.4 + flicker * 0.4);
```

For slow pulse — same pattern: if `EffectsConfig.reduced`, use a fixed alpha; otherwise the animated one.

(Adapt to whatever your existing code actually looks like — the principle is one branch with static value vs animated.)

- [ ] **Step 4: Verify analyze + tests pass**

Run: `cd c:/dev/void_td && flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
cd c:/dev/void_td
git add lib/settings/effects_config.dart lib/settings/settings_controller.dart lib/game/components/enemy.dart
git commit -m "feat(settings): wire ReduceEffects toggle to enemy burn/slow visuals"
```

---

## Task 19: Add Settings access from pause dialog

**Files:**
- Modify: `c:/dev/void_td/lib/game/game_screen.dart`

- [ ] **Step 1: Add SETTINGS option to pause dialog**

Open `c:/dev/void_td/lib/game/game_screen.dart`. Locate `_handleBack` and the existing pause `showDialog` with RESUME/RESTART/QUIT. Add a SETTINGS button between RESUME and RESTART.

Modify the enum `_PauseChoice`:

```dart
enum _PauseChoice { resume, settings, restart, quit }
```

Add a TextButton inside the actions list (after the RESUME button, before RESTART):

```dart
          TextButton(
            onPressed: () => Navigator.pop(ctx, _PauseChoice.settings),
            child: Text(S(context).btnSettings,
                style: TextStyle(
                  color: AppColors.purple,
                  letterSpacing: 2,
                  shadows: [Shadow(color: AppColors.purple.withValues(alpha: 0.85), blurRadius: 6)],
                )),
          ),
```

In the switch statement, add a `settings` case:

```dart
      case _PauseChoice.settings:
        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const SettingsScreen(),
          ));
          // Re-show the pause dialog after returning from settings.
          if (mounted) _handleBack();
        }
        break;
```

Add import: `import '../ui/settings/settings_screen.dart';`

- [ ] **Step 2: Verify analyze + tests pass**

Run: `cd c:/dev/void_td && flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
cd c:/dev/void_td
git add lib/game/game_screen.dart
git commit -m "feat(settings): add SETTINGS option to in-game pause dialog"
```

---

## Task 20: Manual playtest pass + tag

**Files:** none (verification only)

- [ ] **Step 1: Build a debug APK and run on device**

Run: `cd c:/dev/void_td && flutter run`

- [ ] **Step 2: Run through the manual playtest checklist**

For each item below, verify it works:

- [ ] Cold start → menu music plays at ~60% volume
- [ ] Tap CAMPAIGN → music swaps to campaign track
- [ ] Place a tower → place SFX + light haptic
- [ ] Wave starts → wave_start SFX
- [ ] Tower fires (basic) → hit SFX on impact, doesn't machine-gun
- [ ] Crep reaches end → leak SFX + heavy haptic
- [ ] Win level → victory SFX + heavy haptic, music swaps to victory_loop
- [ ] Tap RETRY → game restarts, music back to campaign track
- [ ] Lose level → defeat SFX + heavy haptic, music swaps to defeat_loop
- [ ] Background app (home button) → music pauses
- [ ] Return to app → music resumes
- [ ] Open Settings from main menu → all sections render
- [ ] Drag SFX volume slider → release → hear test click at new volume
- [ ] Drag music volume slider → music playing in background changes immediately
- [ ] Toggle haptic OFF → place a tower → no vibration
- [ ] Toggle Reduce Effects ON → enemy burn/slow visuals become static (no flicker/pulse)
- [ ] Pick RUSSIAN language → tap → no-op (disabled)
- [ ] Open CREDITS → file content renders
- [ ] Back out of Settings → return to main menu, music keeps playing
- [ ] In-game pause → tap SETTINGS → opens settings → back → pause dialog reappears
- [ ] Force-quit app → reopen → SFX/music volumes preserved, haptic state preserved
- [ ] Phone volume keys adjust media stream during gameplay

- [ ] **Step 3: If any item fails, debug and fix before tagging**

Make one extra commit per fix.

- [ ] **Step 4: Tag the Stage 4 release**

```bash
cd c:/dev/void_td
git tag -a stage-4-polish -m "Stage 4: Polish (audio + locale + haptic + settings)"
git push origin main --tags
```

---

## Coverage check

This plan covers every section of the spec:

- ✅ Architecture (Task 1, 2, 3, 4, 5, 6, 7)
- ✅ AudioService API + throttling + lifecycle + music transitions (Task 7, 9, 10, 11)
- ✅ SFX trigger table — 10 SFX wired at exact call sites (Task 10, 11, 12)
- ✅ HapticService + trigger table (Task 5, 12)
- ✅ Localization (l10n.yaml, .arb files, codegen, MaterialApp) (Task 13)
- ✅ String migration ~50 keys (Task 14)
- ✅ Settings screen with NeonSlider/NeonToggle (Task 15, 16)
- ✅ Reduce Effects → enemy visuals (Task 18)
- ✅ Settings reachable from pause dialog (Task 19)
- ✅ Asset acquisition (Task 17) with fallback strategy
- ✅ Testing — unit + widget + manual checklist (Task 2/3/4/5/7/16/20)
- ✅ Hardware volume keys wired (audioplayers default — verified in Task 20)
- ✅ EXIT VOID TD dialog stays unchanged (no task touches it)
