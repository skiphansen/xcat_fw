;$Log: icom.asm,v $
;Revision 1.4  2004/12/31 04:32:20  Skip Hansen
;Version 0.12 changes:
;1. Corrected enable sense for CONFIG_2_5_SEL, it should be active LOW.
;2. Corrected active sense for CONFIG_2_5_SEL, it should be active HIGH.
;3. Corrected value examined for CONFIG_2_5_SEL, it should be srx5.
;4. Call addw2temp1 to add 2.5 Khz, addw2temp1 masks W with a 0xf
;   so only 900 hz was added instead of 2500 Hz.
;5. Bumped versions number to 0.12.
;
;Revision 1.3  2004/12/31 00:39:11  Skip Hansen
;1. Removed all patch kludges!  Too hard to keep track of.  Code is now
;   just inline.
;2. Set a flag when a Rx and Tx frequency is set for debugging control
;   system communications.
;3. Added CI-V command 0xaa, 0x9 to retrieve debug data for sync comms.
;4. Bumped version number to 0.11.
;5. Modified Generic data routine to accept 5 or 7 bytes of data.
;6. Major modifications to Palomar support.  It might even work now!
;
;Revision 1.2  2004/07/24 20:05:50  Skip Hansen
;Version 0.10 changes:
;1. Modified CanSend to return false when already sending.
;2. Fixed bank bugs when disabling PL (freq 0.00).
;3. Added patch routine modechange1 - enable tistate on port port C when
;   for compatibility with 1 of 8 "clam shell" heads.
;4. Added patch routines setmode3, setmode4 to prevent moving
;   stuff around too much.
;
;Revision 1.1.1.1  2004/07/03 16:38:59  Skip Hansen
;Initial import: V0.09.  Burned into first 10 boards.
;
;        
        processor       16F877A
        include <p16f877A.inc>
        include defines.inc

#define         HEX_LOADER

DATA0           udata
                global  memchan
memchan         res     1       ; 1 -> 31

                global  icomflags
icomflags       res     1       ;bit0 = 0 bcd convert msb first (ctcss)
                                ;bit0 = 1 bcd convert lsb first (freq)
                                ;bit1 = 1 Generic data routine, tx offset mode
                                ;bit2 = 1 Rx frequency set successfully
                                ;bit3 = 1 Tx frequency set successfully

DATA1           udata

Duplex          res     1       ;0 = simplex, 1 = -offset, 2 = +offset
rxstate         res     1

rxbyte          res     1
OurCIVAdr       res     1       ;Our address on the CIV bus

start_fe        res     1
To_Adr          res     1
From_Adr        res     1
civ_cmd         res     1
Data_0          res     1
Data_1          res     1
Data_2          res     1
Data_3          res     1
Data_4          res     1
Data_5          res     1
Data_6          res     1
Data_7          res     1
Data_8          res     1
Data_9          res     1
Data_10         res     1
Data_11         res     1
Data_12         res     1
Data_13         res     1
Data_14         res     1
Data_15         res     1
Data_16         res     1
Data_17         res     1
DataP           res     1       ;rx data pointer (NB: must follow last Data_x)

;CI-V transmit variables - in Bank 1 RAM
txstate         res     1
NextTxState     res     1
txcount         res     1

txdatacount     res     1       ;amount of page data to sent
txdpointer      res     1       ;pointer to data

PROG2           code

;CI-V protocol:
;
; <0xfe> <0xfe> <to_adr> <from_adr> <cmd> <data> <0xfd>
; "Good" response
; <0xfe> <0xfe> <to_adr> <from_adr> <0xfb> <0xfd>
; "Bad" response
; <0xfe> <0xfe> <to_adr> <from_adr> <0xfa> <0xfd>
;
;
; A Xcat extension to allow us to send binary data is to "escape"
; 0xfd, 0xfe and 0xff data bytes by sending an 0xff followed by
; just the low nibble of the actual data byte.  i.e.
; 0xfd -> 0xff,0x0d
; 0xfe -> 0xff,0x0e
; 0xff -> 0xff,0x0f
;
        extern  DivA,fvco_0,fvco_1,fvco_2,fvco_3
        extern  N1_0,N1_1,N1_2,N1_3
        extern  rxf_0,rxf_1,rxf_2,rxf_3
        extern  txf_0,txf_1,txf_2,txf_3,nbtemp
        extern  settxf,setrxf,changemode,prgmode,recallmode,SetPL
        extern  SetTxCS,SetRxCS
        extern  AARGB0, AARGB1,AARGB2,AARGB3
        extern  BARGB0, BARGB1, BARGB2, BARGB3
        extern  REMB0, REMB1, REMB2, REMB3
        extern  settxpl,setrxpl
        extern  prg_loop
        extern  LoopCnt
        extern  TxOff_3,TxOff_2,TxOff_1,TxOff_0
        extern  readee

        extern  mode,Config0,ConfUF,code_0,code_8,code_9,code_a,srxcnt
        extern  srx5_d,srxto_d,srxgood,stxgood

#define LoopCntr        DivA
#define temp_0          fvco_0
#define temp_1          fvco_1
#define temp_2          fvco_2
#define temp_3          fvco_3

#define temp1_0         N1_0
#define temp1_1         N1_1
#define temp1_2         N1_2
#define temp1_3         N1_3

#define srx1            AARGB0
#define srx2            AARGB1
#define srx3            AARGB2
#define srx4            AARGB3
#define srx5            BARGB0
#define srxbits         BARGB1


;init uart for 19,200, 8 data bits, no parity
        global  serialinit
serialinit
        ifndef  HEX_LOADER
        BSF     STATUS,RP0      ;Bank 1
        movlw   d'64'           ;19200 divider, 20 Mhz clock, BRGH = 1
        movwf   SPBRG

        BCF     STATUS,RP0      ;Bank 0
        movlw   0x90            ;Serial port enable, continuous receive
        movwf   RCSTA           ;

        BSF     STATUS,RP0      ;Bank 1
        movlw   0x24            ;TX enable, high speed async mode
        movwf   TXSTA           ;
        BCF     STATUS,RP0      ;Bank 0
        endif

        BSF     STATUS,RP0      ;Bank 1
        clrf    Duplex          ;default to simplex
        clrf    rxstate         ;ready for receive
        clrf    txstate         ;Tx idle
        movlw   0x20            ;
        movwf   OurCIVAdr       ;
        BCF     STATUS,RP0      ;Bank 0
        return
;
;
        global  rxdata
