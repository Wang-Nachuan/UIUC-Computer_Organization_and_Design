cache_maskrw.s:
.align 4
.section .text
.globl _start

_start:
    addi x1, x0, 32	    # compile to 4 bytes instruction
    la x2, line_0		# compile to 8 bytes (auipc + addi) instructions
loop:
    sb x1, 0(x2)		# compile to 4 bytes instruction
    addi x1, x1, -1		# compile to 4 bytes instruction
    addi x2, x2, 1		# compile to 4 bytes instruction
    bne x1, x0, loop		# compile to 4 bytes instruction
deadloop:
    beq x0, x0, deadloop    # compile to 4 bytes instruction
	
.section .data
line_0:	    .word   0x0	# Following data is load into a 32 bytes line in cache
line_1:	    .word   0x0
line_2:	    .word   0x0
line_3:	    .word   0x0
line_4:	    .word   0x0
line_5:	    .word   0x0
line_6:	    .word   0x0
line_7:	    .word   0x0