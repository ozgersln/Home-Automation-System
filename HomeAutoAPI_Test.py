import unittest
import importlib.util

from HomeAutoAPI import HomeAutomationSystemConnection, AirConditionerSystemConnection, CurtainControlSystemConnection

class TestHomeAutomationSystemConnection(unittest.TestCase):
    """HomeAutomationSystemConnection sinifinin tum methodlarini test et"""
    
    def setUp(self):
        self.conn = HomeAutomationSystemConnection()
    
    # __init__ testi
    def test_init(self):
        """__init__: Varsayilan degerleri kontrol et"""
        self.assertEqual(self.conn.comPort, "COM1")
        self.assertEqual(self.conn.baudRate, 9600)
        self.assertIsNone(self.conn.serial_link)
    
    # setComPort testi
    def test_setComPort_single_change(self):
        """setComPort: Port numarasini bir kere degistir"""
        self.conn.setComPort("COM10")
        self.assertEqual(self.conn.comPort, "COM10")
    
    def test_setComPort_multiple_changes(self):
        """setComPort: Port numarasini birden fazla kere degistir"""
        self.conn.setComPort("COM5")
        self.assertEqual(self.conn.comPort, "COM5")
        
        self.conn.setComPort("COM18")
        self.assertEqual(self.conn.comPort, "COM18")
        
        self.conn.setComPort("COM14")
        self.assertEqual(self.conn.comPort, "COM14")
    
    # setBaudRate testi
    def test_setBaudRate_single_change(self):
        """setBaudRate: Baud rate tek degistir"""
        self.conn.setBaudRate(115200)
        self.assertEqual(self.conn.baudRate, 115200)
    
    def test_setBaudRate_multiple_changes(self):
        """setBaudRate: Baud rate birden fazla degistir"""
        self.conn.setBaudRate(9600)
        self.assertEqual(self.conn.baudRate, 9600)
        
        self.conn.setBaudRate(19200)
        self.assertEqual(self.conn.baudRate, 19200)
        
        self.conn.setBaudRate(115200)
        self.assertEqual(self.conn.baudRate, 115200)
    
    # open testi
    def test_open(self):
        """open: Portu ac"""
        self.conn.setComPort("COM1")
        result = self.conn.open()
        
        # Sonuc bool olmali
        self.assertIsInstance(result, bool)
        
        # Port acilirsa serial_link None olmamali
        if result:
            self.assertIsNotNone(self.conn.serial_link)
            self.conn.close()
    
    # close testi
    def test_close(self):
        """close: Portu kapat"""
        self.conn.setComPort("COM1")
        open_result = self.conn.open()
        
        if open_result:
            self.conn.close()
            # Kapatilinca is_open False olmali
            self.assertFalse(self.conn.serial_link.is_open)
    
    # _send_byte testi
    def test_send_byte(self):
        """_send_byte: Byte gonder"""
        self.conn.setComPort("COM1")
        result = self.conn.open()
        
        if result:
            # Method hata vermeden calismalı
            self.conn._send_byte(0x42)
            self.conn.close()
    
    # _read_byte testi
    def test_read_byte_no_connection(self):
        """_read_byte: Baglanti yoksa 0 dondur"""
        self.conn.serial_link = None
        result = self.conn._read_byte()
        self.assertEqual(result, 0)
    
    def test_read_byte_with_connection(self):
        """_read_byte: Baglanti varsa sonuc kontrol et"""
        self.conn.setComPort("COM1")
        result = self.conn.open()
        
        if result:
            byte_result = self.conn._read_byte()
            self.assertIsInstance(byte_result, int)
            self.conn.close()