rxdata
        movf    RCREG,w         ;read the data
        BSF     STATUS,RP0      ;Bank 1
        movwf   rxbyte          ;save it
        movf    txstate,f       
        btfss   STATUS,Z        ;
        return                  ;transmitting, ignore any received characters

        movlw   0xfe            ;start of frame character ?
        subwf   rxbyte,w        ;
        btfss   STATUS,Z        ;
        goto    rxdata1         ;nope
        ;got an start of frame character
        decfsz  rxstate,w       ;
        clrf    rxstate         ;goto state 0 unless in state 1
        
rxdata1
        movlw   high rxdata2    ;
        movwf   PCLATH          ;
        movf    rxstate,w
        
rxdata2 addwf   PCL,f
        goto    rxstate0        ;Wait for 1'st 0xFE
        goto    rxstate1        ;Wait for 2'nd 0xFE
        goto    rxstate2        ;Check To adr
        goto    rxstate3        ;Get data until 0xfd (or buffer overflow)
        goto    rxstate4        ;Escape next byte (0xff was last byte received)
        

;state 0: wait for first 0xfe
rxstate0
        movlw   0xfe
        subwf   rxbyte,w
        btfsc   STATUS,Z        ;
        incf    rxstate,f       ;goto state one, we got the first 0xfe
        return

;state 1: wait for second 0xfe
rxstate1
        incf    rxstate,f       ;assume we'll get the second 0xfe
        movlw   0xfe
        subwf   rxbyte,w
        btfss   STATUS,Z        ;
back2state0
        clrf    rxstate         ;nope, back to waiting for first 0xfe
        return

;State 2: To address
rxstate2
        movf    OurCIVAdr,w
        subwf   rxbyte,w
        btfss   STATUS,Z        ;
        goto    back2state0     ;
        movlw   low From_Adr    ;
        movwf   DataP
        incf    rxstate,f       ;it's for us
        return

;State 3: get data until 0xfd or input buffer overflow
rxstate3
        movf    rxbyte,w        ;
        sublw   0xfd            ;0xfd ?
        btfss   STATUS,Z        ;
        goto    rxstate3c
        ;end of command
        movlw   high execcmd
        movwf   PCLATH
        goto    execcmd         ;got an end

rxstate3c
        movf    rxbyte,w        ;
        sublw   0xff            ;0xff ?
        btfsc   STATUS,Z        ;
        goto    rxstate3b       ;this is an 0xff escape character

        ;just plain old data, save it
rxstate3a        
        movf    DataP,w         ;
        movwf   FSR             ;
        movf    rxbyte,w        ;
        movwf   INDF            ;
        incf    DataP,f         ;
        movlw   low DataP       ;
        subwf   DataP,w         ;
        btfsc   STATUS,Z        ;
        clrf    rxstate         ;RX buffer overflow, ignore the frame
        return

rxstate3b
        incf    rxstate,f       ;last character was an 0xff enter state 4
        return

;State 4: last character was a 0xff
rxstate4
        decf    rxstate,f       ;return to state 3
        movlw   0xf0            ;
        iorwf   rxbyte,f        ;
        goto    rxstate3a       ;continue

        global  txdata
;Bank 1 selected
txdata  movf    txstate,w
        addwf   PCL,f
        goto    txstate0        ;idle
        goto    txstate1        
        goto    txstate2
        goto    txstate3
        goto    txstate4
        goto    txstate5

;txstate 0: idle
txstate0
        return                  ;nothing to do

;txstate 1: Send data from DataP (Bank 1 RAM) until 0xfd or txcount expires
;NB: this state is not appropriate for binary data
txstate1
        movf    DataP,w         ;
        incf    DataP,f         ;
        movwf   FSR             ;
        movf    INDF,w          ;
        bcf     STATUS,RP0      ;bank 0
        movwf   TXREG           ;
        bsf     STATUS,RP0      ;bank 1
        sublw   0xfd            ;
        btfss   STATUS,Z        ;
        goto    txstate2c

txcomplete        
        bsf     STATUS,RP0      ;bank 1
        clrf    txstate         ;transmit state back to zero
        return
        

;txstate 2: Send binary data from DataP (Bank 0 RAM) for txcount then
;go to NextTxState
txstate2
        movf    DataP,w         ;
        movwf   FSR             ;
        movlw   0xfd            ;
        bcf     STATUS,RP0      ;bank 0
        subwf   INDF,w          ;
        btfsc   STATUS,C        ;
        goto    txstate2a       ;escape the data
        movf    INDF,w          ;
txstate2b
        movwf   TXREG           ;
        bsf     STATUS,RP0      ;bank 1
        incf    DataP,f         ;

txstate2c
        bsf     STATUS,RP0      ;bank 1
        decfsz  txcount,f
        return
        movf    NextTxState,w   ;
        movwf   txstate         ;
        return

txstate2a
        movlw   0xff            ;
        movwf   TXREG           ;
        bsf     STATUS,RP0      ;bank 1
        incf    txstate,f       ;
        return

;txstate 3: Send low nibble of last data byte and continue
txstate3
        decf    txstate,f       ;
        movf    DataP,w         ;
        bcf     STATUS,RP0      ;bank 0
        movwf   FSR             ;
        movf    INDF,w          ;
        andlw   0xf             ;
        goto    txstate2b       ;continue

;txstate 4: Send 0xfd and then return to txstate 0
txstate4
        bcf     STATUS,RP0      ;bank 0
        movlw   0xfd            ;
        movwf   TXREG           ;
        goto    txcomplete      ;

;txstate 5: Send txdatacount bytes of data from txdpointer (Page 0 data)
txstate5
        movf    txdpointer,w    ;get pointer to data
        movwf   DataP           ;
        movf    txdatacount,w   ;get data acount
        movwf   txcount         ;
        movlw   2               ;
        movwf   txstate         ;
        movlw   4               ;and then state 4
        movwf   NextTxState     ;
        goto    txstate2        ;
        
        ;END of PROG2 code new ADD new PROG2 code here

PROG1   code

;return with zero flag set if it's ok to send
        global  CanSend
CanSend BSF     STATUS,RP0      ;Bank 1
        movf    rxstate,w       ;
        iorwf   txstate,w       ;
        BCF     STATUS,RP0      ;Bank 0
        return

;signal report <cmd0xaa><sub code 0x81><mode><0/1>
        global  sendmode
        
sendmode
        BSF     STATUS,RP0      ;Bank 1
        movwf   Data_2          ;save signal/no signal flag
        BCF     STATUS,RP0      ;Bank 0
        movf    mode,w          ;
        BSF     STATUS,RP0      ;Bank 1
        movwf   Data_1          ;
        clrf    To_Adr          ;to adr (broadcast)
        movlw   0xaa            ;
        movwf   civ_cmd         ;cmd code
        movlw   0x81            ;
        movwf   Data_0          ;subcode
        movlw   0xfd            ;
        movwf   Data_3          ;end of response
        goto    sendit

