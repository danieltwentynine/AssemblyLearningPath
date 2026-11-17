# ============================================================================
#  FILTROS DE IMAGEM E ESTEGANOGRAFIA  -  MIPS assembly para o MARS 4.5
# ============================================================================
#  Como executar (detalhes no README.md):
#    1) MARS: Tools > Bitmap Display
#         Unit Width in Pixels .... 4
#         Unit Height in Pixels ... 4
#         Display Width in Pixels . 256
#         Display Height in Pixels  256
#         Base address for display  0x10008000
#         Clique em "Connect to MIPS"
#    2) MARS: Tools > Keyboard and Display MMIO Simulator
#         Clique em "Connect to MIPS".
#    3) Abra este arquivo no MARS, monte (F3) e execute (F5).
#       Settings > Delayed Branching deve estar DESLIGADO (padrao do MARS).
#    4) Clique dentro da caixa de texto do teclado MMIO e digite as teclas.
#
#  A imagem e uma matriz 64x64 de words 0x00RRGGBB (4096 pixels).
#  Cada pixel ocupa 1 celula do Bitmap Display (4x4 pixels na tela).
#
#  Teclas:
#     0 = Original        1 = Escala de cinza   2 = Negativo
#     3 = Brilho +40      4 = Brilho -40        5 = So canal R
#     6 = Sepia           7 = Desfoque 3x3      8 = Bordas (Sobel)
#     9 = Mapa de LSB
#     H = esconder mensagem (digite e ENTER; BACKSPACE apaga; ESC cancela)
#     X = extrair mensagem     C = limpar LSBs
#     M = mostrar menu         Q = sair
#
#  Esteganografia: 1 bit por pixel, no bit 0 da palavra (LSB do azul).
#     pixels   0..31  : 32 bits de cabecalho = tamanho da mensagem em bytes
#     pixels  32..    : 8 bits por caractere (big-endian)
#     capacidade      : 32 + 8*len <= 4096  =>  len <= 508 caracteres
# ============================================================================

# >>> CONSTANTES-INICIO
.eqv DISPLAY_BASE 0x10008000     # inicio da memoria de video do Bitmap Display
.eqv KEY_CTRL     0xffff0000     # controle do receptor do teclado MMIO
.eqv KEY_DATA     0xffff0004     # dado (ASCII) do receptor do teclado MMIO

.eqv IMG_W        64             # largura da imagem, em pixels
.eqv IMG_H        64             # altura da imagem, em pixels
.eqv NPIX         4096           # IMG_W * IMG_H
.eqv MSG_MAX      508            # (4096 - 32) / 8 caracteres
.eqv MSG_BUF      512            # tamanho do buffer da mensagem (com NUL)
# <<< CONSTANTES-FIM

# ------------------------------- dados --------------------------------------
.data

# >>> DADOS-INICIO
.align 2
orig:        .space 16384        # 4096 words: imagem base 0x00RRGGBB
work:        .space 16384        # 4096 words: resultado do filtro atual
luma:        .space 16384        # 4096 words: luminancia auxiliar do Sobel
msg:         .space 512          # buffer da mensagem (bytes ASCII)
msglen:      .word 0             # tamanho atual da mensagem

.align 2
filter_table:                    # tabela de saltos dos filtros (id -> rotina)
    .word filter_copy
    .word filter_gray
    .word filter_negative
    .word filter_bright_up
    .word filter_bright_down
    .word filter_red
    .word filter_sepia
    .word filter_blur
    .word filter_sobel
    .word filter_lsbmap
# <<< DADOS-FIM

# ---- estado e textos da interface (fora do nucleo testado) ------------------
cur:         .word 0             # filtro atualmente exibido

msg_banner:
    .asciiz "\n==============================================================\n FILTROS DE IMAGEM E ESTEGANOGRAFIA - MIPS / MARS 4.5\n==============================================================\n Imagem 64x64 (4096 pixels 0x00RRGGBB)\n Bitmap Display: 256x256, unidade 4x4, base 0x10008000\n\n [0] Original       [1] Escala de cinza   [2] Negativo\n [3] Brilho +40     [4] Brilho -40        [5] So canal R\n [6] Sepia          [7] Desfoque 3x3      [8] Bordas (Sobel)\n [9] Mapa de LSB\n [H] Esconder mensagem   [X] Extrair mensagem\n [C] Limpar LSBs         [M] Mostrar menu   [Q] Sair\n\n Clique na janela do Keyboard and Display MMIO Simulator\n e digite uma tecla. Mensagens usam 1 bit por pixel (LSB azul).\n"

msg_pronto:  .asciiz "\n[OK] Imagem base gerada. Use as teclas acima.\n"
msg_filtro:  .asciiz "[FILTRO] "
msg_nl:      .asciiz "\n"
msg_adeus:   .asciiz "\nAte mais!\n"

msg_esconder:
    .asciiz "\n[ESTEGANOGRAFIA] Digite a mensagem (ASCII 32-126).\nENTER confirma | BACKSPACE apaga | ESC cancela.\n> "
msg_cancel:     .asciiz "\n[ESTEGANOGRAFIA] Entrada cancelada.\n"
msg_embed_ok1:  .asciiz "\n[OK] Mensagem embutida: "
msg_embed_ok2:  .asciiz " caracteres ("
msg_embed_ok3:  .asciiz " bits). Use X para extrair e 9 para ver o mapa LSB.\n"
msg_embed_err:  .asciiz "\n[ERRO] Nao foi possivel embutir a mensagem.\n"

msg_ext_none:   .asciiz "\n[ESTEGANOGRAFIA] Nenhuma mensagem valida encontrada nos LSBs.\n"
msg_ext_tit:    .asciiz "\n[ESTEGANOGRAFIA] Mensagem encontrada ("
msg_ext_tit2:   .asciiz " caracteres):\n  "
msg_ext_bits:   .asciiz "\n[ESTEGANOGRAFIA] Bits lidos: "
msg_ext_bits2:  .asciiz " (32 de cabecalho + 8 por caractere)\n"

