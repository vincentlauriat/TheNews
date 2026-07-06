# Architecture

Application SwiftUI **à codebase unique partagé** entre les cibles macOS et iOS/iPadOS. Les différences de plateforme sont gérées par des blocs `#if os(macOS)` / `#if os(iOS)`, jamais par duplication de fichiers. TheNews est **multi-sources** : il agrège plusieurs journaux (Le Monde, Les Echos) dans une même interface. Deux compagnons **autonomes** (watchOS, tvOS) réutilisent une partie de ce codebase (`Source`/`Feed`/`RSSService`/`RSSParser`) sans SwiftData ni CloudKit — voir leurs sections dédiées plus bas.

## Vue d'ensemble

```
                    ┌─────────────────────────┐
                    │       TheNewsApp        │  @main — Scene(s) + .modelContainer
                    │ (WindowGroup + Settings) │
                    └────────────┬────────────┘
                       .environment(AppSettings)
                       .modelContext (SwiftData)
                    ┌────────────▼────────────┐
                    │       ContentView       │  NavigationSplitView
                    │   sidebar  ┆   detail    │
                    └─────┬──────┴──────┬──────┘
                          │             │
              ┌───────────▼───┐  ┌──────▼──────────────┐
              │ ArticleListV. │  │  ArticleDetailView  │
              │  (sections)   │  │  EmptySelectionV.   │
              └───────┬───────┘  └─────────────────────┘
                      │ @Bindable
              ┌───────▼──────────┐        ┌──────────────────────────┐
              │  FeedViewModel   │───────▶│ RSSService → RSSParser    │  réseau + parsing
              │ @Observable/Main │        │ FeedStore (dédup SwiftData)│
              └───────┬──────────┘        └────────────┬─────────────┘
                      │                                │
              ┌───────▼───────────────┐        ┌───────▼────────┐
              │ Feed / Source          │  catal.│ Article (@Model)│  SwiftData persisté
              │ catalog = ΣΣ sources   │        └────────────────┘
              └────────────────────────┘
```

## Couches

| Couche | Rôle | Fichiers |
|---|---|---|
| **App** | Points d'entrée, scènes, injection de `AppSettings` + `.modelContainer` | `TheNewsApp.swift` |
| **Views** | SwiftUI pur, aucune logique réseau | `Views/Article*.swift` (dont `ArticlePagerView`, swipe iOS), `ContentView.swift`, `FeedsSidebarView.swift` |
| **ViewModels** | État observable `@MainActor`, orchestration fetch/persist | `ViewModels/FeedViewModel.swift` |
| **Models** | Catalogue multi-sources (`Source`, `Feed`) + entité persistée (`Article` SwiftData) | `Models/*.swift` |
| **Services** | Réseau + parsing + persistance RSS, Keychain | `Services/RSS*.swift`, `FeedStore.swift`, `Keychain.swift` |
| **Localization** | Réglages persistés + traduction | `Localization/*.swift` |

## Modèle multi-sources

Le cœur du « mix » tient dans deux fichiers, sans toucher aux services :

- `Source.all = [.leMonde, .lesEchos]` — la liste ordonnée des journaux agrégés.
- `Feed.catalog = leMondeCatalog + lesEchosCatalog` — concaténation des catalogues. Chaque `Feed.id`
  porte le préfixe de sa source (`lemonde.economie`, `lesechos.finance`), ce qui garantit l'unicité
  inter-sources et permet à `Feed.byID` / `SubscriptionStore` de rester agnostiques.
- `Feed.bySource` — le catalogue regroupé par `Source`, consommé par la **sidebar** et l'**écran de
  gestion** qui affichent une section par journal.

Aucun service n'a de connaissance de la source : `RSSService`/`RSSParser`/`FeedStore` opèrent sur un
`Feed` quelconque ; la déduplication `Article` par `id` (guid) reste valable car les guid sont uniques
par flux. Le fetch « Tous les articles » lance en parallèle toutes les rubriques abonnées, quel que
soit leur journal.

### Catalogue dynamique (sources RSS personnalisées)

Le catalogue n'est plus figé : `Feed.catalog = builtInCatalog + customCatalog`.