execcmd clrf    rxstate         ;back to looking for another command
        movlw   0xff            ;default tx count to max
        movwf   txcount         ;

        movlw   5               ;Command 5 ?
        subwf   civ_cmd,w       ;
        btfss   STATUS,Z        ;
        goto    trycmd8
        ;command 5

;Command 5: write frequency data to vfo or memory
;
;  Cmd     Data_0        Data_1         Data_2           Data_3
; <0x5> [10Hz | 1Hz] [1Khz | 100Hz] [100Khz | 10Khz] [10Mhz | 1Mhz]
;
;     Data_4
; [1Ghz | 100 Mhz]

        BCF     STATUS,RP0      ;Bank 0
        movlw   5               ;convert 10 BCD digits
        movwf   LoopCntr
        movlw   low Data_4      ;msb of data
        movwf   FSR
        bsf     icomflags,COM_FLAG_LSB1ST ;lsb first
        call    bcd2bin

;copy new frequency to transmit and receive frequency
        call    setrxtx         ;

        BSF     STATUS,RP0      ;Bank 1
        movf    Duplex,w
        btfsc   STATUS,Z        ;
        goto    Cmd5B           ;Simplex
        decfsz  Duplex,w        ;
        goto    Cmd5A           ;
        call    MinusOffset     ;
        goto    Cmd5B           ;continue

Cmd5A   call    PlusOffset      ;

;calculate new code plug values
Cmd5B   call    SetFreqs        ;
        btfsc   STATUS,Z        ;
        goto    SendNG
        goto    SendOk

trycmd8 movlw   0x8             ;Command 8 ?
        subwf   civ_cmd,w       ;
        btfss   STATUS,Z        ;
        goto    trycmd9

;Command 8: Select memory channel
;
;  Cmd: select last channel
;  Cmd  Data_0
;  Cmd  Data_0, Data_1
;
        BCF     STATUS,RP0      ;Bank 0
        movlw   1               ;convert 2 BCD digits
        movwf   LoopCntr
        movlw   low Data_0      ;msb of data
        movwf   FSR
        bcf     icomflags,COM_FLAG_LSB1ST ;msb first
        call    bcd2bin
        movlw   d'32'           ;> 31 ?
        subwf   temp_3,w        ;
        btfsc   STATUS,C        ;
        goto    SendNG
        movfw   temp_3          ;
        movwf   memchan         ;
        goto    SendOk          ;

trycmd9 movlw   0x9             ;Command 9 ?
        subwf   civ_cmd,w       ;
        btfss   STATUS,Z        ;
        goto    trycmda

;Command 9: Store VFO in (previously) selected memory channel
;
        BCF     STATUS,RP0      ;Bank 0
        call    prgmode         ;
        goto    SendOk          ;

trycmda movlw   0xa             ;Command a ?
        subwf   civ_cmd,w       ;
        btfss   STATUS,Z        ;
        goto    trycmdf

;Command A: Store (previously) selected memory channel in VFO
;
        BCF     STATUS,RP0      ;Bank 0
        call    recallmode      ;
        goto    SendOk          ;

trycmdf movlw   0xf             ;Command F ?
        subwf   civ_cmd,w       ;
        btfss   STATUS,Z        ;
        goto    trycmd1b

;Command F: write frequency data to vfo or memory
;
;  Cmd  Data_0
; <0xF> 0x00 - Cancel split Freq OP
;       0x01 - Start split freq OP
;       0x10 - Cancel duplex Op
;       0x11 - Set duplex "-" Op
;       0x12 - Set duplex "+" Op

        movlw   0x10            ;subcommand 0x10 ?
        subwf   Data_0,f        ;
        btfsc   STATUS,Z        ;
        goto    SetSimplex      ;
        decfsz  Data_0,f        ;subcommand 0x11 ?
        goto    tryF_12         ;
        movlw   1               ;
        goto    SetDuplex       ;

SetSimplex
        clrf    Duplex          ;
        goto    SendOk          ;

tryF_12 decfsz  Data_0,f        ;subcommand 0x12 ?
        goto    SendNG          ;
        movlw   2

SetDuplex
        movwf   Duplex          ;
        goto    SendOk          ;


trycmd1b
        movlw   0x1b            ;Command 1B ?
        subwf   civ_cmd,w       ;
        btfss   STATUS,Z        ;
        goto    trycmdaa        ;

;Command 1B:
;
;  Cmd     Data_0         Data_1         Data_2
; <0x1b> [0x00 | 0x01] [100Hz | 10Hz] [1Hz | .1Hz]
;
; Data_0
; 0x00 - set encode CTSS frequency
; 0x01 - set decode CTSS frequency
;
        BCF     STATUS,RP0      ;Bank 0
        movlw   2               ;convert 4 BCD digits
        movwf   LoopCntr
        movlw   low Data_1      ;msb of data
        bcf     icomflags,COM_FLAG_LSB1ST ;msb first
        movwf   FSR
        call    bcd2bin

        BSF     STATUS,RP0      ;Bank 1
        movf    Data_0,f        ;sub command 0x00?
        btfsc   STATUS,Z        ;jump if not
        goto    setencode       ;

        decf    Data_0,w        ;sub command 0x01 ?
        btfss   STATUS,Z        ;jump if so
        goto    SendNG          ;

        ;decode

        BCF     STATUS,RP0      ;Bank 0
        call    SetRxCS         ;Turn off rx PL
        movf    temp_2,w        ;
        iorwf   temp_3,w        ;Freq = 0.0 ?
        btfsc   STATUS,Z        ;
        goto    changeok        ;change mode to load new code, then send OK
        call    setrxpl         ;nope, set Rx PL
        goto    tstplresult

setencode
        BCF     STATUS,RP0      ;Bank 0
        call    SetTxCS         ;Turn off tx PL
        movf    temp_2,w        ;
        iorwf   temp_3,w        ;Freq = 0.0 ?
        btfsc   STATUS,Z        ;
        goto    changeok        ;change mode to load new code, then send OK
        call    settxpl         ;nope, set Tx PL

        nop
tstplresult
        andlw   1
        btfss   STATUS,Z        ;
        goto    SendOk          ;
        goto    SendNG          ;

trycmdaa
        movlw   0xaa            ;Command aa ?
        subwf   civ_cmd,w       ;
        btfss   STATUS,Z        ;
        goto    SendNG          ;

