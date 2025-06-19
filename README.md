# 📏 Distance Sensor Project (Assembly & UART Communication)
This project implements a distance measurement system using an ultrasonic sensor, controlled by an AVR microcontroller (e.g., ATmega328P). The code is written entirely in Assembly language, with UART-based serial communication to a host computer. A Python script listens on the COM port and prints out measured distances in centimeters.

## 🛠️ Features
Trigger and receive ultrasonic sensor pulses

Measure time-of-flight using Timer1 (0.5µs resolution)

Convert ticks to distance using optimized fixed-point arithmetic

Transmit distance data over UART (9600 baud)

LED indicator while measuring

Software UART listener (Python script)

## 🔧 Hardware Requirements
ATmega328P or compatible AVR microcontroller

Ultrasonic distance sensor (e.g., HC-SR04)

LED (optional, for visual feedback)

Push button

USB to UART converter (for serial output to PC)

Pin Configuration (ATmega328P - PORTD):

Pin	Function
PD2	Button Input
PD3	Sensor I/O
PD4	LED Output

## 🚀 How It Works
Button Press starts the measurement.

The sensor is triggered with a short pulse.

Timer1 starts on the incoming echo.

Timer1 stops when echo ends.

Time in ticks is converted to centimeters using fixed-point multiplication (avoiding hardware division).

The result is transmitted over UART (2 bytes: High + Low).

An LED lights up during measurement.

A delay prevents immediate re-triggering.

## ⚙️ Build and Flash
You’ll need avr-gcc and avrdude:

'
avr-gcc -mmcu=atmega328p -o main.elf main.asm
avr-objcopy -O ihex main.elf main.hex
avrdude -c usbasp -p m328p -U flash:w:main.hex
'

## 🖥️ UART Listener (Python)
The Python script reads the 2-byte UART output and prints the distance in centimeters:

## Requirements
bash
Copy
Edit
pip install pyserial
Usage
bash
Copy
Edit
python uartListener.py

##📐 Distance Conversion Logic
Ticks (0.5µs each) are converted to distance using:

nginx
Copy
Edit
distance (cm) = ticks / 116
Since division is not natively supported, it’s done via:

Fixed-point multiplication: ticks * (2^16 / 116)

Post-scaling correction for rounding

Fast and efficient in 8-bit AVR assembly

## 🧠 Technical Highlights
Full UART initialization and transmission routines in ASM

Timer1 used in CTC mode with pre-scaler

Manual fixed-point multiplication (16-bit * 16-bit)

Optimized for speed and memory efficiency

Handles UART buffer availability before each transmission

## 📝 License
This project is provided for educational purposes. Feel free to adapt or improve!

### 👤 Author
Built by moya21 and Benedikt_Nau as a deep-dive into AVR Assembly, low-level timing, and sensor integration.
