# DDSM de 2ª ordem, CIFB (Boser-Wooley)

Registro técnico da extensão do modulador para a 2ª ordem e da comparação com a
1ª ordem (`docs/tons-idle.md`). O contrato da 1ª ordem (`rtl/ddsm1_params.vh`)
não muda.

| etapa | situação |
|---|---|
| 1. Estrutura, coeficientes e NTF | concluída (seção 1) |
| 2. Modelo em ponto flutuante e em ponto fixo, contrato `rtl/ddsm2_params.vh` | concluída (seção 2); larguras PROVISÓRIAS |
| 3. Campanha de estabilidade | medida (seção 3); larguras aguardam decisão de contrato |
| 4. RTL com core comum e verificação bit a bit | pendente |
| 5. Comparação com a 1ª ordem | pendente |

## 1. Estrutura, coeficientes e NTF

### Estrutura

Laço CIFB (*cascade of integrators, feedback*) de 2ª ordem na forma de Boser e
Wooley: dois integradores com atraso, cada um com ganho 0,5, e a saída de 1 bit
realimentada nos dois.

```
v1[n+1] = v1[n] + 0,5·(u[n] − y[n])
v2[n+1] = v2[n] + 0,5·(v1[n] − y[n])
y[n]    = FS·sgn(v2[n])
```

### Forma inteira usada no modelo digital

Com w1 = 2·v1 e w2 = 4·v2:

```
w1[n+1] = w1[n] + b1·u[n]  − a1·y[n]        b1 = 1, a1 = 1
w2[n+1] = w2[n] + c1·w1[n] − a2·y[n]        c1 = 1, a2 = 2
y[n]    = FS·sgn(w2[n])
```

- O quantizador de 1 bit só observa o sinal de w2. Como sgn(4·v2) = sgn(v2),
  as decisões da forma inteira são **idênticas** às do laço com ganhos 0,5.
- A forma inteira não tem divisão por 2. No laço com ganhos 0,5, cada
  deslocamento à direita descartaria um LSB e introduziria um erro de
  truncamento que o modelo linear não prevê. Os ganhos 0,5 de Boser e Wooley
  servem para limitar a excursão de tensão nos integradores analógicos; num
  laço digital, a excursão se resolve com a largura dos registradores, que a
  etapa 3 vai medir.
- Os coeficientes (1, 1, 1, 2) são inteiros e pequenos. Multiplicar por 2 é um
  deslocamento à esquerda, sem perda.

### NTF e STF

Linearizando o quantizador como y = k·w2 + e, com k = 1:

> **NTF(z) = (1 − z⁻¹)²**    **STF(z) = z⁻²**

Derivação: com I(z) = z⁻¹/(1 − z⁻¹), tem-se W1 = I·(U − Y) e
W2 = I·(W1 − 2Y). Então Y·(1 + 2I + I²) = I²·U + E. Como
1 + 2I + I² = (1 + I)² = 1/(1 − z⁻¹)², resulta Y = z⁻²·U + (1 − z⁻¹)²·E.

**Verificação** (`model/ddsm2_ntf.m`): o script simula as próprias equações de
diferença acima, com o quantizador linearizado, e mede as respostas ao impulso:

| | medida | esperada |
|---|---|---|
| 2ª ordem, NTF | [1 −2 1 0 0 0] | (1 − z⁻¹)² |
| 2ª ordem, STF | [0 0 1 0 0 0] | z⁻² |
| 1ª ordem, NTF (forma de `ddsm1.m`) | [1 −1 0 0 0 0] | (1 − z⁻¹) |
| 1ª ordem, STF | [1 0 0 0 0 0] | 1 |

**Sobre k = 1:** num quantizador de 1 bit o ganho k não é definido, porque a
saída depende só do sinal. k = 1 é uma convenção do modelo linear e fixa a NTF
nominal. O laço real escolhe o seu ganho efetivo conforme a amplitude de w2, e
a etapa 5 mede o que ele de fato faz.

**Latência:** a STF é z⁻². A entrada aparece na saída com 2 amostras de atraso
no modelo, contra 0 na forma de `ddsm1.m`, cujo integrador não tem atraso. O RTL
da 1ª ordem acrescenta 1 ciclo de registro de saída. A latência medida no
contrato da 2ª ordem é de 2 ciclos de clock (seção 2).

### Previsões do modelo de ruído branco (OSR = 64)

Quantizador ±1 (degrau 2, variância do erro 1/3). Potência na banda relativa a
FS², pela aproximação |NTF| ≈ (2πf)^L para f ≪ 1, conferida por integração
numérica de (1/3)·|NTF|² sobre a banda (`ddsm2_ntf.m`):

