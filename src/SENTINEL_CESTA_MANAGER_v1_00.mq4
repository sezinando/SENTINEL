//+------------------------------------------------------------------+
//| SENTINEL_CESTA_MANAGER_v1_00.mq4                                 |
//| Gestor visual da cesta - somente leitura                         |
//|                                                                  |
//| Funcao:                                                          |
//|  - Ler ordens abertas do simbolo                                 |
//|  - Filtrar por Magic Number                                      |
//|  - Mostrar somente ordens vencedoras                             |
//|  - Separar BUY / SELL                                            |
//|  - Calcular REDUCE MAX = menor volume vencedor entre os lados    |
//|  - Mostrar resumo da cesta                                       |
//|                                                                  |
//| IMPORTANTE:                                                      |
//|  Este indicador NAO envia, fecha ou modifica ordens.              |
//|  A execucao continua sendo responsabilidade do SENTINEL EA.       |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property version "3.13"

//====================================================================
// INPUTS
//====================================================================

input int      InpMagicNumber       = -1;
input bool     InpAnyMagic          = false;

// Referencia para o teste de posicionamento.
input ENUM_BASE_CORNER InpCorner    = CORNER_LEFT_UPPER;

// Posicao X do painel. Nesta versao o painel fica centralizado.
input int      InpPanelX            = 420;
double gPanelX=420;

// Coordenada Y do painel.
input int      InpPanelY            = 280;
input int      InpPanelWidth        = 300;

input bool     InpShowPanel         = true;
input bool     InpShowOrderTickets  = false;
input bool     InpShowLosing        = false;
input bool     InpSelectionEnabled  = true;
input bool     InpTestMode          = false;
input int      InpSelectionMax      = 3;
input bool     InpShowSummary       = true;

input color    InpPanelBorder       = clrSlateGray;
input color    InpPanelBackground   = C'45,45,45';
input color    InpTitleColor        = clrWhite;
input color    InpBuyColor          = clrLimeGreen;
input color    InpSellColor         = clrTomato;
input color    InpPositiveColor     = clrLime;
input color    InpNegativeColor     = clrRed;
input color    InpNeutralColor      = clrSilver;
input color    InpReduceColor       = clrGold;

input int      InpTitleSize         = 11;
input int      InpTextSize          = 10;
input int      InpSummarySize       = 10;

input int      InpRefreshSeconds    = 1;
input double   InpReduceLots        = 0.02;
input int      InpButtonWidth       = 110;
input int      InpButtonHeight      = 22;

//====================================================================
// AJUSTES VISUAIS DO PAINEL
//====================================================================

// Posicao horizontal do conjunto.
// Aumente/diminua para deslocar o painel para a direita/esquerda.
input int      InpPanelXOffset      = 0;

// Posicao vertical do conjunto.

// Distancia entre as duas colunas.
input int      InpColumnGap         = 18;

// Distancia entre cabecalho e primeira ordem.
input int      InpRowsTopGap        = 28;

// Cores das colunas.
input color    InpBuyTextColor      = clrLime;
input color    InpSellTextColor     = clrRed;

// Cores dos botoes.
input color    InpBuyButtonColor    = clrLime;
input color    InpSellButtonColor   = clrTomato;
input color    InpButtonTextColor   = clrBlack;

// Configuracao visual das bordas das ordens.
input color    InpPositiveBorderColor = clrDodgerBlue;
input int      InpPositiveBorderWidth = 2;
input color    InpNeutralBorderColor  = clrDimGray;
input int      InpNeutralBorderWidth  = 1;

// Cor do botao REDUCE BxS.
input color    InpReduceButtonColor = clrGold;
input color    InpReduceTextColor   = clrBlack;
// Cores da selecao operacional:
// T1 = ordem que sera reduzida.
// T2/T3 = ordens que fornecem credito.
input color    InpReduceSelectionColor = clrRed;
input color    InpCreditSelectionColor = clrLimeGreen;
input color    InpSelectedButtonColor = clrGold;


//====================================================================
// PREFIXOS
//====================================================================

string PREFIX = "SCM_";
string SelectionGlobalPrefix()
{
   return "SENTINEL_SELECTED_"+Symbol()+"_"+IntegerToString(InpMagicNumber)+"_";
}

string SelectionGenericPrefix()
{
   return "SENTINEL_SELECTED_"+Symbol()+"_-1_";
}

string SelectionGlobalName(int slot)
{
   return SelectionGlobalPrefix()+IntegerToString(slot);
}

string SelectionGenericName(int slot)
{
   return SelectionGenericPrefix()+IntegerToString(slot);
}

// Acao solicitada pelo CESTA MANAGER ao SENTINEL.
// O fechamento continua sendo executado pelo EA, preservando a
// separacao entre interface e execucao de ordens.
string SelectedActionGlobalName()
{
   return "SENTINEL_SELECTED_ACTION_"+
          Symbol()+"_"+
          IntegerToString(InpMagicNumber);
}

string SelectedActionGenericName()
{
   return "SENTINEL_SELECTED_ACTION_"+
          Symbol()+"_-1";
}

void RequestSelectedReduction()
{
   GlobalVariableSet(SelectedActionGlobalName(),1.0);
   GlobalVariableSet(SelectedActionGenericName(),1.0);
   GlobalVariablesFlush();
}

