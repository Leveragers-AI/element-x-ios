# Patchs Leveragers sur Element X iOS

« Agents by Leveragers » : la branche `leveragers` part de l'étiquette officielle Element `release/26.11.0`
(`975651a`, 05/11/2026), avec ces patchs par-dessus. Ce fichier sert à celui qui les rejoue sur une nouvelle
étiquette (rebase) : une ligne par patch, avec les fichiers d'Element qu'il touche. Règle : une étiquette publiée
depuis au moins 14 jours.

| Commit | But | Fichiers d'Element touchés |
|---|---|---|
| `b39a840` | Identité : nom « Agents », `com.leveragers.agents`, groupe `group.com.leveragers.agents`, équipe Apple `FVBUM2YL8B` ; seul domaine associé `webcredentials:agents.leveragers.com` (retour de connexion) ; import d'Element Classic retiré ; droit de filtrage des notifications retiré de la NSE (accordé par Apple à Element seulement) ; couleur de lancement `launch-color` | `app.yml`, `ElementX/SupportingFiles/{target.yml,ElementX.entitlements,Info.plist}`, `NSE/SupportingFiles/{target.yml,NSE.entitlements}` |
| `0a13323` | Serveur `chat.leveragers.com` seul (un bouton sur l'écran d'accueil, pas de QR), connexion OAuth avec retour sur `agents.leveragers.com`, `client_uri` = `https://leveragers.com`, liens (copyright = ce code source, conditions et confidentialité = www.leveragers.com), passerelle de push prévue sur `chat.leveragers.com`, `Secrets.swift` vide (ni statistiques, ni Sentry, ni rapports de bug, ni cartes) | `ElementX/Sources/Application/Settings/AppSettings.swift`, `Components/Secrets/Secrets.swift`, `ElementX/Sources/Screens/Authentication/StartScreen/AuthenticationStartScreenViewModel.swift` |
| `574b32b` | Marque : icône (logo Leveragers plein cadre, sans transparence), logo de l'écran d'accueil (`app-logo.svg`), fond bleu nuit `#0A082B`, écran d'accueil en apparence sombre, « Element X » → « Agents » dans les textes d'autorisation | `ElementX/Resources/AppIcon.icon/Assets/AppIcon.png`, `ElementX/Resources/Assets.xcassets/{images/app-logo.imageset,images/launch-background.imageset,colors/launch-color.colorset}`, `ElementX/Resources/Localizations/*/InfoPlist.strings`, `ElementX/Sources/Screens/Authentication/StartScreen/View/AuthenticationStartScreen.swift` |
| `d2faa73` | Appels masqués (`isCallingEnabled = false`), entrée « Parcourir les salons » retirée | `RoomScreenModels.swift`, `RoomDetailsScreenModels.swift`, `RoomMemberDetailsScreenModels.swift`, `UserProfileScreenModels.swift`, `StartChatScreen.swift` (sous `ElementX/Sources/Screens/`) |
| `b81cfed` | Construction et envoi sur TestFlight par GitHub Actions ; les workflows d'Element sont retirés de la branche | `.github/workflows/*` |
| ce commit | Signature manuelle en Release (profils App Store créés par l'API) ; droit « Communication Notifications » retiré tant qu'il n'y a pas de push (à remettre avec la passerelle de push, après l'avoir coché sur l'identifiant et recréé le profil) | `ElementX/SupportingFiles/target.yml`, `NSE/SupportingFiles/target.yml`, `ShareExtension/SupportingFiles/target.yml`, `.github/workflows/leveragers-testflight.yml`, `ElementX/SupportingFiles/ElementX.entitlements` |

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
l'identifiant change. Les tests d'Element (unitaires, aperçus, UI) ne sont pas lancés par ce workflow.
