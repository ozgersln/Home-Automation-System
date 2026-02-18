PROCESSOR 16F877A
    #include <xc.inc>

; --- MICROCONTROLLER CONFIGURATION ---
; HS Oscillator enabled, Watchdog Timer disabled, Power-up Timer enabled,
; Code and Data Protection disabled
    CONFIG FOSC = HS, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF

;------------------------------------------------------------------------------
; ; MEMORY MAP AND VARIABLES 
;------------------------------------------------------------------------------
    PSECT udata_bank0
    
    ; ; --- 7-Segment Display Driver Data ---
    SEG_1:          DS 1    ; Hundreds  digit storage
    SEG_2:          DS 1    ; Tens  digit storage
    SEG_3:          DS 1    ; Ones / Fractional digit
    SEG_4:          DS 1    ; Symbol (C or F)
    MUX_INDEX:      DS 1    ;  Display scan order counter
    
    ; --- Timers and State Variables ---
    SEC_TICK:       DS 1    ; 1-second counter
    VIEW_STATE:     DS 1    ; 0: Ambient, 1: Setpoint, 2: Fan
    VIEW_TMR:       DS 1   ; Display change timer
    
    ; --- Input Unit (Keypad) --
    BTN_CODE:       DS 1    ; Read key value
    BTN_STAT:       DS 1    ; Key pressed flag
    IS_TYPING:      DS 1    ; Is data entry mode active?
    TYPE_STEP:      DS 1    ; Input step 
    
    ; --- Physical Values ---
    SET_TEMP:       DS 1    ; Desired temperature 
    ROOM_TEMP:      DS 1    ; Ambient temperature
    FAN_SPEED:      DS 1    ; Fan speed
    
    ; --- Temporary Buffers ---
    VAL_INT:        DS 1    ; Integer part of input value
    VAL_FRAC:       DS 1    ; Fractional part (input)
    RX_BUF:         DS 1    ; UART receive buffer
    PC_CMD_INT:     DS 1    ; Integer value received from PC
    PC_CMD_FRAC:    DS 1    ; Received fractional value from PC
    
    
    MATH_VAR:       DS 1    ; Temporary calculation register
    TX_BUF:         DS 1    ; Data transmission buffer
    WAIT_A:         DS 1    ; Delay loop counter 1 (previously D1)
    WAIT_B:         DS 1    ; Delay counter 2 (former D2)
    DEBOUNCE_T:     DS 1    ; Debounce counter (former SCAN_D)
    LUT_PTR:        DS 1    

   
    PSECT udata_shr
    W_SAVE:         DS 1    ; W register backup
    ST_SAVE:        DS 1    ; STATUS register backup


    PSECT resetVec, class=CODE, delta=2
    GOTO    INIT_SYSTEM

    ORG 0x0004
   ; --- INTERRUPT SERVICE ROUTINE (ISR) ---
   ; Save processor state
    MOVWF   W_SAVE
    SWAPF   STATUS, W
    MOVWF   ST_SAVE
    
    BCF     STATUS, 5       ; Bank 0
    BCF     STATUS, 6

    ; 1. Serial communication (UART) handling
    BANKSEL PIR1
    BTFSC   PIR1, 5         ; Is RCIF set?
    CALL    ISR_UART_TASK

    ; 2. Display scanning (Timer1)
    BANKSEL PIR1
    BTFSS   PIR1, 0         ; Is TMR1IF set ?
    GOTO    EXIT_ISR
    
    BCF     PIR1, 0         ; Clean Flag
    
    ; Reload Timer1 (4 ms scanning rate)
    MOVLW   0xF0
    MOVWF   TMR1H
    MOVLW   0x00
    MOVWF   TMR1L
    
    CALL    UPDATE_7SEG     ; Enable the next display digit
    
   ; 1-second counter
    INCF    SEC_TICK, F
    MOVF    SEC_TICK, W
    SUBLW   250             ; 250 x 4ms = 1000ms
    BTFSS   STATUS, 0
    GOTO    ONE_SEC_TASK
    GOTO    EXIT_ISR

