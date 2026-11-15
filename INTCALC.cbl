       >>SOURCE FORMAT FREE
       IDENTIFICATION DIVISION.
       PROGRAM-ID. INTCALC.
      *>----------------------------------------------------------*
      *> INTCALC - Subprogram: projected monthly interest.       *
      *> Called by BANKLEDG with a balance and a monthly rate;   *
      *> returns the interest amount. Demonstrates CALL ...      *
      *> USING with a LINKAGE SECTION (the classic way a main    *
      *> program and a subprogram exchange data on the           *
      *> mainframe).                                              *
      *>----------------------------------------------------------*
       DATA DIVISION.
       LINKAGE SECTION.
       01  L-BALANCE    PIC S9(9)V99 COMP-3.
       01  L-RATE       PIC 9V9999 COMP-3.
       01  L-INTEREST   PIC S9(9)V99 COMP-3.

       PROCEDURE DIVISION USING L-BALANCE L-RATE L-INTEREST.
           COMPUTE L-INTEREST = L-BALANCE * L-RATE
           EXIT PROGRAM.
       END PROGRAM INTCALC.
