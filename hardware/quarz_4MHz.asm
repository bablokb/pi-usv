;#################################################################
;## UP'e f�r Zeitverz�gerungen mit Quarz 4,000 MHz /4 = 1 MHz :
;## Zykluszeit = 1/1000000 Hz = 1,0 �s                         
;#################################################################
;EQU's, z.B.:
;	miniteil	equ	0x20
;	miditeil	equ	0x21
;	maxiteil	equ	0x22
;	time0	equ	0x23
;	time1	equ	0x24
;	time2	equ	0x25
;#################################################################
;mini-, midi- oder maxitime: Verz�gerung x-mal 100�s, 1ms oder 1/4s
;"x" (dezimal) mu� als Parameter in W vorher geladen worden sein
;#################################################################
minitime
	movwf	miniteil		;"x"=W=miniteil
mm0	call	time100		;100�s Verz�gerung
	decf	miniteil,F		;miniteil=miniteil-1
	btfss	STATUS,Z	;wenn Z=1, �berspringe n�. Bef.
	goto	mm0		;Z=0, miniteil>0
	return			;Z=1, miniteil=0, Verz�gerung erreicht
;
miditime
	movwf	miditeil		;"x"=W=miditeil
mm1	call	time1ms		;1ms Verz�gerung
	decf	miditeil,F		;miditeil=miditeil-1
	btfss	STATUS,Z	;wenn Z=1, �berspringe n�. Bef.
	goto	mm1		;Z=0, miditeil>0
	return			;Z=1, miditeil=0, Verz�gerung erreicht
;
maxitime
	movwf	maxiteil		;"x"=W=maxiteil
mm2	call	time250ms	;250ms Verz�gerung
	decf	maxiteil,F		;maxiteil=maxiteil-1
	btfss	STATUS,Z	;wenn Z=1, �berspringe n�. Bef.
	goto	mm2		;Z=0, maxiteil>0
	return			;Z=1, maxiteil=0, Verz�gerung erreicht
;
;#################################################################
;UP time100: Zeitschleife 100 �s (23x4=92+8=100 Zyklen a 1 �s)
;#################################################################
time100
	movlw	0x17		;W =17 hex , =23 dez
	movwf	time0		;w->time0
m0	decf	time0,F		;time0 decrem., wenn 0, Z=1
	btfss	STATUS,Z	;wenn Z=1, �berspringe n�. Bef.
	goto	m0		;Z=0, weil time0 > 0, springe zu m0
	nop			;Z=1, weil time0 = 0
	nop			;
	return			;UP-Ende
;
;#################################################################
;UP time1ms: Zeitschleife 1 ms (248x4=992+8=1000 Zyklen a 1�s) 
;#################################################################
time1ms
	movlw	0xf8		;W =F8 hex , =248 dez
	movwf	time1		;w->time1
m1	decf	time1,F		;time1 decrem., wenn 0, Z=1
	btfss	STATUS,Z	;
	goto	m1		;
	nop
	nop
	return			;UP-Ende
;
;#################################################################
;UP time250ms: Zeitschleife 250 ms (250x1ms=250ms+6�s)
;#################################################################
time250ms
	movlw	0xfa		;W =FA hex , =250 dez
	movwf	time2		;w->time2
m2	call	time1ms		;Zeitverz�gerung 1ms
	decf	time2,F		;time2 decrem., wenn 0, Z=1
	btfss	STATUS,Z	;wenn Z=1, �berspringe n�. Bef.
	goto	m2
	return
;
;#################################################################
;Ende Datei quarz_4MHz.asm