ONE_SEC_TASK:
    CLRF    SEC_TICK
    ; Giris yapiliyorsa ekran degismesin
    BTFSC   IS_TYPING, 0
    GOTO    EXIT_ISR

   ; Change display mode (Ambient -> Target -> Fan)
    INCF    VIEW_TMR, F
    BTFSS   VIEW_TMR, 1     ; Change every 2 seconds
    GOTO    EXIT_ISR
    CLRF    VIEW_TMR
    INCF    VIEW_STATE, F
    MOVF    VIEW_STATE, W
    SUBLW   3
    BTFSC   STATUS, 2       ; Reset if value reaches 3
    CLRF    VIEW_STATE
    
EXIT_ISR:
    
    SWAPF   ST_SAVE, W
    MOVWF   STATUS
    SWAPF   W_SAVE, F
    SWAPF   W_SAVE, W
    RETFIE

;==============================================================================
; ; UART Communication Subroutines
;==============================================================================
ISR_UART_TASK:
    BANKSEL RCREG
    MOVF    RCREG, W
    MOVWF   RX_BUF

   ; Decode received command
    MOVF    RX_BUF, W
    XORLW   0x01
    BTFSC   STATUS, 2
    GOTO    TX_TARGET_FRAC

    MOVF    RX_BUF, W
    XORLW   0x02
    BTFSC   STATUS, 2
    GOTO    TX_TARGET_INT
    
    MOVF    RX_BUF, W
    XORLW   0x04
    BTFSC   STATUS, 2
    GOTO    TX_ROOM_INT

    MOVF    RX_BUF, W
    XORLW   0x05
    BTFSC   STATUS, 2
    GOTO    TX_FAN_RPM

    ; SET commands (checked using bit masking)
    MOVF    RX_BUF, W
    ANDLW   0xC0
    XORLW   0xC0            ; 11xxxxxx format?
    BTFSC   STATUS, 2
    GOTO    RX_SET_TARGET
    
    GOTO    ISR_UART_END


TX_TARGET_FRAC:
    MOVLW   0
    BTFSC   SET_TEMP, 0     ; LSB chech (0.5 ?)
    MOVLW   5
    CALL    UART_SEND
    GOTO    ISR_UART_END

TX_TARGET_INT:
    MOVF    SET_TEMP, W
    MOVWF   MATH_VAR
    BCF     STATUS, 0
    RRF     MATH_VAR, F     ; Divide 2
    MOVF    MATH_VAR, W
    CALL    UART_SEND
    GOTO    ISR_UART_END

TX_ROOM_INT:
    MOVF    ROOM_TEMP, W
    MOVWF   MATH_VAR
    BCF     STATUS, 0
    RRF     MATH_VAR, F
    MOVF    MATH_VAR, W
    CALL    UART_SEND
    GOTO    ISR_UART_END

TX_FAN_RPM:
    MOVF    FAN_SPEED, W
    CALL    UART_SEND
    GOTO    ISR_UART_END

RX_SET_TARGET:
    MOVF    RX_BUF, W
    ANDLW   0x3F            ; Extract data
    MOVWF   PC_CMD_INT
    GOTO    APPLY_PC_TARGET

APPLY_PC_TARGET:
    MOVF    PC_CMD_INT, W
    MOVWF   SET_TEMP
    BCF     STATUS, 0
    RLF     SET_TEMP, F     ; Multiply by 2 (scaling)
    GOTO    ISR_UART_END

UART_SEND:
    MOVWF   TX_BUF
    BANKSEL TXSTA
WAIT_TX:
    BTFSS   TXSTA, 1        ; Is TRMT empty?
    GOTO    WAIT_TX
    BANKSEL TXREG
    MOVF    TX_BUF, W
    MOVWF   TXREG
    BANKSEL PORTB
    RETURN  

ISR_UART_END:
    RETURN