class TestAirConditionerSystemConnection(unittest.TestCase):
    """AirConditionerSystemConnection sinifinin tum methodlarini test et"""
    
    def setUp(self):
        self.ac = AirConditionerSystemConnection()
    
    # __init__ testi
    def test_init(self):
        """__init__: Klima varsayilan degerleri"""
        self.assertEqual(self.ac.desiredTemperature, 25.0)
        self.assertEqual(self.ac.ambientTemperature, 0.0)
        self.assertEqual(self.ac.fanSpeed, 0)
        self.assertEqual(self.ac.comPort, "COM1")
    
    # setDesiredTemp testi - basarili
    def test_setDesiredTemp_valid_integer(self):
        """setDesiredTemp: Gecerli integer sicaklik"""
        result = self.ac.setDesiredTemp(28)
        self.assertTrue(result)
        self.assertEqual(self.ac.desiredTemperature, 28.0)
    
    def test_setDesiredTemp_valid_float(self):
        """setDesiredTemp: Gecerli float sicaklik"""
        result = self.ac.setDesiredTemp(25.7)
        self.assertTrue(result)
        self.assertEqual(self.ac.desiredTemperature, 25.0)  # int'e donusur
    
    def test_setDesiredTemp_valid_string_float(self):
        """setDesiredTemp: Gecerli string sicaklik"""
        result = self.ac.setDesiredTemp("22.5")
        self.assertTrue(result)
        self.assertEqual(self.ac.desiredTemperature, 22.0)  # int'e donusur
    
    def test_setDesiredTemp_multiple_values(self):
        """setDesiredTemp: Birden fazla sicaklik ayarla"""
        result1 = self.ac.setDesiredTemp(20)
        self.assertTrue(result1)
        self.assertEqual(self.ac.desiredTemperature, 20.0)
        
        result2 = self.ac.setDesiredTemp(30)
        self.assertTrue(result2)
        self.assertEqual(self.ac.desiredTemperature, 30.0)
        
        result3 = self.ac.setDesiredTemp(25)
        self.assertTrue(result3)
        self.assertEqual(self.ac.desiredTemperature, 25.0)
    
    # setDesiredTemp testi - hata
    def test_setDesiredTemp_invalid_string(self):
        """setDesiredTemp: Gecersiz string reddedilir"""
        result = self.ac.setDesiredTemp("sicaklik")
        self.assertFalse(result)
    
    def test_setDesiredTemp_invalid_list(self):
        """setDesiredTemp: Liste reddedilir"""
        result = self.ac.setDesiredTemp([20, 30])
        self.assertFalse(result)
    
    # update testi
    def test_update(self):
        """update: Klima verilerini guncelle"""
        self.ac.setComPort("COM1")
        open_result = self.ac.open()
        
        if open_result:
            self.ac.update()
            # update calistiktan sonra degiskenler sayı olmali
            self.assertIsInstance(self.ac.ambientTemperature, float)
            self.assertIsInstance(self.ac.fanSpeed, int)
            self.ac.close()
        else:
            # Port yoksa yine calisabilmeli (0 donecek)
            self.ac.update()
            self.assertEqual(self.ac.ambientTemperature, 0.0)
            self.assertEqual(self.ac.fanSpeed, 0)
    
    # getDesiredTemp testi
    def test_getDesiredTemp(self):
        """getDesiredTemp: Hedef sicakligi al"""
        self.ac.setDesiredTemp(27)
        temp = self.ac.getDesiredTemp()
        self.assertEqual(temp, 27.0)
    
    def test_getDesiredTemp_different_values(self):
        """getDesiredTemp: Farkli sicakliklari al"""
        values = [20, 25, 30, 15]
        for val in values:
            self.ac.setDesiredTemp(val)
            temp = self.ac.getDesiredTemp()
            self.assertEqual(temp, float(val))
    
    # getAmbientTemp testi
    def test_getAmbientTemp(self):
        """getAmbientTemp: Ortam sicakligini al"""
        temp = self.ac.getAmbientTemp()
        self.assertIsInstance(temp, float)
        self.assertEqual(temp, 0.0)  # Baslangicta 0
    
    # getFanSpeed testi
    def test_getFanSpeed(self):
        """getFanSpeed: Fan hizini al"""
        speed = self.ac.getFanSpeed()
        self.assertIsInstance(speed, int)
        self.assertEqual(speed, 0)  # Baslangicta 0


