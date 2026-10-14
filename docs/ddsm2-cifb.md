# DDSM de 2ª ordem, CIFB (Boser-Wooley)

Registro técnico da extensão do modulador para a 2ª ordem e da comparação com a
1ª ordem (`docs/tons-idle.md`). O contrato da 1ª ordem (`rtl/ddsm1_params.vh`)
não muda.

| etapa | situação |
|---|---|
| 1. Estrutura, coeficientes e NTF | concluída (seção 1) |
| 2. Modelo em ponto flutuante e em ponto fixo, contrato `rtl/ddsm2_params.vh` | pendente |
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
da 1ª ordem acrescenta 1 ciclo de registro de saída. A latência do contrato da
2ª ordem será declarada na etapa 2.

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

Os coeficientes estão escritos em `model/ddsm2_ntf.m` só para esta verificação.
Na etapa 2 eles passam para `rtl/ddsm2_params.vh`, fonte única, e o script
passa a lê-los de lá.
