# SENTINEL — CHECKPOINT 2026-09-29

## Estado
Repositorio: sezinando/SENTINEL
Branch: feature/test-mode
Estagio: INTEGRACAO / VALIDACAO FUNCIONAL

## Arquitetura consolidada
- src/SENTINEL.mq4 = execução, plano econômico, REDUCE, AUTO REDUCE, recovery, TAKE/STOP e consumo das seleções.
- src/SENTINEL_CESTA_MANAGER_v1_00.mq4 = interface visual, descoberta/listagem, seleção T1/T2/T3 e solicitação de REDUCE.
- CESTA_MANAGER não executa ordens; publica seleção/ação via Global Variables.
- SENTINEL continua sendo a autoridade de execução.

## Seleção econômica
T1 = LOSS alvo de redução.
T2 = WIN crédito.
T3 = WIN crédito adicional.
A classificação não depende da ordem dos cliques.
Resultado = OrderProfit + OrderSwap + OrderCommission.
LOSS ocupa T1; WIN ocupa T2/T3; neutra não participa; segunda LOSS não é aceita.
Isso corrigiu o problema em que a ordem do clique alterava o papel econômico.

## Plano WIN + LOSS
- T1 LOSS pode ser reduzida usando crédito das WINs.
- Crédito necessário = |perda realizada| + MIN_PROFIT.
- T2 é consumida primeiro; T3 somente se necessário.
- Entre T2/T3, a maior WIN é consumida primeiro.
- O cálculo é proporcional ao lote efetivamente fechado.
- Todas as ordens são validadas antes da execução.
- Execução: WIN crédito -> WIN adicional se necessário -> LOSS.
- Após execução, seleção é limpa.

## REDUCE isolado — funcionalidade em desenvolvimento final
Nova regra solicitada:
- uma WIN isolada pode ser selecionada e reduzida;
- uma LOSS isolada também pode ser selecionada e reduzida;
- não exige outra operação como crédito;
- LOT do SENTINEL controla o volume;
- LOT menor que a posição = parcial;
- LOT igual/maior que a posição = total;
- execução continua no SENTINEL via PartialCloseTicket().

O CESTA_MANAGER possui GetSingleSelectedTicket() para detectar uma seleção única, independentemente de WIN/LOSS, e exibe REDUCE SELECIONADO.

## Últimos commits
0aa7f19cde12504f1446ee91084292cfa9de32a0
feat: allow direct reduce for single win or loss

90373781b493e612aa01740a0aaf5b29ac06854f
fix: route single reduce in tester mode

## Erro reportado pelo usuário
MetaEditor reportou:
'GetSingleSelectedWinningTicket' - function not defined
'singleSelectedTicket' - undeclared identifier

O estado atual do arquivo no branch já usa GetSingleSelectedTicket(), não GetSingleSelectedWinningTicket(). Portanto, antes de nova alteração, COMPILAR o arquivo atual/sincronizado com o branch. Se o erro antigo persistir, verificar cópia local desatualizada.

## Visual já validado
- Ordens positivas recebem borda azul.
- Borda visual usa quatro segmentos independentes para permitir espessura perceptível.
- T1/REDUCE = vermelho.
- T2/T3/CREDIT = verde.
- Configuração visual permanece no CESTA_MANAGER.
Não mover para SENTINEL sem solicitação.

Inputs visuais relevantes:
InpPositiveBorderColor
InpPositiveBorderWidth
InpReduceSelectionColor
InpCreditSelectionColor

## TAKE / STOP
Estabilizado e confirmado pelo usuário.
Linhas TAKE/STOP/BE permanecem visíveis em Test Mode.
Criação usa BACK=false, HIDDEN=false e z-order elevado.
Valores persistem por Global Variables.
NÃO alterar sem solicitação explícita.

## Strategy Tester
Existe ponte por Global Variables:
SENTINEL_TEST_ORDER_<SYMBOL>_
Publica ticket, tipo, magic, lote, resultado, preço de abertura e horário.
CESTA_MANAGER lê essa ponte no Tester Visual.

## Histórico relevante
9a99955233a16128fa7c483be01266a3991ad54d — enable third cesta selection
e3578c2725a13ff9db38c0a33aad2a0a6aaf8dc8 — accept third cesta selection
7177d709fcc3da2daaf7a695eb73cfb1d3bab075 — show selected cesta orders
074d77edf199be4869963028d7d14e386e855541 — define live cesta selection limit
5e61952f7485b5473de0e90e06d4d9e1b12210d8 — decouple visual markers from magic
d395c7e0b1d17f0cacced15847104a47c4b55ff3 — deterministic selection marker
344cb411ed9b76376147defe7c30181c22f328e5 — selection marker before basket filter
05381b34737346a1824545618d35c740e75c2a96 — restore dashed selection lines
235659714b09f526051756d02622c726fcc3cc0f — distinguish reduction/credit orders
dcfc3ff2a2a081a72f5597efe741c9c28de7be59 — highlight positive orders
024dce280e49cb5d896c2e0d93d8c45969a5f649 — strengthen positive border
0f74b43d44010f69fb49443932f3e91f3307d469 — expose border settings
50dbcddc3f93f1f62e39330c54b05ca801761e49 — keep border styling in manager
065293ff4f2ba6e40b54c57f32b7d921c19fc24b — distinguish reduce/credit selections
cabb9b9f861a05e701405af6e17c6409304b5e0a — visible winner border
2f3c9b55bb5890618a51805cae5cb0a080b8eae9 — publish selections by economic role
13241fc5158e2fe8d18986d3ea47ec2d0c5ed6bd — keep TAKE/STOP visible in test mode
0aa7f19cde12504f1446ee91084292cfa9de32a0 — direct reduce single WIN/LOSS
90373781b493e612aa01740a0aaf5b29ac06854f — route single reduce in tester

## Próximo roteiro obrigatório
1. Compilar feature/test-mode.
2. Corrigir somente erros concretos de compilação.
3. Testar WIN isolada.
4. Testar LOSS isolada.
5. Testar redução parcial.
6. Testar redução total.
7. Testar LOSS + WIN.
8. Testar LOSS + WIN + WIN.
9. Testar no Strategy Tester Visual.
10. Só depois avançar para nova funcionalidade.

## Matriz mínima
WIN isolada -> REDUCE disponível
LOSS isolada -> REDUCE disponível
LOT menor -> parcial
LOT >= posição -> total
LOSS + WIN -> plano econômico
LOSS + WIN + WIN -> crédito duplo
WIN + WIN sem LOSS -> sem plano LOSS
duas LOSS -> não permitido
neutra -> não participa
TAKE/STOP -> preservar
Test Mode -> preservar

## Regra para continuidade
Não fazer refactor amplo. Trabalhar cirurgicamente. Não alterar main durante esta fase. Preservar o que já está funcionando. Sempre compilar antes de introduzir nova funcionalidade.
