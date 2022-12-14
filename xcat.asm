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
; Revision 1.14  2010/02/23 16:47:43  Skip
; Removed code to disable scanning on power up.
; Hopefully this is no longer needed.
; Note to self:  Make sure scanning is disabled when we ship new Xcats!
;
; Revision 1.13  2008/07/03 23:43:24  Skip
; 1. Hard code address of mode_17 which is no longer defines by source.
; 2. Trivial optimization ... removed redundant code at beginning of SyncClkInit.
; 3. Added code to the mainloop to copy PTT_IN to PTT_OUT when I/O 7 is
;    defined as an input and *not* in Palomar mode. (Make testing easier since
;    a radio wired for a Palomar can still transmit w/o the Palomar by disabling
;    Palomar mode.)
;
; Revision 1.12  2008/05/25 05:44:04  Skip
; Added code to SyncClkInit to unkey transmitter on initialization in Palomar
; mode.
;
; Revision 1.11  2008/05/25 05:35:22  Skip
; Merged some of the Palomar/Cactus code changes from Vers 0.23a. The
; exotic changes to the ISR were tossed.  They weren't effective anyway.
;
; Revision 1.10  2008/05/13 14:55:44  Skip
; 1. Removed __config directive, this should only be in the loader.
; 2. Moved debug data to end of page2, added srxlen (Palomar code
;     debug var), wd_count, bo_count and unk_count to debug variables.
; 3. Added code to increment wd_count, bo_count, and unk_count for
;    watchdog timeouts, brownout resets and unknown resets.  NB: requires
;    updated loader that copies STATUS register immediately after reset to
;    0x7f.
; 4. Modified power on RAM clear function to avoid clearing reset counters.
;
; Revision 1.9  2008/05/11 13:34:49  Skip
; Added (untested) support for digital volume pot.
;
; Revision 1.8  2007/07/18 18:48:34  Skip
; 1. Added digital squelch port support.
; 2. Added support for 7 byte Doug Hall/Generic protocol.
; 3. Massive modifications to code plug data ISR and selmode logic.  See
;    the detailed and anal comments about "take 3" above changemode
;    for the gory details.  Changes were necessary to be enable scanning to
;    be turned off reliably.
; 4. Moved test code to tests.asm.
;
; Revision 1.7  2007/07/06 13:55:10  Skip
; 1. Modified main loop to wait for Tx to be idle before testing
;    B1_FLAG_RESET for potential reset.
; 2. Added clrwdt to mainloop (not tested since it requires a bootloader
;    and fuse change).
;
; Revision 1.6  2007/02/03 15:13:44  Skip
; Added test of B1_FLAG_RESET to main loop.
;
; Revision 1.5  2005/01/05 05:10:02  Skip Hansen
; 1. Added debug counter, srxbad, to count invalid sync frames received.
; 2. Clear *all* RAM at power up.
; 3. Corrected initialization of Port D ... bits 1, 2 and 5 are always outputs.
; 4. Cleaned up Sync data processing.  Call cnv_ctrlsys rather each routine.
;    Call setrxcnt to set bit count for next pass.
; 5. Added code to set B1_FLAG_NEW_DATA when the last 3 bytes
;    of sync data have changed since the last frame (used by Palomar code)
;
; Revision 1.4  2004/12/31 04:33:02  Skip Hansen
; Corrected TEST_GENERIC test code.
;
; Revision 1.3  2004/12/31 00:44:00  Skip Hansen
; 1. Added sync data debug variables srx*_d and srxgood, stxgood.
; 2. Modified sync data ISR to disable reception after srxcnt bit have been
;    received.
; 3. Removed patch kludges, all changes are now in line, life is too short!
;
; Revision 1.2  2004/07/24 20:11:58  Skip Hansen
; Version 0.10 changes:
; 1. Moved ISR back to bank 4 !! Bank 4's "table" jumps to vfo0 ... which
;    requires the ISR to be in the same bank as the mode tables.
; 2. Modified initialization code to clear scanning bits from mode 1 loaded from
;    EEPROM to prevent scanning of junk modes.
; 3. Modified modechange routine to enable tistate on port C when changing
;    modes for compatibility with 1 of 8 "clam shell" heads.
; 4. Modified SaveMode to turn put port C back into a tristate mode after the
;    Syntor changes modes.
; 5. Modified setmodeadr to prevent it from clobbering the currently selected
;    memory channel.
;
; Revision 1.1.1.1  2004/07/03 16:38:59  Skip Hansen
; Initial import: V0.09.  Burned into first 10 boards.
;
;
        processor       16F877a
        include <p16f877a.inc>
        include defines.inc

        extern  AARGB0, AARGB1,AARGB2,AARGB3
        extern  BARGB0, BARGB1, BARGB2, BARGB3
        extern  REMB0, REMB1, REMB2, REMB3
        extern  FXD3232U,serialinit,rxdata,txdata
        extern  mode_1,memchan
        extern  sendmode,CanSend
        extern  cnv_generic,cnvcactus
        extern  pltable,limits10m,limits6m,limits2m,limits440
        extern  icomflags,cnv_ctrlsys,setsrxcnt,b1flags,txstate
        extern  copy0,tests,sendsdbg,updateptt

        global  settxf,setrxf
        global  rxf_0,rxf_1,rxf_2,rxf_3
        global  txf_0,txf_1,txf_2,txf_3
        global  fvco_0,fvco_1,fvco_2,fvco_3
        global  DivA,N1_0,N1_1,N1_2,N1_3

