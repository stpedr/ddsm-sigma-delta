# Tons idle no DDSM de 1ª ordem com entrada DC

Registro técnico da caracterização feita em 29/09/2026 no golden model em ponto
fixo, com o RTL conferido bit a bit nos pontos de interesse.

## Condições

| item | valor |
|---|---|
| modulador | 1ª ordem, error-feedback, quantizador de 1 bit, realimentação ±FS |
| entrada | `W_IN` = 16 bits, FS = 2^15 = 32 768; acumulador `W_ACC` = 18 bits, com saturação |
| janela | N = 2^16 amostras, Hann |
| banda | OSR = 64, borda em fs/(2·OSR) = fs/128 |
| SNR na banda | `model/snr_banda_dc.m`: sinal = x² (entrada conhecida); ruído = potência de y − x na banda, incluindo o bin 0; Hann normalizada por N·Σw², soma bilateral |
| referência | modelo de ruído branco para quantizador ±1 e NTF de 1ª ordem: π²/(9·OSR³) = −53,8 dBFS na banda |

x = u/FS é a entrada normalizada e dBFS é a potência relativa a FS².

A normalização do SNR foi conferida em casos com resposta conhecida: um erro
constante c dá c²; um seno de amplitude A na banda dá A²/2; um seno fora da
banda dá ~0; ruído branco de variância σ² dá σ²/OSR (razão média 0,996 em 50
sementes, contra 0,999 esperado). Numa senoide, a medida reproduz os 46,57 dB
de `snr_banda.m`.

## a) O fenômeno

Com entrada constante, o laço de 1ª ordem é determinístico e cai num
ciclo-limite. A saída fica periódica ou quase periódica, e o espectro do erro
passa a ser um conjunto de raias discretas, não um piso contínuo. A estimativa
usual de SQNR supõe que o erro de quantização é ruído branco descorrelacionado
da entrada. Com DC essa hipótese deixa de valer: a potência na banda depende do
valor de x e pode ficar abaixo ou acima do modelo branco.

No panorama (200 códigos entre 0 e 0,95·FS), a mediana do ruído na banda é
−70,3 dBFS, 16,5 dB abaixo do modelo branco. O desvio em relação ao modelo
acontece nas duas direções, conforme o valor de x.

## b) Resultado central: as frações exatas são silenciosas

| x | u | ruído na banda |
|---|---|---|
| 1/8 | 4 096 | −242,7 dBFS |
| 1/4 | 8 192 | −246,5 dBFS |
| 1/2 | 16 384 | −240,7 dBFS |
| 5/8 | 20 480 | −238,7 dBFS |
| 3/4 | 24 576 | −229,8 dBFS |
| 7/8 | 28 672 | −221,8 dBFS |
| ≈1/3 | 10 923 | −99,9 dBFS |
| ≈2/3 | 21 845 | −71,5 dBFS |

Em frações exatas o ruído na banda fica em zero numérico. O ciclo-limite tem
período curto e todas as raias caem em frequência alta, fora da banda.

Os tons aparecem na **vizinhança** das frações. Com x = p/q + ε, o padrão curto
escorrega uma vez a cada ~1/ε amostras, e esse batimento lento cai dentro da
banda.

**Previsões refutadas pela medida:**

1. A expectativa inicial era de vales de SNR *nas* frações simples (1/2, 1/4,
   1/3), atribuídos a um período curto com raias dentro da banda. O mecanismo é
   o oposto: período curto põe as raias fora da banda.
2. Antes da primeira varredura, previ que o código mais próximo de 1/3 (10 923,
   a 1/3 de LSB da fração) seria o pior caso. Ele mede −99,9 dBFS: o batimento
   é mais lento que a janela de N amostras e aparece só como um pequeno erro de
   média.
3. A meia-largura FS/(4·OSR) = 128 LSB, derivada no zoom de x = 1/2, foi
   tomada como constante geral. Ela vale só para x = 1/2; a regra geral está
   na seção c.

## c) Regra quantitativa

**Modelo.** Com DC, a saída {0,1} do laço de 1ª ordem é uma sequência de
rotação de densidade ρ = (1+x)/2. Suas raias ficam em k·ρ mod 1, com amplitude
|sin(πkρ)|/(πk). Perto de uma fração, escreve-se ρ = a/P + ε/2, onde P é o
denominador de ρ na forma irredutível, isto é, o período do ciclo-limite:

| centro x | ρ | P |
|---|---|---|
| 0 | 1/2 | 2 |
| 1/4 | 5/8 | 8 |
| 1/3 | 2/3 | 3 |
| 1/2 | 3/4 | 4 |
| −1 | 0 | 1 |
| +1 | 1 | 1 |

A raia mais baixa é a de k = P, em frequência **P·|ε|/2**. Ela está dentro da
banda enquanto P·|ε|/2 < 1/(2·OSR):

> **meia-largura do platô = FS / (OSR · P)**

A altura do platô é a soma das raias k = m·P (m = 1, 2, …) que caem na banda,
cada uma com potência 8·sin²(π·m·P·ε/2)/(π·m·P)² na saída bipolar
(`model/pn_plato_prev.m`).

