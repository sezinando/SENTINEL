# REDUCE GROUP — ESPECIFICAÇÃO OPERACIONAL PARA AUTOMAÇÃO NO ZETAGOLD

## 1. Objetivo

Este documento registra, de forma operacional e implementável, a solução construída no SENTINEL para redução simultânea de uma posição vencedora e de uma posição perdedora dentro da mesma cesta.

O objetivo é servir como especificação de transferência de estratégia para o projeto ZETAGOLD.

O ZETAGOLD não deve copiar simplesmente a interface do SENTINEL. Deve reproduzir o princípio decisório e de execução:

> Quando uma cesta estiver acumulando exposição e uma operação vencedora puder ser usada como parte de uma redução controlada de uma operação perdedora, reduzir parcialmente as duas pernas pelo mesmo volume, diminuindo a exposição da cesta sem depender obrigatoriamente de um recuo do mercado para encerrar toda a cesta.

A solução é um mecanismo de gestão progressiva de exposição, e não uma nova estratégia de entrada.

---

## 2. Problema operacional

Quando o mercado se move fortemente em uma direção, o EA pode continuar abrindo operações de cesta/grid.

Com a continuidade do movimento:

- aumenta a quantidade de ordens;
- aumenta a exposição;
- aumenta o drawdown potencial;
- a cesta fica mais dependente de um recuo;
- esperar exclusivamente pelo recuo pode deixar a operação excessivamente exposta.

Fluxo tradicional:

~~~
Mercado continua contra a cesta
        ↓
EA adiciona posições
        ↓
Exposição aumenta
        ↓
DD aumenta
        ↓
cesta precisa de recuo
        ↓
se o recuo não ocorrer,
a exposição continua pesada
~~~

A solução introduz uma alternativa:

~~~
Mercado continua contra a cesta
        ↓
Existe uma posição muito vencedora
e outra muito perdedora
        ↓
REDUCE GROUP
        ↓
reduzir parcialmente as DUAS posições
        ↓
exposição da cesta diminui
        ↓
menor peso para novos movimentos
        ↓
a cesta continua viva com menor exposição
~~~

A intenção não é prever o próximo movimento. É reduzir progressivamente a exposição enquanto a cesta ainda possui capacidade operacional.

---

## 3. Descoberta operacional

O mecanismo nasceu da seguinte situação:

~~~
WIN muito positiva
+
LOSS muito negativa
~~~

Em vez de simplesmente fechar a WIN, o operador seleciona as duas.

Exemplo:

~~~
BUY  0.10   +80
BUY  0.10   -30
~~~

Executando:

~~~
REDUCE 0.01
~~~

Resultado:

~~~
BUY  0.09
BUY  0.09
~~~

O mesmo princípio vale para:

~~~
BUY  × SELL
SELL × BUY
BUY  × BUY
SELL × SELL
~~~

desde que uma perna esteja vencedora e a outra perdedora.

Portanto:

> A direção BUY/SELL não define a elegibilidade do grupo. O sinal do resultado de cada operação define a elegibilidade.

---

## 4. Regra fundamental

Um grupo REDUCE válido possui duas pernas:

~~~
LEG A
LEG B
~~~

e resultados opostos:

~~~
Result(A) > 0
Result(B) < 0
~~~

ou:

~~~
Result(A) < 0
Result(B) > 0
~~~

Formalmente:

~~~
Result(A) × Result(B) < 0
~~~

Resultado exatamente zero não deve ser tratado como WIN+LOSS.

---

## 5. Regra de redução

Se a solicitação for:

~~~
REDUCE = R
~~~

então:

~~~
CloseLots(A) = R
CloseLots(B) = R
~~~

limitado pelo menor volume disponível:

~~~
EffectiveReduce =
    min(
        RequestedReduce,
        Lots(A),
        Lots(B)
    )
~~~

Depois, o volume efetivo deve ser normalizado segundo:

- lote mínimo;
- lote máximo;
- passo de lote do broker.

Se o lote normalizado for inválido:

~~~
EffectiveReduce <= 0
~~~

não executar.

---

## 6. Por que reduzir as duas pernas

