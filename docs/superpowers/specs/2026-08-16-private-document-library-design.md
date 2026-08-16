# Bibliothèque privée de documents Markdown

## Objectif

Au premier lancement, SimpleMarkdown affiche une bibliothèque vide. L’app ne recherche et n’affiche aucun fichier déjà présent sur l’iPhone. Chaque document visible est soit créé dans l’app, soit explicitement importé par l’utilisateur.

## Expérience utilisateur

L’écran d’accueil présente la liste des documents gérés par SimpleMarkdown. Quand la liste est vide, il affiche un message explicatif et un bouton d’ajout.

Le bouton `+` propose deux actions :

- `Nouveau document` crée et ouvre un fichier Markdown vide ;
- `Importer` ouvre le sélecteur de fichiers limité aux documents Markdown compatibles.

Un nouveau document reçoit le nom `Sans titre.md`. Si ce nom existe déjà, l’app choisit `Sans titre 2.md`, puis incrémente le suffixe.

Lors d’un import, l’app copie le fichier sélectionné dans sa bibliothèque privée. Le fichier source reste inchangé. Si un fichier du même nom existe, la copie reçoit un suffixe numérique afin qu’aucun document ne soit écrasé.

Toucher un document ouvre l’éditeur existant. Les modifications sont enregistrées automatiquement dans la copie privée. Un glissement permet de supprimer un document de la bibliothèque après confirmation ; cette action ne touche jamais le fichier source d’un import.

## Architecture

`DocumentGroup` est remplacé par une scène `WindowGroup` contenant une navigation propre à l’app. Ce changement retire le navigateur de documents système qui expose actuellement les fichiers Markdown présents dans Fichiers et iCloud Drive.

Un composant `DocumentLibrary` constitue l’unique interface de stockage. Il reçoit l’URL de son dossier racine, ce qui permet d’utiliser le dossier privé de production dans l’app et un dossier temporaire dans les tests. Il fournit les opérations suivantes :

- lister les documents Markdown gérés ;
- créer un document vide avec un nom unique ;
- importer un fichier par copie avec un nom unique ;
- lire et enregistrer le texte UTF-8 d’un document ;
- supprimer un document géré.

La source de vérité reste le système de fichiers. Aucune base de données ni index parallèle n’est ajouté. La liste est reconstruite depuis le seul dossier privé de la bibliothèque, triée par date de modification décroissante puis par nom pour assurer un ordre stable.

## Composants d’interface

`LibraryView` affiche l’état vide, la liste, le menu d’ajout, le sélecteur d’import et les erreurs compréhensibles par l’utilisateur.

`DocumentEditorView` adapte l’éditeur actuel à un document identifié par son URL privée. Il charge le texte à l’ouverture et demande à `DocumentLibrary` de l’enregistrer après chaque modification. Le moteur de style Markdown et le compteur de mots restent inchangés.

## Gestion des fichiers et erreurs

La bibliothèque accepte les extensions Markdown déclarées par l’app : `.md`, `.markdown` et `.mdown`. Un import non lisible, un échec de copie, de sauvegarde ou de suppression affiche une alerte et conserve l’état précédent autant que possible.

Les écritures utilisent une opération atomique afin d’éviter un fichier partiellement écrit si l’app est interrompue. La création et l’import ne remplacent jamais silencieusement un document existant.

## Persistance et confidentialité

Le dossier de bibliothèque appartient au conteneur privé de SimpleMarkdown. Aucun scan de Fichiers, d’iCloud Drive ou des documents d’autres apps n’est effectué. Les documents persistent entre les lancements et sont inclus dans les sauvegardes normales de l’appareil.

## Tests

Les tests de `DocumentLibrary` utilisent un dossier temporaire et couvrent :

- une bibliothèque neuve est vide ;
- seuls les fichiers Markdown du dossier privé sont listés ;
- un nouveau document vide reçoit un nom unique ;
- un import crée une copie et ne modifie pas la source ;
- deux imports homonymes sont conservés sous des noms distincts ;
- les modifications persistent après rechargement ;
- la suppression retire uniquement la copie privée ;
- une erreur de lecture ou d’écriture est propagée à l’interface.

Un test d’interface vérifie que le premier lancement présente l’état vide et que le menu `+` expose les deux actions attendues.

## Hors périmètre

- synchronisation iCloud propre à l’app ;
- liens permanents vers les fichiers originaux ;
- dossiers, tags, recherche ou tri configurable ;
- export et partage, qui pourront être ajoutés séparément.
