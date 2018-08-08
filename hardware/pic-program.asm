; schwellwert_multi.asm								Steinau, 28.03.2018
; ##################################################################
; Spannungsüberwachung mit ADC/PIC und Signalisation
; wenn Unterspannung, mit LED und MeldePort Bu3.
; Neu: Mehrfachspannungsmessung und Mittelwertbildung !
; Schaltung: usv-mini
; ##################################################################
; Pinbelegung:
;
;	GP: 0 - AN0 ADC Eingang (ICSPDAT)
;		1 - AN1 Uref Eingang (ICSPCLK)
;		2 - GP2 Ausgang, T1
;		3 - Vpp/MCLR
;		4 - GP4 Ausgang, Meldeleitung Unterspannung / LED gelb
;		5 - GP5 Ausgang, Jumper: Anode LED rot
;
; Grundlagen: 
; siehe Lernbeispiel Schwellwertschalter von Sprut. Schwellwert-
; schalter mit Hysterese über Spannungsmessung per ADC/CH0. 
;
; ##################################################################
; 3 Prozessoren PIC12F675 (Fabrikzustand) stehen zur Auswahl:
; PIC1: OSCCAL: 344C, BandGap: 0000, Configuration: 01FF, DIL
; PIC2: OSCCAL: 3434, BandGap: 0000, Configuration: 01FF, DIL
; PIC3: OSCCAL: 3434, BandGap: 1000, Configuration: 01FF, DIL
; PIC4: OSCCAL: 3450, BandGap: 1000, Configuration: 01FF, SMD
;
; Prozessor-Takt 4 MHz intern
; Autor: Dipl.-Ing. Lothar Hiller
; ##################################################################
; Includedatei für den 12F675 einbinden:
	list	p=12f675
	#include <P12f675.INC>
	ERRORLEVEL      -302    	;SUPPRESS BANK SELECTION MESSAGES

; Configuration festlegen:
; MCLR ein, Power on Timer, kein WDT, int-Oscillator, kein Brown out
	__CONFIG	_MCLRE_ON & _PWRTE_ON & _WDT_OFF & _INTRC_OSC_NOCLKOUT & _BODEN_OFF
; ##################################################################
; Variablen festlegen  (20h ... 5Fh):
miniteil	equ	0x20	; Zeitverzögerungs-UP'e
miditeil	equ	0x21	
maxiteil	equ	0x22
time0		equ	0x23
time1		equ	0x24
time2		equ	0x25
;
Uon1		equ	0x30	; Main
Uoff1		equ	0x31
Umin		equ	0x32
Uwarn		equ	0x33
Uaus		equ	0x34
akku		equ	0x35
;
; Variablen für Mathe-UP'e, Zähler usw.
f1			equ	0x40
f0			equ 0x41
xw1			equ	0x42
xw0			equ	0x43
count		equ	0x46
counter		equ	0x47	; Div2
NrMessung	equ	0x48	; Anzahl der Mehrfachmessungen
Fehler		equ	0x49
;
; ##################################################################
	org	0x00
	goto	PicInit

; Initialisierung
PicInit
	; IO-Pins
	bcf		STATUS, RP0	; Bank0
	clrf	GPIO		; Init GPIOs
	movlw	0x07
	movwf	CMCON		; Comparator aus, Digital
	bsf		STATUS, RP0	; Bank1
	movlw	b'00001011'	; Eing.=1 oder Ausg.=0 festlegen:
	movwf	TRISIO		; alles Ausgänge, außer: AN0,1 u. GP3/MCLR
	bcf		STATUS, RP0	; Bank0
	;
	; internen Taktgenerator kalibrieren
	bsf	STATUS, RP0		; Bank1
	call	0x3FF
	movwf	OSCCAL		; 4-MHz-Kalibrierung
	bcf		STATUS, RP0	; Bank0
	;
	; Interrupt
	bcf		INTCON, GIE	; Int deaktiviert
	;
	; ADC initialisieren u. einschalten: 
	;(Mess-Eingang GP0/AN0, Uref-Eingang GP1/AN1)
	; ADFM=0 (linksbündig), VCFG=1 (Uref-pin), CHS1:CHS0=00 (AN0),
	; ADON=1 ADC Ein.
	movlw	b'01000001'
	movwf	ADCON0
	;
	; ANSEL (Bank1)
	; ADC-Geschwindigkeit für 4MHz auf TAD=2µs einstellen => Fosc/8
	; GP0 => AN0: auf analog stellen
	; ADCS2:0=001 (Fosc/8), ANS3:0=0011 (AN1,AN0)
	bsf		STATUS,RP0	; Bank1
	movlw	b'00010011'	;
	movwf	ANSEL
	bcf		STATUS,RP0	; Bank0
	;
	; Schwellwert festlegen für AN0=max.2,5V (Spannungsteiler 1:1)
	; und Uref=2,5V !!
	; Beispiel: Bei Uakku < 3,5V soll LED rot, 
	; bei < 3,3V soll LED orange einschalten.
	; Schwellwerte:
	; 3,3/2/2,5*1024 = d'676' = b'1010100100', davon die li. 8 Bits:
	; b'10101001' = d'169' = 0xa9.