msg_clear:      .asciiz "\n[ESTEGANOGRAFIA] LSBs zerados. A mensagem (se havia) foi removida.\n"

.align 2
f_names:
    .word s_orig, s_gray, s_neg, s_brp, s_brn, s_red, s_sep, s_blur, s_sob, s_lsb
s_orig: .asciiz "Original"
s_gray: .asciiz "Escala de cinza"
s_neg:  .asciiz "Negativo"
s_brp:  .asciiz "Brilho +40"
s_brn:  .asciiz "Brilho -40"
s_red:  .asciiz "So canal R"
s_sep:  .asciiz "Sepia"
s_blur: .asciiz "Desfoque 3x3"
s_sob:  .asciiz "Bordas (Sobel)"
s_lsb:  .asciiz "Mapa de LSB"

# ------------------------------- codigo -------------------------------------
.text
.globl main

# ============================================================================
#  main: mostra o menu, gera a imagem, desenha e entra no laco de teclado.
# ============================================================================
main:
    la      $a0, msg_banner
    jal     print_str

    jal     gen_image                # gera a imagem de teste na memoria
    li      $a0, 0                   # filtro Original
    jal     select_filter            # aplica, faz blit e imprime o nome

    la      $a0, msg_pronto
    jal     print_str

# ---------------------------------------------------------------------------
#  Laco principal: le uma tecla (nao bloqueante) e processa.
# ---------------------------------------------------------------------------
main_loop:
    jal     read_key
    bltz    $v0, main_idle           # nenhuma tecla: dorme um pouco
    move    $a0, $v0
    jal     handle_key
    bnez    $v0, main_exit           # 1 = sair
    j       main_loop

main_idle:
    li      $v0, 32                  # syscall 32: sleep
    li      $a0, 20                  # 20 ms
    syscall
    j       main_loop

main_exit:
    la      $a0, msg_adeus
    jal     print_str
    li      $v0, 10
    syscall

# ============================================================================
#  handle_key: trata a tecla recebida em $a0.
#  Retorna $v0 = 1 para encerrar o programa, 0 para continuar.
# ============================================================================
handle_key:
    addiu   $sp, $sp, -8
    sw      $ra, 4($sp)

    # --- digitos 0..9: selecionam filtros ---
    li      $t0, '0'
    blt     $a0, $t0, hk_letra
    li      $t0, '9'
    bgt     $a0, $t0, hk_letra
    li      $t0, '0'
    sub     $a0, $a0, $t0
    jal     select_filter
    j       hk_fim

hk_letra:
    # converte para minuscula para aceitar H/h, X/x, C/c, M/m, Q/q
    move    $t2, $a0
    ori     $t2, $t2, 0x20

    li      $t0, 'h'
    beq     $t2, $t0, hk_esconder
    li      $t0, 'x'
    beq     $t2, $t0, hk_extrair
    li      $t0, 'c'
    beq     $t2, $t0, hk_limpar
    li      $t0, 'm'
    beq     $t2, $t0, hk_menu
    li      $t0, 'q'
    beq     $t2, $t0, hk_sair
    j       hk_fim                   # tecla desconhecida: ignora

hk_esconder:
    jal     hide_flow
    j       hk_fim
hk_extrair:
    jal     extract_flow
    j       hk_fim
hk_limpar:
    jal     clear_flow
    j       hk_fim
hk_menu:
    la      $a0, msg_banner
    jal     print_str
    j       hk_fim
hk_sair:
    li      $v0, 1
    j       hk_ret

hk_fim:
    li      $v0, 0
hk_ret:
    lw      $ra, 4($sp)
    addiu   $sp, $sp, 8
    jr      $ra

# ============================================================================
#  select_filter: aplica o filtro $a0, copia para a tela e mostra o nome.
# ============================================================================
select_filter:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $s0, 8($sp)

    move    $s0, $a0
    sw      $s0, cur                 # guarda o filtro atual
    move    $a0, $s0
    jal     apply_filter
    jal     blit

    la      $a0, msg_filtro
    jal     print_str
    la      $a0, f_names
    sll     $t0, $s0, 2
    add     $a0, $a0, $t0
    lw      $a0, 0($a0)
    jal     print_str
    la      $a0, msg_nl
    jal     print_str

    lw      $s0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    jr      $ra

# ============================================================================
#  refresh: reaplica o filtro atual (cur) sobre a imagem base e faz blit.
#  Usado depois de esconder/extrair/limpar, pois a esteganografia altera orig.
# ============================================================================
refresh:
    addiu   $sp, $sp, -8
    sw      $ra, 4($sp)
    lw      $a0, cur
    jal     apply_filter
    jal     blit
    lw      $ra, 4($sp)
    addiu   $sp, $sp, 8
    jr      $ra

# ============================================================================
#  hide_flow: le uma mensagem pelo teclado MMIO e a embute nos LSBs.
# ============================================================================
hide_flow:
    addiu   $sp, $sp, -24
    sw      $ra, 20($sp)
    sw      $s0, 16($sp)
    sw      $s1, 12($sp)

    la      $a0, msg_esconder
    jal     print_str
    sw      $zero, msglen
    li      $s0, 0                   # comprimento digitado

hide_loop:
    jal     read_key
    bltz    $v0, hide_idle
    li      $t0, 10                  # ENTER
    beq     $v0, $t0, hide_commit
    li      $t0, 13                  # CR
    beq     $v0, $t0, hide_commit
    li      $t0, 27                  # ESC
    beq     $v0, $t0, hide_esc
    li      $t0, 8                   # BACKSPACE
    beq     $v0, $t0, hide_back

    # aceita somente ASCII imprimivel 32..126
    li      $t0, 32
    blt     $v0, $t0, hide_loop
    li      $t0, 126
    bgt     $v0, $t0, hide_loop

    # acrescenta se ainda houver espaco (MSG_MAX)
    li      $t0, MSG_MAX
    bge     $s0, $t0, hide_loop
    la      $t1, msg
    add     $t1, $t1, $s0
    sb      $v0, 0($t1)
    addiu   $s0, $s0, 1
    move    $a0, $v0
    jal     print_char               # ecoa no console
    j       hide_loop

