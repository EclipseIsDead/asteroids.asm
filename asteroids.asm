#####################################################################
# Asteroids for MARS MIPS
#
# Bitmap Display:
# - Unit width: 1
# - Unit height: 1
# - Display width: 256
# - Display height: 256
# - Base address: 0x10008000
#
# Keyboard and Display MMIO:
# - Receiver control: 0xffff0000
# - Receiver data:    0xffff0004
#
# Controls:
# - a: rotate left
# - d: rotate right
# - w: thrust
# - space: fire
# - r: restart after game over
# - q: quit
#####################################################################

.eqv SCREEN_PIXELS      65536
.eqv KEY_CTRL           0xffff0000
.eqv KEY_DATA           0xffff0004
.eqv BULLET_BYTES       16
.eqv ASTEROID_BYTES     32
.eqv BULLET_LIFE        34
.eqv MAX_SPEED          5
.eqv FRAME_SLEEP_MS     60
.eqv START_GRACE_MS     5000
.eqv SPAWN_GRACE_FRAMES 45
.eqv DRAG_FRAMES        10

.data
displayAddress: .word 0x10008000

black:          .word 0x000000
white:          .word 0xffffff
red:            .word 0xff3333
yellow:         .word 0xffdd55
gray:           .word 0xaaaaaa
currentColor:   .word 0xffffff

shipX:          .word 128
shipY:          .word 128
shipVx:         .word 0
shipVy:         .word 0
shipDir:        .word 0
gameOver:       .word 0
quitFlag:       .word 0
spawnGrace:     .word 0
score:          .word 0
thrustThisFrame:.word 0
dragCounter:    .word 10

# Eight directions. 0 = up, then clockwise.
dirDx:          .word 0, 1, 1, 1, 0, -1, -1, -1
dirDy:          .word -1, -1, 0, 1, 1, 1, 0, -1
shipPointDx:    .word 0, 4, 5, 4, 0, -4, -5, -4
shipPointDy:    .word -5, -4, 0, 4, 5, 4, 0, -4

bulletActive:   .word 0, 0, 0, 0
bulletX:        .word 0, 0, 0, 0
bulletY:        .word 0, 0, 0, 0
bulletVx:       .word 0, 0, 0, 0
bulletVy:       .word 0, 0, 0, 0
bulletLife:     .word 0, 0, 0, 0

asteroidActive: .word 1, 1, 1, 1, 1, 0, 0, 0
asteroidX:      .word 28, 224, 64, 204, 128, 0, 0, 0
asteroidY:      .word 42, 58, 214, 202, 28, 0, 0, 0
asteroidVx:     .word 1, -1, 1, -1, 0, 0, 0, 0
asteroidVy:     .word 1, 1, -1, -1, 2, 0, 0, 0
asteroidSize:   .word 16, 17, 15, 14, 13, 0, 0, 0

initAstActive:  .word 1, 1, 1, 1, 1, 0, 0, 0
initAstX:       .word 28, 224, 64, 204, 128, 0, 0, 0
initAstY:       .word 42, 58, 214, 202, 28, 0, 0, 0
initAstVx:      .word 1, -1, 1, -1, 0, 0, 0, 0
initAstVy:      .word 1, 1, -1, -1, 2, 0, 0, 0
initAstSize:    .word 16, 17, 15, 14, 13, 0, 0, 0

.globl main
.text

main:
    lw $s0, displayAddress
    jal initGame
    jal drawScene
    jal delayStart

gameLoop:
    lw $t0, gameOver
    bnez $t0, gameLoopInput

    jal eraseScene

gameLoopInput:
    jal readInput

    lw $t0, quitFlag
    bnez $t0, exitProgram

    lw $t0, gameOver
    bnez $t0, gameOverFrame

    jal updateShip
    jal applyDrag
    jal updateBullets
    jal updateAsteroids
    jal checkCollisions
    jal restartWaveIfClear
    jal drawScene

    lw $t0, gameOver
    beqz $t0, frameDelay
    jal drawGameOverMark
    j frameDelay

