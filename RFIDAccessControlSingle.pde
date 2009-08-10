/**
 * RFID Access Control Single
 *
 * This project implements a simple stand-alone RFID access control
 * system that can operate independently of a host computer or any
 * other device. It uses an ID-12 RFID reader module from ID
 * Innovations to scan for 125KHz "Unique" RFID tags, and when a
 * recognised tag is identified it toggles an output for 1 second.
 * The output can then be used to control a relay to trip an electric
 * striker plate to release a door lock.
 *
 * Because this project is intended to provide a minimal working system
 * it does not have any provision for database updates to be managed
 * externally from a host, so updates to the accepted cards must be
 * made by changing the values in the code, recompiling the program,
 * and re-uploading it to the Arduino. It does however report card
 * readings (both successful and unsuccessful) via the serial
 * connection so you can monitor the system using a connected computer.
 *
 * Some of this code is derived from Tom Igoe's excellent RFID tutorial
 * which is detailed on his blog at:
 *   http://www.tigoe.net/pcomp/code/category/PHP/347
 *
 * Copyright Jonathan Oxer <jon@oxer.com.au>
 * http://www.practicalarduino.com/
 */

// Set up the serial connection to the RFID reader module. The module's
// TX pin needs to be connected to RX (pin 2) on the Arduino. Module
// RX doesn't need to be connected to anything since we won't send
// commands to it, but SoftwareSerial requires us to define a pin for
// TX anyway so you can either connect module RX to Arduino TX or just
// leave them disconnected.
#include <SoftwareSerial.h>
#define rxPin 2
#define txPin 3

// Create a software serial object for the connection to the RFID reader module
SoftwareSerial rfid = SoftwareSerial(rxPin, txPin);

// Set up outputs
#define strikerPlate 12
#define ledPin 13

byte allowedTag[5] = {0x01, 0x04, 0xF5, 0xB5, 0x21};

int incomingByte = 0;    // To store incoming serial data

/**
 * Setup
 */
void setup() {
  pinMode(ledPin, OUTPUT);
  Serial.begin(38400);   // Serial port for connection to host
  rfid.begin(9600);      // Serial port for connection to RFID module

  Serial.println("RFID reader starting up");
}


/**
 * Loop
 */
void loop() {
  byte i             = 0;
  byte authorizedTag = 0;
  byte val           = 0;
  byte checksum      = 0;
  byte bytesread     = 0;
  byte tempbyte      = 0;
  byte tagValue[6];    // Tags are only 5 bytes but we need an extra byte for the checksum

  // Read from the RFID module. Because this connection uses SoftwareSerial
  // there is no equivalent to the Serial.available() function, so at this
  // point the program blocks while waiting for a value from the module
  if((val = rfid.read()) == 2) {        // Check for header
    bytesread = 0;
    while (bytesread < 12) {            // Read 10 digit code + 2 digit checksum
      val = rfid.read();
      if((val == 0x0D)||(val == 0x0A)||(val == 0x03)||(val == 0x02)) { // if header or stop bytes before the 10 digit reading 
        break;                          // Stop reading
      }

      // Ascii/Hex conversion:
      if ((val >= '0') && (val <= '9')) {
        val = val - '0';
      }
      else if ((val >= 'A') && (val <= 'F')) {
        val = 10 + val - 'A';
      }

      // Every two hex-digits, add byte to code:
      if (bytesread & 1 == 1) {
        // make some space for this hex-digit by
        // shifting the previous digit 4 bits to the left:
        tagValue[bytesread >> 1] = (val | (tempbyte << 4));

        if (bytesread >> 1 != 5) {                // If we're at the checksum byte,
          checksum ^= tagValue[bytesread >> 1];       // Calculate the checksum... (XOR)
        };
      }
      else {
        tempbyte = val;                           // Store the first hex digit first...
      };

      bytesread++;                                // ready to read next digit
    }

    // Send the result to the host connected via USB
    if (bytesread == 12) {                        // if 12 digit read is complete
      if(tagValue[0] == allowedTag[0]
        && tagValue[1] == allowedTag[1]
        && tagValue[2] == allowedTag[2]
        && tagValue[3] == allowedTag[3]
        && tagValue[4] == allowedTag[4]
        )
      {
        authorizedTag = 1;
      } else {
        authorizedTag = 0;
      }


      Serial.print("Tag read: ");
      for (i=0; i<5; i++) {
        // Add a leading 0 to pad out values below 16
        if (tagValue[i] < 16){
          Serial.print("0");
        }
        Serial.print(tagValue[i], HEX);
        //Serial.print(" ");
      }
      Serial.println();

      Serial.print("Checksum: ");
      Serial.print(tagValue[5], HEX);
      Serial.println(tagValue[5] == checksum ? " -- passed." : " -- error.");
      Serial.println();

      // Only fire the striker plate if this tag was authorized
      if( authorizedTag == 1)
      {
        Serial.println("Authorized tag: unlocking");
        unlock();
      } else {
        Serial.println("Tag not authorized");
      }
    }

    bytesread = 0;
  }
  //toggle(13);
}

/**
 */
void toggle(int pinNum) {
  digitalWrite(pinNum, !digitalRead(pinNum));
}


/**
 * Fire the relay to activate the striker plate for one second
 */
void unlock() {
  digitalWrite(ledPin, HIGH);
  digitalWrite(strikerPlate, HIGH);
  delay(1000);
  digitalWrite(strikerPlate, LOW);
  digitalWrite(ledPin, LOW);
}