hide_idle:
    li      $v0, 32
    li      $a0, 15
    syscall
    j       hide_loop

hide_back:
    blez    $s0, hide_loop
    addiu   $s0, $s0, -1
    li      $a0, 8
    jal     print_char
    li      $a0, 32
    jal     print_char
    li      $a0, 8
    jal     print_char
    j       hide_loop

hide_esc:
    la      $a0, msg_cancel
    jal     print_str
    j       hide_fim

hide_commit:
    la      $a0, msg_nl
    jal     print_str
    beqz    $s0, hide_cancel         # mensagem vazia = cancelar

    la      $a0, msg
    move    $a1, $s0
    jal     embed_message
    move    $s1, $v0
    bnez    $s1, hide_erro

    jal     refresh                  # redesenha com o filtro atual
    la      $a0, msg_embed_ok1
    jal     print_str
    move    $a0, $s0
    jal     print_int
    la      $a0, msg_embed_ok2
    jal     print_str
    sll     $t0, $s0, 3
    addiu   $t0, $t0, 32
    move    $a0, $t0
    jal     print_int
    la      $a0, msg_embed_ok3
    jal     print_str
    j       hide_fim

hide_erro:
    la      $a0, msg_embed_err
    jal     print_str
    j       hide_fim

hide_cancel:
    la      $a0, msg_cancel
    jal     print_str

hide_fim:
    lw      $s1, 12($sp)
    lw      $s0, 16($sp)
    lw      $ra, 20($sp)
    addiu   $sp, $sp, 24
    jr      $ra

# ============================================================================
#  extract_flow: le os LSBs, valida e imprime a mensagem no console.
# ============================================================================
extract_flow:
    addiu   $sp, $sp, -16
    sw      $ra, 12($sp)
    sw      $s0, 8($sp)

    la      $a0, msg
    li      $a1, MSG_BUF
    jal     extract_message
    move    $s0, $v0
    beqz    $s0, ext_vazio

    la      $a0, msg_ext_tit
    jal     print_str
    move    $a0, $s0
    jal     print_int
    la      $a0, msg_ext_tit2
    jal     print_str
    la      $a0, msg
    jal     print_str

    la      $a0, msg_ext_bits
    jal     print_str
    sll     $t0, $s0, 3
    addiu   $t0, $t0, 32
    move    $a0, $t0
    jal     print_int
    la      $a0, msg_ext_bits2
    jal     print_str
    j       ext_fim

ext_vazio:
    la      $a0, msg_ext_none
    jal     print_str

ext_fim:
    lw      $s0, 8($sp)
    lw      $ra, 12($sp)
    addiu   $sp, $sp, 16
    jr      $ra

# ============================================================================
#  clear_flow: remove a esteganografia (zera os LSBs) e atualiza a tela.
# ============================================================================
clear_flow:
    addiu   $sp, $sp, -8
    sw      $ra, 4($sp)
    jal     clear_lsb
    jal     refresh
    la      $a0, msg_clear
    jal     print_str
    lw      $ra, 4($sp)
    addiu   $sp, $sp, 8
    jr      $ra

# ============================================================================
#  Rotinas utilitarias da interface
# ============================================================================

# read_key: leitura NAO bloqueante do teclado MMIO.
#   Retorna $v0 = ASCII da tecla, ou -1 se nenhuma tecla estiver pronta.
read_key:
    li      $t0, KEY_CTRL
    lw      $t1, 0($t0)
    andi    $t1, $t1, 1
    beqz    $t1, rk_none
    li      $t0, KEY_DATA
    lw      $v0, 0($t0)
    jr      $ra
rk_none:
    li      $v0, -1
    jr      $ra

# print_str: imprime a string terminada em NUL apontada por $a0.
print_str:
    li      $v0, 4
    syscall
    jr      $ra

# print_int: imprime o inteiro em $a0.
print_int:
    li      $v0, 1
    syscall
    jr      $ra

# print_char: imprime o caractere em $a0.
print_char:
    li      $v0, 11
    syscall
    jr      $ra

# ============================================================================
#  NUCLEO: rotinas de imagem, filtros e esteganografia
#  (verificaveis isoladamente pelos testes automaticos; sem syscalls)
# ============================================================================
# >>> ROTINAS-INICIO

# ============================================================================
#  gen_image: gera a imagem de teste 64x64 em orig.
#  Paisagem: ceu em degrade, sol, duas montanhas com neve, agua com ondas,
#  reflexo do sol e um barco. O LSB do azul fica sempre 0.
#  Nao usa syscalls nem aleatoriedade (imagem deterministica).
# ============================================================================
gen_image:
    addiu   $sp, $sp, -24
    sw      $s0, 20($sp)
    sw      $s1, 16($sp)
    sw      $s2, 12($sp)
    la      $s2, orig
    li      $s0, 0                   # y = 0
gi_y:
    li      $s1, 0                   # x = 0
gi_x:
    # cores base do ceu: r = 40 + 4y, g = 70 + 3y, b = 160 - 2y
    sll     $t0, $s0, 2
    addiu   $t0, $t0, 40             # r
    li      $t1, 3
    mul     $t1, $s0, $t1
    addiu   $t1, $t1, 70             # g
    sll     $t2, $s0, 1
    li      $t3, 160
    sub     $t2, $t3, $t2            # b

    # ---------------- ceu e sol (somente y < 44) ----------------
    li      $t3, 44
    bge     $s0, $t3, gi_sky_done
    addiu   $t4, $s1, -46            # dx = x - 46
    addiu   $t5, $s0, -15            # dy = y - 15
    mul     $t6, $t4, $t4
    mul     $t7, $t5, $t5
    add     $t6, $t6, $t7            # d2 = dx*dx + dy*dy
    li      $t7, 64                  # raio^2 do disco = 8^2
    bgt     $t6, $t7, gi_halo
    li      $t0, 255                 # disco do sol
    li      $t1, 240
    li      $t2, 120
    j       gi_sky_done
