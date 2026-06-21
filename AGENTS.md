# AGENTS.md — QualiScan (scanner de documents iOS)

À lire avant toute modification. Fige comment on travaille sur **QualiScan**.

## Le projet
- App iOS native **SwiftUI + SwiftData**, scanner de documents type CamScanner.
- Capture (caméra VisionKit / import Photos) → rendu « scanné » (Core Image) → OCR (Vision) → PDF (PDFKit).
- Dossier local : `~/qualiscan/`. Le dossier local **est** le projet ouvert dans Xcode.
- Mono-target, bundle `company.lno.qualiscan`, **iOS 17+**, Swift 5 mode, team `2E6D4Q69QB`.

## Compiler & lancer
- `./build-run.sh -seedDemo -demoLang fr` — build, boot du simulateur, install, lancement.
- Ou Xcode : ouvrir `QualiScan.xcodeproj`, scheme **QualiScan**, ⌘R.
- ⚠️ **La caméra n'existe pas dans le simulateur** → y tester via **Import depuis Photos**
  (même pipeline). La caméra `VNDocumentCameraViewController` ne marche que sur un iPhone réel.
- Runtimes simulateur présents : iOS 18.6 / 26.3 / 26.4 / 26.5.

## Architecture
- **Models.swift** — SwiftData : `Folder` → `ScanDocument` → `ScanPage` (pages ordonnées par `index`).
  `FilterMode` (original/color/grayscale/bw), `PageSize` (auto/A4/letter). Compatible CloudKit.
- **ImageStore.swift** — les images vivent en **fichiers** (Application Support) : `orig` / `proc` / `thumb`
  par UUID de page. La base ne stocke que les UUID. Nettoyage à la suppression.
- **ScanProcessor.swift** — moteur Core Image : correction de perspective (`CIPerspectiveCorrection`)
  + 4 rendus. Le N&B/gris « scan » vient de la **normalisation d'illumination** (image ÷ flou
  via `CIDivideBlendMode`) + courbe — pas de kernel Metal.
- **DocumentScanner.swift** — `VNDetectRectangles` pour l'auto-crop des photos importées.
- **OCRService.swift** — `VNRecognizeText` (multilingue) → texte + boîtes par ligne.
- **PDFExporter.swift** — PDF multi-pages (`UIGraphicsPDFRenderer`), couche texte OCR **invisible**
  (recherchable), filigrane, A4/Letter/auto ; + export images.
- **UI** : `LibraryView` (grille, dossiers, recherche) · `DocumentDetailView` (pages, filtre doc,
  OCR, export, déplacer) · `PageEditorView`+`QuadCropView` (recadrage 4 coins, rotation, filtre,
  réglages) · `AnnotateView`+`SignatureView` (PencilKit) · `SettingsView`.
- **Localization.swift** — table in-code `L.t(key, lang)` EN/FR/DE/ES/PT. **Palette.swift** — tokens.

## Conventions
- `project.pbxproj` **écrit à la main**, schéma d'UUID lisible : `AA…` projet/groupes · `BB…` target ·
  `CC…` produit · `DD…` config lists · `EE…` build configs · `FF…` build phases ·
  `AC…` file refs · `BA…` build files. Ajouter un fichier = 1 `PBXFileReference` + entrée groupe
  `QualiScan` + 1 `PBXBuildFile` + entrée dans `Sources`. (Ou l'ajouter via Xcode.)
- Toute image affichée passe par `StoredImage` (chargement hors-main + placeholder).

## Arguments de lancement (dev / captures)
- `-seedDemo` : 3 documents synthétiques (texte réel + éclairage inégal) au 1ᵉʳ lancement.
- `-demoLang <en|fr|de|es|pt>` : force la langue.
- `-openDoc <index|titre>` : ouvre un document.
- `-openEditor` : ouvre l'éditeur de la 1ʳᵉ page du document ouvert.
- `-openSettings` : ouvre les réglages.
- `-demoFilter <original|color|grayscale|bw>` : force le filtre du document ouvert.
- `-selfTest` : exporte un PDF du 1ᵉʳ doc + écrit `Documents/selftest.{pdf,txt}` (vérif headless).
- `-inMemory` : base SwiftData en mémoire.

## iCloud (désactivé par défaut)
Le modèle est compatible CloudKit mais la sync est **off** (l'app tourne en local dans le simu,
signature gratuite OK). Pour l'activer : team Apple **payante** + conteneur iCloud, remplir
`QualiScan.entitlements` et passer `ModelConfiguration` en `cloudKitDatabase`.

## Git
- Commit après chaque lot ; message terminé par `Co-Authored-By: Claude Opus 4.8 …`.
