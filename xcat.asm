;Hardware interface:
; Port A: Address bus A0 -> A5  (input)
;
; Port B: Data bus DB0 -> DB7   (output when /CE = 0)
;
; Port C0: Mode select 6 out    (output)
; Port C1: Synchronous data clk (input)
; Port C2: /CE                  (input)
; Port C3: Address bus A6       (input)
; Port C4: Address bus A7       (input)
; Port C5: Address bus A8       (input)
; Port C6: Serial TXD           (output)
; Port C7: Serial RXD           (input)
;
; Port D0->D7 'User function' outputs, multiple possible uses depending
;       on configuration
; port D alternate functions:
; Port D0: COS                  (input)
; Port D1:
;
; $Log: xcat.asm,v $
; Revision 1.1  2004/07/03 16:38:59  Skip Hansen
; Initial revision
;
;
        processor       16F877a
        include <p16f877a.inc>
        include defines.inc

        extern  AARGB0, AARGB1,AARGB2,AARGB3
        extern  BARGB0, BARGB1, BARGB2, BARGB3
        extern  REMB0, REMB1, REMB2, REMB3
        extern  FXD3232U,serialinit,rxdata,txdata
        extern  mode_1,mode_17,memchan
        extern  sendmode,CanSend
        extern  cnv_generic,cnvcactus
        extern  pltable,limits10m,limits6m,limits2m,limits440

        global  settxf,setrxf
        global  rxf_0,rxf_1,rxf_2,rxf_3
        global  txf_0,txf_1,txf_2,txf_3
        global  fvco_0,fvco_1,fvco_2,fvco_3
        global  DivA,N1_0,N1_1,N1_2,N1_3

        __config  _HS_OSC & _BODEN_ON & _CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF

;variables present in all banks
COMMON  udata
W_TEMP  res     1
        global  nbtemp
nbtemp  res     1

;Bank 0 RAM variables
DATA0   udata
PCLATH_TEMP
        res     1
STATUS_TEMP
        res     1

;Current Rx frequency in Hz
rxf_0   res     1       ;msb
rxf_1   res     1
rxf_2   res     1
rxf_3   res     1       ;lsb


;Current Tx frequency in Hz
txf_0   res     1       ;msb
txf_1   res     1
txf_2   res     1
txf_3   res     1       ;lsb


DivA    res     1       ;6 bits

DivB_0  res     1       ;10 bits
DivB_1  res     1

;VCO frequency in Hz
;NB keep fvco_* and N1_* together, they are used as a 16 byte buffer for
;transfering the VCO split frequencies

fvco_0  res     1       ;msb
fvco_1  res     1
fvco_2  res     1
fvco_3  res     1       ;lsb

;
N1_0  res     1
N1_1  res     1
N1_2  res     1
N1_3  res     1

DivC       res     1

        global  LoopCnt
LoopCnt res     1


; -------------------------------------------------------------------------
;The following must remain in order as they are read from EEROM on powerup

        global  code_0,code_4,code_5
code_0  res     1       ;nonpriority scan list M1->M8
code_1  res     1       ;nonpriority scan list M9->M16
code_2  res     1       ;nonpriority scan list M17->M24
code_3  res     1       ;nonpriority scan list M25->M32
code_4  res     1       ;tx PL/DPL 0->7
code_5  res     1       ;tx PL/DPL 8->15
code_6  res     1       ;rx PL/DPL 0->7
code_7  res     1       ;rx PL/DPL 8->16
code_8  res     1       ;Timeout T0->T4, Power control, Ref Freq R0->R1
code_9  res     1       ;Scan control ST0->ST1, TB, P2_0->P2_5
code_a  res     1       ;P1_0->P1_4, SQ0->SQ1, SS
code_b  res     1       ;C0->C1, V0->V1
code_c  res     1       ;DivB6->DivB9
code_d  res     1       ;DivB2->DivB5
code_e  res     1       ;DivA4->DivA5, DivB0->DivB1
code_f  res     1       ;DivA0->DivA3

        global  TxOff_3,TxOff_2,TxOff_1,TxOff_0
TxOff_3         res     1       ;lsb
TxOff_2         res     1
TxOff_1         res     1
TxOff_0         res     1

        global  Config0
Config0 res     1       ;Configuration byte 0
        global  ConfUF
ConfUF  res     1       ;User function output

; -------------------------------------------------------------------------

selmode res     1


LastA   res     1
LastC   res     1

Flags   res     1
#define FLAG_COS        0       ;Bit 0 = 1 - have Carrier detect
#define FLAG_MODEIRQ    1       ;Bit 1 = 1 - Syntor read mode data
#define FLAG_LOWBAND    2       ;Bit 2 = 1 - Lowband frequency range
#define FLAG_VHF        3       ;Bit 3 = 1 - VHF frequency range
#define FLAG_UHF        4       ;Bit 4 = 1 - UHF frequency range
        ;return values from calclowv
#define FLAG_V0         5       ;Bit 5 = 1 - V0 set
#define FLAG_V1         6       ;Bit 6 = 1 - V1 set
#define FLAG_CLR_FREQ   0x83    ;clear frequency calculation related bits

        global  mode
mode    res     1

DATA1   udata
;serial clock & data from control system - Bank 1 RAM
srx5    res     1               ;last byte clocked in
srx4    res     1               ;
srx3    res     1               ;
srx2    res     1               ;
srx1    res     1               ;first byte clocked in

srxbits res     1               ;number of bits clocked in from BCD port
srxto   res     1


        ; Start at the reset vector
STARTUP code
        goto    startup         ;adr = 2 for hex loader
        nop
        ;interrupt vector
isr     MOVWF   W_TEMP          ;Copy W to TEMP register
        SWAPF   STATUS,W        ;Swap status to be saved into W
        CLRF    STATUS          ;bank 0
        MOVWF   STATUS_TEMP     ;Save status to bank zero STATUS_TEMP register
        MOVF    PCLATH,W        ;Only required if using pages 1, 2 and/or 3
        MOVWF   PCLATH_TEMP     ;Save PCLATH into W
        movlw   high isr_cont   ;
        movwf   PCLATH          ;
        goto    isr_cont

PROG2   code
        ;isr continuation
