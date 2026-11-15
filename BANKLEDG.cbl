       >>SOURCE FORMAT FREE
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANKLEDG.
      *>----------------------------------------------------------*
      *> BANKLEDG - Batch ledger update for a small retail bank. *
      *>                                                          *
      *> Reads the day's transactions (sequential file), applies  *
      *> each one to the indexed master account file (the VSAM    *
      *> KSDS equivalent), and writes a formatted report plus    *
      *> an error file. INTCALC is called for every account      *
      *> updated, to show the projected monthly interest.        *
      *>                                                          *
      *> Run it with ./run.sh - it builds the master file with   *
      *> LOADACCT first, then runs this program.                 *
      *>----------------------------------------------------------*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TRANS-FILE ASSIGN TO "data/transactions.txt"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT MASTER-FILE ASSIGN TO "data/accounts.idx"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS M-ACCT-NUM
               FILE STATUS IS WS-MASTER-STATUS.
           SELECT REPORT-FILE ASSIGN TO "output/report.txt"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT ERROR-FILE ASSIGN TO "output/errors.txt"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD  TRANS-FILE.
       01  TRANS-REC.
           05 T-ACCT-NUM    PIC 9(10).
           05 T-TYPE        PIC X.
               88 DEPOSIT       VALUE "D".
               88 WITHDRAWAL    VALUE "W".
           05 T-AMOUNT      PIC 9(7)V99.
           05 T-DATE        PIC 9(8).

       FD  MASTER-FILE.
       01  MASTER-REC.
           05 M-ACCT-NUM    PIC 9(10).
           05 M-ACCT-NAME   PIC X(30).
           05 M-BALANCE     PIC S9(9)V99 COMP-3.

       FD  REPORT-FILE.
       01  REPORT-REC      PIC X(120).

       FD  ERROR-FILE.
       01  ERROR-REC       PIC X(120).

       WORKING-STORAGE SECTION.
       01  WS-MASTER-STATUS   PIC X(2).
           88 MASTER-OK        VALUE "00".
           88 MASTER-NOT-FOUND VALUE "23".
       01  WS-TRANS-EOF       PIC X VALUE "N".
           88 TRANS-EOF        VALUE "Y".
       01  WS-RATE            PIC 9V9999 COMP-3 VALUE 0.005.
       01  WS-INTEREST        PIC S9(9)V99 COMP-3.
       01  WS-TODAY.
           05 WS-YEAR         PIC 9(4).
           05 WS-MONTH        PIC 9(2).
           05 WS-DAY          PIC 9(2).
           05 WS-REST         PIC X(10).
       01  WS-REPORT-DATE     PIC X(10).
       01  WS-AMT-EDIT        PIC ZZ,ZZZ,ZZ9.99.
       01  WS-BAL-EDIT        PIC ZZ,ZZZ,ZZZ,ZZ9.99.
       01  WS-INT-EDIT        PIC ZZ,ZZZ,ZZ9.99.
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
           MOVE FUNCTION CURRENT-DATE TO WS-TODAY
           STRING WS-DAY "/" WS-MONTH "/" WS-YEAR
               DELIMITED BY SIZE INTO WS-REPORT-DATE
           END-STRING
           PERFORM OPEN-FILES
           PERFORM WRITE-HEADER
           PERFORM READ-TRANS
           PERFORM UNTIL TRANS-EOF
               ADD 1 TO WS-CNT-READ
               PERFORM PROCESS-TRANS
               PERFORM READ-TRANS
           END-PERFORM
           PERFORM WRITE-TRAILER
           PERFORM CLOSE-FILES
           DISPLAY "BANKLEDG finished. Read: " WS-CNT-READ
                   " OK: " WS-CNT-OK " Errors: " WS-CNT-ERR
           STOP RUN.

       OPEN-FILES.
           OPEN INPUT TRANS-FILE
           OPEN I-O MASTER-FILE
           IF NOT MASTER-OK
               DISPLAY "ERROR: cannot open master file, status "
                       WS-MASTER-STATUS
               STOP RUN RETURNING 8
           END-IF
           OPEN OUTPUT REPORT-FILE ERROR-FILE.

       CLOSE-FILES.
           CLOSE TRANS-FILE MASTER-FILE REPORT-FILE ERROR-FILE.

       READ-TRANS.
           READ TRANS-FILE
               AT END MOVE "Y" TO WS-TRANS-EOF
           END-READ.

       WRITE-HEADER.
           MOVE SPACES TO REPORT-REC
           STRING "DAILY LEDGER REPORT - " WS-REPORT-DATE
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC
           MOVE "ACCOUNT     TYPE  AMOUNT        NEW BALANCE    MONTHLY INTEREST"
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
           MOVE T-ACCT-NUM TO M-ACCT-NUM
           READ MASTER-FILE
               INVALID KEY
                   MOVE "ACCOUNT NOT FOUND" TO WS-REASON
                   PERFORM WRITE-ERROR
                   EXIT PARAGRAPH
           END-READ
           EVALUATE TRUE
               WHEN DEPOSIT
                   ADD T-AMOUNT TO M-BALANCE
                   ADD 1 TO WS-CNT-DEP
                   ADD T-AMOUNT TO WS-TOT-DEP
               WHEN WITHDRAWAL
                   IF M-BALANCE >= T-AMOUNT
                       SUBTRACT T-AMOUNT FROM M-BALANCE
                       ADD 1 TO WS-CNT-WD
                       ADD T-AMOUNT TO WS-TOT-WD
                   ELSE
                       MOVE "INSUFFICIENT FUNDS" TO WS-REASON
                       PERFORM WRITE-ERROR
                       EXIT PARAGRAPH
                   END-IF
           END-EVALUATE
           REWRITE MASTER-REC
               INVALID KEY
                   MOVE "REWRITE FAILED" TO WS-REASON
                   PERFORM WRITE-ERROR
                   EXIT PARAGRAPH
           END-REWRITE
      *>    Projected monthly interest, via subprogram call.
           CALL "INTCALC" USING M-BALANCE WS-RATE WS-INTEREST
           ADD 1 TO WS-CNT-OK
           PERFORM WRITE-DETAIL.

       WRITE-DETAIL.
           MOVE T-AMOUNT TO WS-AMT-EDIT
           MOVE M-BALANCE TO WS-BAL-EDIT
           MOVE WS-INTEREST TO WS-INT-EDIT
           MOVE SPACES TO REPORT-REC
           STRING T-ACCT-NUM "  " T-TYPE "   "
                  WS-AMT-EDIT "  " WS-BAL-EDIT "  " WS-INT-EDIT
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
           MOVE WS-TOT-DEP TO WS-TOT-DEP-EDIT
           MOVE WS-TOT-WD TO WS-TOT-WD-EDIT
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
