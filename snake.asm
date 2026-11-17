# ============================================================================
#  SNAKE MIPS  -  Jogo da Cobrinha em MIPS assembly para o simulador MARS
# ============================================================================
#  Como executar (detalhes no README.md):
#    1) MARS: Tools > Bitmap Display
#         Unit Width in Pixels .... 8
#         Unit Height in Pixels ... 8
#         Display Width in Pixels . 256
#         Display Height in Pixels  256
#         Base address for display  0x10008000
#         Clique em "Connect to MIPS"
#    2) MARS: Tools > Keyboard and Display MMIO Simulator
#         Clique em "Connect to MIPS" e digite na caixa de teclado.
#    3) Abra este arquivo no MARS, monte (F3) e execute (F5).
#       Ajuste Settings > Delayed Branching = DESLIGADO (padrao do MARS).
#
#  Controles:
#     W / 8  = cima          A / 4 = esquerda
#     S / 2  = baixo         D / 6 = direita
#     P ou ESPACO = pausa    Q = sair
#     R = reiniciar (na tela de game over)
#
#  Regras: coma as frutas vermelhas para crescer e ganhar pontos.
#  Bater na parede ou no proprio corpo termina a partida.
#  Pontuacao = numero de frutas comidas (comprimento inicial = 3).
# ============================================================================

# ----------------------------- constantes -----------------------------------
.eqv DISPLAY_BASE 0x10008000     # inicio da memoria de video do Bitmap Display
.eqv KEY_CTRL     0xffff0000     # controle do receptor do teclado MMIO
.eqv KEY_DATA     0xffff0004     # dado (ASCII) do receptor do teclado MMIO

.eqv GRID_W       32             # largura do tabuleiro, em celulas
.eqv GRID_H       32             # altura do tabuleiro, em celulas
.eqv NPIXELS      1024           # GRID_W * GRID_H
.eqv FRAME_MS     140            # duracao de um frame, em milissegundos

.eqv COR_FUNDO    0x00000000     # preto
.eqv COR_CORPO    0x0000aa00     # verde escuro
.eqv COR_CABECA   0x0000ff44     # verde claro
.eqv COR_COMIDA   0x00ff0000     # vermelho
.eqv COR_MORTA    0x00666666     # cinza (cobra apos a colisao)

# ------------------------------- dados --------------------------------------
.data
head:      .word 2              # indice (no buffer circular) da cabeca
tail:      .word 0              # indice (no buffer circular) da cauda
len:       .word 3              # comprimento atual da cobra
dir:       .word 1              # direcao atual: 0=cima 1=direita 2=baixo 3=esquerda
seed:      .word 1              # semente do gerador pseudoaleatorio (LCG)
score:     .word 0              # frutas comidas
food:      .word 0              # indice da celula da fruta, ou -1 se nao houver

.align 2
snake_x:   .space 4096          # 1024 palavras: coordenada x de cada segmento
snake_y:   .space 4096          # 1024 palavras: coordenada y de cada segmento
occ:       .space 1024          # grade de ocupacao: 1 byte por celula

msg_ini:   .asciiz "\n=== SNAKE MIPS ===\nW/A/S/D (ou 8/4/2/6) = mover | P = pausar | Q = sair\nComa as frutas vermelhas. Nao bata nas paredes nem em voce mesmo!\n"
msg_pausa: .asciiz "\n[PAUSADO] Pressione P ou ESPACO para continuar.\n"
msg_volta: .asciiz "[CONTINUANDO]\n"
msg_over:  .asciiz "\n=== GAME OVER ===\nPontuacao final: "
msg_win:   .asciiz "\n=== VOCE VENCEU! TABULEIRO COMPLETO! ===\nPontuacao final: "
msg_reini: .asciiz "\nR = jogar de novo | Q = sair\n"
msg_nl:    .asciiz "\n"

# ------------------------------- codigo -------------------------------------
.text
.globl main