isr_cont
        btfss   PIR1,CCP1IF     ;/OE interrupt ?
        goto    isr1            ;not an /OE interrupt
        movlw   0xff            ;
        movwf   PORTB           ;
        bsf     STATUS,RP0      ;bank 1
        clrf    TRISB           ;turn on Port B output drivers
        bcf     STATUS,RP0      ;bank 0
        bsf     Flags,FLAG_MODEIRQ

;unfortunately this is a critical timing delay loop...
;The LSB of the address is valid 25.6 microseconds (128 cycles) after
;the following edge of /OE

        movlw   0x22
        movwf   selmode
delayloop
        decfsz  selmode,f
        goto    delayloop
        movf    PORTC,w
        movwf   LastC

        movlw   high mode_1
        btfsc   PORTC,5         ;
        movlw   high mode_17
        movwf   PCLATH          ;
        nop                     ;

        movf    PORTA,w         ;w = A0->A5 (this should occur 129 cycles after /oe)
        btfsc   PORTC,3         ;
        iorlw   0x40            ;
        btfsc   PORTC,4         ;
        iorlw   0x80            ;
        movwf   LastA
        call    GetCodeData     ;
        movwf   PORTB           ;

synloop
        movf    PORTA,w         ;w = A0->A5
        btfsc   PORTC,3         ;
        iorlw   0x40            ;
        btfsc   PORTC,4         ;
        iorlw   0x80            ;
        call    GetCodeData     ;
        movwf   PORTB           ;

        btfss   PORTC,2         ;wait for /OE to go inactive
        goto    synloop         ;

isr1    btfss   PIR2,CCP2IF     ;serial clock interrupt ?
        goto    returni         ;nope, exit interrupt handler

        ;clock in a new data bit
        bcf     STATUS,C        ;assume serial data is low
        btfsc   SERAL_DAT       ;jump if so
        bsf     STATUS,C        ;
        bsf     STATUS,RP0      ;bank 1
        rrf     srx5,f          ;
        rrf     srx4,f          ;
        rrf     srx3,f          ;
        rrf     srx2,f          ;
        rrf     srx1,f          ;
        incf    srxbits,f       ;increment bit count
        clrf    srxto           ;clear timeout counter
        bcf     STATUS,RP0      ;bank 0
        bcf     PIR2,CCP2IF     ;

returni bsf     STATUS,RP0      ;bank 1
        movlw   0xff            ;
        movwf   TRISB           ;turn off Port B output drivers
        bcf     STATUS,RP0      ;bank 0
        bcf     PIR1,CCP1IF     ;

        MOVF    PCLATH_TEMP, W  ;Restore PCLATH
        MOVWF   PCLATH          ;Move W into PCLATH
        SWAPF   STATUS_TEMP,W   ;Swap STATUS_TEMP register into W
;(sets bank to original state)
        MOVWF   STATUS          ;Move W into STATUS register

;nb: why swap instead of ldf ?  because it doesn't effect the
;flags already restored to the STATUS register !

        SWAPF   W_TEMP,F        ;Swap W_TEMP
        SWAPF   W_TEMP,W        ;Swap W_TEMP into W
        retfie

GetCodeData
        movwf   PCL             ;

;VFO mode
        global  vfo0,vfo1,vfo2,vfo3,vfo4,vfo5,vfo6,vfo7
        global  vfo8,vfo9,vfoa,vfob,vfoc,vfod,vfoe,vfof

vfo0    movf    code_0,w
        movwf   PORTB
        return

vfo1    movf    code_1,w
        movwf   PORTB
        return

vfo2    movf    code_2,w
        movwf   PORTB
        return

vfo3    movf    code_3,w
        movwf   PORTB
        return

vfo4    movf    code_4,w
        movwf   PORTB
        return

vfo5    movf    code_5,w
        movwf   PORTB
        return

vfo6    movf    code_6,w
        movwf   PORTB
        return

vfo7    movf    code_7,w
        movwf   PORTB
        return

vfo8    movf    code_8,w
        movwf   PORTB
        return

vfo9    movf    code_9,w
        movwf   PORTB
        return

vfoa    movf    code_a,w
        movwf   PORTB
        return

vfob    movf    code_b,w
        movwf   PORTB
        return

vfoc    movf    code_c,w
        movwf   PORTB
        return

vfod    movf    code_d,w
        movwf   PORTB
        return

vfoe    movf    code_e,w
        movwf   PORTB
        return

vfof    movf    code_f,w
        movwf   PORTB
        return


startup1
;Init port A
        banksel PORTC           ;
        bsf     PORTC,0         ;mode select output high
        bsf     STATUS,RP0      ;bank 1
        movlw   0x6             ;Port A all digital inputs
        movwf   ADCON1
        movlw   0xff            ;
        movwf   TRISA           ;

;Init port C
        movlw   0xBE            ;C0 and C6 are outputs
        movwf   TRISC           ;
        
        bcf     STATUS,RP0      ;bank 0

        ;read mode 1, Tx offset and configuration bytes from EEPROM
        movlw   high readee1    ;
        movwf   PCLATH
        
        movlw   d'16'+4+CONFIG_BYTES ;number of bytes to read
        movwf   DivC            ;
        BSF     STATUS,RP1      ;Bank 2
        movlw   MODE1_ADR       ;
        movwf   EEADR           ;
        clrf    EEADRH          ;
        movlw   low code_0      ;point to start of data
        call    readee1         ;
        
        call    serialinit      ;initialize serial port
        
;Init port D
        movf    ConfUF,w        ;1 = user output bit
        xorlw   0xff            ;invert for tristate control
        bsf     STATUS,RP0      ;bank 1
        movwf   TRISD           ;
        bcf     STATUS,RP0      ;bank 0
        

;initialize timer 2 for a real time clock
;20 Mhz / 4 / 1 / 65536 = 76.29 hz or 13.11 milliseconds
        MOVLW   B'00000001'     ; 1:1 prescale, no osc, no sync, internal clock,
                                ; enable
        movwf   T1CON           ;

        swapf   Config0,w       ;
        andlw   CONFIG_CTRL_MASK;
        btfss   STATUS,Z        ;
        call    SyncClkInit     ;init synchronous clock interrupts

        banksel code_0          ;

