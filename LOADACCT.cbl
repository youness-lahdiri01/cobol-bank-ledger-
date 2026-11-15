       >>SOURCE FORMAT FREE
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOADACCT.
      *>----------------------------------------------------------*
      *> LOADACCT - Builds the indexed master account file       *
      *> (data/accounts.idx) from the flat text file             *
      *> data/accounts.txt. Run once before BANKLEDG - the       *
      *> run.sh script does this for you.                        *
      *>                                                          *
      *> The master file is ORGANIZATION IS INDEXED with the     *
      *> account number as RECORD KEY: the VSAM KSDS equivalent  *
      *> on the mainframe, which is why BANKLEDG can READ it     *
      *> by key in random access mode.                            *
      *>----------------------------------------------------------*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCT-TEXT ASSIGN TO "data/accounts.txt"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT MASTER-FILE ASSIGN TO "data/accounts.idx"
               ORGANIZATION IS INDEXED
               ACCESS MODE IS SEQUENTIAL
               RECORD KEY IS M-ACCT-NUM
               FILE STATUS IS WS-MASTER-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  ACCT-TEXT.
       01  ACCT-TEXT-REC.
           05 A-ACCT-NUM    PIC 9(10).
           05 A-NAME        PIC X(30).
           05 A-BALANCE     PIC 9(9)V99.

       FD  MASTER-FILE.
       01  MASTER-REC.
           05 M-ACCT-NUM    PIC 9(10).
           05 M-ACCT-NAME   PIC X(30).
           05 M-BALANCE     PIC S9(9)V99 COMP-3.

       WORKING-STORAGE SECTION.
       01  WS-MASTER-STATUS   PIC X(2).
           88 MASTER-OK        VALUE "00".
       01  WS-EOF             PIC X VALUE "N".
           88 END-OF-FILE      VALUE "Y".
       01  WS-CNT             PIC 9(5) VALUE 0.

       PROCEDURE DIVISION.
       MAIN-PARA.
           OPEN INPUT ACCT-TEXT
           OPEN OUTPUT MASTER-FILE
           IF NOT MASTER-OK
               DISPLAY "ERROR: cannot create master file, status "
                       WS-MASTER-STATUS
               STOP RUN RETURNING 8
           END-IF
           READ ACCT-TEXT
               AT END MOVE "Y" TO WS-EOF
           END-READ
           PERFORM UNTIL END-OF-FILE
               MOVE A-ACCT-NUM TO M-ACCT-NUM
               MOVE A-NAME TO M-ACCT-NAME
               MOVE A-BALANCE TO M-BALANCE
               WRITE MASTER-REC
                   INVALID KEY
                       DISPLAY "DUPLICATE KEY: " A-ACCT-NUM
               END-WRITE
               ADD 1 TO WS-CNT
               READ ACCT-TEXT
                   AT END MOVE "Y" TO WS-EOF
               END-READ
           END-PERFORM
           CLOSE ACCT-TEXT MASTER-FILE
           DISPLAY "LOADACCT finished. Accounts loaded: " WS-CNT
           STOP RUN.