int GetSelectedTicket(int slot)
{
   int maxSlot=MathMin(3,MathMax(1,InpSelectionMax));

   if(slot<1 || slot>maxSlot)
      return -1;

   string name=SelectionGlobalName(slot);

   if(!GlobalVariableCheck(name))
      return -1;

   int ticket=(int)GlobalVariableGet(name);

   if(ticket<=0)
      return -1;

   return ticket;
}

int FindSelectedSlot(int ticket)
{
   if(ticket<=0)
      return 0;

   if(GetSelectedTicket(1)==ticket)
      return 1;

   if(GetSelectedTicket(2)==ticket)
      return 2;

   if(GetSelectedTicket(3)==ticket)
      return 3;

   return 0;
}

// Retorna a unica ordem selecionada quando ela esta positiva.
// Esse caso habilita REDUCE direto sem exigir uma LOSS ou outra WIN.
int GetSingleSelectedWinningTicket()
{
   int selectedCount=0;
   int winningTicket=-1;

   for(int slot=1;slot<=3;slot++)
   {
      int ticket=GetSelectedTicket(slot);

      if(ticket<=0)
         continue;

      selectedCount++;

      if(GetSelectionOrderResult(ticket)>0.00000001)
         winningTicket=ticket;
   }

   if(selectedCount==1 && winningTicket>0)
      return winningTicket;

   return -1;
}

// Remove uma selecao de um slot e elimina as Global Variables.
// Diferente de escrever 0.0, GlobalVariableDel() realmente limpa o
// registro persistente e evita acumulo de variaveis vazias.
void DeleteSelectionSlot(int slot)
{
   if(slot<1 || slot>3)
      return;

   GlobalVariableDel(SelectionGlobalName(slot));
   GlobalVariableDel(SelectionGenericName(slot));
}

// Valida as selecoes persistidas contra as ordens atualmente abertas.
// Se uma ordem foi fechada, o ticket deixa de ser valido e a selecao
// e removida automaticamente. Se T1 estiver vazio e T2 ainda valido,
// compacta T2 para T1 para manter a selecao utilizavel.
bool ReconcileSelection()
{
   if(!InpSelectionEnabled)
      return false;

   int t1=GetSelectedTicket(1);
   int t2=GetSelectedTicket(2);
   int t3=GetSelectedTicket(3);

   bool changed=false;

   // Valida T1.
   if(t1>0)
   {
      bool valid1=false;

      if(IsTesting())
         valid1=IsTesterBridgeTicketOpen(t1);
      else
      if(OrderSelect(t1,SELECT_BY_TICKET,MODE_TRADES))
         valid1=IsSelectedMarketOrder();

      if(!valid1)
      {
         DeleteSelectionSlot(1);
         t1=-1;
         changed=true;
      }
   }

   // Valida T2.
   if(t2>0)
   {
      bool valid2=false;

      if(IsTesting())
         valid2=IsTesterBridgeTicketOpen(t2);
      else
      if(OrderSelect(t2,SELECT_BY_TICKET,MODE_TRADES))
         valid2=IsSelectedMarketOrder();

      if(!valid2)
      {
         DeleteSelectionSlot(2);
         t2=-1;
         changed=true;
      }
   }

   if(t3>0)
   {
      bool valid3=false;
      if(IsTesting())
         valid3=IsTesterBridgeTicketOpen(t3);
      else
      if(OrderSelect(t3,SELECT_BY_TICKET,MODE_TRADES))
         valid3=IsSelectedMarketOrder();

      if(!valid3)
      {
         DeleteSelectionSlot(3);
         t3=-1;
         changed=true;
      }
   }

   // A selecao possui semantica fixa:
   // T1 = LOSS a reduzir.
   // T2/T3 = WINs de credito.
   // Portanto, uma WIN nunca deve ser compactada para T1.
   if(t1<=0 && t2>0 &&
      GetSelectionOrderResult(t2)<-0.00000001)
   {
      GlobalVariableSet(
         SelectionGlobalName(1),
         t2
      );

      GlobalVariableSet(
         SelectionGenericName(1),
         t2
      );

      DeleteSelectionSlot(2);
      changed=true;
   }

   if(changed)
      GlobalVariablesFlush();

   return changed;
}

int SelectionCount()
{
   ReconcileSelection();

   int count=0;

   if(GetSelectedTicket(1)>0)
      count++;

   if(GetSelectedTicket(2)>0)
      count++;

   if(GetSelectedTicket(3)>0)
      count++;

   return count;
}

void ClearSelectedTickets()
{
   DeleteSelectionSlot(1);
   DeleteSelectionSlot(2);
   DeleteSelectionSlot(3);
   GlobalVariablesFlush();
}

double GetSelectionOrderResult(int ticket)
{
   if(ticket<=0)
      return 0.0;

   if(IsTesting())
   {
      int count=TesterBridgeCount();

      for(int i=0;i<count;i++)
      {
         int t=0,type=0,magic=0;
         double lots=0.0,result=0.0,openPrice=0.0;
         datetime openTime=0;

         if(!GetTesterBridgeOrder(
            i,t,type,magic,lots,result,openPrice,openTime))
            continue;

         if(t==ticket)
            return result;
      }

      return 0.0;
   }

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return 0.0;

   if(!IsSelectedMarketOrder())
      return 0.0;

   return OrderNetResult();
}

