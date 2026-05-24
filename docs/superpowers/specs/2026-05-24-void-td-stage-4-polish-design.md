# VOID TD — Stage 4 Polish (Audio + Locale + Haptic + Settings)

**Date:** 2026-05-24
**Status:** Design approved
**Repo:** `c:\dev\void_td` (separate from `flutter_application_1`)
**Predecessors:** Stage 0/1/1.5/2a/2b/3 — all merged to `main`
**Successors:** Stage 5 (balance pass, KK/RU translations, Hardcore Endless, cleared-campaign-as-endless-map)

---

## Goal

Bring VOID TD from "playable prototype" to "polished pre-release": sound, music, language
infrastructure, haptics, and a Settings screen that controls all of the above.

This stage explicitly does NOT include final translations (KK/RU) or balance tuning — those
are queued for Stage 5.

---

## In scope

- Audio playback infrastructure (SFX + music) via `flame_audio`
- 10 SFX (hit, place, upgrade, sell, leak, waveStart, waveClear, uiClick, victory, defeat)
- 6 music tracks (menu, campaign, endless, constructor, victory_loop, defeat_loop)
- Localization infrastructure: `flutter_localizations` + `intl` + generated delegate
- All hardcoded UI strings extracted into `app_en.arb`
- `app_kk.arb` + `app_ru.arb` created as TODO stubs (auto-fallback to EN)
- Haptic feedback service with on/off toggle
- Settings screen (Audio sliders + Haptic toggle + Reduce Effects toggle + Language radios + Credits)
- Settings persistence via Hive
- Wire system media-stream volume to AudioPlayer (so hardware buttons work)

## Out of scope

- KK and RU translations (only stubs; real translations Stage 5)
- Tower shot SFX ("A" option excluded by user — may add post-playtest)
- Crep death SFX (explicitly excluded by user)
- Balance changes
- Stage 5 deferrals (Hardcore Endless, cleared-Campaign-maps as Endless choices)
- Existing PopScope/EXIT-dialog behavior — unchanged

---

## Architecture

### New folders

```
assets/
  audio/
    sfx/        hit.wav, place.wav, upgrade.wav, sell.wav, leak.wav,
                wave_start.wav, wave_clear.wav, ui_click.wav,
                victory.wav, defeat.wav
    music/      menu.ogg, campaign.ogg, endless.ogg, constructor.ogg,
                victory_loop.ogg, defeat_loop.ogg
    CREDITS.md  attribution for CC-BY assets
lib/
  audio/
    sfx_ids.dart                 // enum SfxId
    music_ids.dart               // enum MusicId
    audio_service.dart           // single facade
  haptics/
    haptic_service.dart          // wraps HapticFeedback, gated by settings
  settings/
    settings.dart                // immutable Settings model
    settings_repo.dart           // Hive persistence
    settings_controller.dart     // Riverpod StateNotifier
  l10n/
    app_en.arb                   // ~50 keys, source of truth
    app_kk.arb                   // TODO stubs
    app_ru.arb                   // TODO stubs
  ui/
    settings/
      settings_screen.dart
      neon_slider.dart           // styled OLED slider
      neon_toggle.dart           // styled OLED switch
      credits_screen.dart        // scrollable list from CREDITS.md
```

### Dependencies added

```yaml
dependencies:
  flame_audio: ^X.Y.Z     # SFX + music, sits on top of audioplayers — pin to latest compatible with Flame 1.37
  intl: ^X.Y.Z            # pin to latest compatible with flutter SDK
  flutter_localizations:
    sdk: flutter
flutter:
  generate: true          # enables flutter_gen for l10n codegen
```

Exact versions resolved via `flutter pub add flame_audio intl` at plan-execution time.

### l10n.yaml (project root)

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

### Settings model

```dart
class Settings {
  final double sfxVolume;       // 0..1, default 0.45
  final double musicVolume;     // 0..1, default 0.60
  final bool hapticOn;          // default true
  final bool reduceEffects;     // default false
  final String? localeCode;     // null = system; 'en' | 'kk' | 'ru'
}
```

Hive box `settings`, key `current`, stored as `Map<String, dynamic>` (consistent with how
MatchSnapshot is stored — no typed adapter required).

### SettingsController (Riverpod)

