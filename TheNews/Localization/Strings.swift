import Foundation

/// Table de traductions bilingue (fr / en). Clé → chaîne. `en` sert de repli.
/// Ajoute des langues en ajoutant une entrée de premier niveau (ex. "zh") et le
/// cas correspondant dans `AppLanguage` / `AppSettings.localeIdentifier`.
enum Strings {
    static let table: [String: [String: String]] = [
        "fr": [
            "app_name": "TheNews",

            // Sidebar / liste
            "search_placeholder": "Rechercher…",
            "refresh": "Rafraîchir",
            "refresh_help": "Recharger la liste",
            "no_items_title": "Aucun article",
            "no_items_desc": "Rafraîchis pour récupérer les derniers articles.",

            // Article
            "read_article": "Lire l'article",
            "favorite": "Favori",
            "unfavorite": "Retirer",
            "share": "Partager",
            "also_covered": "Aussi couvert par…",

            // Rubriques
            "all_feeds": "Tous les articles",
            "briefing": "Briefing",
            "favorites": "Favoris",
            "mark_all_read": "Tout marquer comme lu",
            "sections": "Rubriques",
            "no_subscriptions": "Aucune rubrique suivie. Touche le bouton pour en ajouter.",
            "manage_sections": "Gérer les rubriques",
            "sections_footer": "Active les rubriques (Le Monde, Les Echos) que tu veux suivre.",

            // Flux personnalisés
            "my_feeds": "Mes flux",
            "my_feeds_footer": "Ajoute n'importe quel flux RSS. Il rejoint tes rubriques et ta veille.",
            "no_custom_feeds": "Aucun flux personnalisé.",
            "feed_add": "Ajouter un flux",
            "feed_title": "Nom du flux",
            "feed_title_footer": "Ex. « Le Monde Diplomatique », « Hacker News ».",
            "feed_url": "URL du flux RSS",
            "feed_url_footer": "L'adresse du flux (souvent en /rss ou /feed). Vérifiée à l'ajout.",
            "add": "Ajouter",

            // Veille / alertes
            "alerts": "Alertes",
            "watch_topics": "Sujets de veille",
            "watch_topics_footer": "Reçois une alerte quand un article contient l'un de tes mots-clés.",
            "no_topics": "Aucun sujet de veille.",
            "topic_add": "Ajouter un sujet",
            "topic_new": "Nouveau sujet",
            "topic_edit": "Modifier le sujet",
            "topic_label": "Nom du sujet",
            "topic_label_footer": "Ex. « Intelligence artificielle », « Élection ».",
            "topic_keywords": "Mots-clés",
            "topic_keywords_footer": "Séparés par des virgules. Insensible aux accents et à la casse.",
            "topic_notify": "Me notifier",
            "topic_notify_footer": "Envoyer une notification pour les nouveaux articles correspondants.",
            "cancel": "Annuler",
            "save": "Enregistrer",

            // Notifications
            "notif_section": "Notifications",
            "notif_footer": "TheNews t'alerte quand un nouvel article correspond à un sujet de veille.",
            "notif_on": "Notifications activées",
            "notif_denied": "Notifications refusées — active-les dans Réglages.",
            "notif_enable": "Activer les notifications",
            "notif_test": "Envoyer une notification test",

            // Briefing quotidien
            "briefing_section": "Briefing quotidien",
            "briefing_enable": "Briefing quotidien",
            "briefing_hour": "Heure d'envoi",
            "briefing_footer": "Une notification récapitulative chaque jour. Le briefing condense les sujets marquants des dernières 24 h (doublons cross-source retirés).",

            // Navigation par swipe (iOS)
            "swipe_section": "Navigation par swipe",
            "swipe_mode": "Au swipe",
            "swipe_all": "Article suivant",
            "swipe_unread": "Suivant non lu",
            "swipe_footer": "En balayant un article, passer au suivant dans la liste, ou seulement au prochain article non lu.",

            // Groupes de dates
            "group_today": "Aujourd'hui",
            "group_week": "Cette semaine",
            "group_earlier": "Plus tôt",

            // Sélection vide
            "empty_title": "Sélectionne un élément",
            "empty_desc": "Choisis un élément dans la liste pour voir son détail.",

            // Réglages
            "settings_title": "Réglages",
            "settings_appearance": "Apparence",
            "appearance_system": "Système",
            "appearance_light": "Clair",
            "appearance_dark": "Sombre",
            "settings_language": "Langue",
            "language_system": "Système",
            "settings_apikey": "Clé API",
            "apikey_placeholder": "Colle ta clé API…",
            "apikey_help": "Stockée de façon sécurisée dans le Trousseau, jamais en clair.",
            "apikey_present": "Une clé API est enregistrée.",
            "apikey_absent": "Aucune clé API enregistrée.",
            "settings_about": "À propos",
            "settings_about_text": "TheNews — veille d'information multi-sources (Le Monde, Les Echos) sur flux RSS. macOS + iOS, sans serveur.",

            // Divers
            "ok": "OK",
            "error_title": "Erreur",
        ],
        "en": [
            "app_name": "TheNews",

            "search_placeholder": "Search…",
            "refresh": "Refresh",
            "refresh_help": "Reload the list",
            "no_items_title": "No articles",
            "no_items_desc": "Refresh to fetch the latest articles.",

            // Article
            "read_article": "Read article",
            "also_covered": "Also covered by…",
            "share": "Share",
            "favorite": "Favorite",
            "unfavorite": "Remove",

            // Sections
            "all_feeds": "All articles",
            "briefing": "Briefing",
            "favorites": "Favorites",
            "mark_all_read": "Mark all as read",
            "sections": "Sections",
            "no_subscriptions": "No sections followed yet. Tap the button to add some.",
            "manage_sections": "Manage sections",
            "sections_footer": "Enable the sections (Le Monde, Les Echos) you want to follow.",

            // Custom feeds
            "my_feeds": "My feeds",
            "my_feeds_footer": "Add any RSS feed. It joins your sections and your watch list.",
            "no_custom_feeds": "No custom feed yet.",
            "feed_add": "Add a feed",
            "feed_title": "Feed name",
            "feed_title_footer": "E.g. “Le Monde Diplomatique”, “Hacker News”.",
            "feed_url": "RSS feed URL",
            "feed_url_footer": "The feed address (often under /rss or /feed). Checked when adding.",
            "add": "Add",

            // Watch / alerts
            "alerts": "Alerts",
            "watch_topics": "Watch topics",
            "watch_topics_footer": "Get an alert when an article contains one of your keywords.",
            "no_topics": "No watch topics yet.",
            "topic_add": "Add a topic",
            "topic_new": "New topic",
            "topic_edit": "Edit topic",
            "topic_label": "Topic name",
            "topic_label_footer": "e.g. “Artificial intelligence”, “Election”.",
            "topic_keywords": "Keywords",
            "topic_keywords_footer": "Comma-separated. Case- and accent-insensitive.",
            "topic_notify": "Notify me",
            "topic_notify_footer": "Send a notification for matching new articles.",
            "cancel": "Cancel",
            "save": "Save",

            // Notifications
            "notif_section": "Notifications",
            "notif_footer": "TheNews alerts you when a new article matches a watch topic.",
            "notif_on": "Notifications enabled",
            "notif_denied": "Notifications denied — enable them in Settings.",
            "notif_enable": "Enable notifications",
            "notif_test": "Send a test notification",

            // Daily briefing
            "briefing_section": "Daily briefing",
            "briefing_enable": "Daily briefing",
            "briefing_hour": "Delivery time",
            "briefing_footer": "A daily recap notification. The briefing condenses the key stories of the last 24 h (cross-source duplicates removed).",

            // Swipe navigation (iOS)
            "swipe_section": "Swipe navigation",
            "swipe_mode": "On swipe",
            "swipe_all": "Next article",
            "swipe_unread": "Next unread",
            "swipe_footer": "When swiping an article, go to the next one in the list, or only to the next unread article.",

            "group_today": "Today",
            "group_week": "This week",
            "group_earlier": "Earlier",

            "empty_title": "Select an item",
            "empty_desc": "Pick an item from the list to see its detail.",

            "settings_title": "Settings",
            "settings_appearance": "Appearance",
            "appearance_system": "System",
            "appearance_light": "Light",
            "appearance_dark": "Dark",
            "settings_language": "Language",
            "language_system": "System",
            "settings_apikey": "API Key",
            "apikey_placeholder": "Paste your API key…",
            "apikey_help": "Stored securely in the Keychain, never in plain text.",
            "apikey_present": "An API key is stored.",
            "apikey_absent": "No API key stored.",
            "settings_about": "About",
            "settings_about_text": "TheNews — multi-source news monitoring (Le Monde, Les Echos) over RSS feeds. macOS + iOS, serverless.",

            "ok": "OK",
            "error_title": "Error",
        ],
    ]
}