- `builtInCatalog` — les journaux fournis (Le Monde, Les Echos), statiques en code.
- `customCatalog` — cache des flux ajoutés par l'utilisateur, dérivé du modèle SwiftData `CustomFeed`.
  `CustomFeedStore.reloadCatalog()` le reconstruit depuis la base au démarrage (`FeedViewModel.load`,
  `RefreshEngine.run`) et après chaque ajout/suppression. Tous les consommateurs du catalogue étant
  `@MainActor`, ce cache statique est muté sur le seul `MainActor`.
- Les flux perso sont rattachés à la pseudo-source `Source.custom` (« Mes flux »), donc regroupés
  automatiquement par `Feed.bySource` comme n'importe quel journal — sidebar et gestion inchangées.
- À l'ajout, `CustomFeedStore.validate(urlString:)` sonde l'URL (fetch + parse ≥ 1 article) avant
  de persister ; le nouveau flux est abonné aussitôt pour apparaître dans la sidebar.

### Regroupement cross-source (« Aussi couvert par… »)

`RelatedArticlesEngine` (`@MainActor`) détecte les articles de **sources différentes** traitant le
**même sujet**, entièrement on-device :

1. `tokens(_:)` — normalise (via `MatchingEngine.normalize`, insensible casse/accents) puis extrait les
   mots significatifs (≥ 4 lettres, hors liste de mots vides fr/en).
2. `similarity(_:_:)` — similarité de **Jaccard** entre les deux ensembles de mots, avec un plancher de
   2 mots forts en commun pour éviter les faux positifs.
3. `related(to:context:)` — parmi les articles récents (fenêtre de N jours), garde ceux d'une **autre
   source** dont le score dépasse le seuil, triés par pertinence.

Validé sur cas réels : « Crédit Agricole / Banco BPM » (Les Echos ↔ Le Monde) → score 0.27, regroupé ;
« Crédit Agricole ↔ incendies » → 0.0, écarté. Affiché en bas de `ArticleDetailView`.

### Briefing quotidien (« résumé du jour »)

`BriefingEngine.today(context:)` (`@MainActor`) produit une sélection condensée : articles des
dernières 24 h parmi les rubriques suivies, **priorité aux correspondances de veille**, puis
**déduplication cross-source** (réutilise `RelatedArticlesEngine.similarity` avec un seuil élevé pour
ne garder qu'un article par sujet). Exposé comme portée `FeedSelection.briefing` (entrée « Briefing »
en tête de sidebar), rendu par la liste standard. Une **notification quotidienne** répétée est
programmée par `NotificationService.scheduleDailyBriefing(enabled:hour:)`
(`UNCalendarNotificationTrigger`), pilotée par les réglages persistés `briefingEnabled` / `briefingHour`
(reprogrammée au démarrage et à chaque changement de réglage).

### Widget d'écran d'accueil (WidgetKit, iOS)

Cible d'extension `TheNewsWidgetExtension` séparée, reliée à l'app par un **App Group**
(`group.fr.vincentlauriat.thenews`) — pas de SwiftData partagé entre cibles :

- `WidgetSnapshot` (`Codable`, dans `TheNews/Shared/`, compilé dans les deux cibles) : liste réduite
  d'articles + horodatage, lue/écrite via `WidgetSnapshotStore` dans le container de l'App Group.
- Côté app, `WidgetPublisher.publish(context:)` reprend la sélection du briefing, écrit le snapshot et
  appelle `WidgetCenter.reloadAllTimelines()` après chaque rafraîchissement (`FeedViewModel.refresh`,
  `RefreshEngine.run`).
- Côté widget, `TheNewsProvider` (TimelineProvider) lit le snapshot ; `TheNewsWidgetView` s'adapte aux
  tailles small/medium/large.
- Le build **simulateur non signé** n'applique pas l'entitlement App Group (write = no-op) ; le build
  **signé** (device) provisionne l'App Group automatiquement — vérifié sur l'appareil.

### App compagnon Apple TV (tvOS, autonome — E1 « lite »)

Cible `TheNewsTV`, **sans SwiftData ni CloudKit** (contrairement à macOS/iOS) : réutilise tel quel
`Source`/`Feed`/`RSSService`/`RSSParser`, comme la cible watchOS. Choix assumé (Vincent) : une version
« lite » d'abord (E1), une bascule vers la sync iCloud complète plus tard (E2, mêmes modèles que
Mac/iPhone) — voir `PLAN.md` Phase E.

