cpu_inst_br_unsign.s:
.align 4
.section .text
.globl _start

    # True if x3 is always incremented by 1
    
    li x1, 8
    li x2, -8
    and x3, x3, x0

    # beq
    beq x1, x2, beq_true_0
beq_false_0:
    addi x3, x3, 1
    beq x0, x0, next_1
beq_true_0:
    addi x3, x3, 8
    beq x0, x0, next_1

next_1:
    beq x2, x2, beq_true_1
beq_false_1:
    addi x3, x3, 8
    beq x0, x0, next_2
beq_true_1:
    addi x3, x3, 1
    beq x0, x0, next_2

    # bne
next_2:
    bne x1, x2, bne_true_2
bne_false_2:
    addi x3, x3, 8
    beq x0, x0, next_3
bne_true_2:
    addi x3, x3, 1
    beq x0, x0, next_3

next_3:
    bne x1, x1, bne_true_3
bne_false_3:
    addi x3, x3, 1
    beq x0, x0, next_4
bne_true_3:
    addi x3, x3, 8
    beq x0, x0, next_4

    # bltu
next_4:
    bltu x1, x2, bltu_true_4
bltu_false_4:
    addi x3, x3, 8
    beq x0, x0, next_5
bltu_true_4:
    addi x3, x3, 1
    beq x0, x0, next_5

next_5:
    bltu x2, x2, bltu_true_5
bltu_false_5:
    addi x3, x3, 1
    beq x0, x0, next_6
bltu_true_5:
    addi x3, x3, 8
    beq x0, x0, next_6

    # bgeu
next_6:
    bgeu x2, x1, bgeu_true_6
bgeu_false_6:
    addi x3, x3, 8
    beq x0, x0, next_7
bgeu_true_6:
    addi x3, x3, 1
    beq x0, x0, next_7

next_7:
    bgeu x1, x2, bgeu_true_7
bgeu_false_7:
    addi x3, x3, 1
    beq x0, x0, deadloop
bgeu_true_7:
    addi x3, x3, 8
    beq x0, x0, deadloop

deadloop:
    beq x0, x0, deadloop