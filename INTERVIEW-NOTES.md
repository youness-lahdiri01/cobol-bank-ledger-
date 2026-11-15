# Presenting this project at the interview

## The 60-second pitch

> "Pour préparer cet entretien, j'ai voulu écrire du vrai COBOL, pas
> seulement le lire. J'ai construit un petit batch bancaire complet :
> un programme charge un fichier maître de comptes, un deuxième
> applique les transactions du jour — dépôts, retraits — avec
> validation, mise à jour du fichier indexé et édition d'un rapport
> et d'un fichier d'erreurs. Un sous-programme calcule les intérêts.
> Ça compile et ça tourne avec GnuCOBOL, et j'ai joint un JCL
> d'exemple pour z/OS. Les transactions en erreur n'arrêtent pas le
> batch : elles sont journalisées et le traitement continue."

## Architecture (know this by heart)

- **LOADACCT** : lit `accounts.txt` (séquentiel) et construit le
  fichier maître **indexé** (`accounts.idx`), clé = numéro de compte.
  C'est l'équivalent d'un VSAM KSDS.
- **BANKLEDG** : boucle sur `transactions.txt`. Pour chaque
  transaction : validation montant/type → `READ` du compte par clé
  (`INVALID KEY` = compte inconnu) → `EVALUATE` Dépôt/Retrait →
  contrôle de solde → `REWRITE` → `CALL "INTCALC"` → ligne de
  rapport. En cas d'erreur : ligne dans `errors.txt`, compteur
  d'erreurs, on passe à la suivante.
- **INTCALC** : sous-programme, `LINKAGE SECTION`, retourne
  `balance × 0,5 %` (intérêt mensuel projeté).

## Questions likely to come up — and short answers

**Pourquoi COMP-3 pour les soldes ?**
Packed decimal : chaque chiffre tient sur un demi-octet, le signe
sur le dernier. C'est le format standard des montants sur mainframe —
compact, exact (pas d'erreur d'arrondi binaire comme en flottant),
et c'est ce que DB2 et les fichiers VSAM attendent.

**Que fait FILE STATUS ?**
Après chaque `OPEN`, `READ`, `WRITE`, `REWRITE`, COBOL met un code
à 2 caractères : `00` = OK, `23` = clé non trouvée en lecture
indexée, `10` = fin de fichier... Le programme teste ces codes au
lieu de planter : compte inconnu → erreur journalisée, on continue.

**C'est quoi un niveau 88 ?**
Un nom de condition sur une zone : `88 DEPOSIT VALUE "D"`. Ça rend
le code lisible — `IF DEPOSIT` au lieu de `IF T-TYPE = "D"` — et ça
évite les valeurs magiques dispersées dans le code.

**Séquentiel vs indexé ?**
Séquentiel : on lit du début à la fin, parfait pour les transactions
du jour. Indexé (KSDS) : on accède directement à un enregistrement
par sa clé, sans balayer le fichier — indispensable pour le fichier
maître quand on traite des milliers de transactions.

**CALL statique ou dynamique ?**
Ici le sous-programme est compilé avec le programme principal
(`cobc ... BANKLEDG.cbl INTCALC.cbl`) : appel statique, résolu à la
compilation. En dynamique, le module serait chargé à l'exécution —
utile quand plusieurs programmes partagent le même sous-programme,
ou pour le remplacer sans recompiler les appelants.

**Comment on gère un abend en batch ?**
On ne laisse pas le job planter sur la première anomalie : chaque
transaction est validée, les erreurs sont journalisées avec leur
motif, les compteurs alimentent le trailer du rapport, et le
programme rend un code retour (`STOP RUN RETURNING 8` si le fichier
maître ne s'ouvre pas). Le JCL peut ensuite tester ce code retour
(`COND=`) pour décider de la suite du job.

**Qu'est-ce qui manque pour que ce soit "production" ?**
La persistance DB2 au lieu d'un fichier indexé, la gestion des
reprises (restart après abend, avec point de contrôle / commit),
la concurrence (verrouillage d'enregistrement), et les tests
automatisés. C'est un projet d'apprentissage — je le dis
honnêtement, je ne prétends pas à une expérience mainframe.

## Numbers to remember

- 8 transactions testées : 4 appliquées, 4 rejetées
- Comptes : 1000000001 → 15 500,00 après dépôt de 500,00 ;
  1000000002 → 4 200,50 après retrait de 1 000,00 puis dépôt de 2 000,00
- Taux d'intérêt mensuel : 0,5 %
- `PIC S9(9)V99 COMP-3` : 9 chiffres + 2 décimales, signé

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

**Pourquoi trier avant de compter ?**
Sans tri, les tentatives d'un même utilisateur sont dispersées dans
le fichier, et il faudrait tout garder en mémoire pour compter.
Le `SORT` COBOL regroupe d'abord par user puis par date : ensuite
un seul passage séquentiel suffit, avec juste le compteur du groupe
courant. C'est la façon batch classique — et sur mainframe, ce tri
serait un step DFSORT dans le JCL.

**Et si le fichier n'est pas trié en entrée ?**
C'est le `SORT` qui s'en charge — le programme ne suppose rien sur
l'ordre du fichier d'entrée. Les lignes invalides sont triées comme
les autres, puis rejetées à la validation dans la passe de
comptage.

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
