# Filtros de Imagem e Esteganografia — MIPS/MARS

Programa de **processamento de imagens** e **esteganografia LSB** escrito em
**assembly MIPS puro**, feito para rodar no simulador **MARS 4.5** usando o
**Bitmap Display** (vídeo) e o **Keyboard and Display MMIO Simulator** (teclado).

A imagem é uma matriz **64×64 de palavras de 32 bits** no formato `0x00RRGGBB`
— 4096 pixels. Os **filtros** leem essa imagem base e produzem uma versão
transformada (escala de cinza, negativo, sépia, desfoque, bordas etc.), que é
copiada para a memória de vídeo. A **esteganografia** grava uma mensagem de
texto alterando apenas o **último bit (bit 0, o LSB do canal azul)** de cada
pixel: visualmente a imagem não muda, mas os bits ficam lá e podem ser
revelados pelo filtro "Mapa de LSB" ou recuperados pela tecla de extração.

O programa não usa bibliotecas, arquivos, rede nem instruções fora do conjunto
MIPS32 padrão do MARS. Basta montar e executar.

![Galeria com a imagem original 64x64 e o resultado de alguns filtros](preview.png)

*Galeria montada a partir dos resultados reais do programa no MARS: a mesma cena
64×64 vista com diferentes filtros (imagem original, escala de cinza, negativo,
sépia, desfoque 3×3, bordas de Sobel, só canal R e o mapa de LSB com a mensagem
`ESTEGANOGRAFIA EM MIPS!` embutida).*

| Arquivo | Descrição |
|---|---|
| [`filtros_esteganografia.asm`](filtros_esteganografia.asm) | Código-fonte completo e comentado |
| [`preview.png`](preview.png) | Galeria com a imagem base e alguns filtros gerados pelo programa |
| [`README.md`](README.md) | Este guia |

---

## 1. Requisitos

- **MARS 4.5** (ou superior) — com `java` instalado. Download:
  <https://courses.missouristate.edu/KenVollmar/MARS/>
- Em `Settings > Delayed Branching` deixe **desmarcado** (é o padrão do MARS).
- Em `Settings > Memory Configuration` use a configuração **padrão**
  (`.data` em `0x10010000`).

---

## 2. Como executar (passo a passo)

1. Abra o MARS (`Mars4_5.jar`).
2. Abra o programa: **File → Open…** e escolha `filtros_esteganografia.asm`
   (dentro da pasta `filtros-esteganografia/`).
3. Abra a tela gráfica: **Tools → Bitmap Display** e configure **exatamente**:

   | Campo | Valor |
   |---|---|
   | Unit Width in Pixels | `4` |
   | Unit Height in Pixels | `4` |
   | Display Width in Pixels | `256` |
   | Display Height in Pixels | `256` |
   | Base address for display | `0x10008000` |

   Depois clique em **Connect to MIPS**.

   > **Atenção:** os valores **padrão** do Bitmap Display no MARS 4.5 são
   > diferentes (base `0x10010000`, unidade `1×1`, display `512×256`). É
   > **obrigatório** ajustar a tabela acima **antes** de clicar em
   > *Connect to MIPS*; caso contrário o programa escreve na memória de vídeo
   > errada e a imagem não aparece (ou aparece espremida/deslocada).
   >
   > Com unidade 4×4 e display 256×256 a janela tem 64×64 blocos: **cada pixel
   > da imagem ocupa um bloco de 4×4 pixels na tela**.

4. Abra o teclado: **Tools → Keyboard and Display MMIO Simulator** e clique em
   **Connect to MIPS**.
5. Monte: **F3** (Run → Assemble). Confira a mensagem de sucesso no console.
6. Execute: **F5** (Run → Go).
7. Na janela **Keyboard and Display MMIO Simulator**, clique dentro da caixa de
   texto do teclado (parte de baixo) e digite as teclas de comando: `0`–`9`,
   `H`, `X`, `C`, `M`, `Q`.

> O **menu, os nomes dos filtros e as mensagens de status** aparecem na aba
> **Run I/O** do MARS. A imagem aparece na janela **Bitmap Display**.

> **As teclas de filtro (`0`–`9`) não usam Enter**: cada dígito já aplica o
> filtro e atualiza a tela. O Enter só é usado para confirmar a mensagem no
> modo de digitação (tecla `H`).