Não queremos:

~~~
WIN  → reduzir
LOSS → manter
~~~

porque isso pode remover justamente a posição que está produzindo resultado enquanto mantém integralmente a posição problemática.

Queremos:

~~~
WIN  → reduzir
LOSS → reduzir
~~~

A ideia econômica é usar a posição vencedora como parte de uma redução simultânea da estrutura, enquanto a posição perdedora também tem sua exposição reduzida.

Importante: não existe transferência literal de dinheiro da WIN para a LOSS. O resultado realizado de cada perna depende do P/L por lote no momento do fechamento.

---

## 7. Exemplo BUY × SELL

Estado:

~~~
BUY  0.10  +80
SELL 0.10  -30
~~~

REDUCE 0.01:

~~~
BUY  0.09
SELL 0.09
~~~

A exposição bruta cai de 0.20 para 0.18.

Como as posições são opostas, a exposição líquida pode ter comportamento diferente da exposição bruta. O ZETAGOLD deve registrar separadamente:

~~~
GROSS EXPOSURE
NET EXPOSURE
~~~

---

## 8. Exemplo BUY × BUY

~~~
BUY 0.10  +80
BUY 0.10  -30
~~~

REDUCE 0.01:

~~~
BUY 0.09
BUY 0.09
~~~

A exposição bruta cai e a exposição líquida BUY também diminui.

---

## 9. Exemplo SELL × SELL

~~~
SELL 0.10  +80
SELL 0.10  -30
~~~

REDUCE 0.01:

~~~
SELL 0.09
SELL 0.09
~~~

A mesma regra é aplicada.

---

## 10. Lotes diferentes

Exemplo:

~~~
WIN  0.10
LOSS 0.04
~~~

Solicitação:

~~~
REDUCE 0.05
~~~

O máximo possível é:

~~~
min(0.05, 0.10, 0.04) = 0.04
~~~

Portanto:

~~~
WIN  → 0.06
LOSS → 0.00
~~~

O comportamento de fechamento total da menor posição deve respeitar as regras de lote mínimo do broker.

Nunca solicitar volume superior ao disponível em qualquer uma das duas pernas.

---

## 11. Ordenação visual do CESTA MANAGER

A interface atual foi alterada para:

~~~
mais nova → mais antiga
~~~

O critério primário é:

~~~
OrderOpenTime()
~~~

Em caso de empate:

~~~
maior ticket → primeiro
~~~

Motivo: ordenar por lote faria uma posição mudar de lugar após uma redução parcial. Ordenar por idade mantém a posição visual associada à identidade temporal da operação.

Essa decisão é visual/operacional e não altera a lógica de execução.

---

## 12. Processo manual atual

O operador atualmente faz:

~~~
1. Observar a cesta
2. Identificar que a exposição está ficando pesada
3. Encontrar uma operação muito vencedora
4. Encontrar uma operação muito perdedora
5. Selecionar as duas
6. Definir um volume pequeno
7. REDUCE BOTH
8. Reavaliar a cesta
9. Repetir se necessário
~~~

A característica fundamental é:

> A redução pode ocorrer sem esperar que o mercado recue.

---

## 13. Estratégia progressiva

Exemplo:

~~~
WIN  0.10
LOSS 0.10

GROSS = 0.20
~~~

Após REDUCE 0.01:

~~~
WIN  0.09
LOSS 0.09

GROSS = 0.18
~~~

Se o mercado continuar:

~~~
WIN  0.08
LOSS 0.08

GROSS = 0.16
~~~

E assim por diante.

A estratégia é uma desmontagem progressiva da exposição.

Não é necessário zerar a cesta imediatamente.

---

## 14. Relação com DD

A estratégia não garante redução do drawdown financeiro em todos os instantes.

O efeito pretendido é:

~~~
menos lotes expostos
        ↓
menor exposição futura
        ↓
menor sensibilidade a novos movimentos
        ↓
menor crescimento potencial do DD
~~~

Portanto, o ZETAGOLD deve acompanhar não apenas DD atual, mas também:

~~~
Current Exposure
Projected Exposure
Exposure Growth
Basket Capacity
~~~