;==============================================================================
; ; SYSTEM INITIALIZATION
;==============================================================================
INIT_SYSTEM:
    ; Bank 1 Settings
    BSF     STATUS, 5
    CLRF    TRISD           ; PortD Output (Segment Data)
    CLRF    TRISC           ; PortC Input (Digit Select)
    MOVLW   0xF0            ; RB4-7 Output (Keypad Col), RB0-3 Cikis
    MOVWF   TRISB
    MOVLW   0x11            ; RA0 Analog, RA4 Input
    MOVWF   TRISA
    
    ; UART Configuration (9600 Baud Rate)
    MOVLW   25
    MOVWF   SPBRG
    BSF     TXSTA, 2        ; BRGH High Speed
    BCF     TXSTA, 4        ; Asenkron
    BSF     TXSTA, 5        ; TX active
    
    ; Interrupt
    BSF     PIE1, 0         ; Timer1 Interrupt
    BSF     PIE1, 5         ; RX Interrupt
    
    ; Analog Settings
    MOVLW   0x8E            ; AN0 Analog
    MOVWF   ADCON1
    MOVLW   0x28            ; Timer0 Settings
    MOVWF   OPTION_REG
    
    ; Bank 0 Settings
    BCF     STATUS, 5
    BSF     RCSTA, 7        ; SPEN Open
    BSF     RCSTA, 4        ; CREN Open
    
    MOVLW   0x01            ; Start Timer1
    MOVWF   T1CON
    
    BSF     INTCON, 6       ; PEIE
    BSF     INTCON, 7       ; GIE (Global Interrupt)
    
    MOVLW   0x81            ; ADC Mod On
    MOVWF   ADCON0
    
    ; Clean Port 
    CLRF    PORTD
    CLRF    PORTC
    CLRF    PORTB
    
    ; Keypad 
    BSF     PORTA, 1
    BSF     PORTA, 2
    BSF     PORTA, 3
    BSF     PORTA, 5
    
    
    MOVLW   50             
    MOVWF   SET_TEMP
    CLRF    IS_TYPING
    CLRF    BTN_STAT
    CLRF    VIEW_STATE
    CLRF    FAN_SPEED

;==============================================================================
; Main Looop
;==============================================================================
OP_LOOP:
    ; 1. Input check
    CALL    READ_MATRIX
    MOVF    BTN_STAT, F
    BTFSS   STATUS, 2       ; Is a key pressed?
    CALL    HANDLE_INPUT
    
    ; 2. Mode check (pause system during data entry)
    BTFSC   IS_TYPING, 0
    GOTO    PAUSE_SYS
    
    ; 3. System control logic
    CALL    ADC_GET_VAL     ; Read temperature
    CALL    PREP_UI_DATA    ; Prepare display
    CALL    MANAGE_HVAC     ;  Air conditioner / fan control
    
PAUSE_SYS:
    CALL    WAIT_MS         ; Gecikme
    CLRF    BTN_STAT        ; ; Clear key flag
    
    ; Debounce 
CHECK_RELEASE:
    MOVF    PORTB, W
    ANDLW   0xF0
    XORLW   0xF0
    BTFSS   STATUS, 2
    GOTO    CHECK_RELEASE
    GOTO    OP_LOOP

============================================================================
ADC_GET_VAL:
    BSF     ADCON0, 2      
WAIT_CONV:
    BTFSC   ADCON0, 2       ; wait untill stop
    GOTO    WAIT_CONV
    BANKSEL ADRESL
    MOVF    ADRESL, W
    BANKSEL PORTB
    MOVWF   ROOM_TEMP       ; save the value
    RETURN

PREP_UI_DATA:
    ; Display data according to current mode
    MOVF    VIEW_STATE, W
    SUBLW   0
    BTFSC   STATUS, 2
    GOTO    UI_ROOM
    MOVF    VIEW_STATE, W
    SUBLW   1
    BTFSC   STATUS, 2
    GOTO    UI_TARGET
    GOTO    UI_FAN

UI_ROOM:
    MOVF    ROOM_TEMP, W
    CALL    BIN_TO_BCD
    MOVLW   0x3F            ; '0'
    BTFSC   ROOM_TEMP, 0    ; Bucuklu mu?
    MOVLW   0x6D            ; '5'
    MOVWF   SEG_3
    MOVLW   0x39            ; 'C'
    MOVWF   SEG_4
    RETURN

UI_TARGET:
    MOVF    SET_TEMP, W
    CALL    BIN_TO_BCD
    MOVLW   0x3F
    BTFSC   SET_TEMP, 0
    MOVLW   0x6D
    MOVWF   SEG_3
    MOVLW   0x63            ; Degree Sembol
    MOVWF   SEG_4
    RETURN

