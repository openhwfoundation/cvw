#!/usr/bin/env -S uv run --script
# sha256.py
# Secure Hash Algorithm - SHA-256
# james.stine@okstate.edu 5 Sept 2024

import hashlib

# SHA256 Constants (See FIPS 180 4.2.2)
K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
]

def sigma0(num: int):
    num = (ror(num, 7) ^ ror(num, 18) ^ (num >> 3))
    return num


def sigma1(num: int):
    num = (ror(num, 17) ^ ror(num, 19) ^ (num >> 10))
    return num


def Sigma0(num: int):
    num = (ror(num, 2) ^ ror(num, 13) ^ ror(num, 22))
    return num


def Sigma1(num: int):
    num = (ror(num, 6) ^ ror(num, 11) ^ ror(num, 25))
    return num


def ch(x: int, y: int, z: int):
    return (x & y) ^ (~x & z)


def maj(x: int, y: int, z: int):
    return (x & y) ^ (x & z) ^ (y & z)


def ror(num: int, shift: int, size: int = 32):
    return (num >> shift) | (num << size - shift)


def generate_hash(message: bytearray) -> bytearray:
    """
        generate SHA256 Hash Function
    """

    if isinstance(message, str):
        message = bytearray(message, 'ascii')
    elif isinstance(message, bytes):
        message = bytearray(message)
    elif not isinstance(message, bytearray):
        raise TypeError

    # Padding
    length = len(message) * 8  # len(message) is number of BYTES!!!
    message.append(0x80)
    while (len(message) * 8 + 64) % 512 != 0:
        message.append(0x00)
    message += length.to_bytes(8, 'big')  # pad to 8 bytes or 64 bits
    assert (len(message) * 8) % 512 == 0, "Padding did not complete properly!"

    # Parsing
    blocks = []  # contains 512-bit chunks of message
    for i in range(0, len(message), 64):  # 64 bytes is 512 bits
        blocks.append(message[i:i+64])

    # Setting Initial Hash Value (See FIPS 180 5.3.3)
    h0 = 0x6a09e667
    h1 = 0xbb67ae85
    h2 = 0x3c6ef372
    h3 = 0xa54ff53a
    h5 = 0x9b05688c
    h4 = 0x510e527f
    h6 = 0x1f83d9ab
    h7 = 0x5be0cd19

    # SHA-256 Hash Computation (See FIPS 180 6.2.1)
    for message_block in blocks:
        # Prepare message schedule
        message_schedule = []
        for t in range(0, 64):
            if t <= 15:
                # 4 bytes at a time
                message_schedule.append(bytes(message_block[t*4:(t*4)+4]))
                word = int.from_bytes(message_schedule[t], 'big')
                print(f"W_{t:02} = 0x{word:08x}")
            else:
                term1 = sigma1(int.from_bytes(message_schedule[t-2], 'big'))
                term2 = int.from_bytes(message_schedule[t-7], 'big')
                term3 = sigma0(int.from_bytes(message_schedule[t-15], 'big'))
                term4 = int.from_bytes(message_schedule[t-16], 'big')

                # append a 4-byte byte object
                schedule = ((term1 + term2 + term3 + term4) %
                            2**32).to_bytes(4, 'big')
                message_schedule.append(schedule)
                print("W_" + str(t) + " = " +
                      hex(int.from_bytes(message_schedule[t], 'big')))

        assert len(message_schedule) == 64
        print("-------------")

        # Initialize working variables
        a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
        print("Initial working variables:")
        print("a = " + hex(a))
        print("b = " + hex(b))
        print("c = " + hex(c))
        print("d = " + hex(d))
        print("e = " + hex(e))
        print("f = " + hex(f))
        print("g = " + hex(g))
        print("h = " + hex(h))
        print("-------------")

        # Compression Function (See FIPS 180 6.2.2)
        for t in range(64):
            # addition module 2^{32}
            t1 = ((h + Sigma1(e) + ch(e, f, g) + K[t] +
                   int.from_bytes(message_schedule[t], 'big')) % 2**32)
            t2 = (Sigma0(a) + maj(a, b, c)) % 2**32
            h = g
            g = f
            f = e
            e = (d + t1) % 2**32
            d = c
            c = b
            b = a
            a = (t1 + t2) % 2**32
            print("Step " + str(t))
            print("a = " + hex(a))
            print("b = " + hex(b))
            print("c = " + hex(c))
            print("d = " + hex(d))
            print("e = " + hex(e))
            print("f = " + hex(f))
            print("g = " + hex(g))
            print("h = " + hex(h))
            print("-------------")

        # Compute intermediate hash value
        h0 = (h0 + a) % 2**32
        h1 = (h1 + b) % 2**32
        h2 = (h2 + c) % 2**32
        h3 = (h3 + d) % 2**32
        h4 = (h4 + e) % 2**32
        h5 = (h5 + f) % 2**32
        h6 = (h6 + g) % 2**32
        h7 = (h7 + h) % 2**32

    return ((h0).to_bytes(4, 'big') + (h1).to_bytes(4, 'big') +
            (h2).to_bytes(4, 'big') + (h3).to_bytes(4, 'big') +
            (h4).to_bytes(4, 'big') + (h5).to_bytes(4, 'big') +
            (h6).to_bytes(4, 'big') + (h7).to_bytes(4, 'big'))


if __name__ == "__main__":
    msg = "Go Wally!"
    digest = generate_hash(msg)
    print(f"Computed SHA-256: {digest.hex()}")
    print(f"Expected SHA-256: {hashlib.sha256(msg.encode()).hexdigest()}")