;enable interrupt on /CE (ccp1 input)

        movlw   4               ;capture mode, every falling edge
        movwf   CCP1CON         ;

        bsf     STATUS,RP0      ;bank 1
        bsf     PIE1,CCP1IE     ;
        movlw   0xc0            ;enable global & Peripherial interrupts
        movwf   INTCON          ;
        bcf     STATUS,RP0      ;bank 0

        ifdef  VHF_RANGE_1
        ;VHF range 1 radio, tx vco split
        ;144000000 = 8954400
        movlw   0x00            ;
        movwf   BARGB3
        movlw   0x44            ;
        movwf   BARGB2
        movlw   0x95            ;
        movwf   BARGB1
        movlw   0x8             ;
        movwf   BARGB0
        
        movlw   high write32ee  ;
        movwf   PCLATH
        movlw   TX_VCO_SPLIT_F  ;
        call    write32ee
        
        ;VHF range 1 radio, rx vco split
        ;198500000 = BD4DEA0
        movlw   0xa0            ;
        movwf   BARGB3
        movlw   0xde            ;
        movwf   BARGB2
        movlw   0xd4            ;
        movwf   BARGB1
        movlw   0xb             ;
        movwf   BARGB0
        movlw   RX_VCO_SPLIT_F  ;
        call    write32ee
        endif
        
        ifdef  VHF_RANGE_2
        ;VHF range 2 radio, tx vco split
        ;161800000 = 9A4DF40
        movlw   0x40            ;
        movwf   BARGB3
        movlw   0xdf            ;
        movwf   BARGB2
        movlw   0xa4            ;
        movwf   BARGB1
        movlw   0x9             ;
        movwf   BARGB0
        
        movlw   high write32ee  ;
        movwf   PCLATH
        movlw   TX_VCO_SPLIT_F  ;
        call    write32ee
        
        ;VHF range 2 radio, rx vco split
        ;161600000 = 9A1D200
;        movlw   0x00            ;
;        movwf   BARGB3
;        movlw   0xd2            ;
;        movwf   BARGB2
;        movlw   0xa1            ;
;        movwf   BARGB1
;        movlw   0x9             ;
;        movwf   BARGB0

        ;150000000 = 8F0D180
        movlw   0x80            ;
        movwf   BARGB3
        movlw   0xd1            ;
        movwf   BARGB2
        movlw   0xf0            ;
        movwf   BARGB1
        movlw   0x8             ;
        movwf   BARGB0

        movlw   RX_VCO_SPLIT_F  ;
        call    write32ee
        endif
        
        return

        ;read 32 bit int from FLASH into BARGB3 .. BARGB0
        ;EEADR, EEADRH previously setup
read32  movlw   4               ;number of bytes to read
        movwf   DivC            ;
        movlw   low BARGB3      ;point to LSB

readflash
        BSF     STATUS,RP1      ;Bank 2
        BSF     STATUS,RP0      ;Bank 3
        movwf   FSR             ;
        BSF     EECON1,EEPGD    ;Point to Flash (program) memory
        goto    rd_loop         ;

readee1        
        BSF     STATUS,RP1      ;Bank 2
        BSF     STATUS,RP0      ;Bank 3
        movwf   FSR             ;
        BCF     EECON1,EEPGD    ;Point to EEPROM memory

rd_loop BSF     STATUS,RP1      ;Bank 3
        BSF     STATUS,RP0      ;
        bsf     EECON1,RD
        nop
        nop
        bcf     STATUS,RP0      ;bank 2
        movf    EEDATA,w        ;get the data from Flash/EEPROM
        incf    EEADR,f         ;

        BCF     STATUS,RP1      ;Bank 0
        movwf   INDF            ;save byte
        incf    FSR,f           ;

        decfsz  DivC,f          ;
        goto    rd_loop         ;
        return                  ;

;enable interrupt on Synchronous clock (ccp2 input)
SyncClkInit
        movlw   4               ;capture mode, every falling edge
        movwf   CCP2CON         ;

        bsf     STATUS,RP0      ;bank 1
        bsf     PIE2,CCP2IE     ;
        bcf     STATUS,RP0      ;bank 0
        return                  ;
;
;
PROG1   code
startup
        movlw   high startup1   ;
        movwf   PCLATH
        call    startup1        ;

        clrf    memchan         ;load mode 1 from EEPROM
        movlw   high recallmode ;
        movwf   PCLATH
        call    recallmode      ;
        
        ifdef   TEST_GENERIC
        movlw   CONFIG_2M       ;
        movwf   Config0         ;
        movlw   0xff            ;load 144.60
        movwf   AARGB0          ;srx1
        movlw   0xc2            ;
        movwf   AARGB1          ;srx2
        movlw   0xa4            ;144
        movwf   AARGB2          ;srx3
        movlw   0x60            ;.60
        movwf   AARGB3          ;srx4
        movlw   4               ;
        movwf   BARGB0          ;srx5
        call    cnv_generic     ;
        endif

        ifdef   TEST_GENERIC
        bsf     STATUS,RP0      ;bank 1
        movlw   0xff            ;load 449.220 -
        movwf   srx1            ;
        movlw   0xd4            ;
        movwf   srx2            ;
        movlw   0x89            ;
        movwf   srx3            ;
        movlw   0x22            ;
        movwf   srx4            ;
        movlw   0x54            ;
        movwf   srx5            ;
        movlw   d'40'           ;
        movwf   srxbits         ;
        clrf    srxto           ;clear timeout counter
        bcf     STATUS,RP0      ;bank 0
        endif

mainloop
        btfss   RCSTA,OERR      ;Overrun error ?
        goto    main4           ;
        ;Clear it !
        movf    RCREG,w         ;clear the fifo
        movf    RCREG,w         ;
        bcf     RCSTA,CREN      ;reset the the receiver
        bsf     RCSTA,CREN      ;
        
