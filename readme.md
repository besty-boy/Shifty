# ♻️ Shifty — Assistant de tri écologique

**Shifty** est une application iOS en SwiftUI conçue pour le **Swift Student Challenge**. Elle aide à trier les déchets au quotidien grâce à la caméra et à un modèle Core ML embarqué. 

Bien plus qu'un simple scanner, Shifty propose un mini-jeu d'entraînement, un système de trophées et des statistiques pour encourager des habitudes éco-responsables, avec une attention toute particulière portée à **l'accessibilité**, **la qualité d'interface** et **la confidentialité**.

---

## 🌟 Fonctionnalités Principales

* 📸 **Scanner intelligent en temps réel :** Classe les objets (Compost / Recyclage / Ordures) via `AVCaptureSession` et Vision. Affiche des consignes claires, le niveau de confiance et une anecdote contextuelle.
* 🎮 **Mini-jeu d'entraînement :** Apprentissage par gestes (swipe à gauche = Compost, en haut = Recyclage, à droite = Ordures). Feedback immédiat, animations (confettis) et système de score.
* 🏆 **Progression & Trophées :** Suivi des séries quotidiennes, des scans et des sessions d'entraînement via `EcoStatsStore`. Page de trophées avec badges et objectifs progressifs.
* 🎙️ **Accès rapide par la voix :** Intégration d'App Intents et Raccourcis Siri (ex: *"Scan with Shifty"*).
* ✨ **Effets visuels modernes :** UI soignée avec effets "Liquid Glass" (sur iOS 26+), dégradés animés (`FluidBackground`) et transitions fluides, avec un repli visuel élégant sur les versions antérieures.
* 💡 **Citations quotidiennes :** Génération de citations motivantes via Foundation Models (iOS 26+) ou via une base locale si indisponible.

---

## 🔒 Confidentialité & Accessibilité

Shifty a été pensé pour être utilisable par tous, en toute sécurité :
* **100% On-Device :** Toutes les images capturées restent sur l'appareil. L'inférence Vision/Core ML et la génération de texte (Foundation Models) sont traitées localement. Aucune collecte réseau.
* **VoiceOver :** Annonces détaillées lors de l'analyse et des résultats (nom de l'objet, consigne, confiance). Actions d'accessibilité dédiées sur la carte principale.
* **Inclusivité visuelle & haptique :** Contrastes élevés, hiérarchie visuelle claire et retours haptiques pour guider l'utilisateur sans dépendre uniquement de l'écran.

---

## 🛠️ Technologies & Architecture

* **UI :** SwiftUI, Swift Concurrency.
* **Machine Learning :** Vision + Core ML (`ImageClassifier`).
* **Médias :** AVFoundation (`CameraManager`).
* **Système :** App Intents (`ShiftySiriIntents`), Foundation Models.

### Architecture (Haut Niveau)
| Couche | Composants clés |
| :--- | :--- |
| **Vues (UI)** | `ContentView`, `HomeView`, `ScanView`, `TrainingGamePage`, `TrophiesPage` |
| **ViewModels / Stores** | `ScanViewModel` (orchestration), `EcoStatsStore` (persistance `UserDefaults`) |
| **Services / Managers** | `CameraManager`, `ImageClassifier` |
| **Modèles & Utilitaires** | `ClassificationResult`, `WasteCategory`, `AppPalette`, `FluidBackground`, `L10n` |

---

## 🚀 Installation & Prérequis

* **Environnement :** Xcode 15+ (Compatible Xcode 26.x).
* **OS :** iOS 17+ recommandé (Améliorations visuelles et Foundation Models activés sur iOS 26+).
* **Matériel :** Un appareil iOS physique est requis pour tester la caméra (le simulateur permet tout de même de tester le mini-jeu et l'interface avec le mode "mock" du modèle ML).

### Étapes d'installation
1. Ouvrez le projet dans Xcode.
2. Assurez-vous que le modèle Core ML est présent dans le bundle. Ajoutez `WasteClassifier.mlmodel` (ou `.mlpackage` / `.mlmodelc`) dans le dossier `Sources/`.
3. Vérifiez le fichier `Info.plist` : la clé `NSCameraUsageDescription` doit être présente (ex: *"Cette app utilise la caméra pour analyser et trier les objets."*).
4. Compilez sur votre iPhone et accordez l'accès à la caméra au premier lancement.

> **Note technique sur le Modèle Core ML :** Le classifieur utilise `centerCrop` via `VNCoreMLRequest`. Si le modèle est absent, l'application bascule automatiquement sur un **mode mock** générant des résultats de démonstration (idéal pour le simulateur).

---

## 🎬 Conseils pour la démo (Swift Student Challenge)

**Le Pitch (30–45s) :**
> *"Shifty aide chacun à trier mieux, plus vite. Je scanne un objet, l'app m'explique comment le trier et me récompense. Le mini-jeu me permet d'apprendre en quelques gestes. Tout se passe en local pour la vie privée, et l'UI exploite les dernières possibilités de SwiftUI."*

**Déroulé de test :**
1. Ouvrir le scanner (via le bouton ou en disant *"Scanne avec Shifty"* à Siri).
2. Capturer un objet et observer le résultat (catégorie, confiance, consigne).
3. Aller sur le mini-jeu et réaliser 2–3 swipes pour tester le feedback haptique et visuel.
4. Ouvrir l'onglet Trophées pour constater la progression.

---

## 🔮 Améliorations futures
* Packs de modèles spécialisés (emballages, verre/plastique) et calibration par région.
* Guides de tri adaptés aux règles des municipalités locales.
* Widgets et Live Activities pour suivre ses séries quotidiennes.
* Export/Import des statistiques personnelles.
