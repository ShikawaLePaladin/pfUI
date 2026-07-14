# pfUI — Turtle WoW Edition (running on OctoWoW client)

## Ce que c'est

Fork de **pfUI** (UI replacement complet pour WoW 1.12/Vanilla, créé à l'origine par Shagu :
https://github.com/shagu/pfUI) maintenu par **me0wg4ming** (https://github.com/me0wg4ming/pfUI),
spécialisé pour le serveur privé **Turtle WoW**. Version actuelle : `8.3.0` (voir `pfUI.toc`).

L'auteur original de ce fork a arrêté de jouer/maintenir le projet. On reprend le développement
depuis ce point. Le repo git local (`.git`, remote `origin` = `me0wg4ming/pfUI`) est propre,
sur `master`, à jour avec origin — on part d'une base saine.

**⚠️ Point d'attention majeur : ce fork cible Turtle WoW, pas OctoWoW.**
Le client local tourne sous `I:\OctoWow\...`, mais aucune référence à "Octo"/"OctoWoW" n'existe
dans le code — tout est écrit pour l'API/les globals spécifiques de Turtle WoW. Concrètement :
- `modules/turtle-wow.lua` (4200+ lignes) se désactive proprement si les globals Turtle
  (`TargetHPText`, `TargetHPPercText`, GroupUI Turtle, Turtle Shop, Transmog frame...)
  n'existent pas — donc ça ne casse rien sur OctoWoW, mais toutes ces features
  (GroupUI, zone overlays 1.18.1, Turtle Shop skin, transmog skin) sont **inertes** sur OctoWoW.
- Avant d'ajouter des features "OctoWoW-specific", il faut d'abord vérifier ce qu'OctoWoW
  expose réellement comme API/globals custom (à explorer en jeu avec `/run` et en inspectant
  les autres addons fournis par OctoWoW dans `I:\OctoWow\Interface\AddOns\`).
- Décision à prendre avec l'utilisateur avant d'investir du temps : est-ce qu'on (a) garde le
  fork générique Vanilla/Turtle et on ignore les features Turtle-only, (b) on crée un module
  `octowow.lua` analogue à `turtle-wow.lua` pour les intégrations spécifiques à OctoWoW,
  ou (c) on essaie de faire remonter les changements utiles vers le pfUI original de Shagu.

## Dépendances externes (DLLs)

- **Nampower** — REQUIS (min version 3.0.0+ depuis la 8.0.0). Toute la détection de sorts/casts
  passe par son API (`GetSpellRecField`, `GetUnitField`, `GetNampowerVersion`).
  Vérif en jeu : `/run print(GetNampowerVersion())`.
- **SuperWoW** — dépendance retirée en 8.0.0 (tous les fallbacks `UNIT_CASTEVENT`,
  `UnitCastingInfo`/`UnitChannelInfo` SuperWoW ont été remplacés par l'API Nampower).
  Le module `modules/superwow.lua` existe encore mais n'est plus une dépendance dure.
- **UnitXP_SP3** — optionnel, utilisé pour distance précise (`modules/unitxp.lua`, `librange.lua`).

**Sur OctoWoW, il faut vérifier lesquelles de ces DLLs sont supportées/autorisées par le
launcher/serveur avant de considérer une feature comme fonctionnelle.** Une régression classique :
du code qui suppose Nampower présent sans fallback plantera silencieusement (ou avec une popup
de warning, cf. `pfUI.lua`) si le serveur ne l'autorise pas.

## Architecture

Point d'entrée : `pfUI.toc` → charge `pfUI.lua` puis les fichiers XML d'`init/` dans cet ordre :
`env.xml` → `compat.xml` → `api.xml` → `libs.xml` → `skins.xml` → `modules.xml`.

```
pfUI.lua          Bootstrap, namespace pfUI global, RegisterModule(), gestion évènements de base
init/*.xml        Manifestes de chargement (ordre = dépendances)
env/               Locales (7 langues), profils SavedVariables, tables partagées
compat/            Compat Vanilla (1.12) vs TBC (interface 11200 = vanilla ici, cf. .toc)
api/               api.lua (helpers génériques), config.lua (GUI config), unitframes.lua, ui-widgets.lua
libs/              "Librairies" internes réutilisées par plusieurs modules :
                     libcast, libdebuff (2143 lignes — le cœur du tracking buff/debuff/cast),
                     libhealth, libpredict (prédiction de heal/HoT), librange, libspell,
                     libthrottle (throttling des OnUpdate), libtipscan, libtooltip, libtotem, libunitscan
modules/           ~90 fichiers, un par feature UI (actionbar, nameplates, castbar, raid, group,
                     buffwatch, swingtimer, minimap, chat, bags, tooltip, ...). Chaque module
                     s'enregistre via pfUI:RegisterModule("nom", "vanilla"|"tbc", function() ... end)
skins/blizzard/    Reskin des frames Blizzard natives (character, spellbook, talents, AH...)
```

Fichiers les plus critiques / les plus modifiés historiquement (cf. `git log`, `README.md`) :
- `libs/libdebuff.lua` (2143 lignes) — tracking centralisé des buffs/debuffs/casts via events
  Nampower (`SPELL_GO_SELF/OTHER`, `AURA_CAST_ON_SELF/OTHER`, `DEBUFF_ADDED/REMOVED_OTHER`...).
  Expose un système de hooks public (`pfUI.libdebuff_*_hooks`) pour que d'autres addons s'y greffent
  sans dupliquer l'écoute d'events — voir section dédiée dans `README.md`.
- `modules/nameplates.lua` (2032 lignes) — nameplates custom (castbar dédiée, debuff timers, throttle).
- `modules/turtle-wow.lua` (4211 lignes) — toutes les intégrations Turtle-spécifiques.
- `modules/castbar.lua`, `modules/swingtimer.lua`, `modules/unitframes` (dans `api/unitframes.lua`).

## Conventions de code (à respecter)

- **Lua 5.0 / WoW 1.12 API only** — pas de `#` sur tables non-séquentielles fiable, pas de
  `string.format` moderne au-delà de ce que 5.0 supporte, limite de **locals par fonction**
  (le README mentionne un contournement "Lua 5.0 local variable limit" en déplaçant des tables
  vers le namespace `pfUI.*` — si une fonction dépasse la limite de locals, c'est le pattern à réutiliser).
- Namespace global unique : tout passe par la table `pfUI` (`pfUI.api.*`, `pfUI.uf.*`, hooks, etc.).
  Ne jamais créer de nouveaux globals sauvages.
- Modules déclarés via `pfUI:RegisterModule(name, "vanilla"/"tbc", function() ... end)` — regarder
  un module existant simple (ex. `modules/farmmode.lua` ou `modules/combopoints.lua`) comme gabarit
  avant d'en écrire un nouveau.
- Perf-sensible par nature : tout ce qui tourne en `OnUpdate` doit être throttled
  (voir `libs/libthrottle.lua` — pattern déjà utilisé partout, à réutiliser plutôt que réinventer).
  Le changelog du README montre un historique récurrent de bugs de perf (scans `pairs()` non
  nécessaires, GC churn, tables recréées à chaque tick) — être vigilant sur ce point dans tout nouveau code.
- Pas de tests automatisés possibles (client WoW, pas de runtime Lua headless configuré ici) :
  toute validation se fait **en jeu**. Documenter précisément la procédure de repro/vérif dans les
  commits/PRs (cf. style du changelog existant dans `README.md`, très détaillé sur le "pourquoi").

## Style de changelog / documentation

Le `README.md` (1700+ lignes) contient un changelog très détaillé par version, avec sections
"Added/Fixed/Changed/Removed" et des explications techniques du "pourquoi" (pas juste le "quoi").
**Continuer ce style** pour toute nouvelle version : c'est ce qui permet de comprendre 6 mois plus
tard pourquoi un fix bizarre a été fait. Mettre à jour `## Version:` dans `pfUI.toc` +
`pfUI-tbc.toc` en cohérence avec toute release.

## Known issues actuels (cf. README section "Known Issues")

- 40-man raids avec 5+ druids : non testé (stress test du slot-shifting des debuffs).
- Target-swapping rapide + spam Ferocious Bite : non testé.
- Race condition `DEBUFF_ADDED` vs `AURA_CAST_ON_SELF` (ordre d'arrivée des events pas garanti).
- Multi-caster tracking en gros raids (AQ40/Naxx) : partiellement testé.

## Branches distantes existantes (non fusionnées sur master)

`experiment`, `gryphons`, `libcast-haste`, `mrrosh-master`, `tmp-auctionhouse`, `tmp-messenger`,
`tmp-sandbox-wotlk`, `vanillaplus`, `buff_remover_testbranch` — à inspecter avant de repartir de
zéro sur une feature, du travail inachevé ou expérimental peut déjà exister dessus.

## Prochaines étapes suggérées pour reprendre le projet

1. Clarifier avec l'utilisateur le statut OctoWoW vs Turtle WoW (voir point d'attention en haut) —
   décide si on garde `turtle-wow.lua` tel quel (inerte sur OctoWoW) ou si on investit dans un
   module OctoWoW dédié.
2. Vérifier en jeu ce qui fonctionne/casse actuellement sur OctoWoW (`/run print(GetNampowerVersion())`,
   activer chaque module un par un si des erreurs Lua apparaissent au login).
3. Regarder les issues GitHub ouvertes sur `me0wg4ming/pfUI` (si accessibles) et les branches
   `tmp-*`/`experiment` pour lister le travail en cours non mergé.
4. Reprendre le changelog à partir de 8.3.0 pour toute nouvelle modif, en gardant le niveau de
   détail existant.
