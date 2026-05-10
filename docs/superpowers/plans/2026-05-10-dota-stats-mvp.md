# Dota Stats MVP — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Создать мобильное приложение Dota Stats для Android и iOS — статистика и история матчей Dota 2, с двумя темами (Light + AMOLED), локализацией RU/EN и тремя источниками данных (OpenDota, Steam, Stratz).

**Architecture:** Clean Architecture в Flutter — слои `core / data / presentation` с разделением источников данных, репозиториев, BLoC-ов и UI. State management через `flutter_bloc`, HTTP через `dio` с интерсепторами для retry/кэша, кэш через `hive`, секреты в `flutter_secure_storage`.

**Tech Stack:** Flutter 3.x, Dart, flutter_bloc, dio, hive, go_router, flutter_secure_storage, shared_preferences, google_fonts, lucide_icons, flutter_svg, intl/flutter_localizations, mocktail (тесты), bloc_test.

**Spec:** `docs/superpowers/specs/2026-05-10-dota-stats-mvp-design.md`

**Тестовый Steam ID для разработки:** `https://steamcommunity.com/id/Jas9228/` (vanity URL → нужно резолвить в SteamID64 через Steam API при первом запуске).

**Целевая папка проекта:** `c:\dev\dota_stats` (отдельный git-репозиторий, не связан с `flutter_application_1`).

---

## Подсказка для Windows/bash

Все bash-команды в этом плане выполняются из `c:\dev\dota_stats` (новый проект), кроме первого этапа (создание проекта — выполняется из `c:\dev`).

Если используется PowerShell вместо bash — используй `;` вместо `&&`.

---

## Этап 0: Создание проекта и git-репозитория

### Task 0.1: Создание Flutter-проекта

**Files:**
- Create: `c:\dev\dota_stats\` (вся папка проекта)

- [ ] **Step 1: Проверить установленный Flutter**

Run: `flutter --version`
Expected: Flutter 3.x, Dart 3.x

Если Flutter не установлен — поставить с https://docs.flutter.dev/get-started/install/windows.

- [ ] **Step 2: Создать новый проект**

Run из `c:\dev`:
```bash
flutter create --org com.dotastats --platforms=android,ios --project-name dota_stats dota_stats
```

Expected: создана папка `c:\dev\dota_stats` со стандартной структурой Flutter.

- [ ] **Step 3: Проверить, что проект собирается**

Run из `c:\dev\dota_stats`:
```bash
flutter pub get
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Запустить дефолтное приложение на Android-устройстве**

Подключить Android-телефон по USB (включить Developer Options + USB debugging) или запустить эмулятор.

Run: `flutter devices`
Expected: устройство видно в списке.

Run: `flutter run`
Expected: приложение запускается, видно стандартный счётчик Flutter.

- [ ] **Step 5: Инициализировать git-репозиторий**

Run из `c:\dev\dota_stats`:
```bash
git init
git add .
git commit -m "chore: initial flutter project scaffold"
```

Expected: первый коммит создан.

---

### Task 0.2: Настройка .gitignore и базовая документация

**Files:**
- Modify: `c:\dev\dota_stats\.gitignore`
- Create: `c:\dev\dota_stats\README.md`

- [ ] **Step 1: Проверить .gitignore**

Открыть `.gitignore` и убедиться, что в нём есть строки:
```
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
build/
.idea/
*.iml
```

Если чего-то нет — добавить.

- [ ] **Step 2: Создать README.md**

Записать в `c:\dev\dota_stats\README.md`:
```markdown
# Dota Stats (DS)

Mobile app for Dota 2 statistics and match history (Android + iOS).

## Quick start

```bash
flutter pub get
flutter run
```

## API keys (optional)

The app works without keys (limited mode). For full features:

1. **Steam Web API key** — get free at https://steamcommunity.com/dev/apikey
2. **Stratz API key** — register via Steam at https://stratz.com → Profile → API

Enter keys in app: Settings → API keys.

## Tech stack

Flutter, flutter_bloc, dio, hive, go_router.

See `docs/spec.md` for full design.
```

- [ ] **Step 3: Commit**

```bash
git add README.md .gitignore
git commit -m "docs: add README and refine gitignore"
```

---

## Этап 1: Зависимости и базовая структура папок

### Task 1.1: Подключение зависимостей в pubspec.yaml

**Files:**
- Modify: `c:\dev\dota_stats\pubspec.yaml`

- [ ] **Step 1: Прописать зависимости**

В `pubspec.yaml` в секции `dependencies:` (под `cupertino_icons`) добавить:

```yaml
  # State management
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5

  # Networking
  dio: ^5.7.0

  # Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.2.2
  shared_preferences: ^2.3.3

  # Routing
  go_router: ^14.6.1

  # UI
  google_fonts: ^6.2.1
  flutter_svg: ^2.0.10+1
  lucide_icons: ^0.257.0

  # Localization
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
```

В секции `dev_dependencies:` добавить:
```yaml
  bloc_test: ^9.1.7
  mocktail: ^1.0.4
  hive_generator: ^2.0.1
  build_runner: ^2.4.13
  flutter_launcher_icons: ^0.14.1
```

В секции `flutter:` добавить:
```yaml
  generate: true   # для l10n
  uses-material-design: true
  assets:
    - assets/icon/
    - assets/images/
```

- [ ] **Step 2: Установить зависимости**

Run: `flutter pub get`
Expected: все пакеты загружены без ошибок.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add core dependencies (bloc, dio, hive, router, l10n)"
```

---

### Task 1.2: Создание структуры папок

**Files:**
- Create: пустые папки в `lib/` и `test/`

- [ ] **Step 1: Создать структуру**

Run из `c:\dev\dota_stats`:
```bash
mkdir -p lib/core/constants lib/core/theme lib/core/network lib/core/storage lib/core/router lib/core/utils
mkdir -p lib/data/models lib/data/datasources lib/data/repositories
mkdir -p lib/presentation/blocs lib/presentation/screens lib/presentation/widgets
mkdir -p lib/l10n
mkdir -p assets/icon assets/images
mkdir -p test/unit test/widget test/integration
```

- [ ] **Step 2: Создать `.gitkeep` в пустых папках**

В каждую пустую папку положить пустой файл `.gitkeep`, чтобы git их сохранил.

- [ ] **Step 3: Commit**

```bash
git add lib/ test/ assets/
git commit -m "chore: scaffold folder structure"
```

---

## Этап 2: Темы (Light + AMOLED)

### Task 2.1: Цветовые палитры

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Test: `test/unit/theme/app_colors_test.dart`

- [ ] **Step 1: Написать тест**

Создать `test/unit/theme/app_colors_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dota_stats/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('Light palette has expected accent gold', () {
      expect(AppColors.light.accent, const Color(0xFFC8AA6E));
    });

    test('AMOLED palette has pure black background', () {
      expect(AppColors.amoled.background, const Color(0xFF000000));
    });

    test('Both palettes define win and lose colors', () {
      expect(AppColors.light.win, isA<Color>());
      expect(AppColors.amoled.lose, isA<Color>());
    });
  });
}
```

- [ ] **Step 2: Запустить — тест провалится**

Run: `flutter test test/unit/theme/app_colors_test.dart`
Expected: FAIL — файла нет.

- [ ] **Step 3: Реализовать палитры**

Создать `lib/core/theme/app_colors.dart`:
```dart
import 'package:flutter/material.dart';

class DotaPalette {
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color win;
  final Color lose;
  final Color divider;

  const DotaPalette({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.win,
    required this.lose,
    required this.divider,
  });
}

class AppColors {
  static const light = DotaPalette(
    background: Color(0xFFF5EFE0),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B6B6B),
    accent: Color(0xFFC8AA6E),
    win: Color(0xFF3A8E3A),
    lose: Color(0xFFC13030),
    divider: Color(0xFFE5DFCF),
  );

  static const amoled = DotaPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF000000),
    textPrimary: Color(0xFFF0E6D2),
    textSecondary: Color(0xFF7D7D7D),
    accent: Color(0xFFC8AA6E),
    win: Color(0xFF5CBC4E),
    lose: Color(0xFFE04545),
    divider: Color(0xFF1F1F1F),
  );

  // Цвета медалей рангов
  static const rankHerald = Color(0xFF8C8989);
  static const rankGuardian = Color(0xFF8C5A2B);
  static const rankCrusader = Color(0xFF4F8C3A);
  static const rankArchon = Color(0xFF8C3A8C);
  static const rankLegend = Color(0xFF3A5A8C);
  static const rankAncient = Color(0xFF3A8C8C);
  static const rankDivine = Color(0xFFE08CB0);
  static const rankImmortal = Color(0xFFFFD700);
}
```

- [ ] **Step 4: Запустить — тест проходит**

Run: `flutter test test/unit/theme/app_colors_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_colors.dart test/unit/theme/app_colors_test.dart
git commit -m "feat(theme): add Light and AMOLED color palettes"
```

---

### Task 2.2: Текстовые стили (Inter + JetBrains Mono)

**Files:**
- Create: `lib/core/theme/app_text_styles.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/core/theme/app_text_styles.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  static TextStyle heading1(Color color) => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle heading2(Color color) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle body(Color color) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle caption(Color color) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // Моноширинный для цифр статистики (KDA, GPM, урон)
  static TextStyle stat(Color color, {double size = 14}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle statBold(Color color, {double size = 16}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
```

- [ ] **Step 2: Проверить компиляцию**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/theme/app_text_styles.dart
git commit -m "feat(theme): add text styles using Inter and JetBrains Mono"
```

---

### Task 2.3: ThemeData для обеих тем

**Files:**
- Create: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/core/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData _build(DotaPalette palette, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.accent,
        onPrimary: palette.background,
        secondary: palette.accent,
        onSecondary: palette.background,
        error: palette.lose,
        onError: palette.background,
        surface: palette.surface,
        onSurface: palette.textPrimary,
      ),
      cardTheme: CardTheme(
        color: palette.surface,
        elevation: brightness == Brightness.light ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: brightness == Brightness.dark
              ? BorderSide(color: palette.divider, width: 1)
              : BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.accent,
        unselectedItemColor: palette.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      extensions: [DotaThemeExt(palette: palette)],
    );
  }

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData amoled() => _build(AppColors.amoled, Brightness.dark);
}

@immutable
class DotaThemeExt extends ThemeExtension<DotaThemeExt> {
  final DotaPalette palette;
  const DotaThemeExt({required this.palette});

  @override
  DotaThemeExt copyWith({DotaPalette? palette}) =>
      DotaThemeExt(palette: palette ?? this.palette);

  @override
  DotaThemeExt lerp(DotaThemeExt? other, double t) => this;
}

extension DotaThemeContext on BuildContext {
  DotaPalette get palette =>
      Theme.of(this).extension<DotaThemeExt>()!.palette;
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/theme/app_theme.dart
git commit -m "feat(theme): add Light and AMOLED ThemeData with palette extension"
```

---

### Task 2.4: ThemeCubit для переключения

**Files:**
- Create: `lib/presentation/blocs/theme/theme_cubit.dart`
- Test: `test/unit/blocs/theme_cubit_test.dart`

- [ ] **Step 1: Написать тест**

Создать `test/unit/blocs/theme_cubit_test.dart`:
```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dota_stats/presentation/blocs/theme/theme_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  blocTest<ThemeCubit, AppThemeMode>(
    'starts with system mode by default',
    build: () => ThemeCubit(),
    verify: (cubit) => expect(cubit.state, AppThemeMode.system),
  );

  blocTest<ThemeCubit, AppThemeMode>(
    'switches to AMOLED',
    build: () => ThemeCubit(),
    act: (cubit) => cubit.setMode(AppThemeMode.amoled),
    expect: () => [AppThemeMode.amoled],
  );

  blocTest<ThemeCubit, AppThemeMode>(
    'switches to Light',
    build: () => ThemeCubit(),
    act: (cubit) => cubit.setMode(AppThemeMode.light),
    expect: () => [AppThemeMode.light],
  );
}
```

- [ ] **Step 2: Запустить — провалится**

Run: `flutter test test/unit/blocs/theme_cubit_test.dart`
Expected: FAIL.

- [ ] **Step 3: Реализовать**

Создать `lib/presentation/blocs/theme/theme_cubit.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, amoled, system }

