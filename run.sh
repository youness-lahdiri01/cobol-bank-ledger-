#!/bin/bash
# Build and run the bank ledger batch.
# Requires GnuCOBOL:  sudo apt install gnucobol   (or: brew install gnucobol)
set -e
cd "$(dirname "$0")"
mkdir -p bin output

echo "== Building LOADACCT =="
cobc -x -free -o bin/loadacct LOADACCT.cbl

echo "== Building BANKLEDG + INTCALC =="
cobc -x -free -o bin/bankledg BANKLEDG.cbl INTCALC.cbl

echo "== Loading master account file =="
rm -f data/accounts.idx data/accounts.idx.dat
./bin/loadacct

echo "== Running daily ledger =="
./bin/bankledg

echo ""
echo "== Report (output/report.txt) =="
cat output/report.txt
echo ""
echo "== Errors (output/errors.txt) =="
cat output/errors.txt

echo ""
echo "== Building LOGWATCH =="
cobc -x -free -o bin/logwatch LOGWATCH.cbl

echo "== Running login-log analysis =="
./bin/logwatch

echo ""
echo "== Login watch report (output/logwatch-report.txt) =="
cat output/logwatch-report.txt
echo ""
echo "== Login watch errors (output/logwatch-errors.txt) =="
cat output/logwatch-errors.txt
