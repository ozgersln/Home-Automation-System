import sys
from PySide6.QtWidgets import *
from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QFont
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# =============================================================================
# BÖLÜM 1: BACKEND API ENTEGRASYONU
# Not: HomeAutoAPI.py dosyasi ayni klasorde olmali!
# =============================================================================
try:
    from HomeAutoAPI import AirConditionerSystemConnection, CurtainControlSystemConnection
except ImportError:
    print("HATA: 'HomeAutoAPI.py' dosyasi bulunamadi!")
    sys.exit(1)

# --- PORT AYARLARI (Kendi bilgisayarina gore burayi duzenle) ---
AC_PORT = "COM2"       # Board #1 (Klima) Portu
CURTAIN_PORT = "COM4"  # Board #2 (Perde) Portu

# =============================================================================
# BÖLÜM 2: FRONTEND GUI (NEON TASARIM)
# =============================================================================

NEON_STYLE = """
QWidget {
    background-color: #0b0f1a;
    color: #00fff0;
    font-family: Consolas, 'Segoe UI';
}
QGroupBox {
    border: 2px solid #00fff0;
    border-radius: 5px;
    margin-top: 20px;
    font-weight: bold;
    color: #00fff0;
}
QPushButton {
    background-color: #111827;
    border: 2px solid #00fff0;
    border-radius: 10px;
    padding: 10px;
    font-size: 14px;
    font-weight: bold;
}
QPushButton:hover {
    background-color: #00fff0;
    color: #0b0f1a;
}
QLineEdit {
    background-color: #111827;
    border: 2px solid #ff00ff;
    border-radius: 5px;
    padding: 5px;
    color: #ffffff;
    font-size: 14px;
}
QMessageBox { background-color: #0b0f1a; }
QMessageBox QLabel { color: #ffffff; }
"""

