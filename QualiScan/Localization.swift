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
        // License
        "unlimited_docs": [.en: "Unlimited documents", .fr: "Documents illimités", .de: "Unbegrenzte Dokumente", .es: "Documentos ilimitados", .pt: "Documentos ilimitados"],
        "unlimited_docs_detail": [.en: "Scan and keep as many documents as you need.", .fr: "Numérisez et gardez autant de documents que nécessaire.", .de: "Scannen und behalten Sie so viele Dokumente wie nötig.", .es: "Escanea y conserva tantos documentos como necesites.", .pt: "Digitalize e guarde tantos documentos quantos precisar."],
        "license_feature_ocr_title": [.en: "On-device OCR", .fr: "OCR sur l'appareil", .de: "OCR auf dem Gerät", .es: "OCR en el dispositivo", .pt: "OCR no dispositivo"],
        "license_feature_ocr_detail": [.en: "Searchable text in every scan.", .fr: "Texte recherchable dans chaque scan.", .de: "Durchsuchbarer Text in jedem Scan.", .es: "Texto con búsqueda en cada escaneo.", .pt: "Texto pesquisável em cada digitalização."],
        "license_feature_export_title": [.en: "Searchable PDF export", .fr: "Export PDF recherchable", .de: "Durchsuchbarer PDF-Export", .es: "Exportación de PDF con búsqueda", .pt: "Exportação de PDF pesquisável"],
        "license_feature_export_detail": [.en: "Multi-page PDFs, with an optional watermark.", .fr: "PDF multi-pages, avec filigrane en option.", .de: "Mehrseitige PDFs, mit optionalem Wasserzeichen.", .es: "PDFs multipágina, con marca de agua opcional.", .pt: "PDFs multipágina, com marca de água opcional."],

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
        "support": [.en: "Support & ideas", .fr: "Support et idées", .de: "Support & Ideen", .es: "Soporte e ideas", .pt: "Suporte e ideias"],
        "data_privacy": [.en: "Data & Privacy", .fr: "Données et confidentialité", .de: "Daten & Datenschutz", .es: "Datos y privacidad", .pt: "Dados e privacidade"],
        "privacy_policy": [.en: "Privacy Policy", .fr: "Politique de confidentialité", .de: "Datenschutzerklärung", .es: "Política de privacidad", .pt: "Política de privacidade"],
        "delete_all_data": [.en: "Delete all data", .fr: "Effacer toutes les données", .de: "Alle Daten löschen", .es: "Eliminar todos los datos", .pt: "Eliminar todos os dados"],
        "delete_all": [.en: "Delete everything", .fr: "Tout supprimer", .de: "Alles löschen", .es: "Eliminar todo", .pt: "Eliminar tudo"],
        "delete_all_data_msg": [.en: "This permanently deletes every document, page and image from this device. This can't be undone.", .fr: "Cela supprime définitivement tous les documents, pages et images de cet appareil. Action irréversible.", .de: "Dies löscht alle Dokumente, Seiten und Bilder dauerhaft von diesem Gerät. Nicht widerrufbar.", .es: "Esto elimina permanentemente todos los documentos, páginas e imágenes de este dispositivo. No se puede deshacer.", .pt: "Isto elimina permanentemente todos os documentos, páginas e imagens deste dispositivo. Não pode ser anulado."],
        "on_device_note": [.en: "All your scans stay on this device — QualiScan has no account and no server.", .fr: "Tous vos scans restent sur cet appareil — QualiScan n'a ni compte ni serveur.", .de: "Alle Scans bleiben auf diesem Gerät — QualiScan hat kein Konto und keinen Server.", .es: "Todos tus escaneos permanecen en este dispositivo — QualiScan no tiene cuenta ni servidor.", .pt: "Todas as digitalizações ficam neste dispositivo — o QualiScan não tem conta nem servidor."],

        // Paywall / Pro
        "pay_subtitle": [.en: "Scan without limits and unlock everything.", .fr: "Scannez sans limite et débloquez tout.", .de: "Scanne ohne Limit und schalte alles frei.", .es: "Escanea sin límites y desbloquéalo todo.", .pt: "Digitalize sem limites e desbloqueie tudo."],
        "pay_feat_unlimited": [.en: "Unlimited documents", .fr: "Documents illimités", .de: "Unbegrenzte Dokumente", .es: "Documentos ilimitados", .pt: "Documentos ilimitados"],
        "pay_feat_ocr": [.en: "OCR & searchable PDF", .fr: "OCR & PDF recherchable", .de: "OCR & durchsuchbares PDF", .es: "OCR y PDF con búsqueda", .pt: "OCR e PDF pesquisável"],
        "pay_feat_export": [.en: "Export & share without limits", .fr: "Export & partage sans limite", .de: "Export & Teilen ohne Limit", .es: "Exportar y compartir sin límites", .pt: "Exportar e partilhar sem limites"],
        "pay_feat_support": [.en: "Support future updates", .fr: "Soutenez les futures mises à jour", .de: "Unterstütze künftige Updates", .es: "Apoya futuras actualizaciones", .pt: "Apoie futuras atualizações"],
        "pay_subscribe": [.en: "Start free trial", .fr: "Commencer l'essai gratuit", .de: "Kostenlos testen", .es: "Iniciar prueba gratis", .pt: "Iniciar teste grátis"],
        "pay_per_year": [.en: "then %@ / year", .fr: "puis %@ / an", .de: "danach %@ / Jahr", .es: "luego %@ / año", .pt: "depois %@ / ano"],
        "pay_restore": [.en: "Restore Purchases", .fr: "Restaurer les achats", .de: "Käufe wiederherstellen", .es: "Restaurar compras", .pt: "Restaurar compras"],
        "pay_terms": [.en: "7-day free trial, then auto-renewing yearly. Cancel anytime in the App Store.", .fr: "Essai gratuit de 7 jours, puis abonnement annuel à renouvellement automatique. Annulable à tout moment dans l'App Store.", .de: "7 Tage gratis, danach jährlich automatisch verlängert. Jederzeit im App Store kündbar.", .es: "Prueba gratis de 7 días, luego suscripción anual con renovación automática. Cancela cuando quieras en la App Store.", .pt: "Teste grátis de 7 dias, depois subscrição anual com renovação automática. Cancele quando quiser na App Store."],
        "pro_active": [.en: "QualiScan Pro active", .fr: "QualiScan Pro actif", .de: "QualiScan Pro aktiv", .es: "QualiScan Pro activo", .pt: "QualiScan Pro ativo"],
        "get_pro": [.en: "Unlock QualiScan Pro", .fr: "Débloquer QualiScan Pro", .de: "QualiScan Pro freischalten", .es: "Desbloquear QualiScan Pro", .pt: "Desbloquear o QualiScan Pro"],

        // Account / auth
        "account": [.en: "Account", .fr: "Mon compte", .de: "Konto", .es: "Mi cuenta", .pt: "Conta"],
        "account_intro": [.en: "Sign in to sync your Crazy Bee Labs account across your apps. Optional — QualiScan works fully without one.", .fr: "Connecte-toi pour retrouver ton compte Crazy Bee Labs dans toutes tes apps. Optionnel — QualiScan marche sans compte.", .de: "Melde dich an, um dein Crazy-Bee-Labs-Konto überall zu nutzen. Optional — QualiScan funktioniert auch ohne.", .es: "Inicia sesión para usar tu cuenta Crazy Bee Labs en tus apps. Opcional — QualiScan funciona sin cuenta.", .pt: "Inicia sessão para usar a tua conta Crazy Bee Labs nas apps. Opcional — o QualiScan funciona sem conta."],
        "sign_in": [.en: "Sign in", .fr: "Se connecter", .de: "Anmelden", .es: "Iniciar sesión", .pt: "Iniciar sessão"],
        "sign_out": [.en: "Sign out", .fr: "Se déconnecter", .de: "Abmelden", .es: "Cerrar sesión", .pt: "Terminar sessão"],
        "sign_in_subtitle": [.en: "Sign in or create an account", .fr: "Se connecter ou créer un compte", .de: "Anmelden oder Konto erstellen", .es: "Inicia sesión o crea una cuenta", .pt: "Inicia sessão ou cria uma conta"],
        "create_account": [.en: "Create account", .fr: "Créer un compte", .de: "Konto erstellen", .es: "Crear cuenta", .pt: "Criar conta"],
        "have_account": [.en: "Already have an account? Sign in", .fr: "Déjà un compte ? Se connecter", .de: "Schon ein Konto? Anmelden", .es: "¿Ya tienes cuenta? Inicia sesión", .pt: "Já tens conta? Inicia sessão"],
        "no_account": [.en: "No account? Create one", .fr: "Pas de compte ? En créer un", .de: "Kein Konto? Erstellen", .es: "¿Sin cuenta? Crea una", .pt: "Sem conta? Cria uma"],
        "email": [.en: "Email", .fr: "E-mail", .de: "E-Mail", .es: "Correo", .pt: "E-mail"],
        "password": [.en: "Password", .fr: "Mot de passe", .de: "Passwort", .es: "Contraseña", .pt: "Palavra-passe"],
        "your_name": [.en: "Your name", .fr: "Ton nom", .de: "Dein Name", .es: "Tu nombre", .pt: "O teu nome"],
        "forgot_password": [.en: "Forgot your password?", .fr: "Mot de passe oublié ?", .de: "Passwort vergessen?", .es: "¿Olvidaste tu contraseña?", .pt: "Esqueceste-te da palavra-passe?"],
        "reset_email_sent": [.en: "If that email exists, a reset link is on its way.", .fr: "Si cet e-mail existe, un lien de réinitialisation arrive.", .de: "Falls die E-Mail existiert, kommt ein Reset-Link.", .es: "Si ese correo existe, te enviamos un enlace.", .pt: "Se esse e-mail existir, enviámos um link."],
        "continue_google": [.en: "Continue with Google", .fr: "Continuer avec Google", .de: "Mit Google fortfahren", .es: "Continuar con Google", .pt: "Continuar com Google"],
        "or_email": [.en: "or with email", .fr: "ou par e-mail", .de: "oder per E-Mail", .es: "o con correo", .pt: "ou com e-mail"],
        "delete_account": [.en: "Delete account", .fr: "Supprimer le compte", .de: "Konto löschen", .es: "Eliminar cuenta", .pt: "Eliminar conta"],
        "delete_account_msg": [.en: "This permanently deletes your Crazy Bee Labs account and its data (invoices are kept only as legally required). This can't be undone.", .fr: "Cela supprime définitivement ton compte Crazy Bee Labs et ses données (les factures sont conservées uniquement si la loi l'exige). Irréversible.", .de: "Dies löscht dein Crazy-Bee-Labs-Konto und seine Daten dauerhaft (Rechnungen nur soweit gesetzlich nötig). Nicht widerrufbar.", .es: "Esto elimina permanentemente tu cuenta Crazy Bee Labs y sus datos (las facturas se conservan solo si la ley lo exige). Irreversible.", .pt: "Isto elimina permanentemente a tua conta Crazy Bee Labs e os seus dados (faturas mantidas só se a lei exigir). Irreversível."],
        "field_required": [.en: "Enter a valid email and password.", .fr: "Saisis un e-mail et un mot de passe valides.", .de: "Gültige E-Mail und Passwort eingeben.", .es: "Introduce un correo y contraseña válidos.", .pt: "Introduz um e-mail e palavra-passe válidos."],
        "auth_generic_error": [.en: "Something went wrong. Please try again.", .fr: "Une erreur est survenue. Réessaie.", .de: "Etwas ist schiefgelaufen. Bitte erneut versuchen.", .es: "Algo salió mal. Inténtalo de nuevo.", .pt: "Algo correu mal. Tenta novamente."],
        "auth_network_error": [.en: "No connection. Check your network and try again.", .fr: "Pas de connexion. Vérifie ton réseau et réessaie.", .de: "Keine Verbindung. Netzwerk prüfen und erneut versuchen.", .es: "Sin conexión. Revisa tu red e inténtalo de nuevo.", .pt: "Sem ligação. Verifica a rede e tenta novamente."],
        "google_setup_needed": [.en: "Google sign-in isn't set up yet.", .fr: "La connexion Google n'est pas encore configurée.", .de: "Google-Anmeldung ist noch nicht eingerichtet.", .es: "El inicio con Google aún no está configurado.", .pt: "O início com Google ainda não está configurado."],
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