;variables present in all banks
COMMON  udata
W_TEMP  res     1
        global  nbtemp
nbtemp  res     1
        global  nbloop
nbloop  res     1
        global  nbfrom
nbfrom  res     1
        global  nbto
nbto    res     1

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
;NB keep fvco_* and N1_* together, they are used as a 8 byte buffer for
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

        global  code_0,code_4,code_5,code_8,code_9,code_a
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
        global  Squelch
Squelch res     1       ;squelch pot level
        global  Volume
Volume  res     1       ;volume pot level

; -------------------------------------------------------------------------

selmode res     1       ;mode data last read which is not necessarily the 
                        ;selected mode when scanning.

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
#define FLAG_FORCE_M1   7       ;Bit 7 = 1 - return mode 1 data for all modes
#define FLAG_CLR_FREQ   0x83    ;clear frequency calculation related bits

        global  mode
mode    res     1
#define MODE_TRIES      d'64'   ;try forcing a mode change mode 4 times
Mtries  res     1

DATA1   udata
;serial clock & data from control system - Bank 1 RAM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;NB do not change the order of the following
        global  srx1,srx2,srx3,srx4,srx5,srx6,srx7
srx7    res     1               ;last byte clocked in (all modes)
srx6    res     1               ;
srx5    res     1               ;first byte clocked in (Palomar mode)
srx4    res     1               ;
srx3    res     1               ;first byte clocked in (Doug Hall mode, 5 bytes)
srx2    res     1               ;
srx1    res     1               ;first byte clocked in (Doug Hall mode, 7 bytes)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        global  srxbits
srxbits res     1               ;number of bits clocked in from BCD port
        global  srxto
srxto   res     1
        
        global  srxcnt
        
;Number of sync bits left to shift in before stopping.
;Used in Palomar/Cactus mode to select the correct remote base from the 
;serial stream
srxcnt  res     1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;copy of the last valid data processed in Palomar mode

srx5_l  res     1               ;last byte clocked in
srx4_l  res     1               ;
srx3_l  res     1               ;first byte clocked in

DEBUG   udata
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;NB do not change the order of the following
;Copy of above variables at last sync data timeout for debug
        global  srx7_d
srx7_d  res     1               ;last byte clocked in (all modes)
srx6_d  res     1               ;
srx5_d  res     1               ;first byte clocked in (Palomar mode)
srx4_d  res     1               ;
srx3_d  res     1               ;first byte clocked in (Doug Hall mode, 5 bytes)
srx2_d  res     1               ;
srx1_d  res     1               ;first byte clocked in (Doug Hall mode, 7 bytes)

         global srxbits_d
srxbits_d res   1               ;number of bits clocked in from sync port
        global  srxto_d
srxto_d res     1               ;number of sync data timeouts

        global  srxcnt_d
srxcnt_d res    1               ;number of bits to clock in from sync port
                                ;before stopping
                                
        global  srxgood         ;
srxgood res     1               ;number of frames that set a RX frequency
        global  stxgood         ;
stxgood res     1               ;number of frames that set a TX frequency
        global  srxbad          ;
srxbad  res     1               ;number of invalid frames