- **Écran d'accueil** : Briefing + Tous les articles en tête, puis les rubriques groupées par source
  (réutilise `Feed.bySource`) — la TV a la place d'exposer tout le catalogue, contrairement aux 2 flux
  fixes de la Watch.
- **`TVArticle`** enrichit `ParsedArticle` du nom de sa source (que le flux RSS ne porte pas) ;
  `TVArticleSelection` porte la liste + l'index courant pour naviguer au suivant/précédent en détail
  sans re-fetch ni repousser d'écran.
- **Briefing « lite »** (`TVBriefingView`) : agrège tout `Feed.builtInCatalog` en direct, garde les
  dernières 24 h (repli sur tout si rien de récent), déduplique via une **réimplémentation minimale**
  (tokens + Jaccard) de `RelatedArticlesEngine`/`BriefingEngine` plutôt que de les réutiliser — ceux-ci
  dépendent de `ModelContext`/`Article` (SwiftData), hors périmètre de la version lite.
- **Lu/non-lu** (`TVReadStore`, `@Observable`) : suivi **en mémoire pour la session uniquement** (pas
  de `Article.isRead` persisté comme macOS/iOS) — mêmes codes visuels (pastille + titre en gras).
  ⚠️ Marquer un article lu **mute un état observé par l'écran-liste encore vivant sous la pile de
  navigation** (ses lignes lisent `TVReadStore`) ; le faire de façon synchrone dans `onAppear`, pendant
  l'animation de poussée d'écran, faisait **rebondir immédiatement** vers la liste sur tvOS. Fix :
  `.task(id:)` + court délai, pour ne toucher l'état partagé qu'une fois la transition terminée.
- **Navigation télécommande** dans le détail (`TVArticleDetailView`) : gauche/droite = article
  suivant/précédent (`onMoveCommand`), haut/bas = défilement du contenu. ⚠️ tvOS pilote le scroll
  **par le focus**, comme une `List` : un unique bloc `.focusable()` pour tout l'écran fait que
  haut/bas n'ont rien « en dessous » vers quoi déplacer le focus, donc tombent (comme gauche/droite)
  dans `onMoveCommand` — sans gestion explicite, ils ne font rien. Fix : **3 blocs focusables**
  distincts (image / texte / pied), focus effect désactivé (`.focusEffectDisabled()`, ce ne sont pas
  des boutons) — le focus engine déplace nativement le focus (et le scroll) entre eux, et
  gauche/droite, qu'aucun bloc ne gère (empilés verticalement), remonte à `onMoveCommand`.
- Pas d'icône layered/Top Shelf (chantier de polish séparé, non bloquant).

### Sync iCloud (SwiftData + CloudKit)

Le `ModelContainer` est configuré avec `ModelConfiguration(cloudKitDatabase: .automatic)` : la sync
CloudKit s'active dès que l'entitlement iCloud est présent (build signé), sinon le store reste local
(dev macOS non signé) — sans crash.

Contraintes CloudKit prises en compte dans les modèles (`Article`, `FeedSubscription`, `WatchTopic`,
`CustomFeed`) :

- **Aucun `@Attribute(.unique)`** (CloudKit ne les supporte pas) — l'unicité reste garantie par la
  **déduplication applicative** : `FeedStore.ingest` (fetch par `id` avant insertion),
  `SubscriptionStore` (vérif avant abonnement), `id` en UUID pour `CustomFeed`/`WatchTopic`.
- **Valeur par défaut sur chaque propriété stockée** (exigence CloudKit).

Entitlements iOS : `icloud-container-identifiers` (`iCloud.fr.vincentlauriat.thenews`),
`icloud-services: CloudKit`, `aps-environment`, + background mode `remote-notification` (push de sync).

Sur **macOS**, CloudKit exige l'**App Sandbox** : la cible macOS l'active (`app-sandbox`), rouvre
l'accès réseau sortant (`network.client`, pour les flux/images) et porte les mêmes entitlements iCloud.
La cible macOS est donc **signée** (dev, team KFLACS69T9) — build via `-allowProvisioningUpdates
-allowProvisioningDeviceRegistration` (plus de `CODE_SIGNING_ALLOWED=NO`). Les deux plateformes
partagent le même conteneur CloudKit → sync des données SwiftData (abonnements, favoris, sujets, flux
perso). Les réglages d'interface (`UserDefaults`) ne sont pas synchronisés.