---

## 15. Capacidade da cesta

É útil separar:

~~~
CURRENT EXPOSURE
~~~

de:

~~~
MAXIMUM ACCEPTABLE EXPOSURE
~~~

e:

~~~
REDUCTION CAPACITY
~~~

Conceitualmente:

~~~
Capacity =
MaximumAllowedExposure - CurrentExposure
~~~

A regra exata que dispara uma redução automática ainda precisa ser calibrada com dados.

Não inventar esse gatilho sem teste.

---

## 16. O que ainda NÃO está definido

A solução manual não define automaticamente:

- qual WIN escolher;
- qual LOSS escolher;
- quando exatamente executar;
- qual percentual da exposição reduzir;
- qual DD dispara a redução;
- qual lucro mínimo da WIN deve existir;
- qual prejuízo mínimo da LOSS deve existir;
- quantas reduções consecutivas são permitidas;
- intervalo mínimo entre reduções;
- limite diário de reduções;
- comportamento em notícias;
- comportamento com spread elevado;
- comportamento durante mudanças bruscas de volatilidade.

Esses itens são a futura camada de decisão do ZETAGOLD.

Não devem ser inventados como se fossem regras já validadas.

---

## 17. Regras já definidas e que devem ser preservadas

### Regra A — duas pernas

O grupo é composto por duas posições.

### Regra B — resultados opostos

Uma deve estar positiva e outra negativa.

### Regra C — redução igual

As duas recebem o mesmo volume efetivo.

### Regra D — limite pela menor posição

Nunca reduzir mais do que o volume disponível de qualquer uma das duas.

### Regra E — direção não importa

São válidos:

~~~
BUY × SELL
SELL × BUY
BUY × BUY
SELL × SELL
~~~

desde que sejam:

~~~
WIN × LOSS
~~~

### Regra F — execução parcial

A ação não precisa encerrar a cesta.

### Regra G — reavaliação

Depois de cada redução, a cesta deve ser recalculada.

---

## 18. Implementação atual no SENTINEL

O fluxo de execução é:

~~~
BuildSelectedReductionPlan()
        ↓
identifica T1/T2
        ↓
verifica resultados
        ↓
WIN + LOSS?
        ↓
validar T1
        ↓
validar T2
        ↓
calcular closeLots
        ↓
revalidar T1
        ↓
PartialCloseTicket(T1)
        ↓
revalidar T2
        ↓
PartialCloseTicket(T2)
~~~

A execução não confia cegamente na informação que estava na tela no momento da seleção.

---

## 19. Não existe atomicidade MT4

As duas reduções são duas operações distintas.

Pode ocorrer:

~~~
T1 = sucesso
T2 = falha
~~~

Isso deve ser tratado como:

~~~
PARTIAL EXECUTION
~~~

O ZETAGOLD não deve assumir que as duas operações são uma transação atômica.

Após uma falha parcial, deve:

1. registrar o evento;
2. reconstruir o estado atual da cesta;
3. reavaliar;
4. somente então decidir se alguma nova ação é necessária.

---

## 20. Auto Reduce já existente

O SENTINEL já possui Auto Reduce.

Conceitualmente:

~~~
AUTO REDUCE ON
        ↓
Current Group
        ↓
calcular Group Result
        ↓
verificar Minimum Profit
        ↓
calcular volume
        ↓
usar o mesmo executor manual
~~~

Princípio arquitetural:

> Automatizar o momento da decisão, não duplicar a execução.

Esse princípio deve ser preservado no ZETAGOLD.

---

## 21. Anti-repetição

A automação não pode ficar executando REDUCE a cada tick.

É necessário manter uma identidade do grupo:

~~~
GroupSignature =
TicketA + TicketB
~~~

e estado de execução.

Conceitualmente:

~~~
ARMED
  ↓
EXECUTED
  ↓
WAIT RESET
~~~

Depois de uma redução, deve existir uma nova condição de elegibilidade antes de repetir.

O critério exato de RESET ainda deve ser definido e testado no ZETAGOLD.

---

## 22. Arquitetura desejada no ZETAGOLD