;Command AA: our nonstandard Xcat commands
;
; Data_0
; 0x00 - get vfo raw data
; 0x80 - response to get vfo raw data
; 0x01 - set raw vfo data
; 0x81 - Signal/mode report to PC
; 0x02 - get firmware version number
; 0x82 - get firmware version number response
; 0x03 - get configuration data
; 0x83 - response to get configuration data
; 0x04 - set configuration data
; 0x05 - get Tx offset
; 0x85 - get Tx offset response
; 0x06 - set Tx offset
; 0x07 - get VCO split frequencies
; 0x87 - get VCO split frequencies response
; 0x08 - set VCO split frequencies
; 0x09 - get sync data debug info
; 0x89 - get sync data debug response
;
;  Cmd     Data_0         Data_1 ... Data_16
; <0xaa>   [0x01 | 0x80 ]  <16 bytes of raw data in code plug format>
;
;
        movlw   d'10'           ;> max sub command ?
        subwf   Data_0,w        ;
        btfsc   STATUS,C        ;
        goto    SendNG          ;
        movlw   high aasub
        movwf   PCLATH
        movf    Data_0,w        ;
aasub   addwf   PCL,f
        goto    getcpdat        ;0 - get vfo raw data
        goto    setcpdat        ;1 - set vfo raw data
        goto    getver          ;2 - get firmware version
        goto    getconfig       ;3 - get configuration data
        goto    setconfig       ;4 - set configuration data
        goto    GetTxOffset     ;5 - get Tx offset
        goto    SetTxOffset     ;6 - set Tx offset
        goto    GetVcoSplitF    ;7 - get VCO split frequencies
        goto    SetVcoSplitF    ;8 - set VCO split frequencies
        goto    GetSyncDebug    ;9 - get sync data debug info

;subcommand 0: get raw VFO data
getcpdat
        movlw   5               ;continue @ txstate 5
        movwf   NextTxState     ;
        movlw   low code_0      ;
        movwf   txdpointer      ;
        movlw   d'16'           ;16 bytes to send
        movwf   txdatacount     ;
        movlw   0x80            ;
        goto    sendxcatresp    ;kick it off

;subcommand 1: set raw VFO data
setcpdat
        movlw   d'16'           ;copy 16 bytes
        movwf   txcount         ;
        movlw   low code_0      ;to code_0 ...
        movwf   DataP           ;
        movlw   low Data_1      ;from Data_1 ...
        movwf   Data_0          ;
        call    copy1_0         ;
changeok        
        BCF     STATUS,RP0      ;Bank 0
        goto    changeok1       ;

;subcommand 2: get firmware version
getver  movf    From_Adr,w      ;copy from adr into
        movwf   To_Adr          ;to adr
        movlw   0x82            ;
        movwf   Data_0          ;
        movlw   a'V'            ;
        movwf   Data_1          ;
        movlw   a' '            ;
        movwf   Data_2          ;
        movlw   a'0'            ;
        movwf   Data_3          ;
        movlw   a'.'            ;
        movwf   Data_4          ;
        movlw   a'1'            ;
        movwf   Data_5          ;
        movlw   a'2'            ;
        movwf   Data_6          ;
        movlw   0xfd            ;
        movwf   Data_7          ;end of response
        goto    sendit          ;

;subcommand 3 - get configuration data
getconfig
        movlw   5               ;continue @ txstate 5
        movwf   NextTxState     ;
        movlw   low Config0     ;
        movwf   txdpointer      ;
        movlw   CONFIG_BYTES    ;
        movwf   txdatacount     ;
        movlw   0x83            ;
        goto    sendxcatresp    ;kick it off

;subcommand 4 - set configuration data
setconfig
        movlw   CONFIG_BYTES    ;copy CONFIG_BYTES bytes
        movwf   txcount         ;
        movlw   low Data_1      ;from Data_1 ...
        movwf   Data_0          ;
        movlw   low Config0     ;to Config0 ...
        movwf   DataP           ;
        call    copy1_0         ;
        movlw   low Config0     ;point to data
        movwf   FSR             ;
        
        BCF     STATUS,RP0      ;Bank 0
        movlw   CONFIG_BYTES    ;copy CONFIG_BYTES bytes
        movwf   LoopCnt         ;
        movlw   CONFIG_EEPROM_ADR  ;

        ;write txcount bytes from bank 0 RAM pointed to by FSR into
        ;eeprom address in w, then send OK
Write0ToEEPROM
        BSF     STATUS,RP1      ;Bank 2
        movwf   EEADR           ;
        clrf    EEADRH          ;
        BSF     STATUS,RP0      ;Bank 3
        BCF     EECON1,EEPGD    ;Point to EEPROM memory
        bcf     STATUS,RP1      ;bank 1
        BCF     STATUS,RP0      ;Bank 0
        
        movlw   high prg_loop   ;
        movwf   PCLATH          ;
        call    prg_loop        ;
        movlw   high SendOk     ;
        movwf   PCLATH          ;
        goto    SendOk

;subcommand 5 - get Tx offset
GetTxOffset
        movlw   low TxOff_3     ;point to lsb
        movwf   txdpointer      ;
        movlw   4               ;
        movwf   txdatacount     ;
        movlw   5               ;continue @ txstate 5
        movwf   NextTxState     ;
        movlw   0x85            ;
        goto    sendxcatresp    ;kick it off

;subcommand 6 - set Tx offset
SetTxOffset
        movlw   4               ;copy 4 bytes
        movwf   txcount         ;
        movlw   low Data_1      ;from Data_1 ...
        movwf   Data_0          ;
        movlw   low TxOff_3     ;to TxOff_3 ...
        movwf   DataP           ;
        call    copy1_0         ;
        movlw   low TxOff_3     ;point to data
        movwf   FSR             ;
        BCF     STATUS,RP0      ;Bank 0
        movlw   4               ;copy CONFIG_BYTES bytes
        movwf   LoopCnt         ;
        movlw   TX_OFFSET_ADR   ;
        goto    Write0ToEEPROM  ;