class TestCurtainControlSystemConnection(unittest.TestCase):
    """CurtainControlSystemConnection sinifinin tum methodlarini test et"""
    
    def setUp(self):
        self.curtain = CurtainControlSystemConnection()
    
    # __init__ testi
    def test_init(self):
        """__init__: Perde varsayilan degerleri"""
        self.assertEqual(self.curtain.curtainStatus, 0.0)
        self.assertEqual(self.curtain.outdoorTemperature, 0.0)
        self.assertEqual(self.curtain.outdoorPressure, 0.0)
        self.assertEqual(self.curtain.lightIntensity, 0.0)
    
    # setCurtainStatus testi - basarili
    def test_setCurtainStatus_valid_integer(self):
        """setCurtainStatus: Gecerli integer perde durumu"""
        result = self.curtain.setCurtainStatus(50)
        self.assertTrue(result)
        self.assertEqual(self.curtain.curtainStatus, 50.0)
    
    def test_setCurtainStatus_valid_float(self):
        """setCurtainStatus: Gecerli float perde durumu"""
        result = self.curtain.setCurtainStatus(45.7)
        self.assertTrue(result)
        self.assertEqual(self.curtain.curtainStatus, 45.0)  # int'e donusur
    
    def test_setCurtainStatus_valid_string(self):
        """setCurtainStatus: Gecerli string perde durumu"""
        result = self.curtain.setCurtainStatus("60.5")
        self.assertTrue(result)
        self.assertEqual(self.curtain.curtainStatus, 60.0)
    
    def test_setCurtainStatus_multiple_values(self):
        """setCurtainStatus: Birden fazla perde durumu"""
        result1 = self.curtain.setCurtainStatus(0)
        self.assertTrue(result1)
        self.assertEqual(self.curtain.curtainStatus, 0.0)
        
        result2 = self.curtain.setCurtainStatus(50)
        self.assertTrue(result2)
        self.assertEqual(self.curtain.curtainStatus, 50.0)
        
        result3 = self.curtain.setCurtainStatus(100)
        self.assertTrue(result3)
        self.assertEqual(self.curtain.curtainStatus, 100.0)
    
    # setCurtainStatus testi - hata
    def test_setCurtainStatus_invalid_string(self):
        """setCurtainStatus: Gecersiz string reddedilir"""
        result = self.curtain.setCurtainStatus("perde")
        self.assertFalse(result)
    
    def test_setCurtainStatus_invalid_dict(self):
        """setCurtainStatus: Dict reddedilir"""
        result = self.curtain.setCurtainStatus({"status": 50})
        self.assertFalse(result)
    
    # update testi
    def test_update(self):
        """update: Perde verilerini guncelle"""
        self.curtain.setComPort("COM1")
        open_result = self.curtain.open()
        
        if open_result:
            self.curtain.update()
            # update calistiktan sonra tum degiskenler float olmali
            self.assertIsInstance(self.curtain.curtainStatus, float)
            self.assertIsInstance(self.curtain.outdoorTemperature, float)
            self.assertIsInstance(self.curtain.outdoorPressure, float)
            self.assertIsInstance(self.curtain.lightIntensity, float)
            self.curtain.close()
        else:
            # Port yoksa yine calisabilmeli (0 donecek)
            self.curtain.update()
            self.assertEqual(self.curtain.curtainStatus, 0.0)
            self.assertEqual(self.curtain.outdoorTemperature, 0.0)
            self.assertEqual(self.curtain.outdoorPressure, 0.0)
            self.assertEqual(self.curtain.lightIntensity, 0.0)
    
    # getCurtainStatus testi
    def test_getCurtainStatus(self):
        """getCurtainStatus: Perde durumunu al"""
        self.curtain.setCurtainStatus(75)
        status = self.curtain.getCurtainStatus()
        self.assertEqual(status, 75.0)
    
    def test_getCurtainStatus_different_values(self):
        """getCurtainStatus: Farkli perde durumlari"""
        values = [0, 25, 50, 75, 100]
        for val in values:
            self.curtain.setCurtainStatus(val)
            status = self.curtain.getCurtainStatus()
            self.assertEqual(status, float(val))
    
    # getLightIntensity testi
    def test_getLightIntensity(self):
        """getLightIntensity: Isik yogunlugunu al"""
        intensity = self.curtain.getLightIntensity()
        self.assertIsInstance(intensity, float)
        self.assertEqual(intensity, 0.0)
    
    # getOutdoorTemp testi
    def test_getOutdoorTemp(self):
        """getOutdoorTemp: Dis sicakligi al"""
        temp = self.curtain.getOutdoorTemp()
        self.assertIsInstance(temp, float)
        self.assertEqual(temp, 0.0)
    
    # getOutdoorPress testi
    def test_getOutdoorPress(self):
        """getOutdoorPress: Dis basinci al"""
        press = self.curtain.getOutdoorPress()
        self.assertIsInstance(press, float)
        self.assertEqual(press, 0.0)


