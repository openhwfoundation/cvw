//
// aes.c
// Based on and enhanced work by https://github.com/m3y54m/aes-in-c.git
// james.stine@okstate.edu 11 November 2024
//

#include <stdio.h>

enum errorCode {
    SUCCESS = 0,
    ERROR_AES_UNKNOWN_KEYSIZE
};

// Implementation: S-Box
unsigned char sbox[256] = {
  // 0     1    2      3     4    5     6     7      8    9     A      B    C     D     E     F
  0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,  // 0
  0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,  // 1
  0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,  // 2
  0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,  // 3
  0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,  // 4
  0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,  // 5
  0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,  // 6
  0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,  // 7
  0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,  // 8
  0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,  // 9
  0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,  // A
  0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,  // B
  0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,  // C
  0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,  // D
  0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,  // E
  0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16}; // F

unsigned char rsbox[256] =
  // 0     1    2      3     4    5     6     7      8    9     A      B    C     D     E     F
  {0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,  // 0
   0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,  // 1
   0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,  // 2
   0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,  // 3
   0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,  // 4
   0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,  // 5
   0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,  // 6
   0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,  // 7
   0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,  // 8
   0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,  // 9
   0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,  // A
   0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,  // B
   0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,  // C
   0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,  // D
   0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,  // E
   0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d}; // F

// Implementation: Rcon
unsigned char Rcon[255] = {
  0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8,
  0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3,
  0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f,
  0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d,
  0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab,
  0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d,
  0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25,
  0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01,
  0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d,
  0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa,
  0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a,
  0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02,
  0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a,
  0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef,
  0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94,
  0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04,
  0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f,
  0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5,
  0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33,
  0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb};

// Implementation: Key Expansion
enum keySize {
  SIZE_16 = 16,
  SIZE_24 = 24,
  SIZE_32 = 32
};

// main Function Prototypes
void KeySchedule(unsigned char *word, int iteration);
unsigned char getRconValue(unsigned char num);
void rotate(unsigned char *word);
// AES Encryption Function Prototypes
void subBytes(unsigned char *state);
void shiftRows(unsigned char *state);
void shiftRow(unsigned char *state, unsigned char nbr);
void addRoundKey(unsigned char *state, unsigned char *roundKey);
unsigned char galois_multiplication(unsigned char a, unsigned char b);
void mixColumns(unsigned char *state);
void mixColumn(unsigned char *column);
void aes_cipher(unsigned char *state, unsigned char *roundKey);
void createRoundKey(unsigned char *expandedKey, unsigned char *roundKey);
void aes_main(unsigned char *state, unsigned char *expandedKey, int nbrRounds);
char aes_encrypt(unsigned char *input, unsigned char *output, unsigned char *key, enum keySize size);
// AES Decryption Function Prototypes
void invSubBytes(unsigned char *state);
void invShiftRows(unsigned char *state);
void invShiftRow(unsigned char *state, unsigned char nbr);
void invMixColumns(unsigned char *state);
void invMixColumn(unsigned char *column);
void aes_invRound(unsigned char *state, unsigned char *roundKey);
void aes_invCipher(unsigned char *state, unsigned char *expandedKey, int nbrRounds);
char aes_decrypt(unsigned char *input, unsigned char *output, unsigned char *key, enum keySize size);

// Helper function to print AES state
void printState(const unsigned char *state) {
  for (int col = 0; col < 4; col++) {
    printf("%02x %02x %02x %02x ",
           state[col], state[col + 4], state[col + 8], state[col + 12]);
  }
  printf("\n");
}

unsigned char getSBoxValue(unsigned char num) {
  return sbox[num];
}

unsigned char getSBoxInvert(unsigned char num) {
  return rsbox[num];
}

// left circular rotation (i.e., byte-wise rotate left) on a 4-byte word
void rotate(unsigned char *word) {
  unsigned char temp = word[0];
  word[0] = word[1];
  word[1] = word[2];
  word[2] = word[3];
  word[3] = temp;
}

unsigned char getRconValue(unsigned char num) {
  return Rcon[num];
}

// Key Schedule: RotWord → SubWord → XOR with Rcon
void KeySchedule(unsigned char *word, int iteration) {
  int i;

  // rotate the 32-bit word 8 bits to the left
  rotate(word);
  // apply S-Box substitution on all 4 parts of the 32-bit word
  for (i = 0; i < 4; ++i) {
    word[i] = getSBoxValue(word[i]);
  }
  // XOR the output of the rcon operation with i to the first part (leftmost) only
  word[0] = word[0] ^ getRconValue(iteration);
}

