import serial
import time

# =============================================================================
# GUNCEL HOME AUTOMATION API - [V1.2]
# =============================================================================

class HomeAutomationSystemConnection:
    def __init__(self):
        self.comPort = "COM1"
        self.baudRate = 9600
        self.serial_link = None

    def setComPort(self, port):
        self.comPort = port

    def setBaudRate(self, rate):
        self.baudRate = rate

    def open(self):
        """Baglantiyi acar ve kasmayi engellemek icin kisa timeout ayarlar"""
        try:
            # Timeout 0.1: Veri gelmezse Python bekleyip arayuzu dondurmez
            self.serial_link = serial.Serial(self.comPort, self.baudRate, timeout=0.01)
            time.sleep(0.1)
            self.serial_link.reset_input_buffer()
            self.serial_link.reset_output_buffer()
            return True
        except Exception as e:
            print(f"[API] Port hatasi: {e}")
            return False

    def close(self):
        if self.serial_link and self.serial_link.is_open:
            self.serial_link.close()

    def _send_byte(self, data_byte):
        """PIC'in anlayacagi ham byte formatinda gonderim yapar"""
        if self.serial_link and self.serial_link.is_open:
            try:
                self.serial_link.write(bytes([data_byte]))
                self.serial_link.flush() 
                time.sleep(0.01) # PIC'in islemesi icin kisa es
            except:
                pass

    def _read_byte(self):
        """Board'dan gelen tek byte veriyi okur"""
        if self.serial_link and self.serial_link.is_open:
            try:
                raw = self.serial_link.read(1)
                if raw:
                    return int.from_bytes(raw, byteorder='big')
            except:
                pass
        return 0

class AirConditionerSystemConnection(HomeAutomationSystemConnection):
    def __init__(self):
        super().__init__()
        self.desiredTemperature = 25.0
        self.ambientTemperature = 0.0
        self.fanSpeed = 0

    def setDesiredTemp(self, temp):
        """Board 1 Protokolu: 11xxxxxx formatinda tamsayi yollar"""
        try:
            val = int(float(temp))
            cmd = 0xC0 | (val & 0x3F) 
            self._send_byte(cmd)
            self.desiredTemperature = float(val)
            return True
        except:
            return False

    def update(self):
        """Klima verilerini gunceller"""
        # Ortam Sicakligi iste (0x04)
        self._send_byte(0x04)
        self.ambientTemperature = float(self._read_byte())
        # Fan Hizi iste (0x05)
        self._send_byte(0x05)
        self.fanSpeed = self._read_byte()

    def getAmbientTemp(self): return self.ambientTemperature
    def getFanSpeed(self): return self.fanSpeed
    def getDesiredTemp(self): return self.desiredTemperature

class CurtainControlSystemConnection(HomeAutomationSystemConnection):
    def __init__(self):
        super().__init__()
        self.curtainStatus = 0.0
        self.outdoorTemperature = 0.0
        self.outdoorPressure = 0.0
        self.lightIntensity = 0.0

    def setCurtainStatus(self, status):
        """Board 2 Protokolu: 11xxxxxx formatinda tamsayi yollar"""
        try:
            val = int(float(status))
            cmd = 0xC0 | (val & 0x3F)
            self._send_byte(cmd)
            self.curtainStatus = float(val)
            return True
        except:
            return False

    def update(self):
        """Perde ve Sensor verilerini gunceller"""
        # Perde Durumu (0x02)
        self._send_byte(0x02)
        self.curtainStatus = float(self._read_byte())
        
        # Isik Siddeti (0x08)
        self._send_byte(0x08)
        self.lightIntensity = float(self._read_byte())
        
        # Diger sensorler (Kodda 0 donuyor ama API isterleri icin soruyoruz)
        self._send_byte(0x04) 
        self.outdoorTemperature = float(self._read_byte())
        
        self._send_byte(0x06)
        self.outdoorPressure = float(self._read_byte())

    # Arayuzun hata vermemesi icin gerekli GET fonksiyonlari
    def getCurtainStatus(self): return self.curtainStatus
    def getLightIntensity(self): return self.lightIntensity
    def getOutdoorTemp(self): return self.outdoorTemperature
    def getOutdoorPress(self): return self.outdoorPressure