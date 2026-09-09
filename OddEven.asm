.data

msg: .asciiz "Type a number: "
msg1: .asciiz "This number is odd!\n"
msg2: .asciiz "This number is even!\n"

.text
.globl main
main:

    # Show initial message
    li $v0 4    
    la $a0, msg
    syscall

    # Read input n
    li $v0, 5
    syscall
    move $t0, $v0

    # test n & 1: zero => even, nonzero => odd
    andi $t1, $t0, 1
    beq $t1, $zero, even

odd:
    li $v0, 4
    la $a0, msg1
    syscall
    j end

even:
    li $v0, 4
    la $a0, msg2
    syscall

end:
    # End
    li $v0, 10
    syscall