       >>SOURCE FORMAT FREE
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOGWATCH.
      *>----------------------------------------------------------*
      *> LOGWATCH - Login-log analyzer (brute-force detection).  *
      *>                                                          *
      *> Reads a login log: one line per attempt, three fields -  *
      *> user id, date (YYYYMMDD), result (OK or KO).            *
      *> Rule: for the same user on the same day, 3 failed       *
      *> logins (KO) or more raise an alert.                     *
      *>                                                          *
      *> How it works: the log file is already ordered by user   *
      *> then by date, so all attempts of one user on one day    *
      *> sit together. One sequential pass counts OK and KO     *
      *> per group. Groups with KO >= 3 are written to the      *
      *> report as ALERT; invalid lines go to the error file    *
      *> and are skipped, never aborting the run.                *
      *>                                                          *
      *> SOC angle: this is the batch form of the classic        *
      *> brute-force detection rule (several failures in a short *
      *> window). In production the alert would feed a SIEM;     *
      *> here it is written to output/logwatch-report.txt.       *
      *>----------------------------------------------------------*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT LOG-FILE ASSIGN TO "data/logins.txt"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT REPORT-FILE ASSIGN TO "output/logwatch-report.txt"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT ERROR-FILE ASSIGN TO "output/logwatch-errors.txt"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD  LOG-FILE.
       01  LOG-REC.
           05 L-USER       PIC X(12).
           05 L-DATE       PIC X(8).
           05 L-RESULT     PIC X(2).

       FD  REPORT-FILE.
       01  REPORT-REC      PIC X(120).

       FD  ERROR-FILE.
       01  ERROR-REC       PIC X(120).

       WORKING-STORAGE SECTION.
       01  WS-THRESHOLD       PIC 9(2) VALUE 3.
       01  WS-EOF             PIC X VALUE "N".
           88 END-OF-FILE      VALUE "Y".
       01  WS-FIRST-GROUP     PIC X VALUE "Y".
           88 FIRST-GROUP      VALUE "Y".
       01  WS-CUR-USER        PIC X(12).
       01  WS-CUR-DATE        PIC X(8).
       01  WS-CNT-OK          PIC 9(5) VALUE 0.
       01  WS-CNT-KO          PIC 9(5) VALUE 0.
       01  WS-CNT-READ        PIC 9(5) VALUE 0.
       01  WS-CNT-INVALID     PIC 9(5) VALUE 0.
       01  WS-CNT-GROUPS      PIC 9(5) VALUE 0.
       01  WS-CNT-ALERTS      PIC 9(5) VALUE 0.
       01  WS-REASON          PIC X(30).
       01  WS-ATTEMPTS        PIC 9(5).
       01  WS-STATUS          PIC X(22).

       PROCEDURE DIVISION.
       MAIN-PARA.
           OPEN INPUT LOG-FILE
           OPEN OUTPUT REPORT-FILE ERROR-FILE
           PERFORM WRITE-HEADER
           PERFORM READ-LOG
           PERFORM UNTIL END-OF-FILE
               ADD 1 TO WS-CNT-READ
               PERFORM PROCESS-LINE
               PERFORM READ-LOG
           END-PERFORM
           PERFORM FLUSH-GROUP
           PERFORM WRITE-TRAILER
           CLOSE LOG-FILE REPORT-FILE ERROR-FILE
           DISPLAY "LOGWATCH finished. Lines read: " WS-CNT-READ
                   " Alerts: " WS-CNT-ALERTS
                   " Invalid: " WS-CNT-INVALID
           STOP RUN.

       READ-LOG.
           READ LOG-FILE
               AT END MOVE "Y" TO WS-EOF
           END-READ.

       WRITE-HEADER.
           MOVE "LOGIN WATCH REPORT" TO REPORT-REC
           WRITE REPORT-REC
           MOVE SPACES TO REPORT-REC
           STRING "Rule: 3 or more failed logins (KO) for the same "
                  "user on the same day = ALERT"
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC
           MOVE "USER          DATE      ATTEMPTS  FAILURES  STATUS"
               TO REPORT-REC
           WRITE REPORT-REC
           MOVE ALL "-" TO REPORT-REC
           WRITE REPORT-REC.

       PROCESS-LINE.
      *>    Validate the line before counting it.
           IF L-USER = SPACES
               MOVE "INVALID LINE (NO USER ID)" TO WS-REASON
               PERFORM WRITE-ERROR
               EXIT PARAGRAPH
           END-IF
           IF L-DATE IS NOT NUMERIC
               MOVE "INVALID DATE" TO WS-REASON
               PERFORM WRITE-ERROR
               EXIT PARAGRAPH
           END-IF
           IF L-RESULT NOT = "OK" AND L-RESULT NOT = "KO"
               MOVE "INVALID RESULT (NOT OK/KO)" TO WS-REASON
               PERFORM WRITE-ERROR
               EXIT PARAGRAPH
           END-IF
      *>    New user or new day: close the previous group first.
           IF FIRST-GROUP
               MOVE "N" TO WS-FIRST-GROUP
               MOVE L-USER TO WS-CUR-USER
               MOVE L-DATE TO WS-CUR-DATE
           ELSE
               IF L-USER NOT = WS-CUR-USER
                   OR L-DATE NOT = WS-CUR-DATE
                   PERFORM FLUSH-GROUP
                   MOVE L-USER TO WS-CUR-USER
                   MOVE L-DATE TO WS-CUR-DATE
               END-IF
           END-IF
           IF L-RESULT = "KO"
               ADD 1 TO WS-CNT-KO
           ELSE
               ADD 1 TO WS-CNT-OK
           END-IF.

       FLUSH-GROUP.
           IF FIRST-GROUP
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-CNT-GROUPS
           COMPUTE WS-ATTEMPTS = WS-CNT-OK + WS-CNT-KO
           IF WS-CNT-KO >= WS-THRESHOLD
               MOVE "ALERT - 3+ FAILURES" TO WS-STATUS
               ADD 1 TO WS-CNT-ALERTS
           ELSE
               MOVE "ok" TO WS-STATUS
           END-IF
           MOVE SPACES TO REPORT-REC
           STRING WS-CUR-USER "  " WS-CUR-DATE "  "
                  WS-ATTEMPTS "  " WS-CNT-KO "  " WS-STATUS
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC
           MOVE 0 TO WS-CNT-OK WS-CNT-KO.

       WRITE-ERROR.
           ADD 1 TO WS-CNT-INVALID
           MOVE SPACES TO ERROR-REC
           STRING L-USER " " L-DATE " " L-RESULT " "
                  WS-REASON DELIMITED BY SIZE INTO ERROR-REC
           END-STRING
           WRITE ERROR-REC.

       WRITE-TRAILER.
           MOVE ALL "-" TO REPORT-REC
           WRITE REPORT-REC
           MOVE SPACES TO REPORT-REC
           STRING "Lines read: " WS-CNT-READ
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC
           MOVE SPACES TO REPORT-REC
           STRING "User/day groups: " WS-CNT-GROUPS
                  "  Alerts: " WS-CNT-ALERTS
                  "  Invalid lines: " WS-CNT-INVALID
               DELIMITED BY SIZE INTO REPORT-REC
           END-STRING
           WRITE REPORT-REC.
