# Snake MIPS — Jogo da Cobrinha para o simulador MARS

Jogo da cobrinha (_snake_) escrito em **MIPS assembly puro**, feito para rodar no
simulador **MARS 4.5** usando o **Bitmap Display** (vídeo) e o
**Keyboard and Display MMIO Simulator** (teclado).

O jogo não usa nenhuma biblioteca, pseudo-arquivo ou instrução fora do conjunto
MIPS32 padrão do MARS. Basta montar e executar.

![Tabuleiro 32x32 com a cobra verde, cabeça mais clara e fruta vermelha](snake-preview.svg)

| Arquivo | Descrição |
|---|---|
| [`snake.asm`](snake.asm) | Código-fonte completo e comentado do jogo |
| [`README.md`](README.md) | Este guia |

---

## 1. Requisitos

- **MARS 4.5** (ou superior) — `java` instalado. Download:
  <https://courses.missouristate.edu/KenVollmar/MARS/>
- Em `Settings > Delayed Branching` deixe **desmarcado** (é o padrão do MARS).
- Em `Settings > Memory Configuration` use a configuração **padrão**
  (`.data` em `0x10010000`).

---

## 2. Como executar (passo a passo)

1. Abra o MARS (`Mars4_5.jar`).
2. Abra o jogo: **File → Open…** e escolha `snake.asm`.
3. Abra a tela gráfica: **Tools → Bitmap Display** e configure **exatamente**:

   | Campo | Valor |
   |---|---|
   | Unit Width in Pixels | `8` |
   | Unit Height in Pixels | `8` |
   | Display Width in Pixels | `256` |
   | Display Height in Pixels | `256` |
   | Base address for display | `0x10008000` |

   Depois clique em **Connect to MIPS**.

   > ⚠️ Os valores **padrão** do Bitmap Display no MARS 4.5 são diferentes
   > (base `0x10010000`, unidade `1×1`, display `512×256`). É **obrigatório**
   > ajustar a tabela acima **antes** de clicar em *Connect to MIPS*; caso
   > contrário o jogo escreve na memória de vídeo errada e a tela não aparece.

   > Isso cria uma grade de 32×32 células: cada célula do tabuleiro ocupa
   > 8×8 pixels na tela.

4. Abra o teclado: **Tools → Keyboard and Display MMIO Simulator** e clique em
   **Connect to MIPS**.
5. Monte: **F3** (Run → Assemble). Confira a mensagem de sucesso no console.
6. Execute: **F5** (Run → Go).
7. Na janela **Keyboard and Display MMIO Simulator**, clique dentro da caixa de
   texto do teclado (parte de baixo) e digite **W A S D** para mover a cobra.

> As mensagens de texto (pontuação, game over, pausa) aparecem na aba
> **Run I/O** do MARS. O jogo em si aparece na janela **Bitmap Display**.

> ⚠️ As **setas do teclado não funcionam** no Keyboard MMIO do MARS: o
> simulador só entrega caracteres ASCII. Por isso os controles são **WASD**
> (e, como alternativa, as teclas numéricas `8/4/2/6`).

---

## 3. Controles

| Tecla | Ação |
|---|---|
| `W` ou `8` | mover para cima |
| `A` ou `4` | mover para a esquerda |
| `S` ou `2` | mover para baixo |
| `D` ou `6` | mover para a direita |
| `P` ou `Espaço` | pausar / continuar |
| `Q` | sair do jogo (encerra o programa) |
| `R` | reiniciar (na tela de game over) |

O jogo **ignora o giro de 180°** (por exemplo, de "direita" não se pode ir
direto para "esquerda"), como nos snakes clássicos.

Se a cabeça entrar na célula que a **cauda está deixando no mesmo quadro**, o
movimento é permitido: a cauda sai e a célula passa a ser da cabeça (regra
clássica do snake). Porém, se houver uma fruta nessa célula, a cauda não sai e
o choque é real.

---

## 4. Regras e pontuação

- A cobra começa no centro do tabuleiro, com **3 segmentos**, olhando para a
  direita.
- Cada fruta vermelha comida vale **1 ponto** e faz a cobra crescer 1 segmento.
- Bater na **parede** ou no **próprio corpo** encerra a partida.
- A pontuação final é igual ao número de frutas comidas.
- Se a cobra preencher as 1024 células, o jogo mostra a mensagem de **vitória**
  (situação raríssima, mas tratada sem travar).
- A velocidade é fixa: **140 ms por passo** (constante `FRAME_MS`).

---

## 5. Como o código funciona

### 5.1 Memória de vídeo (Bitmap Display)

- Cada célula do tabuleiro ocupa **1 palavra (4 bytes)** na memória de vídeo.
- Célula `(x, y)`, com `0 ≤ x,y ≤ 31`, fica no endereço:

  ```
  endereço = 0x10008000 + (y * 32 + x) * 4
  ```

- A rotina `draw_cell` recebe o índice da célula em `$a0` e a cor em `$a1`.

### 5.2 Teclado (MMIO)

O teclado do MARS expõe dois registradores de memória:

| Endereço | Registrador | Uso |
|---|---|---|
| `0xffff0000` | Receiver Control | bit 0 = 1 quando há tecla pronta |
| `0xffff0004` | Receiver Data | código ASCII da tecla (a leitura limpa o bit 0) |

