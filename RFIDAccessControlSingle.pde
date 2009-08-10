/**
 * Some of this code is derived from Tom Igoe's excellent RFID project on his blog
 */

// Set up the serial connection to the RFID reader module
#include <SoftwareSerial.h>
#define rxPin 2
#define txPin 3
// Create a software serial object for the connection to the RFID reader module
SoftwareSerial rfid = SoftwareSerial(rxPin, txPin);


// Set up the storage area for tags
#include <EEPROM.h>
#define MAX_NO_CARDS 102

// Set up outputs
#define ledPin 13
#define strikerPlate 13

byte allowedTag[5] = {0x01, 0x04, 0xF5, 0xB5, 0x21};

int incomingByte = 0;	// for incoming serial data

/**
 * Setup
 */
void setup() {
  pinMode(ledPin, OUTPUT);
  Serial.begin(38400);   // Port for connection to host
  rfid.begin(9600);      // Port for connection to RFID

  Serial.println("RFID reader starting up");
  // print user instructions serially:
  Serial.println("n - add card to database");
  Serial.println("c - clear entire database");
  Serial.println("d - delete card from database");
  Serial.println("p - print database"); 
}

/**
 * Loop
 */
void loop() {
  byte i = 0;
  byte val = 0;
  byte tagValue[6];  // Only a 5-byte tag value, but we need an extra byte for the checksum
  byte checksum = 0;
  byte bytesread = 0;
  byte tempbyte = 0;
  
  
  if (Serial.available() > 0) {
    // read the latest byte:
    char incomingByte = Serial.read();
    switch (incomingByte) {
    //case 'n':            // if user enters 'n' then store tag number
    //  seekNewTag();
    //  break;
    case 'c':
      clearEeprom();    // if user enters 'c' then erase database
      Serial.println("Database deleted");
      break;
    //case 'd':           // if user enters 'd' then delete the last tag
    //  seekAndDeleteTag();
    //  break;
    case'p':            // if user enters 'p' then print the database
      printTags();
      break;
    }
  }


  if((val = rfid.read()) == 2) {        // check for header 
    bytesread = 0;
    while (bytesread < 12) {            // read 10 digit code + 2 digit checksum
      val = rfid.read();
      if((val == 0x0D)||(val == 0x0A)||(val == 0x03)||(val == 0x02)) { // if header or stop bytes before the 10 digit reading 
        break;                          // stop reading
      }

      // Do Ascii/Hex conversion:
      if ((val >= '0') && (val <= '9')) {
        val = val - '0';
      } 
      else if ((val >= 'A') && (val <= 'F')) {
        val = 10 + val - 'A';
      }

      // Every two hex-digits, add byte to code:
      if (bytesread & 1 == 1) {
        // make some space for this hex-digit by
        // shifting the previous hex-digit with 4 bits to the left:
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

    // Output to Serial:
    if (bytesread == 12) {                        // if 12 digit read is complete
      Serial.print("Tag value: ");
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
    }

    if(tagValue[0] == allowedTag[0]
      && tagValue[1] == allowedTag[1]
      && tagValue[2] == allowedTag[2]
      && tagValue[3] == allowedTag[3]
      && tagValue[4] == allowedTag[4]
      )
    {
      Serial.println("Allowed tag, unlocking");
      unlock();
    } else {
      Serial.println("Tag value not recognised");
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
  digitalWrite(strikerPlate, HIGH);
  delay(1000);
  digitalWrite(strikerPlate, LOW);
}


/**
 * Reset the entire EEPROM to 0 values
 */
void clearEeprom()
{
  // write a 0 to all 512 bytes of the EEPROM
  for (int i = 0; i < 512; i++)
    EEPROM.write(i, 0);
}

void readEeprom()
{
  int address = 0;
  byte value;
  // read a byte from the current address of the EEPROM
  value = EEPROM.read(address);
  
  Serial.print(address);
  Serial.print("\t");
  Serial.print(value, DEC);
  Serial.println();
  
  // advance to the next address of the EEPROM
  address = address + 1;
  
  // there are only 512 bytes of EEPROM, from 0 to 511, so if we're
  // on address 512, wrap around to address 0
  if (address == 512)
    address = 0;
    
  delay(500);
}

void writeEeprom( byte val )
{
  int addr = 0;
  // write the value to the appropriate byte of the EEPROM.
  // these values will remain there when the board is
  // turned off.
  EEPROM.write(addr, val);
  
  // advance to the next address.  there are 512 bytes in 
  // the EEPROM, so go back to 0 when we hit 512.
  addr = addr + 1;
  if (addr == 512)
    addr = 0;
  
  delay(100);
}


/**
 * print the entire database
 */
void printTags(){
  for (int thisTag = 0; thisTag< MAX_NO_CARDS; thisTag++){
    printOneTag(thisTag);
  }
}

/**
 * Print a single tag given the tag's address:
 */
void printOneTag(int address) {
  Serial.print(address);
  Serial.print(":");
  for (int offset = 1; offset < 5; offset++) {
    int thisByte = int(EEPROM.read(address*5+offset));
    // if the byte is less than 16, i.e. only one hex character
    // add a leading 0:
    if (thisByte < 0x10) {
      Serial.print("0");
    }
    // print the value:
    Serial.print(thisByte,HEX);
  }
  // add a final linefeed and carriage return:
  Serial.println();
}
