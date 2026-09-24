# REDUCE GROUP — Regra Operacional

## Objetivo

O **REDUCE GROUP** reduz simultaneamente a exposição de duas ordens selecionadas que formam um grupo operacional.

Quando o grupo contém uma operação com lucro e outra com prejuízo, a redução deve retirar o mesmo volume de ambas, realizando uma parcela do lucro e uma parcela do prejuízo.

A finalidade é reduzir a exposição das duas pernas do grupo mantendo a relação operacional entre elas.

## Regra fundamental

**WIN + LOSS → reduzir as duas ordens pelo mesmo lote.**

Exemplo:

    T1  SELL  0.10  +$100
    T2  BUY   0.10   -$30

    REDUCE 0.01

Execução esperada:

    T1  SELL  0.10 → 0.09
    T2  BUY   0.10 → 0.09

O resultado financeiro da redução é a soma dos resultados efetivamente realizados nas duas ordens, considerando também custos reais de execução, como comissão e swap.

## A direção das ordens não importa

| Ordem 1 | Ordem 2 | Regra |
|---|---|---|
| BUY | SELL | reduzir ambas |
| SELL | BUY | reduzir ambas |
| BUY | BUY | reduzir ambas |
| SELL | SELL | reduzir ambas |

A direção não define qual ordem será reduzida. A condição que define a operação é a existência de uma WIN e uma LOSS dentro do grupo.

## Exemplo BUY × SELL

    BUY   0.10   +$80
    SELL  0.10   -$30

Com REDUCE 0.01:

    BUY   0.10 → 0.09
    SELL  0.10 → 0.09

A exposição bruta cai:

    Antes: 0.20 lot
    Depois: 0.18 lot

Quando as duas pernas possuem o mesmo volume, o net exposure pode permanecer igual:

    Antes:  +0.10 - 0.10 = 0.00
    Depois: +0.09 - 0.09 = 0.00

O objetivo da operação é a redução da gross exposure, e não necessariamente a alteração do net exposure.

## Exemplo SELL × SELL

    SELL #1  0.20  +$120
    SELL #2  0.20   -$40

Com REDUCE 0.05:

    SELL #1  0.20 → 0.15
    SELL #2  0.20 → 0.15

As duas ordens perdem exposição simultaneamente.

## Exemplo BUY × BUY

    BUY #1  0.10  +$70
    BUY #2  0.10  -$20

Com REDUCE 0.02:

    BUY #1  0.10 → 0.08
    BUY #2  0.10 → 0.08

Novamente, a direção é irrelevante.

## Critério de elegibilidade

Para a regra de profit + loss, o grupo deve conter:

    1 WIN
    1 LOSS

Portanto:

- **WIN + LOSS** → elegível para REDUCE GROUP.
- **LOSS + WIN** → elegível para REDUCE GROUP.
- **WIN + WIN** → não é uma operação de compensação WIN/LOSS.
- **LOSS + LOSS** → não existe reserva de lucro para compensação.

## TARGET e REFERENCE

Para esta regra, o conceito anterior de uma única TARGET e uma única REFERENCE não representa corretamente a operação.

O grupo deve ser tratado como uma unidade de duas pernas:

    GROUP

    LEG 1 → WIN
    LEG 2 → LOSS

    ACTION → REDUCE BOTH

O executor deve receber as duas ordens como participantes da redução.

## Quantidade a reduzir

Se o usuário solicitar:

    REDUCE = X lot

o objetivo é:

    close(T1) = X
    close(T2) = X

respeitando:

- volume disponível de cada ordem;
- lote mínimo do ativo;
- passo de lote;
- normalização de volume;
- validação do ticket imediatamente antes da execução.

A operação não deve assumir que os dois tickets continuam válidos apenas porque estavam selecionados anteriormente.

## Atomicidade operacional

A redução de duas pernas é uma operação composta.

O SENTINEL deve validar as duas ordens antes de iniciar a execução.

Não é aceitável considerar a operação concluída quando ocorrer apenas:

    T1 → sucesso
    T2 → falha

Nesse caso, o sistema precisa informar explicitamente que houve execução parcial e registrar o estado resultante.

Fluxo desejado:

    VALIDAR T1
    VALIDAR T2
    VALIDAR LOTES
    VALIDAR CONDIÇÕES
            ↓
    EXECUTAR T1
    EXECUTAR T2

A execução real continua sujeita às condições do broker; portanto, o código não deve prometer atomicidade transacional que o MT4 não oferece.

## Relação com CURRENT GROUP

O CURRENT GROUP representa a unidade de decisão:

    OBSERVE
       ↓
    CURRENT GROUP
       ↓
    INTERPRET
       ↓
    WIN + LOSS?
       ↓
      SIM
       ↓
    SIMULATE
       ↓
    REDUCE X
       ↓
    EXECUTE
       ↓
    REDUZIR AS DUAS PERNAS

O painel deve permitir visualizar claramente:

- ticket da primeira ordem;
- ticket da segunda ordem;
- direção;
- volume;
- resultado individual;
- resultado do grupo;
- volume de redução;
- exposição antes;
- exposição depois.

## Princípio financeiro

O conceito não é fechar uma operação vencedora para simplesmente realizar lucro.

O conceito é:

**realizar simultaneamente uma parcela do lucro e uma parcela do prejuízo para retirar exposição das duas pernas do grupo.**

Assim, o REDUCE GROUP atua como ferramenta de redução de risco/exposição do conjunto, e não como simples partial close de uma ordem individual.

## Regra oficial para implementação

    REDUCE GROUP

    IF selected_orders == 2
    AND one_order_result > 0
    AND other_order_result < 0

    THEN

        reduce selected order 1 by X
        reduce selected order 2 by X

        where X is the requested normalized reduction volume

A direção das ordens não altera a regra:

    BUY × SELL → REDUCE BOTH
    SELL × BUY → REDUCE BOTH
    BUY × BUY   → REDUCE BOTH
    SELL × SELL → REDUCE BOTH

A implementação futura deve manter esta regra centralizada para que REDUCE manual e AUTO REDUCE utilizem a mesma decisão operacional.