class ThemeCubit extends Cubit<AppThemeMode> {
  static const _key = 'theme_mode';
  ThemeCubit() : super(AppThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      emit(AppThemeMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => AppThemeMode.system,
      ));
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
```

- [ ] **Step 4: Тест проходит**

Run: `flutter test test/unit/blocs/theme_cubit_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/blocs/theme/ test/unit/blocs/theme_cubit_test.dart
git commit -m "feat(theme): add ThemeCubit with persistence"
```

---

## Этап 3: Локализация (RU/EN) и LocaleCubit

### Task 3.1: ARB-файлы и конфиг

**Files:**
- Create: `l10n.yaml`
- Create: `lib/l10n/app_en.arb`
- Create: `lib/l10n/app_ru.arb`

- [ ] **Step 1: Создать `l10n.yaml` в корне проекта**

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
```

- [ ] **Step 2: Создать `lib/l10n/app_en.arb`**

```json
{
  "@@locale": "en",
  "appTitle": "Dota Stats",
  "tabProfile": "Profile",
  "tabSearch": "Search",
  "tabSettings": "Settings",
  "onboardingWelcome": "Welcome to Dota Stats",
  "onboardingEnterIdHint": "Enter Steam ID or profile URL",
  "onboardingContinue": "Continue",
  "onboardingSkipKeys": "Skip for now",
  "profileWinRate": "Win rate",
  "profileTotalGames": "Total games",
  "profileWins": "Wins",
  "profileLosses": "Losses",
  "profileFavoriteHeroes": "Favorite heroes",
  "profileRecentMatches": "Recent matches",
  "profileShowAll": "Show all",
  "matchesTitle": "Match history",
  "matchDetailsRadiant": "Radiant",
  "matchDetailsDire": "Dire",
  "matchDetailsDuration": "Duration",
  "searchTitle": "Search player",
  "searchHint": "Nickname or Steam ID",
  "settingsTitle": "Settings",
  "settingsLanguage": "Language",
  "settingsTheme": "Theme",
  "settingsApiKeys": "API keys",
  "settingsAccount": "Account",
  "settingsLogOut": "Log out",
  "settingsAbout": "About",
  "themeLight": "Light",
  "themeAmoled": "AMOLED",
  "themeSystem": "System",
  "languageEn": "English",
  "languageRu": "Russian",
  "languageSystem": "System",
  "errorNoInternet": "No internet connection",
  "errorRateLimit": "Too many requests, wait a minute",
  "errorPlayerNotFound": "Player not found",
  "errorPrivateProfile": "This profile is private",
  "retry": "Retry"
}
```

- [ ] **Step 3: Создать `lib/l10n/app_ru.arb`**

```json
{
  "@@locale": "ru",
  "appTitle": "Dota Stats",
  "tabProfile": "Профиль",
  "tabSearch": "Поиск",
  "tabSettings": "Настройки",
  "onboardingWelcome": "Добро пожаловать в Dota Stats",
  "onboardingEnterIdHint": "Введите Steam ID или ссылку на профиль",
  "onboardingContinue": "Продолжить",
  "onboardingSkipKeys": "Пропустить",
  "profileWinRate": "Винрейт",
  "profileTotalGames": "Всего игр",
  "profileWins": "Победы",
  "profileLosses": "Поражения",
  "profileFavoriteHeroes": "Любимые герои",
  "profileRecentMatches": "Последние матчи",
  "profileShowAll": "Показать все",
  "matchesTitle": "История матчей",
  "matchDetailsRadiant": "Radiant",
  "matchDetailsDire": "Dire",
  "matchDetailsDuration": "Длительность",
  "searchTitle": "Поиск игрока",
  "searchHint": "Ник или Steam ID",
  "settingsTitle": "Настройки",
  "settingsLanguage": "Язык",
  "settingsTheme": "Тема",
  "settingsApiKeys": "Ключи API",
  "settingsAccount": "Аккаунт",
  "settingsLogOut": "Выйти",
  "settingsAbout": "О приложении",
  "themeLight": "Светлая",
  "themeAmoled": "AMOLED",
  "themeSystem": "Системная",
  "languageEn": "Английский",
  "languageRu": "Русский",
  "languageSystem": "Системный",
  "errorNoInternet": "Нет интернет-соединения",
  "errorRateLimit": "Слишком много запросов, подождите минуту",
  "errorPlayerNotFound": "Игрок не найден",
  "errorPrivateProfile": "Этот профиль приватный",
  "retry": "Повторить"
}
```

- [ ] **Step 4: Сгенерировать**

Run: `flutter gen-l10n`
Expected: создан `.dart_tool/flutter_gen/gen_l10n/app_localizations.dart`.

- [ ] **Step 5: Commit**

```bash
git add l10n.yaml lib/l10n/
git commit -m "feat(l10n): add RU and EN translations"
```

---

### Task 3.2: LocaleCubit

**Files:**
- Create: `lib/presentation/blocs/locale/locale_cubit.dart`
- Test: `test/unit/blocs/locale_cubit_test.dart`

- [ ] **Step 1: Написать тест**

Создать `test/unit/blocs/locale_cubit_test.dart`:
```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dota_stats/presentation/blocs/locale/locale_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  blocTest<LocaleCubit, AppLocale>(
    'defaults to ru',
    build: () => LocaleCubit(),
    verify: (c) => expect(c.state, AppLocale.ru),
  );

  blocTest<LocaleCubit, AppLocale>(
    'switches to en',
    build: () => LocaleCubit(),
    act: (c) => c.setLocale(AppLocale.en),
    expect: () => [AppLocale.en],
  );
}
```

- [ ] **Step 2: Реализовать**

Создать `lib/presentation/blocs/locale/locale_cubit.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLocale { ru, en, system }

class LocaleCubit extends Cubit<AppLocale> {
  static const _key = 'locale';
  LocaleCubit() : super(AppLocale.ru) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      emit(AppLocale.values.firstWhere(
        (l) => l.name == raw,
        orElse: () => AppLocale.ru,
      ));
    }
  }

  Future<void> setLocale(AppLocale locale) async {
    emit(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.name);
  }
}
```

- [ ] **Step 3: Тест проходит**

Run: `flutter test test/unit/blocs/locale_cubit_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/blocs/locale/ test/unit/blocs/locale_cubit_test.dart
git commit -m "feat(l10n): add LocaleCubit with persistence"
```

---

## Этап 4: Сетевой слой (Dio + retry + endpoints)

### Task 4.1: API endpoints (константы)

**Files:**
- Create: `lib/core/constants/api_endpoints.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/core/constants/api_endpoints.dart`:
```dart
class ApiEndpoints {
  static const openDotaBase = 'https://api.opendota.com/api';
  static const steamBase = 'https://api.steampowered.com';
  static const stratzBase = 'https://api.stratz.com/graphql';

  // OpenDota
  static String player(int accountId) => '$openDotaBase/players/$accountId';
  static String playerWinLoss(int accountId) =>
      '$openDotaBase/players/$accountId/wl';
  static String playerHeroes(int accountId) =>
      '$openDotaBase/players/$accountId/heroes';
  static String playerRecentMatches(int accountId) =>
      '$openDotaBase/players/$accountId/recentMatches';
  static String playerMatches(int accountId) =>
      '$openDotaBase/players/$accountId/matches';
  static String match(int matchId) => '$openDotaBase/matches/$matchId';
  static String searchPlayers(String query) =>
      '$openDotaBase/search?q=${Uri.encodeQueryComponent(query)}';
  static const heroesConstants = '$openDotaBase/constants/heroes';
  static const itemsConstants = '$openDotaBase/constants/items';

  // Steam Web API
  static String steamSummaries(String key, String steamIds) =>
      '$steamBase/ISteamUser/GetPlayerSummaries/v0002/?key=$key&steamids=$steamIds';
  static String steamResolveVanity(String key, String vanityName) =>
      '$steamBase/ISteamUser/ResolveVanityURL/v0001/?key=$key&vanityurl=$vanityName';

  // CDN иконок
  static String heroIcon(String heroName) =>
      'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/${heroName.replaceFirst('npc_dota_hero_', '')}.png';
  static String itemIcon(String itemName) =>
      'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/items/${itemName.replaceFirst('item_', '')}.png';
}
```

- [ ] **Step 2: Проверить компиляцию**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/constants/api_endpoints.dart
git commit -m "feat(api): add API endpoint constants for OpenDota, Steam, CDN"
```

---

### Task 4.2: Кастомные исключения API

**Files:**
- Create: `lib/core/network/api_exception.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/core/network/api_exception.dart`:
```dart
sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

class NoInternetException extends ApiException {
  const NoInternetException() : super('No internet connection');
}

class RateLimitException extends ApiException {
  const RateLimitException() : super('Rate limit exceeded');
}

class NotFoundException extends ApiException {
  const NotFoundException(super.message);
}

class PrivateProfileException extends ApiException {
  const PrivateProfileException()
      : super('Profile is private');
}

class ServerException extends ApiException {
  final int statusCode;
  const ServerException(this.statusCode, super.message);
}

class UnknownApiException extends ApiException {
  const UnknownApiException(super.message);
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/network/api_exception.dart
git commit -m "feat(network): add typed API exceptions"
```

---

### Task 4.3: Retry-интерсептор для Dio

**Files:**
- Create: `lib/core/network/retry_interceptor.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/core/network/retry_interceptor.dart`:
```dart
import 'dart:async';
import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 500),
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final retries = (err.requestOptions.extra['retries'] as int?) ?? 0;
    final shouldRetry = _shouldRetry(err) && retries < maxRetries;

    if (shouldRetry) {
      final delay = baseDelay * (1 << retries); // 500ms, 1s, 2s
      await Future<void>.delayed(delay);
      err.requestOptions.extra['retries'] = retries + 1;
      try {
        final response = await dio.fetch<dynamic>(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        return handler.next(err);
      }
    }
    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return true;
    }
    final status = err.response?.statusCode;
    return status != null && status >= 500 && status < 600;
  }
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/network/retry_interceptor.dart
git commit -m "feat(network): add retry interceptor with exponential backoff"
```

---

### Task 4.4: Dio клиент-фабрика

**Files:**
- Create: `lib/core/network/dio_client.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/core/network/dio_client.dart`:
```dart
import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'retry_interceptor.dart';

class DioClient {
  static Dio create({String? baseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(RetryInterceptor(dio: dio));
    return dio;
  }

  /// Конвертирует DioException в ApiException
  static ApiException mapError(DioException err) {
    if (err.type == DioExceptionType.connectionError ||
        err.error is Exception &&
            err.error.toString().toLowerCase().contains('socket')) {
      return const NoInternetException();
    }
    final status = err.response?.statusCode;
    if (status == 429) return const RateLimitException();
    if (status == 404) {
      return const NotFoundException('Resource not found');
    }
    if (status == 403) return const PrivateProfileException();
    if (status != null && status >= 500) {
      return ServerException(status, 'Server error: $status');
    }
    return UnknownApiException(err.message ?? 'Unknown error');
  }
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/network/dio_client.dart
git commit -m "feat(network): add Dio client factory with error mapping"
```

---

## Этап 5: Хранилища (Hive-кэш + Secure Storage)

### Task 5.1: Secure Storage для API-ключей

**Files:**
- Create: `lib/core/storage/secure_storage.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/core/storage/secure_storage.dart`:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _steamKey = 'steam_api_key';
  static const _stratzKey = 'stratz_api_key';
  static const _accountIdKey = 'current_account_id';

  final FlutterSecureStorage _storage;

  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> getSteamApiKey() => _storage.read(key: _steamKey);
  Future<void> setSteamApiKey(String key) =>
      _storage.write(key: _steamKey, value: key);
  Future<void> deleteSteamApiKey() => _storage.delete(key: _steamKey);

  Future<String?> getStratzApiKey() => _storage.read(key: _stratzKey);
  Future<void> setStratzApiKey(String key) =>
      _storage.write(key: _stratzKey, value: key);
  Future<void> deleteStratzApiKey() => _storage.delete(key: _stratzKey);

  Future<int?> getCurrentAccountId() async {
    final raw = await _storage.read(key: _accountIdKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setCurrentAccountId(int accountId) =>
      _storage.write(key: _accountIdKey, value: accountId.toString());

  Future<void> clearAccount() => _storage.delete(key: _accountIdKey);
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/storage/secure_storage.dart
git commit -m "feat(storage): add secure storage for API keys and account ID"
```

---

### Task 5.2: Hive-кэш с TTL

**Files:**
- Create: `lib/core/storage/cache_storage.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/core/storage/cache_storage.dart`:
```dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class CacheStorage {
  static const _boxName = 'api_cache';
  late Box<String> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

  /// Сохранить значение с TTL. ttl == null → бесконечно (для матчей).
  Future<void> set(
    String key,
    Map<String, dynamic> value, {
    Duration? ttl,
  }) async {
    final entry = {
      'data': value,
      'expiresAt': ttl == null
          ? null
          : DateTime.now().add(ttl).millisecondsSinceEpoch,
    };
    await _box.put(key, jsonEncode(entry));
  }

  /// Получить значение, если не истекло.
  Map<String, dynamic>? get(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    final entry = jsonDecode(raw) as Map<String, dynamic>;
    final expiresAt = entry['expiresAt'] as int?;
    if (expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch > expiresAt) {
      _box.delete(key);
      return null;
    }
    return entry['data'] as Map<String, dynamic>;
  }

  Future<void> clear() => _box.clear();
}
```

- [ ] **Step 2: Тест кэша**

Создать `test/unit/storage/cache_storage_test.dart`:
```dart
import 'package:dota_stats/core/storage/cache_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.test_hive';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    PathProviderPlatform.instance = _FakePathProvider();
    Hive.init('.test_hive');
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('api_cache');
  });

  test('stores and retrieves value', () async {
    final cache = CacheStorage();
    await cache.init();
    await cache.set('key1', {'foo': 'bar'});
    expect(cache.get('key1'), {'foo': 'bar'});
  });

  test('returns null after TTL expiry', () async {
    final cache = CacheStorage();
    await cache.init();
    await cache.set('k', {'v': 1}, ttl: const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(cache.get('k'), isNull);
  });
}
```

- [ ] **Step 3: Запустить тесты**

Run: `flutter test test/unit/storage/cache_storage_test.dart`
Expected: PASS (оба теста).

- [ ] **Step 4: Commit**

```bash
git add lib/core/storage/cache_storage.dart test/unit/storage/cache_storage_test.dart
git commit -m "feat(storage): add Hive-based cache with TTL"
```

---

## Этап 6: Модели данных

### Task 6.1: Утилита Steam ID converter

**Files:**
- Create: `lib/core/utils/steam_id_converter.dart`
- Test: `test/unit/utils/steam_id_converter_test.dart`

- [ ] **Step 1: Написать тест**

Создать `test/unit/utils/steam_id_converter_test.dart`:
```dart
import 'package:dota_stats/core/utils/steam_id_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SteamIdConverter', () {
    test('64-bit to 32-bit', () {
      // SteamID64 = 76561197960287930 → SteamID32 = 22202
      expect(SteamIdConverter.to32(76561197960287930), 22202);
    });

    test('32-bit to 64-bit', () {
      expect(SteamIdConverter.to64(22202), 76561197960287930);
    });

    test('parses 32-bit number string', () {
      expect(SteamIdConverter.parseAccountId('22202'), 22202);
    });

    test('parses 64-bit number string and converts to 32', () {
      expect(SteamIdConverter.parseAccountId('76561197960287930'), 22202);
    });

    test('extracts vanity name from URL', () {
      expect(
        SteamIdConverter.extractVanity('https://steamcommunity.com/id/Jas9228/'),
        'Jas9228',
      );
    });

    test('extracts vanity from short form', () {
      expect(SteamIdConverter.extractVanity('Jas9228'), 'Jas9228');
    });

    test('returns null vanity for profile/<digits> URL', () {
      expect(
        SteamIdConverter.extractVanity('https://steamcommunity.com/profiles/76561197960287930'),
        isNull,
      );
    });

    test('extracts steamId64 from profiles URL', () {
      expect(
        SteamIdConverter.extractSteamId64('https://steamcommunity.com/profiles/76561197960287930'),
        76561197960287930,
      );
    });
  });
}
```

- [ ] **Step 2: Реализовать**

Создать `lib/core/utils/steam_id_converter.dart`:
```dart
class SteamIdConverter {
  /// Базовое значение для конвертации SteamID64 ↔ SteamID32
  static const int _steamIdBase = 76561197960265728;

  static int to32(int steamId64) => steamId64 - _steamIdBase;
  static int to64(int accountId) => accountId + _steamIdBase;

  /// Принимает строку ID (32 или 64 бит) и возвращает accountId (32-битный),
  /// который использует OpenDota.
  static int? parseAccountId(String input) {
    final n = int.tryParse(input.trim());
    if (n == null) return null;
    if (n > _steamIdBase) return to32(n);
    return n;
  }

  /// Из ссылки `https://steamcommunity.com/id/<vanity>/` или просто `<vanity>`
  /// возвращает vanity-имя. Если URL вида `/profiles/<digits>` — возвращает null.
  static String? extractVanity(String input) {
    final s = input.trim();
    final idMatch = RegExp(r'steamcommunity\.com/id/([^/?#]+)').firstMatch(s);
    if (idMatch != null) return idMatch.group(1);
    final profileMatch = RegExp(r'steamcommunity\.com/profiles/').hasMatch(s);
    if (profileMatch) return null;
    if (s.contains('/') || s.contains('.')) return null;
    if (int.tryParse(s) != null) return null;
    return s; // голое vanity-имя
  }

  /// Из ссылки `https://steamcommunity.com/profiles/<digits>` извлекает SteamID64.
  static int? extractSteamId64(String input) {
    final m = RegExp(r'steamcommunity\.com/profiles/(\d+)').firstMatch(input);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }
}
```

- [ ] **Step 3: Тест проходит**

Run: `flutter test test/unit/utils/steam_id_converter_test.dart`
Expected: PASS (все тесты).

- [ ] **Step 4: Commit**

```bash
git add lib/core/utils/steam_id_converter.dart test/unit/utils/steam_id_converter_test.dart
git commit -m "feat(utils): add Steam ID converter (vanity, 32/64 bit, URL parse)"
```

---

### Task 6.2: Форматтеры (KDA, время, числа)

**Files:**
- Create: `lib/core/utils/formatters.dart`
- Test: `test/unit/utils/formatters_test.dart`

- [ ] **Step 1: Написать тест**

Создать `test/unit/utils/formatters_test.dart`:
```dart
import 'package:dota_stats/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formatters', () {
    test('formatDuration: 2532s → 42:12', () {
      expect(Formatters.duration(2532), '42:12');
    });

    test('formatDuration: 65s → 01:05', () {
      expect(Formatters.duration(65), '01:05');
    });

    test('formatNumber: 12500 → 12,500', () {
      expect(Formatters.number(12500), '12,500');
    });

    test('formatKda: 10/2/15 → 10/2/15', () {
      expect(Formatters.kda(10, 2, 15), '10/2/15');
    });

    test('formatRelativeTime: minutes ago', () {
      final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 600;
      expect(Formatters.relativeTime(ts), contains('m'));
    });
  });
}
```

- [ ] **Step 2: Реализовать**

Создать `lib/core/utils/formatters.dart`:
```dart
import 'package:intl/intl.dart';

