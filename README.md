# CarWatt 🚗⚡

Application Flutter de suivi des recharges de véhicule électrique avec analyse de consommation et calcul d'économies versus essence.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ Fonctionnalités

### 📊 Tableau de bord
- Vue d'ensemble de la dernière charge
- Statistiques globales (nombre de charges, distance totale)
- Économies cumulées vs essence
- Consommation moyenne et coût au 100 km

### ⚡ Gestion des charges
- Enregistrement complet des recharges
- **Brouillons** : possibilité de saisir partiellement une charge (début uniquement) et la compléter plus tard
- Deux modes de saisie : montant total ou prix au kWh
- Calculs automatiques :
  - Distance parcourue depuis dernière charge
  - Consommation kWh/100km
  - Économie vs essence (coût équivalent)
  - Pertes à la charge
- Filtrage et tri des charges
- Recherche par station ou date

### 🗺️ Carte interactive
- Visualisation de toutes les stations de recharge
- Géolocalisation de l'utilisateur
- Calcul de distance depuis position actuelle
- Filtrage par réseau (Tesla, Ionity, etc.)
- Détails de chaque station avec historique des charges

### 🚉 Gestion des stations
- Création/édition de stations
- **Sélection de position sur carte interactive**
- Récupération automatique de l'adresse via géocodage inverse
- Réseaux multiples par station
- Tri par nom, distance ou réseau

### 🛣️ Trajets
- **Création automatique** de trajets entre charges consécutives
- **Trajets manuels** pour suivre des parcours récurrents spécifiques
- Statistiques détaillées :
  - Détection automatique des trajets récurrents
  - Consommation moyenne par trajet
  - Évolution dans le temps (min/max)
  - Vue d'ensemble globale

### 📥 Import/Export
- **Export CSV** : sauvegarde des stations et charges
- **Import CSV** : restauration complète des données
- Compatibilité multi-plateforme (Android, Linux, macOS, Windows)
- Gestion automatique des encodages

### ⚙️ Paramètres
- Configuration véhicule (capacité batterie, kilométrage initial)
- Paramètres de comparaison essence (consommation, prix E10)
- Personnalisation complète

## 🏗️ Architecture technique

### Stack
- **Frontend** : Flutter / Dart
- **Base de données** : SQLite (sqflite)
- **Cartes** : flutter_map + OpenStreetMap
- **Géolocalisation** : geolocator + geocoding
- **Formats** : CSV (import/export)

### Structure du projet
```
lib/
├── data/
│   ├── models/          # Modèles de données (Charge, Station, Trajet, Parametre)
│   ├── database/        # DatabaseHelper (SQLite)
│   └── utils/           # Utilitaires (CSV importer)
└── presentation/
    ├── screens/         # Écrans de l'application
    └── widgets/         # Composants réutilisables (AppDrawer)
```

### Base de données
- **Version 3** avec migrations automatiques
- Tables : `charges`, `stations`, `trajets`, `parametres`
- Calculs automatiques en cascade
- Support des transactions

## 📱 Plateformes supportées

- ✅ Android
- ✅ Linux
- ✅ Windows
- ✅ macOS
- ✅ iOS (non testé)
- ✅ Web (fonctionnalités limitées)

## 🚀 Installation

### Prérequis
- Flutter SDK 3.19+
- Dart 3.3+

### Cloner le projet
```bash
git clone https://github.com/votre-username/carwatt.git
cd carwatt
```

### Installer les dépendances
```bash
flutter pub get
```

### Lancer l'application
```bash
# Android/iOS
flutter run

# Linux
flutter run -d linux

# Windows
flutter run -d windows

# macOS
flutter run -d macos
```

## 📦 Dépendances principales
```yaml
dependencies:
  sqflite: ^2.4.2
  sqflite_common_ffi: ^2.3.0+4
  flutter_map: ^8.2.2
  latlong2: ^0.9.1
  geolocator: ^14.0.2
  geocoding: ^3.0.0
  csv: ^6.0.0
  intl: ^0.19.0
  file_picker: ^10.3.8
  share_plus: ^12.0.1
  path_provider: ^2.1.5
```

## 🎯 Roadmap

- [ ] Graphiques de statistiques (fl_chart)
- [ ] Export JSON
- [ ] Notifications pour compléter les brouillons
- [ ] Enregistrement rapide de position en cours de route
- [ ] Commande vocale pour saisie rapide
- [ ] Synchronisation cloud (optionnelle)
- [ ] Dark mode
- [ ] Support multi-véhicules
- [ ] Prévisions d'autonomie basées sur historique

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- Signaler des bugs via les [Issues](https://github.com/votre-username/carwatt/issues)
- Proposer des améliorations
- Soumettre des Pull Requests

## 📄 License

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

- [OpenStreetMap](https://www.openstreetmap.org/) pour les données cartographiques
- [flutter_map](https://pub.dev/packages/flutter_map) pour l'intégration des cartes
- La communauté Flutter pour les packages open source

## 📧 Contact

Pour toute question ou suggestion : [boss@djipi.club](mailto:votre-email@exemple.com)

---

Développé avec ❤️ pour les passionnés de mobilité électrique
```

## 📄 Fichier bonus : `LICENSE`

Si vous voulez une licence MIT :
```
MIT License

Copyright (c) 2024 [Votre Nom]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
