//BANKLEDG JOB (ACCT),'DAILY LEDGER',CLASS=A,MSGCLASS=X,
//             NOTIFY=&SYSUID
//*------------------------------------------------------------*
//*  Sample JCL for z/OS - the same two programs, as they     *
//*  would run on the mainframe. Locally, ./run.sh does the    *
//*  equivalent with GnuCOBOL.                                 *
//*                                                             *
//*  Step 1 LOAD builds the VSAM KSDS master file from the     *
//*  flat account list. Step 2 LEDGER applies the day's        *
//*  transactions and produces the report + error file.        *
//*------------------------------------------------------------*
//LOAD     EXEC PGM=LOADACCT
//ACCTLIST DD  DSN=YOUNESS.BANK.ACCTLIST,DISP=SHR
//MASTER   DD  DSN=YOUNESS.BANK.MASTER,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(1,1)),
//             DCB=(RECFM=F,LRECL=44,DSORG=IS)
//SYSOUT   DD  SYSOUT=*
//*
//LEDGER   EXEC PGM=BANKLEDG
//TRANS    DD  DSN=YOUNESS.BANK.TRANS,DISP=SHR
//MASTER   DD  DSN=YOUNESS.BANK.MASTER,DISP=MOD
//REPORT   DD  SYSOUT=*
//ERRORS   DD  DSN=YOUNESS.BANK.ERRORS,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,(1,1)),
//             DCB=(RECFM=FB,LRECL=120,BLKSIZE=1200)
//SYSOUT   DD  SYSOUT=*
//*