UI_FAN:
    MOVF    FAN_SPEED, W
    SUBLW   150
    BTFSS   STATUS, 2
    GOTO    UI_FAN_OFF
    
    ; Fan Aciksa '150 F'
    MOVLW   0x06 ; '1'
    MOVWF   SEG_1
    MOVLW   0x6D ; '5'
    MOVWF   SEG_2
    MOVLW   0x3F ; '0'
    MOVWF   SEG_3
    GOTO    UI_FAN_SYM
UI_FAN_OFF:
    CLRF    SEG_1
    CLRF    SEG_2
    MOVLW   0x3F ; '0'
    MOVWF   SEG_3
UI_FAN_SYM:
    MOVLW   0x71            ; 'F'
    MOVWF   SEG_4
    RETURN

BIN_TO_BCD:
    ; Simple BCD conversion (by dividing by 2)
    MOVWF   MATH_VAR
    BCF     STATUS, 0
    RRF     MATH_VAR, F     ; Divide 2
    CLRF    SEG_1
    CLRF    SEG_2
BCD_CALC:
    MOVF    MATH_VAR, W
    SUBLW   9
    BTFSC   STATUS, 0
    GOTO    BCD_FINISH
    MOVLW   10
    SUBWF   MATH_VAR, F
    INCF    SEG_1, F
    GOTO    BCD_CALC
BCD_FINISH:
    MOVF    MATH_VAR, W
    MOVWF   SEG_2
    
   
    MOVF    SEG_1, W
    CALL    LOOKUP_SEG
    MOVWF   SEG_1
    MOVF    SEG_2, W
    CALL    LOOKUP_SEG
    MOVWF   SEG_2
    RETURN

MANAGE_HVAC:
    ; Histeresis ve Kontrol
    MOVF    ROOM_TEMP, W
    SUBWF   SET_TEMP, W
    BTFSC   STATUS, 2       ; If it is equal
    GOTO    SYS_IDLE
    BTFSS   STATUS, 0       ;Target < Ambient (Cooling)
    GOTO    ACTIVATE_COOL
    GOTO    ACTIVATE_HEAT
ACTIVATE_HEAT:
    BCF     PORTB, 1
    BSF     PORTB, 0        ; Set heater
    CLRF    FAN_SPEED
    RETURN
ACTIVATE_COOL:
    BCF     PORTB, 0
    BSF     PORTB, 1        ; Set cooler
    MOVLW   150
    MOVWF   FAN_SPEED       ; Set fan speed
    RETURN
SYS_IDLE:
    BCF     PORTB, 0
    BCF     PORTB, 1
    CLRF    FAN_SPEED
    RETURN

HANDLE_INPUT:
    ;  (State Machine)
    ; 'A' (Start)
    MOVF    BTN_CODE, W
    XORLW   0x0A
    BTFSC   STATUS, 2
    GOTO    INIT_INPUT
    
    BTFSS   IS_TYPING, 0
    RETURN

    MOVF    TYPE_STEP, W
    XORLW   0
    BTFSC   STATUS, 2
    GOTO    STEP_TENS
    MOVF    TYPE_STEP, W
    XORLW   1
    BTFSC   STATUS, 2
    GOTO    STEP_ONES
    MOVF    TYPE_STEP, W
    XORLW   2
    BTFSC   STATUS, 2
    GOTO    STEP_DOT
    MOVF    TYPE_STEP, W
    XORLW   3
    BTFSC   STATUS, 2
    GOTO    STEP_FRAC
    MOVF    TYPE_STEP, W
    XORLW   4
    BTFSC   STATUS, 2
    GOTO    STEP_COMMIT
    RETURN

INIT_INPUT:
    BSF     IS_TYPING, 0
    CLRF    TYPE_STEP
    MOVLW   0x40            ; '-' 
    MOVWF   SEG_1
    MOVWF   SEG_2
    MOVWF   SEG_3
    MOVWF   SEG_4
    CLRF    VAL_INT
    CLRF    VAL_FRAC
    RETURN

STEP_TENS:
    MOVF    BTN_CODE, W
    SUBLW   9
    BTFSS   STATUS, 0
    RETURN
    MOVWF   VAL_INT
    CALL    LOOKUP_SEG
    MOVWF   SEG_1
    INCF    TYPE_STEP, F
    RETURN

