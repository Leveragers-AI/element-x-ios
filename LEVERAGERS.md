# Patchs Leveragers sur Element X iOS

« Agents by Leveragers » : la branche `leveragers` part de l'étiquette officielle Element `release/26.11.0`
(`975651a`, 05/11/2026), avec ces patchs par-dessus. Ce fichier sert à celui qui les rejoue sur une nouvelle
étiquette (rebase) : une ligne par patch, avec les fichiers d'Element qu'il touche. Règle : une étiquette publiée
depuis au moins 14 jours.

| Commit | But | Fichiers d'Element touchés |
|---|---|---|
| `b39a840` | Identité : nom « Agents », `com.leveragers.agents`, groupe `group.com.leveragers.agents`, équipe Apple `FVBUM2YL8B` ; seul domaine associé `webcredentials:agents.leveragers.com` (retour de connexion) ; import d'Element Classic retiré ; droit de filtrage des notifications retiré de la NSE (accordé par Apple à Element seulement) ; couleur de lancement `launch-color` | `app.yml`, `ElementX/SupportingFiles/{target.yml,ElementX.entitlements,Info.plist}`, `NSE/SupportingFiles/{target.yml,NSE.entitlements}` |
| `0a13323` | Serveur `chat.leveragers.com` seul (un bouton sur l'écran d'accueil, pas de QR), connexion OAuth avec retour sur `agents.leveragers.com`, `client_uri` = `https://leveragers.com`, liens (copyright = ce code source, conditions = politique de modération, confidentialité = politique de confidentialité de www.leveragers.com), passerelle de push prévue sur `chat.leveragers.com`, `Secrets.swift` vide (ni statistiques, ni Sentry, ni rapports de bug, ni cartes) | `ElementX/Sources/Application/Settings/AppSettings.swift`, `Components/Secrets/Secrets.swift`, `ElementX/Sources/Screens/Authentication/StartScreen/AuthenticationStartScreenViewModel.swift` |
| `574b32b` | Marque : icône (logo Leveragers plein cadre, sans transparence), logo de l'écran d'accueil (`app-logo.svg`), fond bleu nuit `#0A082B`, écran d'accueil en apparence sombre, « Element X » → « Agents » dans les textes d'autorisation | `ElementX/Resources/AppIcon.icon/Assets/AppIcon.png`, `ElementX/Resources/Assets.xcassets/{images/app-logo.imageset,images/launch-background.imageset,colors/launch-color.colorset}`, `ElementX/Resources/Localizations/*/InfoPlist.strings`, `ElementX/Sources/Screens/Authentication/StartScreen/View/AuthenticationStartScreen.swift` |
| `d2faa73` | Appels masqués (`isCallingEnabled = false`), entrée « Parcourir les salons » retirée | `RoomScreenModels.swift`, `RoomDetailsScreenModels.swift`, `RoomMemberDetailsScreenModels.swift`, `UserProfileScreenModels.swift`, `StartChatScreen.swift` (sous `ElementX/Sources/Screens/`) |
| `b81cfed` | Construction et envoi sur TestFlight par GitHub Actions ; les workflows d'Element sont retirés de la branche | `.github/workflows/*` |
| `560f11d` | Signature manuelle en Release (profils App Store créés par l'API) ; droit « Communication Notifications » retiré le temps que la capacité soit cochée sur l'identifiant (remis au commit suivant) | `ElementX/SupportingFiles/target.yml`, `NSE/SupportingFiles/target.yml`, `ShareExtension/SupportingFiles/target.yml`, `.github/workflows/leveragers-testflight.yml`, `ElementX/SupportingFiles/ElementX.entitlements` |
| `e4ef125` | « Communication Notifications » remis (nom et photo de l'expéditeur dans les notifications) : capacité cochée sur `com.leveragers.agents`, profil App Store recréé | `ElementX/SupportingFiles/{target.yml,ElementX.entitlements}` |
| `46029d4` | Bouton « Inviter des personnes sur Agents » (lien de partage du profil) retiré de l'écran « + » : les comptes sont créés par Leveragers, pas par invitation | `ElementX/Sources/Screens/StartChatScreen/View/StartChatScreen.swift` |
| `66edad8` | iPhone seulement pour l'instant (`TARGETED_DEVICE_FAMILY: "1"`) : la fiche App Store n'exige plus de capture iPad ; un iPad lance la version iPhone. On pourra rouvrir l'iPad dans une version suivante (l'inverse n'est plus possible après une sortie) | `ElementX/SupportingFiles/target.yml`, `NSE/SupportingFiles/target.yml`, `ShareExtension/SupportingFiles/target.yml` |
| `8f66327` | Notre version (1.0.0, montrée aux utilisateurs et sur l'App Store) séparée de celle d'Element : `ELEMENT_VERSION` (26.11.0) reste celle de l'étiquette d'Element, écrite dans l'Info.plist (`ElementVersion`) et lue par les étapes de mise à jour d'Element (`AppCoordinator`), qui comparent les numéros d'Element. **À chaque reprise d'une étiquette d'Element : mettre à jour `ELEMENT_VERSION`, garder `MARKETING_VERSION`.** | `project.yml`, `ElementX/SupportingFiles/target.yml`, `ElementX/Sources/Other/InfoPlistReader.swift`, `ElementX/Sources/Application/AppCoordinator.swift` |
| `64c61fd` | Construction : entrées `open_test`, `unit_tests` et `build` du workflow (reprises de `sync/26.11.3`) ; lancé à la main avec `open_test=false`, le build ne va qu'au groupe interne « Leveragers » ; `unit_tests=true` lance le lint et les tests unitaires d'Element | `.github/workflows/leveragers-testflight.yml` |
| ce commit | Mise à jour de l'app (voir « Mise à jour de l'app » plus bas) : seuils lus sur la porte d'entrée `login.leveragers.com`, écran bloquant ou fenêtre « Mise à jour disponible » dans une fenêtre à nous, au-dessus de celles d'Element ; aucun écran d'Element modifié | `ElementX/Sources/Application/AppCoordinator.swift`, `ElementX/Sources/Application/Settings/AppSettings.swift` (`leveragersFrontDoorURL`) ; neufs : `ElementX/Sources/Services/Leveragers/AppUpdate/*`, `ElementX/Resources/Localizations/{en,fr}.lproj/Leveragers.strings`, `UnitTests/Sources/AppUpdateTests.swift` |

Restent, comme la politique de marque d'Element l'autorise : les mentions des vrais produits Element (Element Call,
sons « Element », message sur l'ancienne application d'appel) et les mentions de droits d'auteur et de licence.
Le code est sous AGPL-3.0 (voir `LICENSE`) : ce dépôt public contient la source exacte de chaque version distribuée.

## Connexion

Element X ouvre la page de connexion dans une `ASWebAuthenticationSession` avec un retour **https**. Apple vérifie que
le domaine du retour appartient à l'app : `https://agents.leveragers.com/.well-known/apple-app-site-association`
liste `FVBUM2YL8B.com.leveragers.agents` dans `webcredentials`. Côté serveur (Tuwunel 2.0.0), l'hôte du retour doit
être dans `oidc_registration_allowed_redirect_hosts` (agents.leveragers.com l'est sur chat.leveragers.com), et
`logo_uri`, `tos_uri`, `policy_uri`, `redirect_uris` doivent partager l'hôte de `client_uri` ou en être un
sous-domaine.

## Construction

`.github/workflows/leveragers-testflight.yml`, sur l'étiquette de machine `xcode-27` de GitHub : `xcodegen`, puis
`xcodebuild archive` et `-exportArchive` en signature **manuelle** (configuration Release des trois cibles :
certificat Apple Distribution, profils App Store « Agents by Leveragers App Store », « … NSE App Store »,
« … Share App Store »), puis envoi sur TestFlight par `altool` (ou Transporter) avec la clé API App Store Connect.
La signature automatique de Xcode avec la clé API a été refusée par Apple (401) au premier essai ; les appels
classiques à l'API avec la même clé passent. Certificat et profils créés par l'API depuis hub2 (clé privée sur hub2
seulement). Numéro de build = numéro d'exécution du workflow ; version = `MARKETING_VERSION` de `project.yml`.
Secrets du dépôt : `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `SIGNING_DIST_P12_BASE64`, `SIGNING_P12_PASSWORD`,
`PROFILE_APP_BASE64`, `PROFILE_NSE_BASE64`, `PROFILE_SHARE_BASE64`. Les profils se recréent quand une capacité de
l'identifiant change. Lancé à la main avec `unit_tests=true`, le workflow passe aussi le lint SwiftFormat et les tests unitaires d'Element (sans les aperçus ni les tests d'interface). Le `ElementX.xcodeproj` du dépôt n'est pas tenu à jour de nos fichiers neufs : chaque construction lance `xcodegen`, qui les reprend des dossiers listés dans les `target.yml`. Chaque build part ensuite au test ouvert (groupe externe « Test ouvert », lien public) : la tâche `open-test`, sur une machine Linux, attend le traitement d'Apple, pose « À tester » (« Corrections et améliorations » / « Fixes and improvements »), ajoute le build au groupe et le soumet à la revue bêta d'Apple (`.github/scripts/testflight_open_test.py`). Cache entre les passages (comme la CI d'Element) : cache de compilation de Xcode (`COMPILATION_CACHE_ENABLE_CACHING`) et paquets Swift (`-clonedSourcePackagesDirPath ~/SourcePackages`), jeté au-delà de 6 Go.

## Mise à jour de l'app

Une version trop ancienne doit pouvoir être bloquée (correctif de sécurité, changement incompatible) sans que les
petites mises à jour de chaque semaine dérangent qui que ce soit. Les seuils sont publiés par Leveragers sur la porte
d'entrée (le stockage Cloudflare de `login.leveragers.com`, plan 19 du pool), dans `app/agents.json` :
`{"v":1,"ios":{"min_build":N,"recommended_build":N,"update_url":"https://…"},"android":{…}}`. L'app compare son
numéro de build (`CFBundleVersion`) aux valeurs `ios`.

- Lecture au lancement et au retour au premier plan, au plus une fois par heure (délai de 8 s). Le fichier n'est
  retenu que s'il est en version 1, avec des builds entiers positifs ou nuls et un lien https ; la dernière copie
  valable est gardée sur le téléphone. Fichier absent ou illisible, réseau coupé, numéro de build illisible : rien
  ne change. Une app bloquée le reste hors ligne ; une installation neuve hors ligne ne montre rien.
- Build < `min_build` : écran plein, logo, « Mise à jour requise » et un seul bouton « Mettre à jour » qui ouvre
  `update_url` ; rien derrière n'est accessible.
- Sinon build < `recommended_build` : fenêtre « Mise à jour disponible », « Mettre à jour » ou « Plus tard ». « Plus
  tard » la cache 3 jours, puis 1 jour une fois l'app en retard depuis 14 jours (compté depuis la première fois où
  l'app s'est vue en retard, remis à zéro dès qu'elle ne l'est plus). Jamais deux fois dans un même lancement ; un
  nouveau build recommandé ne relance pas le délai.
- Une fenêtre à nous (`AppUpdateGate`, niveau au-dessus des trois fenêtres d'Element), créée avec les fenêtres
  d'Element dans `AppCoordinator.windowManagerDidConfigureWindows` ; cachée quand il n'y a rien à montrer, elle
  laisse passer tous les gestes. Règle pure dans `AppUpdateDecision` (testée), lecture et copie gardée dans
  `AppUpdateService` (testé), dans les réglages de l'app (`leveragersAppUpdate*`).
- Textes en anglais et en français dans notre table `Leveragers.strings` (jamais dans les tables d'Element,
  régénérées à chaque synchronisation), choisis dans la langue de l'app comme ceux d'Element.

Pour essayer : publier des seuils de test sur la porte d'entrée (le build installé sous `min_build`, ou entre
`min_build` et `recommended_build`), relancer l'app, puis remettre les seuils à 0.