;subcommand 7 - get VCO split frequencies
GetVcoSplitF
        movlw   RX_VCO_SPLIT_F  ;
        BCF     STATUS,RP0      ;Bank 0
        BSF     STATUS,RP1      ;Bank 2
        movwf   EEADR           ;
        clrf    EEADRH          ;
        BCF     STATUS,RP1      ;Bank 0
        movlw   8               ;number of bytes to read
        movwf   LoopCnt         ;
        movlw   high readee     ;
        movwf   PCLATH
        movlw   low fvco_0      ;point to LSB
        call    readee          ;read Rx, TX VCO split frequency into fvco_0
        BSF     STATUS,RP0      ;Bank 1
        
        movlw   low fvco_0      ;point to LSB
        movwf   txdpointer      ;
        movlw   high sendxcatresp ;
        movwf   PCLATH
        movlw   8               ;
        movwf   txdatacount     ;
        movlw   5               ;continue @ txstate 5
        movwf   NextTxState     ;
        movlw   0x87            ;
        goto    sendxcatresp    ;kick it off

;subcommand 8 - set VCO split frequencies
SetVcoSplitF    
        movlw   8               ;copy 8 bytes
        movwf   txcount         ;
        movlw   low Data_1      ;from Data_1 ...
        movwf   Data_0          ;
        movlw   low fvco_0      ;to fvco_0 ...
        movwf   DataP           ;
        call    copy1_0         ;
        movlw   low fvco_0      ;point to data
        movwf   FSR             ;
        BCF     STATUS,RP0      ;Bank 0
        movlw   8               ;write 8 bytes
        movwf   LoopCnt         ;
        movlw   RX_VCO_SPLIT_F  ;
        goto    Write0ToEEPROM  ;into EEPROM

;subcommand 9 - get sync data debug info
GetSyncDebug
        movlw   5               ;continue @ txstate 5
        movwf   NextTxState     ;
        movlw   low srx5_d      ;
        movwf   txdpointer      ;
        movlw   d'10'           ;10 bytes to send
        movwf   txdatacount     ;
        movlw   0x89            ;
;       goto    sendxcatresp    ;kick it off
        
sendxcatresp
        movwf   Data_0          ;update subcommand for the response
        movlw   5               ;send header
        movwf   txcount         ;
        movlw   1               ;txstate 1
        movwf   txstate         ;
        movf    From_Adr,w      ;copy from adr into
        movwf   To_Adr          ;to adr
        goto    sendit          ;

SendNG  movlw   0xfa            ;
        goto    sendnd          ;

SendOk  movlw   0xfb

sendnd
sendresponse
        BSF     STATUS,RP0      ;Bank 1
        movwf   civ_cmd         ;save OK/NG command code
        movf    From_Adr,w      ;copy from adr into
        movwf   To_Adr          ;to adr
        movlw   0xfd            ;
        movwf   Data_0          ;end of response

;start sending.  Fill in start_fe, From_Adr
sendit
        ;enable our serial output buffer
        bcf     TRISC,6         ;
        movlw   0xfe            ;
        movwf   start_fe        ;
        movf    OurCIVAdr,w     ;
        movwf   From_Adr        ;
        movlw   1               ;set txstate 1 for send response
        movwf   txstate         ;
        movlw   low start_fe    ;
        movwf   DataP
        BCF     STATUS,RP0      ;Bank 0
        movlw   0xfe            ;
        movwf   TXREG           ;send first 0xfe
        return

;convert LoopCntr BCD bytes into binary in temp_0 ... temp_3
;input is from Bank 1 RAM pointed to by FSR
bcd2bin BCF     STATUS,RP0      ;Bank 0
        clrf    temp_0
        clrf    temp_1
        clrf    temp_2
        clrf    temp_3
        goto    bcd1

bcdloop1
        call    tempx10

        ;add ms nibble to temp
bcd1    BSF     STATUS,RP0      ;Bank 1
        swapf   INDF,w
        BCF     STATUS,RP0      ;Bank 0
        call    addw2temp
        call    tempx10
        ;add ls nibble to temp
        BSF     STATUS,RP0      ;Bank 1
        movf    INDF,w
        BCF     STATUS,RP0      ;Bank 0
        call    addw2temp
        movlw   1               ;add 1 if msb first
        btfsc   icomflags,COM_FLAG_LSB1ST
        movlw   0xff            ;subtract 1 if lsb first
        addwf   FSR,f
        decfsz  LoopCntr,f
        goto    bcdloop1
        return

        ;multiply current temp by 10

tempx10 movf    temp_0,w
        movwf   temp1_0
        movf    temp_1,w
        movwf   temp1_1
        movf    temp_2,w
        movwf   temp1_2
        movf    temp_3,w
        movwf   temp1_3
        call    tempx2          ;* 2
        call    tempx2          ;* 4

        ;add temp to 4*temp

        movf    temp1_3,w
        addwf   temp_3,f        ;
        movf    temp1_2,w
        btfsc   STATUS,C        ;
        incfsz  temp1_2,w
        addwf   temp_2,f        ;
        movf    temp1_1,w
        btfsc   STATUS,C        ;
        incfsz  temp1_1,w
        addwf   temp_1,f        ;
        movf    temp1_0,w
        btfsc   STATUS,C        ;
        incfsz  temp1_0,w
        addwf   temp_0,f        ;
        call    tempx2          ;* 10
        return

tempx2  bcf     STATUS,C
        rlf     temp_3,f
        rlf     temp_2,f
        rlf     temp_1,f
        rlf     temp_0,f
        return

addw2temp
        andlw   0xf             ;
addw2temp1        
        addwf   temp_3,f
        movlw   1
        btfsc    STATUS,C
        addwf   temp_2,f
        btfsc    STATUS,C
        addwf   temp_1,f
        btfsc    STATUS,C
        addwf   temp_0,f
        return

;copy temp to rxf, txf
setrxtx
        movf    temp_0,w
        movwf   rxf_0
        movwf   txf_0
        movf    temp_1,w
        movwf   rxf_1
        movwf   txf_1
        movf    temp_2,w
        movwf   rxf_2
        movwf   txf_2
        movf    temp_3,w
        movwf   rxf_3
        movwf   txf_3
        return

;add current offset to transmit frequency
PlusOffset
        BCF     STATUS,RP0      ;Bank 0
        movf    TxOff_3,w
        addwf   txf_3,f         ;
        movf    TxOff_2,w
        btfsc   STATUS,C        ;
        incfsz  TxOff_2,w
        addwf   txf_2,f         ;
        movf    TxOff_1,w
        btfsc   STATUS,C        ;
        incfsz  TxOff_1,w
        addwf   txf_1,f         ;
        movf    TxOff_0,w
        btfsc   STATUS,C        ;
        incfsz  TxOff_0,w
        addwf   txf_0,f         ;
        return

