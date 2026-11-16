#!/bin/bash
# Build and run the two programs, then show the outputs.
# Requires GnuCOBOL:  sudo apt install gnucobol   (or: brew install gnucobol)
set -e
cd "$(dirname "$0")"
mkdir -p bin output

echo "== Building BANKLEDG =="
cobc -x -free -o bin/bankledg BANKLEDG.cbl

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