> As mensagens que o programa imprime no console usam **ASCII sem acentos**
> (por exemplo, aparecem como `sepia`, `extracao` e `mensagem`), por limitação
> de codificação do console do MARS. O texto deste README usa acentuação
> normal.

---

## 3. Controles

| Tecla | Ação |
|---|---|
| `0` | Original — copia a imagem base, sem alteração |
| `1` | Escala de cinza |
| `2` | Negativo |
| `3` | Brilho +40 |
| `4` | Brilho −40 |
| `5` | Só canal R (vermelho) |
| `6` | Sépia |
| `7` | Desfoque 3×3 |
| `8` | Bordas (Sobel) |
| `9` | Mapa de LSB (mostra os bits escondidos) |
| `H` | Esconder uma mensagem (entra no modo de digitação) |
| `X` | Extrair e mostrar a mensagem no console |
| `C` | Limpar todos os LSBs (remove a mensagem) |
| `M` | Reimprimir o menu |
| `Q` | Sair do programa (encerra a simulação) |

Detalhes:

- **`H` (esconder):** o console entra no modo de digitação. Cada caractere
  imprimível (ASCII 32–126) é **ecoado** no console; **Backspace** apaga o
  último caractere; **Enter** confirma; **Esc** cancela (Enter com a mensagem
  vazia também cancela). O limite é de **508 caracteres**; o que passar disso
  é ignorado. Ao confirmar, a mensagem é gravada nos LSBs da imagem base, o
  filtro atual é reaplicado e a tela é atualizada.
- **Enquanto estiver digitando a mensagem (modo `H`), as teclas `0`–`9`, `H`,
  `X`, `C`, `M` e `Q` fazem parte do texto**, não são comandos. Termine com
  **Enter** ou cancele com **Esc** antes de trocar de filtro ou sair.
- **`X` (extrair):** lê os LSBs, valida o cabeçalho e imprime a mensagem no
  console. Se não houver mensagem válida, o programa avisa.
- **`C` (limpar):** zera o bit 0 de todos os pixels. É a única operação que
  apaga a mensagem (junto com uma nova mensagem, que a sobrescreve).
- **`Q` (sair):** encerra o programa com a syscall de saída (`10`). Para rodar
  de novo, use **Run → Reset** antes de um novo **F5**.
- Os comandos de letra são aceitos em **maiúscula ou minúscula**: `H/h`,
  `X/x`, `C/c`, `M/m`, `Q/q`.

---

## 4. Formato da imagem

### 4.1 A palavra de cor `0x00RRGGBB`

Cada pixel é **uma palavra de 32 bits** (4 bytes) na memória, com os canais
empacotados da seguinte forma:

```
 bits 31..24   bits 23..16   bits 15..8   bits 7..0
  0000 0000     RRRR RRRR     GGGG GGGG    BBBB BBBB
  (reservado)      R             G            B
```

Os canais são extraídos e remontados com deslocamentos e máscaras:

```
R = (p >> 16) & 0xFF
G = (p >> 8)  & 0xFF
B =  p        & 0xFF

p = (R << 16) | (G << 8) | B
```

Exemplos:

| Palavra | Cor |
|---|---|
| `0x00000000` | preto |
| `0x00FFFFFF` | branco |
| `0x00FF0000` | vermelho puro |
| `0x0000FF00` | verde puro |
| `0x000000FF` | azul puro |
| `0x00808080` | cinza médio |

O byte mais significativo é sempre `0x00` (o Bitmap Display do MARS ignora o
canal alfa).

### 4.2 Endereço na memória de vídeo

O programa mantém a imagem nos vetores `orig` e `work` (no segmento de dados) e
copia o resultado para a memória de vídeo. O pixel `(x, y)`, com
`0 ≤ x, y ≤ 63`, fica no endereço:

```
endereço = 0x10008000 + (y * 64 + x) * 4
```

O índice linear do pixel (usado nos laços) é `i = y * 64 + x`, de `0` a `4095`.
A região de vídeo ocupa 4096 palavras = **16 KB**, de `0x10008000` a
`0x1000BFFF` — termina exatamente antes do início do segmento de dados
(`0x10010000`), portanto não há conflito.

A configuração do Bitmap Display (passo 3) define a correspondência entre a
palavra e a tela: unidade 4×4 e display 256×256 resultam em 64×64 blocos, ou
seja, **1 palavra = 1 pixel da imagem = um bloco de 4×4 pixels na tela**.

---

## 5. Filtros

Todos os filtros seguem o mesmo contrato:

- leem a **imagem base `orig`**;
- escrevem o resultado em **`work`**;
- **nunca alteram `orig`** (exceto as rotinas de esteganografia, que gravam
  apenas o bit 0);
- a rotina `blit` copia `work` para a memória de vídeo.

Por isso os filtros **não se acumulam**: aplicar o negativo e depois o original
mostra a imagem original de novo; aplicar o negativo duas vezes não "soma"
efeitos. A imagem base é sempre a mesma referência.

Seja `p = 0x00RRGGBB` a palavra de um pixel e
`R = (p >> 16) & 0xFF`, `G = (p >> 8) & 0xFF`, `B = p & 0xFF`.

| Tecla | Filtro | Rotina | Fórmula (por pixel) |
|---|---|---|---|
| `0` | Original | `filter_copy` | `work = orig` |
| `1` | Escala de cinza | `filter_gray` | `L = (77R + 150G + 29B) >> 8`<br>`work = (L, L, L)` |
| `2` | Negativo | `filter_negative` | `work = 0x00FFFFFF XOR orig` |
| `3` | Brilho +40 | `filter_bright_up` | `c' = min(255, c + 40)` em cada canal |
| `4` | Brilho −40 | `filter_bright_down` | `c' = max(0, c − 40)` em cada canal |
| `5` | Só canal R | `filter_red` | `work = orig & 0x00FF0000` |
| `6` | Sépia | `filter_sepia` | `nr = min(255, (393R + 769G + 189B) >> 10)`<br>`ng = min(255, (349R + 686G + 168B) >> 10)`<br>`nb = min(255, (272R + 534G + 131B) >> 10)` |
| `7` | Desfoque 3×3 | `filter_blur` | média inteira dos 9 vizinhos, com bordas por *clamp* |
| `8` | Bordas (Sobel) | `filter_sobel` | `m = min(255, abs(gx) + abs(gy))`; `work = (m, m, m)` |
| `9` | Mapa de LSB | `filter_lsbmap` | `work = 0x00FFFFFF` se `bit0(orig) = 1`, senão `0x00000000` |

### 5.1 Comentários sobre cada filtro

- **Escala de cinza (`1`).** Usa os pesos `77`, `150` e `29`, que somam 256;
  o deslocamento `>> 8` é uma divisão por 256 — uma aproximação inteira e
  rápida da luminância `0,299R + 0,587G + 0,114B`. Os três canais recebem o
  mesmo valor `L`.
- **Negativo (`2`).** O XOR com `0x00FFFFFF` complementa os 24 bits de cor e
  mantém o byte alto em zero.
- **Brilho (`3` e `4`).** Soma ou subtrai 40 de **cada canal, separadamente**,
  saturando em 0 e 255. A saturação evita que o canal "dê a volta" (por
  exemplo, `250 + 40` virar `34`).
- **Só canal R (`5`).** A máscara `0x00FF0000` zera G e B e deixa apenas o
  vermelho. É útil para visualizar como os canais estão empacotados.
- **Sépia (`6`).** Combina os três canais originais em novas componentes com
  uma matriz de coeficientes; o deslocamento `>> 10` corresponde a dividir por
  1024. Os coeficientes reduzem mais o azul do que o vermelho, o que dá o tom
  amarelado/marrom característico. Os valores são saturados em 255.
- **Desfoque 3×3 (`7`).** Para cada pixel, soma os canais dos 9 pixels da
  vizinhança (3×3) e divide por 9 (divisão inteira). Nas bordas, as
  coordenadas vizinhas são "presas" (*clamp*) entre 0 e 63, repetindo o pixel
  da borda — assim não é preciso tratar casos especiais dentro do laço. A soma
  máxima é `9 × 255 = 2295`, que cabe folgadamente em 32 bits.
- **Bordas / Sobel (`8`).** É um filtro em **duas passagens**. Primeiro calcula
  a luminância `L` de todos os 4096 pixels em um vetor auxiliar (`luma`).
  Depois, para cada pixel, calcula os gradientes horizontal e vertical:

  ```
  gx = (L[x+1,y-1] + 2L[x+1,y] + L[x+1,y+1]) - (L[x-1,y-1] + 2L[x-1,y] + L[x-1,y+1])
  gy = (L[x-1,y+1] + 2L[x,y+1] + L[x+1,y+1]) - (L[x-1,y-1] + 2L[x,y-1] + L[x+1,y-1])
  ```

  A magnitude aproximada é `m = min(255, abs(gx) + abs(gy))` — sem raiz
  quadrada, para ficar barato em assembly. O resultado é cinza: pixels de
  borda claros, áreas uniformes escuras. As bordas da imagem também usam
  *clamp*.
