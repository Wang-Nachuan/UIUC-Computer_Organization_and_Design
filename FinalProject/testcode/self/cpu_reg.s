cpu_inst_br_unsigned.s:
.align 4
.section .text
.globl _start

    addi x1, x0, 1
    addi x2, x0, 2
    addi x3, x0, 3
    addi x4, x0, 4
    addi x5, x0, 5
    addi x6, x0, 6
    addi x7, x0, 7
    addi x8, x0, 8
    addi x9, x0, 9

    add x10, x1, x9
    add x11, x10, x1
    and x12, x7, x1

deadloop:
    beq x0, x0, deadloop