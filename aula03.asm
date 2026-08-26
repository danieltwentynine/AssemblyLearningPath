.data

msg: .asciiz "O resultado de Y é: "

.text
.globl main
main:

    # Atribui valores
    li $s0, 40
    li $s1, -20
    
    # Resolver a equcao Y = A / (A + B)
    add $t0, $s0, $s1      # A + B
    div $s2, $s0, $t0           # A / (A + B)

    # Imprimir a mensagem
    li  $v0, 4
    la $a0, msg
    syscall

    # Imprimir o resultado
    li  $v0, 1
    move $a0, $s2
    syscall

    # Finalizar o programa
    li $v0, 10
    syscall