void ToggleSelectedTicket(int ticket)
{
   // Antes de aceitar uma nova selecao, elimina tickets que ja nao
   // representam ordens abertas.
   ReconcileSelection();

   if(!InpSelectionEnabled || ticket<=0)
      return;

   int slot=FindSelectedSlot(ticket);

   if(slot>0)
   {
      DeleteSelectionSlot(slot);
      GlobalVariablesFlush();
      return;
   }

   int count=SelectionCount();

   int maxSelection=MathMin(3,MathMax(1,InpSelectionMax));

   if(count>=maxSelection)
      return;

   // A ordem de clique nao define o papel economico.
   // LOSS -> T1 (ordem que sera reduzida).
   // WIN  -> T2/T3 (ordens que fornecem credito).
   double selectedResult=GetSelectionOrderResult(ticket);

   int targetSlot=0;

   if(selectedResult<-0.00000001)
   {
      // Existe apenas uma LOSS permitida no plano.
      if(GetSelectedTicket(1)>0)
         return;

      targetSlot=1;
   }
   else
   if(selectedResult>0.00000001)
   {
      if(GetSelectedTicket(2)<=0)
         targetSlot=2;
      else
      if(maxSelection>=3 && GetSelectedTicket(3)<=0)
         targetSlot=3;
      else
         return;
   }
   else
   {
      // Resultado neutro nao participa do plano WIN + LOSS.
      return;
   }

   GlobalVariableSet(
      SelectionGlobalName(targetSlot),
      ticket
   );

   // Publica tambem uma selecao generica por simbolo.
   // O SENTINEL valida depois se o ticket pertence a sua cesta.
   GlobalVariableSet(
      SelectionGenericName(targetSlot),
      ticket
   );

   GlobalVariablesFlush();
}

bool IsSelectedTicket(int ticket)
{
   return FindSelectedSlot(ticket)>0;
}

void SetStatusSelectionHint()
{
   int t1=GetSelectedTicket(1);
   int t2=GetSelectedTicket(2);

   if(t1>0 && t2>0)
   {
      double r1=0.0;
      double r2=0.0;

      if(OrderSelect(t1,SELECT_BY_TICKET,MODE_TRADES))
         r1=OrderNetResult();

      if(OrderSelect(t2,SELECT_BY_TICKET,MODE_TRADES))
         r2=OrderNetResult();

      if(r1>0.00000001 && r2>0.00000001)
      {
         Print(
            "SENTINEL CESTA MANAGER: "
            "T1/T2 publicados como CREDITO. "
            "CREDITO="+DoubleToString(r1+r2,2)
         );
         return;
      }
   }

   Print("SENTINEL CESTA MANAGER: selecao enviada ao SENTINEL.");
}


//====================================================================
// ESTRUTURA
//====================================================================

struct WinningOrder
{
   int      ticket;
   int      type;
   double   lots;
   double   result;
   double   openPrice;
   double   currentPrice;
   datetime openTime;
};

//====================================================================
// PONTE TESTER - ORDENS PUBLICADAS PELO SENTINEL
//====================================================================

string TesterOrderBridgePrefix()
{
   return "SENTINEL_TEST_ORDER_"+Symbol()+"_";
}

int TesterBridgeCount()
{
   string name=TesterOrderBridgePrefix()+"COUNT";
   if(!GlobalVariableCheck(name))
      return 0;

   int count=(int)GlobalVariableGet(name);
   if(count<0) count=0;
   if(count>100) count=100;
   return count;
}

bool GetTesterBridgeOrder(
   int index,
   int &ticket,
   int &type,
   int &magic,
   double &lots,
   double &result,
   double &openPrice,
   datetime &openTime)
{
   string base=TesterOrderBridgePrefix()+IntegerToString(index)+"_";

   if(!GlobalVariableCheck(base+"ACTIVE") ||
      GlobalVariableGet(base+"ACTIVE")<0.5)
      return false;

   ticket=(int)GlobalVariableGet(base+"TICKET");
   type=(int)GlobalVariableGet(base+"TYPE");
   magic=(int)GlobalVariableGet(base+"MAGIC");
   lots=GlobalVariableGet(base+"LOTS");
   result=GlobalVariableGet(base+"RESULT");
   openPrice=GlobalVariableGet(base+"OPENPRICE");
   openTime=(datetime)GlobalVariableGet(base+"OPENTIME");

   return (ticket>0 && (type==OP_BUY || type==OP_SELL));
}

bool IsTesterBridgeTicketOpen(int ticket)
{
   if(ticket<=0)
      return false;

   int count=TesterBridgeCount();
   for(int i=0;i<count;i++)
   {
      int t=0,type=0,magic=0;
      double lots=0.0,result=0.0,openPrice=0.0;
      datetime openTime=0;

      if(!GetTesterBridgeOrder(i,t,type,magic,lots,result,openPrice,openTime))
         continue;

      if(t==ticket)
         return true;
   }

   return false;
}

//====================================================================
// UTILITARIOS
//====================================================================

string TypeText(int type)
{
   if(type==OP_BUY)
      return "BUY";

   if(type==OP_SELL)
      return "SELL";

   return "?";
}

bool IsSelectedMarketOrder()
{
   int type=OrderType();

   if(type!=OP_BUY && type!=OP_SELL)
      return false;

   // No Strategy Tester, o CESTA MANAGER deve enxergar as ordens
   // abertas pelo EA que esta sendo testado no mesmo grafico.
   // O filtro de simbolo continua valido, mas o Magic pode ser
   // deixado em -1 para aceitar qualquer Magic do backtest.
   if(OrderSymbol()!=Symbol())
      return false;

   if(!InpAnyMagic &&
      InpMagicNumber!=-1 &&
      OrderMagicNumber()!=InpMagicNumber)
      return false;

   return true;
}

