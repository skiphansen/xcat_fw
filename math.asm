; $Log: math.asm,v $
; Revision 1.1  2004/07/03 16:38:59  Skip Hansen
; Initial revision
;
;        
        processor       16F877A
        include <p16f877A.inc>


DATA0           udata
;*********************************************************************************************
;
;       GENERAL MATH LIBRARY DEFINITIONS
;
;       general literal constants

;       define assembler constants

B0              equ     0
B1              equ     1
B2              equ     2
B3              equ     3
B4              equ     4
B5              equ     5
B6              equ     6
B7              equ     7

MSB             equ     7
LSB             equ     0


;     define commonly used bits

;     STATUS bit definitions

                #define _C              STATUS,C
                #define _Z              STATUS,Z
;
;       binary operation arguments
;
REMB3           res     1
REMB2           res     1
REMB1           res     1
REMB0           res     1
AARGB3          res     1
AARGB2          res     1
AARGB1          res     1
AARGB0          res     1
#define         AARG AARGB0  ; most significant byte of argument A
;
BARGB3          res     1
BARGB2          res     1
BARGB1          res     1
BARGB0          res     1
#define         BARG BARGB0  ; most significant byte of argument B

        global  AARGB0, AARGB1,AARGB2,AARGB3
        global  BARGB0, BARGB1, BARGB2, BARGB3
;
;       Note that AARG and ACC reference the same storage locations
;
;*********************************************************************************************
;
;       FIXED POINT SPECIFIC DEFINITIONS
;
;       remainder storage
;
;#define                REMB3   AARGB7
;#define                REMB2   AARGB6
;#define                REMB1   AARGB5
;#define                REMB0   AARGB4  ; most significant byte of remainder
        global  REMB0, REMB1, REMB2, REMB3

TEMP            res     1
LOOPCOUNT       res     1

PROG2           code
UDIV3232L       macro

;       Max Timing:     24+6*32+31+31+6*32+31+31+6*32+31+31+6*32+31+16 = 1025 clks

;       Min Timing:     24+6*31+30+30+6*31+30+30+6*31+30+30+6*31+30+3 = 981 clks

;       PM: 359                                 DM: 13

                CLRF            TEMP

                RLF             AARGB0,W
                RLF             REMB3, F
                MOVF            BARGB3,W
                SUBWF           REMB3, F
                MOVF            BARGB2,W
                BTFSS           _C
                INCFSZ          BARGB2,W
                SUBWF           REMB2, F
                MOVF            BARGB1,W
                BTFSS           _C
                INCFSZ          BARGB1,W
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           _C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F

                CLRW
                BTFSS           _C
                MOVLW           1
                SUBWF           TEMP, F
                RLF             AARGB0, F

                MOVLW           7
                MOVWF           LOOPCOUNT

LOOPU3232A      RLF             AARGB0,W
                RLF             REMB3, F
                RLF             REMB2, F
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMP, F
                MOVF            BARGB3,W
                BTFSS           AARGB0,LSB
                GOTO            UADD22LA

                SUBWF           REMB3, F
                MOVF            BARGB2,W
                BTFSS           _C
                INCFSZ          BARGB2,W
                SUBWF           REMB2, F
                MOVF            BARGB1,W
                BTFSS           _C
                INCFSZ          BARGB1,W
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           _C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           _C
                MOVLW           1
                SUBWF           TEMP, F
                GOTO            UOK22LA

UADD22LA        ADDWF           REMB3, F
                MOVF            BARGB2,W
                BTFSC           _C
                INCFSZ          BARGB2,W
                ADDWF           REMB2, F
                MOVF            BARGB1,W
                BTFSC           _C
                INCFSZ          BARGB1,W
                ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           _C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           _C
                MOVLW           1
                ADDWF           TEMP, F