**Medida.** Zooms com passo de 4 LSB (`model/tons_idle_dc.m`): ±400 LSB em
torno de 0, 1/4, 1/3 e 1/2; de 0 a 1024 LSB para dentro da faixa em x = −1 e
x = +1, o dobro da meia-largura prevista para P = 1. Nos extremos só existe o
lado de dentro, porque a entrada vai de −FS a FS − 1. O centro +1 não é
representável, e o zoom parte de FS − 1 (d = −1). A meia-largura foi medida por
dois caminhos independentes:

- pelo ruído: a primeira queda de mais de 10 dB entre pontos vizinhos, andando
  do centro para fora;
- pelo tom: o primeiro ponto em que a frequência do tom idle (`model/tom_idle.m`)
  passa da borda da banda.

Em ambos a borda é o ponto médio entre os dois pontos vizinhos, com resolução
de ±2 LSB.

| centro | P | meia-largura prevista [LSB] | medida pelo ruído (−/+) | medida pelo tom (−/+) | pico medido | pico previsto |
|---|---|---|---|---|---|---|
| 0 | 2 | 256,0 | 258 / 258 | 258 / 258 | −39,3 dBFS | −39,3 dBFS |
| 1/4 | 8 | 64,0 | 66 / 66 | 66 / 66 | −51,7 dBFS | −51,7 dBFS |
| 1/3 | 3 | 170,7 | 170 / 170 | 170 / 170 | −42,8 dBFS | −42,8 dBFS |
| 1/2 | 4 | 128,0 | 130 / 130 | 130 / 130 | −45,4 dBFS | −45,4 dBFS |
| −1 | 1 | 512,0 | — / 514 | — / 514 | −33,2 dBFS | −33,2 dBFS |
| +1 | 1 | 512,0 | 511 / — | 511 / — | −33,2 dBFS | −33,2 dBFS |

- Os dois métodos dão o mesmo valor nos 10 lados medidos. Nos centros de código
  inteiro a medida fica 2 LSB acima da previsão, por construção; em +1 a grade
  está deslocada de 1 LSB (d = −1, −5, …), e a medida fica 1 LSB abaixo. No ponto exatamente
  sobre a borda prevista, a raia está sobre a borda da banda e ainda é contada
  em parte: em x = 0, d = 256 dá −46,9 dBFS e d = 260 dá −75,1 dBFS. A borda
  real está, portanto, no intervalo (256, 260], e o ponto médio é 258.
- "Pico medido" é o máximo do ruído na banda sobre os pontos da grade dentro
  do platô previsto; "pico previsto" é o máximo da fórmula nos mesmos pontos.
  Os dois coincidem na resolução de 0,1 dB com que foram impressos.
- **Ordem entre previsão e medida:** a fórmula da largura e a da altura foram
  escritas antes de rodar os zooms. Para x = 0, 1/4 e 1/3, os valores da tabela
  são previsões independentes, conferidas depois. Para x = 1/2, a largura
  (±128 LSB) e o pico (−45,4 dBFS) já tinham sido observados num zoom anterior;
  ali a concordância é consistência, não previsão independente. Para x = ±1,
  a meia-largura (512 LSB) e a borda (−33,1 dBFS no ponto contínuo |d| = 511)
  foram registradas neste documento antes da medida. Nos pontos da grade
  (|d| = 508 e 509), fórmula e medida dão −33,2 dBFS.
- Os extremos não estão num regime saturado: nos dois zooms houve 0 ciclos de
  saturação. A excursão do acumulador é FS·(1+|x|) ≤ 2·FS = 65 536, contra
  ACC_MAX = 131 071, e o laço segue a mesma regra dos centros internos.
- Figura principal: `figs/fig6_largura_platos.png`, com a meia-largura medida
  contra FS/(OSR·P). Material de apoio: `figs/fig5_platos_tons_idle.png`, com o
  ruído e a frequência do tom contra o desvio, por centro.

## d) Erro de método corrigido: aliasing da grade de varredura

A primeira varredura usou 200 códigos uniformes entre 0 e 0,95·FS, com passo
médio de 156,4 LSB. As meias-larguras dos platôs vão de 64 a 256 LSB. O passo é
maior que várias delas, então cada platô recebe no máximo dois pontos da grade,
em posições arbitrárias:

| platô | pontos da grade dentro dele |
|---|---|
| 0 (±256) | 2: o centro exato (silencioso) e +156 |
| 1/4 (±64) | 1 |
| 1/3 (±170,7) | 2: −129 e +27 |
| 1/2 (±128) | 2: −115 e +41 |

O panorama resultante mostra "vales" de SNR espalhados, sem relação visível com
as frações. Isso é aliasing da grade, não uma propriedade do circuito. A altura
do platô cresce com |ε| até a borda, então um ponto da grade dentro do platô
subestima o pior valor dele. **Armadilha de medida:** o passo da varredura
precisa ser bem menor que FS/(OSR·P) para os P de interesse. Aqui foram usados
zooms de passo 4 LSB, contra uma meia-largura mínima de 64 LSB.