# ============================================================================
#  main: inicializa a semente, mostra instrucoes e inicia a partida.
# ============================================================================
main:
    # Semente pseudoaleatoria: tempo do sistema (syscall 30) misturado.
    li      $v0, 30                  # $a0 = low 32 bits, $a1 = high 32 bits
    syscall
    xor     $t0, $a0, $a1
    ori     $t0, $t0, 1              # nunca zero
    sw      $t0, seed

    la      $a0, msg_ini
    li      $v0, 4
    syscall

    jal     init_game                # limpa a tela e monta o estado inicial

# ---------------------------------------------------------------------------
#  Laco principal: espera um frame, le o teclado e move a cobra.
#  move_snake retorna em $v0: 0 = ok, 1 = colisao, 2 = tabuleiro cheio.
# ---------------------------------------------------------------------------
game_loop:
    jal     delay_frame
    jal     poll_input
    jal     move_snake
    beqz    $v0, game_loop
    li      $t0, 2
    beq     $v0, $t0, vitoria
    j       derrota

derrota:
    jal     show_dead_snake          # pinta a cobra de cinza
    la      $a0, msg_over
    li      $v0, 4
    syscall
    j       fim_mostra_score

vitoria:
    la      $a0, msg_win
    li      $v0, 4
    syscall

fim_mostra_score:
    lw      $a0, score
    li      $v0, 1
    syscall
    la      $a0, msg_nl
    li      $v0, 4
    syscall
    la      $a0, msg_reini
    li      $v0, 4
    syscall

# Espera R (reiniciar) ou Q (sair).
aguarda:
    jal     delay_frame
    jal     read_key
    li      $t0, -1
    beq     $v0, $t0, aguarda
    li      $t0, 114                 # 'r'
    beq     $v0, $t0, reiniciar
    li      $t0, 113                 # 'q'
    beq     $v0, $t0, sair
    j       aguarda

reiniciar:
    jal     init_game
    j       game_loop

sair:
    li      $v0, 10                  # encerra o programa
    syscall

# ============================================================================
#  init_game: limpa a tela e a grade, zera o placar e posiciona a cobra
#  no centro do tabuleiro, olhando para a direita. Sorteia a primeira fruta.
#  Buffers: posicoes 0,1,2 = (14,16), (15,16), (16,16); head=2, tail=0.
# ============================================================================
init_game:
    addiu   $sp, $sp, -8
    sw      $ra, 0($sp)

    # 1) limpa a tela inteira (1024 palavras = 1024 pixels pretos)
    li      $t0, DISPLAY_BASE
    li      $t1, NPIXELS
ig_tela:
    sw      $zero, 0($t0)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, -1
    bgtz    $t1, ig_tela

    # 2) limpa a grade de ocupacao (1024 bytes = 0)
    la      $t0, occ
    li      $t1, NPIXELS
ig_occ:
    sb      $zero, 0($t0)
    addiu   $t0, $t0, 1
    addiu   $t1, $t1, -1
    bgtz    $t1, ig_occ

    # 3) estado do jogo
    li      $t0, 2
    sw      $t0, head
    sw      $zero, tail
    li      $t0, 3
    sw      $t0, len
    li      $t0, 1
    sw      $t0, dir
    sw      $zero, score
    li      $t0, -1
    sw      $t0, food

    # 4) posiciona e desenha os tres segmentos iniciais
    #    i=0 -> x=14, i=1 -> x=15, i=2 -> x=16 ; todos em y=16
    li      $t0, 0                   # i = indice no buffer
    li      $t1, 14                  # x inicial