;In Palomar mode we can't wait for a timeout because a serial frame
;is sent whenever a transmission is made that that could be immediately
;after one of the periodic updates.  So... in Palomar mode we save the 
;number of bits in a serial frame here so we know when to process the data.
;
        global  srxlen
srxlen  res     1
wd_count res    1               ;
bo_count res    1               ;
unk_count res   1               ;
;

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

PROG4   code
;NB the ISR code *must* be in the same page as the code tables !

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
        btfss   Flags,FLAG_FORCE_M1
        goto    isr3

    ;return mode 1 data no matter what mode the Syntor asks for

        movlw   0x22
        movwf   selmode
dloop   decfsz  selmode,f
        goto    dloop

        movlw   high mode_1
        movwf   PCLATH          ;
        nop                     ;

        movf    PORTC,w         ;w = PORTC with stable address (this should occur 129 cycles after /oe)
        movwf   LastC
        
        movf    PORTA,w         ;
        movwf   LastA           ;
        andlw   0xf             ;
        call    GetCodeData     ;

sloop   movf    PORTA,w         ;
        andlw   0xf             ;
        call    GetCodeData     ;
        btfss   PORTC,2         ;wait for /OE to go inactive
        goto    sloop           ;
        
        movf    PORTA,w         ;w = A0->A5
        movwf   selmode         ;save
        
        bsf     STATUS,RP0      ;bank 1
        movlw   0xff            ;
        movwf   TRISB           ;turn off Port B output drivers
        bcf     STATUS,RP0      ;bank 0

        movlw   0x38            ;Test A6, A7, A8 == 0
        andwf   LastC,w         ;
        btfss   STATUS,Z        ;
        goto    isr1            ;Data read not for mode 1, continue

    ;If the address lower nibble of the address is 0x7 then we're not done
    
        movlw   0xf             ;
        andwf   selmode,w       ;
        sublw   0x7             ;
        btfsc   STATUS,Z        ;
        goto    isr1            ;Data read is not full mode info, continue
        
    ;If this was a read of mode 1 then we're done
    
        movlw   0x30            ;Test A5, A4 == 0
        andwf   LastA,w         ;
        btfss   STATUS,Z        ;
        goto    isr1            ;Not mode 1
        bcf     Flags,FLAG_FORCE_M1     ;Whew!
    ;turn off the output driver for the mode 6 output
        bsf     STATUS,RP0      ;bank 1
        bsf     TRISC,0         ;disable output
        bcf     STATUS,RP0      ;bank 0
        goto    isr1            ;continue

;unfortunately this is a critical timing delay loop...
;The LSB of the address is valid 25.6 microseconds (128 cycles) after
;the following edge of /OE

isr3    movlw   0x20
        movwf   selmode
delayloop
        decfsz  selmode,f
        goto    delayloop
        movf    PORTC,w
        movwf   LastC

        movlw   high mode_1
        btfsc   PORTC,5         ;
;        movlw   high mode_17
        movlw   0x1f            ;
        movwf   PCLATH          ;
        nop                     ;
        nop                     ;
        movf    PORTA,w         ;w = A0->A5 (this should occur 129 cycles after /oe)
        btfsc   PORTC,3         ;
        iorlw   0x40            ;
        btfsc   PORTC,4         ;
        iorlw   0x80            ;
        movwf   LastA
        call    GetCodeData     ;
        movwf   PORTB           ;

synloop movf    PORTA,w         ;w = A0->A5
        btfsc   PORTC,3         ;
        iorlw   0x40            ;
        btfsc   PORTC,4         ;
        iorlw   0x80            ;
        call    GetCodeData     ;
        movwf   PORTB           ;

        btfss   PORTC,2         ;wait for /OE to go inactive
        goto    synloop         ;

        bsf     STATUS,RP0      ;bank 1
        movlw   0xff            ;
        movwf   TRISB           ;turn off Port B output drivers
        bcf     STATUS,RP0      ;bank 0

isr1    btfss   PIR2,CCP2IF     ;serial clock interrupt ?
        goto    returni         ;nope, exit interrupt handler

        ;clock in a new data bit
        bcf     STATUS,C        ;assume serial data is low
        btfsc   SERAL_DAT       ;jump if so
        bsf     STATUS,C        ;
        bsf     STATUS,RP0      ;bank 1
        movf    srxcnt,f        ;any bits left to receive?
        btfsc   STATUS,Z        ;
        goto    isr2            ;nope
        rrf     srx7,f          ;
        rrf     srx6,f          ;
        rrf     srx5,f          ;
        rrf     srx4,f          ;
        rrf     srx3,f          ;
        rrf     srx2,f          ;
        rrf     srx1,f          ;
        decf    srxcnt,f        ;bump count of bits received
