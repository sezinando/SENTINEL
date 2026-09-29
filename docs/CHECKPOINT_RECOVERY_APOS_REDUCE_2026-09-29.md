# SENTINEL — CHECKPOINT: RECOVERY APÓS REDUCE — 2026-09-29

Branch: feature/test-mode
Base: aee6f56b51464f729f77a5d6522edd8cae32a0a9

## Observação do teste
Após um REDUCE, permaneceu uma BUY 0.09 com aproximadamente -41.31 USD e uma SELL 0.06 com aproximadamente +30.00 USD. O preço caiu para cerca de 4147.72 enquanto a BUY reduzida estava perto de 4152.71.

## Diagnóstico do código atual
O Recovery NÃO usa o comentário da última ordem para escolher a referência do GRID.

RecoveryLastMarketOrder() escolhe a última ordem de mercado da direção pelo maior OrderOpenTime(), usando OrderTicket() como desempate.

A referência é:
- preço da última ordem;
- lote da última ordem;
- horário da última ordem.

O comentário RECOVERY BUY/SELL é usado para identificar pendências de Recovery, não para escolher a referência do GRID.

Com os parâmetros observados:
InpRecoveryTriggerDistance = 280 pontos
InpRecoveryStepDistance = 340 pontos
requiredDistance inicial = 620 pontos

No caso da imagem:
4152.71 - 4147.72 = aproximadamente 4.99 de preço = aproximadamente 499 pontos com Point=0.01.

Logo, 499 < 620 e a não abertura da nova Recovery é compatível com a regra atual.

## Ideia de melhoria a investigar
O REDUCE muda o lote residual, mas não muda o OrderOpenTime() nem o preço de abertura da posição. Assim, uma ordem parcialmente reduzida pode continuar sendo a referência temporal do Recovery mesmo após uma mudança relevante na estrutura econômica da cesta.

Pergunta de projeto para trabalhar posteriormente:

**Depois de um REDUCE, o Recovery deve continuar usando a ordem reduzida como referência do GRID ou deve reconhecer o REDUCE como mudança de estado e recalcular a referência do próximo nível?**

## Alternativas a estudar
A) manter o comportamento atual: última ordem de mercado por horário;
B) usar o último nível estrutural/econômico do GRID após REDUCE;
C) considerar estado da exposição residual, evento de REDUCE, direção, lote e distância atual.

Ainda NÃO implementar.

Antes de alterar o código:
1. reconstruir a sequência completa do teste;
2. registrar tickets, preços, lotes, horários e REDUCE;
3. calcular a distância do GRID em cada etapa;
4. definir matematicamente o comportamento esperado;
5. avaliar risco de o Recovery recriar automaticamente a exposição retirada pelo REDUCE;
6. somente então decidir a regra e implementar cirurgicamente.

## Regra de continuidade
Preservar o Recovery atual até a regra nova ser definida. Não fazer refactor amplo. Não alterar main.
