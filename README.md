# PIC16F877A Home Automation System

## Overview

This project is a home automation system developed for the PIC16F877A microcontroller using Assembly language.
The system consists of two simulated boards in PICSimLab:

- Board #1: Home Air Conditioner Control
- Board #2: Curtain Control System

The project also includes a PC-side application and API for UART-based communication.

## System Architecture

The system includes:

• Temperature Control Module (LM35, Heater, Cooler, Tachometer)  
• Keypad Input Module  
• 7-Segment Display  
• LCD Display (16x2)  
• Step Motor Curtain Control  
• LDR Light Sensor  
• BMP180 Pressure & Temperature Sensor (I2C)  
• UART Communication (8N1)  
• PC-Side API and Console Application  

Simulation environment: PICSimLab (gpboard)

## Technologies Used

- PIC16F877A
- Assembly Language (for microcontroller)
- C/C++ (for PC-side API & Application)
- UART Serial Communication
- I2C Communication
- PICSimLab Simulation

## Features

Board #1 (Air Conditioner System):
- Desired temperature setting via keypad
- Ambient temperature monitoring
- Heater & cooler control logic
- Fan speed measurement (rps)
- 7-segment display output
- UART data exchange

Board #2 (Curtain Control System):
- Step motor controlled curtain positioning (0–100%)
- Light-based automatic curtain adjustment
- Outdoor temperature & pressure reading
- LCD display output
- UART communication support

## Current Status

The system structure and most modules are implemented.
UART communication and synchronization between modules are partially functional and may require further debugging and optimization.
This project was developed for academic purposes and demonstrates modular embedded system design.

---

# Türkçe Açıklama

## Genel Bakış

Bu proje, PIC16F877A mikrodenetleyicisi kullanılarak Assembly dili ile geliştirilmiş bir ev otomasyon sistemidir.

Sistem PICSimLab ortamında iki kart üzerinden simüle edilmiştir:

- Kart #1: Ev Klima Kontrol Sistemi
- Kart #2: Perde Kontrol Sistemi

Ayrıca PC tarafında UART üzerinden haberleşen bir API ve uygulama geliştirilmiştir.

## Sistem Bileşenleri

• Sıcaklık Kontrol Modülü (LM35, Isıtıcı, Soğutucu, Takometre)  
• Keypad Giriş Modülü  
• 7-Segment Display  
• LCD (16x2)  
• Step Motor Perde Kontrolü  
• LDR Işık Sensörü  
• BMP180 Basınç & Sıcaklık Sensörü (I2C)  
• UART Haberleşme (8N1)  
• PC Tarafı API ve Konsol Uygulaması  

Simülasyon ortamı: PICSimLab (gpboard)

---

## Kullanılan Teknolojiler

- PIC16F877A
- Assembly Dili
- C/C++ (PC uygulaması için)
- UART Seri Haberleşme
- I2C Haberleşme
- PICSimLab

---

## Özellikler

Kart #1:
- Keypad ile hedef sıcaklık girişi
- Ortam sıcaklığı takibi
- Isıtıcı & fan kontrolü
- Fan hız ölçümü
- 7-segment ekran çıktısı
- UART üzerinden veri iletişimi

Kart #2:
- Step motor ile %0–%100 perde kontrolü
- Işık seviyesine göre otomatik perde ayarı
- Dış ortam sıcaklık & basınç ölçümü
- LCD ekran gösterimi
- UART haberleşmesi

## Mevcut Durum

Sistem modüler olarak tasarlanmış ve büyük kısmı çalışır durumdadır.
UART haberleşmesinde ve bazı senkronizasyon işlemlerinde geliştirme gerektiren kısımlar bulunmaktadır.
Bu proje akademik amaçlı geliştirilmiş olup gömülü sistem tasarımını modüler yapı ile göstermektedir.