| | 1ª ordem | 2ª ordem |
|---|---|---|
| ruído na banda | π²/(9·OSR³) = −53,8 dBFS | π⁴/(15·OSR⁵) = −82,2 dBFS |
| SNR, seno com A = 0,5 | 44,8 dB | 73,2 dB |
| inclinação SNR × OSR | 9,0 dB/oitava | 15,1 dB/oitava |
| inclinação da NTF abaixo da borda | 20 dB/década | 40 dB/década |
| ganho máximo fora da banda, max \|NTF\| | 2 (em fs/2) | 4 (em fs/2) |

SNR previsto por OSR, para A = 0,5:

| OSR | 32 | 64 | 128 | 256 |
|---|---|---|---|---|
| 1ª ordem | 35,7 dB | 44,8 dB | 53,8 dB | 62,8 dB |
| 2ª ordem | 58,1 dB | 73,2 dB | 88,2 dB | 103,3 dB |

Na 1ª ordem, o modelo previu 44,8 dB e a medida deu 46,6 dB. São previsões a
conferir na etapa 5, não resultados.

**Estabilidade:** max |NTF| = 4 fica acima do limite heurístico de Lee
(≈ 1,5), usado para laços de ordem ≥ 3 com quantizador de 1 bit. Para a 2ª
ordem esse critério não decide nada: o laço de 2ª ordem com 1 bit é
reconhecido como estável para entradas moderadas, mas a excursão dos estados
cresce sem limite fixo quando |u| se aproxima do fundo de escala. Isso **não**
está assumido aqui; a etapa 3 mede a excursão de cada integrador, o ponto de
sobrecarga e a ocorrência de estado travado.

Figura: `figs/fig10_ntf_ordem1x2.png`, com |NTF| das duas ordens e a borda da
banda.

### De onde vêm os coeficientes

- Laço de 2ª ordem com dupla integração: J. C. Candy, "A Use of Double
  Integration in Sigma Delta Modulation", *IEEE Trans. Communications*,
  vol. COM-33, n. 3, 1985.
- Estrutura com dois integradores com atraso e ganhos 0,5: B. E. Boser e
  B. A. Wooley, "The Design of Sigma-Delta Modulation Analog-to-Digital
  Converters", *IEEE J. Solid-State Circuits*, vol. 23, n. 6, 1988.
- NTF (1 − z⁻¹)² e modelo de ruído na banda: R. Schreier e G. C. Temes,
  *Understanding Delta-Sigma Data Converters*, IEEE Press/Wiley, 2005.

As referências foram citadas de memória: volumes e números devem ser
conferidos antes de entrar no texto do trabalho. A forma inteira (1, 1, 1, 2) e
a equivalência com os ganhos 0,5 não dependem das referências; estão derivadas
acima e verificadas pelo script. A delsig toolbox não foi usada.

Desde a etapa 2, os coeficientes ficam só em `rtl/ddsm2_params.vh`, e
`model/ddsm2_ntf.m` os lê de lá.

## 2. Modelo em ponto flutuante e em ponto fixo

### Contrato (`rtl/ddsm2_params.vh`, separado do da 1ª ordem)

| parâmetro | valor | situação |
|---|---|---|
| `W_IN` | 16 bits, com sinal; FS = 2^15 | definido |
| coeficientes B1, A1, C1, A2 | 1, 1, 1, 2 | definido |
| realimentação | ±FS (A1·FS no integrador 1, A2·FS no 2) | definido |
| saída | 1 bit, {0,1}; registro `y_r` = (w2 ≥ 0) após a atualização | definido |
| reset | w1 = w2 = 0, `y_r` = 0 (realimenta −FS no primeiro ciclo) | definido |
| latência | 2 ciclos (medida; ver abaixo) | definido |
| `W_I1`, `W_I2` | 32 bits cada | **PROVISÓRIO**, fechar na etapa 3 |
| saturação | nenhuma no modelo; estouro só gera alarme | **a decidir** na etapa 3 |

As larguras provisórias são largas de propósito, para observar a excursão
**natural** do laço. Saturar antes de medir faria a saturação realimentar e
alterar a dinâmica que se quer caracterizar. Se um integrador sair dessa faixa,
o modelo **não corrige**: conta e reporta como alarme, e isso é resultado da
etapa 3 (o laço divergiu), não motivo para alargar mais.

### Modelos

