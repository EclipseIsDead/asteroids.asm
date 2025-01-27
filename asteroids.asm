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
# - Every function is responsible for its own registers and cleanup
# - If you run out of argument registers DO NOT move the function body to main,
#   instead please use temp registers and then cleanup later
# - 256 * 256 = 0x10000 WHICH IS IMPORTANT
#####################################################################
.data
displayAddress: .word 0x10008000 # hardcoding framebuffer (if you have a different one then change this)
playerPos: .word 32896  # Example position (128 * 256 + 128)
theta: .word 1 # rotation of player
test1: .word 25700 # (100, 100)
test2: .word 51400 # (200, 200)
white: .word 0xffffff
dim: .word 256

.globl main
.text
lw $s0, displayAddress # $s0 stores the base address for display

main:
    # calculate player's 2 child points then draw them with rotation factored in
    # note player is an isoceles triangle so 10 pixels down, 5 to the right and left
    lw $a0, playerPos
    lw $a1, theta
    lw $a2, dim # should move this to an $sn register rather than arg tbh
    lw $a3, white
    jal drawPlayer

    # Exit program gracefully
    li $v0, 10
    syscall

# arguments -> $a0: starting point in the frame buffer, $a1: endpoint in the buffer
#           -> $a2: dimension of bitmap, $a3: colour in hex
# this is an implementation of Bresenham's Line algorithm, of which there are 4 cases
# gradient +, delta y < delta x
# gradient -, delta y < delta x
# gradient +, delta y > delta x
# gradient -, delta y > delta x
# this implementation needs to handle overflows gracefully (we are on a torus)
drawLine:
    sw $ra, 0($sp)
    addi $sp, $sp, -4
    
    lw $t0, dim # grab the bitmap dimension
    div $a0, $t0 # convert to cartesian coords (lo: x, hi: y)
    mflo $t1 # x1
    mfhi $t2 # y1
    div $a1, $t0 # convert to cartesian coords (lo: x, hi: y)
    mflo $t3 # x2
    mfhi $t4 # y2

    sub $t5, $t3, $t1 # dx = x2 - x1
    sub $t6, $t4, $t2 # dy = y2 - y1
    
    abs $t7, $t5 # |dx|
    abs $t8, $t6 # |dy|
    
    # Determine which octant the line is in
    slt $t9, $t7, $t8 # if |dx| < |dy|, $t9 = 1, else $t9 = 0
    
    beqz $t9, x_dominant
    j y_dominant
    
x_dominant:
    slt $t9, $t5, $zero # if dx < 0, $t9 = 1, else $t9 = 0
    beqz $t9, x_positive
    # dx is negative, swap points
    move $t0, $t1
    move $t1, $t3
    move $t3, $t0
    move $t0, $t2
    move $t2, $t4
    move $t4, $t0

x_positive:
    sub $t5, $t3, $t1 # recalculate dx
    sub $t6, $t4, $t2 # recalculate dy
    sll $t6, $t6, 1 # 2 * dy
    sub $t7, $t6, $t5 # p = 2 * dy - dx
    sll $t5, $t5, 1 # 2 * dx
    j draw_loop_x

y_dominant:
    slt $t9, $t6, $zero # if dy < 0, $t9 = 1, else $t9 = 0
    beqz $t9, y_positive
    # dy is negative, swap points
    move $t0, $t1
    move $t1, $t3
    move $t3, $t0
    move $t0, $t2
    move $t2, $t4
    move $t4, $t0

y_positive:
    sub $t5, $t3, $t1 # recalculate dx
    sub $t6, $t4, $t2 # recalculate dy
    sll $t5, $t5, 1 # 2 * dx
    sub $t7, $t5, $t6 # p = 2 * dx - dy
    sll $t6, $t6, 1 # 2 * dy
    j draw_loop_y

draw_loop_x:
    # Draw pixel at (x1, y1)
    mul $t0, $t2, $a2 # y1 * width
    add $t0, $t0, $t1 # y1 * width + x1
    sll $t0, $t0, 2 # (y1 * width + x1) * 4 (4 bytes per pixel)
    add $t0, $t0, $gp # add base address
    sw $a3, 0($t0) # store color
    
    beq $t1, $t3, exit_draw # if x1 == x2, we're done
    
    addi $t1, $t1, 1 # x1++
    
    bltz $t7, skip_y_x # if p < 0, skip y increment
    slt $t9, $t4, $t2 # if y2 < y1, $t9 = 1, else $t9 = 0
    beqz $t9, inc_y_x
    addi $t2, $t2, -1 # y1--
    j update_p_x

inc_y_x:
    addi $t2, $t2, 1 # y1++
update_p_x:
    sub $t7, $t7, $t5 # p = p - 2dx
skip_y_x:
    add $t7, $t7, $t6 # p = p + 2dy
    
    j draw_loop_x

draw_loop_y:
    # Draw pixel at (x1, y1)
    mul $t0, $t2, $a2 # y1 * width
    add $t0, $t0, $t1 # y1 * width + x1
    sll $t0, $t0, 2 # (y1 * width + x1) * 4 (4 bytes per pixel)
    add $t0, $t0, $gp # add base address
    sw $a3, 0($t0) # store color
    
    beq $t2, $t4, exit_draw # if y1 == y2, we're done
    
    addi $t2, $t2, 1 # y1++
    
    bltz $t7, skip_x_y # if p < 0, skip x increment
    slt $t9, $t3, $t1 # if x2 < x1, $t9 = 1, else $t9 = 0
    beqz $t9, inc_x_y
    addi $t1, $t1, -1 # x1--
    j update_p_y

inc_x_y:
    addi $t1, $t1, 1 # x1++
update_p_y:
    sub $t7, $t7, $t6 # p = p - 2dy
skip_x_y:
    add $t7, $t7, $t5 # p = p + 2dx
    
    j draw_loop_y

exit_draw:
    # cleanup registers
    move $t0, $zero
    move $t1, $zero
    move $t2, $zero
    move $t3, $zero
    move $t4, $zero
    move $t5, $zero
    move $t6, $zero
    move $t7, $zero
    # follow stack pointer
    addi $sp, $sp, 4
    lw $ra, ($sp)
    jr $ra

# arguments -> $a0: player "head" point, $a1: current theta rotation of the player
#           -> $a2: bitmap dim, $a3: colour
# we store the angle of the player as theta and apply a 2D rotation matrix (floored trig functions)
# player dim is constant and then approximated -> down ten then +/- 10 pixels
drawPlayer:
    sw $ra, 0($sp)
    addi $sp, $sp, -4
    
    # store theta seperately and then re-load it later
    # remember $tn is local so we use $sn for this stuff!
    move $s7, $a1
    
    # calculate child point positions and draw them
    addi $a1, $a0, 1290
    jal drawLine

    addi $a1, $a0, 300 # something's going on here?
    jal drawLine
    
    # reload arguments
    move $a1, $s7
    move $s7, $zero
    
    addi $sp, $sp, 4
    lw $ra, ($sp)
    jr $ra

# should not hit this?
jr $ra