STEP_ONES:
    MOVF    BTN_CODE, W
    SUBLW   9
    BTFSS   STATUS, 0
    RETURN
    ; VAL_INT = VAL_INT * 10 + KEY
    MOVF    VAL_INT, W
    MOVWF   MATH_VAR
    BCF     STATUS, 0
    RLF     VAL_INT, F      ; x2
    RLF     VAL_INT, F      ; x4
    ADDWF   VAL_INT, F      ; x5
    RLF     VAL_INT, F      ; x10
    MOVF    BTN_CODE, W
    ADDWF   VAL_INT, F
    
    CALL    LOOKUP_SEG
    MOVWF   SEG_2
    INCF    TYPE_STEP, F
    RETURN

STEP_DOT:
    MOVF    BTN_CODE, W
    XORLW   0x0E            ; '*' 
    BTFSS   STATUS, 2
    RETURN
    INCF    TYPE_STEP, F
    RETURN

STEP_FRAC:
    MOVF    BTN_CODE, W
    SUBLW   9
    BTFSS   STATUS, 0
    RETURN
    MOVWF   VAL_FRAC
    CALL    LOOKUP_SEG
    MOVWF   SEG_3
    INCF    TYPE_STEP, F
    RETURN

STEP_COMMIT:
    MOVF    BTN_CODE, W
    XORLW   0x0F            ; '#' 
    BTFSS   STATUS, 2
    RETURN
    
    ; Store values
    MOVF    VAL_INT, W
    MOVWF   SET_TEMP
    BCF     STATUS, 0
    RLF     SET_TEMP, F     ; x2 
    
    MOVF    VAL_FRAC, W
    SUBLW   4               ; >= 5 ?
    BTFSS   STATUS, 0
    INCF    SET_TEMP, F     ; If it is true add 0.5
    
    CLRF    IS_TYPING       
    RETURN

;==============================================================================
; ; MATRIX SCANNING (KEYPAD)
;==============================================================================
READ_MATRIX:
    CLRF    BTN_CODE
    CLRF    BTN_STAT
    
    ; Scan row 1
    BSF PORTA,1
    BSF PORTA,2
    BSF PORTA,3
    BSF PORTA,5
    CALL SHORT_DLY
    BCF PORTA,1
    CALL SHORT_DLY
    BTFSS PORTB,4
    GOTO ROW1_C1
    BTFSS PORTB,5
    GOTO ROW1_C2
    BTFSS PORTB,6
    GOTO ROW1_C3
    BTFSS PORTB,7
    GOTO ROW1_C4
    
    ; Satir 2 Tara
    BSF PORTA,1
    CALL SHORT_DLY
    BCF PORTA,2
    CALL SHORT_DLY
    BTFSS PORTB,4
    GOTO ROW2_C1
    BTFSS PORTB,5
    GOTO ROW2_C2
    BTFSS PORTB,6
    GOTO ROW2_C3
    BTFSS PORTB,7
    GOTO ROW2_C4
    
    ; Satir 3 Tara
    BSF PORTA,2
    CALL SHORT_DLY
    BCF PORTA,3
    CALL SHORT_DLY
    BTFSS PORTB,4
    GOTO ROW3_C1
    BTFSS PORTB,5
    GOTO ROW3_C2
    BTFSS PORTB,6
    GOTO ROW3_C3
    BTFSS PORTB,7
    GOTO ROW3_C4
    
    ; Satir 4 Tara
    BSF PORTA,3
    CALL SHORT_DLY
    BCF PORTA,5
    CALL SHORT_DLY
    BTFSS PORTB,4
    GOTO ROW4_C1
    BTFSS PORTB,5
    GOTO ROW4_C2
    BTFSS PORTB,6
    GOTO ROW4_C3
    BTFSS PORTB,7
    GOTO ROW4_C4
    BSF PORTA,5
    RETURN

; --- Keypad Key Mapping ---
ROW1_C1: MOVLW 1
    GOTO KEY_HIT
ROW1_C2: MOVLW 2
    GOTO KEY_HIT