class Formatters {
  static final _numberFormat = NumberFormat('#,##0', 'en_US');

  /// Длительность в секундах → "MM:SS" или "H:MM:SS"
  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:$mm:$ss';
    return '$mm:$ss';
  }

  static String number(num n) => _numberFormat.format(n);

  static String kda(int kills, int deaths, int assists) =>
      '$kills/$deaths/$assists';

  /// Unix timestamp (sec) → "5m ago", "2h ago", "3d ago"
  static String relativeTime(int unixSeconds) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - unixSeconds;
    if (diff < 60) return '${diff}s ago';
    if (diff < 3600) return '${diff ~/ 60}m ago';
    if (diff < 86400) return '${diff ~/ 3600}h ago';
    if (diff < 86400 * 30) return '${diff ~/ 86400}d ago';
    return '${diff ~/ (86400 * 30)}mo ago';
  }
}
```

- [ ] **Step 3: Тест проходит**

Run: `flutter test test/unit/utils/formatters_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/core/utils/formatters.dart test/unit/utils/formatters_test.dart
git commit -m "feat(utils): add formatters for duration, KDA, numbers, relative time"
```

---

### Task 6.3: Модель Player

**Files:**
- Create: `lib/data/models/player.dart`
- Test: `test/unit/models/player_test.dart`

- [ ] **Step 1: Написать тест**

Создать `test/unit/models/player_test.dart`:
```dart
import 'package:dota_stats/data/models/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Player.fromOpenDotaJson parses profile', () {
    final json = {
      'profile': {
        'account_id': 22202,
        'personaname': 'Jas9228',
        'avatarfull': 'https://example.com/avatar.jpg',
        'profileurl': 'https://steamcommunity.com/id/Jas9228/',
      },
      'rank_tier': 55, // Legend 5
      'leaderboard_rank': null,
    };
    final p = Player.fromOpenDotaJson(json);
    expect(p.accountId, 22202);
    expect(p.name, 'Jas9228');
    expect(p.rankTier, 55);
  });

  test('Player.fromOpenDotaJson handles null rank', () {
    final json = {
      'profile': {
        'account_id': 1,
        'personaname': 'Anon',
        'avatarfull': '',
        'profileurl': '',
      },
    };
    final p = Player.fromOpenDotaJson(json);
    expect(p.rankTier, isNull);
  });
}
```

- [ ] **Step 2: Реализовать**

Создать `lib/data/models/player.dart`:
```dart
import 'package:equatable/equatable.dart';

class Player extends Equatable {
  final int accountId;
  final String name;
  final String avatarUrl;
  final String profileUrl;
  final int? rankTier; // 11..85, null если не калиброван
  final int? leaderboardRank;

  const Player({
    required this.accountId,
    required this.name,
    required this.avatarUrl,
    required this.profileUrl,
    this.rankTier,
    this.leaderboardRank,
  });

  factory Player.fromOpenDotaJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map<String, dynamic>?) ?? {};
    return Player(
      accountId: profile['account_id'] as int? ?? 0,
      name: profile['personaname'] as String? ?? 'Unknown',
      avatarUrl: profile['avatarfull'] as String? ?? '',
      profileUrl: profile['profileurl'] as String? ?? '',
      rankTier: json['rank_tier'] as int?,
      leaderboardRank: json['leaderboard_rank'] as int?,
    );
  }

  @override
  List<Object?> get props =>
      [accountId, name, avatarUrl, profileUrl, rankTier, leaderboardRank];
}
```

- [ ] **Step 3: Тест проходит**

Run: `flutter test test/unit/models/player_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/player.dart test/unit/models/player_test.dart
git commit -m "feat(models): add Player model with OpenDota JSON parsing"
```

---

### Task 6.4: Модель Rank (медаль)

**Files:**
- Create: `lib/data/models/rank.dart`
- Test: `test/unit/models/rank_test.dart`

- [ ] **Step 1: Написать тест**

Создать `test/unit/models/rank_test.dart`:
```dart
import 'package:dota_stats/data/models/rank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rank from rankTier=55 → Legend 5', () {
    final r = Rank.fromTier(55);
    expect(r.tier, RankTier.legend);
    expect(r.stars, 5);
  });

  test('Rank from null → uncalibrated', () {
    final r = Rank.fromTier(null);
    expect(r.tier, RankTier.uncalibrated);
    expect(r.stars, 0);
  });

  test('Rank from 80 → Immortal (no stars)', () {
    final r = Rank.fromTier(80);
    expect(r.tier, RankTier.immortal);
  });
}
```

- [ ] **Step 2: Реализовать**

Создать `lib/data/models/rank.dart`:
```dart
import 'package:equatable/equatable.dart';

enum RankTier {
  uncalibrated,
  herald,
  guardian,
  crusader,
  archon,
  legend,
  ancient,
  divine,
  immortal,
}

class Rank extends Equatable {
  final RankTier tier;
  final int stars; // 1..5, для immortal не используется
  final int? leaderboardRank;

  const Rank({
    required this.tier,
    required this.stars,
    this.leaderboardRank,
  });

  /// rankTier — это двузначное число: первая цифра тир (1..8), вторая — звёзды (1..5).
  /// Например, 55 = Legend 5; 12 = Herald 2; 80 = Immortal.
  factory Rank.fromTier(int? rankTier, {int? leaderboardRank}) {
    if (rankTier == null) {
      return const Rank(tier: RankTier.uncalibrated, stars: 0);
    }
    final tierIdx = rankTier ~/ 10;
    final stars = rankTier % 10;
    final tier = switch (tierIdx) {
      1 => RankTier.herald,
      2 => RankTier.guardian,
      3 => RankTier.crusader,
      4 => RankTier.archon,
      5 => RankTier.legend,
      6 => RankTier.ancient,
      7 => RankTier.divine,
      8 => RankTier.immortal,
      _ => RankTier.uncalibrated,
    };
    return Rank(
      tier: tier,
      stars: tier == RankTier.immortal ? 0 : stars,
      leaderboardRank: leaderboardRank,
    );
  }

  @override
  List<Object?> get props => [tier, stars, leaderboardRank];
}
```

- [ ] **Step 3: Тест проходит**

Run: `flutter test test/unit/models/rank_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/rank.dart test/unit/models/rank_test.dart
git commit -m "feat(models): add Rank model (medal tier + stars)"
```

---

### Task 6.5: Модель MatchPlayer (один игрок в матче)

**Files:**
- Create: `lib/data/models/match_player.dart`
- Test: `test/unit/models/match_player_test.dart`

- [ ] **Step 1: Написать тест**

Создать `test/unit/models/match_player_test.dart`:
```dart
import 'package:dota_stats/data/models/match_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MatchPlayer.fromJson parses fields', () {
    final json = {
      'account_id': 22202,
      'personaname': 'Jas9228',
      'hero_id': 14,
      'player_slot': 0, // Radiant
      'kills': 10,
      'deaths': 2,
      'assists': 15,
      'level': 25,
      'gold_per_min': 600,
      'xp_per_min': 700,
      'hero_damage': 25000,
      'hero_healing': 1000,
      'last_hits': 250,
      'denies': 12,
      'item_0': 1, 'item_1': 2, 'item_2': 3,
      'item_3': 4, 'item_4': 5, 'item_5': 6,
      'backpack_0': 0, 'backpack_1': 0, 'backpack_2': 0,
      'item_neutral': 7,
    };
    final p = MatchPlayer.fromJson(json);
    expect(p.heroId, 14);
    expect(p.isRadiant, true);
    expect(p.kills, 10);
    expect(p.items.length, 6);
    expect(p.items[0], 1);
    expect(p.neutralItem, 7);
  });

  test('player_slot >= 128 means Dire', () {
    final json = {'player_slot': 128, 'hero_id': 1};
    final p = MatchPlayer.fromJson(json);
    expect(p.isRadiant, false);
  });
}
```

- [ ] **Step 2: Реализовать**

Создать `lib/data/models/match_player.dart`:
```dart
import 'package:equatable/equatable.dart';

class MatchPlayer extends Equatable {
  final int? accountId; // null если анонимный
  final String name;
  final int heroId;
  final int playerSlot; // 0..4 = Radiant, 128..132 = Dire
  final int kills;
  final int deaths;
  final int assists;
  final int level;
  final int gpm;
  final int xpm;
  final int heroDamage;
  final int heroHealing;
  final int lastHits;
  final int denies;
  final List<int> items; // 6 слотов
  final List<int> backpack; // 3 слота
  final int neutralItem;

  const MatchPlayer({
    this.accountId,
    required this.name,
    required this.heroId,
    required this.playerSlot,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.level,
    required this.gpm,
    required this.xpm,
    required this.heroDamage,
    required this.heroHealing,
    required this.lastHits,
    required this.denies,
    required this.items,
    required this.backpack,
    required this.neutralItem,
  });

  bool get isRadiant => playerSlot < 128;

  factory MatchPlayer.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    return MatchPlayer(
      accountId: json['account_id'] as int?,
      name: json['personaname'] as String? ?? 'Anonymous',
      heroId: n('hero_id'),
      playerSlot: n('player_slot'),
      kills: n('kills'),
      deaths: n('deaths'),
      assists: n('assists'),
      level: n('level'),
      gpm: n('gold_per_min'),
      xpm: n('xp_per_min'),
      heroDamage: n('hero_damage'),
      heroHealing: n('hero_healing'),
      lastHits: n('last_hits'),
      denies: n('denies'),
      items: [for (var i = 0; i < 6; i++) n('item_$i')],
      backpack: [for (var i = 0; i < 3; i++) n('backpack_$i')],
      neutralItem: n('item_neutral'),
    );
  }

  @override
  List<Object?> get props => [
        accountId,
        name,
        heroId,
        playerSlot,
        kills,
        deaths,
        assists,
        level,
        gpm,
        xpm,
        heroDamage,
        heroHealing,
        lastHits,
        denies,
        items,
        backpack,
        neutralItem,
      ];
}
```

- [ ] **Step 3: Тест проходит**

Run: `flutter test test/unit/models/match_player_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/match_player.dart test/unit/models/match_player_test.dart
git commit -m "feat(models): add MatchPlayer model with full match stats"
```

---

### Task 6.6: Модели Match и MatchSummary

**Files:**
- Create: `lib/data/models/match.dart`
- Test: `test/unit/models/match_test.dart`

- [ ] **Step 1: Написать тест**

Создать `test/unit/models/match_test.dart`:
```dart
import 'package:dota_stats/data/models/match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MatchSummary parses recentMatches entry', () {
    final json = {
      'match_id': 7654321,
      'player_slot': 0,
      'radiant_win': true,
      'duration': 2400,
      'game_mode': 22,
      'lobby_type': 7,
      'hero_id': 14,
      'kills': 10,
      'deaths': 2,
      'assists': 15,
      'start_time': 1715000000,
    };
    final m = MatchSummary.fromJson(json);
    expect(m.matchId, 7654321);
    expect(m.isWin, true); // Radiant slot + radiant_win=true
    expect(m.duration, 2400);
  });

  test('MatchSummary: dire player + radiant_win=true → loss', () {
    final json = {
      'match_id': 1,
      'player_slot': 128,
      'radiant_win': true,
      'duration': 1000,
      'hero_id': 1,
      'kills': 0,
      'deaths': 0,
      'assists': 0,
      'start_time': 1,
    };
    expect(MatchSummary.fromJson(json).isWin, false);
  });

  test('Match.fromJson parses full match with players', () {
    final json = {
      'match_id': 1,
      'radiant_win': true,
      'duration': 2000,
      'game_mode': 22,
      'lobby_type': 7,
      'start_time': 1,
      'radiant_score': 30,
      'dire_score': 20,
      'players': <Map<String, dynamic>>[],
    };
    final m = Match.fromJson(json);
    expect(m.matchId, 1);
    expect(m.radiantWin, true);
    expect(m.players, isEmpty);
  });
}
```

- [ ] **Step 2: Реализовать**

Создать `lib/data/models/match.dart`:
```dart
import 'package:equatable/equatable.dart';
import 'match_player.dart';

/// Краткая сводка матча (для списка истории)
class MatchSummary extends Equatable {
  final int matchId;
  final int playerSlot;
  final bool radiantWin;
  final int duration;
  final int gameMode;
  final int lobbyType;
  final int heroId;
  final int kills;
  final int deaths;
  final int assists;
  final int startTime;

  const MatchSummary({
    required this.matchId,
    required this.playerSlot,
    required this.radiantWin,
    required this.duration,
    required this.gameMode,
    required this.lobbyType,
    required this.heroId,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.startTime,
  });

  bool get isPlayerRadiant => playerSlot < 128;
  bool get isWin => isPlayerRadiant == radiantWin;

  factory MatchSummary.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    return MatchSummary(
      matchId: n('match_id'),
      playerSlot: n('player_slot'),
      radiantWin: json['radiant_win'] as bool? ?? false,
      duration: n('duration'),
      gameMode: n('game_mode'),
      lobbyType: n('lobby_type'),
      heroId: n('hero_id'),
      kills: n('kills'),
      deaths: n('deaths'),
      assists: n('assists'),
      startTime: n('start_time'),
    );
  }

  @override
  List<Object?> get props => [
        matchId,
        playerSlot,
        radiantWin,
        duration,
        gameMode,
        lobbyType,
        heroId,
        kills,
        deaths,
        assists,
        startTime,
      ];
}

