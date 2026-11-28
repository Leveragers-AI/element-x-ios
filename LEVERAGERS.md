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
| ce commit | Connexion par l'adresse e-mail (plan 19 du pool, partie A2). L'écran d'accueil demande l'adresse ; le guichet `login.leveragers.com` (`AppSettings.leveragersFrontDoorURL`, `FrontDoorService`) donne le serveur de chat du domaine (`d/<domaine>.json`), sinon celui du locataire Microsoft (découverte publique de Microsoft puis `t/<id>.json`), sinon le serveur pro `chat.leveragers.com`. Le verrou « un seul serveur » devient une garde : seul un serveur donné par le guichet et nommé sous `.leveragers.com` est accepté (`FrontDoorService.isAllowedServerName`), jamais de choix ni de saisie de serveur, les liens d'approvisionnement restent refusés. Guichet injoignable, lent, refusé ou réponse invalide : « réessayez », l'adresse reste dans le champ, jamais de repli sur le serveur pro ; une erreur de Microsoft mène au serveur pro. La connexion part ensuite sur ce serveur comme pour un lien d'approvisionnement, l'adresse en `login_hint`. Dernière adresse gardée sur l'appareil (`AppSettings.lastSignInEmail`). Remplace l'ouverture automatique de la page de connexion (`opensSignInAutomatically`, `b0a462f`). Textes fr/en dans notre propre fichier `Leveragers.strings` (lus par `LeveragersL10n`), jamais dans ceux d'Element | `ElementX/Sources/Application/Settings/AppSettings.swift`, `ElementX/Sources/Screens/Authentication/StartScreen/{AuthenticationStartScreenModels,AuthenticationStartScreenViewModel,View/AuthenticationStartScreen}.swift` ; fichiers à nous : `ElementX/Sources/Services/Leveragers/FrontDoorService.swift`, `ElementX/Sources/Other/Leveragers/LeveragersL10n.swift`, `ElementX/Resources/Localizations/{en,fr}.lproj/Leveragers.strings`, `UnitTests/Sources/{FrontDoorServiceTests,AuthenticationStartScreenEmailTests}.swift` |

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

Le serveur de chat vient du guichet `login.leveragers.com` (voir la ligne du patch ci-dessus). Chaque serveur qu'il peut
nommer doit donc accepter ce retour (`agents.leveragers.com` dans `oidc_registration_allowed_redirect_hosts`) et lire
le `login_hint` que l'app ajoute à l'adresse de connexion (page de connexion de chaque serveur), sans quoi la personne
retape son adresse.

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
l'identifiant change. Les tests d'Element (unitaires, aperçus, UI) ne sont pas lancés par ce workflow. Chaque build part ensuite au test ouvert (groupe externe « Test ouvert », lien public) : la tâche `open-test`, sur une machine Linux, attend le traitement d'Apple, pose « À tester » (« Corrections et améliorations » / « Fixes and improvements »), ajoute le build au groupe et le soumet à la revue bêta d'Apple (`.github/scripts/testflight_open_test.py`). Cache entre les passages (comme la CI d'Element) : cache de compilation de Xcode (`COMPILATION_CACHE_ENABLE_CACHING`) et paquets Swift (`-clonedSourcePackagesDirPath ~/SourcePackages`), jeté au-delà de 6 Go.