double OrderNetResult()
{
   return(
      OrderProfit()+
      OrderSwap()+
      OrderCommission()
   );
}

double NormalizeLotsValue(double lots)
{
   double minLot=MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);
   double step  =MarketInfo(Symbol(),MODE_LOTSTEP);

   if(step<=0.0)
      step=minLot;

   if(step<=0.0)
      step=0.01;

   lots=MathFloor(
      (lots+0.0000000001)/step
   )*step;

   if(lots<0.0)
      lots=0.0;

   if(lots>maxLot)
      lots=maxLot;

   if(lots<minLot)
      return 0.0;

   int digits=2;

   if(step>=1.0)
      digits=0;
   else
   if(step>=0.1)
      digits=1;
   else
   if(step>=0.01)
      digits=2;
   else
      digits=3;

   return NormalizeDouble(lots,digits);
}

string MoneyText(double value)
{
   string sign="";

   if(value>0.00000001)
      sign="+";
   else
   if(value< -0.00000001)
      sign="-";

   return sign+
          DoubleToString(
             MathAbs(value),
             2
          );
}

string LotsText(double lots)
{
   double step=MarketInfo(Symbol(),MODE_LOTSTEP);

   // A quantidade exibida deve preservar a precisao da ordem real.
   // Nao podemos reduzir 0.21 para 0.2 apenas porque o LOTSTEP
   // informado pelo broker e 0.10.
   //
   // Mantemos no minimo 2 casas decimais para a interface da cesta.
   // Se o broker trabalhar com passo menor que 0.01, preservamos
   // tambem a precisao necessaria para esses lotes.
   int digits=2;

   if(step>=1.0)
      digits=2;
   else
   if(step>=0.01)
      digits=2;
   else
      digits=3;

   return DoubleToString(lots,digits);
}

//====================================================================
// OBJETOS VISUAIS
//====================================================================

void DeleteObjectSafe(string name)
{
   if(ObjectFind(0,name)>=0)
      ObjectDelete(0,name);
}

void CreateRectangle(
   string name,
   int x,
   int y,
   int width,
   int height,
   color background,
   color border)
{
   if(ObjectFind(0,name)<0)
   {
      ResetLastError();

      if(!ObjectCreate(
         0,
         name,
         OBJ_RECTANGLE_LABEL,
         0,
         0,
         0))
      {
         return;
      }
   }

   ObjectSetInteger(0,name,OBJPROP_CORNER,InpCorner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);

   // Painel visivel.
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);

   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,background);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,300);
}

//====================================================================
// LABEL
//====================================================================

void CreateLabel(
   string name,
   string text,
   int x,
   int y,
   color textColor,
   int fontSize)
{
   if(ObjectFind(0,name)<0)
   {
      ResetLastError();

      if(!ObjectCreate(
         0,
         name,
         OBJ_LABEL,
         0,
         0,
         0))
      {
         return;
      }
   }

   ObjectSetInteger(0,name,OBJPROP_CORNER,InpCorner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      fontSize
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      textColor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ANCHOR,
      ANCHOR_LEFT_UPPER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BACK,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTED,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ZORDER,
      310
   );
}

void HideLabel(string name)
{
   if(ObjectFind(0,name)>=0)
   {
      ObjectSetString(
         0,
         name,
         OBJPROP_TEXT,
         ""
      );
   }
}


//====================================================================
// EXECUCAO DIRETA - SOMENTE POSICOES VENCEDORAS
//====================================================================

double ReduceLots()
{
   return NormalizeLotsValue(InpReduceLots);
}

int GetCenteredPanelX()
{
   long chartWidth=ChartGetInteger(
      0,
      CHART_WIDTH_IN_PIXELS,
      0
   );

   if(chartWidth<=0)
      chartWidth=1000;

   // Com ANCHOR_LEFT_UPPER, X representa a borda esquerda do painel.
   return (int)(chartWidth/2 - InpPanelWidth/2);
}

bool CloseWinningOrder(int ticket,double lots)
{
   if(ticket<=0 || lots<=0.0)
      return false;

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return false;

   if(!IsSelectedMarketOrder())
      return false;

   // Regra fundamental: somente ordem vencedora.
   if(OrderNetResult()<=0.00000001)
      return false;

   double closeLots=
      NormalizeLotsValue(
         MathMin(lots,OrderLots())
      );

   if(closeLots<=0.0)
      return false;

   RefreshRates();

   double price=
      (OrderType()==OP_BUY) ?
      Bid :
      Ask;

   ResetLastError();

   bool ok=
      OrderClose(
         ticket,
         closeLots,
         price,
         30,
         clrNONE
      );

   return ok;
}