Um segundo erro de método apareceu na primeira versão do detector de borda,
que tomava a maior queda de ruído da janela. Fora dos platôs existem pontos
isolados muito silenciosos (outras frações exatas; em 1/3 − 307,7 LSB,
u = 10 615, por exemplo, o ruído é de −127,3 dBFS), cuja queda é maior que a
da borda. Com essa
regra, as bordas de 1/4 (lado +) e de 1/3 (lado −) saíram em 274 e 306 LSB. A
regra correta é a primeira queda de mais de 10 dB andando para fora: dentro do
platô, andando para fora, o ruído só sobe.

## e) Pior caso

**Em toda a faixa de entrada**, o pior caso é **u = 32 259**, 509 LSB abaixo
de +1, na borda do platô de P = 1, com **−33,2 dBFS** (previsão: −33,2 dBFS),
ou seja, 20,6 dB acima do modelo branco. A borda simétrica em −1 (u = −32 260)
dá o mesmo valor.

A validade para toda a faixa é uma inferência a partir da regra, não uma
varredura exaustiva. P = 1 é o menor período possível, e a altura do platô na
borda cresce quando P diminui: a raia fundamental tem amplitude ∝ ε, e a borda
fica em ε = FS/(OSR·P). A regra foi conferida em seis centros (P = 1, 2, 3, 4,
8). Longe das frações o ruído fica abaixo do modelo branco (panorama: mediana
−70,3 dBFS).

Excluindo os extremos de fundo de escala, o pior caso é **u = ±252**, na borda
do platô de x = 0, com **−39,27 dBFS** (previsão: −39,27 dBFS), 14,5 dB acima
do modelo branco.

O pior ponto da grade uniforme era u = 156, com −43,4 dBFS. Esse ponto está
dentro do mesmo platô, 100 LSB antes da borda. A diferença de 3,9 dB é o
crescimento da altura do platô entre |ε| = 156 e |ε| = 252 LSB: a previsão em
156 LSB é −43,44 dBFS e a medida, −43,43 dBFS. O pior caso mudou porque a grade
não tinha ponto perto da borda. O teste preliminar com passo de 40 LSB indicava
u = −240 e −39,7 dBFS; com passo de 4 LSB o valor é o acima.

A ordem das alturas de borda segue P: −33,2 dBFS (P = 1), −39,3 (P = 2),
−42,8 (P = 3), −45,4 (P = 4) e −51,7 dBFS (P = 8).

O RTL foi comparado bit a bit com o golden model no pior caso de toda a faixa
(u = 32 259), no pior caso do platô de x = 0 (u = −252), em 1/2 exato (16 384),
no código mais próximo de 1/3 (10 923) e em −FS (−32 768): 0 divergências e
0 overflows nos cinco (`make dc`).

## f) O que o resultado significa

O bloco não mudou. O que mudou é o conhecimento sobre ele: existe um regime de
operação, com entrada DC ou lentamente variável próxima de frações de período
curto, em que o ruído na banda fica acima do que a estimativa de ruído branco
prevê, em até 20,6 dB (junto aos extremos ±FS; 14,5 dB junto a x = 0). Esse regime agora tem localização
(frações com P pequeno), largura (FS/(OSR·P)) e altura (soma das raias m·P·|ε|/2)
previsíveis. Fora dele, e na maior parte da faixa, o ruído com DC fica abaixo do
modelo branco.

## Reprodução

```
# golden model (Octave 8.4 na imagem ddsm-octave:local; ver CLAUDE.md)
tons_idle_dc      # varreduras, figs/tons_idle_dc.mat, fig4 e vetores (~15 min)
figura_platos     # fig5 e fig6 a partir do .mat

# RTL
make dc           # compara os 5 vetores DC bit a bit
```

## Próximo passo: o que fica em aberto

**Pergunta:** existe amplitude de dither que dissolva os platôs a custo
aceitável neste modulador?

A resposta vai sair da varredura de amplitude, com duas medidas por amplitude:
a profundidade dos platôs (nos mesmos zooms) e a degradação do SNR com senoide
a −6 dBFS. Registramos aqui por que a resposta pode ser negativa em 1ª ordem
com 1 bit, como hipótese a testar:

- O degrau do quantizador é 2·FS. Um dither de 1 LSB quase nunca muda a
  decisão de sinal, então não deve alterar o ciclo-limite.
- Para quebrar o batimento de um platô, o dither precisa deslocar o instante
  dos escorregamentos, e isso pede amplitude comparável à excursão do
  acumulador em torno de zero.
- Dither injetado antes do quantizador é moldado pela mesma NTF de 1ª ordem do
  erro de quantização. Na banda, sua potência cresce com o quadrado da
  amplitude e se soma ao piso da senoide.

Se nenhuma amplitude intermediária baixar os platôs sem elevar o piso a ponto de
anular o ganho, o resultado entra na comparação de arquiteturas: ordem mais alta
e MASH atacam os mesmos tons por outro caminho, com um estado mais longo que
torna o ciclo-limite menos provável.
