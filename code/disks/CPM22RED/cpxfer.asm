	TITLE	'CP/M 1.4 SCRATCH DISK TRANSFER PROGRAM'
;
;	TRANSFER FILE TO / FROM SCRATCH DISK
;
;	COPYRIGHT (C) 1976, 1977, 1978, DIGITAL RESEARCH
	ORG	100H
	JMP	START
	DB	'COPYRIGHT (C) 1978, DIGITAL RESEARCH  '
;
;	GLOBAL EQUATES
BDOS	EQU	0005H
BOOT	EQU	0000H
BIOS	EQU	0001H	;ADDRESS OF WARM START ENTRY POINT
;
NSECTS	EQU	26	;26 SECTORS/TRACK
SECSIZ	EQU	128	;SIZE OF EACH SECTOR
;
;	DRIVE B TABLES
SECTORS:
	DB	NSECTS	;INITIALIZED TO 26
TRAN:	;SECTOR TRANSLATION TABLE (INITIALLY SEQUENTIAL)
TR	SET	1	;GENERATE TABLE OF 1,2,3,...,63
	REPT	16
	DB	TR,TR+1,TR+2,TR+3, TR+4,TR+5,TR+6,TR+7
TR	SET	TR+8
	ENDM
;
;	FUNCTIONS IN BDOS
CONIF	EQU	1	;CONSOLE CHARACTER IN
CONOF	EQU	2	;CONSOLE OUT FUNCTION
PRNF	EQU	9	;PRINT BUFFER
OPENF	EQU	15	;OPEN FILE
CLOSF	EQU	16	;CLOSE FILE
DELF	EQU	19	;DELETE FILE
READF	EQU	20	;READ FILE
WRITF	EQU	21	;WRITE FILE
MAKEF	EQU	22	;MAKE FILE
DMAF	EQU	26	;SET DMA ADDRESS
;
;	FUNCTIONS IN BIOS
ABSEL	EQU	8	;SELECT DISK
ABSTR	EQU	9	;SET TRACK
ABSEC	EQU	10	;SET SECTOR
ABSRD	EQU	12	;READ SECTOR
ABSWR	EQU	13	;WRITE SECTOR
;
;	NON GRAPHIC CHARACTERS
EOFILE	EQU	1AH	;CONTROL-Z
CR	EQU	0DH	;CARRIAGE RETURN
LF	EQU	0AH	;LINE FEED
;
;	MNEMONICS
RFUNC	EQU	0	;READ FUNCTION
WFUNC	EQU	1	;WRITE FUNCTION
;
;	DEFAULT FILE CONTROL BLOCK
DFCB	EQU	5CH
SFCB	EQU	DFCB+17	;START OF SECOND NAME
UFBF	EQU	DFCB+13	;UNFILLED BYTES FIELD
;
;	BDOS SUBROUTINES
FREAD:	;FILE READ
	MVI	C,READF
	JMP	BDOS
;
FWRITE:	;WRITE FILE
	MVI	C,WRITF
	JMP	BDOS
;
SETDMA:	;SET DMA ADDRESS
	MVI	C,DMAF
	JMP	BDOS
;
DELETE:	MVI	C,DELF
	JMP	BDOS
;
MAKE:	MVI	C,MAKEF
	JMP	BDOS
;
OPEN:	;OPEN FILE
	MVI	C,OPENF
	JMP	BDOS
;
CLOSE:	MVI	C,CLOSF
	JMP	BDOS
;
PRINT:	;PRINT BUFFER
	MVI	C,PRNF
	JMP	BDOS
;
CONIN:	;CONSOLE CHARACTER IN
	MVI	C,CONIF
	JMP	BDOS
;
;	BIOS SUBROUTINES
DSELECT:;SELECT DISK
	LXI	D,ABSEL*3
	JMP	GOABS
;
TSELECT:;TRACK SELECT
	LXI	D,ABSTR*3
	JMP	GOABS