; Beispiele aus dem 3V-Bereich:
; 2,8V => d'144' = 0x90;   2,9V => d'149' = 0x95
; 3,0V => d'154' = 0x9a;   3,1V => d'159' = 0x9f
; 3,2V => d'164' = 0xa4;   3,3V => d'169' = 0xa9	 
; 3,4V => d'174' = 0xae;   3,5V => d'179' = 0xb3
; 3,6V => d'184' = 0xb8;   3,7V => d'189' = 0xbd
; 3,8V => d'194' = 0xc2;   3,9V => d'199' = 0xc7
	;
	movlw	0xb3		; Umin=3,5V
	movwf	Umin
	movlw	0xa9		; Uwarn=3,3V
	movwf	Uwarn
	movlw	0x9a		; Uaus=3,0V
;	movlw	0x95		; Uaus=2,9V
	movwf	Uaus
	;
	clrf	akku		; akku=0
	bcf		GPIO,2		; GPIO,2=0, T1=Ein
;
; ##################################################################
Main
	; prüfen ob akku,0=0 Akku geladen oder akku,0=1 Akku leer
	btfsc	akku,0		; wenn akku,0=0, überspringe nä. Bef.
	goto	abschalt	; akku,0=1, Akku leer
						; akku,0=0, Akku ok., weiter
	;
	; 64 mal U messen (obere 8 Bit nach xw0) u. in f1, f0 addieren
	clrf	f1
	clrf	f0
	; 64 Messungen
	movlw	D'64'
	movwf	NrMessung
Messung
	call	UMessenXw0	; Messwerte nach xw0 !
	call	Add16		; 16-bit add: f:= f + xw
	decfsz	NrMessung,f
	goto	Messung

	; 64x Messergebnis stehen nun aufsummiert in f1, f0
	; f1, f0 nach xw umspeichern und durch 64 (w=6) dividieren
	movfw	f1
	movwf	xw1
	movfw	f0
	movwf	xw0
	movlw	0x06
	call	Div2		; Ergebnis in xw0
	;
	movfw	xw0			; umspeichern nach f0
	movwf	f0			; Mittelwert (obere 8 Bit) nun in f0
	;
	; obere 8 Bit in f0 vergleichen und T1 schalten
	call	unterU		; f0 prüfen auf Unterspannung
	movlw	D'4'
	call	maxitime	; 1 Sek. Wartezeit
	goto	Main		; neuer Zyklus
	;
abschalt
	bsf		GPIO,2		; GPIO,2=1, T1=Aus
	goto Main
;
; ##################################################################
; ################################################################
; INCLUDE für Hilfsprogramme:
	#include <quarz_4MHz.asm>		; Zeitverzög.-UP'e
;
; ##################################################################
; Unterprogramme:
; ##################################################################
; UP Aquisit
Aquisit
	clrf	count		; wenn Mess-Eingang wechselt
aqui_loop				; 0,3ms ADC Aquisitionszeit nach Eingangswahl
	decfsz	count,f
	goto	aqui_loop
	return
;
; ##################################################################
; UP UMessenXw0: ADC mißt Spannung an ANx linksbündig,
; Ergebnis (obere 8 Bit) nach xw0
; ##################################################################
UMessenXw0
	bsf		ADCON0,1	; Wandlung starten
wandelnX
	btfsc	ADCON0,1	; ist der ADC fertig ?
	goto	wandelnX	; nein, weiter warten
	movfw	ADRESH		; obere 8 Bit ins W auslesen
	movwf	xw0			; W -> xw0
	;
	bsf		STATUS,RP0	; Bank1
	movfw	ADRESL		; untere 2 Bit nach f0, hier unbenutzt
	bcf		STATUS,RP0	; Bank0
	;
	clrf	count		; Warten, damit sich der ADC erholen kann
wartenX
	decfsz	count,f
	goto	wartenX
	return
