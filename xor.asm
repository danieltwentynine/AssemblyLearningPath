.data

# =====================================================
# BLOCO 1 — DECLARAÇÃO DE DADOS
# =====================================================

entrada: .asciiz "entrada.txt"
# Nome do arquivo que será aberto.
# .asciiz adiciona automaticamente um byte nulo (\0)
# ao final da string.

chave: .asciiz "segredo"
# Nossa chave de criptografia.
# Cada caractere será utilizado para realizar uma
# operação XOR com um byte do arquivo.

buffer: .space 4096
# Reserva 4096 bytes de memória.
# É aqui que o conteúdo do arquivo será armazenado
# temporariamente antes de ser criptografado.


.text

main:

# =====================================================
# BLOCO 2 — ABERTURA DO ARQUIVO
# =====================================================

    li   $v0, 13
    # Define a syscall 13: abrir arquivo (open).

    la   $a0, entrada
    # $a0 recebe o endereço da string "entrada.txt".
    # Ou seja, informa qual arquivo queremos abrir.

    li   $a1, 0
    # $a1 recebe 0: modo de leitura.

    syscall
    # Executa a chamada de sistema.
    # Se funcionar, $v0 recebe o descritor do arquivo.
    # Se falhar, retorna um valor negativo.

    bltz $v0, erro
    # Branch if Less Than Zero.
    # Se $v0 for negativo, salta para o bloco erro.

    move $s0, $v0
    # Guarda o descritor do arquivo em $s0.
    # Precisaremos dele para ler e fechar o arquivo.


# =====================================================
# BLOCO 3 — LEITURA DO ARQUIVO
# =====================================================

    li   $v0, 14
    # Syscall 14: read file.

    move $a0, $s0
    # Informa qual arquivo será lido.
    # $s0 contém o descritor obtido na abertura.

    la   $a1, buffer
    # Informa onde os bytes lidos serão armazenados.
    # O destino é o espaço de memória chamado buffer.

    li   $a2, 4096
    # Define a quantidade máxima de bytes que podem
    # ser lidos nesta operação.

    syscall
    # Realiza a leitura.
    # $v0 retorna a quantidade REAL de bytes lidos.

    move $s1, $v0
    # Guarda a quantidade de bytes lidos em $s1.
    # Esse valor será utilizado como limite do loop.


# =====================================================
# BLOCO 4 — FECHAMENTO DO ARQUIVO
# =====================================================

    li   $v0, 16
    # Syscall 16: close file.

    move $a0, $s0
    # Passa o descritor do arquivo que será fechado.

    syscall
    # Fecha o arquivo.
    # Os dados continuam disponíveis no buffer!


# =====================================================
# BLOCO 5 — INICIALIZAÇÃO DOS PONTEIROS E CONTADOR
# =====================================================

    la   $t0, buffer
    # $t0 aponta para o primeiro byte do arquivo.
    # Funciona como um ponteiro que percorre o buffer.

    li   $t1, 0
    # $t1 é nosso contador.
    # Começa em zero e representa quantos bytes
    # já foram processados.

    la   $t2, chave
    # $t2 guarda o endereço inicial da chave "segredo".

    move $t3, $t2
    # $t3 aponta para o caractere atual da chave.
    # Começamos pelo primeiro caractere: 's'.


# =====================================================
# BLOCO 6 — LOOP DE CRIPTOGRAFIA XOR
# =====================================================

cifra:

    bge  $t1, $s1, grava
    # Branch if Greater or Equal.
    # Se já processamos todos os bytes do arquivo,
    # saltamos para o bloco grava.

    lbu  $t4, 0($t0)
    # Load Byte Unsigned.
    # Carrega o byte atual do arquivo em $t4.
    # Exemplo: primeiro byte = 'H' = 0x48.

    lbu  $t5, 0($t3)
    # Carrega o caractere atual da chave em $t5.
    # Exemplo: primeiro caractere = 's' = 0x73.

    xor  $t4, $t4, $t5
    # Executa a operação XOR entre o byte do arquivo
    # e o caractere da chave.
    #
    # $t4 = $t4 XOR $t5
    #
    # O resultado fica armazenado em $t4.

    sb   $t4, 0($t0)
    # Store Byte.
    # Escreve o resultado do XOR de volta no buffer.
    # Assim, substituímos o byte original pelo cifrado.

    addi $t0, $t0, 1
    # Avança o ponteiro do arquivo em 1 byte.
    # Agora aponta para o próximo caractere.

    addi $t1, $t1, 1
    # Incrementa o contador de bytes processados.

    addi $t3, $t3, 1
    # Avança o ponteiro da chave.
    # Passamos para o próximo caractere de "segredo".

    lbu  $t5, 0($t3)
    # Verifica o próximo caractere da chave.

    bnez $t5, cifra
    # Branch if Not Equal to Zero.
    # Se o próximo caractere não for \0,
    # volta para o início do loop.
    #
    # Isso significa que ainda existem caracteres
    # disponíveis na chave.

    move $t3, $t2
    # Se encontramos o terminador \0 da chave,
    # reiniciamos o ponteiro para o primeiro caractere.

    j    cifra
    # Salto incondicional para continuar a criptografia.


# =====================================================
# BLOCO 7 — ABERTURA DO ARQUIVO PARA ESCRITA
# =====================================================

grava:

    li   $v0, 13
    # Syscall 13: abrir arquivo novamente.

    la   $a0, entrada
    # Endereço do arquivo "entrada.txt".

    li   $a1, 1
    # Modo de escrita.
    # No MARS, 1 representa escrita.

    li   $a2, 0
    # Campo de modo adicional.
    # Não é utilizado nesse caso.

    syscall
    # Abre o arquivo para escrita.

    bltz $v0, erro
    # Se ocorrer erro na abertura, encerra o programa.

    move $s0, $v0
    # Guarda o novo descritor do arquivo.


# =====================================================
# BLOCO 8 — GRAVAÇÃO DO RESULTADO
# =====================================================

    li   $v0, 15
    # Syscall 15: write file.

    move $a0, $s0
    # Descritor do arquivo onde escreveremos.

    la   $a1, buffer
    # Endereço do buffer que contém os dados cifrados.

    move $a2, $s1
    # Quantidade de bytes que devem ser escritos.
    # Utilizamos a quantidade originalmente lida.

    syscall
    # Grava os bytes do buffer no arquivo.


# =====================================================
# BLOCO 9 — FECHAMENTO E ENCERRAMENTO
# =====================================================

    li   $v0, 16
    # Syscall 16: fechar arquivo.

    move $a0, $s0
    # Informa qual descritor será fechado.

    syscall
    # Fecha o arquivo após a gravação.

    li   $v0, 10
    # Syscall 10: encerrar programa.

    syscall
    # Finaliza a execução.


# =====================================================
# BLOCO 10 — TRATAMENTO DE ERRO
# =====================================================

erro:

    li   $v0, 10
    # Syscall 10: encerrar programa.

    syscall
    # Finaliza a execução caso ocorra erro.