/// Полные данные матча (для экрана деталей)
class Match extends Equatable {
  final int matchId;
  final bool radiantWin;
  final int duration;
  final int gameMode;
  final int lobbyType;
  final int startTime;
  final int radiantScore;
  final int direScore;
  final List<MatchPlayer> players;

  const Match({
    required this.matchId,
    required this.radiantWin,
    required this.duration,
    required this.gameMode,
    required this.lobbyType,
    required this.startTime,
    required this.radiantScore,
    required this.direScore,
    required this.players,
  });

  List<MatchPlayer> get radiantPlayers =>
      players.where((p) => p.isRadiant).toList();
  List<MatchPlayer> get direPlayers =>
      players.where((p) => !p.isRadiant).toList();

  factory Match.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    final rawPlayers = (json['players'] as List?) ?? [];
    return Match(
      matchId: n('match_id'),
      radiantWin: json['radiant_win'] as bool? ?? false,
      duration: n('duration'),
      gameMode: n('game_mode'),
      lobbyType: n('lobby_type'),
      startTime: n('start_time'),
      radiantScore: n('radiant_score'),
      direScore: n('dire_score'),
      players: rawPlayers
          .map((e) => MatchPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        matchId,
        radiantWin,
        duration,
        gameMode,
        lobbyType,
        startTime,
        radiantScore,
        direScore,
        players,
      ];
}
```

- [ ] **Step 3: Тест проходит**

Run: `flutter test test/unit/models/match_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/match.dart test/unit/models/match_test.dart
git commit -m "feat(models): add Match and MatchSummary models"
```

---

### Task 6.7: Модели Hero и Item (справочники)

**Files:**
- Create: `lib/data/models/hero.dart`
- Create: `lib/data/models/item.dart`
- Test: `test/unit/models/hero_test.dart`

- [ ] **Step 1: Написать тест для Hero**

Создать `test/unit/models/hero_test.dart`:
```dart
import 'package:dota_stats/data/models/hero.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hero.fromConstantsJson parses one hero', () {
    final entry = {
      'id': 14,
      'name': 'npc_dota_hero_pudge',
      'localized_name': 'Pudge',
      'primary_attr': 'str',
      'attack_type': 'Melee',
      'roles': ['Disabler', 'Initiator', 'Durable', 'Nuker'],
    };
    final h = Hero.fromConstantsJson(entry);
    expect(h.id, 14);
    expect(h.localizedName, 'Pudge');
    expect(h.primaryAttr, 'str');
  });
}
```

- [ ] **Step 2: Реализовать Hero**

Создать `lib/data/models/hero.dart`:
```dart
import 'package:equatable/equatable.dart';

class Hero extends Equatable {
  final int id;
  final String name;          // npc_dota_hero_pudge
  final String localizedName; // Pudge
  final String primaryAttr;   // str / agi / int / all
  final String attackType;
  final List<String> roles;

  const Hero({
    required this.id,
    required this.name,
    required this.localizedName,
    required this.primaryAttr,
    required this.attackType,
    required this.roles,
  });

  factory Hero.fromConstantsJson(Map<String, dynamic> json) {
    return Hero(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      localizedName: json['localized_name'] as String? ?? '',
      primaryAttr: json['primary_attr'] as String? ?? '',
      attackType: json['attack_type'] as String? ?? '',
      roles: ((json['roles'] as List?) ?? []).cast<String>(),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, localizedName, primaryAttr, attackType, roles];
}
```

- [ ] **Step 3: Реализовать Item**

Создать `lib/data/models/item.dart`:
```dart
import 'package:equatable/equatable.dart';

class Item extends Equatable {
  final int id;
  final String name;          // item_blade_mail (без префикса item_)
  final String displayName;
  final String? description;
  final int? cost;
  final List<int>? components; // ID предметов рецепта

  const Item({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    this.cost,
    this.components,
  });