UOK22LA RLF             AARGB0, F

                DECFSZ          LOOPCOUNT, F
                GOTO            LOOPU3232A

                RLF             AARGB1,W
                RLF             REMB3, F
                RLF             REMB2, F
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMP, F
                MOVF            BARGB3,W
                BTFSS           AARGB0,LSB
                GOTO            UADD22L8

                SUBWF           REMB3, F
                MOVF            BARGB2,W
                BTFSS           _C
                INCFSZ          BARGB2,W
                SUBWF           REMB2, F
                MOVF            BARGB1,W
                BTFSS           _C
                INCFSZ          BARGB1,W
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           _C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           _C
                MOVLW           1
                SUBWF           TEMP, F
                GOTO            UOK22L8

UADD22L8        ADDWF           REMB3, F
                MOVF            BARGB2,W
                BTFSC           _C
                INCFSZ          BARGB2,W
                ADDWF           REMB2, F
                MOVF            BARGB1,W
                BTFSC           _C
                INCFSZ          BARGB1,W
                ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           _C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           _C
                MOVLW           1
                ADDWF           TEMP, F

UOK22L8 RLF             AARGB1, F

                MOVLW           7
                MOVWF           LOOPCOUNT

LOOPU3232B      RLF             AARGB1,W
                RLF             REMB3, F
                RLF             REMB2, F
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMP, F
                MOVF            BARGB3,W
                BTFSS           AARGB1,LSB
                GOTO            UADD22LB

                SUBWF           REMB3, F
                MOVF            BARGB2,W
                BTFSS           _C
                INCFSZ          BARGB2,W
                SUBWF           REMB2, F
                MOVF            BARGB1,W
                BTFSS           _C
                INCFSZ          BARGB1,W
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           _C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           _C
                MOVLW           1
                SUBWF           TEMP, F
                GOTO            UOK22LB

UADD22LB        ADDWF           REMB3, F
                MOVF            BARGB2,W
                BTFSC           _C
                INCFSZ          BARGB2,W
                ADDWF           REMB2, F
                MOVF            BARGB1,W
                BTFSC           _C
                INCFSZ          BARGB1,W
                ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           _C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           _C
                MOVLW           1
                ADDWF           TEMP, F

UOK22LB RLF             AARGB1, F

                DECFSZ          LOOPCOUNT, F
                GOTO            LOOPU3232B

                RLF             AARGB2,W
                RLF             REMB3, F
                RLF             REMB2, F
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMP, F
                MOVF            BARGB3,W
                BTFSS           AARGB1,LSB
                GOTO            UADD22L16

                SUBWF           REMB3, F
                MOVF            BARGB2,W
                BTFSS           _C
                INCFSZ          BARGB2,W
                SUBWF           REMB2, F
                MOVF            BARGB1,W
                BTFSS           _C
                INCFSZ          BARGB1,W
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           _C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           _C
                MOVLW           1
                SUBWF           TEMP, F
                GOTO            UOK22L16

UADD22L16       ADDWF           REMB3, F
                MOVF            BARGB2,W
                BTFSC           _C
                INCFSZ          BARGB2,W
                ADDWF           REMB2, F
                MOVF            BARGB1,W
                BTFSC           _C
                INCFSZ          BARGB1,W
                ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           _C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           _C
                MOVLW           1
                ADDWF           TEMP, F

UOK22L16        RLF             AARGB2, F

                MOVLW           7
                MOVWF           LOOPCOUNT

LOOPU3232C      RLF             AARGB2,W
                RLF             REMB3, F
                RLF             REMB2, F
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMP, F
                MOVF            BARGB3,W
                BTFSS           AARGB2,LSB
                GOTO            UADD22LC

                SUBWF           REMB3, F
                MOVF            BARGB2,W
                BTFSS           _C
                INCFSZ          BARGB2,W
                SUBWF           REMB2, F
                MOVF            BARGB1,W
                BTFSS           _C
                INCFSZ          BARGB1,W
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           _C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           _C
                MOVLW           1
                SUBWF           TEMP, F
                GOTO            UOK22LC

UADD22LC        ADDWF           REMB3, F
                MOVF            BARGB2,W
                BTFSC           _C
                INCFSZ          BARGB2,W
                ADDWF           REMB2, F
                MOVF            BARGB1,W
                BTFSC           _C
                INCFSZ          BARGB1,W
                ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           _C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           _C
                MOVLW           1
                ADDWF           TEMP, F