Single source of truth. Loads from Hive on app init. Listeners:
- `AudioService` subscribes to volume changes, applies live
- `MaterialApp` rebuilds with new `locale` when `localeCode` changes
- `HapticService` reads `hapticOn` synchronously on each `trigger()`

---

## AudioService

```dart
class AudioService {
  Future<void> init();
  Future<void> playSfx(SfxId id);
  Future<void> playMusic(MusicId id, {bool loop = true});
  Future<void> stopMusic();
  Future<void> pauseMusic();
  Future<void> resumeMusic();
  void setSfxVolume(double v);
  void setMusicVolume(double v);
}
```

Implementation notes:
- `init()` calls `FlameAudio.audioCache.loadAll([...sfxFiles])` once at app start so first play has no disk-read jank
- `playSfx` uses `FlameAudio.play(file, volume: _sfxVolume)` — fire-and-forget
- Music uses a single long-lived `AudioPlayer` (held in a field): `setReleaseMode(loop)`, `play()`, `setVolume()`
- **Throttling:** each `SfxId` has a per-id minimum interval. Default 50ms. Prevents the `hit` sfx from machine-gunning during multi-pierce/chain shots
- Audio uses Android `STREAM_MUSIC` (the media stream) — hardware volume keys naturally adjust system music volume which gets multiplied by our in-app volume. This is the audioplayers default — verified, no extra config needed

### Music transition table

| Screen / state          | Track             | Notes |
| ---                     | ---               | --- |
| MainMenuScreen          | `menu`            | start in initState |
| LevelSelectScreen       | `menu`            | no change — keeps playing |
| GameScreen (Campaign)   | `campaign`        | swap in initState |
| GameScreen (Endless)    | `endless`         | swap in initState |
| GameScreen (Constructor)| `constructor`     | swap in initState |
| Victory dialog open     | `victory_loop`    | restored to game-music on dialog dismiss (or to `menu` if user quits) |
| Defeat dialog open      | `defeat_loop`     | same restore logic |
| SettingsScreen open     | (no change)       | settings can be opened from menu OR pause dialog — let whatever's playing keep playing |

### SFX trigger table (where each is fired in code)

| SfxId       | Call site |
| ---         | --- |
| `hit`       | `Projectile._onHit` (every pierce/chain hit, gated by 50ms throttle) |
| `place`     | `TdGame._placeAt` |
| `upgrade`   | `TdGame._upgradeTower` / `_upgradeFarm` (success only) |
| `sell`      | `TdGame.sellSelected` |
| `leak`      | `TdGame._onEnemyReachedEnd` |
| `waveStart` | `TdGame._startNextWave` |
| `waveClear` | `TdGame._onWaveCleared` (when bonus > 0) |
| `uiClick`   | `NeonButton.onPressed` wrapper + dialog buttons |
| `victory`   | `GameScreen._showVictory` immediately on show |
| `defeat`    | `GameScreen._showDefeat` immediately on show |

### App-lifecycle handling

`GameScreen.didChangeAppLifecycleState`:
- `paused | inactive` → `audio.pauseMusic()` (already pauses game; add audio)
- `resumed` → `audio.resumeMusic()`

In-game pause dialog: music keeps playing (background atmosphere) — only SFX silenced naturally because game is paused and nothing's triggering them.

---

## HapticService

```dart
class HapticService {
  HapticService(this._settings);
  void trigger(HapticKind kind);
}

enum HapticKind { light, medium, heavy }
```

Each call reads `_settings.read().hapticOn`; returns early if `false`.

### Haptic trigger table

| Event                        | Kind |
| ---                          | --- |
| NeonButton onPressed         | `light` |
| `TdGame._placeAt`            | `light` |
| `TdGame._onEnemyReachedEnd`  | `heavy` (sharp — "you lost a life") |
| Victory dialog show          | `heavy` |
| Defeat dialog show           | `heavy` |

---

## Localization

### Key inventory (~50 strings)

Extracted from existing UI files. Grouped by feature:

