# QualiScan — scanner de documents iOS

App iOS native (SwiftUI) qui transforme une photo en document « scanné » propre, façon CamScanner.
Tout est **100 % natif Apple**, sans dépendance tierce : VisionKit, Vision, Core Image, PDFKit,
PencilKit, SwiftData.

## Fonctionnalités
- **Capture** : caméra de document **VisionKit** (détection des bords, multi-pages, sur appareil réel)
  + **import depuis Photos** (même pipeline, testable au simulateur).
- **Rendu « scanné »** (Core Image) : correction de perspective + 4 modes —
  **Original / Couleur / Gris / N&B**. Le N&B/gris propre vient d'une **normalisation
  d'illumination** (division par un flou) qui efface ombres et éclairage inégal.
- **Auto-recadrage** des photos importées (détection de rectangle Vision).
- **Éditeur de page** : recadrage perspective à **4 coins**, rotation, luminosité/contraste, filtre.
- **OCR** (Vision, multilingue) : **PDF recherchable** (couche texte invisible) + copier-le-texte.
- **Export** : PDF multi-pages (**A4 / US Letter / ajusté**), **filigrane**, partage ; export en images.
- **Bibliothèque** : **dossiers**, **recherche** (titre + texte OCR), tri, renommer, réordonner, déplacer.
- **Annotation & signature** (PencilKit) : markup au stylo + tampon de signature déplaçable.
- **Multilingue** : 🇬🇧 🇫🇷 🇩🇪 🇪🇸 🇵🇹 (anglais par défaut, bascule dans les Réglages).
- **iCloud-ready** : modèle compatible CloudKit (sync désactivée par défaut).

## Structure
```
QualiScan/            sources (mono-target)
  QualiScanApp.swift      point d'entrée, conteneur SwiftData
  Models.swift            Folder / ScanDocument / ScanPage, FilterMode, PageSize
  ImageStore.swift        persistance fichiers (orig/proc/thumb)
  ScanProcessor.swift     moteur Core Image (perspective + 4 filtres)
  DocumentScanner.swift   auto-crop Vision
  OCRService.swift        reconnaissance de texte Vision
  PDFExporter.swift       PDF recherchable + filigrane + export images
  LibraryView / DocumentDetailView / PageEditorView / QuadCropView
  AnnotateView (+ SignatureView) / SettingsView
  Components.swift / Palette.swift / Localization.swift / DemoSeed.swift
QualiScan.xcodeproj/  projet (pbxproj écrit à la main)
build-run.sh          build + boot simulateur + install + lancement
```
- Bundle id : `company.lno.qualiscan` · iOS min : **17.0**

## Lancer
```bash
./build-run.sh -seedDemo -demoLang fr
```
ou `open QualiScan.xcodeproj` puis ⌘R. La caméra nécessite un **iPhone réel** ; au simulateur,
utiliser **Import depuis Photos**.

## Feuille de route
- Caméra testée sur device + signature avec team payante.
- iCloud sync (conteneur + entitlements).
- Share Extension « Ouvrir dans QualiScan » (recevoir PDF/images d'autres apps).
- Seuillage adaptatif Metal pour un N&B encore plus net sur documents très ombrés.

## Push notifications (OneSignal)

The `OneSignal-XCFramework` Swift Package (pinned to **5.5.1**, only the
`OneSignalFramework` product) is linked into the app target, the app declares
`aps-environment` (`production`, even in Debug — the real environment is picked by the
provisioning profile, and `development` in a TestFlight build yields a token APNs rejects
in silence), and Push is enabled on the App ID `company.lno.qualiscan`.

Everything is gated on one constant — `OneSignalPush.appID` in
`QualiScan/OneSignalPush.swift`. While it is empty the SDK is never
initialised: no registration, no network call, no permission prompt. Paste the App ID
from onesignal.com ▸ Settings ▸ Keys & IDs to switch push on.

OneSignal carries Crazy Bee Labs announcements and app-update notices only; anything
this app schedules for itself stays a local notification. A tap on a push can only open
an `apps.apple.com` or `crazybeelabs.com` link — the payload is untrusted input.

Still required server-side before any push is delivered: an APNs `.p8` key uploaded to
the OneSignal app (Settings ▸ Platforms ▸ Apple iOS).