main4   
        movlw   high rxdata     ;
        movwf   PCLATH          ;
        ifndef SIMULATE
        btfsc   PIR1,RCIF       ;
        endif                   ;
        call    rxdata          ;
        
        movlw   high txdata     ;
        movwf   PCLATH          ;
        bsf     STATUS,RP0      ;bank 1
        btfsc   TXSTA,TRMT
        call    txdata          ;
        bcf     STATUS,RP0      ;bank 0
        movlw   high SaveMode   ;
        movwf   PCLATH          ;
        call    SaveMode        ;
        btfsc   Config0,CONFIG_COS_MSG  ;
        call    CheckSignal     ;
        btfss   PIR1,TMR1IF     ;
        goto    main1           ;

        ;the timer has ticked
        bcf     PIR1,TMR1IF     ;

        ;check for serial receive data timeout
        bsf     STATUS,RP0      ;bank 1
        movf    srxbits,w       ;
        btfsc   STATUS,Z        ;
        goto    main1           ;no bits received

        ;nope, increment timeout timer
        incf    srxto,f         ;
        movlw   4               ;> 50 milliseconds ?
        subwf   srxto,w         ;
        btfss   STATUS,Z        ;timeout ?
        goto    main1           ;nope

        ;serial clock timeout, process the data clocked in
        bcf     PIE2,CCP2IE     ;disable further clock interrupt while
                                ;processing the data

        ;copy srx1...srx5 into Bank0 for the conversion routines
        movf    srx1,w          ;
        bcf     STATUS,RP0      ;bank 0
        movwf   AARGB0          ;

        bsf     STATUS,RP0      ;bank 1
        movf    srx2,w          ;
        bcf     STATUS,RP0      ;bank 0
        movwf   AARGB1          ;

        bsf     STATUS,RP0      ;bank 1
        movf    srx3,w          ;
        bcf     STATUS,RP0      ;bank 0
        movwf   AARGB2          ;

        bsf     STATUS,RP0      ;bank 1
        movf    srx4,w          ;
        bcf     STATUS,RP0      ;bank 0
        movwf   AARGB3          ;

        bsf     STATUS,RP0      ;bank 1
        movf    srx5,w          ;
        bcf     STATUS,RP0      ;bank 0
        movwf   BARGB0          ;

        bsf     STATUS,RP0      ;bank 1
        movf    srxbits,w       ;
        bcf     STATUS,RP0      ;bank 0
        movwf   BARGB1          ;

        bsf     STATUS,RP0      ;bank 1
        bsf     PIE2,CCP2IE     ;re-enable clock interrupts
        bcf     STATUS,RP0      ;bank 0

        movlw   high main3
        movwf   PCLATH

        swapf   Config0,w       ;
        andlw   CONFIG_CTRL_MASK;
        addwf   PCL,f
main3   goto    main2           ;no control system configured
        goto    generic         ;
        goto    cactus          ;
        goto    main2           ;not used

        ;Generic mode, we should have exactly 5 bytes of data
generic movf    BARGB1,w        ;
        sublw   d'40'           ;
        btfsc   STATUS,Z        ;
        call    cnv_generic     ;
        goto    main2           ;

        ;Cactus mode, we should have exactly 3 bytes of data
cactus  movf    BARGB1,w        ;
        sublw   d'24'           ;
        btfsc   STATUS,Z        ;
        call    cnvcactus       ;

main2   bsf     STATUS,RP0      ;bank 1
        clrf    srxbits         ;reset for next time
        clrf    srxto           ;

main1   bcf     STATUS,RP0      ;bank 0
        goto    mainloop

;Send signal received/lost state changes
CheckSignal
        btfsc   COS_DAT         ;COS Active ?
        goto    GotSignal       ;
        ;no signal
        btfss   Flags,FLAG_COS  ;
        return

        call    CanSend         ;
        btfss   STATUS,Z        ;
        return

        ;report lost signal
        bcf     Flags,FLAG_COS  ;
        movlw   0               ;
        goto    sendmode        ;

GotSignal
        btfsc   Flags,FLAG_COS  ;
        return
        ;report got signal

        call    CanSend         ;
        btfss   STATUS,Z        ;
        return

        ;report signal received
        bsf     Flags,FLAG_COS  ;
        movlw   1
        goto    sendmode        ;

SaveMode
        btfss   Flags,FLAG_MODEIRQ      ;
        return

        ;possible new mode
        bcf     Flags,FLAG_MODEIRQ      ;
        movf    LastA,w         ;
        movwf   mode            ;
        rrf     mode,f
        rrf     mode,f
        rrf     mode,f
        rrf     mode,f
        movlw   0xf
        andwf   mode,w          ;
        btfsc   LastC,5         ;
        iorlw   0x10
        movwf   mode            ;
        return

CLookup
        movlw   high CLookup
        movwf   PCLATH
        movf    DivC,w
        addwf   PCL,f
        retlw   0x20
        retlw   0x10
        retlw   0x30

chkremainder
        movf    REMB0,w
        iorwf   REMB1,w
        iorwf   REMB2,w
        iorwf   REMB3,w
        return

zeroquotient
        movf    AARGB0,w
        iorwf   AARGB1,w
        iorwf   AARGB2,w
        iorwf   AARGB3,w
        return

;copy fvco -> AARGB
copyfvco
        movf    fvco_0,w
        movwf   AARGB0
        movf    fvco_1,w
        movwf   AARGB1
        movf    fvco_2,w
        movwf   AARGB2
        movf    fvco_3,w
        movwf   AARGB3
        return

;
;Given desired VCO frequency in fvco calculate DivB, DivA and DivC
;returns with w = 0 if frequency is not a multiple of either references
;
calcN
        ;try 5Khz reference frequency
        call    copyfvco
        bsf     code_8,0        ;set
        bsf     code_8,1        ;
        clrf    BARGB0
        clrf    BARGB1
        movlw   0x13            ;BARG = 5000
        movwf   BARGB2          ;
        movlw   0x88
        movwf   BARGB3          ;
        
        call    FXD3232U        ;
        call    chkremainder
        btfsc   STATUS,Z        ;
        goto    refok

        ;try 6.25Khz reference frequency

        call    copyfvco
        bcf     code_8,0        ;
        bcf     code_8,1        ;
        movlw   0x18            ;BARG = 6250
        movwf   BARGB2          ;
        movlw   0x6a
        movwf   BARGB3          ;
        call    FXD3232U        ;
        call    chkremainder
        btfss   STATUS,Z        ;
        goto    badfreq

refok   clrf    BARGB2          ;
        btfsc   Flags,FLAG_LOWBAND      ;lowband ?
        goto    Cnotzero        ;jump if so, low band radio, no /3 prescaller

        ;N = fvco / refreq; (N is in AARGB)
        ;c = N % 3; N1 = N / 3;
        movlw   0x3
        movwf   BARGB3          ;
        call    FXD3232U        ;
        movf    REMB3,w
        movwf   DivC
        btfss   STATUS,Z        ;
        goto    Cnotzero

        ;N1--
        movlw   1
        subwf   AARGB3,f
        btfss    STATUS,C
        subwf   AARGB2,f
        btfss    STATUS,C
        subwf   AARGB1,f
        btfss    STATUS,C
        subwf   AARGB0,f