ig_corpo:
    sll     $t2, $t0, 2
    la      $t3, snake_x
    add     $t3, $t3, $t2
    sw      $t1, 0($t3)              # snake_x[i] = x
    la      $t4, snake_y
    add     $t4, $t4, $t2
    li      $t5, 16
    sw      $t5, 0($t4)              # snake_y[i] = 16
    sll     $t6, $t5, 5
    add     $t6, $t6, $t1            # indice da celula = y*32 + x
    la      $t7, occ
    add     $t7, $t7, $t6
    li      $t8, 1
    sb      $t8, 0($t7)              # occ[celula] = 1
    li      $t9, DISPLAY_BASE
    sll     $t8, $t6, 2              # cada celula ocupa 4 bytes
    add     $t9, $t9, $t8
    li      $t8, COR_CORPO
    sw      $t8, 0($t9)              # desenha o segmento
    addiu   $t1, $t1, 1
    addiu   $t0, $t0, 1
    li      $t2, 3
    blt     $t0, $t2, ig_corpo

    # 5) a cabeca (indice 2, celula 16*32+16 = 528) ganha cor propria
    li      $t0, DISPLAY_BASE
    li      $t1, 528
    sll     $t1, $t1, 2
    add     $t0, $t0, $t1
    li      $t1, COR_CABECA
    sw      $t1, 0($t0)

    # 6) primeira fruta
    jal     place_food

    lw      $ra, 0($sp)
    addiu   $sp, $sp, 8
    jr      $ra

# ============================================================================
#  move_snake: move a cobra um passo na direcao atual.
#  Retorna $v0: 0 = movimento ok, 1 = morreu, 2 = tabuleiro cheio (vitoria).
# ============================================================================
move_snake:
    addiu   $sp, $sp, -32
    sw      $ra, 0($sp)
    sw      $s0, 4($sp)              # indice (buffer) da cabeca
    sw      $s1, 8($sp)              # x da cabeca
    sw      $s2, 12($sp)             # y da cabeca
    sw      $s3, 16($sp)             # indice da celula de destino
    sw      $s4, 20($sp)             # indice (buffer) da cauda
    sw      $s5, 24($sp)             # indice da celula da cabeca atual / cauda

    # le a posicao atual da cabeca
    lw      $s0, head
    sll     $t0, $s0, 2
    la      $t1, snake_x
    add     $t1, $t1, $t0
    lw      $s1, 0($t1)
    la      $t1, snake_y
    add     $t1, $t1, $t0
    lw      $s2, 0($t1)

    # guarda o indice da celula da cabeca atual (para repinta-la de corpo)
    sll     $s5, $s2, 5
    add     $s5, $s5, $s1

    # calcula a celula de destino conforme a direcao
    lw      $t0, dir
    beqz    $t0, ms_cima
    li      $t1, 1
    beq     $t0, $t1, ms_dir
    li      $t1, 2
    beq     $t0, $t1, ms_baixo
    addiu   $s1, $s1, -1             # direcao 3 = esquerda
    j       ms_limites
ms_cima:
    addiu   $s2, $s2, -1
    j       ms_limites
ms_dir:
    addiu   $s1, $s1, 1
    j       ms_limites
ms_baixo:
    addiu   $s2, $s2, 1

ms_limites:
    # colisao com as paredes
    bltz    $s1, ms_morreu
    bltz    $s2, ms_morreu
    li      $t0, GRID_W
    bge     $s1, $t0, ms_morreu
    li      $t0, GRID_H
    bge     $s2, $t0, ms_morreu

    # indice da celula de destino
    sll     $s3, $s2, 5
    add     $s3, $s3, $s1

    # colisao com o proprio corpo. A celula da cauda e um caso especial: se a
    # cobra NAO vai comer, a cauda sai neste mesmo frame, entao entrar nela e
    # permitido (regra classica do snake).
    la      $t0, occ
    add     $t0, $t0, $s3
    lb      $t1, 0($t0)
    beqz    $t1, ms_livre
    lw      $t3, tail
    sll     $t3, $t3, 2
    la      $t4, snake_x
    add     $t4, $t4, $t3
    lw      $t5, 0($t4)              # x da cauda
    la      $t4, snake_y
    add     $t4, $t4, $t3
    lw      $t6, 0($t4)              # y da cauda
    sll     $t6, $t6, 5
    add     $t6, $t6, $t5            # indice da celula da cauda
    bne     $s3, $t6, ms_morreu      # ocupada e nao e a cauda -> morreu
    lw      $t0, food
    beq     $t0, $s3, ms_morreu      # vai comer: a cauda nao sai -> morreu
