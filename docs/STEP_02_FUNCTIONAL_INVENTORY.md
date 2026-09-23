# SENTINEL — Passo 2: Inventário funcional

## Base analisada

Inventário elaborado a partir dos dois arquivos baseline fornecidos para o projeto:

- `SENTINEL.mq4` — 151 definições de função identificadas na análise estrutural.
- `SENTINEL_CESTA_MANAGER_v1_00.mq4` — 31 definições de função identificadas na análise estrutural.

> O inventário classifica responsabilidade; não altera a implementação. As classificações "sobreposição" indicam áreas que deverão ser comparadas na próxima etapa, não que as implementações sejam equivalentes.

## 1. SENTINEL.mq4

### A. Resultado diário / estado operacional
- `GetTodayRealizedProfit` — persistência/cálculo de resultado realizado do dia.
- `FormatMoney` — utilitário de apresentação monetária.
- `GetTodayTotalProfit` — agregação do resultado diário.
- `UpdateTodayRealizedPanel` — interface/painel do resultado diário.

### B. Entry Engine / contexto de mercado
- `GetLevelStepPoints` — cálculo auxiliar de distância de níveis.
- `EntryMA`, `EntryATR`, `EntryRSI` — leitura de indicadores para contexto de entrada.
- `EntryBBUpper`, `EntryBBMiddle`, `EntryBBLower` — leitura das Bandas de Bollinger.
- `EntryMABullSlope`, `EntryMABearSlope` — classificação de inclinação da média.
- `EntryATRReference` — referência de volatilidade.
- `EntryClassifyContext` — classificação do contexto de mercado.
- `EntryClampScore` — normalização do score.
- `EntryLastBuyPrice`, `EntryLastBuyTime` — estado da última entrada BUY.
- `EntrySpacingOK`, `EntryCooldownOK` — filtros de espaçamento e cooldown.
- `GetM5GateATRPoints`, `GetM5GateRequiredPoints` — gate de entrada M5.
- `GetLowestBuyOpenPriceEntry`, `GetHighestSellOpenPriceEntry` — extremos de preço da cesta para o gate.
- `IsM5BuyEntryAllowed`, `IsM5SellEntryAllowed` — decisão de permissão por lado.
- `UpdateM5EntryThreshold` — atualização do limiar M5.
- `CalculateEntryEngine` — orquestração do Entry Engine.
- `EntryActionColor` — representação visual da ação.
- `UpdateEntryEnginePanel` — interface do Entry Engine.

**Responsabilidade:** mercado/entrada. É uma camada distinta da gestão da cesta.

### C. Persistência / estado global
- `BasketGlobalName`
- `BasketReduceExcludedGlobalName`
- `TodayReduceExcludedGlobalName`
- `TargetPointsGlobalName`
- `StopPointsGlobalName`
- `SelectedLotsGlobalName`

Estas funções constroem chaves de estado persistente.

- `GetTodayReduceExcluded`, `AddReduceExcludedResult` — estado de resultado excluído da redução.
- `SavePanelSettingsToGlobals`, `LoadPanelSettingsFromGlobals` — persistência das configurações do painel.
- `SaveLevelPointsToGlobals`, `LoadLevelPointsFromGlobals`, `DeleteLevelPointsGlobals` — persistência dos níveis.

**Responsabilidade:** persistência/estado.

### D. Normalização e identificação de ordens
- `NormalizePrice`
- `LotStep`
- `MinLot`
- `MaxLot`
- `NormalizeLots`
- `IsOurOrder`

**Responsabilidade:** utilitário + filtro de universo operacional.

### E. Basket Core
- `GetBuyLots`
- `GetSellLots`
- `GetNetLots`
- `GetGrossLots`
- `CountOpenPositions`
- `GetHistoricalProfitTotal`
- `StartBasketIfNeeded`
- `EndBasketIfNeeded`
- `GetBasketRealized`
- `GetOpenProfit`
- `GetBasketTotal`
- `GetBuyAverageOpenPrice`
- `GetSellAverageOpenPrice`
- `GetProjectedBuyAverage`
- `GetProjectedSellAverage`
- `GetAverageOpenPrice`

**Responsabilidade:** CORE / cesta. Este é o núcleo mais importante para futura unificação com o CESTA MANAGER.

### F. Matemática de preço, lucro e níveis
- `PriceValuePerLot`
- `BasketProfitAtPrice`
- `AssetPoint`
- `PriceDistanceToPoints`
- `MoneyToAssetPoints`
- `LevelText`
- `OpenProfitAtPrice`
- `SolveOpenBreakevenPrice`
- `SolvePriceForProfit`

