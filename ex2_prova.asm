# Lógica Combinacional e Saltos Condicionais (IF/ELSE) Implemente um programa que atue como um classificador de triângulos. O sistema deve ler três valores inteiros dos registradores, representando as medidas dos lados do triângulo. Faça a validação lógica: a soma de dois lados quaisquer deve ser obrigatoriamente maior que o terceiro lado. Se a condição for falsa, imprima o texto "Triangulo Invalido" no console. Se o triângulo for estruturalmente válido, utilize desvios condicionais para classificar e imprimir no console se ele é "Equilatero", "Isosceles" ou "Escaleno".

.data

msg: .asciiz "Digite o valor do lado 1: "
msg1: .asciiz "Digite o valor do lado 2: "
msg2: .asciiz "Digite o valor do lado 3: "
msg3: .asciiz "Triangulo Invalido\n"
msg4: .asciiz "Equilatero\n"
msg5: .asciiz "Isosceles\n"
msg6: .asciiz "Escaleno\n"

.text
.globl main
main:
    # Show initial message
    li $v0 4    
    la $a0, msg
    syscall

    # Read input lado1
    li $v0, 5
    syscall
    move $t0, $v0

    # Show initial message
    li $v0 4    
    la $a0, msg1
    syscall

    # Read input lado2
    li $v0, 5
    syscall
    move $t1, $v0
    # Show initial message
    li $v0 4    
    la $a0, msg2
    syscall

    # Read input lado3
    li $v0, 5
    syscall
    move $t2, $v0

    # Check if the triangle is valid
    add $t3, $t0, $t1  # t3 = lado1 + lado2
    ble $t3, $t2, invalid_triangle  # if lado1 + lado2 <= lado3, go to invalid_triangle
    add $t3, $t0, $t2  # t3 = lado1 + lado3
    ble $t3, $t1, invalid_triangle  # if lado1 + lado3 <= lado2, go to invalid_triangle
    add $t3, $t1, $t2  # t3 = lado2 + lado3
    ble $t3, $t0, invalid_triangle  # if lado2 + lado3 <= lado1, go to invalid_triangle 

    # Check for Equilateral triangle
    beq $t0, $t1, check_equilateral_2  # if lado1 == lado2, check next condition
    j check_isosceles  # else   

check_equilateral_2:
    beq $t1, $t2, print_equilateral  # if lado2 == lado3, print Equilateral
    j check_isosceles  # else

check_isosceles:
    beq $t0, $t1, print_isosceles  # if lado1 == lado2, print Isosceles
    beq $t0, $t2, print_isosceles  # if lado1 == lado3, print Isosceles
    beq $t1, $t2, print_isosceles  # if lado2 == lado3, print Isosceles
    j print_escaleno  # else, print Escaleno

invalid_triangle:
    li $v0, 4
    la $a0, msg3
    syscall
    j end_program

print_equilateral:
    li $v0, 4
    la $a0, msg4
    syscall
    j end_program
print_isosceles:
    li $v0, 4
    la $a0, msg5
    syscall
    j end_program
print_escaleno:
    li $v0, 4
    la $a0, msg6
    syscall 

end_program:
    li $v0, 10
    syscall
