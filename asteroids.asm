#####################################################################
# Bitmap Display Configuration:
# - Unit width in pixels: 1
# - Unit height in pixels: 1
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# CONVENTIONS:
# - Every function is expected to have a stack pointer wrapper
# - Every function is responsible for its own registers and cleanup!
# - 256 * 256 = 0x10000 WHICH IS IMPORTANT
#####################################################################
.data
displayAddress: .word 0x10008000 # hardcoding framebuffer (if you have a different one then change this)
playerPos: .word 65664  # Example position (128 * 256 + 128)
test1: .word 65792
test2: .word 77000
white: .word 0xffffff
dim: .word 256

.globl main
.text
lw $s0, displayAddress # $s0 stores the base address for display

main:
    # Draw lines on the screen
    lw $a0, test1
    lw $a1, test2
    jal drawLine

    # Exit program gracefully
    li $v0, 10
    syscall

# arguments -> $a0: player's position specifically the head of the ship)
drawPlayer:
    sw $ra, 0($sp)
    addi $sp, $sp, -4
    
    lw $t0, white       # Load white color
    add $t2, $s0, $a0   # Calculate actual memory address
    sw $t0, 0($t1)      # Store white color at calculated address
    
    addi $sp, $sp, 4
    lw $ra, ($sp)
    jr $ra

# arguments -> $a0: starting point in the frame buffer, $a1: endpoint in the buffer
# this is an implementation of Brennan's Line algorithm, of which there are 4 cases
# gradient +, delta y < delta x
# gradient -, delta y < delta x
# gradient +, delta y > delta x
# gradient -, delta y > delta x
drawLine:
    sw $ra, 0($sp)
    addi $sp, $sp, -4
    
    lw $t0, dim # grab the bitmap dimension
    div $a0, $t0 # convert to cartesian coords (lo: x, hi: y)
    mflo $t1
    mfhi $t2
    div $a1, $t0 # convert to cartesian coords (lo: x, hi: y)
    mflo $t3
    mfhi $t4
    # if delta y < delta x and gradient is positive (i need $t1 and $t2 for later)
    sub $t0, $t4, $t2
    sll $t5, $t0, 1 # a = 2(y_1 - y_2) -> $t5 (i don't think this overflows)
    sub $t0, $t3, $t1
    sll $t4, $t0, 1 # no longer need $t4
    sub $t6, $t5, $t4 # b = a - 2(x_1 - x_2) -> $t6
    sub $t4, $t5, $t0 # p = a - (x_1 - x_2) -> $t4
    # if p >= 0
    
    addi $sp, $sp, 4
    lw $ra, ($sp)
    jr $ra

# should not hit this?
jr $ra