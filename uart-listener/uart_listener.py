import serial

def recieve():
    with serial.Serial("COM4", 9600, 8, "N", 1) as ser:
        s = ser.read(2)
        bytes = list(s)
        value = (bytes[0] << 8) | bytes[1]
        return value

def main():
    while True:
        try:
            print(f"{recieve()}cm")
        except KeyboardInterrupt:
            print("exiting program")
            exit()

if __name__ == "__main__":
    main()