UOK22LC RLF             AARGB2, F

                DECFSZ          LOOPCOUNT, F
                GOTO            LOOPU3232C

                RLF             AARGB3,W
                RLF             REMB3, F
                RLF             REMB2, F
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMP, F
                MOVF            BARGB3,W
                BTFSS           AARGB2,LSB
                GOTO            UADD22L24

                SUBWF           REMB3, F
                MOVF            BARGB2,W
                BTFSS           _C
                INCFSZ          BARGB2,W
                SUBWF           REMB2, F
                MOVF            BARGB1,W
                BTFSS           _C
                INCFSZ          BARGB1,W
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           _C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           _C
                MOVLW           1
                SUBWF           TEMP, F
                GOTO            UOK22L24

UADD22L24       ADDWF           REMB3, F
                MOVF            BARGB2,W
                BTFSC           _C
                INCFSZ          BARGB2,W
                ADDWF           REMB2, F
                MOVF            BARGB1,W
                BTFSC           _C
                INCFSZ          BARGB1,W
                ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           _C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           _C
                MOVLW           1
                ADDWF           TEMP, F

UOK22L24        RLF             AARGB3, F

                MOVLW           7
                MOVWF           LOOPCOUNT

LOOPU3232D      RLF             AARGB3,W
                RLF             REMB3, F
                RLF             REMB2, F
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMP, F
                MOVF            BARGB3,W
                BTFSS           AARGB3,LSB
                GOTO            UADD22LD

                SUBWF           REMB3, F
                MOVF            BARGB2,W
                BTFSS           _C
                INCFSZ          BARGB2,W
                SUBWF           REMB2, F
                MOVF            BARGB1,W
                BTFSS           _C
                INCFSZ          BARGB1,W
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           _C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           _C
                MOVLW           1
                SUBWF           TEMP, F
                GOTO            UOK22LD

UADD22LD        ADDWF           REMB3, F
                MOVF            BARGB2,W
                BTFSC           _C
                INCFSZ          BARGB2,W
                ADDWF           REMB2, F
                MOVF            BARGB1,W
                BTFSC           _C
                INCFSZ          BARGB1,W
                ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           _C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           _C
                MOVLW           1
                ADDWF           TEMP, F

UOK22LD RLF             AARGB3, F

                DECFSZ          LOOPCOUNT, F
                GOTO            LOOPU3232D

                BTFSC           AARGB3,LSB
                GOTO            UOK22L
                MOVF            BARGB3,W
                ADDWF           REMB3, F
                MOVF            BARGB2,W
                BTFSC           _C
                INCFSZ          BARGB2,W
                ADDWF           REMB2, F
                MOVF            BARGB1,W
                BTFSC           _C
                INCFSZ          BARGB1,W
                ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           _C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F

UOK22L

                endm

;**********************************************************************************************
;**********************************************************************************************

;       32/32 Bit Unsigned Fixed Point Divide 32/32 -> 32.32

;       Input:  32 bit unsigned fixed point dividend in AARGB0, AARGB1,AARGB2,AARGB3
;               32 bit unsigned fixed point divisor in BARGB0, BARGB1, BARGB2, BARGB3

;       Use:    CALL    FXD3232U

;       Output: 32 bit unsigned fixed point quotient in AARGB0, AARGB1,AARGB2,AARGB3
;               32 bit unsigned fixed point remainder in REMB0, REMB1, REMB2, REMB3

;       Result: AARG, REM  <--  AARG / BARG

;       Max Timing:     4+1025+2 = 1031 clks

;       Max Timing:     4+981+2 = 987 clks

;       PM: 4+359+1 = 364               DM: 13

div32u          CLRF            REMB0
                CLRF            REMB1
                CLRF            REMB2
                CLRF            REMB3

                UDIV3232L

                RETLW           0x00

PROG1           code
                global  FXD3232U
;Stub to call divide routine in PROG2 without having to set PCLATH every where
FXD3232U        movlw   high div32u     ;
                movwf   PCLATH
                call    div32u          ;
                movlw   high FXD3232U   ;
                movwf   PCLATH
                return
                end