ms_livre:

    # a cabeca antiga passa a ser corpo
    move    $a0, $s5
    li      $a1, COR_CORPO
    jal     draw_cell

    # grava a nova cabeca no buffer circular
    addiu   $s0, $s0, 1
    andi    $s0, $s0, 1023
    sw      $s0, head
    sll     $t0, $s0, 2
    la      $t1, snake_x
    add     $t1, $t1, $t0
    sw      $s1, 0($t1)
    la      $t1, snake_y
    add     $t1, $t1, $t0
    sw      $s2, 0($t1)

    # marca a celula como ocupada e desenha a nova cabeca
    la      $t0, occ
    add     $t0, $t0, $s3
    li      $t1, 1
    sb      $t1, 0($t0)
    move    $a0, $s3
    li      $a1, COR_CABECA
    jal     draw_cell

    # comeu a fruta?
    lw      $t0, food
    bne     $t0, $s3, ms_sem_comida

    # --- comeu: pontua, cresce e sorteia outra fruta (a cauda NAO sai) ---
    lw      $t0, score
    addiu   $t0, $t0, 1
    sw      $t0, score
    lw      $t0, len
    addiu   $t0, $t0, 1
    sw      $t0, len
    li      $t1, NPIXELS
    beq     $t0, $t1, ms_venceu      # cobra ocupou o tabuleiro inteiro
    jal     place_food
    li      $v0, 0
    j       ms_ret

ms_sem_comida:
    # --- nao comeu: remove a cauda (apaga a celula e libera a grade) ---
    lw      $s4, tail
    sll     $t1, $s4, 2
    la      $t2, snake_x
    add     $t2, $t2, $t1
    lw      $t3, 0($t2)              # x da cauda
    la      $t2, snake_y
    add     $t2, $t2, $t1
    lw      $t4, 0($t2)              # y da cauda
    sll     $s5, $t4, 5
    add     $s5, $s5, $t3            # celula da cauda
    # se a cabeca ocupou justamente a celula da cauda, nao apague o pixel nem
    # zere a grade: a celula continua ocupada, agora pela cabeca.
    beq     $s5, $s3, ms_cauda_ok
    la      $t2, occ
    add     $t2, $t2, $s5
    sb      $zero, 0($t2)            # libera a celula
    move    $a0, $s5
    li      $a1, COR_FUNDO
    jal     draw_cell                # apaga o pixel
ms_cauda_ok:
    addiu   $s4, $s4, 1
    andi    $s4, $s4, 1023
    sw      $s4, tail
    li      $v0, 0
    j       ms_ret

ms_morreu:
    li      $v0, 1
    j       ms_ret
ms_venceu:
    li      $v0, 2

ms_ret:
    lw      $ra, 0($sp)
    lw      $s0, 4($sp)
    lw      $s1, 8($sp)
    lw      $s2, 12($sp)
    lw      $s3, 16($sp)
    lw      $s4, 20($sp)
    lw      $s5, 24($sp)
    addiu   $sp, $sp, 32
    jr      $ra

# ============================================================================
#  place_food: sorteia uma celula livre, guarda em food e desenha a fruta.
#  Usa o LCG de rand_idx; se falhar 500 vezes, varre o tabuleiro em ordem.
#  Se o tabuleiro estiver cheio, food = -1 (a vitoria e tratada em move_snake).
# ============================================================================
place_food:
    addiu   $sp, $sp, -8
    sw      $ra, 0($sp)
    sw      $s0, 4($sp)              # numero de tentativas
    li      $s0, 0
