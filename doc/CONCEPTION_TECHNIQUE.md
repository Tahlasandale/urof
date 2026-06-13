# Document de Conception Technique (Architecture & Roadmap)

**Projet :** Universal Rich Object Format (UROF)
**Version :** 1.0
**Statut :** Spécification Initiale
**Cible :** iOS & Android (Arrière-plan natif & Interface Flutter)

---

## 1. Résumé Exécutif & Vision

Le projet UROF vise à créer une application mobile utilitaire capable d'intercepter à la demande un texte sélectionné par l'utilisateur sur son smartphone pour en afficher instantanément une fiche d'information normalisée et déterministe.

Contrairement aux solutions actuelles basées sur des modèles de langage (LLM) distants, ce système repose sur une architecture **100% sans serveur propriétaire (Serverless) et sans IA**. Il interroge directement des bases de données publiques et ouvertes (Wikidata, TMDb, OpenLibrary) à partir de schémas JSON stricts et fixes pour construire localement une interface riche, garantissant le principe : **Même entrée, même résultat.**

## 2. Objectifs & Contraintes Techniques

- **Zéro Infrastructure :** Aucun serveur intermédiaire, aucune clé d'API centralisée à payer. Les requêtes partent du client vers les API publiques.
- **Intégration OS Invisible :** Consommation de batterie nulle au repos. L'application ne s'éveille que via les menus contextuels du système (Android `PROCESS_TEXT` et iOS Action Extension).
- **Performance & Cache :** Affichage de la fiche en moins de 500ms grâce à une stratégie de cache local agressif.

## 3. Architecture Globale & Stack Technique

Pour concilier la performance graphique, la manipulation stricte de structures de données et l'interfaçage avec les sous-systèmes d'iOS et d'Android, la stack sélectionnée s'articule autour de **Flutter** complété de modules natifs de bas niveau.

| Composant | Technologie | Justification Technique |
|---|---|---|
| Cœur Logique & UI | Flutter & Dart (v3+) | Rendu graphique ultra-fluide (60/120 FPS), typage fort pour la validation des schémas JSON, portabilité maximale du code de requêtage. |
| Couche Réseau | Dio Package (Dart) | Gestion avancée des requêtes HTTP directes, intercepteurs pour la gestion des erreurs et des timeouts, configuration simplifiée des Headers. |
| Persistance & Cache | Isar ou Hive (NoSQL local) | Bases de données de type Clé-Valeur extrêmement rapides écrites en Dart pur, idéales pour stocker les fiches générées et éviter les requêtes réseau redondantes. |
| Parsing de Données | Freezed & Json_serializable | Génération automatique de code (Data Classes) pour mapper les réponses JSON des API vers les schémas fixes d'UROF sans risque d'erreur d'exécution. |
| Pont Système (OS) | MethodChannels (Native Hooks) | Passerelle bidirectionnelle permettant au code natif (Kotlin/Swift) de transmettre le texte capturé au framework Flutter. |
| Module Android | Kotlin (Process Text Intent) | Enregistrement de l'application dans le menu textuel natif du système pour une intégration transparente. |
| Module iOS | Swift (Action/Share Extension) | Création du conteneur d'extension Apple permettant l'affichage de la vue Flutter en surimpression sans ouvrir l'application principale. |

## 4. Description des Briques Logicielles (Composants)

### 4.1. La Brique d'Interception Native (Platform Ingestion)

**Android :** Un `Activity` sans interface graphique configuré avec l'intent-filter `android.intent.action.PROCESS_TEXT`. Il intercepte la sélection, extrait la chaîne de caractères et initialise l'instance Flutter via un `MethodChannel`.

**iOS :** Un composant `Action Extension` configuré dans Xcode. Il se loge dans le menu contextuel ou de partage, récupère le texte sélectionné sous forme de `NSItemProvider` et instancie un `FlutterViewController` éphémère.

### 4.2. Le Moteur de Résolution (Resolution Engine)

Cette brique en Dart reçoit le texte brut et applique l'algorithme suivant :

1. **Vérification dans le cache local** (Isar/Hive) : Si le mot possède déjà une fiche valide, passage direct à l'affichage.
2. **Requête Wikidata API :** Envoi du texte pour identifier l'entité unique (ex: Q90 pour *Paris*) et sa propriété principale (*instance of*).
3. **Détermination du type UROF :** Traduction de la propriété Wikidata vers l'un des 50 schémas fixes (ex: `instance of: city` → Schéma `city.json`).

### 4.3. Le Moteur de Requêtage Décentralisé (Data Fetcher)

Une fois le type d'objet validé, le système déclenche en parallèle ou en série les requêtes requises vers les API spécialisées préconfigurées :

- **Films / Séries :** API de TMDb.
- **Livres :** API d'OpenLibrary.
- **Géographie / Villes :** Wikidata / GeoNames.
- **Musique :** MusicBrainz.

### 4.4. Le Moteur de Rendu Dynamique (UI Renderer)

Le moteur charge le gabarit UI correspondant au schéma de l'objet (ex: `movie.json` impérativement structuré avec : Titre, Année, Réalisateur, Synopsis). Le composant Flutter génère dynamiquement une feuille (Bottom Sheet) élégante en appliquant les règles de mise en page définies de manière immuable dans l'application.

## 5. Roadmap de Développement (6 Phases)

| Phase | Livrables Clés | Durée Estimée |
|---|---|---|
| **Phase 1 : R&D et PoC Natif** | Mise en place des passerelles iOS (Swift) et Android (Kotlin). Validation de la capture de texte en arrière-plan et réveil d'un sous-processus Flutter minimal. | 2 semaines |
| **Phase 2 : Moteur de Résolution (Wikidata)** | Développement de la logique Dart pour requêter Wikidata, extraire les identifiants uniques (IDs Q) et mapper les types vers les 5 premiers schémas pilotes (Film, Ville, Livre, Animal, Personne). | 3 semaines |
| **Phase 3 : Intégration des APIs tierces** | Écriture des connecteurs HTTP (Dio) pour s'interfacer directement avec TMDb, OpenLibrary et les points d'accès Wikidata. Gestion robuste du mode dégradé (timeouts, données manquantes). | 3 semaines |
| **Phase 4 : Interface et Rendu Dynamique** | Création du système de templating UI dans Flutter. Développement des composants de fiches (gestion des images, des tableaux de caractéristiques, des listes d'attributs) selon les schémas fixes. | 3 semaines |
| **Phase 5 : Cache Local & Optimisation** | Intégration d'Isar/Hive pour la persistance locale des fiches. Indexation pour recherche instantanée. Optimisation du cycle de vie des extensions pour éviter l'arrêt brutal par l'OS (Memory Management). | 2 semaines |
| **Phase 6 : Recette, QA & Déploiement** | Tests de performance en situation réelle sur divers appareils iOS et Android (comportement du menu contextuel dans diverses apps tierces : Chrome, Safari, WhatsApp, PDF Readers). Soumission aux stores (App Store & Google Play). | 2 semaines |

## 6. Risques Techniques & Atténuations

### Risque : Suppression agressive des processus d'arrière-plan par l'OS

**Atténuation :** L'application Flutter ne doit pas tourner en continu. Elle doit être instanciée de manière "Lazy" uniquement au déclenchement de l'action système, effectuer son travail en quelques millisecondes, puis libérer immédiatement la mémoire.

### Risque : Changement ou instabilité des API publiques tierces (ex: Wikidata)

**Atténuation :** Utilisation stricte des endpoints de production stabilisés (Linked Data architecture) et mise en place d'un parsing défensif en Dart (les champs manquants n'interrompent pas le rendu global de la fiche).