bool ReduceBuySellPair()
{
   int buyTicket=-1;
   int sellTicket=-1;

   double buyLots=0.0;
   double sellLots=0.0;

   double bestBuyProfit=-DBL_MAX;
   double bestSellProfit=-DBL_MAX;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      double result=OrderNetResult();

      if(result<=0.00000001)
         continue;

      if(OrderType()==OP_BUY)
      {
         if(result>bestBuyProfit)
         {
            bestBuyProfit=result;
            buyTicket=OrderTicket();
            buyLots=OrderLots();
         }
      }
      else
      if(OrderType()==OP_SELL)
      {
         if(result>bestSellProfit)
         {
            bestSellProfit=result;
            sellTicket=OrderTicket();
            sellLots=OrderLots();
         }
      }
   }

   if(buyTicket<0 || sellTicket<0)
      return false;

   double lots=
      MathMin(
         ReduceLots(),
         MathMin(
            buyLots,
            sellLots
         )
      );

   lots=NormalizeLotsValue(lots);

   if(lots<=0.0)
      return false;

   // Revalida cada ordem antes de fechar.
   if(!CloseWinningOrder(buyTicket,lots))
      return false;

   if(!CloseWinningOrder(sellTicket,lots))
      return false;

   return true;
}

void CreateActionButton(
   string name,
   string text,
   int x,
   int y,
   color background,
   color foreground,
   color borderColor)
{
   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(
         0,
         name,
         OBJ_BUTTON,
         0,
         0,
         0))
         return;
   }

   ObjectSetInteger(0,name,OBJPROP_CORNER,InpCorner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,InpButtonWidth);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,InpButtonHeight);

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ANCHOR,
      ANCHOR_LEFT_UPPER
   );

   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");

   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_COLOR,foreground);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,background);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,borderColor);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,
      (borderColor==InpPositiveBorderColor ?
       InpPositiveBorderWidth :
       InpNeutralBorderWidth)
   );

   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,(IsTesting() || InpTestMode));
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,500);
}

void CreateVisualOrderBorder(
   string name,
   int x,
   int y,
   int width,
   int height,
   color borderColor,
   int borderWidth)
{
   if(borderWidth<=0)
      return;

   string base=name+"_BORDER";

   // Remove a border anterior antes de recriar.
   for(int i=0;i<8;i++)
   {
      string oldName=base+"_"+IntegerToString(i);
      if(ObjectFind(0,oldName)>=0)
         ObjectDelete(0,oldName);
   }

   int w=MathMax(1,borderWidth);

   // Cria quatro segmentos independentes para obter uma borda
   // visual realmente perceptivel, sem depender de OBJPROP_WIDTH
   // do OBJ_BUTTON.
   CreateRectangle(base+"_0",x,y,width,w,borderColor,borderColor);
   CreateRectangle(base+"_1",x,y+height-w,width,w,borderColor,borderColor);
   CreateRectangle(base+"_2",x,y,w,height,borderColor,borderColor);
   CreateRectangle(base+"_3",x+width-w,y,w,height,borderColor,borderColor);

   for(int i=0;i<4;i++)
   {
      string segment=base+"_"+IntegerToString(i);
      ObjectSetInteger(0,segment,OBJPROP_ZORDER,510);
      ObjectSetInteger(0,segment,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,segment,OBJPROP_HIDDEN,true);
   }
}

void DeleteVisualOrderBorder(string name)
{
   string base=name+"_BORDER";

   for(int i=0;i<8;i++)
   {
      string borderName=base+"_"+IntegerToString(i);
      if(ObjectFind(0,borderName)>=0)
         ObjectDelete(0,borderName);
   }
}

void DeleteActionButton(string name)
{
   DeleteVisualOrderBorder(name);

   if(ObjectFind(0,name)>=0)
      ObjectDelete(0,name);
}

void DeleteAllActionButtons()
{
   DeleteActionButton(PREFIX+"BTN_REDUCE_BXS");

   for(int i=0;i<80;i++)
   {
      DeleteActionButton(
         PREFIX+"BTN_BUY_"+IntegerToString(i)
      );

      DeleteActionButton(
         PREFIX+"BTN_SELL_"+IntegerToString(i)
      );
   }
}

//====================================================================
// LIMPEZA
//====================================================================

void DeletePanel()
{
   for(int i=0;i<80;i++)
      DeleteObjectSafe(
         PREFIX+
         "TXT_"+IntegerToString(i)
      );

   DeleteObjectSafe(PREFIX+"TXT_SEPARATOR");
   DeleteObjectSafe(PREFIX+"PANEL");
   DeleteAllActionButtons();
   HideLabel(PREFIX+"TXT_BUY_HEADER");
   HideLabel(PREFIX+"TXT_SELL_HEADER");

   for(int i=0;i<80;i++)
      DeleteActionButton(PREFIX+"QR_"+IntegerToString(i));

}

//====================================================================
// CONSTRUCAO DA LISTA
//====================================================================