class MainMenu(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("SMART HOME CONTROL SYSTEM")
        self.setFixedSize(600, 450)
        self.setStyleSheet(NEON_STYLE)

        # Baglanti Nesnelerini Baslat [R2.3-1 UML Yapisi]
        self.ac_system = AirConditionerSystemConnection()
        self.curtain_system = CurtainControlSystemConnection()
        
        # Portlari Ata
        self.ac_system.setComPort(AC_PORT)
        self.curtain_system.setComPort(CURTAIN_PORT)

        # Baglantilari Ac
        print("[SYSTEM] Baglantilar baslatiliyor...")
        if not self.ac_system.open():
            QMessageBox.warning(self, "Baglanti Hatasi", f"Klima Portu ({AC_PORT}) acilamadi!")
        
        if not self.curtain_system.open():
            QMessageBox.warning(self, "Baglanti Hatasi", f"Perde Portu ({CURTAIN_PORT}) acilamadi!")

        self.initUI()

    def initUI(self):
        layout = QVBoxLayout()
        layout.setSpacing(20)
        layout.setContentsMargins(50, 50, 50, 50)

        title = QLabel("HOME AUTOMATION SYSTEM")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("font-size:26px; font-weight:bold; color: #00fff0; margin-bottom:10px;")
        layout.addWidget(title)
        
        status_label = QLabel(f"Connected Ports: {AC_PORT} & {CURTAIN_PORT}")
        status_label.setAlignment(Qt.AlignCenter)
        status_label.setStyleSheet("color: #888888; font-size: 12px;")
        layout.addWidget(status_label)

        btn_ac = QPushButton("1. AIR CONDITIONER SYSTEM")
        btn_curtain = QPushButton("2. CURTAIN & SENSOR SYSTEM")
        btn_exit = QPushButton("3. EXIT APPLICATION")

        btn_ac.clicked.connect(self.open_ac)
        btn_curtain.clicked.connect(self.open_curtain)
        btn_exit.clicked.connect(self.close_app)

        layout.addWidget(btn_ac)
        layout.addWidget(btn_curtain)
        layout.addWidget(btn_exit)
        layout.addStretch()
        self.setLayout(layout)

    def open_ac(self):
        self.ac_ui = AirConditionerUI(self.ac_system)
        self.ac_ui.show()

    def open_curtain(self):
        # Klima nesnesini de gonderiyoruz ki ic sicakligi oradan ceksin (Senkronizasyon)
        self.curtain_ui = CurtainUI(self.curtain_system, self.ac_system)
        self.curtain_ui.show()
        
    def close_app(self):
        self.ac_system.close()
        self.curtain_system.close()
        self.close()

class AirConditionerUI(QWidget):
    def __init__(self, system_instance):
        super().__init__()
        self.setWindowTitle("KLİMA KONTROL PANELİ")
        self.setFixedSize(500, 500)
        self.setStyleSheet(NEON_STYLE)

        self.api = system_instance

        # Veri Guncelleme Zamanlayicisi (500ms)
        self.timer = QTimer()
        self.timer.timeout.connect(self.refresh_display)
        self.timer.start(500)

        main_layout = QVBoxLayout()
        
        # --- DURUM BILGILERI ---
        info_group = QGroupBox("SYSTEM STATUS")
        info_layout = QVBoxLayout()
        
        self.lbl_ambient = QLabel("Home Ambient Temperature: -- °C")
        self.lbl_desired = QLabel("Home Desired Temperature: -- °C")
        self.lbl_fan = QLabel("Fan Speed: -- rps")
        self.lbl_conn = QLabel(f"Active Port: {self.api.comPort}")
        self.lbl_conn.setStyleSheet("color: #555555; font-size:10px;")

        for lbl in [self.lbl_ambient, self.lbl_desired, self.lbl_fan]:
            lbl.setStyleSheet("font-size: 16px; margin: 4px;")

        info_layout.addWidget(self.lbl_ambient)
        info_layout.addWidget(self.lbl_desired)
        info_layout.addWidget(self.lbl_fan)
        info_layout.addWidget(self.lbl_conn)
        info_group.setLayout(info_layout)
        main_layout.addWidget(info_group)

        # --- KONTROL MENU ---
        control_group = QGroupBox("CONTROL MENU")
        control_layout = QVBoxLayout()
        input_layout = QHBoxLayout()
        
        input_label = QLabel("Enter Desired Temp:")
        self.temp_input = QLineEdit()
        self.temp_input.setPlaceholderText("10.0 - 50.0")
        
        input_layout.addWidget(input_label)
        input_layout.addWidget(self.temp_input)

        btn_set = QPushButton("SET TEMPERATURE")
        btn_set.clicked.connect(self.set_temperature)
        btn_return = QPushButton("ANA MENÜYE DÖN")
        btn_return.clicked.connect(self.close)

        control_layout.addLayout(input_layout)
        control_layout.addWidget(btn_set)
        control_layout.addWidget(btn_return)
        control_group.setLayout(control_layout)
        main_layout.addWidget(control_group)

        self.setLayout(main_layout)
        
        # Pencere acilir acilmaz ilk veriyi cek
        self.refresh_display()

    def refresh_display(self):
        # 1. UART uzerinden yeni verileri cek [R2.1.4-1]
        self.api.update()
        
        # 2. GUI etiketlerini guncelle [R2.4-1]
        self.lbl_ambient.setText(f"Home Ambient Temperature: {self.api.getAmbientTemp()} °C")
        self.lbl_desired.setText(f"Home Desired Temperature: {self.api.getDesiredTemp()} °C")
        self.lbl_fan.setText(f"Fan Speed: {self.api.getFanSpeed()} rps")

    def set_temperature(self):
        text = self.temp_input.text()
        try:
            val = float(text)
            # Board kodundaki sinirlar (10-50)
            if 10.0 <= val <= 50.0:
                if self.api.setDesiredTemp(val):
                    QMessageBox.information(self, "Basarili", f"Sicaklik ayarlandi: {val} °C")
                    self.temp_input.clear()
                    # Anlik guncelleme icin
                    self.lbl_desired.setText(f"Home Desired Temperature: {val} °C")
                else:
                    QMessageBox.critical(self, "Hata", "Veri gonderilemedi! Baglantiyi kontrol edin.")
            else:
                QMessageBox.warning(self, "Aralik Hatasi", "Sicaklik 10.0 ile 50.0 arasinda olmalidir!")
        except ValueError:
            QMessageBox.warning(self, "Giris Hatasi", "Lutfen gecerli bir sayi girin!")

class CurtainUI(QWidget):
    def __init__(self, curtain_system, ac_system_ref):
        super().__init__()
        self.setWindowTitle("PERDE VE SENSÖR PANELİ")
        self.setFixedSize(500, 600)
        self.setStyleSheet(NEON_STYLE)

        self.api = curtain_system
        self.ac_api = ac_system_ref # Klima sisteminden veri cekmek icin

        # Veri Guncelleme Zamanlayicisi (500ms)
        self.timer = QTimer()
        self.timer.timeout.connect(self.refresh_display)
        self.timer.start(500)

        main_layout = QVBoxLayout()
        
        # --- ORTAM BILGILERI ---
        info_group = QGroupBox("ENVIRONMENT STATUS")
        info_layout = QVBoxLayout()

        self.lbl_outdoor = QLabel("Outdoor Temperature: -- °C")
        self.lbl_indoor = QLabel("Indoor Temperature: -- °C") # Klimadan gelecek
        self.lbl_pressure = QLabel("Outdoor Pressure: -- hPa")
        self.lbl_curtain = QLabel("Curtain Status: -- %")
        self.lbl_light = QLabel("Light Intensity: -- Lux")
        self.lbl_conn = QLabel(f"Active Port: {self.api.comPort}")
        self.lbl_conn.setStyleSheet("color: #555555; font-size:10px;")

        for lbl in [self.lbl_outdoor, self.lbl_indoor, self.lbl_pressure, self.lbl_curtain, self.lbl_light]:
            lbl.setStyleSheet("font-size: 16px; margin: 4px;")

        info_layout.addWidget(self.lbl_outdoor)
        info_layout.addWidget(self.lbl_indoor)
        info_layout.addWidget(self.lbl_pressure)
        info_layout.addWidget(self.lbl_curtain)
        info_layout.addWidget(self.lbl_light)
        info_layout.addWidget(self.lbl_conn)
        info_group.setLayout(info_layout)
        main_layout.addWidget(info_group)

        # --- KONTROL MENU ---
        control_group = QGroupBox("CONTROL MENU")
        control_layout = QVBoxLayout()
        input_layout = QHBoxLayout()

        input_label = QLabel("Enter Desired Curtain %:")
        self.curtain_input = QLineEdit()
        self.curtain_input.setPlaceholderText("0 - 100")

        input_layout.addWidget(input_label)
        input_layout.addWidget(self.curtain_input)

        btn_set = QPushButton("SET CURTAIN")
        btn_set.clicked.connect(self.set_curtain)
        btn_return = QPushButton("ANA MENÜYE DÖN")
        btn_return.clicked.connect(self.close)

        control_layout.addLayout(input_layout)
        control_layout.addWidget(btn_set)
        control_layout.addWidget(btn_return)
        control_group.setLayout(control_layout)
        main_layout.addWidget(control_group)

        self.setLayout(main_layout)
        self.refresh_display()

    def refresh_display(self):
        # 1. UART uzerinden Board #2 verilerini cek [R2.2.6-1]
        self.api.update()
        
        # 2. GUI etiketlerini guncelle [R2.4-1]
        self.lbl_outdoor.setText(f"Outdoor Temperature: {self.api.getOutdoorTemp()} °C")
        self.lbl_pressure.setText(f"Outdoor Pressure: {self.api.getOutdoorPress()} hPa")
        self.lbl_curtain.setText(f"Curtain Status: {int(self.api.getCurtainStatus())} %") # Yuzdeyi int gosterelim
        self.lbl_light.setText(f"Light Intensity: {int(self.api.getLightIntensity())}") # Lux degeri
        
        # Klima sisteminden ic sicaklik verisini al (Senkronizasyon)
        real_indoor_temp = self.ac_api.getAmbientTemp()
        self.lbl_indoor.setText(f"Indoor Temperature: {real_indoor_temp} °C")

    def set_curtain(self):
        text = self.curtain_input.text()
        try:
            val = float(text)
            if 0 <= val <= 100:
                if self.api.setCurtainStatus(val):
                    QMessageBox.information(self, "Basarili", f"Perde ayarlandi: %{int(val)}")
                    self.curtain_input.clear()
                else:
                    QMessageBox.critical(self, "Hata", "Komut gonderilemedi! Board baglantisini kontrol edin.")
            else:
                QMessageBox.warning(self, "Aralik Hatasi", "Deger 0 ile 100 arasinda olmalidir!")
        except ValueError:
            QMessageBox.warning(self, "Giris Hatasi", "Lutfen gecerli bir sayi girin!")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setFont(QFont("Consolas", 10))
    
    # Uygulamayi Baslat
    win = MainMenu()
    win.show()
    sys.exit(app.exec())