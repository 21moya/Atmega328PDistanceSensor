"""
serial_distance_reader.py

Reads 2-byte distance values (big-endian) from a serial device.
Prints them continuously until interrupted.
"""

import serial

PORT = "COM4"
BAUDRATE = 9600

def recieve() -> int:
  """
  Read 2 bytes from the serial port.
  Return the value as distance in cm.
  """
  with serial.Serial(PORT, BAUDRATE, 8, "N", 1) as ser:
    s = ser.read(2)
    if len(s) < 2:
      raise ValueError("Expected 2 bytes")
    return (s[0] << 8) | s[1]

def main() -> None:
  """
  Continuously print distance readings.
  Stop when Ctrl+C is pressed.
  """
  print(f"Listening on {PORT}...")
  while True:
    try:
      print(f"{recieve()}cm")
    except KeyboardInterrupt:
      print("Exiting.")
      break

if __name__ == "__main__":
  main()