- **Mapa de LSB (`9`).** É o filtro que revela a esteganografia: em vez de
  processar a cor, olha **somente o bit 0** de cada palavra e pinta o pixel de
  branco (`1`) ou preto (`0`). Como o bit 0 é o LSB do azul, esse filtro mostra
  exatamente os bits escondidos, sem qualquer outro efeito.

---

## 6. Esteganografia LSB

### 6.1 A ideia

O **bit menos significativo** (LSB) de um canal de cor quase não afeta a cor
percebida: trocar o azul de `130` para `131` é imperceptível. A esteganografia
LSB aproveita isso para guardar **1 bit por pixel** no bit 0 de cada palavra —
que é o último bit do canal azul. Com 4096 pixels, há 4096 bits disponíveis
(512 bytes); 32 bits são reservados para um cabeçalho, sobrando **508 bytes**
de mensagem.

O bit é gravado sem destruir o resto da cor:

```
orig[p] = (orig[p] & 0xFFFFFFFE) | bit
```

### 6.2 Formato da mensagem

| Pixels | Conteúdo |
|---|---|
| `0`–`31` | cabeçalho de 32 bits: comprimento da mensagem em **bytes**, em big-endian |
| `32`–`32 + 8*len − 1` | bytes da mensagem, 8 bits por caractere |
| `32 + 8*len`–`4095` | não usados; permanecem com o LSB que já tinham (0 na imagem recém-gerada) |

Regras de ordem dos bits:

- **Cabeçalho:** `bit i = (len >> (31 − i)) & 1`, gravado no pixel `i`
  (para `i = 0..31`). O bit mais significativo do comprimento fica no primeiro
  pixel.
- **Mensagem:** para o caractere `j` (começando em 0) e o bit `k = 0..7`:
  `bit = (msg[j] >> (7 − k)) & 1`, gravado no pixel `32 + 8*j + k`. O bit mais
  significativo de cada byte vem primeiro.
- **Extração:** o processo inverso — lê 32 bits para obter `len`, depois lê
  `8*len` bits e remonta os bytes.

Exemplo com a mensagem `"OI"` (`len = 2`):

```
cabeçalho (pixels 0..31):  0000 0000 0000 0000 0000 0000 0000 0010
'O' = 0x4F = 0100 1111    (pixels 32..39)
'I' = 0x49 = 0100 1001    (pixels 40..47)
```

### 6.3 Capacidade e validação

- `32 + 8*len ≤ 4096`, portanto **`len ≤ 508` bytes** (equivale a 508
  caracteres ASCII; constante `MSG_MAX`).
- `embed_message` aceita `len` de **1 a 508** e retorna `-1` para valores
  inválidos.
- `extract_message` só considera a mensagem **válida** se:
  - `len` estiver entre 1 e 508 e couber no destino;
  - **todos** os bytes estiverem na faixa imprimível **ASCII 32–126**.
- O destino da extração é terminado com NUL (`0`), o que permite imprimir a
  mensagem como string.
- Na geração da imagem, o programa faz `b = b & 0xFE` em todos os pixels, para
  que o mapa de LSB comece **limpo** (todos os bits 0 iguais a zero).

### 6.4 Rotinas de esteganografia

| Rotina | Entrada | Saída |
|---|---|---|
| `embed_message` | `$a0` = ponteiro para os bytes, `$a1` = `len` (1–508) | `$v0 = 0` (ok) ou `-1` (inválido) |
| `extract_message` | `$a0` = destino, `$a1` = capacidade do destino | `$v0` = tamanho extraído, ou `0` se não houver mensagem válida |
| `clear_lsb` | — | `$v0 = 0`; zera o bit 0 das 4096 palavras de `orig` |

### 6.5 Testando o ciclo completo

1. Pressione **`H`** e digite uma mensagem simples, por exemplo
   `ESTEGANOGRAFIA EM MIPS` (somente ASCII imprimível), e confirme com
   **Enter**. O console mostra a confirmação.
