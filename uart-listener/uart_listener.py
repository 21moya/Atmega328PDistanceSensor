import serial

PORT = "COM4"

def recieve():
    with serial.Serial(PORT, 9600, 8, "N", 1) as ser:
        s = ser.read(2)
        bytes = list(s)
        value = (bytes[0] << 8) | bytes[1]
        return value

def main():
    print(f"starting listening on port {PORT}...")
    while True:
        try:
            print(f"{recieve()}cm")
        except KeyboardInterrupt:
            print("exiting program")
            exit()

if __name__ == "__main__":
    main()