int CollectWinningOrders(
   WinningOrder &wins[],
   bool winnersOnly)
{
   ArrayResize(wins,0);

   if(IsTesting())
   {
      int bridgeCount=TesterBridgeCount();

      for(int b=0;b<bridgeCount;b++)
      {
         int ticket=0,type=0,magic=0;
         double lots=0.0,result=0.0,openPrice=0.0;
         datetime openTime=0;

         if(!GetTesterBridgeOrder(b,ticket,type,magic,lots,result,openPrice,openTime))
            continue;

         if(!InpAnyMagic &&
            InpMagicNumber!=-1 &&
            magic!=InpMagicNumber)
            continue;

         if(winnersOnly && result<=0.00000001)
            continue;

         int n=ArraySize(wins);
         ArrayResize(wins,n+1);
         wins[n].ticket=ticket;
         wins[n].type=type;
         wins[n].lots=lots;
         wins[n].result=result;
         wins[n].openTime=openTime;
         wins[n].openPrice=openPrice;
         wins[n].currentPrice=(type==OP_BUY) ? Bid : Ask;
      }

      return ArraySize(wins);
   }

   int total=OrdersTotal();

   for(int i=0;i<total;i++)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES
      ))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      double result=OrderNetResult();

      if(winnersOnly &&
         result<=0.00000001)
         continue;

      int n=ArraySize(wins);

      ArrayResize(
         wins,
         n+1
      );

      wins[n].ticket=
         OrderTicket();

      wins[n].type=
         OrderType();

      wins[n].lots=
         OrderLots();

      wins[n].result=
         result;

      wins[n].openTime=
         OrderOpenTime();

      wins[n].openPrice=
         OrderOpenPrice();

      if(OrderType()==OP_BUY)
         wins[n].currentPrice=
            Bid;
      else
         wins[n].currentPrice=
            Ask;
   }

   return ArraySize(wins);
}

void SortWinningOrders(
   WinningOrder &wins[])
{
   int n=ArraySize(wins);

   for(int i=0;i<n-1;i++)
   {
      for(int j=i+1;j<n;j++)
      {
         // Mais nova primeiro.
         // Em caso de empate, maior ticket primeiro.
         bool shouldSwap=
            (wins[j].openTime>wins[i].openTime);

         if(!shouldSwap &&
            wins[j].openTime==wins[i].openTime &&
            wins[j].ticket>wins[i].ticket)
         {
            shouldSwap=true;
         }

         if(shouldSwap)
         {
            WinningOrder temp=wins[i];
            wins[i]=wins[j];
            wins[j]=temp;
         }
      }
   }
}

//====================================================================
// CALCULO DO REDUCE
//====================================================================

double CalculateWinningLots(
   WinningOrder &wins[],
   int side)
{
   double lots=0.0;

   int n=ArraySize(wins);

   for(int i=0;i<n;i++)
   {
      if(wins[i].type==side)
         lots+=wins[i].lots;
   }

   return NormalizeLotsValue(lots);
}

double CalculateReduceMax(
   WinningOrder &wins[])
{
   double buyLots=
      CalculateWinningLots(
         wins,
         OP_BUY
      );

   double sellLots=
      CalculateWinningLots(
         wins,
         OP_SELL
      );

   if(buyLots<=0.0 ||
      sellLots<=0.0)
      return 0.0;

   return NormalizeLotsValue(
      MathMin(
         buyLots,
         sellLots
      )
   );
}

//====================================================================
// ALTURA DINAMICA
//====================================================================

int CalculatePanelHeight(
   int buyCount,
   int sellCount)
{
   int rows=0;

   rows+=2; // titulo / magic
   rows+=1; // status
   rows+=1; // BUY header
   rows+=MathMax(1,buyCount);
   rows+=1; // SELL header
   rows+=MathMax(1,sellCount);
   rows+=2; // separacao / reduce
   rows+=2; // resumo

   if(InpShowLosing)
      rows+=2;

   return 22+
          rows*18+
          10;
}

//====================================================================
// DIAGNOSTICO DE ORDENS NO TESTER
//====================================================================

void PrintOrderDiscoveryDiagnostic()
{
   static datetime lastPrint=0;
   if(!IsTesting())
      return;

   datetime now=TimeCurrent();
   if(now==lastPrint)
      return;
   lastPrint=now;

   int total=OrdersTotal();
   int buy=0;
   int sell=0;
   int accepted=0;

   Print("SENTINEL CESTA TESTER: OrdersTotal=",total,
         " Symbol=",Symbol(),
         " MagicFilter=",InpMagicNumber,
         " AnyMagic=",InpAnyMagic);

   for(int i=total-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         Print("SENTINEL CESTA TESTER: OrderSelect POS=",i,
               " falhou. Error=",GetLastError());
         continue;
      }

      int type=OrderType();
      if(type==OP_BUY) buy++;
      if(type==OP_SELL) sell++;

      bool market=(type==OP_BUY || type==OP_SELL);
      bool symbolOk=(OrderSymbol()==Symbol());
      bool magicOk=(InpAnyMagic || InpMagicNumber==-1 || OrderMagicNumber()==InpMagicNumber);
      bool ok=(market && symbolOk && magicOk);

      if(ok) accepted++;

      Print("SENTINEL CESTA TESTER: ticket=",OrderTicket(),
            " type=",type,
            " symbol=",OrderSymbol(),
            " magic=",OrderMagicNumber(),
            " lots=",DoubleToString(OrderLots(),2),
            " profit=",DoubleToString(OrderNetResult(),2),
            " accepted=",ok);
   }

   Print("SENTINEL CESTA TESTER: SUMMARY BUY=",buy,
         " SELL=",sell,
         " ACCEPTED=",accepted);
}

//====================================================================
// COR DA SELECAO OPERACIONAL
//====================================================================

color GetSelectionButtonColor(int ticket)
{
   int slot=FindSelectedSlot(ticket);

   if(slot==1)
      return InpReduceSelectionColor;

   if(slot==2 || slot==3)
      return InpCreditSelectionColor;

   return clrNONE;
}

//====================================================================
// RENDER
//====================================================================