pf_try:
    jal     rand_idx
    move    $t0, $v0
    la      $t1, occ
    add     $t1, $t1, $t0
    lb      $t2, 0($t1)
    beqz    $t2, pf_ok
    addiu   $s0, $s0, 1
    li      $t3, 500
    blt     $s0, $t3, pf_try

    # fallback deterministico: procura a primeira celula livre
    li      $t0, 0
pf_scan:
    li      $t3, NPIXELS
    beq     $t0, $t3, pf_none
    la      $t1, occ
    add     $t1, $t1, $t0
    lb      $t2, 0($t1)
    beqz    $t2, pf_ok
    addiu   $t0, $t0, 1
    j       pf_scan

pf_ok:
    sw      $t0, food
    move    $a0, $t0
    li      $a1, COR_COMIDA
    jal     draw_cell
    lw      $ra, 0($sp)
    lw      $s0, 4($sp)
    addiu   $sp, $sp, 8
    jr      $ra

pf_none:
    li      $t0, -1
    sw      $t0, food
    lw      $ra, 0($sp)
    lw      $s0, 4($sp)
    addiu   $sp, $sp, 8
    jr      $ra

# ============================================================================
#  rand_idx: gerador congruente linear. Retorna em $v0 um indice 0..1023.
#  seed = seed * 1103515245 + 12345  (mod 2^32); usa os bits 16..25.
# ============================================================================
rand_idx:
    lw      $t0, seed
    li      $t1, 1103515245
    multu   $t0, $t1
    mflo    $t0
    li      $t1, 12345
    addu    $t0, $t0, $t1
    sw      $t0, seed
    srl     $t0, $t0, 16
    andi    $v0, $t0, 1023
    jr      $ra

# ============================================================================
#  draw_cell: pinta a celula $a0 (0..1023) com a cor $a1.
#  Clobbera apenas $t0 e $t1.
# ============================================================================
draw_cell:
    li      $t0, DISPLAY_BASE
    sll     $t1, $a0, 2
    add     $t0, $t0, $t1
    sw      $a1, 0($t0)
    jr      $ra

# ============================================================================
#  delay_frame: dorme FRAME_MS milissegundos (syscall 32).
# ============================================================================
delay_frame:
    li      $v0, 32
    li      $a0, FRAME_MS
    syscall
    jr      $ra

# ============================================================================
#  read_key: leitura NAO bloqueante do teclado MMIO.
#  Retorna $v0 = ASCII (minusculo) da tecla, ou -1 se nada foi digitado.
#  Ao ler 0xffff0004 o bit "ready" de 0xffff0000 e limpo pelo simulador.
# ============================================================================
read_key:
    li      $t0, KEY_CTRL
    lw      $t1, 0($t0)
    andi    $t1, $t1, 1              # bit 0 = pronto para leitura
    beqz    $t1, rk_nada
    li      $t0, KEY_DATA
    lw      $v0, 0($t0)              # consome a tecla
    li      $t1, 65
    blt     $v0, $t1, rk_fim         # abaixo de 'A': nao normaliza
    li      $t1, 90
    bgt     $v0, $t1, rk_fim         # acima de 'Z': nao normaliza
    addiu   $v0, $v0, 32             # 'A'..'Z' -> 'a'..'z'
rk_fim:
    jr      $ra
rk_nada:
    li      $v0, -1
    jr      $ra