Cnotzero
        ;save N1
        movf    AARGB0,w
        movwf   N1_0
        movf    AARGB1,w
        movwf   N1_1
        movf    AARGB2,w
        movwf   N1_2
        movf    AARGB3,w
        movwf   N1_3

        ;DivA = N1 % 63;
        movlw   d'63'
        movwf   BARGB3          ;
        call    FXD3232U        ;
        call    chkremainder
        btfss   STATUS,Z        ;
        goto    DivAnotzero

        ;if DivA == 0 then DivA = 63; N1 -= 63;
        movlw   d'63'
        movwf   REMB3
        subwf   N1_3,f
        movlw   d'1'
        btfss    STATUS,C
        subwf   N1_2,f
        btfss    STATUS,C
        subwf   N1_1,f
        btfss    STATUS,C
        subwf   N1_0,f

DivAnotzero
        ;save DivA
        movf    REMB3,w
        movwf   DivA

        ;N2 = txn1 / 63;

        movf    N1_0,w
        movwf   AARGB0
        movf    N1_1,w
        movwf   AARGB1
        movf    N1_2,w
        movwf   AARGB2
        movf    N1_3,w
        movwf   AARGB3

        call    FXD3232U        ;

        ;save N2
        movf    AARGB2,w
        movwf   DivB_0
        movf    AARGB3,w
        movwf   DivB_1

        ;DivA = N2 - DivA;

        movf    DivA,w
        subwf   DivB_1,f
        btfss   STATUS,C
        decf    DivB_0,f

        ;now pack DivA, DivB_1 into proper bits for TX

        clrf    BARGB0          ;code_c

        movlw   0x30            ;get top 2 bits of DivA into upper nibble of W
        andwf   DivA,w          ;
        movwf   BARGB2          ;set A4,A5 in code_e

        swapf   DivA,f
        movlw   0xf0
        andwf   DivA,w          ;get bottom 4 bits of DivA in upper nibble of W
        movwf   BARGB3          ;set A0->A3 in code_f

        rrf     DivB_1,f
        rrf     DivB_1,f
        rrf     DivB_1,w
        andlw   0xc0
        iorwf   BARGB2,f        ;set B0,B1 in code e
        swapf   DivB_1,w
        andlw   0xf0
        movwf   BARGB1          ;set B2->B5 in code d

        movf    DivB_1,w
        andlw   0x30
        movwf   BARGB0          ;set B6,B7 in code c

        rrf     DivB_0,f
        rrf     DivB_0,f
        rrf     DivB_0,w
        andlw   0xc0
        iorwf   BARGB0,f        ;set B8, B9 in code c

        btfss   Flags,FLAG_LOWBAND      ;lookup C for all but lowband radios
        call    CLookup
        movwf   DivC
        iorlw   0x1             ;clear zero flag
        return

badfreq clrw                    ;set zero flag
        return

;BARG = BARG - AARG
;AARG is clobbered in the process
sub32   movf    AARGB3,w        ;
        subwf   BARGB3,f        ;
        btfss   STATUS,C
        incf    AARGB2,f        ;
        movf    AARGB2,w        ;
        subwf   BARGB2,f        ;
        btfss   STATUS,C
        incf    AARGB1,f        ;
        movf    AARGB1,w        ;
        subwf   BARGB1,f        ;
        btfss   STATUS,C
        incf    AARGB0,f        ;
        movf    AARGB0,w        ;
        subwf   BARGB0,f        ;
        return

;figure out V0, V1 for lowband radio
calcv_low
        bcf     Flags,FLAG_V0   ;assume v0=0, v1=0

        call    copyfvco
        ;fvco < 113.8 Mhz ?
        ;113800000 = 6C87340
        movlw   0x40            ;
        movwf   BARGB3
        movlw   0x73            ;
        movwf   BARGB2
        movlw   0xc8            ;
        movwf   BARGB1
        movlw   0x6             ;
        movwf   BARGB0
        call    sub32
        btfsc   STATUS,C        ; v0=0, v1=0
        return                  ;fvco < 113.8 Mhz

        ;fvco < 122.8 Mhz ?
        ;122800000 = 751C780
        call    copyfvco
        bsf     Flags,FLAG_V1
        movlw   0x80            ;
        movwf   BARGB3
        movlw   0xc7            ;
        movwf   BARGB2
        movlw   0x51            ;
        movwf   BARGB1
        movlw   0x7             ;
        movwf   BARGB0
        call    sub32
        btfsc   STATUS,C        ; v0=0, v1=1
        return                  ;fvco > 113.8 Mhz & fvco < 122.8 Mhz

        ;fvco < 132.6 Mhz ?
        ;132600000 = 7E750C0
        call    copyfvco
        bcf     Flags,FLAG_V1
        bsf     Flags,FLAG_V0
        movlw   0xc0            ;
        movwf   BARGB3
        movlw   0x50            ;
        movwf   BARGB2
        movlw   0xe7            ;
        movwf   BARGB1
        movlw   0x7             ;
        movwf   BARGB0
        call    sub32
        btfsc   STATUS,C        ; v0=1, v1=0
        return                  ;fvco > 122.8 & fvco < 132.6 Mhz

        bsf     Flags,FLAG_V1   ;v0=1, v1=1
        return                  ;fvco > 132.6 Mhz

;
setrange
        movlw   FLAG_CLR_FREQ   ;clear bits
        andwf   Flags,f
        movlw   0xb             ;f > 170 Mhz ?
        subwf   fvco_0,w        ;
        btfss   STATUS,C        ;
        goto    tryvhf          ;
        bsf     Flags,FLAG_UHF  ;UHF
        return                  ;

tryvhf  movlw   0x5             ;f > 100 Mhz ?
        subwf   fvco_0,w        ;
        btfss   STATUS,C        ;
        goto    lowband         ;
        bsf     Flags,FLAG_VHF  ;yup VHF
        return
        ;must be low band
lowband bsf     Flags,FLAG_LOWBAND
        return

chktxf  addwf   PCL,f           ;
        goto    check10m        ;
        goto    check6m         ;
        goto    check6_10       ;
        goto    check2m         ;
        goto    check440        ;
        goto    badfreq         ;not used
        goto    badfreq         ;not used
        goto    badfreq         ;not used

