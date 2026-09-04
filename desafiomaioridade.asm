.data

msg: .asciiz "Qual a sua idade? "
menor_msg: .asciiz "Você é menor de idade.\n"
maior_msg: .asciiz "Você é maior de idade.\n"

.text
.globl main
main:
    # Imprimir msg
    li $v0, 4
    la $a0, msg
    syscall

    # Ler idade
    li $v0, 5
    syscall 
    move $t0, $v0 # Armazenar idade em $t0

    # Verficar se idade >= 18
    li $t1, 18
    bge $t0, $t1, maior

    # Se não for maior que 18
    li $v0, 4
    la $a0, menor_msg
    syscall
    j fim

maior:
    li $v0, 4
    la $a0, maior_msg
    syscall

fim:
    li $v0, 10
    syscall