2. Pressione **`X`** — a mensagem digitada é extraída e impressa no console.
3. Pressione **`9`** — o **Mapa de LSB** aparece: o fundo fica preto e cada bit
   `1` vira um ponto branco. Os 32 primeiros bits (cabeçalho) ficam nos 32
   primeiros pixels (metade da primeira fileira) e, em seguida, vêm os bits da
   mensagem. O comprimento lido aparece como alguns poucos pontos brancos no
   cabeçalho; o texto em si vira um padrão de pontos.
4. Pressione **`0`** — a imagem original volta a aparecer, agora com os LSBs
   modificados, mas **visualmente idêntica** (a diferença de ±1 no azul é
   imperceptível).
5. Pressione **`C`** — os LSBs são zerados e a mensagem é removida. O filtro
   `9` passa a mostrar a tela toda preta e `X` informa que não há mensagem
   válida.
6. Para esconder outra mensagem, basta repetir o passo 1 (`H`); a nova
   mensagem sobrescreve os bits do cabeçalho e dos caracteres, e `len` delimita
   o que é lido.

### 6.6 Por que o filtro 9 revela e os outros não apagam

- O filtro `9` é o único que **lê o bit 0** e o transforma em cor visível.
- Os demais filtros são funções da imagem base: leem `orig`, calculam uma nova
  cor e gravam em `work`. **Nenhum deles escreve em `orig`.** Portanto, trocar
  de filtro não destrói a mensagem — ela continua na imagem base.
- A mensagem só desaparece por duas vias: **`C`** (limpa explicitamente os
  LSBs de `orig`) ou **uma nova mensagem** (sobrescreve os bits usados).
- A imagem exibida na tela é sempre derivada de `orig`; por isso, depois de
  qualquer filtro, basta voltar ao `9` (ou usar `X`) para encontrar a mensagem
  intacta.

### 6.7 Limitações e cuidados

- O modo de digitação **ignora** teclas fora do ASCII imprimível (32–126), e
  a extração **rejeita** qualquer byte fora dessa faixa; por isso acentos e
  símbolos não fazem parte das mensagens.
- É esteganografia **didática**, não criptografia: qualquer pessoa que conheça
  o formato pode extrair a mensagem (é literalmente o que a tecla `X` faz).
- O limite de **508 bytes** vem do tamanho da imagem; mensagens maiores são
  recusadas.
- O cabeçalho sempre tem 32 bits; se o conteúdo de `orig` não foi gerado pelo
  programa (por exemplo, após edições manuais), a validação de comprimento e
  de ASCII evita extrair "lixo" como mensagem.

---

## 7. Como o código funciona

### 7.1 Mapa de memória

| Região | Endereço | Tamanho | Uso |
|---|---|---|---|
| Memória de vídeo (Bitmap Display) | `0x10008000` | 16 KB (4096 words) | imagem exibida; destino do `blit` |
| Segmento de dados (`.data`) | `0x10010000` | — | início dos vetores do programa |
| `orig` | `0x10010000` | 16384 B (16 KB) | imagem base `0x00RRGGBB` |
| `work` | `0x10014000` | 16384 B (16 KB) | resultado do filtro atual |
| `luma` | `0x10018000` | 16384 B (16 KB) | luminância auxiliar do filtro de Sobel |
| `msg` | `0x1001C000` | 512 B | buffer da mensagem digitada/extraída |
| `msglen` | `0x1001C200` | 4 B | variável auxiliar de comprimento (o comprimento efetivo fica no cabeçalho gravado em `orig`) |
| Controle do teclado MMIO | `0xffff0000` | 4 B | bit 0 = 1 quando há tecla |
| Dados do teclado MMIO | `0xffff0004` | 4 B | código ASCII da tecla |

O segmento de dados começa em `0x10010000` (configuração padrão do MARS). Os
três vetores de imagem são contíguos, o que permite calcular `work` e `luma`
por deslocamento a partir de `orig`, se necessário. A memória de vídeo fica
16 KB antes de `orig`, sem sobreposição.

### 7.2 Geração da imagem base (`gen_image`)

A imagem é **gerada proceduralmente**, de forma determinística (sem
aleatoriedade), uma única vez no início do programa. Para cada pixel `(x, y)`:

```
r = 40 + 4*y ; g = 70 + 3*y ; b = 160 - 2*y     # céu em degradê
b = b & 0xFE                                     # LSB do azul sempre 0
orig[y*64 + x] = (r << 16) | (g << 8) | b
```

Sobre esse fundo, a rotina desenha uma cena:

- **sol** com disco e halo (círculos definidos por `dx² + dy²`), na parte de
  cima;
