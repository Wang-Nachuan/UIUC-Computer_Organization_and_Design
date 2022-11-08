cpu_inst_br_sign.s:
.align 4
.section .text
.globl _start

    # True if x5 is always incremented by 1

    li x1, 0x00000010
    li x2, 0x00000020
    li x3, 0xffffff10 
    li x4, 0xffffff20
    andi x5, x5, 0

    # blt
    blt x1, x2, blt_true_0
blt_false_0:
    addi x5, x5, 8
    beq x0, x0, next_1
blt_true_0:
    addi x5, x5, 1
    beq x0, x0, next_1

next_1:
    blt x3, x4, blt_true_1
blt_false_1:
    addi x5, x5, 8
    beq x0, x0, next_2
blt_true_1:
    addi x5, x5, 1
    beq x0, x0, next_2

next_2:
    blt x1, x3, blt_true_2
blt_false_2:
    addi x5, x5, 1
    beq x0, x0, next_3
blt_true_2:
    addi x5, x5, 8
    beq x0, x0, next_3

next_3:
    blt x4, x2, blt_true_3
blt_false_3:
    addi x5, x5, 8
    beq x0, x0, next_4
blt_true_3:
    addi x5, x5, 1
    beq x0, x0, next_4

    # bge
next_4:
    bge x1, x1, bge_true_4
bge_false_4:
    addi x5, x5, 8
    beq x0, x0, next_5
bge_true_4:
    addi x5, x5, 1
    beq x0, x0, next_5

next_5:
    bge x1, x2, bge_true_5
bge_false_5:
    addi x5, x5, 1
    beq x0, x0, next_6
bge_true_5:
    addi x5, x5, 8
    beq x0, x0, next_6

next_6:
    bge x3, x1, bge_true_6
bge_false_6:
    addi x5, x5, 1
    beq x0, x0, next_7
bge_true_6:
    addi x5, x5, 8
    beq x0, x0, next_7

next_7:
    bge x3, x4, bge_true_7
bge_false_7:
    addi x5, x5, 1
    beq x0, x0, deadloop
bge_true_7:
    addi x5, x5, 8
    beq x0, x0, deadloop

deadloop:
    beq x0, x0, deadloop