A solução deve ser integrada à arquitetura existente, e não virar uma engine paralela sem responsabilidade clara.

Fluxo conceitual:

~~~
MARKET CONTEXT
        +
BASKET CONTEXT
        ↓
DECISION ENGINE
        ↓
HOLD / REDUCE / RED
        ↓
ACTION PREVIEW
        ↓
EXECUTION
~~~

Para REDUCE:

~~~
MARKET CONTEXT
    ↓
BASKET CONTEXT
    ↓
REDUCE DECISION
    ↓
PAIR SELECTION
    ↓
REDUCE PLAN
    ↓
VALIDATION
    ↓
EXECUTION
~~~

A camada de Exposure/Recovery é uma candidata natural para hospedar a lógica de gestão da cesta, mas a responsabilidade deve continuar separada da execução.

---

## 23. MARKET CONTEXT

O mecanismo deve consumir o contexto já existente no ZETAGOLD, por exemplo:

- direção;
- volatilidade;
- ATR;
- regime de mercado;
- velocidade do movimento;
- estresse.

REDUCE não deve criar uma nova família de indicadores somente para funcionar.

---

## 24. BASKET CONTEXT

Deve disponibilizar:

~~~
Ticket
Type
Lots
OpenPrice
CurrentPrice
Profit
Swap
Commission
NetResult
OpenTime
Age
GrossExposure
NetExposure
DD
PositionCount
~~~

Opcionalmente, no futuro:

~~~
MFE
MAE
ATR at entry
ATR current
Market regime at entry
Market regime current
~~~

---

## 25. REDUCE DECISION

A decisão deve responder:

~~~
Existe necessidade de reduzir?
Existe um par WIN+LOSS válido?
Qual par?
Quanto reduzir?
~~~

Não executar ainda.

---

## 26. PAIR SELECTION

Hoje o operador escolhe manualmente.

No ZETAGOLD será necessário selecionar automaticamente:

~~~
WIN CANDIDATES
+
LOSS CANDIDATES
        ↓
PAIR SELECTION
~~~

Não assumir automaticamente que:

~~~
maior WIN + maior LOSS
~~~

é sempre o melhor par.

Esse algoritmo precisa ser estudado com dados.

---

## 27. Dados para Pair Selection

O algoritmo deverá ter acesso a:

~~~
Ticket
Type
Lots
Profit
Swap
Commission
NetResult
OpenPrice
CurrentPrice
OpenTime
Age
Distance from market
Contribution to gross exposure
Contribution to net exposure
~~~

Futuramente:

~~~
MFE
MAE
ATR at entry
ATR current
Market regime
~~~

---

## 28. Critério econômico

Separar:

~~~
Profit of leg
~~~

de:

~~~
Profit contribution of reduction
~~~

Ao reduzir R lotes, o resultado realizado depende do P/L por lote naquele instante.

Logo:

~~~
RealizedA
≠
necessariamente
RealizedB
~~~

e:

~~~
RealizedGroup =
RealizedA + RealizedB
~~~

O ZETAGOLD deve registrar esses valores.

---

## 29. Métricas obrigatórias de teste

Cada REDUCE GROUP deve gerar pelo menos:

~~~
Timestamp
Symbol
Basket ID / Magic
Ticket A
Ticket B
Type A
Type B
Lots A Before
Lots B Before
Result A Before
Result B Before
Requested Reduce
Effective Reduce
Lots A After
Lots B After
Result A Realized
Result B Realized
Group Realized
Gross Exposure Before
Gross Exposure After
Net Exposure Before
Net Exposure After
DD Before
DD After
Basket Result Before
Basket Result After
Market Price
ATR
Market Regime
Execution Status
~~~

---

## 30. Métricas para avaliar a estratégia

### Exposição

~~~
Gross Exposure Before
Gross Exposure After
Exposure Reduction %
~~~

### DD

~~~
DD Before
DD After
Maximum DD after reduction
~~~

### Cesta

~~~
Basket Duration
Final Basket Result
Maximum Exposure
Maximum DD
Number of Reductions
Total Lots Reduced
~~~

### Execução

~~~
Successful Groups
Partial Executions
Failed Executions
Repeated Executions
~~~

