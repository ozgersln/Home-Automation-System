    PROCESSOR 16F877A
    #include <xc.inc>

    ; --- CONFIGURATION AYARLARI ---
    ; HS Osilator, Watchdog Kapali, Power-up Timer Acik
    CONFIG FOSC = HS, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF

;------------------------------------------------------------------------------
; BELLEK YONETIMI VE DEGISKENLER
;------------------------------------------------------------------------------
    PSECT udata_bank0

    ; --- Ana Kontrol Degiskenleri ---
    CURR_POS:       DS 1    ; Anlik perde pozisyonu (0-100)
    GOAL_POS:       DS 1    ; Gidilmesi gereken hedef pozisyon
    LIGHT_LVL:      DS 1    ; Isik sensorunden okunan deger (LDR)
    RAW_POT:        DS 1    ; Potansiyometre ham degeri

    ; --- Motor Surucu Degiskenleri ---
    STEP_PTR:       DS 1    ; Step sirasi indeksi
    DIST_TO_GO:     DS 1    ; Hedef ile anlik arasi fark
    MICRO_STEP:     DS 1    ; %1'lik hareket icin atilacak adim sayaci
    
    ; --- Haberlesme (UART) Degiskenleri ---
    RX_BUF:         DS 1    ; Gelen veri tamponu
    UART_MODE:      DS 1    ; Iletisim durumu (0: Idle, 1: Data Wait)

    ; --- Matematiksel Islemler ---
    ACC_LO:         DS 1    ; Toplama islemi alt bayt
    ACC_HI:         DS 1    ; Toplama islemi ust bayt
    LOOP_CNT:       DS 1    ; Dongu sayaci
    AVG_VAL:        DS 1    ; Ortalama sonuc
    CALC_L:         DS 1    ; Hesaplama gecici L
    CALC_H:         DS 1    ; Hesaplama gecici H
    MATH_CTR:       DS 1    ; Carpma/Bolme sayaci
    PREV_POT:       DS 1    ; Onceki pot degeri (kararlilik icin)
    CALC_POT:       DS 1    ; Hesaplanmis yeni pot degeri
    
    ; --- Zamanlama Degiskenleri ---
    WAIT_1:         DS 1
    WAIT_2:         DS 1

    ; --- Ekran (LCD) Degiskenleri ---
    LCD_BUF:        DS 1
    DIGIT_100:      DS 1
    DIGIT_10:       DS 1
    DIGIT_1:        DS 1

    ; --- Kesme Saklama Alanlari ---
    PSECT udata_shr
    W_TEMP:         DS 1
    STATUS_TEMP:    DS 1

;==============================================================================
; BASLANGIC VEKTORU
;==============================================================================
    PSECT resetVec, class=CODE, delta=2
    GOTO    START_PROG

    ORG 0x0004
    ; --- KESME SERVIS RUTINI (ISR) ---
    ; W ve STATUS registerlarini yedekle
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP

    ; Bank 0'a zorla
    BCF     STATUS, 5
    BCF     STATUS, 6

    ; UART Kesmesi Geldi mi?
    BANKSEL PIR1
    BTFSC   PIR1, 5     ; RCIF kontrol
    CALL    ISR_UART_TASK

    ; Yede?i geri yükle ve ç?k
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE

;==============================================================================
; UART HABERLESME GOREVI (PROJE ISTERLERINE GORE REVIZE)
;==============================================================================
ISR_UART_TASK:
    BANKSEL RCREG
    MOVF    RCREG, W
    MOVWF   RX_BUF      ; Veriyi al

    ; --- GET KOMUTLARI (PC Bilgi Istiyor) ---
    ; Komut: 0x01 -> Hedef Perde (Ondalik) - Bizde yok, 0 don
    MOVF    RX_BUF, W
    XORLW   0x01
    BTFSC   STATUS, 2
    GOTO    REPLY_ZERO

    ; Komut: 0x02 -> Hedef Perde (Tam Sayi)
    MOVF    RX_BUF, W
    XORLW   0x02
    BTFSC   STATUS, 2
    GOTO    REPLY_GOAL_POS

    ; Komut: 0x08 -> Isik Siddeti (Tam Sayi)
    MOVF    RX_BUF, W
    XORLW   0x08
    BTFSC   STATUS, 2
    GOTO    REPLY_LIGHT

    ; Diger sensor sorgulari (BMP180 vs) -> 0 Don
    ; 0x03, 0x04, 0x05, 0x06...
    MOVF    RX_BUF, W
    SUBLW   0x08        ; Eger 8'den kucukse ve yukaridakiler degilse 0 yolla
    BTFSS   STATUS, 0
    GOTO    CHECK_SET_COMMANDS ; 8'den buyukse SET komutu olabilir
    GOTO    REPLY_ZERO