  factory Item.fromConstantsEntry(String key, Map<String, dynamic> json) {
    return Item(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: key,
      displayName: (json['dname'] as String?) ?? key,
      description: json['notes'] as String? ?? json['desc'] as String?,
      cost: (json['cost'] as num?)?.toInt(),
      components: (json['components'] as List?)?.cast<int>(),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, displayName, description, cost, components];
}
```

- [ ] **Step 4: Запустить тесты**

Run: `flutter test test/unit/models/`
Expected: PASS все.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/hero.dart lib/data/models/item.dart test/unit/models/hero_test.dart
git commit -m "feat(models): add Hero and Item models for constants endpoints"
```

---

## Этап 7: Источники данных (API-клиенты)

### Task 7.1: OpenDotaApi

**Files:**
- Create: `lib/data/datasources/opendota_api.dart`
- Test: `test/unit/datasources/opendota_api_test.dart`

- [ ] **Step 1: Написать тест с моком Dio**

Создать `test/unit/datasources/opendota_api_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:dota_stats/core/network/api_exception.dart';
import 'package:dota_stats/data/datasources/opendota_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late OpenDotaApi api;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    dio = _MockDio();
    api = OpenDotaApi(dio);
  });

  test('getPlayer returns parsed Player on 200', () async {
    when(() => dio.get<dynamic>(any())).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'profile': {
            'account_id': 22202,
            'personaname': 'Jas9228',
            'avatarfull': '',
            'profileurl': '',
          },
          'rank_tier': 55,
        },
      ),
    );

    final p = await api.getPlayer(22202);
    expect(p.accountId, 22202);
    expect(p.name, 'Jas9228');
  });

  test('getPlayer throws NotFoundException on 404', () async {
    when(() => dio.get<dynamic>(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
        ),
      ),
    );

    expect(() => api.getPlayer(1), throwsA(isA<NotFoundException>()));
  });

  test('getRecentMatches returns list of summaries', () async {
    when(() => dio.get<dynamic>(any())).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: [
          {
            'match_id': 1,
            'player_slot': 0,
            'radiant_win': true,
            'duration': 1000,
            'game_mode': 22,
            'lobby_type': 7,
            'hero_id': 14,
            'kills': 5,
            'deaths': 3,
            'assists': 10,
            'start_time': 1715000000,
          }
        ],
      ),
    );

    final list = await api.getRecentMatches(22202);
    expect(list, hasLength(1));
    expect(list.first.matchId, 1);
    expect(list.first.isWin, true);
  });
}
```

- [ ] **Step 2: Реализовать**

Создать `lib/data/datasources/opendota_api.dart`:
```dart
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';
import '../models/hero.dart';
import '../models/item.dart';
import '../models/match.dart';
import '../models/player.dart';

class OpenDotaApi {
  final Dio _dio;
  OpenDotaApi(this._dio);

  Future<T> _safe<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<Player> getPlayer(int accountId) => _safe(() async {
        final res = await _dio.get<dynamic>(ApiEndpoints.player(accountId));
        return Player.fromOpenDotaJson(res.data as Map<String, dynamic>);
      });

  Future<({int wins, int losses})> getWinLoss(int accountId) => _safe(() async {
        final res = await _dio.get<dynamic>(ApiEndpoints.playerWinLoss(accountId));
        final m = res.data as Map<String, dynamic>;
        return (
          wins: (m['win'] as num?)?.toInt() ?? 0,
          losses: (m['lose'] as num?)?.toInt() ?? 0,
        );
      });

  /// Топ героев игрока: список карт с полями hero_id, games, win.
  Future<List<Map<String, dynamic>>> getPlayerHeroes(int accountId) =>
      _safe(() async {
        final res = await _dio.get<dynamic>(
          ApiEndpoints.playerHeroes(accountId),
        );
        return (res.data as List).cast<Map<String, dynamic>>();
      });

  Future<List<MatchSummary>> getRecentMatches(int accountId) => _safe(() async {
        final res = await _dio.get<dynamic>(
          ApiEndpoints.playerRecentMatches(accountId),
        );
        return (res.data as List)
            .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Полная история матчей с пагинацией: limit + offset.
  Future<List<MatchSummary>> getMatches(
    int accountId, {
    int limit = 20,
    int offset = 0,
  }) =>
      _safe(() async {
        final res = await _dio.get<dynamic>(
          ApiEndpoints.playerMatches(accountId),
          queryParameters: {'limit': limit, 'offset': offset},
        );
        return (res.data as List)
            .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<Match> getMatch(int matchId) => _safe(() async {
        final res = await _dio.get<dynamic>(ApiEndpoints.match(matchId));
        return Match.fromJson(res.data as Map<String, dynamic>);
      });

  /// Поиск игроков по нику. Возвращает список карт {account_id, personaname, avatarfull, similarity}.
  Future<List<Map<String, dynamic>>> searchPlayers(String query) =>
      _safe(() async {
        final res = await _dio.get<dynamic>(ApiEndpoints.searchPlayers(query));
        return (res.data as List).cast<Map<String, dynamic>>();
      });

  Future<Map<String, Hero>> getHeroesConstants() => _safe(() async {
        final res = await _dio.get<dynamic>(ApiEndpoints.heroesConstants);
        final m = res.data as Map<String, dynamic>;
        final out = <String, Hero>{};
        for (final entry in m.entries) {
          final h = Hero.fromConstantsJson(entry.value as Map<String, dynamic>);
          out[h.id.toString()] = h;
        }
        return out;
      });

  Future<Map<String, Item>> getItemsConstants() => _safe(() async {
        final res = await _dio.get<dynamic>(ApiEndpoints.itemsConstants);
        final m = res.data as Map<String, dynamic>;
        final out = <String, Item>{};
        for (final entry in m.entries) {
          final item = Item.fromConstantsEntry(
            entry.key,
            entry.value as Map<String, dynamic>,
          );
          out[item.id.toString()] = item;
        }
        return out;
      });
}
```

- [ ] **Step 3: Тесты проходят**

Run: `flutter test test/unit/datasources/opendota_api_test.dart`
Expected: PASS все 3 теста.

- [ ] **Step 4: Commit**

```bash
git add lib/data/datasources/opendota_api.dart test/unit/datasources/opendota_api_test.dart
git commit -m "feat(data): add OpenDotaApi client with player, matches, constants"
```

---

### Task 7.2: SteamApi

**Files:**
- Create: `lib/data/datasources/steam_api.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/data/datasources/steam_api.dart`:
```dart
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class SteamProfile {
  final String steamId64;
  final String name;
  final String avatarUrl;
  final int? personaState; // 0 offline, 1 online, etc.
  final String profileUrl;

  const SteamProfile({
    required this.steamId64,
    required this.name,
    required this.avatarUrl,
    required this.profileUrl,
    this.personaState,
  });

  factory SteamProfile.fromJson(Map<String, dynamic> json) {
    return SteamProfile(
      steamId64: json['steamid'] as String? ?? '',
      name: json['personaname'] as String? ?? 'Unknown',
      avatarUrl: json['avatarfull'] as String? ?? '',
      profileUrl: json['profileurl'] as String? ?? '',
      personaState: (json['personastate'] as num?)?.toInt(),
    );
  }
}

class SteamApi {
  final Dio _dio;
  final String? Function() _getApiKey;

  SteamApi(this._dio, this._getApiKey);

  Future<T> _safe<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  /// Резолвит vanity-имя (например, 'Jas9228') в SteamID64. Требует ключ.
  Future<String?> resolveVanityUrl(String vanity) async {
    final key = _getApiKey();
    if (key == null) {
      throw const UnknownApiException('Steam API key not set');
    }
    return _safe(() async {
      final res = await _dio
          .get<dynamic>(ApiEndpoints.steamResolveVanity(key, vanity));
      final response = (res.data as Map<String, dynamic>)['response']
          as Map<String, dynamic>;
      if (response['success'] != 1) return null;
      return response['steamid'] as String?;
    });
  }

  /// Получает профили для одной или нескольких SteamID64 (через запятую).
  Future<List<SteamProfile>> getPlayerSummaries(List<String> steamIds64) async {
    final key = _getApiKey();
    if (key == null) {
      throw const UnknownApiException('Steam API key not set');
    }
    return _safe(() async {
      final res = await _dio.get<dynamic>(
        ApiEndpoints.steamSummaries(key, steamIds64.join(',')),
      );
      final players = ((res.data as Map<String, dynamic>)['response']
              as Map<String, dynamic>)['players'] as List;
      return players
          .map((e) => SteamProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/data/datasources/steam_api.dart
git commit -m "feat(data): add SteamApi for vanity resolve and profile summaries"
```

---

### Task 7.3: StratzApi (заглушка для MVP)

**Files:**
- Create: `lib/data/datasources/stratz_api.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/data/datasources/stratz_api.dart`:
```dart
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

/// Минимальная обёртка над Stratz GraphQL.
/// В MVP используется только для определения позиции/роли игрока в матче.
/// Полноценное использование — в следующих версиях.
class StratzApi {
  final Dio _dio;
  final String? Function() _getApiKey;

  StratzApi(this._dio, this._getApiKey);

  bool get isAvailable => _getApiKey() != null;

  /// Возвращает позиции игроков в матче (POSITION_1..POSITION_5)
  /// в виде map: accountId -> position string. Если ключа нет — пустая map.
  Future<Map<int, String>> getMatchPositions(int matchId) async {
    final key = _getApiKey();
    if (key == null) return {};

    const query = r'''
      query Match($id: Long!) {
        match(id: $id) {
          players {
            steamAccountId
            position
          }
        }
      }
    ''';

    try {
      final res = await _dio.post<dynamic>(
        ApiEndpoints.stratzBase,
        options: Options(
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'query': query,
          'variables': {'id': matchId},
        },
      );
      final data = (res.data as Map<String, dynamic>)['data']
          as Map<String, dynamic>?;
      final match = data?['match'] as Map<String, dynamic>?;
      final players = (match?['players'] as List?) ?? [];
      final out = <int, String>{};
      for (final raw in players) {
        final p = raw as Map<String, dynamic>;
        final id = (p['steamAccountId'] as num?)?.toInt();
        final pos = p['position'] as String?;
        if (id != null && pos != null) out[id] = pos;
      }
      return out;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/data/datasources/stratz_api.dart
git commit -m "feat(data): add minimal StratzApi for match positions"
```

---

## Этап 8: Репозитории (с кэшем)

### Task 8.1: PlayerRepository

**Files:**
- Create: `lib/data/repositories/player_repository.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/data/repositories/player_repository.dart`:
```dart
import '../../core/storage/cache_storage.dart';
import '../datasources/opendota_api.dart';
import '../datasources/steam_api.dart';
import '../models/player.dart';
import '../models/rank.dart';

class PlayerProfile {
  final Player player;
  final Rank rank;
  final int wins;
  final int losses;
  final SteamProfile? steam; // null если ключа Steam нет

  const PlayerProfile({
    required this.player,
    required this.rank,
    required this.wins,
    required this.losses,
    this.steam,
  });

  int get totalGames => wins + losses;
  double get winRate => totalGames == 0 ? 0 : wins / totalGames;
}

class PlayerRepository {
  final OpenDotaApi _openDota;
  final SteamApi _steam;
  final CacheStorage _cache;

  PlayerRepository({
    required OpenDotaApi openDota,
    required SteamApi steam,
    required CacheStorage cache,
  })  : _openDota = openDota,
        _steam = steam,
        _cache = cache;

  Future<PlayerProfile> getProfile(int accountId,
      {bool forceRefresh = false}) async {
    final cacheKey = 'profile_$accountId';
    if (!forceRefresh) {
      final cached = _cache.get(cacheKey);
      if (cached != null) {
        return _deserializeProfile(cached);
      }
    }

    final player = await _openDota.getPlayer(accountId);
    final wl = await _openDota.getWinLoss(accountId);
    SteamProfile? steam;
    try {
      final id64 = (76561197960265728 + accountId).toString();
      final list = await _steam.getPlayerSummaries([id64]);
      if (list.isNotEmpty) steam = list.first;
    } catch (_) {
      steam = null; // ключ не задан или Steam-API недоступен — пропускаем
    }

    final profile = PlayerProfile(
      player: player,
      rank: Rank.fromTier(player.rankTier,
          leaderboardRank: player.leaderboardRank),
      wins: wl.wins,
      losses: wl.losses,
      steam: steam,
    );

    await _cache.set(
      cacheKey,
      _serializeProfile(profile),
      ttl: const Duration(minutes: 5),
    );
    return profile;
  }

  Future<List<Map<String, dynamic>>> getTopHeroes(int accountId,
      {int limit = 5}) async {
    final all = await _openDota.getPlayerHeroes(accountId);
    return all.take(limit).toList();
  }

  /// Резолв любого пользовательского ввода (vanity, ID, ссылка) → accountId.
  /// Возвращает null, если резолвить нельзя.
  Future<int?> resolveAccountId(String input) async {
    // Сначала проверяем явный SteamID64 в URL /profiles/<digits>
    // или vanity-имя. Конвертацию голых чисел делает SteamIdConverter в UI слое
    // до вызова репозитория.
    return null; // используется только для vanity (см. AuthBloc)
  }

  Map<String, dynamic> _serializeProfile(PlayerProfile p) => {
        'player': {
          'accountId': p.player.accountId,
          'name': p.player.name,
          'avatarUrl': p.player.avatarUrl,
          'profileUrl': p.player.profileUrl,
          'rankTier': p.player.rankTier,
          'leaderboardRank': p.player.leaderboardRank,
        },
        'wins': p.wins,
        'losses': p.losses,
        'steam': p.steam == null
            ? null
            : {
                'steamId64': p.steam!.steamId64,
                'name': p.steam!.name,
                'avatarUrl': p.steam!.avatarUrl,
                'profileUrl': p.steam!.profileUrl,
                'personaState': p.steam!.personaState,
              },
      };

  PlayerProfile _deserializeProfile(Map<String, dynamic> raw) {
    final pl = raw['player'] as Map<String, dynamic>;
    final player = Player(
      accountId: pl['accountId'] as int,
      name: pl['name'] as String,
      avatarUrl: pl['avatarUrl'] as String,
      profileUrl: pl['profileUrl'] as String,
      rankTier: pl['rankTier'] as int?,
      leaderboardRank: pl['leaderboardRank'] as int?,
    );
    final steamRaw = raw['steam'] as Map<String, dynamic>?;
    return PlayerProfile(
      player: player,
      rank: Rank.fromTier(player.rankTier,
          leaderboardRank: player.leaderboardRank),
      wins: raw['wins'] as int,
      losses: raw['losses'] as int,
      steam: steamRaw == null
          ? null
          : SteamProfile(
              steamId64: steamRaw['steamId64'] as String,
              name: steamRaw['name'] as String,
              avatarUrl: steamRaw['avatarUrl'] as String,
              profileUrl: steamRaw['profileUrl'] as String,
              personaState: steamRaw['personaState'] as int?,
            ),
    );
  }
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/player_repository.dart
git commit -m "feat(data): add PlayerRepository with profile aggregation and cache"
```

---

### Task 8.2: MatchRepository

**Files:**
- Create: `lib/data/repositories/match_repository.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/data/repositories/match_repository.dart`:
```dart
import '../../core/storage/cache_storage.dart';
import '../datasources/opendota_api.dart';
import '../models/match.dart';

class MatchRepository {
  final OpenDotaApi _api;
  final CacheStorage _cache;

  MatchRepository({required OpenDotaApi api, required CacheStorage cache})
      : _api = api,
        _cache = cache;

  Future<List<MatchSummary>> getRecentMatches(int accountId,
      {bool forceRefresh = false}) async {
    final key = 'recent_matches_$accountId';
    if (!forceRefresh) {
      final cached = _cache.get(key);
      if (cached != null) {
        final list = (cached['matches'] as List).cast<Map<String, dynamic>>();
        return list.map(MatchSummary.fromJson).toList();
      }
    }
    final matches = await _api.getRecentMatches(accountId);
    await _cache.set(
      key,
      {'matches': matches.map(_summaryToJson).toList()},
      ttl: const Duration(minutes: 2),
    );
    return matches;
  }

  Future<List<MatchSummary>> getMatches(
    int accountId, {
    int limit = 20,
    int offset = 0,
  }) =>
      _api.getMatches(accountId, limit: limit, offset: offset);

  /// Подробности матча кэшируются навсегда — завершённый матч не меняется.
  Future<Match> getMatch(int matchId) async {
    final key = 'match_$matchId';
    final cached = _cache.get(key);
    if (cached != null) {
      return Match.fromJson(cached);
    }
    final match = await _api.getMatch(matchId);
    await _cache.set(key, _matchToJson(match));
    return match;
  }

  Map<String, dynamic> _summaryToJson(MatchSummary m) => {
        'match_id': m.matchId,
        'player_slot': m.playerSlot,
        'radiant_win': m.radiantWin,
        'duration': m.duration,
        'game_mode': m.gameMode,
        'lobby_type': m.lobbyType,
        'hero_id': m.heroId,
        'kills': m.kills,
        'deaths': m.deaths,
        'assists': m.assists,
        'start_time': m.startTime,
      };

  Map<String, dynamic> _matchToJson(Match m) => {
        'match_id': m.matchId,
        'radiant_win': m.radiantWin,
        'duration': m.duration,
        'game_mode': m.gameMode,
        'lobby_type': m.lobbyType,
        'start_time': m.startTime,
        'radiant_score': m.radiantScore,
        'dire_score': m.direScore,
        'players': m.players
            .map((p) => {
                  'account_id': p.accountId,
                  'personaname': p.name,
                  'hero_id': p.heroId,
                  'player_slot': p.playerSlot,
                  'kills': p.kills,
                  'deaths': p.deaths,
                  'assists': p.assists,
                  'level': p.level,
                  'gold_per_min': p.gpm,
                  'xp_per_min': p.xpm,
                  'hero_damage': p.heroDamage,
                  'hero_healing': p.heroHealing,
                  'last_hits': p.lastHits,
                  'denies': p.denies,
                  for (var i = 0; i < 6; i++) 'item_$i': p.items[i],
                  for (var i = 0; i < 3; i++) 'backpack_$i': p.backpack[i],
                  'item_neutral': p.neutralItem,
                })
            .toList(),
      };
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/match_repository.dart
git commit -m "feat(data): add MatchRepository with permanent match cache"
```

---

### Task 8.3: ConstantsRepository (герои + предметы)

**Files:**
- Create: `lib/data/repositories/constants_repository.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/data/repositories/constants_repository.dart`:
```dart
import '../../core/storage/cache_storage.dart';
import '../datasources/opendota_api.dart';
import '../models/hero.dart';
import '../models/item.dart';

class ConstantsRepository {
  final OpenDotaApi _api;
  final CacheStorage _cache;

  Map<int, Hero>? _heroesById;
  Map<int, Item>? _itemsById;

  ConstantsRepository({required OpenDotaApi api, required CacheStorage cache})
      : _api = api,
        _cache = cache;

  Future<Map<int, Hero>> getHeroes() async {
    if (_heroesById != null) return _heroesById!;
    const key = 'heroes_constants';
    final cached = _cache.get(key);
    if (cached != null) {
      _heroesById = _decodeHeroes(cached);
      return _heroesById!;
    }
    final fromApi = await _api.getHeroesConstants();
    final byId = {for (final h in fromApi.values) h.id: h};
    _heroesById = byId;
    await _cache.set(
      key,
      {'heroes': fromApi.values.map(_encodeHero).toList()},
      ttl: const Duration(days: 7),
    );
    return byId;
  }

  Future<Map<int, Item>> getItems() async {
    if (_itemsById != null) return _itemsById!;
    const key = 'items_constants';
    final cached = _cache.get(key);
    if (cached != null) {
      _itemsById = _decodeItems(cached);
      return _itemsById!;
    }
    final fromApi = await _api.getItemsConstants();
    final byId = {for (final i in fromApi.values) i.id: i};
    _itemsById = byId;
    await _cache.set(
      key,
      {'items': fromApi.values.map(_encodeItem).toList()},
      ttl: const Duration(days: 7),
    );
    return byId;
  }

  Hero? heroById(int id) => _heroesById?[id];
  Item? itemById(int id) => _itemsById?[id];

  Map<String, dynamic> _encodeHero(Hero h) => {
        'id': h.id,
        'name': h.name,
        'localized_name': h.localizedName,
        'primary_attr': h.primaryAttr,
        'attack_type': h.attackType,
        'roles': h.roles,
      };

  Map<int, Hero> _decodeHeroes(Map<String, dynamic> raw) {
    final list = (raw['heroes'] as List).cast<Map<String, dynamic>>();
    return {for (final j in list) (j['id'] as num).toInt(): Hero.fromConstantsJson(j)};
  }

  Map<String, dynamic> _encodeItem(Item i) => {
        'id': i.id,
        'name': i.name,
        'dname': i.displayName,
        'notes': i.description,
        'cost': i.cost,
        'components': i.components,
      };

  Map<int, Item> _decodeItems(Map<String, dynamic> raw) {
    final list = (raw['items'] as List).cast<Map<String, dynamic>>();
    return {
      for (final j in list)
        (j['id'] as num).toInt(): Item.fromConstantsEntry(j['name'] as String, j),
    };
  }
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/constants_repository.dart
git commit -m "feat(data): add ConstantsRepository for heroes and items lookup"
```

---

## Этап 9: Точка входа приложения (main + app + router)

### Task 9.1: AuthCubit (текущий пользователь)

**Files:**
- Create: `lib/presentation/blocs/auth/auth_cubit.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/presentation/blocs/auth/auth_cubit.dart`:
```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/storage/secure_storage.dart';

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class Authenticated extends AuthState {
  final int accountId;
  const Authenticated(this.accountId);
  @override
  List<Object?> get props => [accountId];
}

class AuthCubit extends Cubit<AuthState> {
  final SecureStorage _storage;

  AuthCubit(this._storage) : super(const AuthLoading()) {
    _load();
  }

  Future<void> _load() async {
    final id = await _storage.getCurrentAccountId();
    if (id == null) {
      emit(const Unauthenticated());
    } else {
      emit(Authenticated(id));
    }
  }

  Future<void> setAccountId(int accountId) async {
    await _storage.setCurrentAccountId(accountId);
    emit(Authenticated(accountId));
  }

  Future<void> logOut() async {
    await _storage.clearAccount();
    emit(const Unauthenticated());
  }
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/blocs/auth/auth_cubit.dart
git commit -m "feat(auth): add AuthCubit with persisted current accountId"
```

---

### Task 9.2: AppRouter (GoRouter)

**Files:**
- Create: `lib/core/router/app_router.dart`

- [ ] **Step 1: Реализовать (с заглушками экранов)**

Создать `lib/core/router/app_router.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/blocs/auth/auth_cubit.dart';

/// Заглушки экранов — заменим на реальные в этапе 11.
class _Stub extends StatelessWidget {
  final String label;
  const _Stub(this.label);
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

class AppRouter {
  static GoRouter create(AuthCubit authCubit) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authCubit.stream),
      redirect: (context, state) {
        final auth = authCubit.state;
        final loc = state.matchedLocation;
        if (auth is AuthLoading) return null;
        final isOnboarding = loc == '/onboarding';
        if (auth is Unauthenticated && !isOnboarding) return '/onboarding';
        if (auth is Authenticated && isOnboarding) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const _Stub('Onboarding'),
        ),
        ShellRoute(
          builder: (context, state, child) => _MainShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const _Stub('Profile'),
              routes: [
                GoRoute(
                  path: 'matches',
                  builder: (_, __) => const _Stub('Match history'),
                ),
                GoRoute(
                  path: 'match/:id',
                  builder: (ctx, st) =>
                      _Stub('Match ${st.pathParameters['id']}'),
                ),
                GoRoute(
                  path: 'player/:id',
                  builder: (ctx, st) =>
                      _Stub('Player ${st.pathParameters['id']}'),
                ),
              ],
            ),
            GoRoute(
              path: '/search',
              builder: (_, __) => const _Stub('Search'),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, __) => const _Stub('Settings'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  static const _tabs = ['/', '/search', '/settings'];

  int _indexFor(String location) {
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _indexFor(loc);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => context.go(_tabs[i]),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

/// Адаптер: Stream → Listenable, чтобы GoRouter подписался на смену AuthState.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final dynamic _sub;

  @override
  void dispose() {
    (_sub as dynamic).cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues (могут быть warnings про неиспользуемые поля — это нормально).

- [ ] **Step 3: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(router): add GoRouter with auth redirect and bottom nav shell"
```

---

### Task 9.3: app.dart (MaterialApp + BLoC providers)

**Files:**
- Create: `lib/app.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/router/app_router.dart';
import 'core/storage/cache_storage.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/opendota_api.dart';
import 'data/datasources/steam_api.dart';
import 'data/datasources/stratz_api.dart';
import 'data/repositories/constants_repository.dart';
import 'data/repositories/match_repository.dart';
import 'data/repositories/player_repository.dart';
import 'l10n/app_localizations.dart';
import 'presentation/blocs/auth/auth_cubit.dart';
import 'presentation/blocs/locale/locale_cubit.dart';
import 'presentation/blocs/theme/theme_cubit.dart';

class DotaStatsApp extends StatefulWidget {
  final SecureStorage secureStorage;
  final CacheStorage cacheStorage;
  final OpenDotaApi openDotaApi;
  final SteamApi steamApi;
  final StratzApi stratzApi;

  const DotaStatsApp({
    super.key,
    required this.secureStorage,
    required this.cacheStorage,
    required this.openDotaApi,
    required this.steamApi,
    required this.stratzApi,
  });

  @override
  State<DotaStatsApp> createState() => _DotaStatsAppState();
}

class _DotaStatsAppState extends State<DotaStatsApp> {
  late final AuthCubit _authCubit;
  late final ThemeCubit _themeCubit;
  late final LocaleCubit _localeCubit;
  late final PlayerRepository _playerRepo;
  late final MatchRepository _matchRepo;
  late final ConstantsRepository _constantsRepo;
  late final dynamic _router;

  @override
  void initState() {
    super.initState();
    _authCubit = AuthCubit(widget.secureStorage);
    _themeCubit = ThemeCubit();
    _localeCubit = LocaleCubit();
    _playerRepo = PlayerRepository(
      openDota: widget.openDotaApi,
      steam: widget.steamApi,
      cache: widget.cacheStorage,
    );
    _matchRepo = MatchRepository(
      api: widget.openDotaApi,
      cache: widget.cacheStorage,
    );
    _constantsRepo = ConstantsRepository(
      api: widget.openDotaApi,
      cache: widget.cacheStorage,
    );
    _router = AppRouter.create(_authCubit);
  }

  @override
  void dispose() {
    _authCubit.close();
    _themeCubit.close();
    _localeCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.secureStorage),
        RepositoryProvider.value(value: widget.cacheStorage),
        RepositoryProvider.value(value: widget.openDotaApi),
        RepositoryProvider.value(value: widget.steamApi),
        RepositoryProvider.value(value: widget.stratzApi),
        RepositoryProvider.value(value: _playerRepo),
        RepositoryProvider.value(value: _matchRepo),
        RepositoryProvider.value(value: _constantsRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authCubit),
          BlocProvider.value(value: _themeCubit),
          BlocProvider.value(value: _localeCubit),
        ],
        child: BlocBuilder<ThemeCubit, AppThemeMode>(
          builder: (context, themeMode) {
            return BlocBuilder<LocaleCubit, AppLocale>(
              builder: (context, localeMode) {
                return MaterialApp.router(
                  title: 'Dota Stats',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light(),
                  darkTheme: AppTheme.amoled(),
                  themeMode: switch (themeMode) {
                    AppThemeMode.light => ThemeMode.light,
                    AppThemeMode.amoled => ThemeMode.dark,
                    AppThemeMode.system => ThemeMode.system,
                  },
                  locale: switch (localeMode) {
                    AppLocale.ru => const Locale('ru'),
                    AppLocale.en => const Locale('en'),
                    AppLocale.system => null,
                  },
                  supportedLocales: const [Locale('ru'), Locale('en')],
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                  ],
                  routerConfig: _router,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Проверить**

Run: `flutter analyze`
Expected: 0 issues. Если ошибка про `app_localizations.dart` — выполнить `flutter gen-l10n`.

- [ ] **Step 3: Commit**

```bash
git add lib/app.dart
git commit -m "feat(app): wire DotaStatsApp with providers, themes, locales, router"
```

---

### Task 9.4: main.dart (точка входа + инициализация)

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Заменить содержимое main.dart**

Перезаписать `lib/main.dart`:
```dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/dio_client.dart';
import 'core/storage/cache_storage.dart';
import 'core/storage/secure_storage.dart';
import 'data/datasources/opendota_api.dart';
import 'data/datasources/steam_api.dart';
import 'data/datasources/stratz_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cacheStorage = CacheStorage();
  await cacheStorage.init();