## Flux RSS (couche métier)

- `RSSService.fetch(Feed)` télécharge le flux (`URLSession`, hors `MainActor`).
- `RSSParser.parse(Data)` — délégué `XMLParser` natif : mappe chaque `<item>` en `ParsedArticle`
  (`Sendable`), gère `media:content`/`enclosure`, décode le HTML du chapô, parse les dates RFC 822.
- `FeedStore.ingest(...)` insère dans SwiftData en **dédupliquant par `id`** (guid, ou lien à défaut)
  et renvoie uniquement les **nouveaux** articles — base de déclenchement des alertes.
- Le corps complet n'est **pas** dans le flux : `ArticleDetailView` ouvre le lien dans le navigateur.

> ⚠️ **Accès Les Echos** : `services.lesechos.fr` renvoie **403 à `curl`** (Akamai fait du
> TLS-fingerprinting) mais **200 à `URLSession`** (pile réseau Apple). Validé à l'exécution dans le
> projet LesEchos d'origine. Le Monde n'a pas cette restriction.

## Décisions clés

- **Observation** (`@Observable`, Swift 5.9) plutôt que `ObservableObject`. Les ViewModels sont `@MainActor`.
- **Multi-sources par concaténation de catalogues** : le mix Le Monde + Les Echos ne demande aucun
  refactor des services — seuls `Source`/`Feed` et deux vues (sidebar, gestion) connaissent la notion
  de source. Extensible à un N-ième journal sans refonte.
- **Réglages** : `AppSettings` centralise apparence, langue et secrets (`UserDefaults` + **Keychain**). Injecté dans l'environnement SwiftUI.
- **Localisation maison** : dictionnaire `[lang: [clé: valeur]]` (`Strings.swift`) avec repli `en`, résolu par `settings.t("clé")`.
- **Build** : projet Xcode **généré** par XcodeGen (`project.yml`) — le `.xcodeproj` n'est pas versionné. Régénérer avec `xcodegen generate`.
- **Signature/notarisation** : gérées manuellement dans `release.sh` (Developer ID + Hardened Runtime + timestamp avec retry).
- **Auto-update macOS (Sparkle)** : seule dépendance externe du projet (package SPM, cible `TheNews`
  macOS uniquement — jamais liée sur iOS/watchOS/tvOS). `SparkleUpdater` (`Services/`) enveloppe
  `SPUStandardUpdaterController`, instancié au lancement (`.task` dans `TheNewsApp`) pour démarrer
  la vérification automatique quotidienne (`SUScheduledCheckInterval`), plus un item de menu
  « Rechercher les mises à jour… » pour une vérification manuelle. `SUAutomaticallyUpdate: false` —
  notifie mais n'installe jamais silencieusement. Fonctionne dans le **sandbox** de l'app (requis
  pour CloudKit) sans entitlement supplémentaire : les XPC Services de Sparkle 2 (`Downloader.xpc`,
  `Installer.xpc`) sont embarqués dans le bundle et conçus pour ça nativement. Clé de signature
  EdDSA dans le trousseau de connexion sous le compte « TheNews » (voir l'avertissement en tête de
  `Scripts/release.sh` — ne jamais la régénérer, ça casserait l'auto-update pour tous les
  utilisateurs déjà installés). Le flux (`appcast.xml`, à la racine du repo, servi via
  `raw.githubusercontent.com`) est régénéré et signé à chaque release par `release.sh`.

## Ajouter une source de presse

1. Ajoute une instance dans `Source.all` (`Models/Source.swift`).
2. Décris ses rubriques (id préfixé, titre, symbole, URL du flux) dans un catalogue `Feed` dédié
   (`Models/Feed.swift`), sur le modèle de `leMondeCatalog` / `lesEchosCatalog`, puis ajoute-le à
   `Feed.catalog`.
3. Rien à changer côté services ni côté vues : la sidebar et la gestion se regroupent automatiquement
   par `Feed.bySource`.
4. Ajoute les clés d'affichage éventuelles dans `Strings.swift`.