;make sure the specified tx frequency is in a ham band

check6_10
        call    check6m         ;
        btfss   STATUS,Z        ;Not a 6 meter frequency, try 10 meters
        return                  ;Yup a 6 meter frequency

check10m        
        movlw   low limits10m   ;
        goto    chktx1          ;continue

check6m
        movlw   low limits6m    ;
        goto    chktx1          ;continue

check2m
        movlw   low limits2m    ;
        goto    chktx1          ;continue

check440
        movlw   low limits440   ;
        
chktx1  bsf     STATUS,RP1      ;bank 2
        movwf   EEADR
        movlw   high limits10m
        movwf   EEADRH          ;
        bcf     STATUS,RP1      ;bank 0
chknxt        
        call    copyfvco        ;
        
        movlw   high read32     ;
        movwf   PCLATH
        call    read32          ;read lower band limit into BARGB
        
        movlw   high sub32      ;
        movwf   PCLATH
        call    sub32           ;
        
        ;tx frequency < lower band limit ?
        btfsc   STATUS,C        ;
        goto    badfreq         ;not in a Ham band !
        
        ;so far so good, check upper band limit
        call    copyfvco        ;
        movlw   high read32     ;
        movwf   PCLATH
        call    read32          ;read upper band limit into BARGB
        
        movlw   high sub32      ;
        movwf   PCLATH
        call    sub32           ;

        ;tx frequency < upper band limit ?
        btfsc   STATUS,C        ;
        goto    inband          ;yup in a Ham band !
        goto    badfreq         ;
        
;
;Set transmit bits, return with zero flag set on error, cleared if ok
;
settxf  
;set tx code to special receive only value (cffff) as a default in 
;case the specified frequency is not in the ham band.
        movf    code_b,w        ;
        andlw   0xf             ;
        iorlw   0xc0            ;
        movwf   code_b          ;
        movlw   0xf0            ;
        iorwf   code_c,f        ;
        iorwf   code_d,f        ;
        iorwf   code_e,f        ;
        iorwf   code_f,f        ;
        
        movf    txf_0,w
        movwf   fvco_0
        movf    txf_1,w
        movwf   fvco_1
        movf    txf_2,w
        movwf   fvco_2
        movf    txf_3,w
        movwf   fvco_3

        movlw   high chktxf     ;
        movwf   PCLATH
        movf    Config0,w       ;
        andlw   CONFIG_BAND_MASK;
        call    chktxf          ;
        btfsc   STATUS,Z        ;
        return                  ;Tx frequency not in a Ham band !
        
        call    setrange
        btfsc   Flags,FLAG_LOWBAND      ;
        goto    lowbandtx       ;

        bsf     Flags,FLAG_V0   ;VHF & UHF tx v0 = 1

        btfsc   Flags,FLAG_VHF  ;
        goto    vhftx

        ;UHF

        bsf     Flags,FLAG_V1   ;UHF tx v1 = 1 (for now, 450->460)
        goto    settx_cont      ;

        ;VHF - figure out V1 for Tx
vhftx   call    copyfvco
        movlw   TX_VCO_SPLIT_F  ;
        call    read32ee        ;read Tx VCO split frequency into BARGB

        ;fvco < Tx VCO split ?
        call    sub32
        btfsc   STATUS,C        ; v0=0, v1=0
        bsf     Flags,FLAG_V1   ;fvco < Tx VCO split, v1 = 1
        goto    settx_cont      ;

lowbandtx
        ;Low band
        ; fVco = 172.8 (0A 4C B8 00) Mhz
        clrf    fvco_3
        movlw   0xb8
        movwf   fvco_2
        movlw   0x4c
        movwf   fvco_1
        movlw   0xa
        movwf   fvco_0

; Low band fVco = 172.8 Mhz - fTx
        movf    txf_3,w
        subwf   fvco_3,f
        movf    txf_2,w
        btfss   STATUS,C        ;
        incf    txf_2,w
        subwf   fvco_2,f
        movf    txf_1,w
        btfss   STATUS,C        ;
        incf    txf_1,w
        subwf   fvco_1,f
        movf    txf_0,w
        btfss   STATUS,C        ;
        incf    txf_0,w
        subwf   fvco_0,f
        ;set flags for TX V0, V1
        call    calcv_low

settx_cont
        call    calcN
        andlw   1
        btfsc   STATUS,Z        ;
        goto    badfreq         ;

        ;clear tx bits from code bytes
        movlw   0xf
        andwf   code_b,f
        andwf   code_c,f
        andwf   code_d,f
        andwf   code_e,f
        andwf   code_f,f

        btfss   Flags,FLAG_LOWBAND      ;
        goto    settx1          ;vhf or uhf

        ;Low band c0=1, c1=1
        movlw   0x30
        goto    settx2          ;continue

settx1  movf    DivC,w          ;get code_b bits

settx2  iorwf   code_b,f

        ;set V0, V1 from flags previously set
        btfsc   Flags,FLAG_V0
        bsf     code_b,6
        btfsc   Flags,FLAG_V1
        bsf     code_b,7

        movf    BARGB0,w        ;code_c bits
        iorwf   code_c,f
        movf    BARGB1,w        ;code_d bits
        iorwf   code_d,f
        movf    BARGB2,w        ;code_e bits
        iorwf   code_e,f
        movf    BARGB3,w        ;code_f bits
        iorwf   code_f,f
        
inband  iorlw   0x1             ;clear zero flag
        return

;
;Set receive bits, return with zero flag set on error, cleared if ok
;
setrxf
        movf    rxf_0,w
        movwf   fvco_0
        movf    rxf_1,w
        movwf   fvco_1
        movf    rxf_2,w
        movwf   fvco_2
        movf    rxf_3,w
        movwf   fvco_3
        call    setrange

        btfsc   Flags,FLAG_UHF
        goto    uhf

        btfsc   Flags,FLAG_VHF
        goto    vhf

;low band: highside injection, add IF frequency of 75.7 Mhz (04 83 17 20)

        movlw   0x20
        addwf   fvco_3,f
        movlw   0x17
        btfsc   STATUS,C
        movlw   0x18
        addwf   fvco_2,f
        movlw   0x83
        btfsc   STATUS,C
        movlw   0x84
        addwf   fvco_1,f
        movlw   0x4
        btfsc   STATUS,C
        movlw   0x5
        addwf   fvco_0,f
        ;set flags for RX V0, V1
        call    calcv_low
        goto    rxcont

