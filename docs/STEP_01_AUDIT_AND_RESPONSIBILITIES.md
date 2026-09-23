# SENTINEL — Passo 1: Auditoria e definição de responsabilidades

## Objetivo

Estabelecer uma base arquitetural para a evolução conjunta dos dois componentes atuais:

- `SENTINEL.mq4`
- `SENTINEL_CESTA_MANAGER_v1_00.mq4`

Este documento registra a intenção do projeto antes de alterações funcionais. Nenhuma mudança de lógica de execução é autorizada por este passo.

## Baseline

Os dois arquivos usados nesta etapa são os arquivos fornecidos como baseline para a análise:

- `SENTINEL.mq4`: painel/EA operacional principal.
- `SENTINEL_CESTA_MANAGER_v1_00.mq4`: ferramenta especializada de gerenciamento seletivo de posições vencedoras da cesta.

## Responsabilidades identificadas

### SENTINEL

O componente principal concentra a operação da cesta e a interface operacional. A evolução deverá preservar sua função como ponto central para:

- visualização da cesta;
- exposição e resultado;
- operações BUY/SELL;
- RED/lock;
- redução e fechamento;
- níveis operacionais como preço médio, BE, TAKE e STOP;
- lógica de entrada/contexto já existente;
- execução das ações solicitadas pelo operador.

### CESTA MANAGER

O componente especializado deve permanecer focado em gestão seletiva da cesta, especialmente:

- identificação de ordens vencedoras;
- seleção e ordenação dessas ordens;
- redução parcial;
- combinação de redução BUY + SELL (BxS);
- visualização operacional das posições elegíveis.

A intenção arquitetural é evitar que o CESTA MANAGER se torne um segundo núcleo de execução com regras divergentes do SENTINEL.

## Problema arquitetural a investigar

Os dois componentes possuem responsabilidades relacionadas à redução parcial e à seleção de posições. Antes de adicionar recursos, será necessário identificar e eliminar divergências entre:

- cálculo de lotes elegíveis;
- seleção de posições vencedoras;
- fechamento parcial;
- redução por lado;
- redução simultânea de lados;
- tratamento de resultado e estado da cesta.

Não haverá consolidação automática neste passo. A primeira meta é mapear a responsabilidade efetiva de cada função.

## Direção proposta

A arquitetura alvo será organizada conceitualmente em quatro camadas:

```
SENTINEL
  ├── Operação / Interface
  ├── Contexto de Mercado
  └── Gestão da Cesta
         ├── Snapshot da cesta
         ├── Exposição
         ├── Vencedoras / perdedoras
         └── Ações de redução
```

O CESTA MANAGER deverá evoluir para uma interface especializada sobre a mesma visão de cesta, e não para uma lógica operacional independente.

## Princípio de segurança da evolução

Durante a refatoração:

1. preservar o comportamento operacional existente;
2. não modificar a lógica do Zeus;
3. não adicionar automação de entrada ou saída sem especificação explícita;
4. centralizar responsabilidades antes de adicionar complexidade;
5. manter alterações pequenas, rastreáveis e compiláveis.

## Próxima etapa

**Passo 2 — Inventário funcional:** levantar função por função dos dois arquivos, classificando cada uma como:

- CORE / cesta;
- execução;
- cálculo;
- interface;
- mercado/entrada;
- persistência;
- utilitário;
- duplicada/sobreposta.

O resultado será a matriz de responsabilidades usada para definir o núcleo comum da próxima versão.
