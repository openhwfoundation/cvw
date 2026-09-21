.section .text
.global _start

# Elaborated routines based on https://github.com/riscv/riscv-crypto
_start:
    la a0, ciphertext
    la a1, plaintext
    la a2, key_schedule

    # Load plaintext into state registers (a4, a5, a6, a7)
    lw a4, 0(a1)
    lw a5, 4(a1)
    lw a6, 8(a1)
    lw a7, 12(a1)

    # Store initial state in signature
    la s11, begin_signature

    # Round 0: AddRoundKey
    lw t0, 0(a2)
    lw t1, 4(a2)
    lw t2, 8(a2)
    lw t3, 12(a2)

    csrr s8, instret                # count instructions at beginning

    # XOR state with round key
    xor a4, a4, t0
    xor a5, a5, t1
    xor a6, a6, t2
    xor a7, a7, t3

    # Initialize loop counter and max rounds
    li t4, 1
    li t5, 10
    addi a2, a2, 16

enc_loop:
    bge t4, t5, final_round

    # AES round: SubBytes, ShiftRows, MixColumns, AddRoundKey
    # Compute new column 0
    aes32esmi t0, zero, a4, 0
    aes32esmi t0, t0,   a5, 1
    aes32esmi t0, t0,   a6, 2
    aes32esmi t0, t0,   a7, 3

    # Compute new column 1
    aes32esmi t1, zero, a5, 0
    aes32esmi t1, t1,   a6, 1
    aes32esmi t1, t1,   a7, 2
    aes32esmi t1, t1,   a4, 3

    # Compute new column 2
    aes32esmi t2, zero, a6, 0
    aes32esmi t2, t2,   a7, 1
    aes32esmi t2, t2,   a4, 2
    aes32esmi t2, t2,   a5, 3

    # Compute new column 3
    aes32esmi t3, zero, a7, 0
    aes32esmi t3, t3,   a4, 1
    aes32esmi t3, t3,   a5, 2
    aes32esmi t3, t3,   a6, 3

    # Load next round key
    lw s0, 0(a2)
    lw s1, 4(a2)
    lw s2, 8(a2)
    lw s3, 12(a2)

    # Update state: XOR with round key
    xor a4, t0, s0
    xor a5, t1, s1
    xor a6, t2, s2
    xor a7, t3, s3

    # Increment key schedule pointer and loop counter
    addi a2, a2, 16
    addi t4, t4, 1

    j enc_loop

final_round:
    # Final round: SubBytes, ShiftRows, AddRoundKey (no MixColumns)
    aes32esi t0, zero, a4, 0
    aes32esi t0, t0, a5, 1
    aes32esi t0, t0, a6, 2
    aes32esi t0, t0, a7, 3

    aes32esi t1, zero, a5, 0
    aes32esi t1, t1, a6, 1
    aes32esi t1, t1, a7, 2
    aes32esi t1, t1, a4, 3

    aes32esi t2, zero, a6, 0
    aes32esi t2, t2, a7, 1
    aes32esi t2, t2, a4, 2
    aes32esi t2, t2, a5, 3

    aes32esi t3, zero, a7, 0
    aes32esi t3, t3, a4, 1
    aes32esi t3, t3, a5, 2
    aes32esi t3, t3, a6, 3

    # Load final round key
    lw a4, 0(a2)
    lw a5, 4(a2)
    lw a6, 8(a2)
    lw a7, 12(a2)

    # XOR with final round key
    xor a4, t0, a4
    xor a5, t1, a5
    xor a6, t2, a6
    xor a7, t3, a7

    # DEBUG
    sw a4, 0(s11)
    sw a5, 4(s11)
    sw a6, 8(s11)
    sw a7, 12(s11)
    addi s11, s11, 16

    # Store ciphertext
    sw a4, 0(a0)
    sw a5, 4(a0)
    sw a6, 8(a0)
    sw a7, 12(a0)

# Finalize
done:
    csrr s9, instret                # Read instruction count
    sub s9, s9, s8                  # get number of #instructions executed
    sw s9, 0(s11)

write_tohost:
    la t1, tohost
    li t0, 1                        # Success code
    sw t0, 0(t1)                    # Send success code

self_loop:
    j self_loop

.section .tohost
tohost:
    .word 0
fromhost:
    .word 0

.data
.align 4

.EQU XLEN,32
begin_signature:
    .fill (4+1)*(XLEN/32),4,0xdeadbeef
end_signature:

# FIPS 197 Example Appendix A AES-128 (stored little endian)
plaintext:
    .word 0xa8f64332, 0x8d305a88, 0xa2983131, 0x340737e0

# Key Expansion Example Appendix B AES-128
key_schedule:
    .word 0x16157e2b, 0xa6d2ae28, 0x8815f7ab, 0x3c4fcf09  # Round 0
    .word 0x17fefaa0, 0xb12c5488, 0x3939a323, 0x05766c2a  # Round 1
    .word 0xf295c2f2, 0x43b9967a, 0x7a803559, 0x7ff65973  # Round 2
    .word 0x7d47803d, 0x3efe1647, 0x447e231e, 0x3b887a6d  # Round 3
    .word 0x41a544ef, 0x7f5b52a8, 0x3b2571b6, 0x00ad0bdb  # Round 4
    .word 0xf8c6d1d4, 0x879d837c, 0xbcb8f2ca, 0xbc15f911  # Round 5
    .word 0x7aa3886d, 0xfd3e0b11, 0x4186f9db, 0xfd9300ca  # Round 6
    .word 0x0ef7544e, 0xf3c95f5f, 0xb24fa684, 0x4fdca64e  # Round 7
    .word 0x2173d2ea, 0xd2ba8db5, 0x60f52b31, 0x2f298d7f  # Round 8
    .word 0xf36677ac, 0x21dcfa19, 0x4129d128, 0x6e005c57  # Round 9
    .word 0xa8f914d0, 0x8925eec9, 0xc80c3fe1, 0xa60c63b6  # Round 10

ciphertext:
    .space 16

.bss
    .space 512