;VHF: highside injection, add IF frequency of 53.9 Mhz (03 36 72 E0)
vhf     movlw   0xe0
        addwf   fvco_3,f
        movlw   0x72
        btfsc   STATUS,C
        movlw   0x73
        addwf   fvco_2,f
        movlw   0x36
        btfsc   STATUS,C
        movlw   0x37
        addwf   fvco_1,f
        movlw   0x3
        btfsc   STATUS,C
        movlw   0x4
        addwf   fvco_0,f

        ;figure out V1 for Rx, highband radio
        call    copyfvco
        movlw   RX_VCO_SPLIT_F  ;
        call    read32ee        ;read Rx VCO split frequency into BARGB
        call    sub32
        ;fvco > Rx VCO split frequency ?
        btfss   STATUS,C        ;
        bsf     Flags,FLAG_V1   ;fvco > RxVCOSplit, v1 = 1
        goto    rxcont

;UHF: lowside injection, subtract IF frequency of 53.9 Mhz (03 36 72 E0)
uhf     movlw   0xe0
        subwf   fvco_3,f
        movlw   0x72
        btfss   STATUS,C
        movlw   0x73
        subwf   fvco_2,f
        movlw   0x36
        btfss   STATUS,C
        movlw   0x37
        subwf   fvco_1,f
        movlw   0x3
        btfss   STATUS,C
        movlw   0x4
        subwf   fvco_0,f
        bsf     Flags,FLAG_V1   ;v1 = 1: 450 -> 460

rxcont
        call    calcN
        andlw   1
        btfsc   STATUS,Z        ;
        goto    badfreq

        ;clear rx bits from code plug bytes
        movlw   0xf0
        andwf   code_b,f
        andwf   code_c,f
        andwf   code_d,f
        andwf   code_e,f
        andwf   code_f,f

        ;set V0, V1
        btfsc   Flags,FLAG_V0
        bsf     code_b,2
        btfsc   Flags,FLAG_V1
        bsf     code_b,3

        btfss   Flags,FLAG_LOWBAND      ;
        goto    setrx1

        movlw   0x3             ;c0=1 (extender off), c1=1
        goto    setrx2          ;continue

setrx1  swapf   DivC,w          ;code_b bits

setrx2  iorwf   code_b,f
        swapf   BARGB0,w        ;code_c bits
        iorwf   code_c,f
        swapf   BARGB1,w        ;code_d bits
        iorwf   code_d,f
        swapf   BARGB2,w        ;code_e bits
        iorwf   code_e,f
        swapf   BARGB3,w        ;code_f bits
        iorwf   code_f,f
        iorlw   0x1             ;clear zero flag
        return

;toggle the mode output line to force the Syntor to re-read the code plug
        global  changemode
changemode
        btfss   PORTC,0         ;
        goto    setmodehigh     ;
        bcf     PORTC,0         ;
        return

setmodehigh
        bsf     PORTC,0         ;
        return

;Set Rx & Tx PL frequencies to the Comm Spec number in W
        global  SetPL           ;
SetPL   movwf   fvco_0          ;save number
        addwf   fvco_0,f        ;(N-1) * 2
        addwf   fvco_0,w        ;(N-1) * 3
        addlw   low pltable     ;
        bsf     STATUS,RP1      ;bank 2
        movwf   EEADR
        movlw   high pltable
        movwf   EEADRH
        incf    EEADR,f         ;point to Tx code
        call    settxpa         ;set Tx PL frequency
        goto    setrxpa         ;set Rx PL frequency

        global  SetRxCS
SetRxCS
        movlw   0xff            ;
        movwf   code_6
        movlw   0xDF
        movwf   code_7
        return

        global  SetTxCS
SetTxCS
        movlw   0xff            ;
        movwf   code_4
        movlw   0xDF
        movwf   code_5
        return

;Set PL encoder frequency
;
        global  settxpl
settxpl call    findpl
        btfsc   STATUS,Z        ;
        return                  ;
        call    settxpa         ;
        call    changemode      ;
        movlw   1               ;
        return

settxpa bsf     STATUS,RP0      ;bank 3
        bsf     STATUS,RP1      ;
        BSF     EECON1,EEPGD    ;Point to Program memory
        bsf     EECON1,RD
        nop
        nop
        bcf     STATUS,RP0      ;bank 2
        movf    EEDATH,w        ;
        iorlw   0x80            ;set "No MPL Operator select" bit
        bcf     STATUS,RP1      ;bank 0
        movwf   code_5          ;
        bsf     STATUS,RP1      ;bank 2
        movf    EEDATA,w        ;
        bcf     STATUS,RP1      ;bank 0
        movwf   code_4          ;
        return                  ;

        global  setrxpl
setrxpl call    findpl
        btfsc   STATUS,Z        ;
        return                  ;
        call    setrxpa         ;
        call    changemode      ;
        movlw   1               ;
        return

setrxpa bsf     STATUS,RP1      ;bank 2
        incf    EEADR,f         ;
        bsf     STATUS,RP0      ;bank 3
        BSF     EECON1,EEPGD    ;Point to Program memory
        bsf     EECON1,RD
        nop
        nop
        bcf     STATUS,RP0      ;bank 2
        movf    EEDATH,w        ;
        iorlw   0x80            ;set "No MPL Operator select" bit
        bcf     STATUS,RP1      ;bank 0
        movwf   code_7          ;
        bsf     STATUS,RP1      ;bank 2
        movf    EEDATA,w        ;
        bcf     STATUS,RP1      ;bank 0
        movwf   code_6          ;
        return                  ;


;find specified PL tone in table.
;Returns with zero flag set on match
findpl  bsf     STATUS,RP1      ;bank 2
        movlw   high pltable
        movwf   EEADRH
        movlw   low pltable
        movwf   EEADR
