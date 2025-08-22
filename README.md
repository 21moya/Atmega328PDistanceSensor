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

## ⚙️ Build & Flash

### Requirements
Install AVR tools:
```sh
# Debian/Ubuntu
sudo apt install gcc-avr binutils-avr avr-libc avrdude
# macOS (Homebrew)
brew install avr-gcc avrdude
```

### Build
```sh
# Assemble + link (for .asm)
avr-gcc -mmcu=atmega328p -DF_CPU=16000000UL -Os -nostdlib -x assembler-with-cpp -o main.elf main.asm
avr-objcopy -O ihex -R .eeprom main.elf main.hex

# Or, if renamed to main.S
avr-gcc -mmcu=atmega328p -DF_CPU=16000000UL -Os -nostdlib -o main.elf main.S
avr-objcopy -O ihex -R .eeprom main.elf main.hex
```

### Flash
```sh
avrdude -c usbasp -p m328p -U flash:w:main.hex:i
```

---

### Minimal Makefile
```makefile
MCU = atmega328p
F_CPU = 16000000UL
PROG = usbasp
SRC = main.asm
ELF = main.elf
HEX = main.hex

all: $(HEX)
$(ELF): $(SRC)
	avr-gcc -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os -nostdlib -x assembler-with-cpp -o $@ $<
$(HEX): $(ELF)
	avr-objcopy -O ihex -R .eeprom $< $@
flash: $(HEX)
	avrdude -c $(PROG) -p m328p -U flash:w:$(HEX):i
clean:
	rm -f $(ELF) $(HEX)
```


## 🖥️ UART Listener (Python)
The Python script reads the 2-byte UART output and prints the distance in centimeters:

## Requirements
`pip install pyserial`

Usage
`python uartListener.py`

##📐 Distance Conversion Logic
Ticks (0.5µs each) are converted to distance using:

`distance (cm) = ticks / 116`
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

## 👤 Author
Built by [BenediktNau](https://github.com/BenediktNau) and [21moya](https://github.com/21moya) as a deep-dive into AVR Assembly, low-level timing, and sensor integration.