gameOverFrame:
    jal drawGameOverMark

frameDelay:
    jal delayFrame
    j gameLoop

exitProgram:
    li $v0, 10
    syscall

#####################################################################
# Initialization and input
#####################################################################

initGame:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    li $t0, 128
    sw $t0, shipX
    sw $t0, shipY
    sw $zero, shipVx
    sw $zero, shipVy
    sw $zero, shipDir
    sw $zero, gameOver
    sw $zero, quitFlag
    sw $zero, score
    sw $zero, thrustThisFrame
    li $t0, DRAG_FRAMES
    sw $t0, dragCounter
    li $t0, SPAWN_GRACE_FRAMES
    sw $t0, spawnGrace

    jal clearBullets
    jal resetAsteroids

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

clearBullets:
    li $t0, 0
clearBulletsLoop:
    bge $t0, BULLET_BYTES, clearBulletsDone
    la $t1, bulletActive
    add $t1, $t1, $t0
    sw $zero, 0($t1)
    la $t1, bulletLife
    add $t1, $t1, $t0
    sw $zero, 0($t1)
    addi $t0, $t0, 4
    j clearBulletsLoop
clearBulletsDone:
    jr $ra

resetAsteroids:
    li $t0, 0
resetAsteroidsLoop:
    bge $t0, ASTEROID_BYTES, resetAsteroidsDone

    la $t1, initAstActive
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    la $t3, asteroidActive
    add $t3, $t3, $t0
    sw $t2, 0($t3)

    la $t1, initAstX
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    la $t3, asteroidX
    add $t3, $t3, $t0
    sw $t2, 0($t3)

    la $t1, initAstY
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    la $t3, asteroidY
    add $t3, $t3, $t0
    sw $t2, 0($t3)

    la $t1, initAstVx
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    la $t3, asteroidVx
    add $t3, $t3, $t0
    sw $t2, 0($t3)

    la $t1, initAstVy
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    la $t3, asteroidVy
    add $t3, $t3, $t0
    sw $t2, 0($t3)

    la $t1, initAstSize
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    la $t3, asteroidSize
    add $t3, $t3, $t0
    sw $t2, 0($t3)

    addi $t0, $t0, 4
    j resetAsteroidsLoop
resetAsteroidsDone:
    jr $ra

readInput:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    li $t0, KEY_CTRL
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, readInputDone

    li $t0, KEY_DATA
    lw $t2, 0($t0)

    li $t3, 113
    beq $t2, $t3, keyQuit

    li $t3, 114
    beq $t2, $t3, keyRestart

    lw $t4, gameOver
    bnez $t4, readInputDone

    li $t3, 97
    beq $t2, $t3, keyLeft

    li $t3, 100
    beq $t2, $t3, keyRight

    li $t3, 119
    beq $t2, $t3, keyThrust

    li $t3, 87
    beq $t2, $t3, keyThrust

    li $t3, 32
    beq $t2, $t3, keyFire

    j readInputDone

keyQuit:
    li $t0, 1
    sw $t0, quitFlag
    j readInputDone

keyRestart:
    lw $t0, gameOver
    beqz $t0, readInputDone
    jal initGame
    jal drawScene
    jal delayStart
    j readInputDone

keyLeft:
    lw $t0, shipDir
    addi $t0, $t0, 7
    andi $t0, $t0, 7
    sw $t0, shipDir
    j readInputDone

keyRight:
    lw $t0, shipDir
    addi $t0, $t0, 1
    andi $t0, $t0, 7
    sw $t0, shipDir
    j readInputDone

keyThrust:
    jal applyThrust
    j readInputDone

keyFire:
    jal fireBullet

readInputDone:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