isr2        
        incf    srxbits,f       ;increment bit count
        clrf    srxto           ;clear timeout counter
        bcf     STATUS,RP0      ;bank 0
        bcf     PIR2,CCP2IF     ;

returni bcf     PIR1,CCP1IF     ;

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
PROG2   code

startup1
        BCF     STATUS,RP1      ;Bank 1
        BSF     STATUS,RP0      ;Bank 1
        btfsc   PCON,NOT_POR    ;
        goto    start1          ;not a power on reset
        ;power on reset
        clrf    wd_count        ;
        clrf    bo_count        ;
        clrf    unk_count       ;
        goto    start3          ;
        
start1  btfsc   PCON,NOT_BOR    ;
        goto    start2          ;not a brownout reset
        ;brownout reset
        incf    bo_count,w      ;
        btfss   STATUS,Z        ;don't roll over counter
        incf    bo_count,f      ;
        goto    start3          ;
        
        ;NB: we don't test STATUS,NOT_TO because the loader resets the 
        ;watchdog.  The loader stores the STATUS register at 0x7f before
        ;it resets the watchdog the first time so we can test it here.
start2
;       btfsc   STATUS,NOT_TO   ;
        btfsc   0x7f,NOT_TO     ;
        goto    start4          ;Say what ?
        ;Watchdog timeout 
        incf    wd_count,w      ;
        btfss   STATUS,Z        ;don't roll over counter
        incf    wd_count,f      ;
        goto    start3          ;

start4  incf    unk_count,w     ;
        btfss   STATUS,Z        ;don't roll over counter
        incf    unk_count,f     ;

start3  bsf     PCON,NOT_BOR    ;Reset BOR, POR bits for next time
        bsf     PCON,NOT_POR    ;

;Clear all of RAM
        clrf    STATUS          ;bank 0
        movlw   0x20            ;start of RAM
        movwf   FSR             ;
clrloop clrf    INDF            ;
        incf    FSR,f           ;
        movlw   0x80            ;end of RAM in Bank 0
        subwf   FSR,w           ;
        btfss   STATUS,Z        ;
        goto    clrloop         ;

        ;clear bank 1        
        movlw   0xa0            ;start of RAM
        movwf   FSR             ;
clr1    clrf    INDF            ;
        incf    FSR,f           ;
        movlw   low wd_count    ;end of RAM to clear in Bank 1
        subwf   FSR,w           ;
        btfss   STATUS,Z        ;
        goto    clr1            ;
        
        bsf     STATUS,IRP      ;
        ;clear bank 2        
        movlw   0x10            ;start of RAM
        movwf   FSR             ;
clr2    clrf    INDF            ;
        incf    FSR,f           ;
        movlw   0x70            ;end of RAM in Bank 0
        subwf   FSR,w           ;
        btfss   STATUS,Z        ;
        goto    clr2            ;
        
        movlw   0x90            ;start of RAM in bank 3
        movwf   FSR             ;
clr3    clrf    INDF            ;
        incf    FSR,f           ;
        movlw   0xf0            ;end of RAM in Bank 3
        subwf   FSR,w           ;
        btfss   STATUS,Z        ;
        goto    clr3            ;
        clrf    STATUS          ;bank 0
        
;Init port A
        banksel PORTC           ;
        bsf     PORTC,0         ;mode select output high
        bsf     STATUS,RP0      ;bank 1
        movlw   0x6             ;Port A all digital inputs
        movwf   ADCON1
        movlw   0xff            ;
        movwf   TRISA           ;

;Init port C
        movlw   0xBF            ;C6 is an output (C0 configured dynamically)
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
        