;
SSELECT:;SECTOR SELECT
;	REGISTER C HAS SECTOR NUMBER, TRANSLATE IT
	DCR	C	;NORMALIZE TO 0 ...
	MVI	B,0	;DOUBLE PRECISION
	LXI	H,TRAN	;TRANSLATE TABLE
	DAD	B	;HL IS .TRAN(SEC#-1)
	MOV	C,M	;TO C READY FOR SELECT
	LXI	D,ABSEC*3
	JMP	GOABS
;
DREAD:	;DISK READ TO DMA ADDRESS
	LXI	D,ABSRD*3
	JMP	GOABS
;
DWRITE:	;WRITE FROM DMA ADDRESS
	LXI	D,ABSWR*3
	JMP	GOABS
;
GOABS:	LHLD	BIOS
	DAD	D
	PCHL
;
;
;	UTILITY SUBROUTINES
;
REBOOT:	;SELECT DISK DRIVE 0 BEFORE REBOOT
	MVI	C,0
	CALL	DSELECT
	JMP	BOOT
;
PRCHAR:	;PRINT CHARACTER IN REGISTER A
	MOV	E,A	;READY FOR BDOS
	MVI	C,CONOF	;CONSOLE OUT
	JMP	BDOS
;
PRNIB:	;PRINT NIBBLE FROM REGISTER A
	SUI	10
	JNC	PRNIB0
;	VALUE IS DECIMAL DIGIT BETWEEN 0 AND 9
	ADI	10+'0'
	JMP	PRCHAR	;PRINT CHARACTER
PRNIB0:	ADI	'A'
	JMP	PRCHAR
;
PRHEX:	;PRINT HEX VALUE IN A
	PUSH	PSW
	RRC
	RRC
	RRC
	RRC
	ANI	0FH	;MOST SIGNIFCANT DIGIT
	CALL	PRNIB	;PRINTED
	POP	PSW
	ANI	0FH
	JMP	PRNIB	;PRINTED
;
PRADDR:	;PRINT ADDRESS VALUE IN HL
	PUSH	H
	MOV	A,H
	CALL	PRHEX
	POP	H
	MOV	A,L
	JMP	PRHEX
;
PRBYTES:
	;PRINT NUMBER OF BYTES IN TRANSFER
	LXI	D,SECMSG
	CALL	PRINT	;BYTE MESSAGE PRINTED
	LHLD	SECCNT
	CALL	PRADDR	;PRINTED
	LXI	D,UFBMSG
	CALL	PRINT	;UNFILLED BYTES MESSAGE
	LDA	UFB
	CALL	PRHEX
	RET
;
SECMSG	DB	CR,LF,'SECTORS = $'
UFBMSG	DB	', UNFILLED BYTES = $'
;
;
FFWB:	;FILE FILL WORKING BUFFER (FULL TRACK)
	LXI	D,WBUFF
	LDA	SECTORS		;SECTOR COUNT
	MOV	B,A		;TO B FOR COUNT DOWN
FFWB0:	;READ SECTOR LOOP ON REG-B
	PUSH	B	;SAVE SECTOR COUNT
	PUSH	D	;SAVE DMA ADDRESS
	CALL	SETDMA
	LXI	D,DFCB	;FILE CONTROL BLOCK FOR INPUT FILE
	CALL	FREAD
	POP	D
	POP	B
	ORA	A	;RETURN CODE=0 FOR READ?
	JZ	FROK	;OK IF ZERO
;	END OF FILE ON INPUT
	LXI	H,EOFSET
	MVI	M,1	;MARK AS EOF
	RET
;
FROK:	;FILE READ OK
	LHLD	SECCNT		;SECTOR COUNT INCREMENT
	INX	H
	SHLD	SECCNT		;FOR HEADER RECORD
;
;	NOW INCREMENT DMA ADDRESS
	LXI	H,SECSIZ	;SECTOR SIZE
	DAD	D
	XCHG		;INCREMENTED DMA ADDRESS IN D,E
	DCR	B
	RZ		;STOP IF NSECTS SECTORS READ
	JMP	FFWB0	;FOR MORE DATA
;
WFWB:	;WRITE FILE FROM BUFFER
	LXI	D,WBUFF
	LDA	SECTORS
	MOV	B,A	;TO B FOR COUNT
WFWB0:
	;CHECK FOR END OF FILE
	LHLD	SECCNT
	MOV	A,L	;0000?
	ORA	H
	JNZ	WFWB1
;
;	END OF SECTOR TRANSFER
	MVI	A,1
	STA	EOFSET
	RET
;
WFWB1:	;NOT END OF FILE, DECREMENT SECTOR COUNT
	DCX	H
	SHLD	SECCNT
	PUSH	B	;SAVE SECTOR COUNT ON THIS TRACK
	PUSH	D
	CALL	SETDMA
	LXI	D,DFCB
	CALL	FWRITE	;SECTOR WRITTEN, CHECK ERRS
	POP	D
	POP	B
	ORA	A
	JZ	FWOK
;	ERROR IN WRITE
	LXI	D,FULMSG
	CALL	PRINT
	JMP	REBOOT
FULMSG:	DB	CR,LF,'DISK FULL$'
;
FWOK:	;FILE WRITE OK
	LDAX	D
	CPI	EOFILE
	RZ
	LXI	H,SECSIZ	;SECTOR SIZE
	DAD	D
	XCHG
	DCR	B
	RZ
	JMP	WFWB0
;
WTRK:	;WRITE FULL TRACK TO SCRATCH DISK
	MVI	A,WFUNC
	JMP	SETFUNC
;
RTRK:	;READ A FULL TRACK TO MEMORY
	MVI	A,RFUNC
;
SETFUNC:
	STA	FUNCTION
	LXI	H,CURTRK	;CURRENT TRACK
	MOV	C,M
	INR	M	;TO NEXT TRACK
	CALL	TSELECT	;SELECT TRACK IN REG-C
	LDA	SECTORS
	MOV	B,A
	MVI	C,0	;B=NSECTS, C=0
	LXI	D,WBUFF	;DMA ADDRESS
;
WSEC:	;WRITE SECTOR
	INR	C	;TO NEXT SECTOR NUMBER
	PUSH	B
	PUSH	D	;COUNTS AND DMA ADDRESS SAVED
	CALL	SSELECT	;SELECT SECTOR FROM REG-C
	POP	D	;DMA ADDRESS
	PUSH	D
	CALL	SETDMA
	LDA	FUNCTION
	CPI	RFUNC
	JZ	RDSECT
	CALL	DWRITE	;ABSOLUTE SECTOR WRITTEN
	JMP	CHKCOND
RDSECT:	CALL	DREAD	;ABSOLUTE SECTOR READ
CHKCOND:
	POP	D
	POP	B	;RESTORE DMA AND COUNTS
	ORA	A	;ERROR CODE ON DWRITE?
	JZ	NOERR
	LXI	D,ERRED
	CALL	PRINT
	JMP	REBOOT
ERRED:	DB	CR,LF,'CANNOT ACCESS SCRATCH DISK$'
;
NOERR:
	LDAX	D	;EOF?
	CPI	EOFILE
	JNZ	NOTEOF
	MVI	A,1
	STA	EOFSET
	RET
NOTEOF:
	LXI	H,SECSIZ	;SECTOR SIZE
	DAD	D
	XCHG		;INCREMENTED DMA ADDRESS
	DCR	B
	RZ		;STOP IF ALL NSECTS SECTORS WRITTEN
	JMP	WSEC	;FOR ANOTHER SECTOR
;
START:	;PROCESS SUCCESSIVE TRACKS TIL FILE EMPTY
	LXI	SP,STACK
	XRA	A
	STA	EOFSET
;
;	CHECK MODE OF OPERATION
	LDA	SFCB
	CPI	'S'
	JNZ	RCVCHK
;	SEND DATA, PROMPT CONSOLE
	LXI	D,SMSG
	CALL	PRINT
	CALL	CONIN
;	OPEN FILE FOR INPUT
	LXI	D,DFCB
	CALL	OPEN
	CPI	255
	JNZ	WRSCR
;
;	CANNOT OPEN FILE
	LXI	D,FMSG
	CALL	PRINT
	JMP	REBOOT
;
FMSG:	DB	CR,LF,'NO INPUT FILE PRESENT$'
SMSG:	DB	CR,LF,'READY SCRATCH DISK ON B, TYPE RETURN$'
;
WRSCR:	;WRITE THE SCRATCH DISK, SKIP HEADER TRACK
	LXI	H,CURTRK
	MVI	M,1	;START WITH TRACK 1
	LXI	H,0
	SHLD	SECCNT	;CLEAR SECTOR COUNT
;
RDTRK:	;READ NEXT TRACK FULL
	CALL	FFWB
	MVI	C,1
	CALL	DSELECT	;SELECT SECOND DISK
	CALL	WTRK
	MVI	C,0
	CALL	DSELECT	;SELECT ORIGINAL DISK
	LDA	EOFSET	;END OF FILE?
	ORA	A
	JZ	RDTRK	;FOR ANOTHER TRACK
;
;	NOW FILL THE SECTOR COUNT AND UNFILLED BYTES
	LHLD	SECCNT
	SHLD	WBUFF
	LDA	UFBF	;GET UNFILLED BYTES FROM DFCB
	STA	WBUFF+2
	STA	UFB	;READY FOR BYTE COUNT
	MVI	C,1
	CALL	DSELECT	;DRIVE ONE SELECTED
	XRA	A
	STA	CURTRK	;TRACK 0 SELECTED
	CALL	WTRK	;WRITE THE HEADER TRACK
;
;	PRINT TRANSFER COUNT
	CALL	PRBYTES
;
	LXI	D,EMSG
	CALL	PRINT
	JMP	REBOOT
;
EMSG:	DB	CR,LF,'SCRATCH DISK WRITTEN$'
;
RCVCHK:	;CHECK FOR RECEIVE MODE
	CPI	'R'
	JNZ	BADCOM
;	RECEIVE MODE SET
	LXI	D,RMSG
	CALL	PRINT
	CALL	CONIN
;	DELETE OLD COPIES, MAKE NEW COPY
	LXI	D,DFCB
	PUSH	D
	CALL	DELETE
	POP	D
	CALL	MAKE
	CPI	255
	JNZ	OPOK
;	CANNOT OPEN
	LXI	D,OPMSG
	CALL	PRINT
	JMP	REBOOT
OPMSG:	DB	CR,LF,'NO DIRECTORY SPACE$'
;
OPOK:	LXI	H,DFCB+32	;NEXT RECORD FIELD
	MVI	M,0
;
;	GET HEADER TRACK, FILL SECCNT AND UFB
	XRA	A
	STA	CURTRK	;TRACK 00
	MVI	C,1
	CALL	DSELECT	;DISK SELECTED
	CALL	RTRK	;READ TRACK
	LHLD	WBUFF
	SHLD	SECCNT	;NUMBER OF SECTORS TO READ
	LDA	WBUFF+2
	STA	UFB	;SAVE UNFILLED BYTE FIELD
;
	CALL	PRBYTES	;PRINT COUNTERS
WRTRK:	MVI	C,1	;SELECT DRIVE 1
	CALL	DSELECT
	CALL	RTRK
	MVI	C,0
	CALL	DSELECT
	CALL	WFWB	;WRITE TO FILE
	LDA	EOFSET
	ORA	A
	JZ	WRTRK
	LXI	D,DFCB
	LDA	UFB	;UNFILLED BYTES
	STA	UFBF	;STORE TO FCB
	CALL	CLOSE
	LXI	D,REMSG
	CALL	PRINT
	JMP	REBOOT
REMSG:	DB	CR,LF,'DATA DISK READ OK$'
RMSG:	DB	CR,LF,'READY DATA DISK ON B, TYPE RETURN$'
;
BADCOM: LXI	D,BADMSG
	CALL	PRINT
	JMP	REBOOT
BADMSG:	DB	CR,LF,'INVALID COMMAND, FORM IS:'
	DB	CR,LF,'CPXFER <FILENAME> <MODE> <CR>'
	DB	CR,LF,'WHERE <MODE> IS S FOR SEND, AND R FOR RECEIVE$'
;
;	DATA AREAS
	DS	64	;32 LEVEL STACK
STACK:
FUNCTION:
	DS	1	;READ/WRITE FUNCTION
CURTRK:	DS	1
EOFSET:	DS	1
SECCNT:	DS	2	;SECTOR COUNTER
UFB:	DS	1	;UNFILLED BYTES IN FCB
WBUFF:	;BUFFER BEGINS AT END OF PROGRAM
	END
