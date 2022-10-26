test_rw.s:
.align 4
.section .text
.globl _start
    
_start:

    andi x1, x1, 0
    andi x2, x2, 0
    lui x1, 3
    lui x1, 5
    auipc x2, 4
    auipc x2, 6

deadloop:
    beq x0, x0, deadloop