CHECK_SET_COMMANDS:
    ; --- SET KOMUTLARI (PC Veri Yolluyor) ---
    ; Format: 11xxxxxx -> Hedef Perdeyi Ayarla
    
    MOVF    RX_BUF, W
    ANDLW   0xC0        ; Maskele (Ust 2 bit)
    MOVWF   CALC_L
    
    ; 11xxxxxx kontrolu
    MOVF    CALC_L, W
    XORLW   0xC0
    BTFSC   STATUS, 2
    GOTO    EXECUTE_SET_POS

    RETURN

; --- Yanit Alt Programlari ---
REPLY_ZERO:
    MOVLW   0
    CALL    TX_SEND_BYTE
    RETURN

REPLY_GOAL_POS:
    MOVF    GOAL_POS, W
    CALL    TX_SEND_BYTE
    RETURN

REPLY_LIGHT:
    MOVF    LIGHT_LVL, W
    CALL    TX_SEND_BYTE
    RETURN

EXECUTE_SET_POS:
    ; Gelen verinin alt 6 bitini al ve hedefe yaz
    MOVF    RX_BUF, W
    ANDLW   0x3F
    MOVWF   GOAL_POS
    RETURN

TX_SEND_BYTE:
    BANKSEL TXSTA
    BTFSS   TXSTA, 1    ; Buffer bos mu?
    GOTO    $-1
    BANKSEL TXREG
    MOVWF   TXREG
    BANKSEL PORTB
    RETURN

;==============================================================================
; ANA PROGRAM BLOGU
;==============================================================================
START_PROG:
    ; --- Donanim Ayarlari (Bank 1) ---
    BSF     STATUS, 5
    
    CLRF    TRISB       ; PORTB Cikis (Motor)
    CLRF    TRISD       ; PORTD Cikis (LCD)
    BSF     TRISA, 0    ; RA0 Analog Giris (Pot)
    BSF     TRISA, 1    ; RA1 Analog Giris (LDR)
    
    ; UART Pinleri
    BCF     TRISC, 6    ; TX
    BSF     TRISC, 7    ; RX

    ; Analog/Dijital Ayarlari
    MOVLW   0x04        ; AN0 ve AN1 Analog, gerisi dijital
    MOVWF   ADCON1

    ; UART Hiz Ayari (9600 Baud)
    MOVLW   25
    MOVWF   SPBRG
    BSF     TXSTA, 2    ; BRGH=1
    BCF     TXSTA, 4    ; SYNC=0
    BSF     TXSTA, 5    ; TX Aktif

    ; Kesme Yetkileri
    BSF     PIE1, 5     ; RX Kesmesini ac

    ; --- Bank 0 Ayarlari ---
    BCF     STATUS, 5
    
    BSF     RCSTA, 7    ; Seri Portu Ac
    BSF     RCSTA, 4    ; Surekli alim modunu ac

    MOVLW   0x81        ; ADC Modulunu Ac (Fosc/32)
    MOVWF   ADCON0

    ; Genel Kesmeler
    BSF     INTCON, 6   ; PEIE
    BSF     INTCON, 7   ; GIE

    ; Temizlik
    CLRF    PORTB
    CLRF    PORTD
    CLRF    UART_MODE

    ; LCD'yi Hazirla
    CALL    WAIT_MS
    CALL    INIT_SCREEN
    CALL    SHOW_INTRO