- **duas montanhas** em silhueta, com neve nos topos, perto do horizonte
  (`y < 44`);
- **água** (`y ≥ 44`) com degradê, ondas aproximadas por um padrão de módulo e
  reflexo do sol;
- um **barco** com casco, mastro e vela triangular.

Tudo é feito com aritmética inteira e `min`/`max` saturados. O passo
`b = b & 0xFE` garante que o mapa de LSB comece limpo antes de qualquer
mensagem.

### 7.3 Rotinas principais

| Rotina | Responsabilidade |
|---|---|
| `main` | Inicializa, gera a imagem, aplica o filtro inicial, imprime o menu e executa o laço principal |
| `gen_image` | Gera a cena 64×64 em `orig` e zera o LSB do azul |
| `apply_filter` | Recebe o id do filtro em `$a0` (0–9), despacha para a rotina certa e retorna `0` ou `-1` |
| `filter_copy`, `filter_gray`, `filter_negative`, `filter_bright_up`, `filter_bright_down`, `filter_red`, `filter_sepia`, `filter_lsbmap` | Filtros por pixel: leem `orig`, escrevem `work` |
| `filter_blur` | Desfoque 3×3 com vizinhança por *clamp* |
| `filter_sobel` | Preenche `luma`, calcula `gx`/`gy` e escreve as bordas |
| `blit` | Copia as 4096 palavras de `work` para a memória de vídeo |
| `embed_message` | Grava cabeçalho e bits da mensagem nos LSBs de `orig` |
| `extract_message` | Reconstrói e valida a mensagem a partir dos LSBs de `orig` |
| `clear_lsb` | Zera o bit 0 das 4096 palavras de `orig` |
| `read_key` | Leitura **não bloqueante** do teclado MMIO: ASCII ou `-1` |
| `handle_key` | Interpreta a tecla e despacha para filtro, menu, `H`, `X`, `C` ou `Q` |
| `hide_flow` | Modo de digitação da mensagem (eco, Backspace, Enter, Esc, limite) |
| `extract_flow` | Fluxo da tecla `X`: extrai e imprime a mensagem |
| `clear_flow` | Fluxo da tecla `C`: limpa os LSBs e atualiza a tela |
| `select_filter` | Troca o filtro atual, aplica sobre `orig` e redesenha |
| `refresh` | Reaplica o filtro atual e refaz o blit (usado depois de `H`/`C`) |
| `print_str`, `print_int`, `print_char` | Utilitários de impressão no console (string, inteiro, caractere) |

O estado da interface fica em variáveis simples no `.data` (fora do núcleo da
esteganografia): o **filtro atual** (`cur`), as **strings do menu** e os
**nomes dos filtros**.

### 7.4 Laço principal (não bloqueante)

O programa **não fica parado esperando tecla**. A cada iteração ele consulta o
teclado MMIO e, se não houver nada, dorme 20 ms com a **syscall 32** (sleep)
para não consumir CPU à toa. Esquema (simplificado):

```
laco:
    jal  read_key           # retorna ASCII ou -1 (não bloqueia)
    bltz $v0, ocioso        # nenhuma tecla?
    move $a0, $v0
    jal  handle_key         # processa; retorna 1 para sair
    bnez $v0, fim
    j    laco

ocioso:
    li   $a0, 20            # 20 milissegundos
    li   $v0, 32
    syscall
    j    laco

fim:
    li   $v0, 10
    syscall
```

Assim o programa responde a qualquer momento, e o laço continua sendo simples
de entender. Durante a digitação da mensagem (`hide_flow`), o mesmo esquema é
usado com espera de 15 ms. As teclas `0`–`9` chamam `select_filter`; `M`
reimprime o menu; `H`/`X`/`C` entram nos fluxos correspondentes; `Q` encerra
com a syscall `10`.

### 7.5 Convenções e detalhes de MIPS

- **Delayed Branching desligado** (padrão do MARS): não há `nop` em *delay
  slots*; o código assume o comportamento padrão do simulador.
- Convenção de chamada MIPS: quem chama salva `$ra` quando necessário;
  `$s0`–`$s7` são preservados pelas rotinas; `$t*`, `$a*` e `$v*` são voláteis
  entre chamadas.
- O **núcleo** (geração da imagem, filtros, esteganografia, `blit`) **não usa
  syscalls** — só a interface (console, sleep e saída) usa. Isso permite testar
  o núcleo pela linha de comando do MARS.
