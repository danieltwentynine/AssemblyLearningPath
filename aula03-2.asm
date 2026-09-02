.data

msg: .asciiz "O resultado de Y é: "

.text
.globl main
main:

    # Atribui valores
    li $s0, 20   # A
    li $s1, 5  # B
    li $s2, 2   # C
    li $s3, 1   # D
    li $s4, 3   # E

    # Resolver a equação Y = (A - B) / C + (D * E)
    sub $t0, $s0, $s1
    mul $t1, $s3, $s4
    add $t2, $s2, $t1
    div $s5, $t0, $t2

    # Imprimir a mensagem
    li $v0, 4
    la $a0, msg
    syscall

    # Imprimir resultado
    li  $v0, 1
    move $a0, $s5
    syscall

    # Finalizar o programa
    li $v0, 10
    syscall
