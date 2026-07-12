<div align="center">

# TheNews

**Veille d'information multi-sources pour macOS & iOS — sans serveur, 100 % sur l'appareil.**

Agrège *Le Monde*, *Les Echos* et **n'importe quel flux RSS** dans une seule app, regroupe
automatiquement les articles qui parlent du même sujet, et te livre un briefing quotidien condensé.

![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20iPadOS%20%7C%20watchOS%20%7C%20tvOS-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-SwiftData%20%7C%20WidgetKit%20%7C%20CloudKit-4B9CD3)
![Dependencies](https://img.shields.io/badge/dependencies-Sparkle%20only-brightgreen)
![License](https://img.shields.io/badge/license-MIT-lightgrey)
![Release](https://img.shields.io/github/v/release/vincentlauriat/TheNews)

**[⬇️ Télécharger pour macOS](https://github.com/vincentlauriat/TheNews/releases/latest)** · signé Developer ID + notarisé

</div>

![Capture d'écran de TheNews sur macOS — sidebar groupée par source, article détaillé avec « Aussi couvert par… »](docs/screenshot.png)

---

## Pourquoi TheNews ?

La plupart des applications d'actualité te lient à **un seul média** ou envoient tes données à
**leurs serveurs**. TheNews prend le contre-pied :

- **Multi-sources** — tes journaux et tes flux, réunis dans une interface unique, groupés par source.
- **Sans serveur** — tout le traitement (parsing, veille, regroupement, résumé) se fait **sur l'appareil**.
  Aucune télémétrie, aucun compte.
- **Quasi zéro dépendance** — que du natif Apple : SwiftData, XMLParser, UserNotifications,
  BackgroundTasks, WidgetKit, CloudKit. Seule exception : [Sparkle](https://sparkle-project.org)
  pour l'auto-update macOS (hors App Store).

## Fonctionnalités inédites

| | Fonctionnalité | Ce qui la rend différente |
|---|---|---|
| 🗞️ | **Sources RSS personnalisées** | Ajoute n'importe quel flux (validé à l'ajout). Le catalogue est **dynamique** : tes sources rejoignent le tien comme un journal de plus. |
| 🔗 | **Regroupement cross-source** | En bas d'un article, « **Aussi couvert par…** » : le même événement vu par d'autres sources, détecté **on-device** (similarité de Jaccard sur les titres/chapôs). |
| ☀️ | **Briefing quotidien** | Un « résumé du jour » condensé : les sujets marquants des dernières 24 h, **doublons cross-source retirés**, avec notification à l'heure que tu choisis. |
| ✨ | **IA on-device (Apple Intelligence)** | Synthèse des grands thèmes d'une liste (longueur/format/ton configurables), **matching sémantique** des sujets de veille (capte les reformulations, pas seulement les mots-clés exacts), **résumé auto** pour les flux sans chapô, et **recherche en langage naturel**. Le tout via **Foundation Models**, 100 % sur l'appareil, avec repli automatique sans IA si indisponible. |
| 📱 | **Widget & iCloud** | Widget d'écran d'accueil (WidgetKit, 3 tailles) **sur iOS et macOS** + **sync iCloud** (CloudKit) de tes abonnements, favoris, sujets de veille et flux perso entre tes appareils. |
| ⌚ | **App Apple Watch** | App compagnon watchOS autonome : les gros titres du Monde et des Echos, chargés en direct sur ta montre. |
| 📺 | **App Apple TV** | App compagnon tvOS autonome : Briefing, Tous les articles et toutes les rubriques sur grand écran, miniatures, détail image + chapô, navigation complète à la télécommande. |
| 🌙 | **Écran de veille macOS** | Briefing éditorial en rotation, **embarqué dans l'app** — installé et mis à jour automatiquement à chaque update de TheNews, sans téléchargement séparé. |

Plus le socle classique : veille par mots-clés, alertes locales, favoris, partage natif, 3 colonnes
(rubriques · articles · détail), affichage liste ou cartes au choix, swipe entre articles sur iOS
(**mode « tous » ou « non lus »**), apparence & langue (fr/en).

## Fonctionnalités par plateforme

| Fonctionnalité | macOS | iOS/iPadOS |
|---|:---:|:---:|
| Le Monde (11 rubriques) + Les Echos (9 rubriques) + flux perso | ✅ | ✅ |
| Sidebar groupée par source · vue « Tous les articles » | ✅ | ✅ |
| Regroupement cross-source « Aussi couvert par… » | ✅ | ✅ |
| Briefing quotidien + notification programmée | ✅ | ✅ |
| Sujets de veille par mots-clés + alertes locales | ✅ | ✅ |
| **IA on-device** (synthèse, matching sémantique, résumé auto, recherche NL) | ✅ | ✅ |
| Rafraîchissement en tâche de fond | 30 min | `BGAppRefreshTask` |
| Widget d'écran d'accueil | ✅ | ✅ |
| **App compagnon Apple Watch** | — | ✅ |
| Sync iCloud (SwiftData + CloudKit) | ✅ | ✅ |
| Écran de veille (embarqué, auto-update) | ✅ | — |

> Le flux RSS ne fournit que titre, chapô et image ; l'article complet s'ouvre dans le navigateur.
> Sur macOS, la sync iCloud requiert une app signée avec App Sandbox (activés ici).

## Ajouter une source

1. **Gérer les rubriques** (icône réglages) → section **« Mes flux »** → **Ajouter un flux**.
2. Saisis un nom et l'**URL du flux RSS** (souvent en `/rss` ou `/feed`).
3. TheNews vérifie le flux (au moins un article) puis l'ajoute et l'abonne — il apparaît dans la
   sidebar sous **« Mes flux »** et alimente ta veille, ton briefing et le widget.

## Sous le capot

Application SwiftUI **à codebase unique partagé** entre macOS et iOS (`#if os(...)`). Points de design :

- **Catalogue dynamique** : `Feed.catalog = builtInCatalog + customCatalog` — les journaux fournis +
  tes flux perso (SwiftData). L'ajout d'un journal ne demande qu'une `Source` + un catalogue.
- **Services agnostiques de la source** : parsing, stockage, dédup, veille, regroupement opèrent sur
  un `Feed` quelconque.
- **On-device, sans serveur** : regroupement cross-source et briefing sont de simples algorithmes
  locaux (tokenisation normalisée + similarité de Jaccard).
- **Auto-update macOS** : [Sparkle](https://sparkle-project.org) vérifie une fois par jour
  (`« Rechercher les mises à jour… »` dans le menu app), signature EdDSA, hors App Store.

Détails et diagrammes dans [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Build

Prérequis : Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate            # génère TheNews.xcodeproj
open TheNews.xcodeproj        # macOS : scheme TheNews — iOS : scheme TheNewsiOS
```

Projet Xcode **généré** (le `.xcodeproj` n'est pas versionné). Release macOS :
`./Scripts/release.sh 1.4.1` (build → sign Developer ID → DMG → notarize → staple → Sparkle-sign →
appcast).

## Structure

```
TheNews/
├── TheNewsApp.swift            # @main — SwiftData container (CloudKit), BGTask, notifs
├── Models/                     # Source, Feed (catalogue dynamique), Article, FeedSubscription, WatchTopic, CustomFeed
├── ViewModels/FeedViewModel    # portées (briefing/tous/alertes/favoris/rubrique), refresh parallèle
├── Views/                      # sidebar, liste, détail (+ « aussi couvert par… »), réglages, éditeurs
├── Services/                   # RSSParser/Service, FeedStore, SubscriptionStore, CustomFeedStore,
│                               # MatchingEngine, RelatedArticlesEngine, BriefingEngine,
│                               # NotificationService, RefreshEngine, WidgetPublisher
├── Shared/                     # WidgetSnapshot (App Group, partagé avec le widget)
└── Localization/               # AppSettings + tables fr/en
TheNewsWidget/                   # extension WidgetKit (iOS + macOS)
TheNewsWatch/                    # app compagnon watchOS autonome (fetch RSS direct)
TheNewsTV/                       # app compagnon tvOS autonome (fetch RSS direct, sans SwiftData)
TheNewsScreenSaver/               # .saver autonome, embarqué dans TheNews.app et auto-update
Scripts/                        # release.sh, make-thenews-icon.swift
```

## Contribuer

Les contributions sont bienvenues — voir [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Licence

MIT — voir [`LICENSE`](LICENSE).
