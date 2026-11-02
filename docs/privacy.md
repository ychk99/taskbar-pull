# Taskbar Pull – Privacy policy

*Last updated: 2 November 2026 · applies to Taskbar Pull 1.0.0 and later (Microsoft Store, installer and portable versions)*

Taskbar Pull is a free, open-source Windows utility published by Yasser Chkam. This policy explains what the app does with your data. Short version: **nothing leaves your PC.**

## What we collect

**Nothing.** Taskbar Pull does not collect, send, sell or share any personal information or usage data.

- It never connects to the internet: it has no network code, no telemetry, no analytics, no crash reporting, no ads and no update checks of its own. (The Microsoft Store version is updated by the Microsoft Store.)
- It has no accounts and asks for no personal details.
- Nobody, including the developer, receives anything from the app.

## What stays on your PC

Taskbar Pull keeps two kinds of files, only on your own computer:

1. **Settings** (`settings.ini`): your choices, such as Alt+click and plain click, which screens react to a plain click, game exclusions, start with Windows and language.
2. **Diagnostic logs**: one file per day (`taskbar-pull-YYYY-MM-DD.log`; a day's file that passes about 5 MB continues in a `.log.1` file). Files older than 14 days are deleted automatically (the number of days can be changed in Settings → Advanced), and logging can be switched off there. The logs help you, or the developer if you choose to send them, understand what the app did. Each line can contain:
   - the date and time;
   - where you clicked (screen coordinates) and the kind of taskbar element clicked;
   - your screen layout (number of screens, their names, size, position and scaling);
   - for windows the app looked at or moved: **the window title**, the program name (for example `notepad.exe`), its process number and whether it runs as administrator, and the window's position and size before and after;
   - when the game guard held back or skipped a key, and why;
   - start, stop and error messages.

   Window titles can contain personal things such as a document name or an e-mail subject. The logs never contain window contents, keystrokes, passwords, files or screenshots, and they are never sent anywhere.

### Where the files are

- Installer and portable versions: settings in `%APPDATA%\Taskbar Pull\`, logs in `%LOCALAPPDATA%\Taskbar Pull\logs\`. The tray menu's **Open log folder** item opens the log folder.
- Microsoft Store version: Windows keeps the app's files in its private package folder under `%LOCALAPPDATA%\Packages\`. **Open log folder** opens it too.

### How to delete them

- Tray menu → **Open log folder**, then delete the log files at any time (exit Taskbar Pull first if a file is in use).
- Uninstalling the Microsoft Store version removes its files automatically. For the installer and portable versions, delete the `%APPDATA%\Taskbar Pull` and `%LOCALAPPDATA%\Taskbar Pull` folders to remove settings and logs; the installer's uninstaller asks whether to keep your settings.

## Sharing a log with the developer

Only if you decide to. If you attach log lines to a GitHub issue, they become public: remove or replace window titles you don't want to show before posting.

## Children

The app collects no data from anyone, including children.

## Changes and contact

Changes to this policy will be published on this page with a new date. Questions: open an issue at https://github.com/ychk99/taskbar-pull/issues.

---

# Taskbar Pull – Politique de confidentialité

*Dernière mise à jour : 2 novembre 2026 · s'applique à Taskbar Pull 1.0.0 et versions suivantes (Microsoft Store, installateur et version portable)*

Taskbar Pull est un utilitaire Windows gratuit et open source publié par Yasser Chkam. Cette politique explique ce que l'application fait de vos données. En bref : **rien ne quitte votre PC.**

## Ce que nous collectons

**Rien.** Taskbar Pull ne collecte, n'envoie, ne vend ni ne partage aucune donnée personnelle ni donnée d'utilisation.

- Elle ne se connecte jamais à Internet : aucun code réseau, aucune télémétrie, aucune statistique, aucun rapport de plantage, aucune publicité, aucune vérification de mise à jour de sa part. (La version Microsoft Store est mise à jour par le Microsoft Store.)
- Elle n'a pas de compte et ne demande aucune information personnelle.
- Personne, développeur compris, ne reçoit quoi que ce soit de l'application.

## Ce qui reste sur votre PC

Taskbar Pull conserve deux types de fichiers, uniquement sur votre ordinateur :

1. **Les réglages** (`settings.ini`) : vos choix, comme l'Alt+clic et le clic simple, les écrans qui réagissent au clic simple, les jeux exclus, le démarrage avec Windows et la langue.
2. **Des journaux de diagnostic** : un fichier par jour (`taskbar-pull-AAAA-MM-JJ.log` ; au-delà d'environ 5 Mo, la journée continue dans un fichier `.log.1`). Les fichiers de plus de 14 jours sont supprimés automatiquement (le nombre de jours se règle dans Réglages → Avancé), et la journalisation peut y être désactivée. Ils servent à comprendre ce que l'application a fait, pour vous ou pour le développeur si vous choisissez de les lui envoyer. Chaque ligne peut contenir :
   - la date et l'heure ;
   - l'endroit du clic (coordonnées à l'écran) et le type d'élément de la barre des tâches cliqué ;
   - la disposition de vos écrans (nombre, noms, taille, position, mise à l'échelle) ;
   - pour les fenêtres examinées ou déplacées : **le titre de la fenêtre**, le nom du programme (par exemple `notepad.exe`), son numéro de processus, s'il tourne en administrateur, et la position et la taille de la fenêtre avant et après ;
   - quand la protection jeux a retenu ou sauté une touche, et pourquoi ;
   - les messages de démarrage, d'arrêt et d'erreur.

   Un titre de fenêtre peut contenir des éléments personnels, comme un nom de document ou l'objet d'un e-mail. Les journaux ne contiennent jamais le contenu des fenêtres, les frappes au clavier, des mots de passe, des fichiers ni des captures d'écran, et ils ne sont jamais envoyés nulle part.

### Où se trouvent les fichiers

- Versions installateur et portable : réglages dans `%APPDATA%\Taskbar Pull\`, journaux dans `%LOCALAPPDATA%\Taskbar Pull\logs\`. Le menu de la zone de notification **Ouvrir le dossier du journal** ouvre ce dossier.
- Version Microsoft Store : Windows range les fichiers de l'application dans son dossier de package privé sous `%LOCALAPPDATA%\Packages\`. **Ouvrir le dossier du journal** l'ouvre aussi.

### Comment les supprimer

- Menu de la zone de notification → **Ouvrir le dossier du journal**, puis supprimez les fichiers journaux quand vous voulez (quittez d'abord Taskbar Pull si un fichier est en cours d'utilisation).
- La désinstallation de la version Microsoft Store supprime automatiquement ses fichiers. Pour les versions installateur et portable, supprimez les dossiers `%APPDATA%\Taskbar Pull` et `%LOCALAPPDATA%\Taskbar Pull` pour effacer réglages et journaux ; le désinstalleur de la version installateur demande s'il faut garder vos réglages.

## Partager un journal avec le développeur

Seulement si vous le décidez. Les lignes de journal jointes à un ticket GitHub deviennent publiques : retirez ou remplacez auparavant les titres de fenêtres que vous ne voulez pas montrer.

## Enfants

L'application ne collecte de données sur personne, enfants compris.

## Modifications et contact

Toute modification de cette politique sera publiée sur cette page avec une nouvelle date. Questions : ouvrez un ticket sur https://github.com/ychk99/taskbar-pull/issues.
