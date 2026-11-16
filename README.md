# COBOL Logwatch — Login-Log Analyzer

A small, simple COBOL program — a brute-force detection rule, in
batch form. Built in November 2026 as a learning project to prepare
for a COBOL interview: the goal was to write real, runnable COBOL,
not to claim production mainframe experience. It compiles and runs
locally with [GnuCOBOL](https://gnucobol.sourceforge.io/).

## What it does

`LOGWATCH` reads `data/logins.txt`: one line per login attempt,
three fields — user id, date (`YYYYMMDD`), result (`OK` or `KO`).

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
| `LOGWATCH.cbl` | Login-log analyzer: brute-force detection (3 KO same user/day = ALERT) |
| `data/logins.txt` | 13 sample login attempts (user, date, OK/KO) |
| `run.sh` | Build + run the program + show the outputs |
| `INTERVIEW-NOTES.md` | How to present this project, and the concepts it demonstrates |

## Build and run

```bash
# GnuCOBOL needed once:
#   Debian/Ubuntu: sudo apt install gnucobol
#   macOS:         brew install gnucobol

./run.sh
```

That compiles the program, runs the log analysis, and prints the
report and the error file.

Manual build, if you prefer:

```bash
cobc -x -free -o bin/logwatch LOGWATCH.cbl
./bin/logwatch
```

## COBOL concepts used

- The four divisions, `FILE-CONTROL` with `SELECT`, `FD` entries
- Sequential files only — read line by line, write line by line
- 88-level condition names (`END-OF-FILE`, `FIRST-GROUP`) —
  readable tests, no magic values
- `PERFORM ... UNTIL`, `STRING`, `COMPUTE`
- Error handling that never aborts the batch: a bad line is logged
  and the next one is processed
- Control-break counting: one pass, one group at a time
- A named constant for the threshold (`WS-THRESHOLD VALUE 3`) —
  one place to change the rule, like a SIEM rule threshold
