.section .text
.global _start

_start:
    la sp, topofstack               # Initialize stack pointer
    # Load initial hash state into a0–a7
    la t0, H
    lw a0, 0(t0)
    lw a1, 4(t0)
    lw a2, 8(t0)
    lw a3, 12(t0)
    lw a4, 16(t0)
    lw a5, 20(t0)
    lw a6, 24(t0)
    lw a7, 28(t0)

    # Store initial state in signature
    la s11, begin_signature
    csrr s10, instret               # count instructions at beginning

    la s0, M                    # Load point to padded message
    la s1, W                    # See NIST 180-4 6.2.2
    li t1, 0                    # Initialize counter (t)

load_loop:
    lw t2, 0(s0)
    sw t2, 0(s1)
    addi s0, s0, 4              # increment source M ptr
    addi s1, s1, 4              # increment destination W ptr
    addi t1, t1, 1              # increment t
    li t3, 16
    blt t1, t3, load_loop

    # Let's now compute W[16] to W[63]
    la s1, W
    li t1, 16

gen_loop:
    slli t2, t1, 2              # addr{W[16]} <- 16 * 4 (XLEN=32)
    add t3, s1, t2              # Compute addr{W[16]}

    lw t4, -8(t3)               # W_{t-2}
    lw t5, -28(t3)              # W_{t-7}
    lw t6, -60(t3)              # W_{t-15}
    lw t0, -64(t3)              # W_{t-16}

    sha256sig1 t4, t4               # Sigma1 transformation
    sha256sig0 t6, t6               # Sigma0 transofmration

    add t4, t4, t5              # temp = Sigma1+W_{t-7}
    add t4, t4, t6              # temp = temp + Sigma0
    add t4, t4, t0              # Message Schedule W_t

    sw t4, 0(t3)                # Store W_t

    addi t1, t1, 1
    li t5, 64
    blt t1, t5, gen_loop

    # Working variables: s2–s9 = a-h
    addi sp, sp, -64                    # Allocate 64 bytes on the stack
    mv s2, a0                   # a
    mv s3, a1                   # b
    mv s4, a2                   # c
    mv s5, a3                   # d
    mv s6, a4                   # e
    mv s7, a5                   # f
    mv s8, a6                   # g
    mv s9, a7                   # h

    sw s2,  0(sp)                       # Save a on the stack
    sw s3,  4(sp)                       # Save b on the stack
    sw s4,  8(sp)                       # Save c on the stack
    sw s5, 12(sp)                       # Save d on the stack
    sw s6, 16(sp)                       # Save e on the stack
    sw s7, 20(sp)                       # Save f on the stack
    sw s8, 24(sp)                       # Save g on the stack
    sw s9, 28(sp)                       # Save h on the stack

    li t0, 0                        # schedule counter
    la t1, K
    la t2, W

# Compression Function
sha_round:
    slli t3, t0, 2
    add t4, t1, t3
    lw t5, 0(t4)                    # K[t]

    add t4, t2, t3
    lw t6, 0(t4)                    # W[t]

    sha256sum1 a0, s6               # Sum1 transformation
    and a1, s6, s7                  # a1 = x & y
    not a2, s6                      # a2 = ~x
    and a2, a2, s8                  # a2 = ~x & z
    xor a1, a1, a2
    add a2, a0, a1
    add a2, a2, s9
    add a2, a2, t5              # Ch = a1 = (x & y) ^ (~x & z) (4 instructions)
    add a2, a2, t6                  # T1 = h + SUM1(e) + Ch(e,f,g) + K[i] + W[i]

    sha256sum0 a3, s2               # Sum0 transformation
    and a4, s2, s3                              # a4 = a & b
    and a5, s2, s4                              # a5 = a & c
    xor a4, a4, a5                              # a4 = (a & b) ^ (a & c)
    and a5, s3, s4                              # a5 = b & c
    xor a4, a4, a5                              # a4 = Maj(a, b, c) (5 instructions)
    add a5, a3, a4                  # T2 = SUM0(a) + Maj(a,b,c)

    # Compression Function Shift
    mv s9, s8                   # h
    mv s8, s7                   # g
    mv s7, s6                   # f
    add s6, s5, a2              # e = d+T1
    mv s5, s4                   # d
    mv s4, s3                   # c
    mv s3, s2                   # b
    add s2, a2, a5              # a = T1+T2

    addi t0, t0, 1              # Modify branch ctr for t
    li a7, 64
    blt t0, a7, sha_round

    # Restore eight working variables
    lw a0,  0(sp)                       # Restore a0 (a)
    lw a1,  4(sp)                       # Restore a1 (b)
    lw a2,  8(sp)                       # Restore a2 (c)
    lw a3, 12(sp)                       # Restore a3 (d)
    lw a4, 16(sp)                       # Restore a4 (e)
    lw a5, 20(sp)                       # Restore a5 (f)
    lw a6, 24(sp)                       # Restore a6 (g)
    lw a7, 28(sp)                       # Restore a7 (h)
    addi sp, sp, 64                     # Deallocate stack space

    # Intermediate Hash (e.g., H_0^i = a + H_0^{i-1})
    add a0, a0, s2              # H0
    add a1, a1, s3              # H1
    add a2, a2, s4              # H2
    add a3, a3, s5              # H3
    add a4, a4, s6              # H4
    add a5, a5, s7              # H5
    add a6, a6, s8              # H6
    add a7, a7, s9              # H7

    # Print out hash value or digest
    sw a0, 0(s11)
    sw a1, 4(s11)
    sw a2, 8(s11)
    sw a3, 12(s11)
    sw a4, 16(s11)
    sw a5, 20(s11)
    sw a6, 24(s11)
    sw a7, 28(s11)
    addi s11, s11, 32

# Finalize
done:
    csrr s9, instret                # Read instruction count
    sub s9, s9, s10                 # get number of #instructions executed
    sw s9, 0(s11)               # Print instruction count

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
    .fill (8*1+1)*(XLEN/32),4,0xdeadbeef
end_signature:

# Initial SHA-256 hash values (NIST 180-4 5.3.3)
H:
    .word 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    .word 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

# K constants for SHA-256 (NIST 180-4 4.2.2)
K:
    .word 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5
    .word 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
    .word 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3
    .word 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174

    .word 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc
    .word 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
    .word 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7
    .word 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967

    .word 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13
    .word 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
    .word 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3
    .word 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070

    .word 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5
    .word 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
    .word 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208
    .word 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2

# One padded 512-bit block for message "Go Wally!"
M:
    .word 0x476f2057, 0x616c6c79, 0x21800000, 0x00000000
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000000
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000000
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000048

# Space for W[0..63] (64 x 4 bytes)
W:
     .skip 256

.bss
    .space 512
topofstack:
