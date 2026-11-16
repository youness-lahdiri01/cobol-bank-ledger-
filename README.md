# COBOL Bank Ledger — Simple Daily Batch

Two small, simple COBOL programs — the kind of nightly batch job
that still runs on mainframes in banking IT. Built in November 2026
as a learning project to prepare for a COBOL interview: the goal was
to write real, runnable COBOL, not to claim production mainframe
experience. It compiles and runs locally with
[GnuCOBOL](https://gnucobol.sourceforge.io/).

## BANKLEDG — daily ledger

Applies a day's banking transactions to the accounts.

1. Loads the accounts from `data/accounts.txt` into a table in
   memory (6 accounts, max 20).
2. Reads the day's transactions from `data/transactions.txt`,
   one by one: deposit (`D`) adds the amount, withdrawal (`W`)
   subtracts it if the balance is enough.
3. Writes one report line per applied transaction
   (`output/report.txt`) and one error line per rejected one
   (`output/errors.txt`), then a short summary: totals of deposits
   and withdrawals.

A bad transaction never stops the run: zero amount, unknown type,
unknown account, insufficient funds — each is logged with its
reason and processing continues.

Sample run: 8 transactions → 4 applied (2 deposits, 2 withdrawals),
4 rejected.

## LOGWATCH — login-log analyzer

A brute-force detection rule, in batch form — the SOC side of the
project. `LOGWATCH` reads `data/logins.txt`: one line per login
attempt, three fields — user id, date (`YYYYMMDD`), result (`OK`
or `KO`).

**Rule: 3 or more failed logins (KO) for the same user on the same
day = ALERT.**

The log file is already ordered by user then date, so one
sequential pass counts OK and KO per user/day group. Groups at or
above the threshold are written to `output/logwatch-report.txt` as
`ALERT`; invalid lines (bad date, result other than OK/KO, missing
user id) go to `output/logwatch-errors.txt` and are skipped — the
run never aborts on a bad line.

Demo data (13 lines): `amrani` has 2 KO on 15/11 → not flagged;
`bennis` has 3 KO on 15/11 → **ALERT** (and 2 KO on 16/11 → not
flagged, proving the rule is per-day); `idrissi` has 1 KO one day
and 2 the next → not flagged; one invalid line (`ZZ` result) is
rejected cleanly. In production the alert would feed a SIEM; here
it is the report.

## Files

| File | What it is |
|---|---|
| `BANKLEDG.cbl` | Ledger: load accounts into a table, apply transactions, report |
| `data/accounts.txt` | 6 sample accounts (number, name, balance) |
| `data/transactions.txt` | 8 sample transactions (account, type, amount, date) |
| `LOGWATCH.cbl` | Login-log analyzer: brute-force detection (3 KO same user/day = ALERT) |
| `data/logins.txt` | 13 sample login attempts (user, date, OK/KO) |
| `run.sh` | Build + run both programs + show the outputs |
| `INTERVIEW-NOTES.md` | How to present this project, and the concepts it demonstrates |

## Build and run

```bash
# GnuCOBOL needed once:
#   Debian/Ubuntu: sudo apt install gnucobol
#   macOS:         brew install gnucobol

./run.sh
```

That compiles both programs, runs the ledger, runs the log
analysis, and prints the reports and the error files.

Manual build, if you prefer:

```bash
cobc -x -free -o bin/bankledg BANKLEDG.cbl
cobc -x -free -o bin/logwatch LOGWATCH.cbl
./bin/bankledg
./bin/logwatch
```

## COBOL concepts used

- The four divisions, `FILE-CONTROL` with `SELECT`, `FD` entries
- Sequential files only — read line by line, write line by line
- A table in memory: `OCCURS` + subscript, searched with
  `PERFORM VARYING`
- 88-level condition names (`DEPOSIT`, `WITHDRAWAL`,
  `ACCOUNT-FOUND`, `END-OF-FILE`) — readable tests, no magic values
- `EVALUATE`, `PERFORM ... UNTIL`, `STRING`, edited numeric
  pictures (`ZZ,ZZZ,ZZ9.99`)
- Error handling that never aborts the batch: a bad transaction is
  logged and the next one is processed
- Control-break counting (LOGWATCH): one pass, one group at a time
