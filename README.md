# COBOL Bank Ledger — Daily Batch Processing

A small, complete COBOL batch system: it applies a day's banking
transactions to a master account file and produces a report and an
error file — the kind of nightly batch job that still runs on
mainframes in banking IT (TMA / maintenance applicative).

Built in November 2026 as a learning project to prepare for a COBOL
interview: the goal was to write real, runnable COBOL — not to claim
production mainframe experience. It compiles and runs locally with
[GnuCOBOL](https://gnucobol.sourceforge.io/); a sample z/OS JCL is
included in `jcl/` to show how the same programs run on the mainframe.

## What it does

1. **LOADACCT** builds the master account file from a flat list
   (`data/accounts.txt` → `data/accounts.idx`).
   The master file is `ORGANIZATION IS INDEXED` with the account
   number as `RECORD KEY` — the VSAM KSDS equivalent.
2. **BANKLEDG** reads the day's transactions (`data/transactions.txt`),
   one by one:
   - validates the amount and the transaction type (`D` deposit / `W` withdrawal),
   - reads the account by key (`READ ... INVALID KEY` → account not found),
   - applies the movement, refusing withdrawals above the balance,
   - rewrites the master record (`REWRITE`),
   - calls the **INTCALC** subprogram to compute the projected monthly
     interest (0.5%) for the updated account,
   - writes a report line; rejected transactions go to `output/errors.txt`
     with the reason, and processing continues.
3. The report ends with a trailer: transactions read, applied,
   errors, total deposits and withdrawals.

Sample run: 8 transactions → 4 applied (2 deposits, 2 withdrawals),
4 rejected (insufficient funds, unknown account, invalid type,
zero amount). See `output/report.txt` after a run.

## LOGWATCH — login-log analyzer (second program)

A brute-force detection rule, in batch form — the SOC side of the
project. `LOGWATCH` reads `data/logins.txt`: one line per login
attempt, three fields — user id, date (`YYYYMMDD`), result (`OK`
or `KO`).

**Rule: 3 or more failed logins (KO) for the same user on the same
day = ALERT.**

How it works: the COBOL `SORT` verb first orders the log by user,
then by date, so all attempts of one user on one day sit together;
then a single sequential pass counts OK and KO per user/day group.
Groups at or above the threshold are written to
`output/logwatch-report.txt` as `ALERT`; invalid lines (bad date,
result other than OK/KO, missing user id) go to
`output/logwatch-errors.txt` and are skipped — the run never aborts
on a bad line.

Demo data (13 lines): `amrani` has 2 KO on 15/11 → not flagged;
`bennis` has 3 KO on 15/11 → **ALERT** (and 2 KO on 16/11 → not
flagged, proving the rule is per-day); `idrissi` has 1 KO one day
and 2 the next → not flagged; one invalid line (`ZZ` result) is
rejected cleanly. In production the alert would feed a SIEM; here
it is the report.

## Files

| File | What it is |
|---|---|
| `BANKLEDG.cbl` | Main program: transaction loop, validation, indexed-file update, report |
| `INTCALC.cbl` | Subprogram: monthly interest, via `CALL ... USING` + `LINKAGE SECTION` |
| `LOADACCT.cbl` | Loader: flat account list → indexed master file |
| `data/accounts.txt` | 6 sample accounts (fixed layout: 10-digit number, 30-char name, balance) |
| `data/transactions.txt` | 8 sample transactions (account, type, amount, date) |
| `LOGWATCH.cbl` | Login-log analyzer: brute-force detection (3 KO same user/day = ALERT) |
| `data/logins.txt` | 13 sample login attempts (user, date, OK/KO) |
| `jcl/BANKLEDG.jcl` | Sample z/OS JCL for the two steps (illustrative) |
| `run.sh` | Build + load + run + show the outputs |
| `INTERVIEW-NOTES.md` | How to present this project, and the concepts it demonstrates |

## Build and run

```bash
# GnuCOBOL needed once:
#   Debian/Ubuntu: sudo apt install gnucobol
#   macOS:         brew install gnucobol

./run.sh
```

That compiles both programs, rebuilds the master file, runs the
ledger, and prints the report and the error file. Re-running
`./run.sh` resets the master file first, so the run is repeatable.

Manual build, if you prefer:

```bash
cobc -x -free -o bin/loadacct LOADACCT.cbl
cobc -x -free -o bin/bankledg BANKLEDG.cbl INTCALC.cbl
./bin/loadacct
./bin/bankledg
```

## COBOL concepts used

- The four divisions, `FILE-CONTROL` with `SELECT`, `FD` entries
- Sequential vs indexed file organization, random access by key
- `PIC S9(9)V99 COMP-3` (packed decimal) for balances
- 88-level condition names (`DEPOSIT`, `WITHDRAWAL`, `MASTER-OK`)
- `EVALUATE`, `PERFORM ... UNTIL`, `STRING`, edited numeric pictures
- `FILE STATUS` checking after `OPEN` / `READ` / `REWRITE`
- `CALL` to a subprogram with `LINKAGE SECTION`
- `FUNCTION CURRENT-DATE` for the report header
- Error handling that never aborts the batch: a bad transaction is
  logged and the next one is processed
- The `SORT` verb (LOGWATCH): ordering a file by key before a
  sequential pass, instead of loading everything into memory
