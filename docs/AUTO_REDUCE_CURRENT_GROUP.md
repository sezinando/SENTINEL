# SENTINEL — Auto Reduce por CURRENT GROUP

## 1. Objetivo

Adicionar ao SENTINEL uma camada opcional de AUTO REDUCE sobre o mecanismo existente de seleção e redução do CURRENT GROUP.

A funcionalidade não substitui o REDUCE manual. Ela adiciona uma forma condicionada de disparar a mesma operação quando o resultado do grupo selecionado atingir um lucro mínimo configurado.

Regra central:

SELEÇÃO + RESULTADO DO CURRENT GROUP + AUTO REDUCE + MIN PROFIT + REDUCE LOTS → DECISION ENGINE → REDUCE TARGET

## 2. Princípio arquitetural

- Manual Reduce: operador decide quando executar.
- Auto Reduce: sistema decide quando executar, mas utiliza o mesmo executor de redução.
- Execution: permanece centralizada na lógica de redução existente.

Não criar uma segunda implementação de fechamento parcial para o Auto Reduce. O Auto Reduce altera a condição de disparo, não a mecânica de execução.

## 3. Interface proposta

CURRENT GROUP

T1 [12345]   T2 [12367]   LIMPAR

TARGET      BUY 0.40
REFERENCE   SELL 0.20
GROUP NET   +0.20 → +0.10
EXPOSURE    0.60 → 0.50
RESULT      +22.50

AUTO REDUCE [OFF]
MIN PROFIT  20.00
REDUCE LOTS 0.10

[ REDUCE GROUP ]

### Campos

**AUTO REDUCE**
- OFF = somente REDUCE manual.
- ON = habilita o gatilho automático.

**MIN PROFIT**
Valor monetário mínimo necessário para liberar a redução automática.

**REDUCE LOTS**
Quantidade de lotes a reduzir quando a condição for atendida.

## 4. Fonte do lucro

O gatilho deve utilizar o resultado do CURRENT GROUP selecionado, e não o lucro aberto total da cesta.

Exemplo: cesta total +87.00, CURRENT GROUP +22.00, MIN PROFIT 20.00 → AUTO REDUCE permitido.

Se a cesta total estiver em +87.00, mas o CURRENT GROUP estiver em +14.00, com MIN PROFIT 20.00 → aguardar.

Isso mantém a decisão vinculada ao grupo que o operador selecionou.

## 5. Fluxo operacional

### AUTO REDUCE = OFF

O comportamento atual permanece: selecionar T1/T2 → CURRENT GROUP → operador analisa → REDUCE GROUP → execução existente.

### AUTO REDUCE = ON

Selecionar T1/T2 → construir CURRENT GROUP → monitorar resultado → RESULT >= MIN PROFIT? → revalidar seleção → revalidar TARGET → revalidar lote → executar REDUCE LOTS → atualizar CURRENT GROUP.

## 6. Regra de alvo

O Auto Reduce deve utilizar a mesma definição de TARGET já estabelecida para o CURRENT GROUP.

- Uma ordem selecionada → ela é TARGET.
- WIN + LOSS → LOSS é TARGET e WIN é REFERENCE.
- Dois WIN → menor lote é TARGET e maior lote é REFERENCE.
- Dois LOSS → T1 é TARGET e T2 é REFERENCE.

O Auto Reduce não deve criar uma nova regra de escolha de ordem.

## 7. Revalidação antes da execução

Antes de fechar qualquer lote automaticamente, o sistema deve revalidar:

1. CURRENT GROUP ainda válido.
2. TARGET ainda selecionado.
3. TARGET ainda aberto.
4. TARGET ainda pertence ao universo operacional.
5. Lote disponível ainda é suficiente.
6. REDUCE LOTS é válido e normalizável.
7. Resultado atual do grupo ainda atende MIN PROFIT.
8. Não existe outro disparo pendente para o mesmo estado do grupo.

A execução deve usar o mesmo mecanismo de fechamento parcial já existente.