---

## 31. Métrica mais importante

Não avaliar somente:

~~~
"REDUCE deu lucro?"
~~~

A pergunta principal é:

> Quanto risco/exposição futura foi removido para cada unidade de resultado realizado?

Uma possível métrica futura é:

~~~
Reduction Efficiency =
Exposure Reduced / Realized Cost
~~~

O formato definitivo dessa métrica deve ser definido após os primeiros testes.

---

## 32. Comparação necessária

Para validar a estratégia, comparar:

~~~
BASELINE
cesta sem REDUCE
~~~

contra:

~~~
REDUCE GROUP
cesta com reduções
~~~

Comparar pelo menos:

~~~
Maximum DD
Maximum Exposure
Time in Drawdown
Maximum Lot
Basket Duration
Final Basket Result
Recovery Time
Number of Basket Closures
~~~

Não comparar apenas lucro líquido.

---

## 33. Cenários de teste

Testar primeiro:

~~~
BUY × SELL
SELL × BUY
BUY × BUY
SELL × SELL
~~~

Depois:

~~~
0.10 × 0.05
0.05 × 0.10
~~~

Depois:

~~~
múltiplas reduções consecutivas
~~~

E finalmente movimentos prolongados contra a cesta.

---

## 34. Cenário crítico

Testar:

~~~
WIN  0.10
LOSS 0.10
~~~

com:

~~~
REDUCE 0.01
REDUCE 0.01
REDUCE 0.01
REDUCE 0.01
...
~~~

Observar:

- lote mínimo;
- encerramento de uma perna;
- reconstrução do grupo;
- nova seleção;
- comportamento da cesta após uma perna desaparecer.

---

## 35. Cenário de mercado prolongado

Testar:

~~~
t0 → cesta pesada
t1 → REDUCE
t2 → mercado continua
t3 → REDUCE
t4 → mercado continua
t5 → REDUCE
~~~

Objetivo experimental:

verificar se a estratégia reduz a taxa de crescimento de:

~~~
Exposure
DD potential
Lot accumulation
~~~

sem exigir que o mercado faça um recuo imediato.

---

## 36. Não confundir REDUCE com RED

REDUCE:

~~~
diminui posições existentes
~~~

RED:

~~~
altera/protege a estrutura de exposição
~~~

São decisões diferentes.

Não combinar automaticamente as duas.

---

## 37. Não confundir REDUCE com CLOSE ALL

REDUCE mantém a cesta viva.

CLOSE ALL encerra a cesta.

Uma oportunidade REDUCE não deve automaticamente impedir regras existentes de encerramento.

---

## 38. Não alterar a lógica de entrada

REDUCE é pós-entrada.

Não deve modificar:

- sinal de entrada;
- direção;
- grid;
- FirstStep;
- Step;
- multiplicador;
- lógica de abertura.

A entrada continua sendo responsabilidade do mecanismo existente.

---

## 39. Fluxo OBSERVE → INTERPRET → SIMULATE → EXECUTE

### OBSERVE

Ler a cesta.

### INTERPRET

Identificar se existe oportunidade REDUCE.

### SIMULATE

Calcular:

~~~
Lots After
Gross Exposure After
Net Exposure After
Projected Realized Result
~~~

### EXECUTE

Enviar as duas reduções.

---

## 40. Action Preview

Antes de executar, o sistema deve conseguir representar algo equivalente a:

~~~
REDUCE GROUP

WIN
Ticket: 12345
BUY
0.10
+82.40

LOSS
Ticket: 12367
SELL
0.10
-51.20

REDUCE
0.01

AFTER
WIN  0.09
LOSS 0.09

GROSS EXPOSURE
0.20 → 0.18

NET EXPOSURE
before → after

PROJECTED GROUP RESULT
...
~~~

Isso é importante para debug, backtest e validação.

---

## 41. Revalidação

Nunca executar usando dados antigos.

Entre decisão e execução:

~~~
OrderSelect(ticket)
~~~

deve ser realizado novamente.

Validar:

~~~
ticket exists
symbol
magic
type
lots
current result
~~~

e:

~~~
effective reduce <= current lots
~~~

Se qualquer condição mudou:

~~~
ABORT
ou
REBUILD PLAN
~~~

---

## 42. Falha parcial

Caso:

~~~
A = sucesso
B = falha
~~~

registrar:

~~~
PARTIAL_REDUCE
~~~

Depois:

1. reconstruir o estado da cesta;
2. atualizar exposição;
3. atualizar DD;
4. impedir repetição cega;
5. reavaliar a próxima ação.

---

## 43. Estado persistente

O mecanismo deve possuir estado suficiente para sobreviver ao ciclo normal do EA.

Estado conceitual mínimo:

~~~
LastReduceGroupSignature
LastReduceTimestamp
LastReduceResult
LastReduceStatus
~~~

A forma de persistência deve seguir o padrão existente do ZETAGOLD.

---

## 44. Anti-overtrading

Deve existir um mecanismo de cooldown ou equivalente.

Conceito:

~~~
REDUCE
  ↓
aguardar nova avaliação
  ↓
não repetir imediatamente
~~~

O valor do cooldown não está definido.

Deve ser calibrado em teste.

---

## 45. O que a solução NÃO promete

A estratégia não garante:

- lucro;
- redução instantânea do DD;
- encerramento da cesta;
- recuperação;
- proteção contra movimentos extremos;
- proteção contra gap;
- proteção contra spread anormal;
- proteção contra falha de execução.

Ela fornece um mecanismo para:

> reduzir progressivamente a exposição de uma cesta através da redução simultânea de uma posição vencedora e uma perdedora.

---

## 46. Hipótese a ser validada

Hipótese operacional:

> Em movimentos prolongados de mercado que fazem a cesta acumular posições, pequenas reduções simultâneas de posições WIN e LOSS podem reduzir a exposição e a capacidade de crescimento do DD, permitindo administrar a cesta sem depender exclusivamente de um recuo do mercado.

Essa hipótese deve ser validada por backtest e forward test.

---

## 47. Objetivo final no ZETAGOLD

O objetivo não é reproduzir o painel.

É transformar:

~~~
DECISÃO MANUAL
~~~

em:

~~~
DECISÃO ALGORÍTMICA
~~~

O operador hoje faz:

~~~
"Esta WIN está muito boa."
+
"Esta LOSS está muito pesada."
+
"Vou reduzir 0.01 das duas."
~~~

O ZETAGOLD deverá futuramente chegar à mesma decisão usando dados objetivos:

~~~
BASKET STATE
+
MARKET STATE
+
EXPOSURE STATE
+
PAIR QUALITY
+
RISK STATE
        ↓
REDUCE DECISION
        ↓
REDUCE PLAN
        ↓
EXECUTION
~~~

---

## 48. Fluxo completo desejado

~~~
┌──────────────────────────────┐
│        MARKET CONTEXT        │
│ ATR / regime / direction     │
│ volatility / stress          │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│        BASKET CONTEXT        │
│ tickets / lots / P&L         │
│ gross / net exposure / DD    │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│      REDUCE DECISION         │
│                              │
│ Is basket overloaded?        │
│ Is there WIN + LOSS?         │
│ Is reduction justified?      │
└──────────────┬───────────────┘
               │
              YES
               │
               ▼
┌──────────────────────────────┐
│       PAIR SELECTION         │
│ select WIN                   │
│ select LOSS                  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│        REDUCE PLAN           │
│ requested lots               │
│ effective lots               │
│ projected exposure           │
│ projected result             │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│         VALIDATION           │
│ ticket / symbol / magic      │
│ lots / lot step              │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│          EXECUTION           │
│ PartialClose(A,R)            │
│ PartialClose(B,R)            │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│         POST-TRADE           │
│ re-read basket               │
│ record result                │
│ update exposure              │
│ update DD                    │
│ update state                 │
└──────────────────────────────┘
~~~

---

## 49. Contrato funcional

Conceitualmente:

~~~
ReduceGroup(
    ticketWin,
    ticketLoss,
    requestedLots
)
~~~

Pré-condições:

~~~
ticketWin exists
ticketLoss exists