;subtract current offset from transmit frequency
MinusOffset
        BCF     STATUS,RP0      ;Bank 0
        movf    TxOff_3,w
        subwf   txf_3,f         ;
        movf    TxOff_2,w
        btfss   STATUS,C        ;
        incfsz  TxOff_2,w
        subwf   txf_2,f         ;
        movf    TxOff_1,w
        btfss   STATUS,C        ;
        incfsz  TxOff_1,w
        subwf   txf_1,f         ;
        movf    TxOff_0,w
        btfss   STATUS,C        ;
        incfsz  TxOff_0,w
        subwf   txf_0,f         ;
        return

;Set Rx frequency first since it's (sometimes) ok to listen out of band
SetFreqs
        BCF     STATUS,RP0      ;Bank 0
        call    setrxf          ;
        btfsc   STATUS,Z        ;
        return                  ;error setting rx frequency
        bsf     icomflags,COM_FLAG_RX_SET       ;
        
        call    settxf          ;
        btfsc   STATUS,Z        ;
        goto    changebad       ;
        call    changemode      ;
        bsf     icomflags,COM_FLAG_TX_SET       ;
        iorlw   0x1             ;clear zero flag
        return                  ;
                
changebad
;load the new frequencies into into the radio even if the
;attempt to set a tx frequency failed.  This allows us to 
;*listen* out of band.
        call    changemode      ;
        clrw                    ;set zero flag
        return                  ;

;copy txcount bytes from Bank 1 RAM address in Data_0 to
;Bank 0 RAM address in DataP.  Enter/exit with RAM Bank 1 selected.
        global  copy1_0
copy1_0 movf    Data_0,w        ;get from address
        incf    Data_0,f        ;
        movwf   FSR             ;
        movf    INDF,w          ;get byte from rx buffer
        movwf   nbtemp          ;save it
        movf    DataP,w         ;get to address
        incf    DataP,f         ;
        movwf   FSR             ;
        bcf     STATUS,RP0      ;bank 0
        movf    nbtemp,w        ;get byte to copy
        movwf   INDF            ;save it
        BSF     STATUS,RP0      ;Bank 1
        decfsz  txcount,f       ;
        goto    copy1_0         ;
        return
        

;copy txcount bytes from Bank 0 RAM address in Data_0 to
;Bank 1 RAM address in DataP.  Enter/exit with RAM Bank 1 selected.
;copy0_1 movf    Data_0,w        ;get from address
;        incf    Data_0,f        ;
;        movwf   FSR             ;
;        bcf     STATUS,RP0      ;bank 0
;        movf    INDF,w          ;get byte from rx buffer
;        movwf   nbtemp          ;save it
;        BSF     STATUS,RP0      ;Bank 1
;        movf    DataP,w         ;get to address
;        incf    DataP,f         ;
;        movwf   FSR             ;
;        movf    nbtemp,w        ;get byte to copy
;        movwf   INDF            ;save it
;        decfsz  txcount,f       ;
;        goto    copy0_1         ;
;        return
        

;------------------------------------------------------------------------------
;"Link Comm RLC3" / "Generic" / "Doug Hall" format:
;
; Byte lsb bit of byte 1 shifted in first
;  Byte 1: 8 user functions, high = off, low = on
; (srx5)
;  Byte 2: B7 - TX power, 1 = on
; (srx4)   B6 - RX power, 1 = on
;          B5, B4 - Tx power:
;                 B5 0, B4 0 = low
;                 B5 1, B4 0 = medium
;                 B5 0, B4 1 = high
;                 B5 1, B4 1 = no power change
;          B0 -> B3 Band select:
;                 0 - UHF 430   (43x.xxx Mhz)
;                 1 - 1250      (125x.xxx Mhz)
;                 2 - 2 meters  (14x.xxx Mhz)
;                 3 - 220       (22x.xxx Mhz)
;                 4 - UHF 440   (44x.xxx Mhz)
;                 5 - 1270      (127x.xxx Mhz)
;                 6 - 1280      (128x.xxx Mhz)
;                 7 - 1290      (129x.xxx Mhz)
;                 8 - 1260      (126x.xxx Mhz)
;                 9 - 1240      (124.xxx Mhz)
;                 A - UHF 420   (42x.xxx Mhz)
;                 B - 900       (90x.xxx Mhz)
;                 C - 6 meters  (05x.xxx Mhz)
;                 D - 10 meters (02x.xxx Mhz)
;                 E - 130 Mhz   (13x.xxx Mhz)
;               If the band select nibble is not in the above list then
;               the frequency will be used as the transmitter offset for
;               duplex operations.
;
;  Byte 3: B7 - Radio power, 1 = on
; (srx3)   B6 - 5 Khz bit, 1 = +5 Khz
;          B5 -> B4 Offset:
;               B5 0, B4 0 = negative Tx offset
;               B5 0, B4 1 = positive Tx offset
;               B5 1, B4 0 = simplex
;               B5 1, B4 1 = negative 20 Mhz Tx offset (1200 radios only)
;          B0 -> B3 Mhz digit (note: 100 Mhz and 10 Mhz digits are implied)
;
;  Byte 4: B4 -> B7 100 Khz digit
; (srx2)   B0 -> B3 10 Khz digit
;
;  Byte 5: B7 - 1 = PL decode enable
; (srx1)   B6 - 1 = PL encode enable
;          B0 -> B5 = PL tone (Communications Specialists TS64 number)
;
;  (Byte 6 and 7 are currently ignored by the Xcat)
;  Byte 6: B4 -> B7 Rx level
;          B0 -> B3 Squelch level
;
;  Byte 7: B4 -> B7 Memory channel
;          B3 - Memory channel 16
;          B2 - Memory save
;          B1 - Open squelch
;          B0 - Scan on
;
;1 = 67.0Hz 2 = 71.9Hz 3 = 74.4Hz 4 = 77.0Hz 5 = 79.7Hz
;6 = 82.5Hz 7 = 85.4Hz 8 = 88.5Hz 9 = 91.5Hz 10 = 94.8Hz
;11 = 97.4Hz 12 = 100.0Hz 13 = 103.5Hz 14 = 107.2Hz 15 = 110.9Hz
;16 = 114.8Hz 17 = 118.8Hz 18 = 123.0Hz 19 = 127.3Hz 20 = 131.8Hz
;21 = 136.5Hz 22 = 141.3Hz 23 = 146.2Hz 24 = 151.4Hz 25 = 156.7Hz
;26 = 162.2Hz 27 = 167.9Hz 28 = 173.8Hz 29 = 179.9Hz 30 = 186.2Hz
;31 = 192.8Hz 32 = 203.5Hz 33 = 210.7Hz 34 = 218.1Hz 35 = 225.7Hz
;36 = 233.6Hz 37 = 241.8Hz 38 = 250.3Hz 39 = 254.1Hz 40 =  69.3Hz
;41 = 159.8Hz 42 = 165.5Hz 43 = 171.3Hz 44 = 177.3Hz 45 = 183.5Hz
;46 = 189.9Hz 47 = 196.6Hz 48 = 199.5Hz 49 = 206.5Hz 50 = 229.1Hz
;------------------------------------------------------------------------------
        global  cnv_generic