gi_halo:
    li      $t7, 121                 # raio^2 do halo = 11^2
    bgt     $t6, $t7, gi_sky_done
    li      $t0, 255                 # halo do sol
    li      $t1, 205
    li      $t2, 90
gi_sky_done:

    # ---------------- montanhas ----------------
    li      $t5, 45                  # topo da montanha (45 = nenhuma)
    li      $t6, 32
    bgt     $s1, $t6, gi_mount_right
    addiu   $t7, $s1, -18
    sra     $t8, $t7, 31
    xor     $t7, $t7, $t8
    subu    $t7, $t7, $t8            # abs(x - 18)
    li      $t8, 14
    sub     $t7, $t8, $t7            # h = 14 - abs(x-18)
    blez    $t7, gi_mount_right
    li      $t8, 44
    sub     $t9, $t8, $t7            # t = 44 - h
    bge     $t9, $t5, gi_mount_right
    move    $t5, $t9
gi_mount_right:
    li      $t6, 32
    blt     $s1, $t6, gi_mount_done
    addiu   $t7, $s1, -44
    sra     $t8, $t7, 31
    xor     $t7, $t7, $t8
    subu    $t7, $t7, $t8            # abs(x - 44)
    li      $t8, 12
    sub     $t7, $t8, $t7            # h = 12 - abs(x-44)
    blez    $t7, gi_mount_done
    li      $t8, 44
    sub     $t9, $t8, $t7
    bge     $t9, $t5, gi_mount_done
    move    $t5, $t9
gi_mount_done:
    blt     $s0, $t5, gi_water        # y acima do topo: nao e montanha
    li      $t6, 44
    bge     $s0, $t6, gi_water        # y na agua
    li      $t0, 58                  # silhueta da montanha
    li      $t1, 42
    li      $t2, 78
    addiu   $t7, $t5, 3
    bge     $s0, $t7, gi_water
    li      $t0, 205                 # neve no topo
    li      $t1, 205
    li      $t2, 225

    # ---------------- agua (somente y >= 44) ----------------
gi_water:
    li      $t6, 44
    blt     $s0, $t6, gi_pixel       # ceu ou montanha
    li      $t0, 18
    addiu   $t7, $s0, -44            # y - 44
    sll     $t8, $t7, 1              # 2*(y-44)
    addiu   $t1, $t8, 58             # g
    addiu   $t2, $t8, 130            # b
    add     $t9, $s1, $t8            # x + 2*(y-44)
    li      $t3, 10
    div     $t9, $t3
    mfhi    $t9
    li      $t3, 2
    bge     $t9, $t3, gi_waves_done
    addiu   $t0, $t0, 24             # onda clara
    addiu   $t1, $t1, 24
    addiu   $t2, $t2, 24
gi_waves_done:
    # reflexo do sol (faixa vertical com brilho alternado)
    li      $t3, 40
    blt     $s1, $t3, gi_refl_done
    li      $t3, 52
    bgt     $s1, $t3, gi_refl_done
    li      $t3, 46
    blt     $s0, $t3, gi_refl_done
    addiu   $t4, $s1, -46
    sra     $t5, $t4, 31
    xor     $t4, $t4, $t5
    subu    $t4, $t4, $t5            # abs(x - 46)
    li      $t3, 52
    sub     $t4, $t3, $t4            # k
    add     $t5, $s1, $s0
    li      $t3, 4
    div     $t5, $t3
    mfhi    $t5
    li      $t3, 2
    bge     $t5, $t3, gi_refl_done
    sll     $t5, $t4, 1
    add     $t0, $t0, $t5
    add     $t1, $t1, $t5
    add     $t2, $t2, $t4
gi_refl_done:
    # barco: casco (linhas 55/56 vermelho, 57 vermelho escuro)
    li      $t3, 12
    blt     $s1, $t3, gi_mast
    li      $t3, 22
    bgt     $s1, $t3, gi_mast
    li      $t3, 55
    beq     $s0, $t3, gi_hull
    addiu   $t3, $t3, 1
    beq     $s0, $t3, gi_hull
    li      $t3, 57
    beq     $s0, $t3, gi_hull2
    j       gi_mast
gi_hull:
    li      $t0, 180
    li      $t1, 30
    li      $t2, 30
    j       gi_mast
gi_hull2:
    li      $t0, 120
    li      $t1, 20
    li      $t2, 20
gi_mast:
    # mastro (x = 17, y = 47..55)
    li      $t3, 17
    bne     $s1, $t3, gi_sail
    li      $t3, 47
    blt     $s0, $t3, gi_sail
    li      $t3, 55
    bgt     $s0, $t3, gi_sail
    li      $t0, 60
    li      $t1, 40
    li      $t2, 20
gi_sail:
    # vela (triangulo branco)
    li      $t3, 17
    blt     $s1, $t3, gi_pixel
    li      $t3, 21
    bgt     $s1, $t3, gi_pixel
    li      $t3, 47
    blt     $s0, $t3, gi_pixel
    li      $t3, 54
    bgt     $s0, $t3, gi_pixel
    li      $t3, 54
    sub     $t4, $t3, $s0
    srl     $t4, $t4, 1              # (54 - y) / 2
    addiu   $t5, $s1, -17
    bgt     $t5, $t4, gi_pixel
    li      $t0, 245
    li      $t1, 240
    li      $t2, 230

