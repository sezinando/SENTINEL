# STEP 04 — Implementação: Seleção de Tickets e Redução Dirigida

## Checkpoint de implementação

Implementação inicial concluída no branch `main`.

Commits de implementação:
- `281846f51713e6c56abf18f1e22e021d378e55dc` — seleção de tickets no Cesta Manager
- `1b1384ccd1fd0aaff3e371aa7fe6de51c63632a4` — preservação do filtro de perdedoras fora do modo seleção
- `92249f6fd091155a41296398ea3181cad3ee3ff8` — integração da redução selecionada no SENTINEL
- `e31597d3392ac2fa83d83f6ad0a96c3358ffbd4e` — fallback de seleção genérica e referência explícita

## O que foi implementado

### Cesta Manager

Quando `InpSelectionEnabled=true`:

- os botões das ordens passam a selecionar/deselecionar tickets;
- até dois tickets podem ser mantidos na seleção;
- a seleção é armazenada em Global Variables do terminal;
- a seleção é compartilhada com o SENTINEL;
- ordens vencedoras e perdedoras ficam disponíveis para seleção;
- uma ordem selecionada recebe indicação visual `[SEL]`;
- o Cesta Manager não executa fechamento quando o modo seleção está ativo.

O comportamento antigo de execução continua disponível se `InpSelectionEnabled=false`.

### SENTINEL

O painel recebeu:

- campo T1 para o primeiro ticket;
- campo T2 para o segundo ticket;
- botão LIMPAR;
- preview do alvo;
- referência da segunda ordem;
- cálculo explícito de redução;
- cálculo NET antes/depois;
- cálculo de EXPOSIÇÃO antes/depois;
- botão REDUCE para a seleção.

Os campos T1/T2 são somente leitura e refletem a seleção realizada no Cesta Manager.

## Regras atuais da redução dirigida

### Uma ordem selecionada

A ordem selecionada é o alvo.

`Lote` define quanto será reduzido.

### Duas ordens — uma WIN e uma LOSS

A LOSS é o alvo.

A WIN é mostrada como referência.

A WIN permanece aberta.

### Duas ordens WIN

A ordem com menor lote é o alvo.

A ordem com maior lote permanece aberta como referência.

Isso atende ao caso:

`BUY 0.02 + BUY 0.04`

com `Lote=0.01`:

`BUY 0.02 -> 0.01`

`BUY 0.04 -> 0.04`

Exposição:

`0.06 -> 0.05`

### Duas ordens LOSS

A operação é considerada inválida nesta primeira versão.

## Execução

A execução continua centralizada no SENTINEL.

O SENTINEL:
1. relê os tickets;
2. valida se continuam abertos;
3. valida se pertencem ao conjunto administrado;
4. limita a redução ao lote disponível;
5. normaliza o lote;
6. usa o mecanismo de `PartialCloseTicket()`;
7. limpa a seleção após uma execução bem-sucedida.

O fechamento parcial usa `OrderClose(ticket,lots,...)`, portanto uma ordem permanece aberta quando o lote solicitado é menor que seu volume atual.

## Comunicação

A comunicação Cesta Manager -> SENTINEL usa Global Variables do terminal, que são acessíveis simultaneamente pelos programas MQL4 executados no mesmo terminal.

A chave é isolada por símbolo e Magic Number.

Existe fallback para seleção publicada pelo Cesta Manager com Magic Number `-1`.

## Auditoria estrutural

Foi feita uma verificação automática dos dois arquivos após a implementação:

- `SENTINEL.mq4`: chaves balanceadas;
- `SENTINEL_CESTA_MANAGER_v1_00.mq4`: chaves balanceadas;
- não foram encontrados nomes de funções duplicados no Cesta Manager;
- no SENTINEL, a única ocorrência duplicada identificada foi a declaração antecipada existente de `GetTodayTotalProfit()`, não uma segunda implementação.

## Teste necessário no MetaEditor

Antes de considerar a funcionalidade operacionalmente validada:

1. compilar `SENTINEL.mq4`;
2. compilar `SENTINEL_CESTA_MANAGER_v1_00.mq4`;
3. executar em DEMO;
4. abrir duas ordens BUY vencedoras com lotes diferentes;
5. selecionar as duas no Cesta Manager;
6. confirmar T1/T2 no SENTINEL;
7. informar Lote=0.01;
8. confirmar o preview `NET/EXPOSIÇÃO`;
9. executar REDUCE;
10. verificar que somente o ticket alvo foi parcialmente reduzido;
11. repetir com WIN + LOSS em lados opostos;
12. repetir com uma seleção inválida de duas LOSS.

## Estado

**IMPLEMENTAÇÃO INICIAL CONCLUÍDA — AGUARDANDO COMPILAÇÃO/TESTE NO MT4.**

Nenhuma alteração foi feita na lógica dos comandos tradicionais de BUY, SELL, REDUCE BUY/SELL, REDUCE BxS, CLOSE ALL ou RED, além da adição do novo caminho de REDUCE SELECIONADO.