- A leitura do teclado é feita pelos registradores MMIO em `0xffff0000` e
  `0xffff0004`, não pela syscall de leitura de teclado.

### 7.6 Custo

- Filtros simples (`0`–`6` e `9`) fazem **uma passagem** pelos 4096 pixels, com
  algumas dezenas de instruções por pixel.
- O **desfoque** lê 9 pixels da vizinhança para cada pixel (cerca de 9 leituras
  por pixel), sendo mais caro que os filtros de cor.
- O **Sobel** é o filtro mais pesado: uma passagem para calcular a luminância
  de todos os pixels e outra, com 8 leituras da vizinhança por pixel, para os
  gradientes.
- Em 64×64 (4096 pixels) tudo é rápido no MARS; o Sobel é o que leva mais
  tempo para redesenhar, mas continua sendo uma atualização praticamente
  imediata na simulação. O gargalo real é a própria simulação, não o tamanho da
  imagem.

---

## 8. Personalização rápida

As constantes ficam no início do `filtros_esteganografia.asm` (bloco de
constantes):

| Constante | Valor padrão | Uso |
|---|---|---|
| `DISPLAY_BASE` | `0x10008000` | base da memória de vídeo (deve casar com o Bitmap Display) |
| `IMG_W` / `IMG_H` | `64` / `64` | largura e altura da imagem |
| `NPIX` | `4096` | número de pixels (`IMG_W * IMG_H`) |
| `MSG_MAX` | `508` | capacidade da mensagem em bytes |
| `MSG_BUF` | `512` | tamanho do buffer da mensagem |
| `KEY_CTRL` / `KEY_DATA` | `0xffff0000` / `0xffff0004` | registradores do teclado MMIO |

Outros ajustes possíveis:

- **Pesos da luminância:** `77`, `150`, `29` (e o `>> 8`). Mantenha a soma em
  256 (ou ajuste o deslocamento) para não estourar a faixa dos canais. Esses
  pesos também são usados no Sobel.
- **Fator de brilho:** o valor `40` somado/subtraído nos filtros `3` e `4`.
  Qualquer valor entre 0 e 255 funciona.
- **Coeficientes da sépia:** as três linhas da matriz no `filter_sepia`. O
  deslocamento `>> 10` pressupõe coeficientes na casa das centenas.
- **Cores e cena da imagem:** todos os parâmetros de `gen_image` (degradê do
  céu, centro/raios do sol, alturas das montanhas, ondas, posição do barco)
  são números inteiros comuns; ajuste à vontade. **Mantenha o `b = b & 0xFE`**
  no final, para o mapa de LSB começar limpo.
- **Novo filtro:** crie uma rotina que leia `orig` e escreva `work`, adicione-a
  ao despacho de `apply_filter`, acrescente o nome no menu e a tecla em
  `handle_key` (o id deve continuar na faixa 0–9, ou o despacho precisa ser
  estendido).
- **Tamanho da imagem:** é a mudança mais trabalhosa. Seria necessário:
  1. ajustar `IMG_W`, `IMG_H` e `NPIX` (e os `.space` de `orig`/`work`/`luma`);
  2. ajustar `MSG_MAX = (NPIX − 32) / 8` e o tamanho de `MSG_BUF`;
  3. recalcular os laços (que usam 64 e 4096 de forma explícita em alguns
     pontos) e a fórmula de endereço `(y * IMG_W + x) * 4`;
  4. reconfigurar o Bitmap Display: para uma imagem 128×128, por exemplo, use
     unidade 2×2 com display 256×256 (ou unidade 4×4 com display 512×512).

---

## 9. Solução de problemas