;Init port D
        movf    ConfUF,w        ;1 = user output bit, 0 = alternate function
        iorlw   0x7e            ;bits 1 -> 6 are always outputs
        xorlw   0xff            ;invert for tristate control
        bsf     STATUS,RP0      ;bank 1
        movwf   TRISD           ;
        bcf     STATUS,RP0      ;bank 0
        
        call    serialinit      ;initialize serial port
        
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

        ;temp routine to clear scanning bits from vfo data in EEPROM
        ;to workaround version 0.09 bug that left scanning enabled
        clrf    memchan         ;load mode 1 from EEPROM
        movlw   high recallmode ;
        movwf   PCLATH
        call    recallmode      ;
        
        ;Disable scan for now
        ifdef   CLR_SCAN_ON_POWER_UP
        movlw   0x80            ;
        movwf   code_9          ;
        movwf   code_a          ;
        endif      
        
        ifdef   SIMULATE
        movlw   high tests      
        movwf   PCLATH          ;
        call    tests           ;        
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
        sublw   1               ;Doug Hall mode ?
        btfss   STATUS,Z        ;skip if so
        bsf     PORTD,CONFIG_PTT_OUT    ;unkey Tx for Palomar mode

        movlw   4               ;capture mode, every falling edge
        movwf   CCP2CON         ;

        bsf     STATUS,RP0      ;bank 1
        bsf     PIE2,CCP2IE     ;
        bcf     STATUS,RP0      ;bank 0
        return                  ;

;
;
PROG1   code
startup FCALL   startup1        ;

mainloop
        clrwdt                  ;kick the dog
        btfss   RCSTA,OERR      ;Overrun error ?
        goto    main4           ;
        ;Clear it !
        movf    RCREG,w         ;clear the fifo
        movf    RCREG,w         ;
        bcf     RCSTA,CREN      ;reset the the receiver
        bsf     RCSTA,CREN      ;
        
main4   btfsc   PIR1,RCIF       ;
        goto    main5           ;Rx ready
        bsf     STATUS,RP0      ;bank 1
        btfss   TXSTA,TRMT
        goto    main2           ;Tx not ready

        FCALL   txdata          ;
        btfss   TXSTA,TRMT      ;
        goto    main2           ;The UART hasn't finished sending yet
        
        btfss   b1flags,B1_FLAG_RESET   ;
        goto    main2           ;
        ;reset !        
        movlw   0               ;
        movwf   PCLATH          ;
        goto    0               ;

;Rx is ready
main5   movlw   high rxdata     ;
        movwf   PCLATH          ;
        call    rxdata          ;
        
main2   bcf     STATUS,RP0      ;bank 0
        movlw   high SaveMode   ;
        movwf   PCLATH          ;
        call    SaveMode        ;
        btfsc   Config0,CONFIG_COS_MSG  ;
        call    CheckSignal     ;
        
        bsf     STATUS,RP0      ;bank 1
        movf    srxlen,w        ;serial frame length set ? (Palomar mode only)        
        btfsc   STATUS,Z        ;
        goto    main8           ;nope
        subwf   srxbits,w       ;received all of the bits ?
        btfsc   STATUS,Z        ;
        goto    procsrx         ;yup, go process the bits
        
main8   bcf     STATUS,RP0      ;bank 0
        btfss   PIR1,TMR1IF     ;has the timer ticked ?
        goto    main1           ;

        ;the timer has ticked
        bcf     PIR1,TMR1IF     ;

    ;Kludge: toggle the mode 6 line once every 200 milliseconds 
    ;until the Syntor reads mode 1 !
    
        btfss   Flags,FLAG_FORCE_M1
        goto    main6           ;
        decfsz  Mtries,f        ;
        goto    main7           ;

    ;Hmmm... maybe the control head isn't on mode 1... give up
        bcf     Flags,FLAG_FORCE_M1
        
        ifdef   DEBUG_MODE_SEL        
        bsf     STATUS,RP0      ;bank 1
        incf    stxgood,w       ;
        btfss   STATUS,Z        ;don't roll over counter
        incf    stxgood,f       ;
        bcf     STATUS,RP0      ;bank 0
        endif
        
        goto    main6           ;

main7   movlw   0xf             ;16 ticks since the last change ?
        andwf   Mtries,w        ;
        btfsc   STATUS,Z        ;
        call    changem         ;
        
        ;check for serial receive data timeout
main6   bsf     STATUS,RP0      ;bank 1
        movf    srxbits,w       ;
        btfsc   STATUS,Z        ;
        goto    main1           ;no bits received

        ;nope, increment timeout timer
        incf    srxto,f         ;
        movlw   4               ;> 50 milliseconds ?
        subwf   srxto,w         ;
        btfss   STATUS,Z        ;timeout ?
        goto    main1           ;nope
        
        ;serial clock timeout or number of expected bits received
        ;process the data clocked in
