.data

A:  .word 10
B:  .word 5
C:  .word 3
D:  .word 2
result: .word 0

.text
.globl main

main:
    
    lw $t1, A
    lw $t2, B
    lw $t3, C
    lw $t4, D

    add $t5, $t1, $t2 # A + B --> T5
    add $t6, $t3, $t4 # C + D --> T6
    sub $t0, $t5, $t6 # (A + B) - (C + D) --> T0

    sw $t0, result

    li $v0, 10
    syscall