cnv_generic
        ;set the number of bits to receive for the next time
        bsf     STATUS,RP0      ;bank 1
        movlw   d'40'           ;5 bytes / remote
        movwf   srxcnt          ;
        bcf     STATUS,RP0      ;bank 0
        subwf   BARGB1,w        ;
        btfsc   STATUS,Z        ;
        goto    cnv_generic1    ;
        movlw   d'56'           ;7 bytes ?
        subwf   BARGB1,w        ;
        btfss   STATUS,Z        ;
        return
        
cnv_generic1
        bcf     icomflags,COM_FLAG_TXOFF ;Not Tx frequency select (yet)
        movf    srx2,w          ;get 2'nd byte from serial stream
        andlw   0xf             ;
        movwf   temp_0          ;save

        movlw   2               ;2 meters ?
        subwf   temp_0,w        ;
        btfss   STATUS,Z        ;
        goto    gen1            ;

        ;2 meter frequency
        movf    Config0,w       ;
        andlw   CONFIG_BAND_MASK;
        sublw   CONFIG_2M       ;configured as 2 meter radio ?
        btfss   STATUS,Z        ;
        return                  ;nope, ignore command
        movlw   d'14'           ;
        goto    gensetband      ;

gen1    movlw   4               ;440 ?
        subwf   temp_0,w        ;
        btfss   STATUS,Z        ;
        goto    gen2            ;
        ;440 frequency
        movf    Config0,f       ;
        andlw   CONFIG_BAND_MASK;
        sublw   CONFIG_440      ;configured as 440 radio ?
        btfsc   STATUS,Z        ;
        return                  ;nope, ignore command
        movlw   d'44'           ;
        goto    gensetband      ;

gen2    movlw   0xc             ;6 meters ?
        subwf   temp_0,w        ;
        btfss   STATUS,Z        ;
        goto    gen3            ;
        ;6 meter frequency
        movf    Config0,f       ;
        andlw   CONFIG_BAND_MASK;
        sublw   CONFIG_6M       ;configured as 6 meter radio ?
        btfsc   STATUS,Z        ;
        goto    gen6m           ;Yup
        sublw   CONFIG_10_6M    ;configured as 10/6 meter radio ?
        btfsc   STATUS,Z        ;
        return                  ;nope, ignore command
gen6m   movlw   5               ;
        goto    gensetband      ;

gen3    movlw   1               ;10 meters ?
        subwf   temp_0,w        ;
        btfsc   STATUS,Z        ;
        ;Not a known frequency band, assume it's a transmitter offset
        bsf     icomflags,COM_FLAG_TXOFF ;Tx frequency select
        clrw                    ;
        goto    gensetband      ;

        ;10 meter frequency
        movf    Config0,f       ;
        andlw   CONFIG_BAND_MASK;
        btfsc   STATUS,Z        ;configured as a 10 meter radio ?
        goto    gen10m          ;Yup, a 10 meter radio
        sublw   CONFIG_10_6M    ;configurated as a 6 & 10 meter radio ?
        btfsc   STATUS,Z        ;
        return                  ;guess not, ignore it

gen10m  movlw   2               ;

        ;w = BCD for Mhz hunderds and tens
gensetband
        movwf   temp_3          ;Init temp w 100Mhz digit, 10Mhz digit
        clrf    temp_2          ;
        clrf    temp_1          ;
        clrf    temp_0          ;
        call    tempx10         ;
        movf    srx3,w          ;get Mhz digit
        call    addw2temp       ;
        call    tempx10         ;
        swapf   srx4,w          ;get 100Khz digit
        call    addw2temp       ;
        call    tempx10         ;
        movf    srx4,w          ;get 10Khz digit
        call    addw2temp       ;
        call    tempx10         ;
        movlw   5               ;
        btfsc   srx3,6          ;jump if not +5 Khz
        call    addw2temp       ;
        call    tempx10         ;
        btfsc   ConfUF,CONFIG_2_5_SEL
        goto    gen4            ;

        ;add 2.5 Khz to frequency if UF6 is high
        movlw   d'25'           ;
        btfsc   srx5,CONFIG_2_5_SEL
        call    addw2temp1      ;add 2.5 Khz

gen4    call    tempx10         ;
        call    tempx10         ;
        btfsc   icomflags,COM_FLAG_TXOFF        ;
        goto    settxoff        ;
;copy new frequency to transmit and receive frequency
        call    setrxtx         ;
        btfsc   srx3,4          ;Positive TX offset ?
        goto    genplus         ;
        btfss   srx3,5          ;Negative TX offset ?
        call    MinusOffset     ;do it if so

gensimplex
        movfw   srx5            ;get PL code
        andlw   0x3f            ;
        call    SetPL           ;set it
        btfss   srx5,6          ;jump if PL encode is enabled
        call    SetTxCS         ;disable PL encode
        btfss   srx5,7          ;jump if PL decode is enabled
        call    SetRxCS         ;disable PL decode
        movf    ConfUF,w        ;Get User function configuration
        andwf   srx1,f          ;mask bits to zero that aren't configured as
                                ;user function outputs
        xorlw   0xff            ;invert mask
        andwf   PORTD,w         ;get bits we're keeping
        iorwf   srx1,w          ;or in UF bits
        movwf   PORTD           ;output new port D bits
        ;TODO: set high/medium/low power
        goto    SetFreqs        ;

genplus call    PlusOffset      ;
        goto    gensimplex      ;continue

;Temp = new transmit offset
settxoff
        movf    temp_0,w
        movwf   TxOff_0
        movf    temp_1,w
        movwf   TxOff_1
        movf    temp_2,w
        movwf   TxOff_2
        movf    temp_3,w
        movwf   TxOff_3
        return

;
;Cactus format:  LSB of byte 1 shifted out first
;NB: Clock and data lines are inverted, the following is shown as true logic.
;3, 6, 9, or 12 bytes are clocked out depending on the number of remote bases
;the software has been configured for.  The original hardware had a seperate 
;load line which was used to transfer the data from the shift register into
;a parallel latch to driver the radio.
;The Xcat is configured to know which set of 3 bytes to look at after a timeout
;rather than trying to use the (too narrow) load pulse.
;RBC-700 