gi_pixel:
    # monta a word 0x00RRGGBB, com LSB do azul = 0
    andi    $t2, $t2, 0xFE
    sll     $t0, $t0, 16
    sll     $t1, $t1, 8
    or      $t0, $t0, $t1
    or      $t0, $t0, $t2
    sll     $t3, $s0, 6              # y * 64
    add     $t3, $t3, $s1
    sll     $t3, $t3, 2
    add     $t3, $s2, $t3
    sw      $t0, 0($t3)

    addiu   $s1, $s1, 1
    li      $t3, 64
    blt     $s1, $t3, gi_x
    addiu   $s0, $s0, 1
    li      $t3, 64
    blt     $s0, $t3, gi_y

    lw      $s2, 12($sp)
    lw      $s1, 16($sp)
    lw      $s0, 20($sp)
    addiu   $sp, $sp, 24
    jr      $ra

# ============================================================================
#  apply_filter: aplica o filtro cujo id esta em $a0.
#  Le APENAS a imagem base (orig) e grava o resultado em work.
#  Retorna $v0 = 0 (ok) ou -1 (id invalido).
# ============================================================================
apply_filter:
    bltz    $a0, af_bad
    li      $t0, 10
    bge     $a0, $t0, af_bad
    la      $t0, filter_table
    sll     $t1, $a0, 2
    add     $t0, $t0, $t1
    lw      $t0, 0($t0)
    jr      $t0                      # salta direto para a rotina do filtro
af_bad:
    li      $v0, -1
    jr      $ra

# ============================================================================
#  filter_copy (id 0): copia orig para work.
# ============================================================================
filter_copy:
    la      $t0, orig
    la      $t1, work
    li      $t2, 0
    li      $t3, NPIX
fc_loop:
    lw      $t4, 0($t0)
    sw      $t4, 0($t1)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 1
    blt     $t2, $t3, fc_loop
    li      $v0, 0
    jr      $ra

# ============================================================================
#  filter_gray (id 1): escala de cinza por luminancia ITU-R 601
#  L = (77R + 150G + 29B) >> 8
# ============================================================================
filter_gray:
    la      $t0, orig
    la      $t1, work
    li      $t2, 0
    li      $t3, NPIX
fg_loop:
    lw      $t4, 0($t0)
    srl     $t5, $t4, 16
    andi    $t5, $t5, 0xFF           # R
    srl     $t6, $t4, 8
    andi    $t6, $t6, 0xFF           # G
    andi    $t7, $t4, 0xFF           # B
    li      $t8, 77
    mul     $t5, $t5, $t8
    li      $t8, 150
    mul     $t6, $t6, $t8
    li      $t8, 29
    mul     $t7, $t7, $t8
    add     $t5, $t5, $t6
    add     $t5, $t5, $t7
    srl     $t5, $t5, 8              # L
    sll     $t6, $t5, 16
    sll     $t7, $t5, 8
    or      $t5, $t5, $t6
    or      $t5, $t5, $t7
    sw      $t5, 0($t1)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 1
    blt     $t2, $t3, fg_loop
    li      $v0, 0
    jr      $ra

# ============================================================================
#  filter_negative (id 2): negativo = 0x00FFFFFF XOR pixel.
# ============================================================================
filter_negative:
    la      $t0, orig
    la      $t1, work
    li      $t2, 0
    li      $t3, NPIX
fn_loop:
    lw      $t4, 0($t0)
    li      $t5, 0x00FFFFFF
    xor     $t4, $t4, $t5
    sw      $t4, 0($t1)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 1
    blt     $t2, $t3, fn_loop
    li      $v0, 0
    jr      $ra

# ============================================================================
#  filter_bright_up (id 3): soma 40 em cada canal, saturando em 255.
# ============================================================================
filter_bright_up:
    la      $t0, orig
    la      $t1, work
    li      $t2, 0
    li      $t3, NPIX
fbu_loop:
    lw      $t4, 0($t0)
    srl     $t5, $t4, 16
    andi    $t5, $t5, 0xFF
    srl     $t6, $t4, 8
    andi    $t6, $t6, 0xFF
    andi    $t7, $t4, 0xFF
    li      $t9, 255
    addiu   $t5, $t5, 40
    ble     $t5, $t9, fbu_r
    move    $t5, $t9
fbu_r:
    addiu   $t6, $t6, 40
    ble     $t6, $t9, fbu_g
    move    $t6, $t9
fbu_g:
    addiu   $t7, $t7, 40
    ble     $t7, $t9, fbu_b
    move    $t7, $t9
fbu_b:
    sll     $t8, $t5, 16
    sll     $t9, $t6, 8
    or      $t8, $t8, $t9
    or      $t8, $t8, $t7
    sw      $t8, 0($t1)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 1
    blt     $t2, $t3, fbu_loop
    li      $v0, 0
    jr      $ra

# ============================================================================
#  filter_bright_down (id 4): subtrai 40 de cada canal, saturando em 0.
# ============================================================================
filter_bright_down:
    la      $t0, orig
    la      $t1, work
    li      $t2, 0
    li      $t3, NPIX
fbd_loop:
    lw      $t4, 0($t0)
    srl     $t5, $t4, 16
    andi    $t5, $t5, 0xFF
    srl     $t6, $t4, 8
    andi    $t6, $t6, 0xFF
    andi    $t7, $t4, 0xFF
    addiu   $t5, $t5, -40
    bge     $t5, $zero, fbd_r
    li      $t5, 0
fbd_r:
    addiu   $t6, $t6, -40
    bge     $t6, $zero, fbd_g
    li      $t6, 0
fbd_g:
    addiu   $t7, $t7, -40
    bge     $t7, $zero, fbd_b
    li      $t7, 0
fbd_b:
    sll     $t8, $t5, 16
    sll     $t9, $t6, 8
    or      $t8, $t8, $t9
    or      $t8, $t8, $t7
    sw      $t8, 0($t1)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 1
    blt     $t2, $t3, fbd_loop
    li      $v0, 0
    jr      $ra

# ============================================================================
#  filter_red (id 5): mantem somente o canal vermelho.
# ============================================================================
filter_red:
    la      $t0, orig
    la      $t1, work
    li      $t2, 0
    li      $t3, NPIX
fr_loop:
    lw      $t4, 0($t0)
    li      $t5, 0x00FF0000
    and     $t4, $t4, $t5
    sw      $t4, 0($t1)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 1
    blt     $t2, $t3, fr_loop
    li      $v0, 0
    jr      $ra