// Rijndael's key expansion:  expands an 128, 192, 256 key into an 176, 208, 240 bytes key
void KeyExpansion(unsigned char *expandedKey, unsigned char *key,
                  enum keySize size, unsigned int expandedKeySize) {

  int currentSize = 0;
  int rconIteration = 1;
  int i;
  unsigned char t[4] = {0}; // temporary 4-byte variable

  // set the 16, 24,32 bytes of the expanded key to the input key
  for (i = 0; i < size; i++)
    expandedKey[i] = key[i];
  currentSize += size;
  while (currentSize < expandedKeySize) {
    // assign the previous 4 bytes to the temporary value t
    for (i = 0; i < 4; i++) {
      t[i] = expandedKey[(currentSize - 4) + i];
    }
    // every 16, 24, 32 bytes we apply the core schedule to t
    // and increment rconIteration afterwards
    if (currentSize % size == 0) {
      KeySchedule(t, rconIteration++);
    }
    // For 256-bit keys, we add an extra sbox to the calculation
    if (size == SIZE_32 && ((currentSize % size) == 16)) {
      for (i = 0; i < 4; i++)
        t[i] = getSBoxValue(t[i]);
    }

    // We XOR t with the four-byte block 16, 24, 32 bytes before the new expanded key.
    // This becomes the next four bytes in the expanded key.
    for (i = 0; i < 4; i++) {
      expandedKey[currentSize] = expandedKey[currentSize - size] ^ t[i];
      currentSize++;
    }
  }
}

void subBytes(unsigned char *state) {
  for (int i = 0; i < 16; i++) {
    state[i] = getSBoxValue(state[i]);
  }
}

void shiftRows(unsigned char *state) {
  for (int row = 0; row < 4; row++) {
    shiftRow(state + row * 4, row);
  }
}

void shiftRow(unsigned char *state, unsigned char nbr) {
  unsigned char temp[4];

  // Perform rotation directly
  for (int i = 0; i < 4; i++) {
    temp[i] = state[(i + nbr) % 4];
  }

  // Copy result back to state
  for (int i = 0; i < 4; i++) {
    state[i] = temp[i];
  }
}

void addRoundKey(unsigned char *state, unsigned char *roundKey) {
  int i;
  for (i = 0; i < 16; i++)
    state[i] = state[i] ^ roundKey[i];
}

// Based on work by Tom St. Denis/Simon Johnson
// https://www.amazon.com/Cryptography-Developers-Tom-St-Denis/dp/1597491047
unsigned char gfmul(unsigned char a, unsigned char b) {
  unsigned char p = 0;
  for (unsigned char counter = 0; counter < 8; counter++) {
    if (b & 1)
      p ^= a;
    a = (a << 1) ^ ((a & 0x80) ? 0x1b : 0);
    b >>= 1;
  }
  return p;
}

// Section 5.1.3 of FIPS 197
void mixColumns(unsigned char *state) {
  unsigned char column[4];

  for (int col = 0; col < 4; col++) {
    // Extract the column from the state
    for (int row = 0; row < 4; row++) {
      column[row] = state[row * 4 + col];
    }

    // Mix the column
    mixColumn(column);

    // Store the mixed column back into the state
    for (int row = 0; row < 4; row++) {
      state[row * 4 + col] = column[row];
    }
  }
}

void mixColumn(unsigned char *column) {
  unsigned char a[4], b[4];

  for (int i = 0; i < 4; i++) {
    a[i] = column[i];
    b[i] = gfmul(column[i], 2);
  }

  column[0] = b[0] ^ a[3] ^ a[2] ^ gfmul(a[1], 3);
  column[1] = b[1] ^ a[0] ^ a[3] ^ gfmul(a[2], 3);
  column[2] = b[2] ^ a[1] ^ a[0] ^ gfmul(a[3], 3);
  column[3] = b[3] ^ a[2] ^ a[1] ^ gfmul(a[0], 3);
}

// The rounds in the specifcation of aes_cipher() are composed of the following 4 byte-oriented
// transformations on the state (Section 5.1 of FIPS 197) - outputs hex after each step
void aes_cipher(unsigned char *state, unsigned char *roundKey) {
  subBytes(state);
  printState(state);

  shiftRows(state);
  printState(state);

  mixColumns(state);
  printState(state);

  addRoundKey(state, roundKey);
  printf("\n");
}

void createRoundKey(unsigned char *expandedKey, unsigned char *roundKey) {
  int i, j;
  // iterate over the columns
  for (i = 0; i < 4; i++) {
    // iterate over the rows
    for (j = 0; j < 4; j++)
      roundKey[(i + (j * 4))] = expandedKey[(i * 4) + j];
  }
}

