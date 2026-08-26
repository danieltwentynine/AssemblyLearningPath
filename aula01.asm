.data
prompt: .asciiz "Digite um nome: "
nome: .space 50
saida: .asciiz "Seu nome é: "

.text
.globl main
main:
    # Exibe o prompt para o usuário
    li $v0, 4          # Código do serviço para imprimir string
    la $a0, prompt     # Carrega o endereço da string do prompt
    syscall             # Chama o serviço do sistema        

    # Lê o nome do usuário
    li $v0, 8          # Código do serviço para ler string
    la $a0, nome       # Carrega o endereço do buffer para armazenar o nome
    li $a1, 50         # Define o tamanho máximo do buffer
    syscall             # Chama o serviço do sistema    

    # Exibe a mensagem de saída
    li $v0, 4          # Código do serviço para imprimir string
    la $a0, saida      # Carrega o endereço da string de saída
    syscall             # Chama o serviço do sistema

    # Exibe o nome digitado pelo usuário
    li $v0, 4          # Código do serviço para imprimir string
    la $a0, nome       # Carrega o endereço do buffer com o nome        
    syscall             # Chama o serviço do sistema

    # Finaliza o programa
    li $v0, 10         # Código do serviço para encerrar o programa
    syscall             # Chama o serviço do sistema
