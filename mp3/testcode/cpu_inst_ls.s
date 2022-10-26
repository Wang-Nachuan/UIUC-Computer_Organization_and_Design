test_l_s.s:
.align 4
.section .text
.globl _start
    
_start:

    # x1 for value
    # x2 for address
    # x3 for check stored value

    # Init
    add x1, x0, x0
    add x2, x0, x0
    add x3, x0, x0

    # Test for lw, sw
    lw x1, test_lw          # x1 <- 0x12345678
    la x2, test_sw
    sw x1, 0(x2)            # [test_sw] <- 0x12345678
    lw x3, test_sw          # x3 <- 0x12345678

    # Test for lh
    lh x1, test_lh_s0       # x1 <- 0x00001FFF
    lh x1, test_lh_s1       # x1 <- 0xFFFFF111
    lh x1, test_lh_s0 + 2   # x1 <- 0x00002FFF
    lh x1, test_lh_s1 + 2   # x1 <- 0xFFFFF222

    # Test for sh
    la x2, test_sh
    sh x1, 0(x2)            # [test_sh] <- 0x____F222
    lw x3, test_sh          # x3 <- 0x0000F222
    la x2, test_sh + 2
    sh x1, 0(x2)            # [test_sh] <- 0xF222____
    lw x3, test_sh          # x3 <- 0xF222F222

    # Test for lb
    lb x1, test_lb_s0       # x1 <- 0x0000001F
    lb x1, test_lb_s1       # x1 <- 0xFFFFFFF1
    lb x1, test_lb_s0 + 1   # x1 <- 0x0000002F
    lb x1, test_lb_s1 + 1   # x1 <- 0xFFFFFFF2
    lb x1, test_lb_s0 + 2   # x1 <- 0x0000003F
    lb x1, test_lb_s1 + 2   # x1 <- 0xFFFFFFF3
    lb x1, test_lb_s0 + 3   # x1 <- 0x0000004F
    lb x1, test_lb_s1 + 3   # x1 <- 0xFFFFFFF4

    # Test for sb
    la x2, test_sb
    sb x1, 0(x2)            # [test_sb] <- 0x______F4
    lw x3, test_sb          # x3 <- 0x000000F4
    la x2, test_sb + 1
    sb x1, 0(x2)            # [test_sb] <- 0x____F4__
    lw x3, test_sb          # x3 <- 0x0000F4F4
    la x2, test_sb + 2
    sb x1, 0(x2)            # [test_sb] <- 0x__F4____
    lw x3, test_sb          # x3 <- 0x00F4F4F4
    la x2, test_sb + 3
    sb x1, 0(x2)            # [test_sb] <- 0xF4______
    lw x3, test_sb          # x3 <- 0xF4F4F4F4

    # Test for lhu
    lhu x1, test_lhu_s0         # x1 <- 0x00001FFF
    lhu x1, test_lhu_s1         # x1 <- 0x0000FFF1
    lhu x1, test_lhu_s0 + 2     # x1 <- 0x00002FFF
    lhu x1, test_lhu_s1 + 2     # x1 <- 0x0000FFF2

    # Test for lbu
    lbu x1, test_lbu_s0         # x1 <- 0x0000001F
    lbu x1, test_lbu_s1         # x1 <- 0x000000F1
    lbu x1, test_lbu_s0 + 1     # x1 <- 0x0000002F
    lbu x1, test_lbu_s1 + 1     # x1 <- 0x000000F2
    lbu x1, test_lbu_s0 + 2     # x1 <- 0x0000003F
    lbu x1, test_lbu_s1 + 2     # x1 <- 0x000000F3
    lbu x1, test_lbu_s0 + 3     # x1 <- 0x0000004F
    lbu x1, test_lbu_s1 + 3     # x1 <- 0x000000F4

deadloop:
    beq x0, x0, deadloop


.section .data

test_lw:        .word 0x12345678
test_sw:        .word 0x00000000

test_lh_s0:     .word 0x2FFF1FFF
test_lh_s1:     .word 0xF222F111
test_sh:        .word 0x00000000

test_lb_s0:     .word 0x4F3F2F1F
test_lb_s1:     .word 0xF4F3F2F1
test_sb:        .word 0x00000000

test_lhu_s0:    .word 0x2FFF1FFF
test_lhu_s1:    .word 0xF222F111
test_lbu_s0:    .word 0x4F3F2F1F
test_lbu_s1:    .word 0xF4F3F2F1

