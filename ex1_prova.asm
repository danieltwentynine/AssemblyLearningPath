.data

num1: .word 8 # usamos .word para declarar variaveis de valores inteiros como numeros de 32 bits
num2: .word 16
num3: .word 4
result: .word 0

.text
.globl main
main:
    # Carrega os valores das variaveis da memoria para os registradores
    lw $t0, num1      # Carrega o primeiro numero em $t0
    lw $t1, num2      # Carrega o segundo numero em $t1
    lw $t2, num3      # Carrega o terceiro numero em $t2

    # Multiplica o primeiro numero por 4 usando deslocamento a esquerda
    sll $t0, $t0, 2   # $t0 = $t0 * 4   

    # Divide o segundo numero por 8 usando deslocamento a direita
    srl $t1, $t1, 3   # $t1 = $t1 / 8

    # Soma os resultados
    add $t3, $t0, $t1  # $t3 = $t0 + $t1    

    # Subtrai o terceiro numero com o resultado da soma
    sub $t3, $t3, $t2  # $t3 = $t3 - $t2

    # Armazena o resultado final na memoria
    sw $t3, result  # Armazena o resultado final em result

    # Imprime result 
    li $v0, 1
    lw $a0, result  
    syscall

    # Fim
    li $v0, 10
    syscall