A rotina `read_key` faz **leitura não bloqueante**: retorna o ASCII da tecla ou
`-1` se nenhuma tecla estiver disponível. Assim o laço do jogo continua
rodando normalmente enquanto espera comandos. O jogo processa **no máximo uma
tecla por frame**; se duas teclas chegarem no mesmo intervalo, a segunda pode
ser descartada (limitação do teclado MMIO do MARS).

### 5.3 Estado do jogo (`.data`)

| Rótulo | Conteúdo |
|---|---|
| `head`, `tail` | índices no buffer circular do corpo |
| `len` | comprimento atual da cobra |
| `dir` | direção atual: `0`=cima, `1`=direita, `2`=baixo, `3`=esquerda |
| `food` | índice da célula da fruta (`-1` se não houver) |
| `score` | frutas comidas |
| `snake_x[1024]`, `snake_y[1024]` | coordenadas de cada segmento (buffer circular) |
| `occ[1024]` | grade de ocupação: `1` byte por célula (teste de colisão O(1)) |

O corpo é um **buffer circular**: a cabeça e a cauda avançam com
`(índice + 1) & 1023`, sem deslocar elementos. A grade `occ` permite testar
colisão com o corpo sem varrer o vetor de segmentos.

### 5.4 Fruta aleatória (LCG)

O MARS não é necessário para o sorteio: o código usa um **gerador congruente
linear** (`rand_idx`):

```
seed = seed * 1103515245 + 12345   (mod 2^32)
índice = (seed >>> 16) & 1023
```

A semente vem do relógio do sistema (`syscall 30`), então as partidas variam.
Se o número sorteado cair sobre a cobra, o código tenta novamente (até 500
vezes) e, em último caso, varre o tabuleiro em ordem até achar uma célula
livre — evitando laço infinito.

### 5.5 Rotinas principais

| Rotina | Responsabilidade |
|---|---|
| `main` | semente aleatória, mensagens iniciais, laço principal e game over |
| `init_game` | limpa tela/grade, posiciona a cobra e sorteia a 1ª fruta |
| `move_snake` | calcula o próximo passo, testa paredes/corpo, atualiza e desenha |
| `place_food` | sorteia e desenha a fruta em célula livre |
| `rand_idx` | gerador pseudoaleatório (LCG) |
| `draw_cell` | pinta uma célula do Bitmap Display |
| `read_key` | leitura não bloqueante do teclado MMIO |
| `poll_input` | traduz teclas em direção/pausa/saída |
| `pause_loop` | laço de pausa |
| `show_dead_snake` | repinta a cobra de cinza no game over |
| `delay_frame` | `syscall 32` (sleep) para controlar a velocidade |

### 5.6 Renderização incremental

Em vez de redesenhar a tela inteira a cada frame (o que piscaria), o jogo
desenha apenas o que muda:

- nova cabeça → verde-claro;
- cabeça anterior → verde-escuro;
- cauda removida → preto;
- fruta nova → vermelho.

Na reinicialização (`R`), a tela inteira é limpa e redesenhada.

---

## 6. Personalização rápida

Edite as constantes no início de `snake.asm`:

- **Velocidade:** `FRAME_MS` (menor = mais rápido).
- **Cores:** `COR_FUNDO`, `COR_CORPO`, `COR_CABECA`, `COR_COMIDA`, `COR_MORTA`
  (formato `0x00RRGGBB`).
- **Tamanho do tabuleiro:** `GRID_W`/`GRID_H`/`NPIXELS` — se mudar, ajuste também
  as configurações do Bitmap Display (as 1024 células atuais correspondem a
  32×32 com unidades de 8×8 pixels).

---

## 7. Solução de problemas

| Sintoma | Causa provável / solução |
|---|---|
| A cobra não se move com as teclas | Clique dentro da caixa de teclado da janela *Keyboard and Display MMIO Simulator* e confirme **Connect to MIPS**. |
| Nada aparece na tela | O *Bitmap Display* não está conectado ou a base não é `0x10008000`; confira a tabela do passo 3. |
| Erro de "endereço fora do intervalo" ao montar/executar | Use a *Memory Configuration* padrão do MARS e não altere `0x10008000`. |
| Comportamento estranho nos desvios | `Settings > Delayed Branching` deve estar **desmarcado**. |
| Setas não fazem nada | Normal: o MMIO do MARS só entrega ASCII. Use WASD ou `8/4/2/6`. |
| Rodar de novo sem reiniciar a simulação | Use **Run → Reset** no MARS (ou feche a janela do Bitmap Display e reconecte) antes de executar de novo. |
| Console muito rápido/lento | Ajuste `FRAME_MS` e a opção `Run → Maximum speed` do MARS. |

---

## 8. Observações didáticas

- Todo o estado do jogo fica em memória (`.data`); os registradores são usados
  para cálculos locais.
- As rotinas seguem a convenção MIPS: quem chama salva `$ra` e `$s*` quando
  necessário; `$t*` e `$a*` são voláteis entre chamadas.
- O código assume `Delayed Branching` desligado (padrão do MARS). Para usar
  *delayed branching*, seria necessário inserir `nop` nos *delay slots*.
- Endereço do Bitmap Display (`0x10008000`) fica **antes** do segmento de dados
  do MARS (`0x10010000`), portanto não há conflito com os vetores do programa.
