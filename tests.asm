; $Log: tests.asm,v $
; Revision 1.1  2007/07/18 18:35:25  Skip
; Initial import - test code removed from xcat.asm and in a different bank.
;
        processor       16F877a
        include <p16f877a.inc>
        include defines.inc

        extern  Config0
        extern  srx1,srx2,srx3,srx4,srx5,srx6,srx7,srxbits,srxto
        

PROG3   code
        global  tests
tests        
        ifdef   TEST_PALOMAR
        movlw   0x23            ;
        movwf   Config0         ;
        endif      
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
        
        ifdef   TEST_GENERIC
        movlw   0x13            ;
        movwf   Config0         ;
        bsf     STATUS,RP0      ;bank 1
        movlw   0xff            ;load 146.52
        movwf   srx3            ;UF
        movlw   0xc2            ;
        movwf   srx4            ;tx, rx on, low power, 2 meters
        movlw   0xa6            ;radio power on, not +5, simplex, 146
        movwf   srx5            ;
        movlw   0x52            ;.52
        movwf   srx6            ;
        movlw   0x00            ;
        movwf   srx7            ;
        movlw   d'40'           ;
        movwf   srxbits         ;
        clrf    srxto           ;clear timeout counter
        bcf     STATUS,RP0      ;bank 0
        endif
        
        ifdef   TEST_GENERIC7
        movlw   0x13            ;
        movwf   Config0         ;
        bsf     STATUS,RP0      ;bank 1
        movlw   0xff            ;load 146.52
        movwf   srx1            ;UF
        movlw   0xc2            ;
        movwf   srx2            ;tx, rx on, low power, 2 meters
        movlw   0xa6            ;radio power on, not +5, simplex, 146
        movwf   srx3            ;
        movlw   0x52            ;.52
        movwf   srx4            ;
        movlw   0x00            ;
        movwf   srx5            ;
        movlw   0x8             ;squelch level
        movwf   srx6            ;
        movlw   0x3f            ;save into memory channel 3, open squelch, scan on
        movwf   srx7            ;
        movlw   d'56'           ;
        movwf   srxbits         ;
        clrf    srxto           ;clear timeout counter
        bcf     STATUS,RP0      ;bank 0
        endif

        movlw   0x13            ;
        movwf   Config0         ;
        bsf     STATUS,RP0      ;bank 1
        movlw   0xff            ;load 146.52
        movwf   srx1            ;UF
        movlw   0xf2            ;
        movwf   srx2            ;tx, rx on, low power, 2 meters
        movlw   0xa6            ;radio power on, not +5, simplex, 146
        movwf   srx3            ;
        movlw   0x94            ;
        movwf   srx4            ;
        movlw   0x00            ;
        movwf   srx5            ;
        movlw   0x10            ;squelch level
        movwf   srx6            ;
        movlw   0x75
        movwf   srx7            ;
        movlw   d'56'           ;
        movwf   srxbits         ;
        clrf    srxto           ;clear timeout counter
        bcf     STATUS,RP0      ;bank 0
        
        return
        
        end
