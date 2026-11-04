# Daniel Cardoso
.data

.globl main

main:
    lui $t0, 0x1001 # load upper immediate, onde carrega o valor 0x1001 no registrador $t0
    li $t1, 16 # load immediate, onde carrega o valor 16 no registrador $t1

    cicloMemoria: # função que escreve 0 na memória, incrementa o endereço e decrementa o contador
        sw $zero, 0($t0) # store word, escreve o valor 0 no endereço de memória apontado por $t0
        addi $t0, $t0, 4 # add immediate, incrementa o valor do registrador $t0 em 4
        addi $t1, $t1, -1 # add immediate, decrementa o valor do registrador $t1 em 1
        bgtz $t1, cicloMemoria # branch if greater than zero, salta para cicloMemoria se $t1 for maior que zero

        li $v0, 10 # load immediate, onde carrega o valor 10 no registrador $v0
        syscall