  final secureStorage = SecureStorage();

  // Один Dio на приложение — common settings, общий retry.
  final dio = DioClient.create();

  final openDotaApi = OpenDotaApi(dio);
  final steamApi = SteamApi(dio, secureStorage.getSteamApiKey as dynamic);
  final stratzApi = StratzApi(dio, secureStorage.getStratzApiKey as dynamic);

  // SteamApi ожидает sync getter String? Function(). У нас — Future<String?>.
  // Вместо async getter в API будем кэшировать ключи в памяти после старта.
  final steamKey = await secureStorage.getSteamApiKey();
  final stratzKey = await secureStorage.getStratzApiKey();
  final keyHolder = _ApiKeyHolder(steam: steamKey, stratz: stratzKey);

  runApp(DotaStatsApp(
    secureStorage: secureStorage,
    cacheStorage: cacheStorage,
    openDotaApi: openDotaApi,
    steamApi: SteamApi(dio, () => keyHolder.steam),
    stratzApi: StratzApi(dio, () => keyHolder.stratz),
  ));
}

class _ApiKeyHolder {
  String? steam;
  String? stratz;
  _ApiKeyHolder({this.steam, this.stratz});
}
```

> **Примечание:** _ApiKeyHolder — простой in-memory кэш ключей. Когда пользователь меняет ключи в Settings, нужно обновлять этот объект (это сделаем в Task 11.6).

- [ ] **Step 2: Проверить компиляцию**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 3: Запустить на телефоне**

Run: `flutter run`
Expected: приложение запускается, открывается экран-заглушка `Onboarding` (т.к. accountId не сохранён). Нижняя навигация ещё не видна — это правильно для онбординга.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(app): initialize storage, Dio, APIs in main and run app"
```

---

## Этап 10: Переиспользуемые виджеты

### Task 10.1: SkeletonLoader

**Files:**
- Create: `lib/presentation/widgets/skeleton_loader.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/presentation/widgets/skeleton_loader.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              palette.divider,
              palette.surface,
              _ctrl.value,
            ),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/skeleton_loader.dart
git commit -m "feat(widgets): add SkeletonLoader with shimmer animation"
```

---

### Task 10.2: StatCard

**Files:**
- Create: `lib/presentation/widgets/stat_card.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/presentation/widgets/stat_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.caption(palette.textSecondary)),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.statBold(
                valueColor ?? palette.textPrimary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Widget-тест**

Создать `test/widget/stat_card_test.dart`:
```dart
import 'package:dota_stats/core/theme/app_theme.dart';
import 'package:dota_stats/presentation/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StatCard shows label and value', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.amoled(),
      home: const Scaffold(
        body: StatCard(label: 'Win rate', value: '57%'),
      ),
    ));
    expect(find.text('Win rate'), findsOneWidget);
    expect(find.text('57%'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Запустить тест**

Run: `flutter test test/widget/stat_card_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/stat_card.dart test/widget/stat_card_test.dart
git commit -m "feat(widgets): add StatCard component"
```

---

### Task 10.3: HeroAvatar

**Files:**
- Create: `lib/presentation/widgets/hero_avatar.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/presentation/widgets/hero_avatar.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/theme/app_theme.dart';

enum HeroAvatarSize { small, medium, large }

class HeroAvatar extends StatelessWidget {
  final String? heroName; // npc_dota_hero_pudge
  final bool? isRadiant;  // null → нейтральная рамка
  final HeroAvatarSize size;

  const HeroAvatar({
    super.key,
    required this.heroName,
    this.isRadiant,
    this.size = HeroAvatarSize.medium,
  });

  double get _size => switch (size) {
        HeroAvatarSize.small => 32,
        HeroAvatarSize.medium => 48,
        HeroAvatarSize.large => 72,
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final borderColor = isRadiant == null
        ? palette.divider
        : (isRadiant! ? palette.win : palette.lose);

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 2),
        color: palette.divider,
      ),
      clipBehavior: Clip.antiAlias,
      child: heroName == null
          ? Icon(Icons.help_outline, color: palette.textSecondary)
          : Image.network(
              ApiEndpoints.heroIcon(heroName!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.broken_image, color: palette.textSecondary),
            ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/hero_avatar.dart
git commit -m "feat(widgets): add HeroAvatar with team-colored border"
```

---

### Task 10.4: ItemSlot

**Files:**
- Create: `lib/presentation/widgets/item_slot.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/presentation/widgets/item_slot.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/item.dart';

class ItemSlot extends StatelessWidget {
  final Item? item; // null → пустой слот
  final double size;

  const ItemSlot({super.key, required this.item, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: item == null ? null : () => _showDetails(context, item!),
      child: Container(
        width: size,
        height: size * 0.75, // соотношение как в Dota
        decoration: BoxDecoration(
          color: palette.divider,
          border: Border.all(color: palette.divider, width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        clipBehavior: Clip.antiAlias,
        child: item == null
            ? null
            : Image.network(
                ApiEndpoints.itemIcon(item!.name),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.help_outline, size: 12, color: palette.textSecondary),
              ),
      ),
    );
  }

  void _showDetails(BuildContext context, Item item) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.displayName,
                style: AppTextStyles.heading2(palette.textPrimary)),
            const SizedBox(height: 8),
            if (item.cost != null)
              Text('Cost: ${item.cost}',
                  style: AppTextStyles.body(palette.accent)),
            const SizedBox(height: 8),
            if (item.description != null)
              Text(item.description!,
                  style: AppTextStyles.body(palette.textSecondary)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/item_slot.dart
git commit -m "feat(widgets): add ItemSlot with bottom sheet for item details"
```

---

### Task 10.5: RankMedal

**Files:**
- Create: `lib/presentation/widgets/rank_medal.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/presentation/widgets/rank_medal.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/rank.dart';

class RankMedal extends StatelessWidget {
  final Rank rank;
  final double size;

  const RankMedal({super.key, required this.rank, this.size = 56});

  Color _color() => switch (rank.tier) {
        RankTier.uncalibrated => const Color(0xFF4A4A4A),
        RankTier.herald => AppColors.rankHerald,
        RankTier.guardian => AppColors.rankGuardian,
        RankTier.crusader => AppColors.rankCrusader,
        RankTier.archon => AppColors.rankArchon,
        RankTier.legend => AppColors.rankLegend,
        RankTier.ancient => AppColors.rankAncient,
        RankTier.divine => AppColors.rankDivine,
        RankTier.immortal => AppColors.rankImmortal,
      };

  String _label() {
    if (rank.tier == RankTier.uncalibrated) return '–';
    if (rank.tier == RankTier.immortal) {
      return rank.leaderboardRank != null
          ? '#${rank.leaderboardRank}'
          : 'Immortal';
    }
    final tier = rank.tier.name[0].toUpperCase() + rank.tier.name.substring(1);
    return '$tier ${rank.stars}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Icon(Icons.shield, color: color, size: size * 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(_label(),
            style: AppTextStyles.caption(palette.textSecondary)),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/rank_medal.dart
git commit -m "feat(widgets): add RankMedal with tier color and stars"
```

---

### Task 10.6: MatchTile

**Files:**
- Create: `lib/presentation/widgets/match_tile.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/presentation/widgets/match_tile.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/hero.dart' as dota;
import '../../data/models/match.dart';
import 'hero_avatar.dart';

class MatchTile extends StatelessWidget {
  final MatchSummary match;
  final dota.Hero? hero;
  final VoidCallback? onTap;

  const MatchTile({
    super.key,
    required this.match,
    required this.hero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = match.isWin ? palette.win : palette.lose;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              HeroAvatar(
                heroName: hero?.name,
                isRadiant: match.isPlayerRadiant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hero?.localizedName ?? 'Hero ${match.heroId}',
                        style: AppTextStyles.heading2(palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.kda(match.kills, match.deaths, match.assists),
                      style: AppTextStyles.stat(palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(match.isWin ? 'WIN' : 'LOSS',
                      style: AppTextStyles.statBold(color, size: 14)),
                  const SizedBox(height: 2),
                  Text(Formatters.duration(match.duration),
                      style: AppTextStyles.caption(palette.textSecondary)),
                  Text(Formatters.relativeTime(match.startTime),
                      style: AppTextStyles.caption(palette.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/match_tile.dart
git commit -m "feat(widgets): add MatchTile for match list rows"
```

---

### Task 10.7: SectionHeader

**Files:**
- Create: `lib/presentation/widgets/section_header.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/presentation/widgets/section_header.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: palette.accent),
          const SizedBox(width: 8),
          Text(title,
              style: AppTextStyles.heading2(palette.textPrimary)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/section_header.dart
git commit -m "feat(widgets): add SectionHeader with gold accent stripe"
```

---

## Этап 11: Экраны и BLoC-и

### Task 11.1: Экран онбординга

**Files:**
- Create: `lib/presentation/screens/onboarding/onboarding_screen.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/presentation/screens/onboarding/onboarding_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/steam_id_converter.dart';
import '../../../data/datasources/steam_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/auth/auth_cubit.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Голое число или /profiles/<digits> — конвертируем напрямую.
      final fromDigits = SteamIdConverter.parseAccountId(input) ??
          (SteamIdConverter.extractSteamId64(input) != null
              ? SteamIdConverter.to32(SteamIdConverter.extractSteamId64(input)!)
              : null);
      if (fromDigits != null) {
        await context.read<AuthCubit>().setAccountId(fromDigits);
        return;
      }

      // 2) Vanity-имя — нужен Steam API ключ.
      final vanity = SteamIdConverter.extractVanity(input);
      if (vanity == null) {
        setState(() => _error = 'Invalid input');
        return;
      }
      final steamApi = context.read<SteamApi>();
      final id64 = await steamApi.resolveVanityUrl(vanity);
      if (id64 == null) {
        setState(() => _error = 'Vanity not resolved');
        return;
      }
      final accountId = SteamIdConverter.to32(int.parse(id64));
      await context.read<AuthCubit>().setAccountId(accountId);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),
              Text(l10n.onboardingWelcome,
                  style: AppTextStyles.heading1(palette.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: l10n.onboardingEnterIdHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: AppTextStyles.body(palette.lose)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.onboardingContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Подключить в роутере**

В `lib/core/router/app_router.dart` заменить `_Stub('Onboarding')` на `const OnboardingScreen()`. Добавить импорт.

- [ ] **Step 3: Запустить и протестировать**

Run: `flutter run`
Ввести в поле: `https://steamcommunity.com/id/Jas9228/`.
Expected: если Steam-ключ задан — резолвится в accountId, переходим на главный экран. Если нет — ошибка «Steam API key not set» (это нормально, сейчас исправим в Settings).

Альтернатива для теста без ключа: можно ввести голое число `22202` (любой публичный 32-bit accountId) — должно сразу пройти.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/onboarding/ lib/core/router/app_router.dart
git commit -m "feat(onboarding): add ID/URL input screen with Steam vanity resolve"
```

---

### Task 11.2: ProfileBloc + Profile screen

**Files:**
- Create: `lib/presentation/blocs/profile/profile_cubit.dart`
- Create: `lib/presentation/screens/profile/profile_screen.dart`

- [ ] **Step 1: ProfileCubit**

Создать `lib/presentation/blocs/profile/profile_cubit.dart`:
```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/match_repository.dart';
import '../../../data/repositories/player_repository.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final PlayerProfile profile;
  final List<Map<String, dynamic>> topHeroes;
  final List<MatchSummary> recentMatches;

  const ProfileLoaded({
    required this.profile,
    required this.topHeroes,
    required this.recentMatches,
  });

  @override
  List<Object?> get props => [profile, topHeroes, recentMatches];
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
  @override
  List<Object?> get props => [message];
}

class ProfileCubit extends Cubit<ProfileState> {
  final PlayerRepository _playerRepo;
  final MatchRepository _matchRepo;

  ProfileCubit({
    required PlayerRepository playerRepo,
    required MatchRepository matchRepo,
  })  : _playerRepo = playerRepo,
        _matchRepo = matchRepo,
        super(const ProfileLoading());

  Future<void> load(int accountId, {bool refresh = false}) async {
    emit(const ProfileLoading());
    try {
      final profile =
          await _playerRepo.getProfile(accountId, forceRefresh: refresh);
      final top = await _playerRepo.getTopHeroes(accountId);
      final recent = await _matchRepo.getRecentMatches(accountId,
          forceRefresh: refresh);
      emit(ProfileLoaded(
        profile: profile,
        topHeroes: top,
        recentMatches: recent.take(10).toList(),
      ));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
```

- [ ] **Step 2: ProfileScreen**

Создать `lib/presentation/screens/profile/profile_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/constants_repository.dart';
import '../../../data/repositories/match_repository.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/profile/profile_cubit.dart';
import '../../widgets/hero_avatar.dart';
import '../../widgets/match_tile.dart';
import '../../widgets/rank_medal.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/stat_card.dart';

class ProfileScreen extends StatelessWidget {
  final int? accountIdOverride; // null → текущий пользователь
  const ProfileScreen({super.key, this.accountIdOverride});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) {
        final cubit = ProfileCubit(
          playerRepo: ctx.read<PlayerRepository>(),
          matchRepo: ctx.read<MatchRepository>(),
        );
        final id = accountIdOverride ??
            (ctx.read<AuthCubit>().state as Authenticated).accountId;
        cubit.load(id);
        return cubit;
      },
      child: _ProfileView(accountIdOverride: accountIdOverride),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final int? accountIdOverride;
  const _ProfileView({this.accountIdOverride});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.palette;
    final isOwn = accountIdOverride == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabProfile),
        actions: isOwn
            ? [
                IconButton(
                  icon: const Icon(LucideIcons.settings),
                  onPressed: () => context.go('/settings'),
                ),
              ]
            : null,
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          return switch (state) {
            ProfileLoading() => const _ProfileSkeleton(),
            ProfileError(:final message) => _ErrorView(
                message: message,
                onRetry: () {
                  final id = accountIdOverride ??
                      (context.read<AuthCubit>().state as Authenticated)
                          .accountId;
                  context.read<ProfileCubit>().load(id, refresh: true);
                },
              ),
            ProfileLoaded() => RefreshIndicator(
                onRefresh: () async {
                  final id = accountIdOverride ??
                      (context.read<AuthCubit>().state as Authenticated)
                          .accountId;
                  await context
                      .read<ProfileCubit>()
                      .load(id, refresh: true);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Header(state: state),
                    const SizedBox(height: 16),
                    _StatsRow(state: state),
                    SectionHeader(title: l10n.profileFavoriteHeroes),
                    _TopHeroes(state: state),
                    SectionHeader(
                      title: l10n.profileRecentMatches,
                      trailing: TextButton(
                        onPressed: () => context.go('/matches'),
                        child: Text(l10n.profileShowAll),
                      ),
                    ),
                    _RecentMatches(state: state),
                  ],
                ),
              ),
          };
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ProfileLoaded state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = state.profile;
    return Row(
      children: [
        ClipOval(
          child: Image.network(
            p.steam?.avatarUrl.isNotEmpty == true
                ? p.steam!.avatarUrl
                : p.player.avatarUrl,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.person, size: 72, color: palette.textSecondary),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.steam?.name ?? p.player.name,
                  style: AppTextStyles.heading1(palette.textPrimary)),
              Text('ID ${p.player.accountId}',
                  style: AppTextStyles.caption(palette.textSecondary)),
            ],
          ),
        ),
        RankMedal(rank: p.rank),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ProfileLoaded state;
  const _StatsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = state.profile;
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: l10n.profileWinRate,
            value: '${(p.winRate * 100).toStringAsFixed(1)}%',
            valueColor: palette.accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: l10n.profileTotalGames,
            value: Formatters.number(p.totalGames),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: '${l10n.profileWins} / ${l10n.profileLosses}',
            value: '${p.wins} / ${p.losses}',
          ),
        ),
      ],
    );
  }
}