procsrx bcf     PIE2,CCP2IE     ;disable further clock interrupt while
                                ;processing the data
        incf    srxto_d,w       ;
        btfss   STATUS,Z        ;don't roll over counter
        incf    srxto_d,f       ;
        
        ;check to see if any of the first 3 bytes have changed
        bcf     b1flags,B1_FLAG_NEW_DATA        ;
        movf    srx5,w          ;has srx3 changed ?
        subwf   srx5_d,w        ;
        btfss   STATUS,Z        ;
        goto    newdata         ;
        movf    srx6,w          ;has srx4 changed ?
        subwf   srx6_d,w        ;
        btfss   STATUS,Z        ;
        goto    newdata         ;
        movf    srx7,w          ;has srx5 changed ?
        subwf   srx7_d,w        ;
        btfss   STATUS,Z        ;
newdata bsf     b1flags,B1_FLAG_NEW_DATA        ;

        ;save number of bits received for control system code
        movf    srxbits,w       ;
        bcf     STATUS,RP0      ;bank 0
        movwf   Srxbits         ;
        
        ;copy srx1...srx7, srxbits into srx1_d ... srx7_d,srxbits_d for debug

        movlw   8               ;
        movwf   nbloop          ;        
        movlw   low srx7        ;
        movwf   nbfrom          ;
        movlw   low srx7_d      ;
        movwf   nbto            ;
        call    copy0           ;

        bsf     STATUS,RP0      ;bank 1
        bsf     PIE2,CCP2IE     ;re-enable clock interrupts
        bcf     STATUS,RP0      ;bank 0

        bcf     icomflags,COM_FLAG_RX_SET ;clear RX frequency set flag
        bcf     icomflags,COM_FLAG_TX_SET ;clear TX frequency set flag
        bcf     icomflags,COM_FLAG_BAD_DATA
        call    cnv_ctrlsys     ;
        movlw   high setsrxcnt  ;
        movwf   PCLATH          ;
        call    setsrxcnt       ;reset bit count for next time

        bsf     STATUS,RP0      ;bank 1
        clrf    srxbits         ;reset for next time
        clrf    srxto           ;
        bcf     STATUS,RP0      ;bank 0
        btfss   icomflags,COM_FLAG_TX_SET
        goto    txnotset        ;
        bsf     STATUS,RP0      ;bank 1
        
        incf    stxgood,w       ;
        btfss   STATUS,Z        ;don't roll over counter
        incf    stxgood,f       ;
        bcf     STATUS,RP0      ;bank 0
        
txnotset        
        btfss   icomflags,COM_FLAG_RX_SET
        goto    rxnotset        ;
        bsf     STATUS,RP0      ;bank 1
        
        incf    srxgood,w       ;
        btfss   STATUS,Z        ;don't roll over counter
        incf    srxgood,f       ;

rxnotset
        btfss   icomflags,COM_FLAG_BAD_DATA
        goto    save3           ;
        bsf     STATUS,RP0      ;bank 1
        
        incf    srxbad,w        ;
        btfss   STATUS,Z        ;don't roll over counter
        incf    srxbad,f        ;
        goto    sendstats       ;
       
        ;data was valid, save the first 3 bytes
        ;NB: use the "debug" versions because the orginal data may have
        ;changed by now.
save3   bsf     STATUS,RP0      ;bank 1
        movf    srx5_d,w        ;
        movwf   srx5_l          ;
        movf    srx4_d,w        ;
        movwf   srx4_l          ;
        movf    srx3_d,w        ;
        movwf   srx3_l          ;

        ;DEBUG --
sendstats
        call    CanSend         ;
        btfsc   STATUS,Z        ;
        call    sendsdbg        
        ;DEBUG --
        
main1   bcf     STATUS,RP0      ;bank 0
        btfsc   ConfUF,CONFIG_PTT_IN    ;I/O 7 PTT in ?
        goto    main3           ;no
        
        swapf   Config0,w       ;
        andlw   CONFIG_CTRL_MASK;
        sublw   1               ;Palomar mode ?
        btfss   STATUS,C        ;
        ;Palomar mode, don't update PTT until we get a frequency update
        goto    main3
        FCALL   updateptt
main3   goto    mainloop

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