applyThrust:
    addi $sp, $sp, -12
    sw $ra, 8($sp)

    li $t0, 1
    sw $t0, thrustThisFrame

    lw $t0, shipDir
    sll $t0, $t0, 2

    la $t1, dirDx
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    sll $t2, $t2, 1
    sw $t2, 0($sp)
    lw $t3, shipVx
    add $a0, $t3, $t2
    jal clampSpeed
    sw $v0, shipVx

    lw $t0, shipDir
    sll $t0, $t0, 2
    la $t1, dirDy
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    sll $t2, $t2, 1
    sw $t2, 4($sp)
    lw $t3, shipVy
    add $a0, $t3, $t2
    jal clampSpeed
    sw $v0, shipVy

    lw $t0, shipX
    lw $t1, 0($sp)
    add $t0, $t0, $t1
    andi $t0, $t0, 255
    sw $t0, shipX

    lw $t0, shipY
    lw $t1, 4($sp)
    add $t0, $t0, $t1
    andi $t0, $t0, 255
    sw $t0, shipY

    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra

clampSpeed:
    li $t0, MAX_SPEED
    bgt $a0, $t0, clampHigh
    li $t0, -5
    blt $a0, $t0, clampLow
    move $v0, $a0
    jr $ra
clampHigh:
    li $v0, MAX_SPEED
    jr $ra
clampLow:
    li $v0, -5
    jr $ra

fireBullet:
    li $t0, 0
findBulletSlot:
    bge $t0, BULLET_BYTES, fireBulletDone
    la $t1, bulletActive
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    beqz $t2, useBulletSlot
    addi $t0, $t0, 4
    j findBulletSlot

useBulletSlot:
    li $t2, 1
    sw $t2, 0($t1)

    lw $t2, shipX
    la $t3, bulletX
    add $t3, $t3, $t0
    sw $t2, 0($t3)

    lw $t2, shipY
    la $t3, bulletY
    add $t3, $t3, $t0
    sw $t2, 0($t3)

    lw $t4, shipDir
    sll $t4, $t4, 2

    la $t5, dirDx
    add $t5, $t5, $t4
    lw $t6, 0($t5)
    li $t7, 5
    mul $t6, $t6, $t7
    lw $t8, shipVx
    add $t6, $t6, $t8
    la $t3, bulletVx
    add $t3, $t3, $t0
    sw $t6, 0($t3)

    la $t5, dirDy
    add $t5, $t5, $t4
    lw $t6, 0($t5)
    li $t7, 5
    mul $t6, $t6, $t7
    lw $t8, shipVy
    add $t6, $t6, $t8
    la $t3, bulletVy
    add $t3, $t3, $t0
    sw $t6, 0($t3)

    li $t2, BULLET_LIFE
    la $t3, bulletLife
    add $t3, $t3, $t0
    sw $t2, 0($t3)

fireBulletDone:
    jr $ra

#####################################################################
# Simulation
#####################################################################

updateShip:
    lw $t0, shipX
    lw $t1, shipVx
    add $t0, $t0, $t1
    andi $t0, $t0, 255
    sw $t0, shipX

    lw $t0, shipY
    lw $t1, shipVy
    add $t0, $t0, $t1
    andi $t0, $t0, 255
    sw $t0, shipY
    jr $ra

applyDrag:
    lw $t0, thrustThisFrame
    beqz $t0, dragMaybe
    sw $zero, thrustThisFrame
    li $t0, DRAG_FRAMES
    sw $t0, dragCounter
    jr $ra

dragMaybe:
    lw $t0, dragCounter
    addi $t0, $t0, -1
    sw $t0, dragCounter
    bgtz $t0, dragDone

    li $t0, DRAG_FRAMES
    sw $t0, dragCounter

    lw $t1, shipVx
    beqz $t1, dragY
    bgtz $t1, dragVxPositive
    addi $t1, $t1, 1
    j dragStoreVx
dragVxPositive:
    addi $t1, $t1, -1
dragStoreVx:
    sw $t1, shipVx

dragY:
    lw $t1, shipVy
    beqz $t1, dragDone
    bgtz $t1, dragVyPositive
    addi $t1, $t1, 1
    j dragStoreVy
dragVyPositive:
    addi $t1, $t1, -1
