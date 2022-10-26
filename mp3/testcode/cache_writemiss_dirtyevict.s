cache_writemiss_dirtyevict.s:
.align 5
.section .text
.globl _start

    # x1: line counter
    # x2: base address
    # x3: value to write/read

# 13 words
_start:
    addi x1, x0, 16
    la x2, line_0_1     # 2 words
    addi x3, x0, -1     # x3 <- 0xffff, 4 bytes
loop:
    # Perform write miss to each 8-word line
    sw x3, 0(x2)
    addi x1, x1, -1
    addi x2, x2, 32
    bne x1, x0, loop
    # Evict dirty line
    sw x3, 0(x2)        # This should evict line 6
    addi x2, x2, 32
    sw x3, 0(x2)        # This should evict line 7
    # Read some value back to x3 check
    la x2, line_6_1     # 2 words
    lw x3, 4(x2)
deadloop:
    beq x0, x0, deadloop


.section .data
.align 5

# Line 0
line_0_1:	    .word   0x00000001
line_0_2:	    .word   0x00000002
line_0_3:	    .word   0x00000003
line_0_4:	    .word   0x00000004
line_0_5:	    .word   0x00000005
line_0_6:	    .word   0x00000006
line_0_7:	    .word   0x00000007
line_0_8:	    .word   0x00000008

# Line 1
line_1_1:       .word   0x00000011
line_1_2:       .word   0x00000012
line_1_3:       .word   0x00000013
line_1_4:       .word   0x00000014
line_1_5:       .word   0x00000015
line_1_6:       .word   0x00000016
line_1_7:       .word   0x00000017
line_1_8:       .word   0x00000018

# Line 2 (to set 4)
line_2_1:       .word   0x00000021
line_2_2:       .word   0x00000022
line_2_3:       .word   0x00000023
line_2_4:       .word   0x00000024
line_2_5:       .word   0x00000025
line_2_6:       .word   0x00000026
line_2_7:       .word   0x00000027
line_2_8:       .word   0x00000028

# Line 3 (to set 5)
line_3_1:       .word   0x00000031
line_3_2:       .word   0x00000032
line_3_3:       .word   0x00000033
line_3_4:       .word   0x00000034
line_3_5:       .word   0x00000035
line_3_6:       .word   0x00000036
line_3_7:       .word   0x00000037
line_3_8:       .word   0x00000038

# Line 4 (to set 6)
line_4_1:       .word   0x00000041
line_4_2:       .word   0x00000042
line_4_3:       .word   0x00000043
line_4_4:       .word   0x00000044
line_4_5:       .word   0x00000045
line_4_6:       .word   0x00000046
line_4_7:       .word   0x00000047
line_4_8:       .word   0x00000048

# Line 5 (to set 7)
line_5_1:       .word   0x00000051
line_5_2:       .word   0x00000052
line_5_3:       .word   0x00000053
line_5_4:       .word   0x00000054
line_5_5:       .word   0x00000055
line_5_6:       .word   0x00000056
line_5_7:       .word   0x00000057
line_5_8:       .word   0x00000058

# Line 6 (to set 0)
line_6_1:       .word   0x00000061
line_6_2:       .word   0x00000062
line_6_3:       .word   0x00000063
line_6_4:       .word   0x00000064
line_6_5:       .word   0x00000065
line_6_6:       .word   0x00000066
line_6_7:       .word   0x00000067
line_6_8:       .word   0x00000068

# Line 7 (to set 1)
line_7_1:       .word   0x00000071
line_7_2:       .word   0x00000072
line_7_3:       .word   0x00000073
line_7_4:       .word   0x00000074
line_7_5:       .word   0x00000075
line_7_6:       .word   0x00000076
line_7_7:       .word   0x00000077
line_7_8:       .word   0x00000078

# Line 8 (to set 2)
line_8_1:       .word   0x00000081
line_8_2:       .word   0x00000082
line_8_3:       .word   0x00000083
line_8_4:       .word   0x00000084
line_8_5:       .word   0x00000085
line_8_6:       .word   0x00000086
line_8_7:       .word   0x00000087
line_8_8:       .word   0x00000088

# Line 9 (to set 3)
line_9_1:       .word   0x00000091
line_9_2:       .word   0x00000092
line_9_3:       .word   0x00000093
line_9_4:       .word   0x00000094
line_9_5:       .word   0x00000095
line_9_6:       .word   0x00000096
line_9_7:       .word   0x00000097
line_9_8:       .word   0x00000098

# Line 10 (to set 4)
line_10_1:      .word   0x000000a1
line_10_2:      .word   0x000000a2
line_10_3:      .word   0x000000a3
line_10_4:      .word   0x000000a4
line_10_5:      .word   0x000000a5
line_10_6:      .word   0x000000a6
line_10_7:      .word   0x000000a7
line_10_8:      .word   0x000000a8

# Line 11 (to set 5)
line_11_1:      .word   0x000000b1
line_11_2:      .word   0x000000b2
line_11_3:      .word   0x000000b3
line_11_4:      .word   0x000000b4
line_11_5:      .word   0x000000b5
line_11_6:      .word   0x000000b6
line_11_7:      .word   0x000000b7
line_11_8:      .word   0x000000b8

# Line 12 (to set 6)
line_12_1:      .word   0x000000c1
line_12_2:      .word   0x000000c2
line_12_3:      .word   0x000000c3
line_12_4:      .word   0x000000c4
line_12_5:      .word   0x000000c5
line_12_6:      .word   0x000000c6
line_12_7:      .word   0x000000c7
line_12_8:      .word   0x000000c8

# Line 13 (to set 7)
line_13_1:      .word   0x000000d1
line_13_2:      .word   0x000000d2
line_13_3:      .word   0x000000d3
line_13_4:      .word   0x000000d4
line_13_5:      .word   0x000000d5
line_13_6:      .word   0x000000d6
line_13_7:      .word   0x000000d7
line_13_8:      .word   0x000000d8

# Line 14 (to set 0)
line_14_1:      .word   0x000000e1
line_14_2:      .word   0x000000e2
line_14_3:      .word   0x000000e3
line_14_4:      .word   0x000000e4
line_14_5:      .word   0x000000e5
line_14_6:      .word   0x000000e6
line_14_7:      .word   0x000000e7
line_14_8:      .word   0x000000e8

# Line 15 (to set 1)
line_15_1:      .word   0x000000f1
line_15_2:      .word   0x000000f2
line_15_3:      .word   0x000000f3
line_15_4:      .word   0x000000f4
line_15_5:      .word   0x000000f5
line_15_6:      .word   0x000000f6
line_15_7:      .word   0x000000f7
line_15_8:      .word   0x000000f8