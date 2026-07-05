# Contribuer à TheNews

Merci de ton intérêt ! TheNews est une app SwiftUI macOS + iOS **sans dépendance externe** et
**100 % on-device** — garde ces deux principes en tête pour toute contribution.

## Démarrer

```bash
brew install xcodegen
xcodegen generate
open TheNews.xcodeproj
```

- Scheme **TheNews** → macOS · scheme **TheNewsiOS** → iOS/iPadOS.
- Le `.xcodeproj` est généré par XcodeGen ; ne le versionne pas. Modifie la config dans `project.yml`.

## Principes de conception

- **Zéro dépendance externe** : uniquement les frameworks Apple (SwiftData, XMLParser,
  UserNotifications, BackgroundTasks, WidgetKit, CloudKit).
- **Sans serveur, sans télémétrie** : tout traitement reste sur l'appareil.
- **Agnostique de la source** : les services opèrent sur un `Feed` quelconque. Une nouvelle source =
  une `Source` + un catalogue `Feed` (voir [`ARCHITECTURE.md`](ARCHITECTURE.md) → « Ajouter une source »).
- **Codebase partagé** : une seule base pour les deux plateformes, différences via `#if os(...)`.
- **Compatibilité CloudKit** : les modèles SwiftData n'utilisent pas `@Attribute(.unique)` et donnent
  une valeur par défaut à chaque propriété. L'unicité passe par la dédup applicative des stores.

## Style

- Conventions Swift standard ; le code et les commentaires suivent le style existant (commentaires en
  français, identifiants en anglais).
- Chaîne visible par l'utilisateur → ajoute la clé dans `Localization/Strings.swift` (**fr et en**).
- Vérifie que ça compile sur **les deux** plateformes avant d'ouvrir une PR :

```bash
xcodebuild -scheme TheNews    -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme TheNewsiOS -destination 'platform=iOS Simulator,name=iPhone 15' build CODE_SIGNING_ALLOWED=NO
```

## Commits & PR

- Commits conventionnels, en anglais, au présent (`feat:`, `fix:`, `refactor:`…).
- Une PR = une intention claire ; décris le quoi et le pourquoi.

## Signaler un bug

Ouvre une issue avec la plateforme (macOS/iOS + version), les étapes de reproduction et, si possible,
le flux RSS concerné.