;
;  Byte 1: B7 - not used
; (srx3)   B6 - not used
;          B5 - 0 = PL encode enabled, 1 = PL encode disabled
;          B0 -> B4 = PL tone (Communications Specialists TS32 number)
;
;  Byte 2: B4 -> B7 10 Khz digit
; (srx4)   B3 - 5 Khz bit
;          B2 - not used
;          B1 - 1 = high power level
;          B0 - 1 = QRP power level
;
;  Byte 3: B4 -> B7 Mhz digit (note: 100 Mhz and 10 Mhz digits are implied)
; (srx5)   B0 -> B3 100 Khz digit
;
;
;Communications Specialists TS32 number numbers (binary value + 1):
;
;     C.T.C.S.S.   EIA
;          FREQ.   CODE
;======================
;   1       67.0   XZ
;   2       71.9   XA
;   3       74.4   WA
;   4       77.0   XB
;   5       79.7   SP
;   6       82.5   YZ
;   7       85.4   YA
;   8       88.5   YB
;   9       91.5   ZZ
;  10       94.8   ZA
;  11       97.4   ZB
;  12      100.0   1Z
;  13      103.5   1A
;  14      107.2   1B
;  15      110.9   2Z
;  16      114.8   2A
;  17      118.8   2B
;  18      123.0   3Z
;  19      127.3   3A
;  20      131.8   3B
;  21      136.5   4Z
;  22      141.3   4A
;  23      146.2   4B
;  24      151.4   5Z
;  25      156.7   5A
;  26      162.2   SB
;  27      167.9   6Z
;  28      173.8   6A
;  29      179.9   6B
;  30      186.2   7Z
;  31      192.8   7A
;  32      203.5   Ml
;====================

        global  cnvcactus
cnvcactus
        ;all of the data bits should have been shifted in by now
        bsf     STATUS,RP0      ;bank 1
        movf    srxcnt,f        ;
        bcf     STATUS,RP0      ;bank 0
        btfss   STATUS,Z        ;
        clrf    srxbits         ;Clear srxbits to force an error later

;calculate the number of bits to receive for the next time
        
        movf    Config0,w       ;Get configuration byte
        bsf     STATUS,RP0      ;bank 1
        movwf   rxbyte          ;
        ;shift bits into place
        rlf     rxbyte,f        ;
        rlf     rxbyte,f        ;
        rlf     rxbyte,f        ;
        movlw   0x3             ;
        andwf   rxbyte,f        ;
        incf    rxbyte,f        ;rxbyte = remote base # 1 -> 4
        
        clrf    srxcnt          ;
        movlw   d'24'           ;3 bytes / remote
cactus6 addwf   srxcnt,f        ;
        decfsz  rxbyte,f        ;
        goto    cactus6         ;loop
        bcf     STATUS,RP0      ;bank 0

;In cactus mode we should have N x 3 bytes of serial data were
;N = 1, 2, 3 or 4.
        subwf   srxbits,w       ;
        btfsc   STATUS,Z        ;
        goto    cactus1         ;
        movlw   d'48'           ;6 bytes ?
        subwf   srxbits,w       ;
        btfsc   STATUS,Z        ;
        goto    cactus1         ;
        movlw   d'72'           ;9 bytes ?
        subwf   srxbits,w       ;
        btfsc   STATUS,Z        ;
        goto    cactus1         ;
        movlw   d'96'           ;12 bytes ?
        subwf   srxbits,w       ;
        btfss   STATUS,Z        ;
        return                  ;nope !

        ;we have a sane number of bits
cactus1
        ;data passes initial tests our data is in srx5 .. srx3
        ;data is inverted, fix it
        comf    srx5,f          ;
        comf    srx4,f          ;
        comf    srx3,f          ;
        
        ;Set tx power level outputs
        btfsc   srx4,0          ;
        goto    cactus3         ;not QRP
        bsf     PORTD,CONFIG_QRP
        ;set code plug bit for low power
        bcf     code_8,2
        goto    cactus4
cactus3
        bcf     PORTD,CONFIG_QRP
        ;set code plug bit for high power
        bsf     code_8,2

cactus4        
        btfsc   srx4,1          ;
        goto    cactus5         ;not high power
        bsf     PORTD,CONFIG_HI_PWR
        goto    cactus2
cactus5
        bcf     PORTD,CONFIG_HI_PWR
        
cactus2 movfw   srx3            ;get PL code
        andlw   0x1f            ;
        call    SetPL           ;set it
        btfsc   srx3,5          ;jump if PL encode is enabled
        call    SetTxCS         ;disable PL encode
        ;cactus is always carrier squelch on receive ?
        call    SetRxCS         ;disable PL decode
        movlw   high crcmhzlookup
        movwf   PCLATH
        movf    Config0,w       ;
        andlw   CONFIG_BAND_MASK;
        call    crcmhzlookup    ;

        ;w = BCD for Mhz hunderds and tens
        movwf   temp_3          ;Init temp w 100Mhz digit, 10Mhz digit
        clrf    temp_2          ;
        clrf    temp_1          ;
        clrf    temp_0          ;
        call    tempx10         ;
        swapf   srx5,w          ;get Mhz digit
        call    addw2temp       ;
        call    tempx10         ;
        movf    srx5,w          ;get 100Khz digit
        call    addw2temp       ;
        call    tempx10         ;
        swapf   srx4,w          ;get 10Khz digit
        call    addw2temp       ;
        call    tempx10         ;
        movlw   5               ;
        btfsc   srx4,3          ;jump if not +5 Khz
        call    addw2temp       ;
        call    tempx10         ;
        call    tempx10         ;
        call    tempx10         ;
        
;copy new frequency to transmit and receive frequency
        call    setrxtx         ;
        goto    SetFreqs        ;

crcmhzlookup
        addwf   PCL,f
        retlw   2               ;10 meters 2x.xxx
        retlw   5               ;6 meters 5x.xxx
        retlw   5               ;6 & 10 default to 5x.xxx
        retlw   d'14'           ;2 meters 14x.xxx
        retlw   d'44'           ;44x.xxxx
        retlw   d'14'           ;not used
        retlw   d'14'           ;not used
        retlw   d'14'           ;not used

changeok1
        call    changemode      ;
        goto    SendOk          ;

setmodehigh
        bsf     STATUS,RP0      ;bank 1
        bcf     TRISC,0         ;enable output
        bcf     STATUS,RP0      ;bank 0
        bsf     PORTC,0         ;set the output high
        return
        
        ;END of PROG1 code new ADD new PROG1 code here

        end

