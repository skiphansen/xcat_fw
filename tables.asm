;First entry PL frequency * 10
;Second entry byte 5 in msb, byte 4 in lsb
;Third entry byte 7 in msb, byte 6 in lsb
;note "MPL Operator select" bit is *not* in the table
;Ordered by Comm Spec PL number
;
; $Log: tables.asm,v $
; Revision 1.2  2005/01/05 05:02:17  Skip Hansen
; Added GetBaudRate, GetCIVAdr.
;
; Revision 1.1.1.1  2004/07/03 16:38:59  Skip Hansen
; Initial import: V0.09.  Burned into first 10 boards.
;
;
PL_TBL  code
        global  GetBaudRate
GetBaudRate
        retlw   0x4             ;19200
        
        global  GetCIVAdr       ;
GetCIVAdr
        retlw   0x20            ;
;2 words of padding
        retlw   0x00            ;
        retlw   0x20            ;
        
        global  pltable
pltable
        data    d'670'  ;1
        data    0x3b45  ;Tx code
        data    0x2ffd  ;Rx code
        data    d'719'  ;2
        data    0x3aec
        data    0x2ed1
        data    d'744'  ;3
        data    0x3abf
        data    0x2e38
        data    d'770'  ;4
        data    0x3a90
        data    0x2d99
        data    d'797'  ;5
        data    0x3a5f
        data    0x2cf4
        data    d'825'  ;6
        data    0x3a2d
        data    0x2c48
        data    d'854'  ;7
        data    0x39f9
        data    0x2b97
        data    d'885'  ;8
        data    0x39c1
        data    0x2ad9
        data    d'915'  ;9
        data    0x398a
        data    0x2a22
        data    d'948'  ;10
        data    0x394f
        data    0x2958
        data    d'974'  ;11
        data    0x3920
        data    0x28b9
        data    d'1000' ;12
        data    0x38f1
        data    0x281a
        data    d'1035' ;13
        data    0x38b2
        data    0x2744
        data    d'1072' ;14
        data    0x386f
        data    0x2662
        data    d'1109' ;15
        data    0x382c
        data    0x257f
        data    d'1148' ;16
        data    0x37e6
        data    0x2491
        data    d'1188' ;17
        data    0x379d
        data    0x239c
        data    d'1230' ;18
        data    0x3751
        data    0x229b
        data    d'1273' ;19
        data    0x3704
        data    0x2194
        data    d'1318' ;20
        data    0x36b2
        data    0x2081
        data    d'1365' ;21
        data    0x365e
        data    0x1f61
        data    d'1413' ;22
        data    0x3607
        data    0x1e3c
        data    d'1462' ;23
        data    0x35ae
        data    0x1d10
        data    d'1514' ;24
        data    0x3550
        data    0x1bd2
        data    d'1567' ;25
        data    0x34f1
        data    0x1a8e
        data    d'1622' ;26
        data    0x348d
        data    0x193d
        data    d'1679' ;27
        data    0x3426
        data    0x17e1
        data    d'1738' ;28
        data    0x33bc
        data    0x1678
        data    d'1799' ;29
        data    0x334e
        data    0x1503
        data    d'1862' ;30
        data    0x32dc
        data    0x1381
        data    d'1928' ;31
        data    0x3265
        data    0x11ed
        data    d'2035' ;32
        data    0x31a3
        data    0xf5f
        data    d'2107' ;33
        data    0x3121
        data    0xda6
        data    d'2181' ;34
        data    0x309c
        data    0xbe2
        data    d'2257' ;35
        data    0x3012
        data    0xa11
        data    d'2336' ;36
        data    0x2f84
        data    0x82e
        data    d'2418' ;37
        data    0x2ef0
        data    0x638
        data    d'2503' ;38
        data    0x2e56
        data    0x430
        data    d'2541' ;39
        data    0x2e12
        data    0x348
        data    d'693'  ;40
        data    0x3b1b
        data    0x2f70
        data    d'1598' ;41
        data    0x34b9
        data    0x19d0
        data    d'1655' ;42
        data    0x3452
        data    0x1873
        data    d'1713' ;43
        data    0x33e9
        data    0x1711
        data    d'1773' ;44
        data    0x337d
        data    0x15a2
        data    d'1835' ;45
        data    0x330d
        data    0x1426
        data    d'1899' ;46
        data    0x3299
        data    0x129f
        data    d'1966' ;47
        data    0x3220
        data    0x1105
        data    d'1995' ;48
        data    0x31ec
        data    0x1054
        data    d'2065' ;49
        data    0x316d
        data    0xea7
        data    d'2291' ;50
        data    0x2fd5
        data    0x941
        data    0               ;end of table

;
;band limit table
;
        ;10 meters 28.0 -> 29.7 Mhz
        ;6 meters 50 -> 54 Mhz
        ;2 meter 144 -> 148 Mhz
        ;70 cm 440 -> 450 Mhz
        
        ;28.0 Mhz = 01 AB 3F 00
        global  limits10m
limits10m
        data    0
        data    0x3f
        data    0xab
        data    1
        
        ;29.7 Mhz = 1 C5 2F A0
        data    0xa0
        data    0x2f
        data    0xc5
        data    1
        
        ;50 Mhz = 2 FA F0 80
        global  limits6m
limits6m
        data    0x80
        data    0xf0
        data    0xfa
        data    2
        
        ;54 Mhz = 3 37 F9 80
        data    0x80
        data    0xf9
        data    0x37
        data    3
        
        ;144 Mhz = 8 95 44 00
        global  limits2m
limits2m
        data    0x00
        data    0x44
        data    0x95
        data    8
        
        ;148 Mhz = 8 D2 4D 00
        data    0
        data    0x4d
        data    0xd2
        data    8
        
        ;440 Mhz = 1A 39 DE 00
        global  limits440
limits440
        data    0
        data    0xde
        data    0x39
        data    0x1a
        
        ;450 Mhz = 1A D2 74 80
        data    0x80
        data    0x74
        data    0xd2
        data    0x1a

        end

