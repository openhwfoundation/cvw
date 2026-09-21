.section .text
.global _start

_start:
    la sp, topofstack               # Initialize stack pointer
    la s4, key
    la a0, ciphertext
    la a1, plaintext

    # Load plaintext
    ld s0, 0(a1)
    ld s1, 8(a1)

    # Copy initial 128-bit key into key_schedule
    ld s2, 0(s4)                        # First 64 bits - {w3, w2}
    ld s3, 8(s4)                        # Second 64 bits - {w1, w0}

    # Store initial state in signature
    la s11, begin_signature
    csrr s8, instret                # count instructions at beginning
    addi sp, sp, -8                     # Allocate 8 bytes on the stack
    sd s8,  0(sp)                       # Save instreg on the stack

    xor s0, s0, s2                  # state0 ^= roundkey0
    xor s1, s1, s3                  # state1 ^= roundkey1

    # Set round counter (i = 1)
    li s4, 1                            # round index (1-based)
    li s5, 10                           # total number of additional rounds

    # key_ptr points to start of last written round key
    addi s6, s1, 16                     # move to next write location

enc_loop:
    bge s4, s5, final_round

    # Extract high 32 bits from s8 (last word of previous round key)
    srli s9, s3, 32

    # SubWord(s9): apply RotWord and S-box to each byte
    srli a0, s9, 8
    and a0, a0, 0xff                # byte0
    srli a1, s9, 16
    and a1, a1, 0xff                # byte1
    srli a2, s9, 24
    and a2, a2, 0xff                # byte2
    and a3, s9, 0xff                # byte3

    # Lookup each byte in S-box table
    la a4, sbox
    add a5, a4, a0
    lbu a0, 0(a5)
    add a5, a4, a1
    lbu a1, 0(a5)
    add a5, a4, a2
    lbu a2, 0(a5)
    add a5, a4, a3
    lbu a3, 0(a5)

    # Recombine bytes into a word
    slli a1, a1, 8
    or a0, a0, a1
    slli a2, a2, 16
    or a0, a0, a2
    slli a3, a3, 24
    or s9, a0, a3

    # Rcon XOR
    la a5, rcon
    add a5, a5, s4
    lbu a6, -1(a5)                  # rcon[s4-1]
    xor s9, s9, a6                  # SubWord result ^= Rcon

    # Reconstruct new words
    xor s2, s2, s9
    slli a0, s2, 32
    xor s2, s2, a0
    srli a1, s2, 32
    xor s3, s3, a1
    slli a2, s3, 32
    xor s3, s3, a2

    ####################################################
    # Middle AES Round
    aes64esm t0, s0, s1
    aes64esm t1, s1, s0

    xor s0, t0, s2
    xor s1, t1, s3

    addi a2, a2, 16
    addi s4, s4, 1
    j enc_loop

final_round:
    # Extract high 32 bits from s8 (last word of previous round key)
    srli s9, s3, 32

    # SubWord(s9): apply RotWord and S-box to each byte
    srli a0, s9, 8
    and a0, a0, 0xff                # byte0
    srli a1, s9, 16
    and a1, a1, 0xff                # byte1
    srli a2, s9, 24
    and a2, a2, 0xff                # byte2
    and a3, s9, 0xff                # byte3

    # Lookup each byte in S-box table
    la a4, sbox
    add a5, a4, a0
    lbu a0, 0(a5)
    add a5, a4, a1
    lbu a1, 0(a5)
    add a5, a4, a2
    lbu a2, 0(a5)
    add a5, a4, a3
    lbu a3, 0(a5)

    # Recombine bytes into a word
    slli a1, a1, 8
    or a0, a0, a1
    slli a2, a2, 16
    or a0, a0, a2
    slli a3, a3, 24
    or s9, a0, a3

    # Rcon XOR
    la a5, rcon
    add a5, a5, s4
    lbu a6, -1(a5)                  # rcon[s4-1]
    xor s9, s9, a6                  # SubWord result ^= Rcon

    # Reconstruct new words
    xor s2, s2, s9
    slli a0, s2, 32
    xor s2, s2, a0
    srli a1, s2, 32
    xor s3, s3, a1
    slli a2, s3, 32
    xor s3, s3, a2

    #########################################################
    # Final AES round without MixColumns
    aes64es t0, s0, s1
    aes64es t1, s1, s0

    xor s0, t0, s2
    xor s1, t1, s3

    # Store HTIF
    sd s0, 0(s11)
    sd s1, 8(s11)
    addi s11, s11, 16

# Finalize
done:
    ld s8,  0(sp)                       # Restore instret (s8)
    addi sp, sp, 8                      # Deallocate stack space
    csrr s9, instret                # Read instruction count
    sub s9, s9, s8                  # get number of #instructions executed
    sd s9, 0(s11)               # store number of #instructions executed
    addi s11, s11, 8

write_tohost:
    la a0, tohost
    li a1, 1                        # Success code
    sd a1, 0(a0)                    # Send success code

self_loop:
    j self_loop

.section .tohost
tohost:
    .dword 0
fromhost:
    .dword 0

.data
.align 3

.EQU XLEN,64
begin_signature:
    .fill (2+1)*(XLEN/32),4,0xdeadbeef
end_signature:

topofstack:

# FIPS 197 Example Appendix A AES-128 (stored little endian)
plaintext:
  .dword 0x8d305a88a8f64332, 0x340737e0a2983131

key:
  .dword 0xa6d2ae2816157e2b, 0x3c4fcf098815f7ab

rcon:
    .byte 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36

sbox:
    .byte 0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5
    .byte 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76
    .byte 0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0
    .byte 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0
    .byte 0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc
    .byte 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15
    .byte 0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a
    .byte 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75
    .byte 0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0
    .byte 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84
    .byte 0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b
    .byte 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf
    .byte 0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85
    .byte 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8
    .byte 0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5
    .byte 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2
    .byte 0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17
    .byte 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73
    .byte 0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88
    .byte 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb
    .byte 0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c
    .byte 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79
    .byte 0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9
    .byte 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08
    .byte 0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6
    .byte 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a
    .byte 0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e
    .byte 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e
    .byte 0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94
    .byte 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf
    .byte 0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68
    .byte 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16

ciphertext:
    .space 16

.bss
    .space 512