SYSTEM_LOOP:
    ; 1. Adim: Potansiyometreyi Oku ve Isle
    CALL    ADC_READ_AVG
    CALL    SCALE_TO_PERCENT

    ; 2. Adim: Isik Sensorunu Kontrol Et (Guvenlik)
    CALL    CHECK_LIGHT_SENSOR

    ; 3. Adim: Motoru Hedefe Sur
    CALL    DRIVE_STEPPER

    ; 4. Adim: Ekrani Guncelle
    CALL    UPDATE_DISPLAY

    GOTO    SYSTEM_LOOP

;==============================================================================
; SENSOR VE MATEMATIK FONKSIYONLARI
;==============================================================================

ADC_READ_AVG:
    ; 32 Ornek alip ortalamasini cikaran fonksiyon
    CLRF    ACC_LO
    CLRF    ACC_HI
    MOVLW   32
    MOVWF   LOOP_CNT

SAMPLE_LOOP:
    BANKSEL ADCON0
    MOVLW   0x41        ; Kanal 0 (Pot) Sec
    MOVWF   ADCON0
    BSF     ADCON0, 2   ; Cevirimi baslat
BUSY_WAIT:
    BTFSC   ADCON0, 2
    GOTO    BUSY_WAIT

    ; Okunan degeri topla
    MOVF    ADRESH, W
    ADDWF   ACC_LO, F
    BTFSC   STATUS, 0
    INCF    ACC_HI, F
    
    DECFSZ  LOOP_CNT, F
    GOTO    SAMPLE_LOOP

    ; 32'ye bol (5 defa saga kaydir)
    MOVLW   5
    MOVWF   LOOP_CNT
SHIFT_AVG:
    BCF     STATUS, 0
    RRF     ACC_HI, F
    RRF     ACC_LO, F
    DECFSZ  LOOP_CNT, F
    GOTO    SHIFT_AVG

    MOVF    ACC_LO, W
    MOVWF   AVG_VAL
    RETURN

SCALE_TO_PERCENT:
    ; 0-255 arasi degeri 0-100 arasi yuzdeye cevirir
    CLRF    CALC_L
    CLRF    CALC_H
    
    ; Basit carpma: AVG * 25
    MOVLW   25
    MOVWF   MATH_CTR
MUL_REPEAT:
    MOVF    AVG_VAL, W
    ADDWF   CALC_L, F
    BTFSC   STATUS, 0
    INCF    CALC_H, F
    DECFSZ  MATH_CTR, F
    GOTO    MUL_REPEAT

    ; Yuvarlama ekle (+32)
    MOVLW   32
    ADDWF   CALC_L, F
    BTFSC   STATUS, 0
    INCF    CALC_H, F

    ; 64'e bol (6 kaydirma)
    MOVLW   6
    MOVWF   MATH_CTR
DIV_SHIFT:
    BCF     STATUS, 0
    RRF     CALC_H, F
    RRF     CALC_L, F
    DECFSZ  MATH_CTR, F
    GOTO    DIV_SHIFT

    MOVF    CALC_L, W
    MOVWF   CALC_POT

    ; Sinirlandirma (0-100)
    MOVF    AVG_VAL, W
    SUBLW   5
    BTFSC   STATUS, 0
    CLRF    CALC_POT    ; 5'ten kucukse 0 yap

    MOVF    CALC_POT, W
    SUBLW   100
    BTFSS   STATUS, 0
    GOTO    FIX_MAX
    GOTO    COMPARE_VAL
FIX_MAX:
    MOVLW   100
    MOVWF   CALC_POT

COMPARE_VAL:
    ; Degisim var mi kontrol et
    MOVF    CALC_POT, W
    SUBWF   PREV_POT, W
    BTFSC   STATUS, 2
    RETURN  ; Degisim yoksa cik

    ; Degisim varsa guncelle
    MOVF    CALC_POT, W
    MOVWF   GOAL_POS
    MOVWF   PREV_POT
    RETURN

CHECK_LIGHT_SENSOR:
    ; LDR Okuma ve Karar Verme
    BANKSEL ADCON0
    MOVLW   0x49        ; Kanal 1 (LDR) Sec
    MOVWF   ADCON0
    
    ; Kisa bekleme
    MOVLW   5
    MOVWF   WAIT_1
    DECFSZ  WAIT_1, F
    GOTO    $-1

    BSF     ADCON0, 2   ; Baslat