void RenderPanel()
{
   // O painel agora nao possui fundo.
   // Remove qualquer retangulo remanescente de versoes anteriores.
   DeleteObjectSafe(PREFIX+"PANEL");

   DeleteAllActionButtons();

   if(!InpShowPanel)
   {
      HideLabel(PREFIX+"TXT_BUY_HEADER");
      HideLabel(PREFIX+"TXT_SELL_HEADER");
      return;
   }

   WinningOrder wins[];
   bool winnersOnly=
      InpSelectionEnabled ?
      false :
      !InpShowLosing;

   int count=CollectWinningOrders(
      wins,
      winnersOnly
   );

   SortWinningOrders(wins);

   int buyCount=0;
   int sellCount=0;

   for(int i=0;i<count;i++)
   {
      if(wins[i].type==OP_BUY)
         buyCount++;
      else
      if(wins[i].type==OP_SELL)
         sellCount++;
   }

   // Painel simples:
   // esquerda = BUY vencedoras
   // direita  = SELL vencedoras
   // inferior = REDUCE BxS elegivel
   int rows=
      MathMax(
         buyCount,
         sellCount
      );

   rows=MathMax(rows,1);

   int panelHeight=
      20+
      rows*(InpButtonHeight+5)+
      38;

   // Centraliza o painel no grafico.
   gPanelX=GetCenteredPanelX();

   // Colunas simples e simetricas:
   // BUY = esquerda
   // SELL = direita
   int leftX =
      (int)(
         gPanelX +
         8 +
         InpPanelXOffset
      );

   int rightX =
      (int)(
         leftX +
         InpButtonWidth +
         InpColumnGap
      );

   CreateLabel(
      PREFIX+"TXT_BUY_HEADER",
      "BUY",
      leftX,
      InpPanelY+6,
      InpBuyTextColor,
      10
   );

   CreateLabel(
      PREFIX+"TXT_SELL_HEADER",
      "SELL",
      rightX,
      InpPanelY+6,
      InpSellTextColor,
      10
   );

   int y=
      InpPanelY+
      InpRowsTopGap;

   // Coluna BUY - lado esquerdo visual do painel.
   int buyRow=0;

   // Coluna SELL - lado direito visual do painel.
   int sellRow=0;

   for(int i=0;i<count;i++)
   {
      string label=
         LotsText(wins[i].lots)+
         "  "+
         DoubleToString(
            wins[i].result,
            2
         );

      if(wins[i].type==OP_BUY)
      {
         string name=
            PREFIX+"BTN_BUY_"+
            IntegerToString(buyRow);

         CreateActionButton(
            name,
            (IsSelectedTicket(wins[i].ticket) ?
             "[SEL] " : "")+
            "BUY  "+label,
            leftX,
            y+
            buyRow*
            (InpButtonHeight+5),
            (IsSelectedTicket(wins[i].ticket) ?
             GetSelectionButtonColor(wins[i].ticket) :
             InpBuyButtonColor),
            InpButtonTextColor,
            (wins[i].result>0.00000001 ?
             InpPositiveBorderColor :
             InpNeutralBorderColor)
         );

         if(wins[i].result>0.00000001)
         {
            CreateVisualOrderBorder(
               name,
               leftX,
               y+buyRow*(InpButtonHeight+5),
               InpButtonWidth,
               InpButtonHeight,
               InpPositiveBorderColor,
               InpPositiveBorderWidth
            );
         }

         // Ticket guardado na tooltip apenas para o evento local.
         ObjectSetString(
            0,
            name,
            OBJPROP_TOOLTIP,
            IntegerToString(wins[i].ticket)
         );

         buyRow++;
      }
      else
      if(wins[i].type==OP_SELL)
      {
         string name=
            PREFIX+"BTN_SELL_"+
            IntegerToString(sellRow);

         CreateActionButton(
            name,
            (IsSelectedTicket(wins[i].ticket) ?
             "[SEL] " : "")+
            "SELL "+label,
            rightX,
            y+
            sellRow*
            (InpButtonHeight+5),
            (IsSelectedTicket(wins[i].ticket) ?
             GetSelectionButtonColor(wins[i].ticket) :
             InpSellButtonColor),
            InpButtonTextColor,
            (wins[i].result>0.00000001 ? clrDodgerBlue : clrDimGray)
         );

         if(wins[i].result>0.00000001)
         {
            CreateVisualOrderBorder(
               name,
               rightX,
               y+sellRow*(InpButtonHeight+5),
               InpButtonWidth,
               InpButtonHeight,
               InpPositiveBorderColor,
               InpPositiveBorderWidth
            );
         }

         ObjectSetString(
            0,
            name,
            OBJPROP_TOOLTIP,
            IntegerToString(wins[i].ticket)
         );

         sellRow++;
      }
   }

   // REDUCE:
   // 1) WIN isolada selecionada -> REDUCE WIN direto.
   // 2) BUY WIN + SELL WIN -> REDUCE BxS tradicional.
   int singleSelectedWinningTicket=GetSingleSelectedWinningTicket();

   if((buyCount>0 && sellCount>0) ||
      singleSelectedWinningTicket>0)
   {
      int bottomY=
         InpPanelY+
         20+
         rows*
         (InpButtonHeight+5)+
         4;

      string reduceText=
         (singleSelectedWinningTicket>0) ?
         "REDUCE WIN" :
         "REDUCE BxS  ELEGIVEL";

      CreateActionButton(
         PREFIX+"BTN_REDUCE_BXS",
         reduceText,
         gPanelX+
         (InpPanelWidth-InpButtonWidth)/2+
         InpPanelXOffset,
         bottomY,
         InpReduceButtonColor,
         InpReduceTextColor,
         clrDimGray
      );
   }

   ChartRedraw();
}

