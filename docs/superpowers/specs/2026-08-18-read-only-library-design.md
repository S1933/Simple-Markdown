# Bibliothèque privée de documents Markdown en lecture seule

## Objectif

Faire de MarkdownReadOnly un lecteur Markdown pur. Toute modification en place (édition de texte, renommage) disparaît. Le document et son nom sont figés au moment où il entre dans la bibliothèque. Le bouton d’import unique est remplacé par trois sources d’ajout : copier-coller, URL distante, fichier local. Chaque source produit une copie privée et immuable.

## Sources d’ajout

Le bouton `+` propose exactement trois actions :

- `Coller le texte` ouvre une feuille avec un `PasteButton` ; le texte collé est prévisualisé puis ajouté via `DocumentLibrary.add(text:suggestedName:)` avec le nom suggéré `Collé` ;
- `Depuis une URL` ouvre une feuille saisissant une URL HTTPS ; `RemoteMarkdownLoader` récupère le contenu, le valide, puis l’ajoute via `add(text:suggestedName:)` avec le nom suggéré égal au dernier segment de l’URL ;
- `Importer un fichier` ouvre le sélecteur de fichiers limité aux documents Markdown compatibles, via `DocumentLibrary.importDocument(from:)`.

Les trois chemins convergent vers la même dérivation du nom gérée par `DocumentNaming` : premier titre `H1` du texte, sinon le nom suggéré sans extension, sinon `Sans titre`. Si le nom dérivé existe déjà, un suffixe numérique est ajouté afin qu’aucun document ne soit jamais écrasé.

## Immuabilité

Aucune écriture n’est exposée après la création. `DocumentLibrary` ne propose plus `createDocument()`, `save(_:to:)` ni `rename(_:to:)`. Sa surface d’écriture se réduit à `add(text:suggestedName:)` et `importDocument(from:)`. `DocumentReaderView` remplace `DocumentEditorView` : il affiche uniquement `MarkdownPreviewView`, ne détient aucun état de texte mutable et n’effectue aucune écriture. Le titre et le nom de fichier sont fixés à l’ajout.

## Exposition du système de fichiers

Le dossier privé de la bibliothèque n’est plus exposé via l’app Fichiers ni iCloud Drive : les clés `UIFileSharingEnabled` et `LSSupportsOpeningDocumentsInPlace` sont retirées d’`Info.plist`. Le système de fichiers reste la source de vérité interne, mais il ne constitue plus une surface d’édition externe. `UTImportedTypeDeclarations` et `UIAppFonts` sont conservés.

## Récupération par URL

`RemoteMarkdownLoader` récupère et valide le Markdown distant sur `URLSession` via un protocole étroit `URLSessionProtocol` injectable pour les tests. Les règles de validation :

- seul le schéma `https` est accepté (`insecureScheme`) ;
- les URLs `github.com/…/blob/…` sont réécrites vers `raw.githubusercontent.com` afin de récupérer le texte plutôt qu’une page HTML ;
- seules les réponses 2xx sont acceptées ; les autres codes HTTP deviennent `serverError(Int)` ;
- seuls les types de contenu commençant par `text/` ou `application/octet-stream` sont acceptés (`unsupportedContentType`) ;
- la charge utile est plafonnée à 2 Mio (`tooLarge`) ;
- le corps doit être décodable en UTF-8 (`invalidResponse`).

L’import par URL stocke une unique copie immuable. Aucune URL source, aucun fichier annexe, aucun front matter n’est conservé. Il n’existe pas de fonctionnalité de rafraîchissement : l’import est une photographie unique.

## Architecture

`DocumentLibrary` reste l’unique frontière système. `DocumentNaming` centralise la dérivation du nom (H1 → suggestion → repli) afin que les trois sources d’ajout nomment les documents de manière identique. `LibraryView` conserve son rôle de liste et de navigation ; `DocumentReaderView` sert de détail en lecture seule. `MarkdownPreviewView`, `MarkdownPreviewTheme`, `CodeSyntaxHighlighter`, `CodePalette`, `EditorTheme`, `SearchIndex`, `LibrarySearch`, `QueryParser` et toute l’interface de recherche restent inchangés.

## Tests

Les tests unitaires couvrent :

- `DocumentNaming` : préférence du titre H1, repli sur la suggestion, repli sur `Sans titre`, assainissement des caractères interdits, troncature à 120 caractères ;
- `DocumentLibrary.add(text:suggestedName:)` : nom issu du titre, repli sur la suggestion, absence d’écrasement (`Same 2.md`), rejet du texte vide ;
- `RemoteMarkdownLoader` : rejet des URLs non HTTPS, réécriture des URLs blob GitHub, rejet des types non textuels, rejet des charges trop volumineuses, remontée des erreurs HTTP.

Les tests d’interface vérifient que le menu `+` expose les trois actions, que le collage crée et ouvre un document, et qu’aucune surface éditable `document.editor` n’existe.

## Hors périmètre

- synchronisation iCloud propre à l’app ;
- rafraîchissement ou suivi d’une URL distante ;
- renommage, édition ou export après création ;
- dossiers, tags ou tri configurable.
