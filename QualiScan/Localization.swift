import Foundation

/// Supported in-app languages. English is the default; the user switches in Settings.
enum AppLanguage: String, CaseIterable, Identifiable {
    case en, fr, de, es, pt
    var id: String { rawValue }

    var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .fr: return "🇫🇷"
        case .de: return "🇩🇪"
        case .es: return "🇪🇸"
        case .pt: return "🇵🇹"
        }
    }

    /// Endonym (language name in that language).
    var name: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .pt: return "Português"
        }
    }

    /// Vision / OCR language codes mapped from the UI language.
    var ocrCodes: [String] {
        switch self {
        case .en: return ["en-US"]
        case .fr: return ["fr-FR", "en-US"]
        case .de: return ["de-DE", "en-US"]
        case .es: return ["es-ES", "en-US"]
        case .pt: return ["pt-BR", "en-US"]
        }
    }

    static let storageKey = "app.language"

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "en") ?? .en
    }
}

/// Tiny in-app localization table (key → per-language string).
enum L {
    static func t(_ key: String, _ lang: AppLanguage = .current) -> String {
        table[key]?[lang] ?? table[key]?[.en] ?? key
    }

    static let table: [String: [AppLanguage: String]] = [
        // App
        "app_name": [.en: "QualiScan", .fr: "QualiScan", .de: "QualiScan", .es: "QualiScan", .pt: "QualiScan"],
        "app_tagline": [.en: "Scan. Clean. Share.", .fr: "Scanner. Nettoyer. Partager.", .de: "Scannen. Säubern. Teilen.", .es: "Escanea. Limpia. Comparte.", .pt: "Digitalize. Limpe. Partilhe."],

        // Library
        "library_title": [.en: "Documents", .fr: "Documents", .de: "Dokumente", .es: "Documentos", .pt: "Documentos"],
        "search_placeholder": [.en: "Search documents", .fr: "Rechercher un document", .de: "Dokumente suchen", .es: "Buscar documentos", .pt: "Procurar documentos"],
        "empty_title": [.en: "No documents yet", .fr: "Aucun document", .de: "Noch keine Dokumente", .es: "Aún no hay documentos", .pt: "Ainda sem documentos"],
        "empty_subtitle": [.en: "Scan a page or import a photo to get started.", .fr: "Scannez une page ou importez une photo pour commencer.", .de: "Scanne eine Seite oder importiere ein Foto.", .es: "Escanea una página o importa una foto para empezar.", .pt: "Digitalize uma página ou importe uma foto para começar."],
        "folders": [.en: "Folders", .fr: "Dossiers", .de: "Ordner", .es: "Carpetas", .pt: "Pastas"],
        "all_documents": [.en: "All documents", .fr: "Tous les documents", .de: "Alle Dokumente", .es: "Todos los documentos", .pt: "Todos os documentos"],
        "new_folder": [.en: "New folder", .fr: "Nouveau dossier", .de: "Neuer Ordner", .es: "Nueva carpeta", .pt: "Nova pasta"],
        "folder_name": [.en: "Folder name", .fr: "Nom du dossier", .de: "Ordnername", .es: "Nombre de la carpeta", .pt: "Nome da pasta"],

        // Actions
        "scan_camera": [.en: "Scan with camera", .fr: "Scanner avec l'appareil", .de: "Mit Kamera scannen", .es: "Escanear con la cámara", .pt: "Digitalizar com a câmara"],
        "import_photos": [.en: "Import from Photos", .fr: "Importer depuis Photos", .de: "Aus Fotos importieren", .es: "Importar desde Fotos", .pt: "Importar das Fotos"],
        "settings": [.en: "Settings", .fr: "Réglages", .de: "Einstellungen", .es: "Ajustes", .pt: "Definições"],
        "sort": [.en: "Sort", .fr: "Trier", .de: "Sortieren", .es: "Ordenar", .pt: "Ordenar"],
        "sort_date": [.en: "Newest first", .fr: "Plus récents", .de: "Neueste zuerst", .es: "Más recientes", .pt: "Mais recentes"],
        "sort_name": [.en: "Name", .fr: "Nom", .de: "Name", .es: "Nombre", .pt: "Nome"],

        // Document
        "untitled": [.en: "Scan", .fr: "Scan", .de: "Scan", .es: "Escaneo", .pt: "Digitalização"],
        "page": [.en: "page", .fr: "page", .de: "Seite", .es: "página", .pt: "página"],
        "pages": [.en: "pages", .fr: "pages", .de: "Seiten", .es: "páginas", .pt: "páginas"],
        "rename": [.en: "Rename", .fr: "Renommer", .de: "Umbenennen", .es: "Renombrar", .pt: "Renomear"],
        "delete": [.en: "Delete", .fr: "Supprimer", .de: "Löschen", .es: "Eliminar", .pt: "Eliminar"],
        "export": [.en: "Export", .fr: "Exporter", .de: "Exportieren", .es: "Exportar", .pt: "Exportar"],
        "share": [.en: "Share", .fr: "Partager", .de: "Teilen", .es: "Compartir", .pt: "Partilhar"],
        "export_pdf": [.en: "Share as PDF", .fr: "Partager en PDF", .de: "Als PDF teilen", .es: "Compartir como PDF", .pt: "Partilhar como PDF"],
        "export_images": [.en: "Share as images", .fr: "Partager en images", .de: "Als Bilder teilen", .es: "Compartir como imágenes", .pt: "Partilhar como imagens"],
        "run_ocr": [.en: "Recognize text", .fr: "Reconnaître le texte", .de: "Text erkennen", .es: "Reconocer texto", .pt: "Reconhecer texto"],
        "copy_text": [.en: "Copy text", .fr: "Copier le texte", .de: "Text kopieren", .es: "Copiar texto", .pt: "Copiar texto"],
        "edit": [.en: "Edit", .fr: "Modifier", .de: "Bearbeiten", .es: "Editar", .pt: "Editar"],
        "annotate": [.en: "Annotate", .fr: "Annoter", .de: "Markieren", .es: "Anotar", .pt: "Anotar"],
        "add_pages": [.en: "Add pages", .fr: "Ajouter des pages", .de: "Seiten hinzufügen", .es: "Añadir páginas", .pt: "Adicionar páginas"],
        "move_to": [.en: "Move to folder", .fr: "Déplacer vers", .de: "Verschieben nach", .es: "Mover a", .pt: "Mover para"],
        "reorder": [.en: "Reorder", .fr: "Réordonner", .de: "Neu anordnen", .es: "Reordenar", .pt: "Reordenar"],

        // Filters
        "filter_original": [.en: "Original", .fr: "Original", .de: "Original", .es: "Original", .pt: "Original"],
        "filter_color": [.en: "Color", .fr: "Couleur", .de: "Farbe", .es: "Color", .pt: "Cor"],
        "filter_grayscale": [.en: "Gray", .fr: "Gris", .de: "Grau", .es: "Gris", .pt: "Cinza"],
        "filter_bw": [.en: "B&W", .fr: "N&B", .de: "S/W", .es: "B/N", .pt: "P&B"],
        "filter": [.en: "Filter", .fr: "Filtre", .de: "Filter", .es: "Filtro", .pt: "Filtro"],

        // Editor
        "crop": [.en: "Crop", .fr: "Recadrer", .de: "Zuschneiden", .es: "Recortar", .pt: "Recortar"],
        "adjust": [.en: "Adjust", .fr: "Ajuster", .de: "Anpassen", .es: "Ajustar", .pt: "Ajustar"],
        "brightness": [.en: "Brightness", .fr: "Luminosité", .de: "Helligkeit", .es: "Brillo", .pt: "Brilho"],
        "contrast": [.en: "Contrast", .fr: "Contraste", .de: "Kontrast", .es: "Contraste", .pt: "Contraste"],
        "reset": [.en: "Reset", .fr: "Réinitialiser", .de: "Zurücksetzen", .es: "Restablecer", .pt: "Repor"],
        "done": [.en: "Done", .fr: "OK", .de: "Fertig", .es: "Hecho", .pt: "Concluído"],
        "cancel": [.en: "Cancel", .fr: "Annuler", .de: "Abbrechen", .es: "Cancelar", .pt: "Cancelar"],
        "apply": [.en: "Apply", .fr: "Appliquer", .de: "Anwenden", .es: "Aplicar", .pt: "Aplicar"],
        "save": [.en: "Save", .fr: "Enregistrer", .de: "Speichern", .es: "Guardar", .pt: "Guardar"],
        "auto_crop": [.en: "Auto", .fr: "Auto", .de: "Auto", .es: "Auto", .pt: "Auto"],
        "rotate_left": [.en: "Rotate left", .fr: "Pivoter à gauche", .de: "Links drehen", .es: "Girar a la izquierda", .pt: "Rodar à esquerda"],
        "rotate_right": [.en: "Rotate right", .fr: "Pivoter à droite", .de: "Rechts drehen", .es: "Girar a la derecha", .pt: "Rodar à direita"],
        "rotate": [.en: "Rotate", .fr: "Pivoter", .de: "Drehen", .es: "Girar", .pt: "Rodar"],

        // Annotate / signature
        "signature": [.en: "Signature", .fr: "Signature", .de: "Unterschrift", .es: "Firma", .pt: "Assinatura"],
        "add_signature": [.en: "Add signature", .fr: "Ajouter une signature", .de: "Unterschrift hinzufügen", .es: "Añadir firma", .pt: "Adicionar assinatura"],
        "clear": [.en: "Clear", .fr: "Effacer", .de: "Löschen", .es: "Borrar", .pt: "Limpar"],
        "sign_here": [.en: "Sign here", .fr: "Signez ici", .de: "Hier unterschreiben", .es: "Firme aquí", .pt: "Assine aqui"],
        "undo": [.en: "Undo", .fr: "Annuler", .de: "Rückgängig", .es: "Deshacer", .pt: "Anular"],

        // Settings
        "set_language": [.en: "Language", .fr: "Langue", .de: "Sprache", .es: "Idioma", .pt: "Idioma"],
        "set_default_filter": [.en: "Default filter", .fr: "Filtre par défaut", .de: "Standardfilter", .es: "Filtro predeterminado", .pt: "Filtro predefinido"],
        "set_page_size": [.en: "PDF page size", .fr: "Format de page PDF", .de: "PDF-Seitengröße", .es: "Tamaño de página PDF", .pt: "Tamanho da página PDF"],
        "set_searchable": [.en: "Searchable PDF (OCR)", .fr: "PDF recherchable (OCR)", .de: "Durchsuchbares PDF (OCR)", .es: "PDF con búsqueda (OCR)", .pt: "PDF pesquisável (OCR)"],
        "set_watermark": [.en: "Watermark", .fr: "Filigrane", .de: "Wasserzeichen", .es: "Marca de agua", .pt: "Marca de água"],
        "set_watermark_ph": [.en: "e.g. CONFIDENTIAL", .fr: "ex. CONFIDENTIEL", .de: "z. B. VERTRAULICH", .es: "p. ej. CONFIDENCIAL", .pt: "ex. CONFIDENCIAL"],
        "set_icloud": [.en: "iCloud sync", .fr: "Synchronisation iCloud", .de: "iCloud-Sync", .es: "Sincronización iCloud", .pt: "Sincronização iCloud"],
        "set_icloud_note": [.en: "Requires a paid Apple Developer team and an iCloud container.", .fr: "Nécessite une équipe Apple Developer payante et un conteneur iCloud.", .de: "Erfordert ein kostenpflichtiges Apple-Developer-Team und einen iCloud-Container.", .es: "Requiere un equipo de Apple Developer de pago y un contenedor iCloud.", .pt: "Requer uma equipa Apple Developer paga e um contentor iCloud."],
        "about": [.en: "About", .fr: "À propos", .de: "Über", .es: "Acerca de", .pt: "Acerca de"],
        "version": [.en: "Version", .fr: "Version", .de: "Version", .es: "Versión", .pt: "Versão"],
        "general": [.en: "General", .fr: "Général", .de: "Allgemein", .es: "General", .pt: "Geral"],
        "export_section": [.en: "Export", .fr: "Export", .de: "Export", .es: "Exportar", .pt: "Exportação"],

        // Page sizes
        "size_auto": [.en: "Fit to page", .fr: "Ajusté", .de: "Anpassen", .es: "Ajustar", .pt: "Ajustar"],
        "size_a4": [.en: "A4", .fr: "A4", .de: "A4", .es: "A4", .pt: "A4"],
        "size_letter": [.en: "US Letter", .fr: "US Letter", .de: "US Letter", .es: "Carta (US)", .pt: "Carta (US)"],

        // Status / confirmations
        "processing": [.en: "Processing…", .fr: "Traitement…", .de: "Verarbeitung…", .es: "Procesando…", .pt: "A processar…"],
        "recognizing": [.en: "Recognizing text…", .fr: "Reconnaissance du texte…", .de: "Texterkennung…", .es: "Reconociendo texto…", .pt: "A reconhecer texto…"],
        "no_text_found": [.en: "No text found", .fr: "Aucun texte trouvé", .de: "Kein Text gefunden", .es: "No se encontró texto", .pt: "Nenhum texto encontrado"],
        "text_copied": [.en: "Text copied", .fr: "Texte copié", .de: "Text kopiert", .es: "Texto copiado", .pt: "Texto copiado"],
        "confirm_delete_doc": [.en: "Delete this document?", .fr: "Supprimer ce document ?", .de: "Dieses Dokument löschen?", .es: "¿Eliminar este documento?", .pt: "Eliminar este documento?"],
        "confirm_delete_page": [.en: "Delete this page?", .fr: "Supprimer cette page ?", .de: "Diese Seite löschen?", .es: "¿Eliminar esta página?", .pt: "Eliminar esta página?"],
        "ocr_text": [.en: "Recognized text", .fr: "Texte reconnu", .de: "Erkannter Text", .es: "Texto reconocido", .pt: "Texto reconhecido"]
    ]
}
