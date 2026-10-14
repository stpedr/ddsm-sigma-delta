# DDSM de 2ª ordem, CIFB (Boser-Wooley)

Registro técnico da extensão do modulador para a 2ª ordem e da comparação com a
1ª ordem (`docs/tons-idle.md`). O contrato da 1ª ordem (`rtl/ddsm1_params.vh`)
não muda.

| etapa | situação |
|---|---|
| 1. Estrutura, coeficientes e NTF | concluída (seção 1) |
| 2. Modelo em ponto flutuante e em ponto fixo, contrato `rtl/ddsm2_params.vh` | concluída (seção 2); larguras PROVISÓRIAS |
| 3. Campanha de estabilidade | pendente |
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
