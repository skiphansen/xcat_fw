;
; $Log: defines.inc,v $
; Revision 1.1  2004/07/03 16:38:59  Skip Hansen
; Initial revision
;        
        ERRORLEVEL -302 ;remove messages about using proper bank

;#define SIMULATE
;#define VHF_RANGE_1
;#define VHF_RANGE_2
;#define TEST_GENERIC


;EEPROM layout


;Adr 16 -> 19 V1 Rx switch frequency (lsb first)
#define RX_VCO_SPLIT_F  d'16'

;Adr 20 -> 23 V1 Tx switch frequency (lsb first)
#define TX_VCO_SPLIT_F  d'20'

;Adr 24 -> 39 Mode 1 (VFO) code storage
#define MODE1_ADR       d'24'

;Adr 40 -> 43 Transmit offset 
#define TX_OFFSET_ADR   d'40'

;Adr 44 -> 45 Configuration bytes
#define CONFIG_EEPROM_ADR       d'44'
#define CONFIG_BYTES            2

;Configuration byte 0 read from EEPROM on powerup

;Bottom 3 bits: radio band

#define CONFIG_BAND_MASK 7
#define CONFIG_10M      0       ;10 meter radio (only)
#define CONFIG_6M       1       ;6 meter radio (only)
#define CONFIG_10_6M    2       ;6 and 10 meter radio
#define CONFIG_2M       3       ;VHF radio
#define CONFIG_440      4       ;440 Mhz radio

;Config0, B3: 0 = don't send COS signal transistion messages
;             1 = send COS signal transistion messages
#define CONFIG_COS_MSG  3

;Config0, B4, B5, B6 - Control system type
;
#define CONFIG_CTRL_MASK 0x3    ;NB: after nibble swap!
#define CONFIG_GENERIC  0x1     ;Generic / Link Comm RLC3 / Doug Hall
#define CONFIG_CACTUS   0x2     ;Palomar / Cactus


;Config1 - User defined output port bit usages
#define CONFIG_COS_IN   0       ;b0: 0 - UF1 COS input
                                ;    1 - UF1 user output
#define CONFIG_QRP      1       ;b1: 0 - UF2 QRP power output
                                ;    1 - UF2 output
#define CONFIG_HI_PWR   2       ;b2: 0 - UF3 High power output
                                ;    1 - UF3 output

#define CONFIG_2_5_SEL  5       ;b5: 0 - UF6 user output
                                ;    1 - UF6 active adds 2.5 Khz to frequency
                                                                

#define SERAL_DAT       PORTE,0
#define COS_DAT         PORTD,0