## 8. Proteção contra disparos repetidos

O sistema não deve executar repetidamente uma redução cada vez que o lucro permanecer acima do limiar.

Estado recomendado: ARMED → PROFIT >= MIN PROFIT → EXECUTED → WAIT RESET.

O primeiro desenho recomendado é utilizar como reset uma mudança material do grupo: seleção limpa, TARGET alterado, TARGET encerrado ou CURRENT GROUP deixa de ser válido.

Não usar simplesmente o retorno do lucro abaixo do limiar como único reset, pois isso pode provocar múltiplos disparos quando o resultado oscilar ao redor do MIN PROFIT.

## 9. Estado recomendado

Conceitualmente: AutoReduceEnabled, AutoReduceMinProfit, AutoReduceLots, AutoReduceExecuted e AutoReduceGroupSignature.

A assinatura do grupo deve permitir identificar se o grupo que disparou a redução continua sendo o mesmo.

A implementação final deverá reutilizar as estruturas e convenções já existentes no SENTINEL sempre que possível, evitando duplicação de estado.

## 10. Segurança operacional

O Auto Reduce não deve selecionar ordens por conta própria, alterar TARGET, criar novas posições, executar RED, executar CLOSE ALL, substituir TAKE/STOP, alterar Entry Engine ou alterar a regra manual de REDUCE.

Ele somente poderá executar: GRUPO SELECIONADO + CONDIÇÃO DE LUCRO ATENDIDA → REDUZIR TARGET.

## 11. Relação com a arquitetura

MARKET CONTEXT + BASKET CONTEXT + CURRENT GROUP → DECISION ENGINE → HOLD / REDUCE / RED → ACTION PREVIEW → EXECUTION

O Auto Reduce deve ser tratado como uma política de decisão, e não como uma nova engine de execução.

## 12. Exemplo

Configuração: AUTO REDUCE = ON, MIN PROFIT = 20.00, REDUCE LOTS = 0.10.

Grupo: TARGET BUY 0.40, REFERENCE SELL 0.20, GROUP NET +0.20, EXPOSURE 0.60, RESULT +17.80.

Estado: AGUARDAR.

Quando RESULT = +20.35: confirmar grupo, TARGET e lote; executar 0.10; registrar o disparo; atualizar CURRENT GROUP; entrar em WAIT RESET.

Resultado esperado: TARGET BUY 0.30, REFERENCE SELL 0.20, EXPOSURE 0.50.

## 13. Critério para implementação

### Fase A — Interface
- AUTO REDUCE;
- MIN PROFIT;
- REDUCE LOTS.

### Fase B — Estado
Adicionar persistência/estado necessário sem interferir nas configurações atuais.

### Fase C — Decisão
Criar função dedicada, conceitualmente equivalente a EvaluateAutoReduce(), responsável por habilitação, CURRENT GROUP, resultado, MIN PROFIT e estado de disparo.

### Fase D — Execução
Reutilizar a função existente de REDUCE.

### Fase E — Proteção
Adicionar revalidação, anti-duplicação, reset do estado e mensagens de status.

### Fase F — Teste
1. AUTO OFF → comportamento atual intacto.
2. AUTO ON + lucro abaixo do mínimo → nenhuma ação.
3. AUTO ON + lucro no mínimo → redução.
4. TARGET alterado → novo grupo pode disparar.
5. TARGET fechado antes do disparo → nenhuma execução.
6. Lote solicitado maior que o disponível → normalização/rejeição segura.
7. Oscilação do lucro acima/abaixo do limiar → sem repetição indevida.
8. Troca de timeframe/reinicialização → estado persistente conforme definido.
9. Seleção limpa → Auto Reduce desarmado.

## 14. Decisão de arquitetura

**Aprovado para implementação futura.**

O Auto Reduce deve ser construído como uma camada de decisão sobre o CURRENT GROUP, compartilhando o executor de REDUCE existente.

Regra fundamental:

> Automatizar o momento da decisão, não duplicar a execução.