dragStoreVy:
    sw $t1, shipVy

dragDone:
    jr $ra

updateBullets:
    li $t0, 0
updateBulletsLoop:
    bge $t0, BULLET_BYTES, updateBulletsDone
    la $t1, bulletActive
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    beqz $t2, updateBulletsNext

    la $t3, bulletX
    add $t3, $t3, $t0
    lw $t4, 0($t3)
    la $t5, bulletVx
    add $t5, $t5, $t0
    lw $t6, 0($t5)
    add $t4, $t4, $t6
    andi $t4, $t4, 255
    sw $t4, 0($t3)

    la $t3, bulletY
    add $t3, $t3, $t0
    lw $t4, 0($t3)
    la $t5, bulletVy
    add $t5, $t5, $t0
    lw $t6, 0($t5)
    add $t4, $t4, $t6
    andi $t4, $t4, 255
    sw $t4, 0($t3)

    la $t3, bulletLife
    add $t3, $t3, $t0
    lw $t4, 0($t3)
    addi $t4, $t4, -1
    sw $t4, 0($t3)
    bgtz $t4, updateBulletsNext
    sw $zero, 0($t1)

updateBulletsNext:
    addi $t0, $t0, 4
    j updateBulletsLoop
updateBulletsDone:
    jr $ra

updateAsteroids:
    li $t0, 0
updateAsteroidsLoop:
    bge $t0, ASTEROID_BYTES, updateAsteroidsDone
    la $t1, asteroidActive
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    beqz $t2, updateAsteroidsNext

    la $t3, asteroidX
    add $t3, $t3, $t0
    lw $t4, 0($t3)
    la $t5, asteroidVx
    add $t5, $t5, $t0
    lw $t6, 0($t5)
    add $t4, $t4, $t6
    andi $t4, $t4, 255
    sw $t4, 0($t3)

    la $t3, asteroidY
    add $t3, $t3, $t0
    lw $t4, 0($t3)
    la $t5, asteroidVy
    add $t5, $t5, $t0
    lw $t6, 0($t5)
    add $t4, $t4, $t6
    andi $t4, $t4, 255
    sw $t4, 0($t3)

updateAsteroidsNext:
    addi $t0, $t0, 4
    j updateAsteroidsLoop
updateAsteroidsDone:
    jr $ra

restartWaveIfClear:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    li $t0, 0
restartWaveLoop:
    bge $t0, ASTEROID_BYTES, restartWave
    la $t1, asteroidActive
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    bnez $t2, restartWaveDone
    addi $t0, $t0, 4
    j restartWaveLoop
restartWave:
    jal resetAsteroids
restartWaveDone:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

#####################################################################
# Collisions
#####################################################################

checkCollisions:
    addi $sp, $sp, -20
    sw $ra, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    sw $s4, 0($sp)

    li $s1, 0
bulletCollisionLoop:
    bge $s1, BULLET_BYTES, shipCollisionStart
    la $t0, bulletActive
    add $t0, $t0, $s1
    lw $t1, 0($t0)
    beqz $t1, bulletCollisionNext

    li $s2, 0
asteroidCollisionLoop:
    bge $s2, ASTEROID_BYTES, bulletCollisionNext
    la $t0, asteroidActive
    add $t0, $t0, $s2
    lw $t1, 0($t0)
    beqz $t1, asteroidCollisionNext

    la $t0, bulletX
    add $t0, $t0, $s1
    lw $a0, 0($t0)
    la $t0, bulletY
    add $t0, $t0, $s1
    lw $a1, 0($t0)
    la $t0, asteroidX
    add $t0, $t0, $s2
    lw $a2, 0($t0)
    la $t0, asteroidY
    add $t0, $t0, $s2
    lw $a3, 0($t0)
    jal wrappedDistance
    move $s3, $v0

    la $t0, asteroidSize
    add $t0, $t0, $s2
    lw $t1, 0($t0)
    addi $t1, $t1, 3
    bgt $s3, $t1, asteroidCollisionNext

    la $t0, bulletActive
    add $t0, $t0, $s1
    sw $zero, 0($t0)
    move $a0, $s2
    jal breakAsteroid
    lw $t0, score
    addi $t0, $t0, 10
    sw $t0, score
    j bulletCollisionNext