| Sintoma | Causa provável / solução |
|---|---|
| Nada aparece na tela (tela preta) | O *Bitmap Display* não está conectado, ou a base não é `0x10008000`, ou a configuração está diferente da tabela do passo 3. Confira e clique em **Connect to MIPS**. |
| A imagem aparece espremida ou só em parte da janela | `Unit Width/Height` ou `Display Width/Height` errados. Use **4 / 4 / 256 / 256**. |
| Erro de "endereço fora do intervalo" | *Memory Configuration* diferente da padrão, ou `DISPLAY_BASE` alterado. Restaure a configuração padrão (`.data` em `0x10010000`). |
| O teclado não responde | O *Keyboard and Display MMIO Simulator* não está conectado ou a caixa de texto não está com o foco. Clique em **Connect to MIPS** e depois **clique dentro da caixa de texto** antes de digitar. |
| Os dígitos `0`–`9` não trocam o filtro | Pode estar no modo de digitação (após `H`): nesse modo as teclas fazem parte do texto. Termine com **Enter** ou cancele com **Esc**. |
| As setas do teclado não fazem nada | Normal: o MMIO do MARS só entrega caracteres ASCII. Use as teclas indicadas na tabela de controles. |
| "Nenhuma mensagem válida encontrada" ao pressionar `X` | A mensagem nunca foi embutida, ou foi removida com `C`, ou tem caracteres fora de ASCII 32–126 (a validação rejeita). Embute de novo com `H`. |
| O mapa de LSB (`9`) está todo preto | Não há mensagem embutida (todos os LSB estão em 0) ou a mensagem foi limpa com `C`. Isso é o estado inicial normal. |
| A execução parece lenta ao aplicar um filtro | O Sobel e o desfoque são os filtros mais pesados; em 64×64 a atualização é rápida. Se necessário, use **Run → Maximum speed** e feche janelas extras do MARS. |
| Comportamento estranho nos desvios (`beq`/`bne`) | `Settings > Delayed Branching` deve estar **desmarcado** (padrão do MARS). |
| Rodar de novo sem reiniciar a simulação | Use **Run → Reset** (ou recarregue o arquivo) antes de um novo **F5**. Se a janela do Bitmap Display foi fechada, reconecte-a. |
| `Q` não encerra / o programa fica parado | Verifique se o foco está na caixa de texto do teclado MMIO e pressione `Q` de novo; em último caso feche e reabra o MARS. |

---

## 10. Observações didáticas

- **Uma palavra, três canais.** O formato `0x00RRGGBB` mostra na prática o uso
  de deslocamentos (`sll`/`srl`), máscaras (`and`) e OR (`or`) para empacotar
  e desempacotar dados. Extrair `R`, `G` e `B` e remontar a palavra é o
  exercício central de várias rotinas.
- **Laços aninhados.** A imagem é varrida com um laço externo para `y` e um
  interno para `x` (ou um único laço sobre o índice `i = y*64 + x`). O padrão se
  repete em todos os filtros e nas rotinas de esteganografia.
- **Separação entre base e resultado.** Os vetores `orig` e `work` funcionam
  como um *double buffer* de processamento: a base nunca é alterada pelos
  filtros, o que torna o pipeline previsível e os filtros independentes entre
  si. A esteganografia é a única etapa que modifica `orig`, e só no bit 0.
- **Operações locais e pontuais.** Filtros de cor são operações *pointwise*
  (cada pixel depende só dele mesmo); desfoque e Sobel são operações de
  vizinhança (cada pixel depende da vizinhança 3×3, com bordas por *clamp*).
  Comparar os dois grupos é uma boa introdução a processamento de imagens.
- **MMIO do MARS.** O teclado é um periférico mapeado em memória: `lw` em
  `0xffff0000` e `0xffff0004`. O laço de leitura é *polling*
  não bloqueante, e a syscall 32 (sleep) evita um laço quente. Isso ilustra
  E/S mapeada em memória e espera eficiente sem interrupções.
- **Convenção de registradores.** As rotinas seguem a ABI MIPS (argumentos em
  `$a0`–`$a3`, retorno em `$v0`, `$s*` preservados). O `$ra` é salvo na pilha
  quando a rotina faz chamadas.
- **Delayed branching.** O código assume a opção desmarcada, o padrão do MARS.
  Se você ativá-la, será preciso inserir `nop` (ou uma instrução útil) nos
  *delay slots* dos desvios.
- **Sem aleatoriedade.** A imagem é determinística: as mesmas cores e o mesmo
  barco em toda execução, o que facilita comparar resultados, depurar e testar
  os filtros.
- **Limite da esteganografia.** A capacidade (508 bytes) é uma consequência
  direta do tamanho da imagem (4096 bits − 32 de cabeçalho). Esconder mais
  exigiria mais pixels ou mais bits por pixel — e mais bits por pixel tornariam
  a alteração visível. É um bom exemplo do compromisso entre capacidade e
  invisibilidade.
- **Verificação.** O programa foi montado e executado no MARS 4.5; o núcleo
  (geração da imagem, filtros e esteganografia) também foi verificado pelo modo
  de linha de comando do simulador, comparando a memória resultante com uma
  implementação de referência independente.