**Responsabilidade:** cálculo financeiro/geométrico da cesta.

### G. Objetos gráficos e níveis
- `CreateHLine`
- `CreatePriceText`
- `PriceToScreenY`
- `ClampBoxY`
- `CreatePriceBox`
- `UpdatePointer`
- `UpdateLevelLabel`
- `CreateDraggableHLine`
- `RemoveLegacyLevelObjects`
- `UpdateLevelPanelPrice`
- `LevelMoneyText`
- `UpdateTargetBox`
- `UpdateStopBox`
- `DeleteObjectSafe`
- `CreateSegmentHLine`
- `CreateProjectedSegmentHLine`
- `UpdateTradingReferenceLines`
- `UpdateTradingLevels`
- `UpdateChartProfitLabel`
- `UpdateTradingObjects`

**Responsabilidade:** interface gráfica/visualização operacional.

### H. Execução e redução
- `RebalanceSides` — execução/RED/reequilíbrio de lados.
- `CloseAllPositions` — execução de fechamento.
- `GetOurPositions` — seleção de ordens operacionais.
- `PartialCloseTicket` — execução de fechamento parcial.
- `PartialCloseAndCaptureResult` — execução + contabilização.
- `ReduceSideByResult` — redução seletiva por resultado.
- `ReduceSide` — redução por lado.
- `GetWinningLotsBySide` — cálculo de volume vencedor.
- `ReduceBothSides` — redução BUY + SELL.
- `BuildOrderComment` — metadado/comentário de execução.
- `ExecuteBuy`, `ExecuteSell` — execução de novas ordens.

**Responsabilidade:** execução.  
**Área crítica de sobreposição com o CESTA MANAGER:** `PartialCloseTicket`, `ReduceSideByResult`, `ReduceSide`, `GetWinningLotsBySide`, `ReduceBothSides`.

### I. Interface
- `PanelObjectX`, `PanelObjectY`, `EstimateLabelWidth`
- `CreatePanel`, `CreateLabel`, `UpdateLabel`
- `SetStatus`
- `MakeButtonNonSelectable`
- `RestoreReduceButtonColor`
- `ShowReduceButtonFeedback`
- `ResetButtonVisualState`, `ResetAllButtonVisualStates`
- `CreateButton`, `CreateEdit`
- `BuildInterface`
- `UpdateATRContextPanel`
- `UpdateReduceBothAvailability`
- `UpdateInterface`
- `ProcessLevelLineDrag`, `ProcessEdit`
- `AdjustTargetPoints`, `AdjustStopPoints`
- `GetSelectedLots`, `SetSelectedLots`, `AdjustLotsByStep`
- `ProcessButton`
- `OnChartEvent`

**Responsabilidade:** interface e controle do operador.

### J. Volatilidade / ATR
- `GetATRPoints`
- `GetATRReferencePoints`
- `GetATRRegime`
- `UpdateATRContextPanel`

**Responsabilidade:** contexto de mercado/risco visual. `UpdateATRContextPanel` também pertence à camada de interface.

### K. Auto-close / ciclo de vida
- `UpdateAutoCloseArming`
- `CheckAutoClose`
- `OnInit`
- `OnDeinit`
- `OnTick`
- `OnTimer`

**Responsabilidade:** ciclo de vida + automação operacional.

### L. Limpeza
- `DeleteAllSentinelObjects`
- `DeleteAllSentinelNamedObjects`

**Responsabilidade:** housekeeping da interface.

---

## 2. SENTINEL_CESTA_MANAGER_v1_00.mq4

### A. Seleção e normalização
- `TypeText` — apresentação do tipo.
- `IsSelectedMarketOrder` — filtro por símbolo, tipo e Magic.
- `OrderNetResult` — resultado líquido da ordem.
- `NormalizeLotsValue` — normalização de lote.
- `MoneyText`, `LotsText` — apresentação.

### B. Interface gráfica
- `DeleteObjectSafe`
- `CreateRectangle`
- `CreateLabel`
- `HideLabel`
- `GetCenteredPanelX`
- `CreateActionButton`
- `DeleteActionButton`
- `DeleteAllActionButtons`
- `DeletePanel`
- `CalculatePanelHeight`
- `RenderPanel`
- `OnChartEvent`
- `OnInit`, `OnDeinit`, `OnTimer`, `OnCalculate`

**Responsabilidade:** indicador visual/operacional.

