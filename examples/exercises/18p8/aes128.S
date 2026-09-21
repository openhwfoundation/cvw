.section .text
.global _start

_start:
    la a0, ciphertext
    la a1, plaintext
    la a2, key_schedule

    # Load plaintext
    ld s0, 0(a1)
    ld s1, 8(a1)
    # Load plaintext
    ld s2, 0(a2)
    ld s3, 8(a2)

    # Store initial state in signature
    la s11, begin_signature

    csrr s8, instret                # count instructions at beginning

    xor s0, s0, s2                  # state0 ^= roundkey0
    xor s1, s1, s3                  # state1 ^= roundkey1

    # Initialize loop counter and max rounds
    li s4, 1
    li s5, 10
    addi a2, a2, 16

enc_loop:
    bge s4, s5, final_round

    # Load next round key pair into s2/s3
    ld s2, 0(a2)
    ld s3, 8(a2)

    aes64esm t2, s0, s1
    aes64esm t3, s1, s0

    xor s0, t2, s2
    xor s1, t3, s3

    addi a2, a2, 16
    addi s4, s4, 1
    j enc_loop

final_round:

   # Load final round key
    ld s2, 0(a2)
    ld s3, 8(a2)

    # Final AES round without MixColumns
    aes64es t2, s0, s1
    aes64es t3, s1, s0

    xor s0, t2, s2
    xor s1, t3, s3

    # Print out through HTIF
    sd s0, 0(s11)
    sd s1, 8(s11)
    addi s11, s11, 16

    # Store ciphertext
    sd a4, 0(a0)
    sd a5, 8(a0)

# Finalize
done:
    csrr s9, instret                # Read instruction count
    sub s9, s9, s8                  # get number of #instructions executed
    sd s9, 0(s11)

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

# FIPS 197 Example Appendix A AES-128 (stored little endian)
plaintext:
  .dword 0x8d305a88a8f64332, 0x340737e0a2983131

key:
  .dword 0xa6d2ae2816157e2b, 0x3c4fcf098815f7ab

# Key Expansion Example Appendix B AES-128
key_schedule:
  .dword 0xa6d2ae2816157e2b, 0x3c4fcf098815f7ab  # Round 0
  .dword 0xb12c548817fefaa0, 0x05766c2a3939a323  # Round 1
  .dword 0x43b9967af295c2f2, 0x7ff659737a803559  # Round 2
  .dword 0x3efe16477d47803d, 0x3b887a6d447e231e  # Round 3
  .dword 0x7f5b52a841a544ef, 0x00ad0bdb3b2571b6  # Round 4
  .dword 0x879d837cf8c6d1d4, 0xbc15f911bcb8f2ca  # Round 5
  .dword 0xfd3e0b117aa3886d, 0xfd9300ca4186f9db  # Round 6
  .dword 0xf3c95f5f0ef7544e, 0x4fdca64eb24fa684  # Round 7
  .dword 0xd2ba8db52173d2ea, 0x2f298d7f60f52b31  # Round 8
  .dword 0x21dcfa19f36677ac, 0x6e005c574129d128  # Round 9
  .dword 0x8925eec9a8f914d0, 0xa60c63b6c80c3fe1  # Round 10

ciphertext:
    .space 16

.bss
    .space 512
