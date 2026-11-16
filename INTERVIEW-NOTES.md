# Presenting this project at the interview

## The 30-second pitch

> "Pour préparer cet entretien, j'ai voulu écrire du vrai COBOL, pas
> seulement le lire. J'ai construit un petit programme simple, proche
> de mon domaine : un analyseur de journaux de connexion. Il lit les
> tentatives — user, date, OK ou KO — et il signale un compte à
> partir de trois échecs le même jour. C'est la version batch d'une
> règle de détection brute-force, comme celles qu'on écrit dans un
> SIEM. Ça compile et ça tourne avec GnuCOBOL."

## How it works (know this by heart)

- **Entrée** : `data/logins.txt` — 13 lignes, 3 champs (user, date
  `AAAAMMJJ`, résultat OK/KO). Le fichier est déjà trié par user
  puis par date.
- **Un seul passage séquentiel** : on compte les OK et les KO par
  groupe (même user, même jour). Quand le user ou le jour change,
  on "ferme" le groupe : on écrit sa ligne dans le rapport.
- **Règle** : 3 KO ou plus dans le groupe → `ALERT` dans
  `output/logwatch-report.txt`.
- **Lignes invalides** (mauvaise date, résultat autre que OK/KO,
  user manquant) → `output/logwatch-errors.txt` avec le motif, sans
  arrêter le programme.
- **Seuil** : une seule constante nommée (`WS-THRESHOLD VALUE 3`) —
  un seul endroit à changer, comme le seuil d'une règle SIEM.

## How to demo it with the recruiter

1. Show `data/logins.txt` — 13 lignes, 3 champs, lisible.
2. Explain the rule: même user + même jour + 3 KO = ALERT.
3. Run `./run.sh` (or just `./bin/logwatch`) and open
   `output/logwatch-report.txt` together: `bennis` 15/11 → ALERT,
   `amrani` 2 KO → ok, `idrissi` 1 + 2 KO sur deux jours → ok,
   `bennis` 16/11 2 KO → ok. Then `output/logwatch-errors.txt`:
   la ligne `ZZ` rejetée avec son motif.
4. Point out the threshold is one named constant — easy to tune,
   like a SIEM rule threshold.

## Questions likely to come up — and short answers

**C'est quoi un niveau 88 ?**
Un nom de condition sur une zone : `88 FIRST-GROUP VALUE "Y"`.
Ça rend le code lisible — `IF FIRST-GROUP` au lieu de comparer la
zone — et ça évite les valeurs magiques dispersées dans le code.

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

**Qu'est-ce qui manque pour que ce soit "production" ?**
La corrélation multi-sources (IP, plusieurs comptes), la fenêtre
glissante, l'envoi réel vers un SIEM, et les tests automatisés.
C'est un projet d'apprentissage — je le dis honnêtement, je ne
prétends pas à une expérience mainframe.

## Numbers to remember

- 13 lignes lues : 5 groupes user/jour, 1 alerte, 1 ligne invalide
- `bennis` 15/11 : 4 tentatives, 3 KO → ALERT
- Seuil : 3 échecs (`WS-THRESHOLD VALUE 3`)
