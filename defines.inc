;
; $Log: defines.inc,v $
; Revision 1.6  2008/05/11 13:34:49  Skip
; Added (untested) support for digital volume pot.
;
; Revision 1.5  2007/07/18 18:41:01  Skip
; 1. Added the current Squelch pot level to config info sent/received and
;    stored in EEPROM.
; 2. Added CONFIG_POT_* defines for squelch pot UF bits.
; 3. Added Srx1...Srx7 and Srxbits alias defines.
;
; Revision 1.4  2005/01/05 05:01:31  Skip Hansen
; Added COM_FLAG_BAD_DATA, B1_FLAG_RESET, B1_FLAG_NEW_DATA
;
; Revision 1.3  2004/12/31 04:28:53  Skip Hansen
; Corrected comments on CONFIG_2_5_SEL, it's active LOW.
;
; Revision 1.2  2004/12/31 00:40:12  Skip Hansen
; Added CONFIG_REMOTE_MASK, COM_FLAG_*.
;
; Revision 1.1.1.1  2004/07/03 16:38:59  Skip Hansen
; Initial import: V0.09.  Burned into first 10 boards.
;        
        ERRORLEVEL -302 ;remove messages about using proper bank

;#define SIMULATE
;#define VHF_RANGE_1
;#define VHF_RANGE_2
;#define TEST_GENERIC
;#define TEST_GENERIC7
;#define TEST_PALOMAR
;#define DEBUG_MODE_SEL

;EEPROM layout


;Adr 16 -> 19 V1 Rx switch frequency (lsb first)
#define RX_VCO_SPLIT_F  d'16'

;Adr 20 -> 23 V1 Tx switch frequency (lsb first)
#define TX_VCO_SPLIT_F  d'20'

;Adr 24 -> 39 Mode 1 (VFO) code storage
#define MODE1_ADR       d'24'

;Adr 40 -> 43 Transmit offset 
#define TX_OFFSET_ADR   d'40'

;Adr 44 -> 46 Configuration bytes
#define CONFIG_EEPROM_ADR       d'44'
#define CONFIG_BYTES            4

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

;Config0, B4, B5 - Control system type
;
#define CONFIG_CTRL_MASK 0x3    ;NB: after nibble swap!
#define CONFIG_GENERIC  0x1     ;Generic / Link Comm RLC3 / Doug Hall
#define CONFIG_CACTUS   0x2     ;Palomar / Cactus

;Config0, B7, B6 - Remote base base number when in Cactus mode
;0x00 - remote base 1 (first 3 bytes in serial stream)
;0x40 - remote base 2 (bytes 4->6 in serial stream)
;0x80 - remote base 3 (bytes 7->9 in serial stream)
;0xC0 - remote base 4 (bytes 10->12 in the serial stream)
#define CONFIG_REMOTE_MASK      0xc0

;Config0, B6 - User Function used for 8 bit squelch level in Generic mode
#define CONFIG_UF_AS_SQUELCH    0x80

;Configuration byte 1: ConfUF - User defined output port bit usages
#define CONFIG_COS_IN   0       ;b0: 0 - UF0 COS input
                                ;    1 - UF0 user output
#define CONFIG_QRP      1       ;b1: 0 - UF1 QRP power output
                                ;    1 - UF1 output
#define CONFIG_HI_PWR   2       ;b2: 0 - UF2 High power output
                                ;    1 - UF2 output

;Bits b6, b5 and b3 can optionally be used to control a 
; Microchip mcp41010 digital pot for squelch

#define CONFIG_POT_CS   3       ;b3: 0 - UF3 Digital pots CS
                                ;    1 - UF3 output
                                
#define CONFIG_POT_SCLK 4       ;b4: 0 - UF4 Digital pots SCLK
                                ;    1 - UF4 output

#define CONFIG_2_5_SEL  5       ;b5: 0 - UF5 active adds 2.5 Khz to frequency
                                ;    1 - UF5 user output

#define CONFIG_POT_SI   6       ;b6: 0 - UF6 Digital pots SI
                                ;    1 - UF6 output
                                
#define CONFIG_SQU_POT_MASK     0x58                                

;Configuration byte 2: SquelchLevel

;Configuration byte 3: VolumeLevel

;icomflags bit definitions
#define COM_FLAG_LSB1ST 0
#define COM_FLAG_TXOFF  1
#define COM_FLAG_RX_SET 2
#define COM_FLAG_TX_SET 3
#define COM_FLAG_BAD_DATA 4

;b1flags bit definitions
#define B1_FLAG_RESET   1        
#define B1_FLAG_NEW_DATA 2        

#define SERAL_DAT       PORTE,0
#define COS_DAT         PORTD,0

;bank 0 aliases for serial rx data.  Used by control system code to
;process serial data without excessive bank switching.
;NB don't change the order! Srx7 ... Srx1 must be in consecutive memory
;locations.
#define Srx7            REMB3
#define Srx6            REMB2
#define Srx5            REMB1
#define Srx4            REMB0
#define Srx3            AARGB3
#define Srx2            AARGB2
#define Srx1            AARGB1
#define Srxbits         AARGB0