ROW1_C3: MOVLW 3
    GOTO KEY_HIT
ROW1_C4: MOVLW 0x0A
    GOTO KEY_HIT
ROW2_C1: MOVLW 4
    GOTO KEY_HIT
ROW2_C2: MOVLW 5
    GOTO KEY_HIT
ROW2_C3: MOVLW 6
    GOTO KEY_HIT
ROW2_C4: MOVLW 0x0B
    GOTO KEY_HIT
ROW3_C1: MOVLW 7
    GOTO KEY_HIT
ROW3_C2: MOVLW 8
    GOTO KEY_HIT
ROW3_C3: MOVLW 9
    GOTO KEY_HIT
ROW3_C4: MOVLW 0x0C
    GOTO KEY_HIT
ROW4_C1: MOVLW 0x0E ; *
    GOTO KEY_HIT
ROW4_C2: MOVLW 0
    GOTO KEY_HIT
ROW4_C3: MOVLW 0x0F ; #
    GOTO KEY_HIT
ROW4_C4: MOVLW 0x0D
    GOTO KEY_HIT
KEY_HIT: MOVWF BTN_CODE
    BSF BTN_STAT,0
    RETURN

UPDATE_7SEG:
    CLRF PORTC
    INCF MUX_INDEX,F
    MOVF MUX_INDEX,W
    ANDLW 0x03
    MOVWF MUX_INDEX
    
    MOVF MUX_INDEX,W
    SUBLW 0
    BTFSC STATUS,2
    GOTO ACT_D1
    MOVF MUX_INDEX,W
    SUBLW 1
    BTFSC STATUS,2
    GOTO ACT_D2
    MOVF MUX_INDEX,W
    SUBLW 2
    BTFSC STATUS,2
    GOTO ACT_D3
    GOTO ACT_D4

ACT_D1:
    MOVF SEG_1,W
    MOVWF PORTD
    BSF PORTC,0
    RETURN
ACT_D2:
    MOVF SEG_2,W
    ; Enable decimal point in fan mode
    BTFSC VIEW_STATE, 1
    GOTO  SKIP_DOT
    IORLW 0x80      ; Nokta
SKIP_DOT:
    MOVWF PORTD
    BSF PORTC,1
    RETURN
ACT_D3:
    MOVF SEG_3,W
    MOVWF PORTD
    BSF PORTC,2
    RETURN
ACT_D4:
    MOVF SEG_4,W
    MOVWF PORTD
    BSF PORTC,3
    RETURN

LOOKUP_SEG:
    MOVWF LUT_PTR
    MOVF LUT_PTR,W
    XORLW 0
    BTFSC STATUS,2
    RETLW 0x3F
    MOVF LUT_PTR,W
    XORLW 1
    BTFSC STATUS,2
    RETLW 0x06
    MOVF LUT_PTR,W
    XORLW 2
    BTFSC STATUS,2
    RETLW 0x5B
    MOVF LUT_PTR,W
    XORLW 3
    BTFSC STATUS,2
    RETLW 0x4F
    MOVF LUT_PTR,W
    XORLW 4
    BTFSC STATUS,2
    RETLW 0x66
    MOVF LUT_PTR,W
    XORLW 5
    BTFSC STATUS,2
    RETLW 0x6D
    MOVF LUT_PTR,W
    XORLW 6
    BTFSC STATUS,2
    RETLW 0x7D
    MOVF LUT_PTR,W
    XORLW 7
    BTFSC STATUS,2
    RETLW 0x07
    MOVF LUT_PTR,W
    XORLW 8
    BTFSC STATUS,2
    RETLW 0x7F
    MOVF LUT_PTR,W
    XORLW 9
    BTFSC STATUS,2
    RETLW 0x6F
    RETLW 0x40

WAIT_MS:
    MOVLW 250
    MOVWF WAIT_A
L_O: MOVLW 250
    MOVWF WAIT_B
L_I: DECFSZ WAIT_B,F
    GOTO L_I
    DECFSZ WAIT_A,F
    GOTO L_O
    RETURN

SHORT_DLY:
    MOVLW 100
    MOVWF DEBOUNCE_T
    NOP
    DECFSZ DEBOUNCE_T,F
    GOTO $-2
    RETURN

    END