# asteroids.asm
Asteroid written in MIPS assembly.

## How to Run

1. Install the emulator of choice, [MARS](http://courses.missouristate.edu/KenVollmar/MARS/).
2. Open `asteroids.asm` in MARS.
3. Use Tools -> Keyboard and Display MMIO Simulator for keyboard input.
4. Use Tools -> Bitmap Display for screen output:
   - Unit width: 1
   - Unit height: 1
   - Display width: 256
   - Display height: 256
   - Base address: `0x10008000`
5. Assemble and run the program.
6. Feed input via the Keyboard and Display MMIO Simulator.

## Controls

- `a`: rotate left
- `d`: rotate right
- `w`: thrust
- `space`: fire
- `r`: restart after collision
- `q`: quit

## Demo

https://github.com/user-attachments/assets/a0fe350a-3a44-402e-bb4f-8c5b048e6d1a