- **Main menu:** title.void, title.td, btn.continue, btn.campaign, btn.endless, btn.constructor, btn.settings, dialog.exit.title, dialog.exit.body, btn.cancel, btn.exit
- **HUD:** label.wave, label.lives, label.gold, label.farms
- **Constructor setup:** title.constructor, prompt.tapExit, prompt.tapEntry, prompt.ready, btn.back, btn.begin
- **Pause dialog:** title.paused, btn.resume, btn.restart, btn.quit
- **Victory:** title.victory, label.livesLeft (with `{lives}` placeholder), btn.retry, btn.next, btn.quit
- **Defeat:** title.defeat, label.wavesReached, label.highScore, btn.retry, btn.quit
- **Tower palette:** tower.basic, tower.splash, tower.sniper, tower.slow, tower.farm
- **Upgrade panel:** branch.basicA (RANGE+RATE), branch.basicB (CRIT), branch.splashA (RADIUS), branch.splashB (BURN), branch.sniperA (PIERCE), branch.sniperB (CHAIN), branch.slowA (STRONGER), branch.slowB (AURA), branch.farmA (INCOME), branch.farmB (CHEAPER), label.budget, btn.sell (with `{refund}`), label.max, stat.damage (with `{n}`), stat.fireRate (with `{n}`), stat.farmIncome (with `{n}`)
- **Settings:** title.settings, section.audio, label.sfxVolume, label.musicVolume, section.gameplay, label.haptic, label.reduceEffects, section.language, label.langEn, label.langKk, label.langRu, label.comingSoon, section.about, label.version (with `{v}`), btn.credits

### Pipeline

1. `app_en.arb` is hand-written, source of truth.
2. `app_kk.arb` and `app_ru.arb` are created as copies of `app_en.arb` with every value prefixed with `TODO: ` (or left as `"@@x-translator-note": "TODO"`). Flutter's locale resolution will fall back to EN automatically when a key is missing or marked.
3. `flutter gen-l10n` (auto-runs as part of `flutter pub get` when `generate: true`) produces `lib/l10n/app_localizations.dart`.
4. `MaterialApp` config:
   ```dart
   localizationsDelegates: AppLocalizations.localizationsDelegates,
   supportedLocales: AppLocalizations.supportedLocales,
   locale: localeCode != null ? Locale(localeCode) : null,
   ```
5. Every existing hardcoded `Text('...')` is migrated to `Text(AppLocalizations.of(context)!.someKey)` via a helper extension `S(context)` for brevity (`S(c).btnCampaign`).

Stage 5 will replace the TODO stubs with real translations.

---

## Settings screen

Opened from main menu `SETTINGS` button (currently disabled — enable it) and from pause dialog (NEW: add a small ⚙ icon next to RESUME/RESTART/QUIT).

### Layout (vertical, scrollable)

```
┌──────────────────────────────┐
│  ← SETTINGS                  │
│                              │
│  AUDIO                       │
│  ──────────                  │
│  SFX VOLUME                  │
│  ▮▮▮▮▮▮▯▯▯▯  45%             │
│                              │
│  MUSIC VOLUME                │
│  ▮▮▮▮▮▮▮▮▯▯  60%             │
│                              │
│  GAMEPLAY                    │
│  ──────────                  │
│  HAPTIC FEEDBACK    [● ON  ] │
│  REDUCE EFFECTS     [   OFF ○] │
│                              │
│  LANGUAGE                    │
│  ──────────                  │
│  ⦿ ENGLISH                   │
│  ○ ҚАЗАҚША    (coming soon)  │
│  ○ РУССКИЙ    (coming soon)  │
│                              │
│  ABOUT                       │
│  ──────────                  │
│  VOID TD v0.x.x              │
│  > CREDITS                   │
└──────────────────────────────┘
```

Components:
- `NeonSlider` — a styled Material `Slider` wrapper: cyan track + thumb + glow shadow, percentage label on the right. On `onChangeEnd` for SFX-volume, plays a test SFX (uiClick) so the user hears the new level.
- `NeonToggle` — styled `Switch`: cyan glow when ON.
- Language radios — KK and RU are disabled in Stage 4 (visually dimmed with "coming soon" label). Tap on them is a no-op.
- `> CREDITS` opens `CreditsScreen`, which renders `assets/audio/CREDITS.md` via a simple Text scroll.

### Defaults

```dart
const _defaults = Settings(
  sfxVolume: 0.45,
  musicVolume: 0.60,
  hapticOn: true,
  reduceEffects: false,
  localeCode: null,
);
```

### Reduce Effects — what it does

Toggled by user; read via `EffectsConfig.reduced` static getter (set from `SettingsController` on init and on change).