asteroidCollisionNext:
    addi $s2, $s2, 4
    j asteroidCollisionLoop

bulletCollisionNext:
    addi $s1, $s1, 4
    j bulletCollisionLoop

shipCollisionStart:
    lw $t0, spawnGrace
    blez $t0, shipCollisionActive
    addi $t0, $t0, -1
    sw $t0, spawnGrace
    j collisionsDone

shipCollisionActive:
    li $s1, 0
shipCollisionLoop:
    bge $s1, ASTEROID_BYTES, collisionsDone
    la $t0, asteroidActive
    add $t0, $t0, $s1
    lw $t1, 0($t0)
    beqz $t1, shipCollisionNext

    lw $a0, shipX
    lw $a1, shipY
    la $t0, asteroidX
    add $t0, $t0, $s1
    lw $a2, 0($t0)
    la $t0, asteroidY
    add $t0, $t0, $s1
    lw $a3, 0($t0)
    jal wrappedDistance
    move $s2, $v0

    la $t0, asteroidSize
    add $t0, $t0, $s1
    lw $t1, 0($t0)
    addi $t1, $t1, 5
    bgt $s2, $t1, shipCollisionNext

    li $t0, 1
    sw $t0, gameOver
    j collisionsDone

shipCollisionNext:
    addi $s1, $s1, 4
    j shipCollisionLoop

collisionsDone:
    lw $s4, 0($sp)
    lw $s3, 4($sp)
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra

wrappedDistance:
    sub $t0, $a0, $a2
    bgez $t0, absXDone
    sub $t0, $zero, $t0
absXDone:
    li $t1, 128
    ble $t0, $t1, xReady
    li $t1, 256
    sub $t0, $t1, $t0
xReady:
    sub $t2, $a1, $a3
    bgez $t2, absYDone
    sub $t2, $zero, $t2
absYDone:
    li $t1, 128
    ble $t2, $t1, yReady
    li $t1, 256
    sub $t2, $t1, $t2
yReady:
    add $v0, $t0, $t2
    jr $ra

breakAsteroid:
    move $t9, $a0
    la $t0, asteroidSize
    add $t0, $t0, $t9
    lw $t1, 0($t0)
    ble $t1, 8, removeAsteroid

    addi $t1, $t1, -5
    sw $t1, 0($t0)
    move $t8, $t1

    li $t2, 0
findSplitSlot:
    bge $t2, ASTEROID_BYTES, breakAsteroidDone
    beq $t2, $t9, splitSlotNext
    la $t3, asteroidActive
    add $t3, $t3, $t2
    lw $t4, 0($t3)
    beqz $t4, useSplitSlot
splitSlotNext:
    addi $t2, $t2, 4
    j findSplitSlot

useSplitSlot:
    li $t4, 1
    sw $t4, 0($t3)

    la $t3, asteroidX
    add $t3, $t3, $t9
    lw $t4, 0($t3)
    la $t5, asteroidX
    add $t5, $t5, $t2
    sw $t4, 0($t5)

    la $t3, asteroidY
    add $t3, $t3, $t9
    lw $t4, 0($t3)
    la $t5, asteroidY
    add $t5, $t5, $t2
    sw $t4, 0($t5)

    la $t5, asteroidSize
    add $t5, $t5, $t2
    sw $t8, 0($t5)

    la $t3, asteroidVy
    add $t3, $t3, $t9
    lw $t4, 0($t3)
    addi $t4, $t4, 1
    la $t5, asteroidVx
    add $t5, $t5, $t2
    sw $t4, 0($t5)

    la $t3, asteroidVx
    add $t3, $t3, $t9
    lw $t4, 0($t3)
    sub $t4, $zero, $t4
    addi $t4, $t4, -1
    la $t5, asteroidVy
    add $t5, $t5, $t2
    sw $t4, 0($t5)
    j breakAsteroidDone