void aes_main(unsigned char *state, unsigned char *expandedKey, int nbrRounds) {
  unsigned char roundKey[16];

  // Initial round key
  createRoundKey(expandedKey, roundKey);
  printState(state);
  printf("\n");
  addRoundKey(state, roundKey);

  for (int i = 1; i < nbrRounds; i++) {
    createRoundKey(expandedKey + 16 * i, roundKey);
    printState(state);
    aes_cipher(state, roundKey);
  }
  // Final round (no MixColumns)
  printState(state);

  createRoundKey(expandedKey + 16 * nbrRounds, roundKey);
  subBytes(state);
  printState(state);

  shiftRows(state);
  printState(state);

  addRoundKey(state, roundKey);
  printState(state);
}

char aes_encrypt(unsigned char *input, unsigned char *output,
                 unsigned char *key, enum keySize size) {
  int nbrRounds;
  int expandedKeySize;
  unsigned char block[16];

  // Determine number of rounds based on key size
  switch (size) {
    case SIZE_16: nbrRounds = 10; break;
    case SIZE_24: nbrRounds = 12; break;
    case SIZE_32: nbrRounds = 14; break;
    default: return ERROR_AES_UNKNOWN_KEYSIZE;
  }

  expandedKeySize = 16 * (nbrRounds + 1);
  unsigned char expandedKey[expandedKeySize];

  // Map input (row-major to column-major for AES)
  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 4; col++) {
      block[row + 4 * col] = input[4 * row + col];
    }
  }

  // Expand the key
  KeyExpansion(expandedKey, key, size, expandedKeySize);
  // Encrypt the block
  aes_main(block, expandedKey, nbrRounds);
  // Map block back to output (column-major to row-major)
  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 4; col++) {
      output[4 * row + col] = block[row + 4 * col];
    }
  }

  return SUCCESS;
}

void invSubBytes(unsigned char *state) {
  for (int i = 0; i < 16; i++) {
    state[i] = getSBoxInvert(state[i]);
  }
}

void invShiftRows(unsigned char *state) {
  for (int row = 0; row < 4; row++) {
    invShiftRow(state + row * 4, row);
  }
}

void invShiftRow(unsigned char *state, unsigned char nbr) {
  unsigned char temp[4];

  // Perform rotation to the right by `nbr` positions
  for (int i = 0; i < 4; i++) {
    temp[i] = state[(i - nbr + 4) % 4];
  }

  // Copy back the rotated values
  for (int i = 0; i < 4; i++) {
    state[i] = temp[i];
  }
}

void invMixColumns(unsigned char *state) {
  unsigned char column[4];

  for (int col = 0; col < 4; col++) {
    // Extract one column (4 bytes from each row)
    for (int row = 0; row < 4; row++) {
      column[row] = state[row * 4 + col];
    }

    // Apply inverse MixColumn transformation
    invMixColumn(column);

    // Store transformed column back into the state
    for (int row = 0; row < 4; row++) {
      state[row * 4 + col] = column[row];
    }
  }
}

void invMixColumn(unsigned char *column) {
  unsigned char a[4];

  for (int i = 0; i < 4; i++)
    a[i] = column[i];

  unsigned char a0_14 = gfmul(a[0], 14);
  unsigned char a1_11 = gfmul(a[1], 11);
  unsigned char a2_13 = gfmul(a[2], 13);
  unsigned char a3_9  = gfmul(a[3],  9);

  unsigned char a0_9  = gfmul(a[0],  9);
  unsigned char a1_14 = gfmul(a[1], 14);
  unsigned char a2_11 = gfmul(a[2], 11);
  unsigned char a3_13 = gfmul(a[3], 13);

  unsigned char a0_13 = gfmul(a[0], 13);
  unsigned char a1_9  = gfmul(a[1],  9);
  unsigned char a2_14 = gfmul(a[2], 14);
  unsigned char a3_11 = gfmul(a[3], 11);

  unsigned char a0_11 = gfmul(a[0], 11);
  unsigned char a1_13 = gfmul(a[1], 13);
  unsigned char a2_9  = gfmul(a[2],  9);
  unsigned char a3_14 = gfmul(a[3], 14);

  column[0] = a0_14 ^ a1_11 ^ a2_13 ^ a3_9;
  column[1] = a0_9  ^ a1_14 ^ a2_11 ^ a3_13;
  column[2] = a0_13 ^ a1_9  ^ a2_14 ^ a3_11;
  column[3] = a0_11 ^ a1_13 ^ a2_9  ^ a3_14;
}

void aes_invRound(unsigned char *state, unsigned char *roundKey) {

  invShiftRows(state);
  invSubBytes(state);
  addRoundKey(state, roundKey);
  invMixColumns(state);
}