- `model/ddsm2_flut.m`: ponto flutuante, na forma da literatura, com ganhos 0,5.
- `model/ddsm2.m`: ponto fixo na forma inteira, **única** implementação do laço
  de 2ª ordem em ponto fixo. Os integradores são livres (aritmética exata em
  double até 2^53), devolve a excursão de cada integrador e conta os ciclos fora
  das larguras provisórias.
- `model/ddsm2_fixo.m`: as verificações abaixo.

Os dois usam a mesma convenção de registro da 1ª ordem (`ddsm1.m` e
`rtl/ddsm1.v`), para o core do RTL poder ser comum na etapa 4:

```
fb  = +FS se y_r = 1, −FS se y_r = 0
w1 ← w1 + B1·u  − A1·fb
w2 ← w2 + C1·w1 − A2·fb        (w1 ANTES da atualização)
y_r ← (w2 ≥ 0)                 (w2 DEPOIS da atualização)
```

### Verificação (senoide A = 0,5, K = 41, N = 2^16, OSR = 64)

| verificação | resultado |
|---|---|
| ponto fixo × ponto flutuante, mesma entrada quantizada | **0 divergências** em 65 536 amostras |
| SNR, ponto flutuante (entrada não quantizada) | 70,2 dB |
| SNR, ponto fixo | 70,7 dB |
| SNR, modelo de ruído branco | 73,2 dB |
| piso da própria medida (SNR da senoide ideal pela mesma rotina) | 116,0 dB |
| atraso pela fase do tom (amostras do modelo) | 1ª ordem −0,031; 2ª ordem 0,969 |
| latência em ciclos (+1 do registro de saída) | 1ª ordem 1; 2ª ordem **2** |
| controle do alarme (larguras de 16 bits de propósito) | dispara em i = 1; saída idêntica à da execução larga |
| regressão da 1ª ordem (`le_params()` e `ddsm1_fixo`) | parâmetros e `vetores_ddsm1.txt` inalterados |

- **Equivalência entre forma inteira e ganhos 0,5:** a forma inteira (1, 1, 1, 2)
  e o laço com ganhos 0,5 tomam as mesmas decisões em todas as amostras. Isso
  confirma por medida a equivalência derivada na seção 1.
- **SNR 2,5 a 3 dB abaixo do modelo branco.** Na 1ª ordem a medida ficou 1,8 dB
  *acima* do modelo. O modelo branco com k = 1 é só uma referência; a diferença é
  um dado a acompanhar na etapa 5 (SQNR × OSR e espectro), não um defeito. O piso
  da medida, em 116 dB, está 45 dB abaixo, então a janela não limita o valor
  medido.
- **Latência:** o atraso medido é de 1 amostra a mais que na 1ª ordem, com o
  mesmo deslocamento fracionário (−0,03) nas duas, que vem da própria medida de
  fase. A STF z⁻² da seção 1 corresponde a 2 ciclos de clock entre a entrada e a
  saída registrada.

### Excursão neste estímulo (só informativa; a campanha é a etapa 3)

| integrador | faixa | em FS | largura mínima |
|---|---|---|---|
| w1 | [−87 666, 88 342] | [−2,68, 2,70] | 18 bits |
| w2 | [−129 927, 133 222] | [−3,97, 4,07] | 19 bits |

Na 1ª ordem, o mesmo estímulo deu |acc|max = 1,50·FS. A regra FS·(1+A) da 1ª
ordem não se aplica aqui. A etapa 3 mede a excursão em toda a faixa de entrada.

## 3. Campanha de estabilidade

`model/ddsm2_estab.m` (dados em `figs/ddsm2_estab.mat`), figura
`figs/fig11_estab_2a_ordem.png` (`model/figura_estab.m`). Integradores com as
larguras provisórias de 32 bits, sem saturação; estouro dessa faixa é alarme.

### Critérios, fixados antes da medida

- **Envelope normal:** excursão com entrada zero, em regime, vezes 2:
  |w1| ≤ 2·FS, |w2| ≤ 4·FS. A excursão com entrada zero é |w1| ≤ 1,00·FS e
  |w2| ≤ 2,00·FS.
- **Recuperação:** estímulo por 2¹⁵ amostras, depois 2¹⁴ de entrada zero. O laço
  se recupera se os dois estados entram no envelope em até R = 4096 ciclos e não
  saem mais.
- **Sobrecarga:** bisseção na amplitude de pico, com resolução de 1 LSB e esse
  critério. Só vale se a recuperação for monotônica na grade, o que foi
  conferido.
