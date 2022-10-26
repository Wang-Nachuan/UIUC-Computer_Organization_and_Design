test_jump.s:
.align 4
.section .text
.globl _start
    
_start:

    # Init
    add x1, x0, x0
    add x2, x0, x0
    add x3, x0, x0

    # Test jal
    la x2, j_1_ret
    jal x1, j_1
j_1_ret:
    add x4, x0, x0      # Place holder
    add x4, x0, x0
j_1:
    beq x1, x2, j_1_true
j_1_false:
    add x3, x3, 0
    j j_1_end
j_1_true:
    add x3, x3, 1
j_1_end:

    # Test jalr
    la x2, j_2
    jalr x1, x2
j_2_ret: 
    add x4, x0, x0      # Place holder
    add x4, x0, x0
j_2:
    la x2, j_2_ret
    beq x1, x2, j_2_true
j_2_false:
    add x3, x3, 0
    j deadloop
j_2_true:
    add x3, x3, 1

deadloop:
    beq x0, x0, deadloop

.section .rodata