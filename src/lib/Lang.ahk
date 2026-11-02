; Taskbar Pull - user interface text in English and French.
; Language "auto" follows the Windows display language (French for any fr-* language).

global Strings := Map()

LangCode() {
    if (IsObject(S) && S.HasOwnProp("Language") && (S.Language = "en" || S.Language = "fr"))
        return S.Language
    return (DllCall("GetUserDefaultUILanguage", "ushort") & 0x3FF) = 0x0C ? "fr" : "en"
}

; T("key", args*) returns the text in the current language, with {1}, {2}... filled in
T(key, args*) {
    if !Strings.Count
        LangInit()
    if !Strings.Has(key)
        return key
    s := Strings[key][LangCode() = "fr" ? 2 : 1]
    for i, a in args
        s := StrReplace(s, "{" i "}", a)
    return s
}

LangInit() {
    L(k, en, fr) => Strings[k] := [en, fr]
    ; ---- first run
    L("fr.title", "Welcome to Taskbar Pull", "Bienvenue dans Taskbar Pull")
    L("fr.intro", "Taskbar Pull brings a window to the screen you are looking at. Click a window's button on the taskbar of any screen, and the window moves to that screen: minimized or not, maximized or not, even from a combined button's thumbnails."
        , "Taskbar Pull amène une fenêtre sur l'écran que vous regardez. Cliquez sur le bouton d'une fenêtre dans la barre des tâches de n'importe quel écran : la fenêtre vient sur cet écran, qu'elle soit réduite ou non, agrandie ou non, même depuis les miniatures d'un bouton groupé.")
    L("fr.choose", "Choose how it works:", "Choisissez son fonctionnement :")
    L("fr.note", "Nothing changes until you click Start. You can change these choices at any time from the Taskbar Pull icon in the notification area.", "Rien ne change tant que vous n'avez pas cliqué sur Démarrer. Vous pourrez modifier ces choix à tout moment depuis l'icône de Taskbar Pull dans la zone de notification.")
    L("fr.start", "&Start", "&Démarrer")
    L("fr.cancel", "Cancel", "Annuler")
    ; ---- options (first run and settings)
    L("opt.alt", "&Alt+click on a taskbar button pulls the window to that screen", "&Alt+clic sur un bouton de la barre des tâches amène la fenêtre sur cet écran")
    L("opt.plain", "&Plain click (without Alt) also pulls the window", "Clic &simple (sans Alt) amène aussi la fenêtre")
    L("opt.all", "on all screens, including screens connected later", "sur tous les écrans, y compris ceux branchés plus tard")
    L("opt.chosen", "only on the taskbars of these screens:", "seulement sur la barre des tâches de ces écrans :")
    L("opt.notconnected", "{1} (not connected)", "{1} (non branché)")
    L("opt.startup", "Start with &Windows", "Lancer au démarrage de &Windows")
    L("opt.enabled", "&Enabled", "&Activé")
    L("opt.logging", "Write a &log (kept {1} days)", "Écrire un &journal (gardé {1} jours)")
    L("opt.arm", "Wait for the window or thumbnail &pick up to (seconds):", "Attendre la fenêtre ou le choix de &miniature jusqu'à (secondes) :")
    L("opt.lang", "&Language:", "&Langue :")
    L("opt.lang.auto", "Automatic (Windows language)", "Automatique (langue de Windows)")
    ; ---- settings window
    L("set.title", "Taskbar Pull settings", "Paramètres de Taskbar Pull")
    L("set.tabs", "General|Game guard|Advanced", "Général|Protection des jeux|Avancé")
    L("set.screens", "Plain click on these screens", "Clic simple sur ces écrans")
    L("set.guard.intro", "Taskbar Pull never sends a key into a full-screen window or a game listed here. It only sends a harmless key while Alt is held after an Alt+click, so that releasing Alt does not open the window's menu."
        , "Taskbar Pull n'envoie jamais de touche à une fenêtre plein écran ni à un jeu de cette liste. Il n'envoie qu'une touche sans effet pendant qu'Alt est maintenu après un Alt+clic, pour que relâcher Alt n'ouvre pas le menu de la fenêtre.")
    L("set.guard.exes", "Game programs (one .exe name per line):", "Programmes de jeux (un nom de .exe par ligne) :")
    L("set.guard.paths", "Game folders (part of the program's path, one per line):", "Dossiers de jeux (partie du chemin du programme, un par ligne) :")
    L("set.guard.reset", "&Reset to defaults", "&Rétablir les valeurs par défaut")
    L("set.admin", "Ad&min mode: also move windows of apps running as administrator", "Mode ad&ministrateur : déplacer aussi les fenêtres des applications lancées en administrateur")
    L("set.admin.note", "Windows does not let a normal app move the windows of apps that run as administrator. Admin mode starts Taskbar Pull with administrator rights at sign-in, through a scheduled task created after a Windows confirmation (UAC). Switching it off removes the task."
        , "Windows ne laisse pas une application normale déplacer les fenêtres des applications lancées en administrateur. Le mode administrateur démarre Taskbar Pull avec les droits administrateur à l'ouverture de session, par une tâche planifiée créée après une confirmation de Windows (UAC). Le désactiver supprime la tâche.")
    L("set.admin.store", "Admin mode is not available in the Microsoft Store version.", "Le mode administrateur n'est pas disponible dans la version Microsoft Store.")
    L("set.startup.store", "In the Microsoft Store version, Windows controls this: Settings > Apps > Startup.", "Dans la version Microsoft Store, Windows le gère : Paramètres > Applications > Démarrage.")
    L("set.startup.open", "Open startup settings", "Ouvrir les paramètres de démarrage")
    L("set.ok", "OK", "OK")
    L("set.cancel", "Cancel", "Annuler")
    L("set.apply", "A&pply", "A&ppliquer")
    L("set.logs", "Open &log folder", "Ouvrir le dossier du &journal")
    L("set.admin.failed", "Admin mode could not be switched on: {1}", "Impossible d'activer le mode administrateur : {1}")
    L("set.admin.offfailed", "The admin-mode task could not be removed: {1}", "Impossible de supprimer la tâche du mode administrateur : {1}")
    L("set.admin.cancelled", "the Windows confirmation was cancelled", "la confirmation de Windows a été annulée")
    L("set.store.disabledbyuser", "Start with Windows was switched off in Windows settings; switch it on there (Settings > Apps > Startup).", "Le lancement au démarrage a été désactivé dans les paramètres de Windows `; réactivez-le là (Paramètres > Applications > Démarrage).")
    ; ---- tray
    L("tray.enabled", "&Enabled", "&Activé")
    L("tray.settings", "&Settings…", "&Paramètres…")
    L("tray.logs", "Open &log folder", "Ouvrir le dossier du &journal")
    L("tray.about", "&About", "À &propos")
    L("tray.exit", "E&xit", "&Quitter")
    L("tip.on", "Taskbar Pull: on`n{1}", "Taskbar Pull : activé`n{1}")
    L("tip.off", "Taskbar Pull: off", "Taskbar Pull : désactivé")
    L("tip.alt", "Alt+click", "Alt+clic")
    L("tip.plain.all", "plain click: all screens", "clic simple : tous les écrans")
    L("tip.plain.some", "plain click: {1}", "clic simple : {1}")
    L("tip.admin", "admin mode", "mode administrateur")
    ; ---- about
    L("about.title", "About Taskbar Pull", "À propos de Taskbar Pull")
    L("about.text", "Version {1}{2}`n`nBrings a window to the screen whose taskbar you click.`n`nFree and open-source software under the MIT licence.`nCopyright © 2026 Yasser Chkam.`n`nRuns on AutoHotkey {3} (GPL-2.0).", "Version {1}{2}`n`nAmène une fenêtre sur l'écran dont vous cliquez la barre des tâches.`n`nLogiciel libre et gratuit sous licence MIT.`nCopyright © 2026 Yasser Chkam.`n`nFonctionne avec AutoHotkey {3} (GPL-2.0).")
    L("about.store", " (Microsoft Store)", " (Microsoft Store)")
    L("about.site", "Source code and help:", "Code source et aide :")
    ; ---- messages
    L("msg.running", "Taskbar Pull is already running. Its settings are open.", "Taskbar Pull est déjà lancé. Ses paramètres sont ouverts.")
}