removeAsteroid:
    la $t0, asteroidActive
    add $t0, $t0, $t9
    sw $zero, 0($t0)

breakAsteroidDone:
    jr $ra

#####################################################################
# Rendering
#####################################################################

clearScreen:
    lw $t0, black
    move $t1, $s0
    li $t2, SCREEN_PIXELS
clearScreenLoop:
    beqz $t2, clearScreenDone
    sw $t0, 0($t1)
    addi $t1, $t1, 4
    addi $t2, $t2, -1
    j clearScreenLoop
clearScreenDone:
    jr $ra

eraseScene:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t0, black
    sw $t0, currentColor
    jal drawShip
    jal drawBullets
    jal drawAsteroids

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

drawScene:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t0, gray
    sw $t0, currentColor
    jal drawAsteroids

    lw $t0, yellow
    sw $t0, currentColor
    jal drawBullets

    lw $t0, white
    sw $t0, currentColor
    jal drawShip

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

drawShip:
    addi $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s1, 16($sp)
    sw $s2, 12($sp)
    sw $s3, 8($sp)
    sw $s4, 4($sp)
    sw $s5, 0($sp)

    lw $s1, shipX
    lw $s2, shipY
    lw $s3, shipDir

    move $a0, $s1
    move $a1, $s2
    li $a2, 0
    jal drawBlock

    sll $t0, $s3, 2
    la $t1, shipPointDx
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    add $a0, $s1, $t2
    la $t1, shipPointDy
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    add $a1, $s2, $t2
    li $a2, 0
    jal drawBlock

    addi $s4, $s3, 3
    andi $s4, $s4, 7
    sll $t0, $s4, 2
    la $t1, shipPointDx
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    add $a0, $s1, $t2
    la $t1, shipPointDy
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    add $a1, $s2, $t2
    li $a2, 0
    jal drawBlock

    addi $s5, $s3, 5
    andi $s5, $s5, 7
    sll $t0, $s5, 2
    la $t1, shipPointDx
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    add $a0, $s1, $t2
    la $t1, shipPointDy
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    add $a1, $s2, $t2
    li $a2, 0
    jal drawBlock

    lw $s5, 0($sp)
    lw $s4, 4($sp)
    lw $s3, 8($sp)
    lw $s2, 12($sp)
    lw $s1, 16($sp)
    lw $ra, 20($sp)
    addi $sp, $sp, 24
    jr $ra

drawAsteroids:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s1, 0($sp)

    li $s1, 0
drawAsteroidsLoop:
    bge $s1, ASTEROID_BYTES, drawAsteroidsDone
    la $t0, asteroidActive
    add $t0, $t0, $s1
    lw $t1, 0($t0)
    beqz $t1, drawAsteroidsNext

    la $t0, asteroidX
    add $t0, $t0, $s1
    lw $a0, 0($t0)
    la $t0, asteroidY
    add $t0, $t0, $s1
    lw $a1, 0($t0)
    la $t0, asteroidSize
    add $t0, $t0, $s1
    lw $a2, 0($t0)
    jal drawAsteroidSprite

drawAsteroidsNext:
    addi $s1, $s1, 4
    j drawAsteroidsLoop

drawAsteroidsDone:
    lw $s1, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