class _TopHeroes extends StatelessWidget {
  final ProfileLoaded state;
  const _TopHeroes({required this.state});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FutureBuilder(
      future: context.read<ConstantsRepository>().getHeroes(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return SkeletonLoader(width: double.infinity, height: 56);
        }
        final heroes = snap.data!;
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.topHeroes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final raw = state.topHeroes[i];
              final hero = heroes[(raw['hero_id'] as num).toInt()];
              final games = (raw['games'] as num).toInt();
              final wins = (raw['win'] as num).toInt();
              final wr = games == 0 ? 0 : (wins / games * 100);
              return Column(
                children: [
                  HeroAvatar(heroName: hero?.name, size: HeroAvatarSize.large),
                  const SizedBox(height: 4),
                  Text('$games · ${wr.toStringAsFixed(0)}%',
                      style: AppTextStyles.caption(palette.textSecondary)),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _RecentMatches extends StatelessWidget {
  final ProfileLoaded state;
  const _RecentMatches({required this.state});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<ConstantsRepository>().getHeroes(),
      builder: (ctx, snap) {
        final heroes = snap.data;
        return Column(
          children: [
            for (final m in state.recentMatches)
              MatchTile(
                match: m,
                hero: heroes?[m.heroId],
                onTap: () => context.go('/match/${m.matchId}'),
              ),
          ],
        );
      },
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const SkeletonLoader(width: 72, height: 72),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(width: 160, height: 24),
                SizedBox(height: 8),
                SkeletonLoader(width: 100, height: 14),
              ],
            )),
          ],
        ),
        const SizedBox(height: 24),
        for (int i = 0; i < 5; i++) ...[
          const SkeletonLoader(width: double.infinity, height: 64),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: palette.lose, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(palette.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Подключить в роутере**

В `lib/core/router/app_router.dart`:
- Заменить `_Stub('Profile')` на `const ProfileScreen()`
- Заменить `_Stub('Player ${st.pathParameters['id']}')` на:
  ```dart
  ProfileScreen(accountIdOverride: int.parse(st.pathParameters['id']!))
  ```
- Добавить импорт.

- [ ] **Step 4: Запустить и проверить**

Run: `flutter run`
Expected: после ввода твоего accountId на онбординге → главный экран показывает аватар, ник, медаль, винрейт, любимых героев, последние матчи. Тап на матч ведёт на заглушку Match.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/blocs/profile/ lib/presentation/screens/profile/ lib/core/router/app_router.dart
git commit -m "feat(profile): add ProfileCubit and ProfileScreen with full layout"
```

---

### Task 11.3: MatchHistory screen

**Files:**
- Create: `lib/presentation/blocs/matches/matches_cubit.dart`
- Create: `lib/presentation/screens/match_history/match_history_screen.dart`

- [ ] **Step 1: MatchesCubit с пагинацией**

Создать `lib/presentation/blocs/matches/matches_cubit.dart`:
```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/match_repository.dart';

class MatchesState extends Equatable {
  final List<MatchSummary> matches;
  final bool loading;
  final bool reachedEnd;
  final String? error;

  const MatchesState({
    this.matches = const [],
    this.loading = false,
    this.reachedEnd = false,
    this.error,
  });

  MatchesState copyWith({
    List<MatchSummary>? matches,
    bool? loading,
    bool? reachedEnd,
    String? error,
  }) =>
      MatchesState(
        matches: matches ?? this.matches,
        loading: loading ?? this.loading,
        reachedEnd: reachedEnd ?? this.reachedEnd,
        error: error,
      );

  @override
  List<Object?> get props => [matches, loading, reachedEnd, error];
}

class MatchesCubit extends Cubit<MatchesState> {
  final MatchRepository _repo;
  final int accountId;
  static const _pageSize = 20;

  MatchesCubit({required MatchRepository repo, required this.accountId})
      : _repo = repo,
        super(const MatchesState());

  Future<void> loadMore() async {
    if (state.loading || state.reachedEnd) return;
    emit(state.copyWith(loading: true, error: null));
    try {
      final next = await _repo.getMatches(
        accountId,
        limit: _pageSize,
        offset: state.matches.length,
      );
      emit(state.copyWith(
        matches: [...state.matches, ...next],
        loading: false,
        reachedEnd: next.length < _pageSize,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}
```

- [ ] **Step 2: MatchHistoryScreen**

Создать `lib/presentation/screens/match_history/match_history_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/constants_repository.dart';
import '../../../data/repositories/match_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/matches/matches_cubit.dart';
import '../../widgets/match_tile.dart';
import '../../widgets/skeleton_loader.dart';

class MatchHistoryScreen extends StatelessWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthCubit>().state as Authenticated;
    return BlocProvider(
      create: (ctx) => MatchesCubit(
        repo: ctx.read<MatchRepository>(),
        accountId: auth.accountId,
      )..loadMore(),
      child: const _MatchHistoryView(),
    );
  }
}

class _MatchHistoryView extends StatefulWidget {
  const _MatchHistoryView();
  @override
  State<_MatchHistoryView> createState() => _MatchHistoryViewState();
}

class _MatchHistoryViewState extends State<_MatchHistoryView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 200) {
        context.read<MatchesCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matchesTitle)),
      body: FutureBuilder(
        future: context.read<ConstantsRepository>().getHeroes(),
        builder: (ctx, heroSnap) {
          final heroes = heroSnap.data;
          return BlocBuilder<MatchesCubit, MatchesState>(
            builder: (context, state) {
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: state.matches.length + (state.loading ? 3 : 0),
                itemBuilder: (_, i) {
                  if (i >= state.matches.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: SkeletonLoader(width: double.infinity, height: 64),
                    );
                  }
                  final m = state.matches[i];
                  return MatchTile(
                    match: m,
                    hero: heroes?[m.heroId],
                    onTap: () => context.go('/match/${m.matchId}'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: Подключить в роутере**

Заменить `_Stub('Match history')` на `const MatchHistoryScreen()`.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/blocs/matches/ lib/presentation/screens/match_history/ lib/core/router/app_router.dart
git commit -m "feat(matches): add MatchesCubit and MatchHistoryScreen with pagination"
```

---

### Task 11.4: MatchDetails screen

**Files:**
- Create: `lib/presentation/blocs/match_details/match_details_cubit.dart`
- Create: `lib/presentation/screens/match_details/match_details_screen.dart`
- Create: `lib/presentation/widgets/player_row.dart`

- [ ] **Step 1: PlayerRow виджет**

Создать `lib/presentation/widgets/player_row.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/hero.dart' as dota;
import '../../data/models/item.dart';
import '../../data/models/match_player.dart';
import 'hero_avatar.dart';
import 'item_slot.dart';

class PlayerRow extends StatelessWidget {
  final MatchPlayer player;
  final dota.Hero? hero;
  final Map<int, Item> itemsById;

  const PlayerRow({
    super.key,
    required this.player,
    required this.hero,
    required this.itemsById,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: player.accountId == null
          ? null
          : () => context.go('/player/${player.accountId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            HeroAvatar(
              heroName: hero?.name,
              isRadiant: player.isRadiant,
              size: HeroAvatarSize.small,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(palette.textPrimary)),
                  Text('Lv ${player.level}',
                      style: AppTextStyles.caption(palette.textSecondary)),
                ],
              ),
            ),
            Expanded(
              child: Text(
                Formatters.kda(player.kills, player.deaths, player.assists),
                style: AppTextStyles.stat(palette.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text('${player.gpm}',
                      style: AppTextStyles.stat(palette.accent)),
                  Text('${player.xpm}',
                      style: AppTextStyles.caption(palette.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                for (final id in player.items)
                  ItemSlot(item: id == 0 ? null : itemsById[id]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: MatchDetailsCubit**

Создать `lib/presentation/blocs/match_details/match_details_cubit.dart`:
```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/match_repository.dart';

sealed class MatchDetailsState extends Equatable {
  const MatchDetailsState();
  @override
  List<Object?> get props => [];
}

class MatchDetailsLoading extends MatchDetailsState {
  const MatchDetailsLoading();
}

class MatchDetailsLoaded extends MatchDetailsState {
  final Match match;
  const MatchDetailsLoaded(this.match);
  @override
  List<Object?> get props => [match];
}

class MatchDetailsError extends MatchDetailsState {
  final String message;
  const MatchDetailsError(this.message);
  @override
  List<Object?> get props => [message];
}

class MatchDetailsCubit extends Cubit<MatchDetailsState> {
  final MatchRepository _repo;
  MatchDetailsCubit(this._repo) : super(const MatchDetailsLoading());

  Future<void> load(int matchId) async {
    emit(const MatchDetailsLoading());
    try {
      emit(MatchDetailsLoaded(await _repo.getMatch(matchId)));
    } catch (e) {
      emit(MatchDetailsError(e.toString()));
    }
  }
}
```

- [ ] **Step 3: MatchDetailsScreen**

Создать `lib/presentation/screens/match_details/match_details_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/constants_repository.dart';
import '../../../data/repositories/match_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/match_details/match_details_cubit.dart';
import '../../widgets/player_row.dart';

class MatchDetailsScreen extends StatelessWidget {
  final int matchId;
  const MatchDetailsScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          MatchDetailsCubit(ctx.read<MatchRepository>())..load(matchId),
      child: const _MatchDetailsView(),
    );
  }
}

class _MatchDetailsView extends StatelessWidget {
  const _MatchDetailsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match')),
      body: BlocBuilder<MatchDetailsCubit, MatchDetailsState>(
        builder: (context, state) => switch (state) {
          MatchDetailsLoading() =>
            const Center(child: CircularProgressIndicator()),
          MatchDetailsError(:final message) =>
            Center(child: Text(message)),
          MatchDetailsLoaded(:final match) => _Body(match: match),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Match match;
  const _Body({required this.match});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder(
      future: Future.wait([
        context.read<ConstantsRepository>().getHeroes(),
        context.read<ConstantsRepository>().getItems(),
      ]),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final heroes = snap.data![0] as Map;
        final items = snap.data![1] as Map;
        return ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${match.radiantScore} : ${match.direScore}',
                    style: AppTextStyles.heading1(palette.textPrimary),
                  ),
                  Text(
                    '${Formatters.duration(match.duration)} · #${match.matchId}',
                    style: AppTextStyles.caption(palette.textSecondary),
                  ),
                ],
              ),
            ),
            _TeamHeader(label: l10n.matchDetailsRadiant, color: palette.win),
            for (final p in match.radiantPlayers)
              PlayerRow(
                player: p,
                hero: heroes[p.heroId],
                itemsById: items.cast(),
              ),
            _TeamHeader(label: l10n.matchDetailsDire, color: palette.lose),
            for (final p in match.direPlayers)
              PlayerRow(
                player: p,
                hero: heroes[p.heroId],
                itemsById: items.cast(),
              ),
          ],
        );
      },
    );
  }
}

class _TeamHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _TeamHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Text(label,
          style: AppTextStyles.heading2(color)),
    );
  }
}
```

- [ ] **Step 4: Подключить в роутере**

Заменить `_Stub('Match ${st.pathParameters['id']}')` на:
```dart
MatchDetailsScreen(matchId: int.parse(st.pathParameters['id']!))
```

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/blocs/match_details/ lib/presentation/screens/match_details/ lib/presentation/widgets/player_row.dart lib/core/router/app_router.dart
git commit -m "feat(match): add MatchDetailsScreen with both teams and items"
```

---

### Task 11.5: Search screen

**Files:**
- Create: `lib/presentation/blocs/search/search_cubit.dart`
- Create: `lib/presentation/screens/search/search_screen.dart`

- [ ] **Step 1: SearchCubit**

Создать `lib/presentation/blocs/search/search_cubit.dart`:
```dart
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/opendota_api.dart';

class SearchResult extends Equatable {
  final int accountId;
  final String name;
  final String avatarUrl;

  const SearchResult({
    required this.accountId,
    required this.name,
    required this.avatarUrl,
  });

  @override
  List<Object?> get props => [accountId, name];
}

class SearchState extends Equatable {
  final List<SearchResult> results;
  final bool loading;
  final String? error;

  const SearchState({
    this.results = const [],
    this.loading = false,
    this.error,
  });

  @override
  List<Object?> get props => [results, loading, error];
}

class SearchCubit extends Cubit<SearchState> {
  final OpenDotaApi _api;
  Timer? _debounce;

  SearchCubit(this._api) : super(const SearchState());

  void onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      emit(const SearchState());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String q) async {
    emit(SearchState(loading: true, results: state.results));
    try {
      final raw = await _api.searchPlayers(q);
      emit(SearchState(
        results: raw
            .map((m) => SearchResult(
                  accountId: (m['account_id'] as num).toInt(),
                  name: m['personaname'] as String? ?? 'Unknown',
                  avatarUrl: m['avatarfull'] as String? ?? '',
                ))
            .toList(),
      ));
    } catch (e) {
      emit(SearchState(error: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 2: SearchScreen**

Создать `lib/presentation/screens/search/search_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/opendota_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/search/search_cubit.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => SearchCubit(ctx.read<OpenDotaApi>()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatelessWidget {
  const _SearchView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: context.read<SearchCubit>().onQueryChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (_, state) {
                  if (state.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.error != null) {
                    return Center(
                        child: Text(state.error!,
                            style: AppTextStyles.body(palette.lose)));
                  }
                  return ListView.separated(
                    itemCount: state.results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = state.results[i];
                      return ListTile(
                        leading: r.avatarUrl.isEmpty
                            ? const Icon(Icons.person)
                            : CircleAvatar(
                                backgroundImage: NetworkImage(r.avatarUrl)),
                        title: Text(r.name),
                        subtitle: Text('ID ${r.accountId}'),
                        onTap: () => context.go('/player/${r.accountId}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Подключить в роутере**

Заменить `_Stub('Search')` на `const SearchScreen()`.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/blocs/search/ lib/presentation/screens/search/ lib/core/router/app_router.dart
git commit -m "feat(search): add SearchScreen with debounced player search"
```

---

### Task 11.6: Settings screen

**Files:**
- Create: `lib/presentation/screens/settings/settings_screen.dart`

- [ ] **Step 1: Реализовать**

Создать `lib/presentation/screens/settings/settings_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/locale/locale_cubit.dart';
import '../../blocs/theme/theme_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(text: l10n.settingsTheme),
          BlocBuilder<ThemeCubit, AppThemeMode>(
            builder: (_, mode) => Column(
              children: [
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.light,
                  groupValue: mode,
                  title: Text(l10n.themeLight),
                  onChanged: (v) =>
                      context.read<ThemeCubit>().setMode(v!),
                ),
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.amoled,
                  groupValue: mode,
                  title: Text(l10n.themeAmoled),
                  onChanged: (v) =>
                      context.read<ThemeCubit>().setMode(v!),
                ),
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.system,
                  groupValue: mode,
                  title: Text(l10n.themeSystem),
                  onChanged: (v) =>
                      context.read<ThemeCubit>().setMode(v!),
                ),
              ],
            ),
          ),
          _SectionHeader(text: l10n.settingsLanguage),
          BlocBuilder<LocaleCubit, AppLocale>(
            builder: (_, locale) => Column(
              children: [
                RadioListTile<AppLocale>(
                  value: AppLocale.ru,
                  groupValue: locale,
                  title: Text(l10n.languageRu),
                  onChanged: (v) =>
                      context.read<LocaleCubit>().setLocale(v!),
                ),
                RadioListTile<AppLocale>(
                  value: AppLocale.en,
                  groupValue: locale,
                  title: Text(l10n.languageEn),
                  onChanged: (v) =>
                      context.read<LocaleCubit>().setLocale(v!),
                ),
                RadioListTile<AppLocale>(
                  value: AppLocale.system,
                  groupValue: locale,
                  title: Text(l10n.languageSystem),
                  onChanged: (v) =>
                      context.read<LocaleCubit>().setLocale(v!),
                ),
              ],
            ),
          ),
          _SectionHeader(text: l10n.settingsApiKeys),
          ListTile(
            title: const Text('Steam Web API key'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editKey(context, isSteam: true),
          ),
          ListTile(
            title: const Text('Stratz API key'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editKey(context, isSteam: false),
          ),
          _SectionHeader(text: l10n.settingsAccount),
          ListTile(
            title: Text(l10n.settingsLogOut,
                style: AppTextStyles.body(palette.lose)),
            onTap: () => context.read<AuthCubit>().logOut(),
          ),
        ],
      ),
    );
  }

  Future<void> _editKey(BuildContext context, {required bool isSteam}) async {
    final storage = context.read<SecureStorage>();
    final current = isSteam
        ? await storage.getSteamApiKey()
        : await storage.getStratzApiKey();
    final controller = TextEditingController(text: current ?? '');
    if (!context.mounted) return;
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isSteam ? 'Steam API key' : 'Stratz API key'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    if (saved.isEmpty) {
      if (isSteam) {
        await storage.deleteSteamApiKey();
      } else {
        await storage.deleteStratzApiKey();
      }
    } else {
      if (isSteam) {
        await storage.setSteamApiKey(saved);
      } else {
        await storage.setStratzApiKey(saved);
      }
    }
    // Применение изменений к работающему API-клиенту требует перезапуска
    // приложения (in-memory кэш ключей в main.dart). Покажем уведомление.
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Key saved. Restart the app to apply.'),
    ));
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text,
          style: AppTextStyles.caption(palette.accent)),
    );
  }
}
```

- [ ] **Step 2: Подключить в роутере**

Заменить `_Stub('Settings')` на `const SettingsScreen()`.

- [ ] **Step 3: Запустить и проверить**

Run: `flutter run`
Проверить:
- Переключение темы Light/AMOLED работает мгновенно.
- Переключение языка RU/EN работает.
- Ввод API ключей сохраняется (после рестарта приложения подхватываются).
- «Выйти» возвращает на онбординг.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/settings/ lib/core/router/app_router.dart
git commit -m "feat(settings): add SettingsScreen with theme, locale, API keys, logout"
```

---

## Этап 12: Логотип, иконка, splash, README

### Task 12.1: SVG-логотип «DS»

**Files:**
- Create: `c:\dev\dota_stats\assets\icon\logo.svg`

- [ ] **Step 1: Создать SVG**

Создать `assets/icon/logo.svg`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" fill="#0D0D0D"/>
  <!-- Скрещенные клинки сверху -->
  <g stroke="#C8AA6E" stroke-width="14" stroke-linecap="round" fill="none">
    <path d="M 110 130 L 256 70 L 402 130"/>
    <path d="M 130 80 L 180 160"/>
    <path d="M 382 80 L 332 160"/>
  </g>
  <!-- Монограмма DS -->
  <text x="256" y="360"
        font-family="Georgia, serif"
        font-weight="900"
        font-size="200"
        fill="#C8AA6E"
        text-anchor="middle"
        letter-spacing="-8">DS</text>
  <!-- Нижняя золотая полоса -->
  <rect x="80" y="430" width="352" height="6" fill="#C8AA6E"/>
</svg>
```

- [ ] **Step 2: Конвертировать в PNG для иконки приложения**

Лучший способ: открыть SVG в любом онлайн-конвертере (например, https://cloudconvert.com/svg-to-png), экспортировать в PNG 1024×1024, сохранить как `assets/icon/app_icon.png`.

Альтернатива (если есть Inkscape):
```bash
inkscape assets/icon/logo.svg --export-type=png --export-filename=assets/icon/app_icon.png -w 1024 -h 1024
```

- [ ] **Step 3: Настроить flutter_launcher_icons**

В `pubspec.yaml` добавить в самом конце:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#0D0D0D"
  adaptive_icon_foreground: "assets/icon/app_icon.png"
  remove_alpha_ios: true
```

- [ ] **Step 4: Сгенерировать иконки**

Run:
```bash
flutter pub get
dart run flutter_launcher_icons
```

Expected: иконки сгенерированы для Android (`android/app/src/main/res/mipmap-*`) и iOS (`ios/Runner/Assets.xcassets/AppIcon.appiconset/`).

- [ ] **Step 5: Commit**

```bash
git add assets/icon/ pubspec.yaml android/app/src/main/res/ ios/Runner/Assets.xcassets/
git commit -m "feat(icon): add DS SVG logo and generate launcher icons"
```

---

### Task 12.2: Splash screen

**Files:**
- Modify: `pubspec.yaml`
- Create config через flutter_native_splash (опционально, можно вручную)

- [ ] **Step 1: Подключить flutter_native_splash**

В `dev_dependencies:` добавить:
```yaml
  flutter_native_splash: ^2.4.3
```

В `pubspec.yaml` (в корне) добавить секцию:
```yaml
flutter_native_splash:
  color: "#0D0D0D"
  image: assets/icon/app_icon.png
  android_12:
    color: "#0D0D0D"
    image: assets/icon/app_icon.png
```

- [ ] **Step 2: Сгенерировать**

Run:
```bash
flutter pub get
dart run flutter_native_splash:create
```

Expected: splash настроен для Android и iOS.

- [ ] **Step 3: Запустить и убедиться**

Run: `flutter run`
Expected: при старте видно тёмный сплеш с логотипом DS.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml android/app/src/main/res/drawable* ios/Runner/Assets.xcassets/LaunchImage.imageset/ ios/Runner/Base.lproj/LaunchScreen.storyboard
git commit -m "feat(splash): configure native splash with DS logo"
```

---

### Task 12.3: Permissions для интернета

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Android — добавить INTERNET permission**

В `android/app/src/main/AndroidManifest.xml` перед тегом `<application ...>` добавить:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

- [ ] **Step 2: iOS — Info.plist уже разрешает HTTPS**

Все наши API используют HTTPS — никаких NSAppTransportSecurity исключений не нужно. Шаг проверочный.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "chore(android): add INTERNET permission"
```

---

### Task 12.4: Финальное обновление README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Обновить README**

Заменить содержимое `README.md`:
```markdown
# Dota Stats (DS)

Mobile app for Dota 2 statistics and match history. Android + iOS, Flutter.

## Features (MVP)

- View own profile: rank medal, win rate, total games, favorite heroes
- Match history with pagination
- Detailed match view: both teams, KDA, GPM/XPM, damage, healing, last hits, items
- Search any player by nickname or Steam ID
- Two themes: Light and AMOLED (pure black for OLED)
- Two languages: Russian and English

## Quick start

Requirements: Flutter 3.x, Android device or iPhone.

```bash
flutter pub get
flutter run
```

## API keys (optional, but recommended)

The app works without keys (limited mode — no high-res Steam avatars, no vanity URL resolve, no Stratz position data).

For full features:

1. **Steam Web API key** — free at https://steamcommunity.com/dev/apikey
   - Enables: vanity URL resolve (`steamcommunity.com/id/<name>/`), real Steam avatars and online status
2. **Stratz API key** — register via Steam at https://stratz.com → Profile → API
   - Enables: precise player positions in match details

Enter keys in app: **Settings → API keys**, then restart the app.

## Architecture

- **Flutter + flutter_bloc** for state management
- **Dio** for HTTP with retry interceptor
- **Hive** for cache (matches: forever, profile: 5 min, recent matches: 2 min, constants: 7 days)
- **flutter_secure_storage** for API keys (Keychain/Keystore)
- **GoRouter** for navigation

```
lib/
├── core/          # constants, theme, network, storage, router, utils
├── data/          # models, datasources (OpenDota/Steam/Stratz), repositories
├── presentation/  # blocs, screens, widgets
└── l10n/          # RU/EN translations
```

## Data sources

- **OpenDota API** — main source (no key required)
- **Steam Web API** — profile metadata (key required)
- **Stratz API** — extended analytics (key required, minimal use in MVP)

## Building for release

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS (requires macOS + Xcode)
```bash
flutter build ipa --release
```

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README with MVP features and architecture"
```

---

### Task 12.5: Финальный прогон тестов и анализатора

- [ ] **Step 1: Прогнать все тесты**

Run: `flutter test`
Expected: все тесты PASS.

- [ ] **Step 2: Прогнать анализатор**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Финальная сборка release-APK для проверки**

Run: `flutter build apk --release`
Expected: APK создан в `build/app/outputs/flutter-apk/app-release.apk`.

Установить на Android-телефон (через USB или передать файл) и проверить, что приложение запускается без debug-режима.

- [ ] **Step 4: Финальный коммит-тэг**

```bash
git tag v0.1.0-mvp -m "MVP release: core profile, matches, search, settings"
```

---

## Self-Review (для исполнителя плана)

После выполнения всех задач — проверить:

1. **Spec coverage:** все 12 разделов спеки покрыты задачами:
   - 1 (Обзор) → Task 12.4 (README)
   - 2 (Стек) → Task 1.1
   - 3 (Источники данных) → Этап 7
   - 4 (Экраны) → Этап 11
   - 5 (Дизайн) → Этап 2 + Этап 10 + Task 12.1
   - 6 (Аутентификация) → Task 11.1 (онбординг с ID + vanity)
   - 7 (Локализация) → Этап 3
   - 8 (Структура папок) → Task 1.2 + поэтапное создание
   - 9 (Тестирование) → unit-тесты в каждой задаче, widget-тесты в 10.2
   - 10 (Этапы реализации) → весь план
   - 11 (На будущее) → не входит в план (post-MVP)
   - 12 (Целевое расположение) → Task 0.1

2. **Не реализовано (специально, по решению из брейншторма):**
   - Steam OpenID-вход (отложен до v1.1)
   - Полные справочники героев/предметов как отдельный экран
   - Графики по минутам
   - Push-уведомления

3. **Запуск на устройстве:** перед финальным коммитом — установить release-APK на свой Android-телефон, ввести `https://steamcommunity.com/id/Jas9228/` (или числовой accountId), проверить, что профиль грузится, последние матчи отображаются, тап на матч открывает детали с обеими командами.

---

## Готово!

Полный план занимает 12 этапов и около 50 задач TDD-стиля. После прохождения всех задач:
- В `c:\dev\dota_stats\` лежит работающее MVP-приложение Dota Stats для Android и iOS.
- Тесты проходят, анализатор чист.
- Профиль, история матчей, детали матча, поиск, настройки, две темы и два языка работают.
- Логотип DS, иконка приложения, splash настроены.
- README описывает запуск и получение API-ключей.

Дальнейшие версии (v1.1, v1.2, v2.0) — см. раздел 11 спеки.
