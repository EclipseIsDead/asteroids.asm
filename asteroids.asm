#####################################################################
# Bitmap Display Configuration:
# - Unit width in pixels: 1
# - Unit height in pixels: 1
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#####################################################################
.data
displayAddress: .word 0x10008000 # hardcoding framebuffer (if you have a different one then change this)
playerPos: .word 32896  # Example position (128 * 256 + 128)
white: .word 0xffffff
# gonna need to store a sprite map here...

.globl main
.text
lw $t0, displayAddress # $t0 stores the base address for display

main:
    # Draw player to screen
    lw $a0, playerPos
    jal drawPlayer

    # Exit program gracefully
    li $v0, 10
    syscall

# arguments -> $a0: player's position (pixel to draw)
drawPlayer:
    lw $t1, white       # Load white color
    add $t2, $t0, $a0   # Calculate actual memory address
    sw $t1, 0($t2)      # Store white color at calculated address
    jr $ra

jr $ra