class TestIntegration(unittest.TestCase):
    """Sistemlerin birlikte calismasi"""
    
    def test_ac_complete_workflow(self):
        """Klima: Tum islemleri sirayla yap"""
        ac = AirConditionerSystemConnection()
        
        # Port ayarla
        ac.setComPort("COM18")
        self.assertEqual(ac.comPort, "COM18")
        
        # Baud rate ayarla
        ac.setBaudRate(115200)
        self.assertEqual(ac.baudRate, 115200)
        
        # Sicaklik ayarla
        result = ac.setDesiredTemp(24)
        self.assertTrue(result)
        
        # Sicakligi oku
        temp = ac.getDesiredTemp()
        self.assertEqual(temp, 24.0)
    
    def test_curtain_complete_workflow(self):
        """Perde: Tum islemleri sirayla yap"""
        curtain = CurtainControlSystemConnection()
        
        # Port ayarla
        curtain.setComPort("COM14")
        self.assertEqual(curtain.comPort, "COM14")
        
        # Baud rate ayarla
        curtain.setBaudRate(9600)
        self.assertEqual(curtain.baudRate, 9600)
        
        # Perde durumu ayarla
        result = curtain.setCurtainStatus(60)
        self.assertTrue(result)
        
        # Perde durumunu oku
        status = curtain.getCurtainStatus()
        self.assertEqual(status, 60.0)
    
    def test_both_systems_independent(self):
        """Her iki sistem bagimsiz calisir"""
        ac = AirConditionerSystemConnection()
        curtain = CurtainControlSystemConnection()
        
        # Klima ayarla
        ac.setComPort("COM18")
        ac.setDesiredTemp(26)
        
        # Perde ayarla
        curtain.setComPort("COM14")
        curtain.setCurtainStatus(50)
        
        # Degerleri kontrol et
        self.assertEqual(ac.getDesiredTemp(), 26.0)
        self.assertEqual(curtain.getCurtainStatus(), 50.0)
    
    def test_multiple_operations_same_system(self):
        """Ayni sisteme birden fazla islem yap"""
        ac = AirConditionerSystemConnection()
        
        # Birbiri ardina degisiklikler
        temps = [20, 22, 25, 28, 30]
        for temp in temps:
            result = ac.setDesiredTemp(temp)
            self.assertTrue(result)
            read_temp = ac.getDesiredTemp()
            self.assertEqual(read_temp, float(temp))


if __name__ == '__main__':
    print("\n=== HomeAutoAPI - Komplet Test Suite ===\n")
    print("Tum member functionlari test ediliyor...\n")
    
    unittest.main(verbosity=2)