drawAsteroidSprite:
    addi $sp, $sp, -28
    sw $ra, 24($sp)
    sw $s1, 20($sp)
    sw $s2, 16($sp)
    sw $s3, 12($sp)
    sw $s4, 8($sp)
    sw $s5, 4($sp)
    sw $s6, 0($sp)

    move $s1, $a0
    move $s2, $a1
    move $s3, $a2
    sra $s4, $s3, 1
    li $s5, 1

    move $a0, $s1
    sub $a1, $s2, $s3
    move $a2, $s5
    jal drawBlock

    add $a0, $s1, $s3
    sub $a1, $s2, $s4
    move $a2, $s5
    jal drawBlock

    add $a0, $s1, $s3
    add $a1, $s2, $s4
    move $a2, $s5
    jal drawBlock

    move $a0, $s1
    add $a1, $s2, $s3
    move $a2, $s5
    jal drawBlock

    sub $a0, $s1, $s3
    add $a1, $s2, $s4
    move $a2, $s5
    jal drawBlock

    sub $a0, $s1, $s3
    sub $a1, $s2, $s4
    move $a2, $s5
    jal drawBlock

    move $a0, $s1
    move $a1, $s2
    li $a2, 0
    jal drawBlock

    lw $s6, 0($sp)
    lw $s5, 4($sp)
    lw $s4, 8($sp)
    lw $s3, 12($sp)
    lw $s2, 16($sp)
    lw $s1, 20($sp)
    lw $ra, 24($sp)
    addi $sp, $sp, 28
    jr $ra

drawBullets:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s1, 0($sp)

    li $s1, 0
drawBulletsLoop:
    bge $s1, BULLET_BYTES, drawBulletsDone
    la $t0, bulletActive
    add $t0, $t0, $s1
    lw $t1, 0($t0)
    beqz $t1, drawBulletsNext

    la $t0, bulletX
    add $t0, $t0, $s1
    lw $a0, 0($t0)
    la $t0, bulletY
    add $t0, $t0, $s1
    lw $a1, 0($t0)
    li $a2, 1
    jal drawBlock

drawBulletsNext:
    addi $s1, $s1, 4
    j drawBulletsLoop

drawBulletsDone:
    lw $s1, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

drawGameOverMark:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s1, 0($sp)

    lw $t0, red
    sw $t0, currentColor
    li $s1, -18

gameOverMarkLoop:
    bgt $s1, 18, gameOverMarkDone
    li $t0, 128
    add $a0, $t0, $s1
    add $a1, $t0, $s1
    li $a2, 1
    jal drawBlock

    li $t0, 128
    add $a0, $t0, $s1
    sub $a1, $t0, $s1
    li $a2, 1
    jal drawBlock

    addi $s1, $s1, 3
    j gameOverMarkLoop

gameOverMarkDone:
    lw $s1, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

drawBlock:
    addi $sp, $sp, -28
    sw $ra, 24($sp)
    sw $s1, 20($sp)
    sw $s2, 16($sp)
    sw $s3, 12($sp)
    sw $s4, 8($sp)
    sw $s5, 4($sp)
    sw $s6, 0($sp)

    move $s1, $a0
    move $s2, $a1
    move $s3, $a2
    sub $s4, $zero, $s3

drawBlockYLoop:
    bgt $s4, $s3, drawBlockDone
    sub $s5, $zero, $s3

drawBlockXLoop:
    bgt $s5, $s3, drawBlockNextY
    add $a0, $s1, $s5
    add $a1, $s2, $s4
    jal plotPixel
    addi $s5, $s5, 1
    j drawBlockXLoop

drawBlockNextY:
    addi $s4, $s4, 1
    j drawBlockYLoop

drawBlockDone:
    lw $s6, 0($sp)
    lw $s5, 4($sp)
    lw $s4, 8($sp)
    lw $s3, 12($sp)
    lw $s2, 16($sp)
    lw $s1, 20($sp)
    lw $ra, 24($sp)
    addi $sp, $sp, 28
    jr $ra

plotPixel:
    andi $t0, $a0, 255
    andi $t1, $a1, 255
    sll $t1, $t1, 8
    add $t0, $t0, $t1
    sll $t0, $t0, 2
    add $t0, $t0, $s0
    lw $t1, currentColor
    sw $t1, 0($t0)
    jr $ra

delayStart:
    li $v0, 32
    li $a0, START_GRACE_MS
    syscall
    jr $ra

delayFrame:
    li $v0, 32
    li $a0, FRAME_SLEEP_MS
    syscall
    jr $ra