//====================================================================
// POLLING DOS BOTOES NO STRATEGY TESTER VISUAL
//====================================================================

bool ProcessTesterSelectionButtonState(string name)
{
   if(ObjectFind(0,name)<0)
      return false;

   bool pressed=(bool)ObjectGetInteger(0,name,OBJPROP_STATE);

   if(!pressed)
      return false;

   string ticketText=ObjectGetString(0,name,OBJPROP_TOOLTIP);
   int ticket=(int)StringToInteger(ticketText);

   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);

   if(ticket<=0)
      return true;

   ToggleSelectedTicket(ticket);
   RenderPanel();
   return true;
}

void PollTesterSelectionButtons()
{
   if(!IsTesting() || !IsVisualMode() || !InpSelectionEnabled)
      return;

   for(int i=0;i<80;i++)
   {
      if(ProcessTesterSelectionButtonState(PREFIX+"BTN_BUY_"+IntegerToString(i)))
         return;

      if(ProcessTesterSelectionButtonState(PREFIX+"BTN_SELL_"+IntegerToString(i)))
         return;
   }
}

//====================================================================
// EVENTO DE CLIQUE
//====================================================================

void OnChartEvent(
   const int id,
   const long &lparam,
   const double &dparam,
   const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK)
      return;

   if(InpSelectionEnabled)
   {
      string buyPrefix=PREFIX+"BTN_BUY_";
      string sellPrefix=PREFIX+"BTN_SELL_";

      if(StringFind(sparam,buyPrefix,0)==0 ||
         StringFind(sparam,sellPrefix,0)==0)
      {
         string ticketText=
            ObjectGetString(
               0,
               sparam,
               OBJPROP_TOOLTIP
            );

         int ticket=(int)StringToInteger(ticketText);

         if(ticket>0)
            ToggleSelectedTicket(ticket);

         ObjectSetInteger(
            0,
            sparam,
            OBJPROP_STATE,
            false
         );

         RenderPanel();
         return;
      }

      // A execucao pertence ao SENTINEL.
      if(sparam==PREFIX+"BTN_REDUCE_BXS")
      {
         int singleWinningTicket=
            GetSingleSelectedWinningTicket();

         if(singleWinningTicket>0)
         {
            RequestSelectedReduction();

            Print(
               "SENTINEL CESTA MANAGER: "
               "REDUCE WIN solicitado. TICKET=",
               singleWinningTicket
            );
         }
         else
         {
            SetStatusSelectionHint();
         }

         ObjectSetInteger(
            0,
            sparam,
            OBJPROP_STATE,
            false
         );
         return;
      }

      return;
   }


   if(id!=CHARTEVENT_OBJECT_CLICK)
      return;

   // ---------------------------------------------------------------
   // REDUCE BxS
   // ---------------------------------------------------------------
   if(sparam==PREFIX+"BTN_REDUCE_BXS")
   {
      bool ok=ReduceBuySellPair();

      ObjectSetInteger(
         0,
         sparam,
         OBJPROP_STATE,
         false
      );


      RenderPanel();
      return;
   }

   // ---------------------------------------------------------------
   // BUY
   // ---------------------------------------------------------------
   string buyPrefix=PREFIX+"BTN_BUY_";

   if(StringFind(sparam,buyPrefix,0)==0)
   {
      string ticketText=
         ObjectGetString(
            0,
            sparam,
            OBJPROP_TOOLTIP
         );

      int ticket=
         (int)StringToInteger(ticketText);

      bool ok=
         CloseWinningOrder(
            ticket,
            ReduceLots()
         );

      ObjectSetInteger(
         0,
         sparam,
         OBJPROP_STATE,
         false
      );


      RenderPanel();
      return;
   }

   // ---------------------------------------------------------------
   // SELL
   // ---------------------------------------------------------------
   string sellPrefix=PREFIX+"BTN_SELL_";

   if(StringFind(sparam,sellPrefix,0)==0)
   {
      string ticketText=
         ObjectGetString(
            0,
            sparam,
            OBJPROP_TOOLTIP
         );

      int ticket=
         (int)StringToInteger(ticketText);

      bool ok=
         CloseWinningOrder(
            ticket,
            ReduceLots()
         );

      ObjectSetInteger(
         0,
         sparam,
         OBJPROP_STATE,
         false
      );


      RenderPanel();
      return;
   }

}

//====================================================================
// CICLO DE VIDA
//====================================================================

int OnInit()
{
   EventSetTimer(
      MathMax(
         1,
         InpRefreshSeconds
      )
   );

   RenderPanel();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   DeleteAllActionButtons();
   DeleteObjectSafe(PREFIX+"PANEL");

   for(int i=0;i<120;i++)
   {
      HideLabel(
         PREFIX+
         "TXT_"+
         IntegerToString(i)
      );
   }

   ChartRedraw();
}

//====================================================================
// TIMER
//====================================================================

void OnTimer()
{
   RenderPanel();
}

//====================================================================
// CALCULATE
//====================================================================

int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[])
{
   PrintOrderDiscoveryDiagnostic();
   PollTesterSelectionButtons();
   RenderPanel();

   return rates_total;
}
//+------------------------------------------------------------------+