- **Estado travado:** saída constante do fim do estímulo ao fim da janela.
- **Estabilização da excursão:** máximo da segunda metade da janela de 2¹⁶ maior
  que o da primeira → "não estabilizou".

### Resultados

**Senoide (23 amplitudes, de 0,05 a 1,00):**

| A | max&#124;w1&#124; / FS | max&#124;w2&#124; / FS | razão w2/w1 | SNR (OSR 64) | 1ª ordem: max&#124;acc&#124; / FS |
|---|---|---|---|---|---|
| 0,10 | 1,96 | 2,85 | 1,45 | 57,8 dB | 1,10 |
| 0,30 | 2,22 | 3,18 | 1,43 | 67,3 dB | 1,30 |
| 0,50 | 2,70 | 4,07 | 1,51 | 70,7 dB | 1,50 |
| 0,70 | 3,08 | 5,88 | 1,91 | **71,3 dB** (máximo) | 1,70 |
| 0,80 | 3,33 | 7,73 | 2,32 | 70,9 dB | 1,80 |
| 0,90 | 3,18 | 10,85 | 3,05 | 68,8 dB | 1,90 |
| 0,95 | 3,14 | 15,54 | 4,95 | 61,1 dB | 1,95 |
| 0,98 | 3,72 | 40,10 | 10,35 | 46,2 dB | 1,98 |
| 1,00 | 4,61 | 131,71 | 27,79 | 35,1 dB | 2,00 |

Para A = 0,85, 0,90, 0,98 e 1,00, o máximo de w2 da tabela vem da janela de
2²⁰ amostras (ver "estabilização" abaixo). A razão w2/w1 foi calculada na
janela de 2¹⁶.

- **Não há amplitude de senoide sem recuperação:** o laço se recuperou em toda a
  grade, até o fundo de escala (pico de 32 767 LSB), com tempo de recuperação 0.
  A recuperação foi monotônica (trivialmente: todas recuperam), e a bisseção não
  teve fronteira para buscar.
- **Sobrecarga de desempenho:** o SNR é máximo em A = 0,70 (71,3 dB), fica a até
  3 dB do máximo até A = 0,90 (68,8 dB) e cai rápido depois: 61,1 dB em 0,95 e
  35,1 dB em 1,00. Nessa mesma faixa, a excursão de w2 cresce rápido.

**DC (39 códigos, dos dois sinais, finos junto a ±FS):**

- **Em u = −FS (x = −1) o laço diverge.** w2 cresce
  linearmente, em −2·FS por amostra (w1 vai a −4·FS): −131 070·FS em 2¹⁶ amostras e −524 286·FS em
  2¹⁸. O alarme dispara (32 769 ciclos fora dos 32 bits) e o laço não se
  recupera. A saída fica em 0 durante todo o estímulo (65 534 amostras), que é a
  média correta para x = −1, mas o estado interno diverge. Na 1ª ordem, o mesmo
  estímulo deixa o acumulador parado.
- **Fora de −FS a excursão é limitada, mas w2 cresce como 1/(1 − |x|).** Do lado
  negativo, max|w2| segue o ajuste empírico **FS·(2/(1 − |x|) − 1)** com resíduo
  de até 1,14·FS (em |x| = 0,6) para |x| ≥ 0,5, e exato a 0,3·FS para |x| ≥ 0,7.
  Exemplos: 19,00·FS em x = −0,9 (ajuste 19,0), 198,8·FS em −0,99 (199,0) e
  4095,0·FS em u = −32 752 (4095,0). Do lado positivo os valores ficam abaixo do
  ajuste e se aproximam dele perto de +1: 12,5·FS em +0,9 e 64 815·FS em
  u = 32 767, contra 65 535 do ajuste. O ajuste é uma constatação, não uma
  derivação.
- w1 fica limitado em todo DC: |w1| ≤ 4,00·FS, perto de FS·(1 + 3|x|) para
  |x| ≥ 0,5.
- **Recuperação de DC** (bisseção, depende de R = 4096): recupera até u = −32 764
  (x = −0,999878) e até u = +32 752 (x = +0,999512). Fora desses códigos, o tempo
  para voltar ao envelope passa de R, porque w2 parte de valores muito grandes.

**Rampa de −FS a FS − 1 em 2¹⁶ amostras:** w1 em [−4,00; 3,23]·FS, w2 em
[−482,7; 134,0]·FS, sem alarme. A excursão de w2 vem do começo da rampa, perto
de x = −1. Na 1ª ordem, o mesmo estímulo dá 2,00·FS.

