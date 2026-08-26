.section __TEXT,__cstring,cstring_literals
msg:
	.asciz "Hello from M3\n"
msg_end:
.equ MSG_LEN, msg_end - msg - 1

.text
.globl _main
.p2align 2
_main:
	mov x0, #1
	adrp x1, msg@PAGE
	add x1, x1, msg@PAGEOFF
	mov x2, #MSG_LEN
	mov x16, #4
	svc #0x80

	mov x0, #0
	mov x16, #1
	svc #0x80
