# Presenting this project at the interview

## The 60-second pitch

> "Pour préparer cet entretien, j'ai voulu écrire du vrai COBOL, pas
> seulement le lire. J'ai construit deux petits programmes simples.
> Le premier, c'est un batch bancaire : il charge les comptes en
> mémoire, applique les transactions du jour — dépôts, retraits —
> avec validation, et il édite un rapport et un fichier d'erreurs.
> Une transaction en erreur n'arrête pas le batch : elle est
> journalisée et le traitement continue. Le deuxième est plus proche
> de mon domaine : un analyseur de journaux de connexion, qui
> signale un compte à partir de trois échecs le même jour — la
> version batch d'une règle de détection brute-force, comme celles
> d'un SIEM. Ça compile et ça tourne avec GnuCOBOL."

## Architecture (know this by heart)

- **BANKLEDG** : lit `accounts.txt` (6 comptes) et les met dans un
  tableau en mémoire (`OCCURS 20 TIMES`). Puis boucle sur
  `transactions.txt`. Pour chaque transaction : validation
  montant/type → recherche du compte dans le tableau → `EVALUATE`
  Dépôt/Retrait → contrôle de solde → ligne de rapport. En cas
  d'erreur : ligne dans `errors.txt`, compteur d'erreurs, on passe
  à la suivante. Tout est en fichiers séquentiels, rien d'indexé.
- **LOGWATCH** : lit `logins.txt` (déjà trié par user puis par
  date), un seul passage : on compte les OK et les KO par groupe
  (même user, même jour). À 3 KO ou plus → `ALERT` dans le rapport.
  Lignes invalides → fichier d'erreurs, sans arrêter le run.

## Questions likely to come up — and short answers

**C'est quoi un niveau 88 ?**
Un nom de condition sur une zone : `88 DEPOSIT VALUE "D"`. Ça rend
le code lisible — `IF DEPOSIT` au lieu de `IF T-TYPE = "D"` — et ça
évite les valeurs magiques dispersées dans le code.

**Pourquoi un tableau en mémoire pour les comptes ?**
Parce que le fichier est petit (6 comptes) : on le charge une fois,
puis chaque transaction cherche son compte dans le tableau avec
`PERFORM VARYING`. Simple à expliquer et à tester. En production,
avec des millions de comptes, on utiliserait un fichier indexé
(VSAM KSDS) ou une base DB2 — le tableau ne passerait plus en
mémoire.

**Séquentiel, ça veut dire quoi ?**
On lit le fichier du début à la fin, ligne par ligne — parfait
pour les transactions du jour et pour un journal de logs. Pas
d'accès direct par clé ici : pour trouver un compte, on parcourt
le tableau.

**Comment on gère une erreur en batch ?**
On ne laisse pas le job planter sur la première anomalie : chaque
transaction est validée, les erreurs sont journalisées avec leur
motif, les compteurs alimentent le résumé du rapport, et le
programme continue avec la transaction suivante.

**Qu'est-ce qui manque pour que ce soit "production" ?**
La persistance (DB2 ou fichier indexé au lieu d'un tableau en
mémoire), la gestion des reprises (restart après abend), la
concurrence, et les tests automatisés. C'est un projet
d'apprentissage — je le dis honnêtement, je ne prétends pas à une
expérience mainframe.

## Numbers to remember

- 8 transactions testées : 4 appliquées, 4 rejetées
- Comptes : 1000000001 → 15 500,00 après dépôt de 500,00 ;
  1000000002 → 4 200,50 après retrait de 1 000,00 puis dépôt de 2 000,00
- Tableau : 20 comptes max, 6 dans le fichier d'exemple

## LOGWATCH — the second program (security angle)

**The 30-second pitch:**

> "Le deuxième programme est plus proche de mon domaine : un
> analyseur de journaux de connexion. Il lit les tentatives — user,
> date, OK ou KO — et il signale un compte à partir de trois échecs
> le même jour. C'est la version batch d'une règle de détection
> brute-force, comme celles qu'on écrit dans un SIEM. La démo montre
> les trois cas : deux échecs, ça ne déclenche rien ; trois échecs,
> alerte ; une ligne invalide, rejetée proprement sans arrêter le
> traitement."

**How to demo it with the recruiter:**

1. Show `data/logins.txt` — 13 lignes, 3 champs, lisible.
2. Explain the rule: même user + même jour + 3 KO = ALERT.
3. Run `./run.sh` (or just `./bin/logwatch`) and open
   `output/logwatch-report.txt` together: `bennis` 15/11 → ALERT,
   `amrani` 2 KO → ok, `idrissi` 1 + 2 KO sur deux jours → ok,
   `bennis` 16/11 2 KO → ok. Then `output/logwatch-errors.txt`:
   la ligne `ZZ` rejetée avec son motif.
4. Point out the threshold is one named constant (`WS-THRESHOLD`
   VALUE 3) — easy to tune, like a SIEM rule threshold.

**Questions likely to come up — and short answers:**

**Pourquoi ça marche sans trier le fichier ?**
Parce que le fichier d'entrée est déjà ordonné par user puis par
date : les tentatives d'un même utilisateur un même jour sont
déjà groupées. Un seul passage suffit, avec juste les compteurs
du groupe courant. Si le fichier n'était pas trié, il faudrait
d'abord le trier — en COBOL avec le verbe `SORT`, ou en JCL avec
un step DFSORT.

**Et si une ligne est invalide ?**
Elle est rejetée dans le fichier d'erreurs avec son motif, et le
traitement continue — le batch ne s'arrête jamais sur une mauvaise
ligne.

**Que se passerait-il en production ?**
L'alerte partirait vers un SIEM (ou un fichier d'alertes consommé
par le SOC), avec corrélation : même IP source, plusieurs comptes,
fenêtre glissante au lieu d'une journée calendaire, et une action —
blocage temporaire du compte, par exemple. Ici le rapport joue ce
rôle, pour que la règle reste vérifiable à l'œil nu.

**Pourquoi 3 échecs, et pas 5 ?**
C'est un seuil de démonstration, comme dans une règle SIEM : assez
bas pour attraper un brute-force, assez haut pour ne pas alerter sur
une simple faute de frappe. En production on le règle avec les
données réelles — et c'est une constante nommée, donc un seul
endroit à changer.