# ============================================================================
#  filter_sepia (id 6): tom sepia pela matriz classica /1024.
# ============================================================================
filter_sepia:
    addiu   $sp, $sp, -20
    sw      $s0, 16($sp)
    sw      $s1, 12($sp)
    sw      $s2, 8($sp)
    la      $t0, orig
    la      $t1, work
    li      $t2, 0
    li      $t3, NPIX
fs_loop:
    lw      $t4, 0($t0)
    srl     $t5, $t4, 16
    andi    $t5, $t5, 0xFF           # R
    srl     $t6, $t4, 8
    andi    $t6, $t6, 0xFF           # G
    andi    $t7, $t4, 0xFF           # B

    li      $t8, 393                 # nr = (393R + 769G + 189B) >> 10
    mul     $t8, $t5, $t8
    li      $t9, 769
    mul     $t9, $t6, $t9
    add     $t8, $t8, $t9
    li      $t9, 189
    mul     $t9, $t7, $t9
    add     $t8, $t8, $t9
    srl     $s0, $t8, 10
    li      $t9, 255
    ble     $s0, $t9, fs_nr
    move    $s0, $t9
fs_nr:
    li      $t8, 349                 # ng = (349R + 686G + 168B) >> 10
    mul     $t8, $t5, $t8
    li      $t9, 686
    mul     $t9, $t6, $t9
    add     $t8, $t8, $t9
    li      $t9, 168
    mul     $t9, $t7, $t9
    add     $t8, $t8, $t9
    srl     $s1, $t8, 10
    li      $t9, 255
    ble     $s1, $t9, fs_ng
    move    $s1, $t9
fs_ng:
    li      $t8, 272                 # nb = (272R + 534G + 131B) >> 10
    mul     $t8, $t5, $t8
    li      $t9, 534
    mul     $t9, $t6, $t9
    add     $t8, $t8, $t9
    li      $t9, 131
    mul     $t9, $t7, $t9
    add     $t8, $t8, $t9
    srl     $s2, $t8, 10
    li      $t9, 255
    ble     $s2, $t9, fs_nb
    move    $s2, $t9
fs_nb:
    sll     $t8, $s0, 16
    sll     $t9, $s1, 8
    or      $t8, $t8, $t9
    or      $t8, $t8, $s2
    sw      $t8, 0($t1)

    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 1
    blt     $t2, $t3, fs_loop

    lw      $s2, 8($sp)
    lw      $s1, 12($sp)
    lw      $s0, 16($sp)
    addiu   $sp, $sp, 20
    li      $v0, 0
    jr      $ra

# ============================================================================
#  filter_blur (id 7): media aritmetica 3x3, com coordenadas "clamp"
#  nas bordas (a borda e replicada).
# ============================================================================
filter_blur:
    addiu   $sp, $sp, -20
    sw      $s0, 16($sp)
    sw      $s1, 12($sp)
    sw      $s2, 8($sp)
    sw      $s3, 4($sp)
    la      $s2, orig
    la      $s3, work
    li      $s0, 0                   # y
fb_y:
    li      $s1, 0                   # x
fb_x:
    li      $t0, 0                   # soma R
    li      $t1, 0                   # soma G
    li      $t2, 0                   # soma B
    li      $t3, -1                  # dy
fb_dy:
    add     $t4, $s0, $t3            # sy = y + dy
    bge     $t4, $zero, fb_sy1
    li      $t4, 0
fb_sy1:
    li      $t7, 63
    ble     $t4, $t7, fb_sy2
    move    $t4, $t7
fb_sy2:
    li      $t5, -1                  # dx
fb_dx:
    add     $t6, $s1, $t5            # sx = x + dx
    bge     $t6, $zero, fb_sx1
    li      $t6, 0
fb_sx1:
    li      $t7, 63
    ble     $t6, $t7, fb_sx2
    move    $t6, $t7
fb_sx2:
    sll     $t7, $t4, 6
    add     $t7, $t7, $t6
    sll     $t7, $t7, 2
    add     $t7, $s2, $t7
    lw      $t8, 0($t7)
    srl     $t9, $t8, 16
    andi    $t9, $t9, 0xFF
    add     $t0, $t0, $t9
    srl     $t9, $t8, 8
    andi    $t9, $t9, 0xFF
    add     $t1, $t1, $t9
    andi    $t9, $t8, 0xFF
    add     $t2, $t2, $t9

    addiu   $t5, $t5, 1
    li      $t7, 1
    ble     $t5, $t7, fb_dx
    addiu   $t3, $t3, 1
    li      $t7, 1
    ble     $t3, $t7, fb_dy

    li      $t7, 9
    div     $t0, $t7
    mflo    $t0
    div     $t1, $t7
    mflo    $t1
    div     $t2, $t7
    mflo    $t2
    sll     $t8, $t0, 16
    sll     $t9, $t1, 8
    or      $t8, $t8, $t9
    or      $t8, $t8, $t2
    sll     $t7, $s0, 6
    add     $t7, $t7, $s1
    sll     $t7, $t7, 2
    add     $t7, $s3, $t7
    sw      $t8, 0($t7)

    addiu   $s1, $s1, 1
    li      $t7, 64
    blt     $s1, $t7, fb_x
    addiu   $s0, $s0, 1
    li      $t7, 64
    blt     $s0, $t7, fb_y

    lw      $s3, 4($sp)
    lw      $s2, 8($sp)
    lw      $s1, 12($sp)
    lw      $s0, 16($sp)
    addiu   $sp, $sp, 20
    li      $v0, 0
    jr      $ra

