       >>SOURCE FORMAT FREE
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKLEDG.
      *>----------------------------------------------------------*
      *> BANKLEDG - Simple batch ledger for a small bank.        *
      *>                                                          *
      *> 1. Loads the accounts from data/accounts.txt into a     *
      *>    table in memory (max 20 accounts).                   *
      *> 2. Reads the day's transactions from                   *
      *>    data/transactions.txt, one by one, and applies      *
      *>    each one: deposit (D) adds the amount, withdrawal   *
      *>    (W) subtracts it if the balance is enough.          *
      *> 3. Writes one report line per applied transaction      *
      *>    and one error line per rejected one, then a short   *
      *>    summary (totals) at the end. A bad transaction      *
      *>    never stops the run: it is logged and the next      *
      *>    one is processed.                                    *
      *>                                                          *
      *> Only sequential files are used - no indexed file,      *
      *> no subprogram. Run it with ./run.sh                   *
      *>----------------------------------------------------------*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCT-FILE ASSIGN TO "data/accounts.txt"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT TRANS-FILE ASSIGN TO "data/transactions.txt"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT REPORT-FILE ASSIGN TO "output/report.txt"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT ERROR-FILE ASSIGN TO "output/errors.txt"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD  ACCT-FILE.
       01  ACCT-REC.
           05 A-ACCT-NUM    PIC 9(10).
           05 A-NAME        PIC X(30).
           05 A-BALANCE     PIC 9(9)V99.

       FD  TRANS-FILE.
       01  TRANS-REC.
           05 T-ACCT-NUM    PIC 9(10).
           05 T-TYPE        PIC X.
               88 DEPOSIT       VALUE "D".
               88 WITHDRAWAL    VALUE "W".
           05 T-AMOUNT      PIC 9(7)V99.
           05 T-DATE        PIC 9(8).

       FD  REPORT-FILE.
       01  REPORT-REC      PIC X(120).

       FD  ERROR-FILE.
       01  ERROR-REC       PIC X(120).

       WORKING-STORAGE SECTION.
      *> The accounts table: 20 rows max, 6 in the sample file.
       01  WS-NB-ACCOUNTS     PIC 9(3) VALUE 0.
       01  WS-ACCOUNTS.
           05 WS-ACCT OCCURS 20 TIMES.
               10 TBL-NUM     PIC 9(10).
               10 TBL-NAME    PIC X(30).
               10 TBL-BALANCE PIC S9(9)V99.
       01  WS-EOF             PIC X VALUE "N".
           88 END-OF-FILE     VALUE "Y".
       01  WS-FOUND           PIC X VALUE "N".
           88 ACCOUNT-FOUND   VALUE "Y".
       01  WS-IDX             PIC 9(3) VALUE 0.
       01  WS-AMT-EDIT        PIC ZZ,ZZZ,ZZ9.99.
       01  WS-BAL-EDIT        PIC ZZ,ZZZ,ZZZ,ZZ9.99.
       01  WS-REASON          PIC X(30).
       01  WS-CNT-READ        PIC 9(5) VALUE 0.
       01  WS-CNT-OK          PIC 9(5) VALUE 0.
       01  WS-CNT-DEP         PIC 9(5) VALUE 0.
       01  WS-CNT-WD          PIC 9(5) VALUE 0.
       01  WS-CNT-ERR         PIC 9(5) VALUE 0.
       01  WS-TOT-DEP         PIC S9(11)V99 VALUE 0.
       01  WS-TOT-WD          PIC S9(11)V99 VALUE 0.
       01  WS-TOT-DEP-EDIT    PIC $$,$$$,$$$,$$9.99.
       01  WS-TOT-WD-EDIT     PIC $$,$$$,$$$,$$9.99.

       PROCEDURE DIVISION.
       MAIN-PARA.
           PERFORM LOAD-ACCOUNTS
           PERFORM OPEN-FILES
           PERFORM WRITE-HEADER
           PERFORM READ-TRANS
           PERFORM UNTIL END-OF-FILE
               ADD 1 TO WS-CNT-READ
               PERFORM PROCESS-TRANS
               PERFORM READ-TRANS
           END-PERFORM
           PERFORM WRITE-TRAILER
           PERFORM CLOSE-FILES
           DISPLAY "BANKLEDG finished. Read: " WS-CNT-READ
                   " OK: " WS-CNT-OK " Errors: " WS-CNT-ERR
           STOP RUN.

      *> Step 1: read all accounts into the table.
       LOAD-ACCOUNTS.
           OPEN INPUT ACCT-FILE
           MOVE "N" TO WS-EOF
           READ ACCT-FILE
               AT END MOVE "Y" TO WS-EOF
           END-READ
           PERFORM UNTIL END-OF-FILE
               ADD 1 TO WS-NB-ACCOUNTS
               MOVE A-ACCT-NUM TO TBL-NUM (WS-NB-ACCOUNTS)
               MOVE A-NAME TO TBL-NAME (WS-NB-ACCOUNTS)
               MOVE A-BALANCE TO TBL-BALANCE (WS-NB-ACCOUNTS)
               READ ACCT-FILE
                   AT END MOVE "Y" TO WS-EOF
               END-READ
           END-PERFORM
           CLOSE ACCT-FILE
           MOVE "N" TO WS-EOF
           DISPLAY "Accounts loaded: " WS-NB-ACCOUNTS.

       OPEN-FILES.
           OPEN INPUT TRANS-FILE
           OPEN OUTPUT REPORT-FILE ERROR-FILE.

       CLOSE-FILES.
           CLOSE TRANS-FILE REPORT-FILE ERROR-FILE.

       READ-TRANS.
           READ TRANS-FILE
               AT END MOVE "Y" TO WS-EOF
           END-READ.

       WRITE-HEADER.
           MOVE "DAILY LEDGER REPORT" TO REPORT-REC
           WRITE REPORT-REC
           MOVE "ACCOUNT     TYPE  AMOUNT        NEW BALANCE"
               TO REPORT-REC
           WRITE REPORT-REC
           MOVE ALL "-" TO REPORT-REC
           WRITE REPORT-REC.

       PROCESS-TRANS.
      *>    Validation first: amount, then type, then account.
           IF T-AMOUNT = 0
               MOVE "INVALID AMOUNT (ZERO)" TO WS-REASON
               PERFORM WRITE-ERROR
               EXIT PARAGRAPH
           END-IF
           IF NOT DEPOSIT AND NOT WITHDRAWAL
               MOVE "INVALID TRANSACTION TYPE" TO WS-REASON
               PERFORM WRITE-ERROR
               EXIT PARAGRAPH
           END-IF
           PERFORM FIND-ACCOUNT
           IF NOT ACCOUNT-FOUND
               MOVE "ACCOUNT NOT FOUND" TO WS-REASON
               PERFORM WRITE-ERROR
               EXIT PARAGRAPH
           END-IF
           EVALUATE TRUE
               WHEN DEPOSIT
                   ADD T-AMOUNT TO TBL-BALANCE (WS-IDX)
                   ADD 1 TO WS-CNT-DEP
                   ADD T-AMOUNT TO WS-TOT-DEP
               WHEN WITHDRAWAL
                   IF TBL-BALANCE (WS-IDX) >= T-AMOUNT
                       SUBTRACT T-AMOUNT
                           FROM TBL-BALANCE (WS-IDX)
                       ADD 1 TO WS-CNT-WD
                       ADD T-AMOUNT TO WS-TOT-WD
                   ELSE
                       MOVE "INSUFFICIENT FUNDS" TO WS-REASON
                       PERFORM WRITE-ERROR
                       EXIT PARAGRAPH
                   END-IF
           END-EVALUATE
           ADD 1 TO WS-CNT-OK
           PERFORM WRITE-DETAIL.

      *> Look for the account number in the table.
       FIND-ACCOUNT.
           MOVE "N" TO WS-FOUND
           MOVE 0 TO WS-IDX
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NB-ACCOUNTS
                   OR ACCOUNT-FOUND
               IF T-ACCT-NUM = TBL-NUM (WS-IDX)
                   MOVE "Y" TO WS-FOUND
                   EXIT PERFORM
               END-IF
           END-PERFORM.

       WRITE-DETAIL.
           MOVE T-AMOUNT TO WS-AMT-EDIT
           MOVE TBL-BALANCE (WS-IDX) TO WS-BAL-EDIT
           MOVE SPACES TO REPORT-REC
           STRING T-ACCT-NUM "  " T-TYPE "   "
                  WS-AMT-EDIT "  " WS-BAL-EDIT
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC.

       WRITE-ERROR.
           ADD 1 TO WS-CNT-ERR
           MOVE SPACES TO ERROR-REC
           STRING T-ACCT-NUM " " T-TYPE " " T-AMOUNT " "
                  WS-REASON DELIMITED BY SIZE INTO ERROR-REC
           END-STRING
           WRITE ERROR-REC.

       WRITE-TRAILER.
           MOVE ALL "-" TO REPORT-REC
           WRITE REPORT-REC
           MOVE SPACES TO REPORT-REC
           STRING "Transactions read: " WS-CNT-READ
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC
           MOVE SPACES TO REPORT-REC
           STRING "Applied OK: " WS-CNT-OK
                  " (deposits: " WS-CNT-DEP
                  ", withdrawals: " WS-CNT-WD ")"
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC
           MOVE SPACES TO REPORT-REC
           STRING "Errors: " WS-CNT-ERR
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC
           MOVE WS-TOT-DEP TO WS-TOT-DEP-EDIT
           MOVE WS-TOT-WD TO WS-TOT-WD-EDIT
           MOVE SPACES TO REPORT-REC
           STRING "Total deposits: " WS-TOT-DEP-EDIT
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC
           MOVE SPACES TO REPORT-REC
           STRING "Total withdrawals: " WS-TOT-WD-EDIT
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC.