**Estado travado:** nenhum, pelo critério definido (saída constante depois do
fim do estímulo). Durante o estímulo, nos extremos, a saída fica constante por
dezenas de milhares de ciclos: 65 534 em u = −FS e 65 173 em u = FS − 1.

**Estabilização da excursão:** o critério fixado marcou 18 senoides e 8 DCs.
Medindo de novo com janela de 2¹⁸ (4 vezes maior):
- 13 senoides e 6 DCs não mudaram nada. O critério era sensível demais: com
  senoide, o pico cai em fases diferentes de cada metade da janela.
- Em 4 senoides (A = 0,85, 0,90, 0,98, 1,00), o máximo cresceu de 2% a 12% em
  2¹⁸. Com 2²⁰ amostras ficou igual ao de 2¹⁸: a excursão é **limitada**, só
  precisava de uma janela maior para ser atingida.
- O único crescimento real é o DC em u = −FS, que é linear.

### A regra da 1ª ordem não vale na 2ª

Na 1ª ordem, a realimentação de fundo de escala garante |acc| ≤ FS·(1 + |x|) ≤
2·FS para qualquer entrada. Na 2ª ordem não há teto: w2 já chega a 2·FS com
entrada zero, chega a 4·FS em A = 0,5 contra 1,5 na 1ª ordem, e cresce como
2/(1 − |x|) perto do fundo de escala, até divergir em x = −1. O painel (a) da
fig11 mostra os dois comportamentos lado a lado.

### Razão entre as excursões dos integradores

A razão max|w2| / max|w1| é **estável só no regime moderado**: 1,43 a 1,52 para
senoides com A ≤ 0,50, e 1,40 a 1,46 para DC com 0,1 ≤ |x| ≤ 0,4. Acima disso ela
cresce com a amplitude (3,05 em A = 0,9 e 27,8 em A = 1,0) porque só w2 tem a
dependência em 1/(1 − |x|). Conclusões:

- No regime moderado, w2 pede sistematicamente cerca de 1,5 vezes a faixa de
  w1, ou seja, pouco mais de meio bit. No laço digital, mudar a escala entre os
  estágios não muda nenhuma decisão do quantizador (só o sinal de w2 importa):
  muda só onde ficam os bits. Uma escala diferente de 1 entre os estágios
  exigiria divisão e introduziria truncamento, que a forma inteira evita.
- O crescimento perto do fundo de escala não é um desequilíbrio de escala que
  coeficientes resolvam; é a dinâmica do laço de 2ª ordem com 1 bit perto da
  sobrecarga.

### Larguras: o que a medida permite decidir

**w1:** pior caso medido de 4,61·FS (151 k LSB, senoide com A = 1). Cabe em
**19 bits**, com faixa de ±8·FS e margem de 1,7×, em toda a faixa de entrada.

**w2:** não existe largura finita que cubra a faixa de entrada inteira. Em
u = −FS o laço diverge, e de −FS + 1 a FS − 1 a excursão chega a 2³¹ LSB. A
largura depende de **até onde a entrada pode ir**:

| entrada limitada a | pior max&#124;w2&#124; medido | largura com sinal |
|---|---|---|
| &#124;x&#124; ≤ 0,90 (SNR a até 3 dB do máximo) | 19,0·FS (DC −0,9) | 21 bits (±32·FS) |
| &#124;x&#124; ≤ 0,95 | 39,1·FS (DC −0,95) | 22 bits (±64·FS) |
| &#124;x&#124; ≤ 0,99 | 198,8·FS (DC −0,99) | 24 bits (±256·FS) |
| −FS + 1 ≤ u ≤ FS − 1 | 65 535·FS (ajuste) | 33 bits |
| u = −FS | diverge | nenhuma |

A decisão é de contrato e fica com você (seção "Decisão pendente" abaixo).

### Decisão pendente (antes de congelar `ddsm2_params.vh`)

1. **Faixa de entrada especificada** da 2ª ordem. A tabela acima dá a largura de
   w2 para cada escolha. |x| ≤ 0,9 coincide com a faixa em que o SNR fica a até
   3 dB do máximo.
2. **O que acontece fora dela.** A entrada é uma palavra de 16 bits e pode
   chegar a −FS, onde o laço diverge. As opções são limitar a entrada no RTL
   (*clamp*, o que muda o contrato de entrada), saturar os integradores na
   largura escolhida, ou as duas coisas. A saturação muda a dinâmica justamente
   na região de sobrecarga. Se for escolhida, o modelo passa a saturar, e isto
   precisa ser medido antes de congelar: ela não atua dentro da faixa
   especificada, e o laço saturado se recupera de u = −FS.