txplloop
        banksel EECON1          ;bank 3
        BSF     EECON1,EEPGD    ;Point to Program memory
        bsf     EECON1,RD
        nop
        nop
        bcf     STATUS,RP0      ;bank 2
        movf    EEDATH,w        ;
        bcf     STATUS,RP1      ;bank 0
        btfsc   STATUS,Z        ;
        ;Error, end of table before finding specified PL
        return                  ;w = 0 & Z flag set

        bsf     STATUS,RP1      ;bank 2
        incf    EEADR,f         ;point to next entry
        incf    EEADR,f         ;
        incf    EEADR,f         ;
        bcf     STATUS,RP1      ;bank 0
        subwf   fvco_2,w        ;MSB match ?
        btfss   STATUS,Z        ;
        goto    txplloop

        bsf     STATUS,RP1      ;bank 2
        movf    EEDATA,w        ;

        bcf     STATUS,RP1      ;bank 0
        subwf   fvco_3,w        ;LSB match ?
        btfss   STATUS,Z        ;
        goto    txplloop

        ;found a match
        bsf     STATUS,RP1      ;bank 2
        decf    EEADR,f         ;return point to tx value
        decf    EEADR,f         ;
        bcf     STATUS,RP1      ;bank 0
        iorlw   1               ;clear zero flag
        return                  ;

setmodeadr
        movf    memchan,w       ;
        btfss   STATUS,Z        ;
        goto    setmodeadr1     ;
;setup to read/write mode 1 from/into EEPROM
        BSF     STATUS,RP1      ;Bank 2
        movlw   MODE1_ADR       ;
        MOVWF   EEADR           ;
        clrf    EEADRH          ;
        BSF     STATUS,RP0      ;Bank 3
        BCF     EECON1,EEPGD    ;Point to EEPROM memory
        goto    setmodeadr2     ;continue
        
setmodeadr1
        bcf     STATUS,C        ;memchan * 16
        rlf     memchan,f
        rlf     memchan,f
        rlf     memchan,f
        rlf     memchan,f

        BSF     STATUS,RP1      ;Bank 2

        movlw   high mode_1     ;Flash address MSB
        btfsc   STATUS,C        ;
        movlw   high mode_17    ;
        MOVWF   EEADRH          ;

        BCF     STATUS,RP1      ;Bank 0
        MOVF    memchan,w       ;Flash address LSB
        BSF     STATUS,RP1      ;Bank 2
        MOVWF   EEADR           ;
        BSF     STATUS,RP0      ;Bank 3
        BSF     EECON1,EEPGD    ;Point to Program memory

setmodeadr2
        BCF     STATUS,RP0      ;Bank 2
        movlw   low code_0      ;
        movwf   FSR             ;
        return
        
        ;write 32 bit int from BARGB3 .. BARGB0 into EEPROM
        ;w = EEPROM address
write32ee
        BSF     STATUS,RP1      ;Bank 2
        movwf   EEADR           ;
        clrf    EEADRH          ;
        BSF     STATUS,RP0      ;Bank 3
        BCF     EECON1,EEPGD    ;Point to EEPROM memory
        BCF     STATUS,RP1      ;Bank 2
        BCF     STATUS,RP0      ;Bank 0
        movlw   4               ;number of bytes to read
        movwf   LoopCnt         ;
        movlw   low BARGB3      ;point to LSB
        movwf   FSR             ;
        goto    prg_loop        ;

;
;Program code_0 -> code_f into specified mode in flash
;
        global  prgmode
prgmode movlw   d'16'           ;16 bytes to program
        movwf   LoopCnt         ;
        call    setmodeadr
        movlw   0x34            ;ms 6 bits of retlw instruction
        MOVWF   EEDATH          ;
        BCF     STATUS,RP1      ;Bank 0
        call    prg_loop        ;
        goto    changemode      ;force Syntor to reload current channel & return

;program LoopCnt bytes of ram from bank 0 into flash or EEPROM starting
;at the EEADR previously set
        global  prg_loop
prg_loop
        movf    INDF,w          ;
        incf    FSR,f           ;
        BSF     STATUS,RP1      ;Bank 2
        MOVWF   EEDATA          ;program at
        BSF     STATUS,RP0      ;Bank 3
        BSF     EECON1,WREN     ;Enable writes
        BCF     INTCON,GIE      ;Disable interrupts
        MOVLW   0x55            ;Write 55h to
        MOVWF   EECON2          ;EECON2
        MOVLW   0xAA            ;Write AAh to
        MOVWF   EECON2          ;EECON2
        BSF     EECON1,WR       ;Start write operation
        NOP                     ;Two NOPs to allow micro
        NOP                     ;to setup for write
        BSF     INTCON,GIE      ;re-enable interrupts
        BCF     EECON1,WREN     ;Disable writes
        
        btfsc   EECON1,WR       ;
        goto    $-1             ;wait for write to complete
        
        BCF     STATUS,RP0      ;Bank 2
        incf    EEADR,f         ;
        BCF     STATUS,RP1      ;Bank 0
        decfsz  LoopCnt,f
        goto    prg_loop        ;
        return                  ;

        ;read 32 bit int from EEPROM into BARGB3 .. BARGB0
        ;w = EEPROM address
read32ee
        BSF     STATUS,RP1      ;Bank 2
        movwf   EEADR           ;
        clrf    EEADRH          ;
        BCF     STATUS,RP1      ;Bank 0
        movlw   4               ;number of bytes to read
        movwf   LoopCnt         ;
        movlw   low BARGB3      ;point to LSB

        ;read LoopCnt bytes from previously set EEPROM address into bank 0
        ;memory pointed to by w
        global  readee
readee  movwf   FSR             ;
        BSF     STATUS,RP1      ;Bank 2
        BSF     STATUS,RP0      ;Bank 3
        BCF     EECON1,EEPGD    ;Point to eeprom memory
        goto    recall_loop     ;
        
        global  recallmode
recallmode
        movlw   d'16'           ;16 bytes to program
        movwf   LoopCnt         ;
        call    setmodeadr
        call    recall_loop     ;
        BCF     STATUS,RP1      ;return with bank 0 selected
        goto    changemode      ;force Syntor to reload current channel & return
        
;Read LoopCnt bytes of flash or EEPROM into bank 0 RAM starting
;at the EEADR previously set
recall_loop
        BSF     STATUS,RP1      ;Bank 3
        BSF     STATUS,RP0      ;
        bsf     EECON1,RD
        nop
        nop
        bcf     STATUS,RP0      ;bank 2
        movf    EEDATA,w        ;get the data from flash
        incf    EEADR,f         ;

        BCF     STATUS,RP1      ;Bank 0
        movwf   INDF            ;
        incf    FSR,f           ;
        decfsz  LoopCnt,f
        goto    recall_loop     ;
        return

        end