;
; ##################################################################
; UP unterU, f0 auf Unterspannung prüfen (3 Stufen):
; LED rot Ein, wenn f0 < w (Umin). Signal Unterspannung !
; Wenn f0 >= w (Umin), dann LED Aus, keine Unterspannung.
; ##################################################################
unterU
	; 1. Stufe: prüfen ob f0 < Umin
	movfw	Umin		; w:=Umin
	subwf	f0,w		; w:=f0-w
	; Ergebnis der Subtraktion:
	; f > w => C=1, Z=0
	; f = w => C=1, Z=1
	; f < w => C=0, Z=0
	btfss	STATUS,C	; wenn C=1, überspringe nä. Bef.
	goto	unterUmin	; C=0, Unterspannung
	bcf		GPIO,5		; C=1, keine Unterspannung, LED Aus
	return
	;
unterUmin
	bsf		GPIO,5		; C=0, Unterspannung, LED rot Ein
	; 2. Stufe: prüfen ob f0 < Uwarn
	movfw	Uwarn		; w:=Uwarn
	subwf	f0,w		; w:=f0-w
	; Ergebnis der Subtraktion, siehe oben
	btfss	STATUS,C	; wenn C=1, überspringe nä. Bef.
	goto	unterUwarn	; C=0, Uwarn unterschritten
	bcf		GPIO,4		; C=1, keine Unterspannung, GP4=Low
	return
	;
unterUwarn
	bsf		GPIO,4		; C=0, Unterspannung Uwarn, GP4=High
	; 3. Stufe: prüfen ob f0 < Uaus
	movfw	Uaus		; w:=Uaus
	subwf	f0,w		; w:=f0-w
	; Ergebnis der Subtraktion, siehe oben
	btfss	STATUS,C	; wenn C=1, überspringe nä. Bef.
	goto	unterUaus	; C=0, Uaus unterschritten
	return				; C=1, Uaus nicht unterschritten
	;
unterUaus
	; 3 Min. warten, damit Pi herunter fahren kann:
	bcf		GPIO,5		; GP5=0, LED rot AUS
	bsf		GPIO,4		; GP4=1, LED gelb EIN
	movlw	D'240'		; Warteschleife 240x0,25 Sek. = 1 Min.
	call	maxitime
	bsf		GPIO,5		; GP5=1, LED rot EIN
	bcf		GPIO,4		; GP4=0, LED gelb AUS
	movlw	D'240'		; Warteschleife 240x0,25 Sek. = 1 Min.
	call	maxitime
	bcf		GPIO,5		; GP5=0, LED rot AUS
	bsf		GPIO,4		; GP4=1, LED gelb EIN
	movlw	D'240'		; Warteschleife 240x0,25 Sek. = 1 Min.
	call	maxitime
	bsf		GPIO,5		; GP5=1, LED rot EIN
	bsf		GPIO,2		; GP2=1, T1=Aus (Akku abschalten)
	bsf		akku,0		; akku,0=1 (Akku-Kontrollbit)
	return				; Nun ist Bu2 aus, LED grün aus
;
; ##################################################################
; Mathe-(2 Byte)-Unterprogramme: Add16, Sub16, Div2
; ##################################################################
;
; ##################################################################
; UP Add16: 16 bit Adition, C-Flag bei Überlauf gesetzt
; ##################################################################
Add16 		; 16-bit add: f = f + xw
	movf	xw0,W		;low byte
	addwf	f0,F 		;low byte add
;
	movf	xw1,W 		;next byte
	btfsc	STATUS,C 	;skip to simple add if C was reset
	incfsz	xw1,W 		;add C if it was set
	addwf	f1,F 		;high byte add if NZ
	return
;
; ##################################################################
; UP Div2: Division durch 2 wird w-mal ausgeführt,
; die zu dividierende Zahl steht in xw
; ##################################################################
Div2 
	movwf	counter		; Anzahl der Divisionen speichern
Div2a					; 16 bit xw:=xw/2
	bcf		STATUS,C	; carry löschen
	rrf		xw1,F
	rrf		xw0,F
	decfsz	counter,F	; fertig?
	goto	Div2a		; nein: noch mal
	return
;
;Anwendung:
;	movf	f0,W		; f ==> W ==> xw
;	movwf	xw0
;	movf	f1,W
;	movwf	xw1		;
;			;z.B. xw durch 64 dividieren (6 mal durch 2):
;			; also W=6
;	movlw	0x06
;	call	Div2
;
; ##################################################################
; Kalibrierwert für PIC12F675 auf Adresse 3FFH ablegen
; ##################################################################
	org		0x03FF
;	retlw	0x4c		; Kalibrierwert PIC1
;	retlw	0x34		; Kalibrierwert PIC2, PIC3
	retlw	0x50		; Kalibrierwert PIC4
;
; ##################################################################
	end
; Ende Datei schwellwert_multi.asm