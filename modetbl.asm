;
; $Log: modetbl.asm,v $
; Revision 1.1  2004/07/03 16:38:59  Skip Hansen
; Initial revision
;        
        processor       16F877A
        extern  vfo0,vfo1,vfo2,vfo3,vfo4,vfo5,vfo6,vfo7
        extern  vfo8,vfo9,vfoa,vfob,vfoc,vfod,vfoe,vfof
MODE1   code

        global  mode_1
mode_1
        goto    vfo0    ;
        goto    vfo1    ;
        goto    vfo2    ;
        goto    vfo3    ;
        goto    vfo4    ;
        goto    vfo5    ;
        goto    vfo6    ;
        goto    vfo7    ;
        goto    vfo8    ;
        goto    vfo9    ;
        goto    vfoa    ;
        goto    vfob    ;
        goto    vfoc    ;
        goto    vfod    ;
        goto    vfoe    ;
        goto    vfof    ;

        global  mode_2
mode_2
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_3
mode_3
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_4
mode_4
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_5
mode_5
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_6
mode_6
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_7
mode_7
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_8
mode_8
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_9
mode_9
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_10
mode_10
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_11
mode_11
        retlw   0xff
        retlw   0xc0
        retlw   0xff
        retlw   0xff
        retlw   0xf1
        retlw   0xb8
        retlw   0x1b
        retlw   0xa8
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x66
        retlw   0x87
        retlw   0xb8
        retlw   0x34

        global  mode_12
mode_12
        retlw   0xff
        retlw   0xc0
        retlw   0xff
        retlw   0xff
        retlw   0xf1
        retlw   0xb8
        retlw   0x1b
        retlw   0xa8
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xdc
        retlw   0x9a
        retlw   0xff

        global  mode_13
mode_13
        retlw   0xff
        retlw   0xc0
        retlw   0xff
        retlw   0xff
        retlw   0xf1
        retlw   0xb8
        retlw   0x1b
        retlw   0xa8
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xd9
        retlw   0x65
        retlw   0xdc
        retlw   0xde
        retlw   0xee

        global  mode_14
mode_14
        retlw   0xff
        retlw   0xc0
        retlw   0xff
        retlw   0xff
        retlw   0xf1
        retlw   0xb8
        retlw   0x1b
        retlw   0xa8
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xea
        retlw   0x65
        retlw   0xed
        retlw   0x56
        retlw   0xcc

        global  mode_15
mode_15
        retlw   0xff
        retlw   0xc0
        retlw   0xff
        retlw   0xff
        retlw   0xf1
        retlw   0xb8
        retlw   0x1b
        retlw   0xa8
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xed
        retlw   0x9a
        retlw   0xbb

        global  mode_16
mode_16
        retlw   0xff
        retlw   0xc0
        retlw   0xff
        retlw   0xff
        retlw   0xf1
        retlw   0xb8
        retlw   0x1b
        retlw   0xa8
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xea
        retlw   0x66
        retlw   0x87
        retlw   0x74
        retlw   0x45
MODE2   code

        global  mode_17
mode_17
        retlw   0xff
        retlw   0xc0
        retlw   0x4c
        retlw   0x7
        retlw   0xff
        retlw   0xdf
        retlw   0xff
        retlw   0xdf
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xda
        retlw   0x65
        retlw   0x69
        retlw   0xf7
        retlw   0xc9

        global  mode_18
mode_18
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xff
        retlw   0xdf
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xda
        retlw   0x76
        retlw   0x13
        retlw   0x19
        retlw   0x74

        global  mode_19
mode_19
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xcb
        retlw   0xab
        retlw   0x44

        global  mode_20
mode_20
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0x5e
        retlw   0xb6
        retlw   0x62
        retlw   0x9f
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xcb
        retlw   0xab
        retlw   0x44

        global  mode_21
mode_21
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_22
mode_22
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_23
mode_23
        retlw   0xff
        retlw   0xff
        retlw   0xfc
        retlw   0xff
        retlw   0x5e
        retlw   0xb6
        retlw   0x62
        retlw   0x9f
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x76
        retlw   0x21
        retlw   0x89
        retlw   0xbb

        global  mode_24
mode_24
        retlw   0xff
        retlw   0xff
        retlw   0xfc
        retlw   0xff
        retlw   0xf1
        retlw   0xb8
        retlw   0x1b
        retlw   0xa8
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xea
        retlw   0x66
        retlw   0x87
        retlw   0x74
        retlw   0x34

        global  mode_25
mode_25
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0x7
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xd9
        retlw   0x66
        retlw   0x76
        retlw   0xfc
        retlw   0x23

        global  mode_26
mode_26
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0x7
        retlw   0x5e
        retlw   0xb6
        retlw   0x62
        retlw   0x9f
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xd9
        retlw   0x76
        retlw   0x32
        retlw   0xcd
        retlw   0x77

        global  mode_27
mode_27
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0x7
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xdc
        retlw   0xab
        retlw   0x0

        global  mode_28
mode_28
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xf
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xea
        retlw   0x66
        retlw   0x76
        retlw   0x74
        retlw   0x89

        global  mode_29
mode_29
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xf7
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xd9
        retlw   0x65
        retlw   0xba
        retlw   0xef
        retlw   0x77

        global  mode_30
mode_30
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0x8b
        retlw   0xb9
        retlw   0x22
        retlw   0xaa
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x76
        retlw   0x43
        retlw   0x89
        retlw   0x44

        global  mode_31
mode_31
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x65
        retlw   0xba
        retlw   0xab
        retlw   0x88

        global  mode_32
mode_32
        retlw   0xff
        retlw   0xff
        retlw   0xff
        retlw   0xfd
        retlw   0xb3
        retlw   0xb6
        retlw   0x81
        retlw   0xa0
        retlw   0xff
        retlw   0x5f
        retlw   0x9f
        retlw   0xfb
        retlw   0x76
        retlw   0x43
        retlw   0x89
        retlw   0x44
        end