# ============================================================================
#  filter_sobel (id 8): deteccao de bordas de Sobel sobre a luminancia.
#  1) calcula luma[];  2) gx, gy;  magnitude = min(255, |gx| + |gy|).
# ============================================================================
filter_sobel:
    addiu   $sp, $sp, -32
    sw      $ra, 28($sp)
    sw      $s0, 24($sp)
    sw      $s1, 20($sp)
    sw      $s3, 16($sp)
    sw      $s4, 12($sp)
    sw      $s5, 8($sp)

    # ---- 1) luminancia de toda a imagem em luma[] ----
    la      $t0, orig
    la      $t1, luma
    li      $t2, 0
    li      $t3, NPIX
fsb_luma:
    lw      $t4, 0($t0)
    srl     $t5, $t4, 16
    andi    $t5, $t5, 0xFF
    srl     $t6, $t4, 8
    andi    $t6, $t6, 0xFF
    andi    $t7, $t4, 0xFF
    li      $t8, 77
    mul     $t5, $t5, $t8
    li      $t8, 150
    mul     $t6, $t6, $t8
    li      $t8, 29
    mul     $t7, $t7, $t8
    add     $t5, $t5, $t6
    add     $t5, $t5, $t7
    srl     $t5, $t5, 8
    sw      $t5, 0($t1)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 1
    blt     $t2, $t3, fsb_luma

    # ---- 2) gradiente por pixel ----
    la      $s3, work
    li      $s0, 0
fsb_y:
    li      $s1, 0
fsb_x:
    # gx = (L(x+1,y-1) + 2L(x+1,y) + L(x+1,y+1))
    #    - (L(x-1,y-1) + 2L(x-1,y) + L(x-1,y+1))
    addiu   $a0, $s1, 1
    addiu   $a1, $s0, -1
    jal     sobel_L
    move    $s4, $v0
    addiu   $a0, $s1, 1
    move    $a1, $s0
    jal     sobel_L
    sll     $t0, $v0, 1
    add     $s4, $s4, $t0
    addiu   $a0, $s1, 1
    addiu   $a1, $s0, 1
    jal     sobel_L
    add     $s4, $s4, $v0
    addiu   $a0, $s1, -1
    addiu   $a1, $s0, -1
    jal     sobel_L
    sub     $s4, $s4, $v0
    addiu   $a0, $s1, -1
    move    $a1, $s0
    jal     sobel_L
    sll     $t0, $v0, 1
    sub     $s4, $s4, $t0
    addiu   $a0, $s1, -1
    addiu   $a1, $s0, 1
    jal     sobel_L
    sub     $s4, $s4, $v0

    # gy = (L(x-1,y+1) + 2L(x,y+1) + L(x+1,y+1))
    #    - (L(x-1,y-1) + 2L(x,y-1) + L(x+1,y-1))
    addiu   $a0, $s1, -1
    addiu   $a1, $s0, 1
    jal     sobel_L
    move    $s5, $v0
    move    $a0, $s1
    addiu   $a1, $s0, 1
    jal     sobel_L
    sll     $t0, $v0, 1
    add     $s5, $s5, $t0
    addiu   $a0, $s1, 1
    addiu   $a1, $s0, 1
    jal     sobel_L
    add     $s5, $s5, $v0
    addiu   $a0, $s1, -1
    addiu   $a1, $s0, -1
    jal     sobel_L
    sub     $s5, $s5, $v0
    move    $a0, $s1
    addiu   $a1, $s0, -1
    jal     sobel_L
    sll     $t0, $v0, 1
    sub     $s5, $s5, $t0
    addiu   $a0, $s1, 1
    addiu   $a1, $s0, -1
    jal     sobel_L
    sub     $s5, $s5, $v0

    # m = min(255, |gx| + |gy|)
    sra     $t0, $s4, 31
    xor     $s4, $s4, $t0
    subu    $s4, $s4, $t0            # |gx|
    sra     $t0, $s5, 31
    xor     $s5, $s5, $t0
    subu    $s5, $s5, $t0            # |gy|
    add     $s4, $s4, $s5
    li      $t0, 255
    ble     $s4, $t0, fsb_mag
    move    $s4, $t0
fsb_mag:
    sll     $t0, $s4, 16
    sll     $t1, $s4, 8
    or      $t0, $t0, $t1
    or      $t0, $t0, $s4
    sll     $t1, $s0, 6
    add     $t1, $t1, $s1
    sll     $t1, $t1, 2
    add     $t1, $s3, $t1
    sw      $t0, 0($t1)

    addiu   $s1, $s1, 1
    li      $t0, 64
    blt     $s1, $t0, fsb_x
    addiu   $s0, $s0, 1
    li      $t0, 64
    blt     $s0, $t0, fsb_y

    lw      $s5, 8($sp)
    lw      $s4, 12($sp)
    lw      $s3, 16($sp)
    lw      $s1, 20($sp)
    lw      $s0, 24($sp)
    lw      $ra, 28($sp)
    addiu   $sp, $sp, 32
    li      $v0, 0
    jr      $ra

# sobel_L: le luma[clamp(sy)*64 + clamp(sx)].
#   $a0 = sx (pode ser -1 ou 64), $a1 = sy; retorna $v0 = luminancia.
sobel_L:
    bge     $a0, $zero, sl_x1
    li      $a0, 0
sl_x1:
    li      $t0, 63
    ble     $a0, $t0, sl_x2
    move    $a0, $t0
sl_x2:
    bge     $a1, $zero, sl_y1
    li      $a1, 0
sl_y1:
    li      $t0, 63
    ble     $a1, $t0, sl_y2
    move    $a1, $t0
sl_y2:
    sll     $t0, $a1, 6
    add     $t0, $t0, $a0
    sll     $t0, $t0, 2
    la      $t1, luma
    add     $t0, $t1, $t0
    lw      $v0, 0($t0)
    jr      $ra

# ============================================================================
#  filter_lsbmap (id 9): mostra o bit 0 de cada pixel.
#  Branco = 1 (bit usado pela esteganografia), preto = 0.
# ============================================================================
filter_lsbmap:
    la      $t0, orig
    la      $t1, work
    li      $t2, 0
    li      $t3, NPIX