POLL_LDR:
    BTFSC   ADCON0, 2
    GOTO    POLL_LDR

    MOVF    ADRESH, W
    
    ; Filtreleme
    SUBLW   250
    BTFSS   STATUS, 0
    MOVLW   0
    MOVWF   LIGHT_LVL

    ; Esik Deger Kontrolu (87)
    MOVLW   87
    SUBWF   LIGHT_LVL, W
    BTFSS   STATUS, 0
    GOTO    FORCE_CLOSE
    RETURN

FORCE_CLOSE:
    ; Hava karanliksa perdeyi tam kapat
    MOVLW   100
    MOVWF   GOAL_POS
    MOVLW   0xFF        ; Pot kontrolunu bypass et
    MOVWF   PREV_POT
    RETURN

;==============================================================================
; MOTOR SURUCU FONKSIYONLARI
;==============================================================================

DRIVE_STEPPER:
    MOVF    GOAL_POS, W
    SUBWF   CURR_POS, W
    BTFSC   STATUS, 2
    RETURN              ; Hedefteyiz, islem yok

    ; Yon Tayini
    BTFSS   STATUS, 0
    GOTO    DIR_CLOSE   ; Curr < Goal -> Kapat
    GOTO    DIR_OPEN    ; Curr > Goal -> Ac

DIR_CLOSE:
    MOVF    CURR_POS, W
    SUBWF   GOAL_POS, W
    MOVWF   DIST_TO_GO

CYCLE_FWD:
    MOVLW   10
    MOVWF   MICRO_STEP
RUN_FWD:
    CALL    STEP_CW
    CALL    WAIT_MS
    DECFSZ  MICRO_STEP, F
    GOTO    RUN_FWD

    INCF    CURR_POS, F
    DECFSZ  DIST_TO_GO, F
    GOTO    CYCLE_FWD
    RETURN

DIR_OPEN:
    MOVF    GOAL_POS, W
    SUBWF   CURR_POS, W
    MOVWF   DIST_TO_GO

CYCLE_BCK:
    MOVLW   10
    MOVWF   MICRO_STEP
RUN_BCK:
    CALL    STEP_CCW
    CALL    WAIT_MS
    DECFSZ  MICRO_STEP, F
    GOTO    RUN_BCK

    DECF    CURR_POS, F
    DECFSZ  DIST_TO_GO, F
    GOTO    CYCLE_BCK
    RETURN

STEP_CW:
    DECF    STEP_PTR, F
    MOVLW   0x03
    ANDWF   STEP_PTR, F
    CALL    APPLY_COILS
    RETURN

STEP_CCW:
    INCF    STEP_PTR, F
    MOVLW   0x03
    ANDWF   STEP_PTR, F
    CALL    APPLY_COILS
    RETURN

APPLY_COILS:
    MOVF    STEP_PTR, W
    CALL    GET_STEP_MASK
    MOVWF   PORTB
    RETURN

GET_STEP_MASK:
    ADDWF   PCL, F
    RETLW   0x01
    RETLW   0x02
    RETLW   0x04
    RETLW   0x08

;==============================================================================
; EKRAN (LCD) YONETIMI
;==============================================================================

INIT_SCREEN:
    MOVLW   0x03
    CALL    SEND_NIBBLE
    CALL    WAIT_SHORT
    MOVLW   0x03
    CALL    SEND_NIBBLE
    CALL    WAIT_SHORT
    MOVLW   0x03
    CALL    SEND_NIBBLE
    CALL    WAIT_SHORT
    MOVLW   0x02
    CALL    SEND_NIBBLE
    CALL    WAIT_SHORT

    MOVLW   0x28        ; 4-bit Mode
    CALL    SEND_CMD
    MOVLW   0x0C        ; Display On
    CALL    SEND_CMD
    MOVLW   0x06        ; Entry Mode
    CALL    SEND_CMD
    MOVLW   0x01        ; Clear
    CALL    SEND_CMD
    CALL    WAIT_MS
    RETURN