### C. Seleção de vencedoras
- `CollectWinningOrders` — coleta ordens BUY/SELL vencedoras.
- `SortWinningOrders` — ordenação das vencedoras.
- `CalculateWinningLots` — volume vencedor.
- `CalculateReduceMax` — limite BxS pelo menor volume elegível.

**Responsabilidade:** CORE de seleção para redução.

### D. Redução
- `ReduceLots` — volume configurado para ação.
- `CloseWinningOrder` — **atenção:** apesar do cabeçalho declarar o indicador como somente leitura e dizer que a execução pertence ao SENTINEL, esta função implementa fechamento de ordem. Esta inconsistência deve ser verificada na próxima etapa.
- `ReduceBuySellPair` — rotina de redução BxS.

**Responsabilidade:** execução/gestão de redução.  
**Sobreposição direta com SENTINEL.**

---

# 3. Matriz de sobreposição

| Área | SENTINEL | CESTA MANAGER | Situação |
|---|---|---|---|
| Seleção de ordens | `GetOurPositions` | `IsSelectedMarketOrder` / `CollectWinningOrders` | Sobreposição |
| Resultado por ordem | `PartialCloseAndCaptureResult` / rotinas de redução | `OrderNetResult` | Sobreposição |
| Normalização de lotes | `NormalizeLots` | `NormalizeLotsValue` | Sobreposição direta |
| Ordens vencedoras | `GetWinningLotsBySide` | `CollectWinningOrders` | Sobreposição direta |
| Redução por lado | `ReduceSide` / `ReduceSideByResult` | seleção de vencedoras | Sobreposição |
| Redução BxS | `ReduceBothSides` | `CalculateReduceMax` / `ReduceBuySellPair` | Sobreposição direta |
| Fechamento parcial | `PartialCloseTicket` | `CloseWinningOrder` | Sobreposição direta |
| Interface | Painel completo | Painel especializado | Complementar |
| Entrada BUY/SELL | `ExecuteBuy` / `ExecuteSell` | Não possui | SENTINEL |
| RED/reequilíbrio | `RebalanceSides` | Não possui | SENTINEL |
| BE/TAKE/STOP | Possui | Não possui | SENTINEL |
| Entry Engine | Possui | Não possui | SENTINEL |
| ATR/contexto | Possui | Não possui | SENTINEL |
| Persistência | Possui | Não identificada | SENTINEL |
| Visualização de vencedoras | Possui parcialmente | Especializada | CESTA MANAGER |

## 4. Constatação arquitetural principal

O inventário confirma a hipótese do Passo 1:

**O maior ponto de sobreposição está na gestão de posições vencedoras e na redução parcial.**

O CESTA MANAGER não precisa ser eliminado. Sua função visual especializada é útil. O que precisa ser evitado é manter duas implementações independentes das regras de:

1. seleção da cesta;
2. identificação de vencedoras;
3. normalização de lote;
4. cálculo de redução;
5. fechamento parcial;
6. redução BxS.

A direção natural é um **Basket Core único**, consumido pelo SENTINEL e pela interface do CESTA MANAGER.

## 5. Núcleo comum candidato

A próxima arquitetura deverá avaliar a extração/consolidação destas responsabilidades:

```
Basket Core
├── IsOurOrder / seleção
├── BuyLots / SellLots
├── NetLots / GrossLots
├── Average / Projected Average
├── Open / Realized / Total
├── Winning Orders
├── Winning Lots
├── Normalize Lots
├── Partial Close
└── Reduce BxS
```

O `Entry Engine`, os níveis BE/TAKE/STOP e a interface geral permanecem fora deste núcleo.

## 6. Inconsistência encontrada para validação

O cabeçalho do `SENTINEL_CESTA_MANAGER_v1_00.mq4` declara:

> "Este indicador NAO envia, fecha ou modifica ordens. A execução continua sendo responsabilidade do SENTINEL EA."

Entretanto, o inventário estrutural identifica `CloseWinningOrder` e `ReduceBuySellPair` como rotinas de redução/fechamento.

Essa diferença entre documentação declarada e implementação deve ser validada diretamente no código antes de qualquer mudança.

## 7. Próximo passo

**Passo 3 — Reconciliação do Basket Core.**

Objetivo:

- comparar as implementações sobrepostas linha a linha;
- definir uma única fonte de verdade para seleção da cesta;
- definir uma única regra de normalização de lote;
- definir uma única representação de ordem vencedora;
- definir uma única interface para redução parcial;
- manter o CESTA MANAGER como interface especializada;
- não alterar ainda o comportamento do Entry Engine ou das regras de entrada.