In Stage 4 it affects exactly two visuals:
1. `Enemy.render` burn-flicker animation → static dim orange
2. `Enemy.render` slow-pulse-ring → static cyan ring

Future stages can opt more effects in by reading the flag.

---

## Asset acquisition plan

For each SFX and music file, the implementation plan lists:
- Target filename
- Required character (e.g. "short click ~100ms, mid-tone, no reverb")
- Source URL (OpenGameArt.org or Freesound.org, preferring CC0 → CC-BY 4.0)
- License + author (for CREDITS.md)
- Fallback: if no URL pans out within 5 min of search, mark `MISSING` and use a silent stub (`assets/audio/silent_50ms.wav`) so code doesn't crash; revisit later.

CC-BY attributions are bundled in `assets/audio/CREDITS.md`. The file is committed alongside the audio assets; the Credits screen reads it via `rootBundle.loadString`.

Expected sizes:
- SFX: ~10-50 KB each × 10 = ~500 KB
- Music OGG: ~1-2 MB each × 6 = ~8-12 MB

Total APK increase: ~10 MB. Acceptable for a TD game.

---

## Testing

### Unit tests

- `SettingsRepo` round-trip: save → load returns identical Settings (all fields)
- `SettingsController` volume change emits new state to listeners
- `HapticService.trigger` with mocked `HapticFeedback` — no calls when `hapticOn=false`
- `AudioService` SFX throttling: two `playSfx(hit)` within 50ms → only one underlying play

### Widget tests

- `SettingsScreen` renders all sections; dragging SFX slider updates `SettingsController` state
- Existing `widget_test.dart` for main menu still passes (no removed assertions expected — only the underlying strings now come from AppLocalizations EN bundle)
- `widget_test.dart` ensures the SETTINGS button is now enabled and navigates

### Manual playtest checklist

- Cold start → defaults applied; menu music plays
- Change SFX/music volumes → close app → reopen → values persisted
- Background app (home button) → music pauses → return → resumes
- Hardware volume keys adjust media stream as expected
- Mode switch (Menu → Campaign → Endless → Constructor) → music swaps cleanly
- Victory/Defeat dialog → music swaps to victory_loop/defeat_loop, returns to gameplay music on retry/restart
- Toggle haptic OFF → placement/button presses produce no vibration
- Toggle Reduce Effects ON → burn/slow visual effects become static
- Open Settings from pause dialog → returns to game without losing match state
- Credits screen scrolls and shows correct CC-BY attributions

---

## Risks & unknowns

1. **flame_audio threading on Android** — we've already hit Flame's gesture-pipeline issues twice this project. `AudioService.init()` will run AFTER first frame via `addPostFrameCallback` to avoid colliding with build phase.

2. **Finding 6 quality chillout/ambient tracks** — may eat time. Mitigation: if no good Constructor-specific track surfaces, reuse the Endless track and mark a TODO in CREDITS.

3. **flutter gen-l10n vs build_runner conflict** — Hive already uses build_runner. l10n codegen runs separately via `flutter gen-l10n` (auto-invoked by `flutter pub get` thanks to `generate: true`). Should not conflict — verify on first run.

4. **System volume vs in-app slider UX confusion** — two independent controls. If a user maxes the phone but says "not loud enough," they'd need our slider too. Mitigation: confirm media-stream wiring is correct so phone keys directly affect total perceived loudness. If still confusing during playtest, consider hiding our sliders behind an "advanced" section.

5. **`PopScope canPop:false` + EXIT VOID TD? dialog** — UNCHANGED in this stage. Stays exactly as today.

---

## Out-of-scope confirmations

- No tower shot SFX (the user excluded option "A")
- No creep death SFX (the user explicitly excluded)
- No real KK/RU translations (Stage 5)
- No balance changes
- No new gameplay features
- No removal of the EXIT VOID TD? dialog — it stays as-is

---

## Definition of done

- All 10 SFX + 6 music files in `assets/audio/`, CREDITS.md complete
- `flutter analyze` clean, all existing + new tests green
- Settings screen reachable from main menu AND in-game pause
- Persisting/restoring settings works across cold-start
- Music transitions correctly between all screens
- App background/foreground pauses/resumes music
- Hardware volume keys work
- Hot restart and manual playtest checklist all pass
- Stage 4 plan committed and tagged in `c:\dev\void_td`; this design doc committed in `c:\dev\flutter_application_1`