void aes_invCipher(unsigned char *state, unsigned char *expandedKey, int nbrRounds) {
  unsigned char roundKey[16];

  // Initial round key for final round
  createRoundKey(expandedKey + 16 * nbrRounds, roundKey);
  addRoundKey(state, roundKey);

  // Inverse rounds (excluding final round)
  for (int round = nbrRounds - 1; round > 0; round--) {
    createRoundKey(expandedKey + 16 * round, roundKey);
    aes_invRound(state, roundKey);
  }

  // Final inverse round (no invMixColumns)
  createRoundKey(expandedKey, roundKey);
  invShiftRows(state);
  invSubBytes(state);
  addRoundKey(state, roundKey);
}

char aes_decrypt(unsigned char *input, unsigned char *output,
                 unsigned char *key, enum keySize size) {
  int nbrRounds;
  int expandedKeySize;
  unsigned char block[16];

  // Determine the number of rounds based on key size
  switch (size) {
    case SIZE_16: nbrRounds = 10; break;
    case SIZE_24: nbrRounds = 12; break;
    case SIZE_32: nbrRounds = 14; break;
    default: return ERROR_AES_UNKNOWN_KEYSIZE;
  }

  expandedKeySize = 16 * (nbrRounds + 1);
  unsigned char expandedKey[expandedKeySize];

  // Transpose input (column-major block for AES)
  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 4; col++) {
      block[row + 4 * col] = input[4 * row + col];
    }
  }

  // Key expansion
  KeyExpansion(expandedKey, key, size, expandedKeySize);

  // Decrypt
  aes_invCipher(block, expandedKey, nbrRounds);

  // Transpose back into output (row-major)
  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 4; col++) {
      output[4 * row + col] = block[row + 4 * col];
    }
  }

  return SUCCESS;
}

int main(int argc, char *argv[]) {

  // Rounds: Number of AES rounds
  // Words/Key: Number of 32-bit words per round key (Nb = 4 for AES)
  // Round Keys: Total words in expanded key = Nb × (Rounds + 1)
  // KeyExp (B): Key expansion size in bytes = Round Keys × 4
  // Block (B): Block size in bytes = 128 bits / 8 = 16

  //+-----------+ Block Size | Rounds | Words/Key | Round Keys | KeyExp (B) | Block (B) |
  //|-----------|------------|--------|-----------|------------|------------|-----------|
  //| AES-128   | 128 bits   | 10     | 4         | 44         | 176        | 16        |
  //| AES-192   | 128 bits   | 12     | 4         | 52         | 208        | 16        |
  //| AES-256   | 128 bits   | 14     | 4         | 60         | 240        | 16        |
  //+-----------+------------+--------+-----------+------------+------------+-----------+

  // the expanded keySize to store full set of round keys (change according to table)
  int expandedKeySize = 176;

  // the cipher key size defined on Line 81 (change for different AES key)
  enum keySize size = SIZE_16;

  unsigned char expandedKey[expandedKeySize];

  // the cipher key (FIPS 197 example (page 28) 128-bit Cipher Key in Appendix A)
  unsigned char key[16] = {0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
                           0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c};

  // (FIPS 197 example (page 34) in Appendix B)
  // AES uses an internal structure called the state, which is a 4x4 byte matrix (16 bytes total).
  // AES operates on 128-bit blocks (16 bytes), always — regardless of key size (128, 192, 256).
  unsigned char plaintext[16] = {0x32, 0x43, 0xf6, 0xa8, 0x88, 0x5a, 0x30, 0x8d,
                                 0x31, 0x31, 0x98, 0xa2, 0xe0, 0x37, 0x07, 0x34};

  unsigned char ciphertext[16];
  unsigned char decryptedtext[16];
  int i;

  printf("\nCipher Key (hex format):\n");
  for (i = 0; i < 16; i++) {
    printf("%2.2x%c", key[i], ((i + 1) % 16) ? ' ' : '\n');
  }

  KeyExpansion(expandedKey, key, size, expandedKeySize);
  printf("\nExpanded Key (hex format):\n");
  for (i = 0; i < expandedKeySize; i++) {
    printf("%2.2x%c", expandedKey[i], ((i + 1) % 16) ? ' ' : '\n');
  }

  printf("\nPlaintext (hex format):\n");
  for (i = 0; i < 16; i++) {
    printf("%2.2x%c", plaintext[i], ((i + 1) % 16) ? ' ' : '\n');
  }

  // AES Encryption
  aes_encrypt(plaintext, ciphertext, key, size);
  printf("\nCiphertext (hex format):\n");
  for (i = 0; i < 16; i++) {
    printf("%02x%c", ciphertext[i], ((i + 1) % 16) ? ' ' : '\n');
  }

  // AES Decryption
  aes_decrypt(ciphertext, decryptedtext, key, size);
  printf("\nDecrypted text (hex format):\n");
  for (i = 0; i < 16; i++) {
    printf("%2.2x%c", decryptedtext[i], ((i + 1) % 16) ? ' ' : '\n');
  }

  return 0;
}