Result(ticketWin) > 0
Result(ticketLoss) < 0

requestedLots > 0
~~~

Cálculo:

~~~
effectiveLots =
    NormalizeLot(
        min(
            requestedLots,
            Lots(ticketWin),
            Lots(ticketLoss)
        )
    )
~~~

Execução:

~~~
PartialClose(ticketWin, effectiveLots)
PartialClose(ticketLoss, effectiveLots)
~~~

Pós-condições esperadas, se ambas tiverem sucesso:

~~~
LotsWinAfter  = LotsWinBefore  - effectiveLots
LotsLossAfter = LotsLossBefore - effectiveLots
~~~

---

## 50. Teste de aceitação

A implementação automática deve reproduzir:

~~~
WIN BUY  × LOSS SELL
WIN SELL × LOSS BUY
WIN BUY  × LOSS BUY
WIN SELL × LOSS SELL
~~~

com:

~~~
Reduce(A) == Reduce(B)
~~~

e, quando ambas as pernas forem efetivamente reduzidas:

~~~
GrossExposureAfter < GrossExposureBefore
~~~

---

## 51. Status atual

### IMPLEMENTADO NO SENTINEL

- seleção de duas posições;
- seleção por ticket;
- identificação WIN/LOSS;
- redução simultânea;
- BUY × SELL;
- SELL × BUY;
- estrutura para BUY × BUY;
- estrutura para SELL × SELL;
- limite pelo menor lote;
- normalização de lote;
- revalidação antes da execução;
- tratamento explícito de execução parcial;
- Auto Reduce;
- Current Group;
- exposição;
- resultado do grupo;
- assinatura para anti-repetição;
- ordenação visual por ordem mais nova → mais antiga.

### AINDA A DEFINIR PARA O ZETAGOLD

- algoritmo de seleção automática da WIN;
- algoritmo de seleção automática da LOSS;
- gatilho de REDUCE;
- limite de exposição;
- limite de DD;
- cooldown;
- quantidade máxima de reduções;
- distância mínima entre reduções;
- critérios de qualidade do par;
- interação com regime de mercado;
- interação com RED;
- interação com Recovery;
- interação com CLOSE ALL;
- parametrização para backtest;
- métricas definitivas de sucesso.

---

## 52. Diretriz para o chat de programação do ZETAGOLD

Ao implementar:

1. Não criar uma segunda lógica de execução de ordens.
2. Utilizar o executor existente do ZETAGOLD.
3. Criar REDUCE como camada de gestão.
4. Preservar a regra WIN+LOSS.
5. Reduzir as duas pernas pelo mesmo volume efetivo.
6. Revalidar as duas posições imediatamente antes da execução.
7. Tratar execução parcial explicitamente.
8. Registrar todas as decisões e resultados.
9. Não alterar a lógica de entrada existente.
10. Não alterar RED, CLOSE ALL, TAKE ou STOP sem decisão específica de arquitetura.
11. Implementar primeiro em modo observação/simulação.
12. Depois executar em modo controlado.
13. Validar contra o comportamento manual do SENTINEL.
14. Só depois permitir automação completa.

---

## 53. Regra de ouro

> Não fechar a vencedora isoladamente quando a intenção é aliviar uma cesta WIN+LOSS. Reduzir as duas pernas do grupo pelo mesmo volume efetivo, preservando a relação do grupo e diminuindo a exposição da cesta.

Segunda regra:

> Automatizar a decisão sem duplicar a execução.

---

## 54. Essência da solução

A ideia que deve ser transportada para o ZETAGOLD é:

> Quando uma cesta estiver pesada, não precisamos necessariamente esperar que o mercado volte para começar a diminuir a exposição. Podemos usar uma posição vencedora e uma perdedora como um grupo de redução, diminuindo simultaneamente as duas exposições em pequenos passos e mantendo a cesta operacional.

Este documento deve ser tratado como a especificação funcional inicial do mecanismo REDUCE GROUP no ZETAGOLD. Os critérios de seleção automática e os gatilhos quantitativos devem ser desenvolvidos posteriormente a partir de testes e dados, e não presumidos como regras já validadas.