# ============================================================================
#  poll_input: le no maximo uma tecla por frame e atualiza a direcao.
#  Rejeita giro de 180 graus. Trata pausa (P/ESPACO) e saida (Q).
# ============================================================================
poll_input:
    addiu   $sp, $sp, -8
    sw      $ra, 0($sp)
    jal     read_key
    li      $t0, -1
    beq     $v0, $t0, pi_fim

    li      $t0, 119                 # 'w'
    beq     $v0, $t0, pi_cima
    li      $t0, 56                  # '8'
    beq     $v0, $t0, pi_cima
    li      $t0, 115                 # 's'
    beq     $v0, $t0, pi_baixo
    li      $t0, 50                  # '2'
    beq     $v0, $t0, pi_baixo
    li      $t0, 97                  # 'a'
    beq     $v0, $t0, pi_esq
    li      $t0, 52                  # '4'
    beq     $v0, $t0, pi_esq
    li      $t0, 100                 # 'd'
    beq     $v0, $t0, pi_dir
    li      $t0, 54                  # '6'
    beq     $v0, $t0, pi_dir
    li      $t0, 112                 # 'p'
    beq     $v0, $t0, pi_pausa
    li      $t0, 32                  # ESPACO
    beq     $v0, $t0, pi_pausa
    li      $t0, 113                 # 'q'
    beq     $v0, $t0, pi_sair
    j       pi_fim

pi_cima:
    li      $a0, 0
    j       pi_aplica
pi_dir:
    li      $a0, 1
    j       pi_aplica
pi_baixo:
    li      $a0, 2
    j       pi_aplica
pi_esq:
    li      $a0, 3
pi_aplica:
    lw      $t0, dir
    addiu   $t0, $t0, 2
    andi    $t0, $t0, 3              # direcao oposta
    beq     $t0, $a0, pi_fim         # ignora giro de 180 graus
    sw      $a0, dir
    j       pi_fim

pi_pausa:
    jal     pause_loop
    j       pi_fim

pi_sair:
    li      $v0, 10
    syscall

pi_fim:
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 8
    jr      $ra

# ============================================================================
#  pause_loop: congela o jogo ate P/ESPACO. Q encerra o programa.
# ============================================================================
pause_loop:
    addiu   $sp, $sp, -8
    sw      $ra, 0($sp)
    la      $a0, msg_pausa
    li      $v0, 4
    syscall
pl_loop:
    jal     delay_frame
    jal     read_key
    li      $t0, -1
    beq     $v0, $t0, pl_loop
    li      $t0, 112                 # 'p'
    beq     $v0, $t0, pl_fim
    li      $t0, 32                  # ESPACO
    beq     $v0, $t0, pl_fim
    li      $t0, 113                 # 'q'
    beq     $v0, $t0, pl_sair
    j       pl_loop
pl_fim:
    la      $a0, msg_volta
    li      $v0, 4
    syscall
    lw      $ra, 0($sp)
    addiu   $sp, $sp, 8
    jr      $ra
pl_sair:
    li      $v0, 10
    syscall

# ============================================================================
#  show_dead_snake: repinta todos os segmentos da cobra em cinza.
# ============================================================================
show_dead_snake:
    addiu   $sp, $sp, -16
    sw      $ra, 0($sp)
    sw      $s0, 4($sp)              # percorre o buffer a partir da cauda
    sw      $s1, 8($sp)              # contador
    lw      $s0, tail
    li      $s1, 0
sds_loop:
    lw      $t0, len
    beq     $s1, $t0, sds_fim
    sll     $t1, $s0, 2
    la      $t2, snake_x
    add     $t2, $t2, $t1
    lw      $t3, 0($t2)              # x do segmento
    la      $t2, snake_y
    add     $t2, $t2, $t1
    lw      $t4, 0($t2)              # y do segmento
    sll     $t4, $t4, 5
    add     $t4, $t4, $t3            # celula = y*32 + x
    move    $a0, $t4
    li      $a1, COR_MORTA
    jal     draw_cell
    addiu   $s0, $s0, 1
    andi    $s0, $s0, 1023
    addiu   $s1, $s1, 1
    j       sds_loop
sds_fim:
    lw      $ra, 0($sp)
    lw      $s0, 4($sp)
    lw      $s1, 8($sp)
    addiu   $sp, $sp, 16
    jr      $ra
