# STEP 03 — Seleção de Ordens para Redução Dirigida

## Checkpoint

Estado do projeto no início deste checkpoint:
- Branch: main
- HEAD: ce984f151bb713095b6d132574cf043fa4b09e90
- Código operacional atual não deve ser alterado nesta etapa.
- Esta etapa documenta a funcionalidade proposta; não implementa mudanças de execução.

## Objetivo

Permitir que o Cesta Manager seja utilizado para selecionar ordens específicas e que o SENTINEL receba esses tickets para apresentar, validar e executar uma redução dirigida de exposição.

A seleção deve identificar explicitamente os tickets das ordens selecionadas.

## Fluxo proposto

1. O operador seleciona uma ou duas ordens no Cesta Manager.
2. Cada ordem selecionada fornece seu ticket ao SENTINEL.
3. O SENTINEL apresenta os tickets selecionados em seu painel.
4. O operador informa no campo Lote quanto de exposição deseja reduzir.
5. O SENTINEL calcula previamente o efeito da operação.
6. O painel apresenta de forma explícita:
   - ticket;
   - BUY/SELL;
   - lote atual;
   - resultado atual;
   - lote solicitado para redução;
   - lote após redução;
   - exposição antes;
   - exposição depois;
   - NET antes/depois;
   - GROSS antes/depois.
7. Somente após a confirmação a execução é realizada pelo SENTINEL.

## Princípio arquitetural

O Cesta Manager deve atuar como mecanismo de seleção.

O SENTINEL permanece como autoridade de:
- validação;
- cálculo;
- preview;
- execução;
- partial close;
- fechamento total quando aplicável;
- tratamento de erros.

Não criar uma segunda lógica de execução independente no Cesta Manager.

## Caso 1 — Redução parcial de uma ordem vencedora

Exemplo:

BUY #101 = 0.02  
BUY #102 = 0.04

Redução solicitada = 0.01

A ordem de maior lote pode continuar aberta:

BUY #102: 0.04 -> 0.03

Exposição:
- antes: 0.06
- depois: 0.05

Se o lote solicitado for igual ao lote da ordem alvo, a ordem é fechada integralmente.

Se for menor, é realizado partial close.

## Caso 2 — Operação BxS dirigida

Exemplo:

BUY #101 = 0.04, perdedora  
SELL #102 = 0.02, vencedora

Redução solicitada = 0.01

A intenção é utilizar a ordem vencedora como parte da seleção/estrutura da operação e reduzir a exposição da ordem perdedora:

BUY #101: 0.04 -> 0.03  
SELL #102: 0.02 -> 0.02

A ordem vencedora permanece aberta.

A operação deve ser explicitamente apresentada no painel antes da execução.

## Requisitos do painel SENTINEL

Adicionar, em etapa posterior de implementação:

### Seleção
- Ticket 1
- Ticket 2
- tipo BUY/SELL
- lote atual
- resultado

### Parâmetro
- campo Lote

### Preview
- redução solicitada
- ordem que será reduzida
- lote atual
- lote restante
- exposição total antes/depois
- NET antes/depois
- GROSS antes/depois

### Execução
- botão específico para a operação selecionada, sem alterar o comportamento dos comandos atuais.

## Regras de segurança propostas

Antes da execução, o SENTINEL deve:
1. confirmar que o ticket ainda existe;
2. confirmar que a ordem está aberta;
3. confirmar que o ticket continua sendo do conjunto administrado pelo SENTINEL;
4. confirmar BUY/SELL e lote atual;
5. validar o lote solicitado contra min lot, lot step e lote disponível;
6. impedir redução maior que o lote existente;
7. recalcular o preview imediatamente antes da execução;
8. executar somente os tickets explicitamente selecionados.

## Compatibilidade

A primeira implementação deve ser incremental.

Os comandos atuais do SENTINEL permanecem inalterados.

A nova capacidade deve ser introduzida como uma operação separada de redução dirigida/selecionada.

## Decisões ainda pendentes

Antes da implementação, definir:
- se dois tickets serão obrigatórios para BxS ou se uma seleção unitária também poderá usar a operação;
- como o operador identifica qual ticket é a ordem alvo e qual é a referência;
- nomes finais dos botões;
- se a seleção permanece após a execução ou é limpa;
- se haverá REDUCE WIN, REDUCE LOSS e REDUCE BxS como operações distintas;
- comportamento quando o lote informado exceder a posição alvo;
- comportamento quando uma das ordens selecionadas desaparecer antes da execução.

## Estado

**CHECKPOINT 03 — ESPECIFICAÇÃO FUNCIONAL INICIAL**

Status: documentado, não implementado.

Próxima etapa: fechar as regras de seleção, target/reference e operações REDUCE antes de alterar o código.