UPDATE_DISPLAY:
    ; LDR Degeri
    MOVLW   0xC2
    CALL    SEND_CMD
    MOVF    LIGHT_LVL, W
    CALL    CONV_DECIMAL

    ; Perde Yuzdesi
    MOVLW   0xCA
    CALL    SEND_CMD
    MOVF    CURR_POS, W
    CALL    CONV_DECIMAL
    MOVLW   '%'
    CALL    SEND_DATA
    RETURN

SHOW_INTRO:
    MOVLW   0x80
    CALL    SEND_CMD
    MOVLW   'S'
    CALL    SEND_DATA
    MOVLW   'y'
    CALL    SEND_DATA
    MOVLW   's'
    CALL    SEND_DATA
    MOVLW   't'
    CALL    SEND_DATA
    MOVLW   'e'
    CALL    SEND_DATA
    MOVLW   'm'
    CALL    SEND_DATA
    
    MOVLW   0xC0
    CALL    SEND_CMD
    MOVLW   'O'
    CALL    SEND_DATA
    MOVLW   'K'
    CALL    SEND_DATA
    RETURN

CONV_DECIMAL:
    ; W registerindeki sayiyi LCD'ye basar
    MOVWF   LOOP_CNT
    CLRF    DIGIT_100
    CLRF    DIGIT_10
    CLRF    DIGIT_1
F_100:
    MOVLW   100
    SUBWF   LOOP_CNT, W
    BTFSS   STATUS, 0
    GOTO    F_10
    MOVWF   LOOP_CNT
    INCF    DIGIT_100, F
    GOTO    F_100
F_10:
    MOVLW   10
    SUBWF   LOOP_CNT, W
    BTFSS   STATUS, 0
    GOTO    F_1
    MOVWF   LOOP_CNT
    INCF    DIGIT_10, F
    GOTO    F_10
F_1:
    MOVF    LOOP_CNT, W
    MOVWF   DIGIT_1

    ; Ekrana Bas
    MOVLW   0x30
    ADDWF   DIGIT_100, W
    CALL    SEND_DATA
    MOVLW   0x30
    ADDWF   DIGIT_10, W
    CALL    SEND_DATA
    MOVLW   0x30
    ADDWF   DIGIT_1, W
    CALL    SEND_DATA
    RETURN

SEND_CMD:
    MOVWF   LCD_BUF
    MOVF    LCD_BUF, W
    ANDLW   0xF0
    MOVWF   PORTD
    BCF     PORTD, 2    ; RS=0
    CALL    LCD_PULSE
    SWAPF   LCD_BUF, W
    ANDLW   0xF0
    MOVWF   PORTD
    BCF     PORTD, 2
    CALL    LCD_PULSE
    CALL    WAIT_SHORT
    RETURN

SEND_DATA:
    MOVWF   LCD_BUF
    MOVF    LCD_BUF, W
    ANDLW   0xF0
    MOVWF   PORTD
    BSF     PORTD, 2    ; RS=1
    CALL    LCD_PULSE
    SWAPF   LCD_BUF, W
    ANDLW   0xF0
    MOVWF   PORTD
    BSF     PORTD, 2
    CALL    LCD_PULSE
    CALL    WAIT_SHORT
    RETURN

SEND_NIBBLE:
    MOVWF   LCD_BUF
    SWAPF   LCD_BUF, W
    ANDLW   0xF0
    MOVWF   PORTD
    BCF     PORTD, 2
    CALL    LCD_PULSE
    RETURN

LCD_PULSE:
    BSF     PORTD, 3    ; EN=1
    NOP
    BCF     PORTD, 3    ; EN=0
    RETURN

WAIT_MS:
    MOVLW   5
    MOVWF   WAIT_1
L_OUT:
    MOVLW   200
    MOVWF   WAIT_2
L_IN:
    DECFSZ  WAIT_2, F
    GOTO    L_IN
    DECFSZ  WAIT_1, F
    GOTO    L_OUT
    RETURN

WAIT_SHORT:
    MOVLW   5
    MOVWF   WAIT_2
    DECFSZ  WAIT_2, F
    GOTO    $-1
    RETURN

    END