fl_loop:
    lw      $t4, 0($t0)
    andi    $t4, $t4, 1
    beqz    $t4, fl_black
    li      $t4, 0x00FFFFFF
    j       fl_store
fl_black:
    li      $t4, 0
fl_store:
    sw      $t4, 0($t1)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 1
    blt     $t2, $t3, fl_loop
    li      $v0, 0
    jr      $ra

# ============================================================================
#  blit: copia a imagem de work (4096 words) para a memoria de video.
# ============================================================================
blit:
    la      $t0, work
    li      $t1, DISPLAY_BASE
    li      $t2, 0
    li      $t3, NPIX
bl_loop:
    lw      $t4, 0($t0)
    sw      $t4, 0($t1)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 4
    addiu   $t2, $t2, 1
    blt     $t2, $t3, bl_loop
    jr      $ra

# ============================================================================
#  embed_message: grava a mensagem nos LSBs de orig.
#   $a0 = ponteiro para os bytes; $a1 = numero de bytes (1..MSG_MAX).
#   Retorna $v0 = 0 (ok) ou -1 (tamanho invalido).
# ============================================================================
embed_message:
    move    $t2, $a1                 # len
    li      $t9, 1
    blt     $t2, $t9, emb_bad
    li      $t9, MSG_MAX
    bgt     $t2, $t9, emb_bad

    la      $t0, orig
    move    $t1, $a0

    # ---- cabecalho: 32 bits do comprimento, big-endian ----
    li      $t3, 0                   # i = 0
emb_hdr:
    li      $t4, 31
    sub     $t4, $t4, $t3
    srlv    $t5, $t2, $t4
    andi    $t5, $t5, 1              # bit do comprimento
    sll     $t6, $t3, 2
    add     $t6, $t0, $t6
    lw      $t7, 0($t6)
    li      $t8, 0xFFFFFFFE
    and     $t7, $t7, $t8
    or      $t7, $t7, $t5
    sw      $t7, 0($t6)
    addiu   $t3, $t3, 1
    li      $t4, 32
    blt     $t3, $t4, emb_hdr

    # ---- mensagem: 8 bits por caractere ----
    li      $t3, 0                   # j = 0
emb_char:
    lbu     $t4, 0($t1)
    addiu   $t1, $t1, 1
    li      $t5, 7                   # k = 7 (MSB primeiro)
emb_bit:
    srlv    $t6, $t4, $t5
    andi    $t6, $t6, 1
    sll     $t7, $t3, 3
    addiu   $t7, $t7, 32
    li      $t8, 7
    sub     $t8, $t8, $t5
    add     $t7, $t7, $t8
    sll     $t7, $t7, 2
    add     $t7, $t0, $t7
    lw      $t8, 0($t7)
    li      $t9, 0xFFFFFFFE
    and     $t8, $t8, $t9
    or      $t8, $t8, $t6
    sw      $t8, 0($t7)
    addiu   $t5, $t5, -1
    bge     $t5, $zero, emb_bit
    addiu   $t3, $t3, 1
    blt     $t3, $t2, emb_char

    li      $v0, 0
    jr      $ra
emb_bad:
    li      $v0, -1
    jr      $ra

# ============================================================================
#  extract_message: le a mensagem dos LSBs de orig.
#   $a0 = destino; $a1 = capacidade do destino.
#   Retorna $v0 = comprimento (1..MSG_MAX) ou 0 se nao houver mensagem valida.
#   A mensagem lida e terminada com NUL.
# ============================================================================
extract_message:
    move    $t1, $a0                 # destino
    move    $t2, $a1                 # capacidade
    la      $t0, orig

    # ---- cabecalho: 32 bits do comprimento ----
    li      $t3, 0                   # len
    li      $t4, 0                   # i
ext_hdr:
    sll     $t5, $t4, 2
    add     $t5, $t0, $t5
    lw      $t5, 0($t5)
    andi    $t5, $t5, 1
    sll     $t3, $t3, 1
    or      $t3, $t3, $t5
    addiu   $t4, $t4, 1
    li      $t5, 32
    blt     $t4, $t5, ext_hdr

    # ---- valida o comprimento ----
    li      $t5, 1
    blt     $t3, $t5, ext_none
    li      $t5, MSG_MAX
    bgt     $t3, $t5, ext_none
    bge     $t3, $t2, ext_none       # precisa de espaco para o NUL

    # ---- le os caracteres ----
    li      $t4, 0                   # j
ext_char:
    li      $t5, 0                   # caractere
    li      $t6, 0                   # k
    sll     $t7, $t4, 3
    addiu   $t7, $t7, 32             # pixel base = 32 + 8j
ext_bit:
    add     $t8, $t7, $t6
    sll     $t8, $t8, 2
    add     $t8, $t0, $t8
    lw      $t8, 0($t8)
    andi    $t8, $t8, 1
    sll     $t5, $t5, 1
    or      $t5, $t5, $t8
    addiu   $t6, $t6, 1
    li      $t9, 8
    blt     $t6, $t9, ext_bit

    # valida caractere imprimivel ASCII
    li      $t9, 32
    blt     $t5, $t9, ext_none
    li      $t9, 126
    bgt     $t5, $t9, ext_none
    sb      $t5, 0($t1)
    addiu   $t1, $t1, 1
    addiu   $t4, $t4, 1
    blt     $t4, $t3, ext_char

    sb      $zero, 0($t1)
    move    $v0, $t3
    jr      $ra
ext_none:
    li      $v0, 0
    jr      $ra

# ============================================================================
#  clear_lsb: zera o bit 0 de todos os pixels de orig (remove a mensagem).
# ============================================================================
clear_lsb:
    la      $t0, orig
    li      $t1, 0
    li      $t2, NPIX
    li      $t3, 0xFFFFFFFE
cl_loop:
    lw      $t4, 0($t0)
    and     $t4, $t4, $t3
    sw      $t4, 0($t0)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, 1
    blt     $t1, $t2, cl_loop
    li      $v0, 0
    jr      $ra

# <<< ROTINAS-FIM