;Take 1: I orginally drove the mode 6 select line by toggling it every time 
;the VFO frequency changed to toggle between the two banks of 32 modes. 
;I later discovered that approach didn't work with the 8 channel clam shell 
;style heads that have a 8 pole switch rather than a BCD switch, since that 
;caused the Syntor to alternately read mode 6 and whatever mode
;was actually selected.
;
;Take 2: Read the state of the mode 6 line, turn on the tristate driver and 
;then drive it in the opposite direction.  Once the Syntor read the code plug, 
;the tristate driver was turned off allowing the restoring the previous mode.  
;This caused problems setting the mode when scanning was enabled since *ANY* 
;code plug read by the syntor returned the mode 6 line to its previous state.  
;If the next read happened to be because of scanning rather than because the 
;Syntor firmware had noticed that the mode had changed then the new mode 1 
;info wasn't refreshed.
;
;Take 3:
;Set a force refresh flag and then drive the mode 6 select line to the 
;opposite sense.  If we have a BCD control head this will cause mode 33 
;to be read which looks like mode 1 to us.  If we have single pole control 
;head this will cause the Syntor to read mode 6 information, but the ISR 
;returns mode 1 information no matter what when the force refresh flag is set.
;When the ISR has detected that a full read of mode 1 data has occurred
;(not a truncated mode read for scanning data) it will clear the refresh
;flag and turn off the tristate driver.  This will cause the Syntor to
;reread the current mode data in the normal manner.
;
;NB: Yes this causes a glitch when mode 1 is not the selected mode and
;the VFO setting is changed, but that's life.
;
;We toggle the sense of the mode 6 line every 200 milliseconds until the
;Syntor reads mode 1...  why ?  A couple of reasons:
;
;1. Normally the Syntor reads the code plug right away, but for some reason 
;it's hard to get it's attention when scanning is enabled and it's stopped 
;on an active channel...
;
;2. The mode bus is bidirectional when used with some control groups.  This
;means that when we read the sense of the mode 6 line and then drive it in
;the "opposite" direction we may read the line while it's an output rather
;than an input causing us to drive it in the same direction... sigh.
;

;Force the Syntor to re-read the code plug

        global  changemode
changemode
        movlw   MODE_TRIES      ;
        movwf   Mtries          ;set retry counter
        bsf     Flags,FLAG_FORCE_M1     ;
        
changem 
        ifdef   DEBUG_MODE_SEL        
        bsf     STATUS,RP0      ;bank 1
        incf    srxgood,w       ;
        btfss   STATUS,Z        ;don't roll over counter
        incf    srxgood,f       ;
        bcf     STATUS,RP0      ;bank 0
        endif
        
        btfss   PORTC,0         ;
        goto    setmodehigh     ;
        bsf     STATUS,RP0      ;bank 1
        bcf     TRISC,0         ;enable output
        bcf     STATUS,RP0      ;bank 0
        bcf     PORTC,0         ;set the output low
        return

setmodehigh
        bsf     STATUS,RP0      ;bank 1
        bcf     TRISC,0         ;enable output
        bcf     STATUS,RP0      ;bank 0
        bsf     PORTC,0         ;set the output high
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
        movwf   LoopCnt         ;
        bcf     STATUS,C        ;memchan * 16
        rlf     LoopCnt,f
        rlf     LoopCnt,f
        rlf     LoopCnt,f
        rlf     LoopCnt,f

        BSF     STATUS,RP1      ;Bank 2

        movlw   high mode_1     ;Flash address MSB
        btfsc   STATUS,C        ;
;       movlw   high mode_17    ;
        movlw   0x1f            ;
        
        MOVWF   EEADRH          ;

        BCF     STATUS,RP1      ;Bank 0
        MOVF    LoopCnt,w       ;Flash address LSB
        BSF     STATUS,RP1      ;Bank 2
        MOVWF   EEADR           ;
        BSF     STATUS,RP0      ;Bank 3
        BSF     EECON1,EEPGD    ;Point to Program memory

setmodeadr2
        BCF     STATUS,RP0      ;Bank 2
        movlw   0x34            ;ms 6 bits of retlw instruction
        MOVWF   EEDATH          ;
        BCF     STATUS,RP1      ;Bank 0
        movlw   d'16'           ;16 bytes to program
        movwf   LoopCnt         ;
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
prgmode call    setmodeadr
        goto    prg_loop        ;

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
        
        nop
        nop
        global  recallmode
recallmode
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

