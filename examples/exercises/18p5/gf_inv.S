.text

.global rvtest_entry_point
rvtest_entry_point:

    li a0, 0x43        # Input value to invert in GF(2^8)
    li t0, 0x11B       # Modulus: irreducible poly x^8 + x^4 + x^3 + x + 1

    # Initialize Extended Euclidean variables: a*x+b*y=gcd(a,b)
    li t1, 0           # s0 = 0 (old x)
    li t2, 1           # s1 = 1 (new x)
    mv t3, t0          # r0 = modulus
    mv t4, a0          # r1 = input value

    csrr s8, instret   # count instructions at beginning

    # --- Register usage ---
    # a0: Input / Final result (return value)
    # t0: Modulus (0x11B)
    # t1: s0 (previous x value)
    # t2: s1 (current x value)
    # t3: r0 (previous remainder)
    # t4: r1 (current remainder)
    # t5: degree(r0)
    # t6: degree(r1)
    # a1: argument to gf_degree
    # a2: shift amount
    # a3: temporary for SLT result
    # a4/a5: shift results, temporaries
    # s8: initial seed of instruction count (instret)
    # s9: final value of instruction count (instret)

# --------------------------------------
# Main loop: Extended Euclidean Division
# --------------------------------------
inv_loop:
    beqz t4, fail           # If r1 == 0, input is not invertible → fail

    # Compute degree of r0
    mv a1, t3               # Set a1 = r0 = (modulus m)
    call gf_degree          # Compute deg(r0)
    mv t5, a0           # degree(r0)

    # Compute degree of r1
    mv a1, t4               # Set a1 = r1 = (input a)
    call gf_degree          # Compute deg(r1)
    mv t6, a0           # degree (r1)

    # Compute shift = deg(r0) - deg(r1)
    sub a2, t5, t6      # alignment r1 with highest term in r0
    slt a3, a2, zero        # Check if shift < 0
    bnez a3, swap_and_negate

    # Perform r0 ^= r1 << shift
    # Polynomial subtraction in GF(2)
    sll a4, t4, a2
    xor t3, t3, a4
    andi t3, t3, 0x1FF      # Mask off 9 bits to stay in GF(2^8)

    # Update s0: s0 ^= s1 << shift - Update Bezout coefficient
    sll a5, t2, a2
    xor t1, t1, a5
    andi t1, t1, 0x1FF      # Mask off 9 bits to stay in GF(2^8)

    # Swap (r0, r1)
    mv a4, t3
    mv t3, t4
    mv t4, a4

    # Swap (s0, s1)
    mv a4, t1
    mv t1, t2
    mv t2, a4

    # Check if r0 == 1, then we are done
    li t5, 1
    beq t3, t5, done

    j inv_loop

# -------------------------------------------
# Case: shift < 0 → negate, then apply shift
# -------------------------------------------
swap_and_negate:
    # Swap r0 <-> r1
    mv a4, t3
    mv t3, t4
    mv t4, a4

    # Swap s0 <-> s1
    mv a4, t1
    mv t1, t2
    mv t2, a4

    # shift = -shift
    sub a2, zero, a2

    # r0 ^= r1 << shift
    sll a4, t4, a2
    xor t3, t3, a4
    andi t3, t3, 0x1FF      # Mask off to 9 bits again

    # s0 ^= s1 << shift
    sll a5, t2, a2
    xor t1, t1, a5
    andi t1, t1, 0x1FF

    # Final swap to maintain invariant
    mv a4, t3
    mv t3, t4
    mv t4, a4

    mv a4, t1
    mv t1, t2
    mv t2, a4

    # Check if r0 == 1
    li t5, 1
    beq t3, t5, done

    j inv_loop

# -------------------------------------
# Helper: compute degree of a1 (MSB set)
# -------------------------------------
gf_degree:
    li t0, 8                # Start checking from MSB down
deg_loop:
    srl a0, a1, t0          # Right shift a1 by t0
    andi a0, a0, 1          # Isolate LSB
    bnez a0, done_deg       # If bit is set, we're done
    addi t0, t0, -1
    bgez t0, deg_loop       # Check next bit
    li a0, 0                # Nothing set
    ret
done_deg:
    mv a0, t0
    ret

# ---------------------
# Finalize inverse
# ---------------------
done:
    mv a0, t1               # Result is a0
    andi a0, a0, 0xFF       # Mask to 8 bits
    csrr s9, instret        # count instructions at end
    sub s9, s9, s8          # get number of #instructions executed

write_tohost:           # HTIF stuff
    la t1, tohost
    li t0, 1                # 1 for success, 3 for failure
    sw t0, 0(t1)            # send success code

    la t0, begin_signature  # Address of signature
    sw a0, 0(t0)                # Store result (i.e., a0)
    sw s9, 4(t0)                # record #instructions executed

fail:
    li a0, 0xff         # Signal failure: no inverse exists

self_loop:
    j self_loop

.section .tohost
tohost:                     # write to HTIF
    .word 0
fromhost:
    .word 0

.data
.EQU XLEN,32
begin_signature:
    .fill 2*(XLEN/32),4,0xdeadbeef
end_signature:


.bss
    .space 512
