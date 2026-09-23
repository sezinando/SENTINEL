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
#property version "3.11"

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

// Cor do botao REDUCE BxS.
input color    InpReduceButtonColor = clrGold;
input color    InpReduceTextColor   = clrBlack;


//====================================================================
// PREFIXOS
//====================================================================

string PREFIX = "SCM_";

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
};

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

   if(OrderSymbol()!=Symbol())
      return false;

   // Magic = -1 significa: aceitar todas as ordens de mercado
   // deste simbolo, independentemente do Magic Number.
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
   color foreground)
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
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrDimGray);

   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,500);
}

void DeleteActionButton(string name)
{
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
         // Maior lucro primeiro.
         if(wins[j].result>wins[i].result)
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
   int count=CollectWinningOrders(
      wins,
      true
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
            "BUY  "+label,
            leftX,
            y+
            buyRow*
            (InpButtonHeight+5),
            InpBuyButtonColor,
            InpButtonTextColor
         );

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
            "SELL "+label,
            rightX,
            y+
            sellRow*
            (InpButtonHeight+5),
            InpSellButtonColor,
            InpButtonTextColor
         );

         ObjectSetString(
            0,
            name,
            OBJPROP_TOOLTIP,
            IntegerToString(wins[i].ticket)
         );

         sellRow++;
      }
   }

   // REDUCE BxS:
   // somente aparece quando existe pelo menos uma BUY WIN
   // e uma SELL WIN.
   if(buyCount>0 && sellCount>0)
   {
      int bottomY=
         InpPanelY+
         20+
         rows*
         (InpButtonHeight+5)+
         4;

      CreateActionButton(
         PREFIX+"BTN_REDUCE_BXS",
         "REDUCE BxS  ELEGIVEL",
         gPanelX+
         (InpPanelWidth-InpButtonWidth)/2+
         InpPanelXOffset,
         bottomY,
         InpReduceButtonColor,
         InpReduceTextColor
      );
   }

   ChartRedraw();
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
   RenderPanel();

   return rates_total;
}
//+------------------------------------------------------------------+