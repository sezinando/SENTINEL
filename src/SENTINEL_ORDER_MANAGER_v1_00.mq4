//+------------------------------------------------------------------+
//| SENTINEL_ORDER_MANAGER_v1_00.mq4                                 |
//| Gestor visual independente de ordens                             |
//|                                                                  |
//| Funcao:                                                          |
//|  - Ler ordens abertas do simbolo                                 |
//|  - Filtrar por Magic Number                                      |
//|  - Separar BUY / SELL                                            |
//|  - Selecionar ate 2 ordens                                       |
//|  - Mostrar resultado, lotes e exposicao                          |
//|  - Reduzir ordem selecionada                                     |
//|  - Reduzir um par BUY x SELL vencedor                            |
//|                                                                  |
//| IMPORTANTE:                                                      |
//|  Este painel e INDEPENDENTE do SENTINEL_CESTA_MANAGER.           |
//|  Nao compartilha codigo, objetos ou variaveis de selecao.        |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property version "1.00"

//====================================================================
// INPUTS
//====================================================================

input int      InpMagicNumber       = -1;
input bool     InpAnyMagic          = false;

input ENUM_BASE_CORNER InpCorner    = CORNER_LEFT_UPPER;
input int      InpPanelX            = 320;
input int      InpPanelY            = 80;
input int      InpPanelWidth        = 390;

input bool     InpShowTickets       = true;
input bool     InpShowLosing        = true;
input bool     InpSelectionEnabled  = true;
input int      InpSelectionMax      = 2;

input int      InpRefreshSeconds    = 1;
input double   InpReduceLots        = 0.01;

input color    InpPanelBackground   = C'24,24,24';
input color    InpPanelBorder       = C'62,66,76';
input color    InpTitleColor        = clrWhite;
input color    InpMutedColor        = C'145,145,145';
input color    InpBuyColor          = C'45,185,85';
input color    InpSellColor         = C'225,72,68';
input color    InpProfitColor       = C'60,200,105';
input color    InpLossColor         = C'240,75,70';
input color    InpAccentColor       = C'215,165,35';
input color    InpSelectedColor     = C'215,165,35';
input color    InpButtonColor       = C'58,58,58';

input int      InpTitleSize         = 11;
input int      InpTextSize          = 9;
input int      InpRowHeight         = 21;

//====================================================================
// PREFIXOS
//====================================================================

#define PREFIX "SOM_"
#define SEL_PREFIX "SOM_SELECTED_"

#define OBJ_PANEL       PREFIX+"PANEL"
#define OBJ_TITLE       PREFIX+"TITLE"
#define OBJ_SUMMARY     PREFIX+"SUMMARY"
#define OBJ_STATUS      PREFIX+"STATUS"
#define OBJ_CLEAR       PREFIX+"BTN_CLEAR"
#define OBJ_REDUCE      PREFIX+"BTN_REDUCE"
#define OBJ_REDUCE_BXS  PREFIX+"BTN_BXS"
#define OBJ_ORDER_LINE_1 PREFIX+"ORDER_LINE_1"
#define OBJ_ORDER_LINE_2 PREFIX+"ORDER_LINE_2"

//====================================================================
// DADOS
//====================================================================

struct OrderRow
{
   int      ticket;
   int      type;
   double   lots;
   double   result;
   double   openPrice;
   datetime openTime;
};

string SelectionPrefix()
{
   return SEL_PREFIX+
          Symbol()+"_"+
          IntegerToString(InpMagicNumber)+"_";
}

string SelectionName(int slot)
{
   return SelectionPrefix()+IntegerToString(slot);
}

int GetSelectedTicket(int slot)
{
   if(slot<1 || slot>2)
      return -1;

   string name=SelectionName(slot);

   if(!GlobalVariableCheck(name))
      return -1;

   int ticket=(int)GlobalVariableGet(name);

   if(ticket<=0)
      return -1;

   return ticket;
}

int SelectionCount()
{
   int n=0;

   if(GetSelectedTicket(1)>0) n++;
   if(GetSelectedTicket(2)>0) n++;

   return n;
}

int FindSelectedSlot(int ticket)
{
   if(ticket<=0)
      return 0;

   if(GetSelectedTicket(1)==ticket) return 1;
   if(GetSelectedTicket(2)==ticket) return 2;

   return 0;
}

void ClearSelection()
{
   GlobalVariableSet(SelectionName(1),0.0);
   GlobalVariableSet(SelectionName(2),0.0);
   GlobalVariablesFlush();
}

void ToggleSelection(int ticket)
{
   if(!InpSelectionEnabled || ticket<=0)
      return;

   int slot=FindSelectedSlot(ticket);

   if(slot>0)
   {
      GlobalVariableSet(SelectionName(slot),0.0);
      GlobalVariablesFlush();
      return;
   }

   int maxSel=MathMin(2,MathMax(1,InpSelectionMax));

   if(SelectionCount()>=maxSel)
      return;

   int target=GetSelectedTicket(1)<=0 ? 1 : 2;

   GlobalVariableSet(SelectionName(target),ticket);
   GlobalVariablesFlush();
}

bool IsSelected(int ticket)
{
   return FindSelectedSlot(ticket)>0;
}

//====================================================================
// UTILITARIOS
//====================================================================

string TypeText(int type)
{
   if(type==OP_BUY)  return "BUY";
   if(type==OP_SELL) return "SELL";
   return "?";
}

double OrderNetResult()
{
   return OrderProfit()+OrderSwap()+OrderCommission();
}

bool IsManagedMarketOrder()
{
   int type=OrderType();

   if(type!=OP_BUY && type!=OP_SELL)
      return false;

   if(OrderSymbol()!=Symbol())
      return false;

   if(!InpAnyMagic &&
      InpMagicNumber!=-1 &&
      OrderMagicNumber()!=InpMagicNumber)
      return false;

   return true;
}

double NormalizeLots(double lots)
{
   double minLot=MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);
   double step=MarketInfo(Symbol(),MODE_LOTSTEP);

   if(step<=0.0)
      step=minLot;

   if(step<=0.0)
      step=0.01;

   lots=MathFloor((lots+1e-10)/step)*step;

   if(lots<0.0) lots=0.0;
   if(lots>maxLot) lots=maxLot;
   if(lots<minLot) return 0.0;

   int digits=2;
   if(step>=1.0) digits=0;
   else if(step>=0.1) digits=1;
   else if(step>=0.01) digits=2;
   else digits=3;

   return NormalizeDouble(lots,digits);
}

string MoneyText(double value)
{
   if(value>0.00000001)
      return "+"+DoubleToString(value,2);

   if(value<-0.00000001)
      return "-"+DoubleToString(MathAbs(value),2);

   return "0.00";
}

string LotsText(double lots)
{
   double step=MarketInfo(Symbol(),MODE_LOTSTEP);
   int digits=2;

   if(step>=1.0) digits=0;
   else if(step>=0.1) digits=1;
   else if(step>=0.01) digits=2;
   else digits=3;

   return DoubleToString(lots,digits);
}

void SetText(string name,string text,color clr,int size=-1)
{
   if(ObjectFind(0,name)<0)
      return;

   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);

   if(size>0)
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
}

void DeleteObjectSafe(string name)
{
   if(ObjectFind(0,name)>=0)
      ObjectDelete(0,name);
}

//====================================================================
// OBJETOS
//====================================================================

void CreatePanel()
{
   if(ObjectFind(0,OBJ_PANEL)<0)
   {
      ObjectCreate(0,OBJ_PANEL,OBJ_RECTANGLE_LABEL,0,0,0);
   }

   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_CORNER,InpCorner);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_XDISTANCE,InpPanelX);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_YDISTANCE,InpPanelY);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_XSIZE,InpPanelWidth);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_YSIZE,445);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_BGCOLOR,InpPanelBackground);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_BORDER_COLOR,InpPanelBorder);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_BACK,false);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_ZORDER,200);
}

void CreateLabel(string name,string text,int x,int y,color clr,int size)
{
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,InpCorner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,300);
}

void CreateButton(string name,string text,int x,int y,int width,int height,color bg,color fg)
{
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_BUTTON,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,InpCorner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_COLOR,fg);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,InpPanelBorder);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,500);
}

void DeleteRows()
{
   for(int i=0;i<120;i++)
   {
      DeleteObjectSafe(PREFIX+"ROW_"+IntegerToString(i));
   }
}

//====================================================================
// COLETA
//====================================================================

int CollectOrders(OrderRow &rows[])
{
   ArrayResize(rows,0);

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(!IsManagedMarketOrder())
         continue;

      double result=OrderNetResult();

      if(!InpShowLosing && result<=0.00000001)
         continue;

      int n=ArraySize(rows);
      ArrayResize(rows,n+1);

      rows[n].ticket=OrderTicket();
      rows[n].type=OrderType();
      rows[n].lots=OrderLots();
      rows[n].result=result;
      rows[n].openPrice=OrderOpenPrice();
      rows[n].openTime=OrderOpenTime();
   }

   // Mais recentes primeiro.
   for(int a=0;a<ArraySize(rows)-1;a++)
   {
      for(int b=a+1;b<ArraySize(rows);b++)
      {
         bool swapIt=rows[b].openTime>rows[a].openTime;

         if(!swapIt &&
            rows[b].openTime==rows[a].openTime &&
            rows[b].ticket>rows[a].ticket)
            swapIt=true;

         if(swapIt)
         {
            OrderRow tmp=rows[a];
            rows[a]=rows[b];
            rows[b]=tmp;
         }
      }
   }

   return ArraySize(rows);
}

//====================================================================
// LINHAS DE ORDEM NO GRAFICO
//====================================================================

void DeleteOrderLine(int slot)
{
   if(slot<1 || slot>2)
      return;

   string name=
      slot==1 ? OBJ_ORDER_LINE_1 : OBJ_ORDER_LINE_2;

   DeleteObjectSafe(name);
}

void UpdateOrderLine(int slot,int ticket)
{
   if(slot<1 || slot>2)
      return;

   string name=
      slot==1 ? OBJ_ORDER_LINE_1 : OBJ_ORDER_LINE_2;

   if(ticket<=0)
   {
      DeleteOrderLine(slot);
      return;
   }

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
   {
      DeleteOrderLine(slot);
      return;
   }

   if(!IsManagedMarketOrder())
   {
      DeleteOrderLine(slot);
      return;
   }

   double price=OrderOpenPrice();

   if(ObjectFind(0,name)<0)
   {
      ResetLastError();

      if(!ObjectCreate(
         0,
         name,
         OBJ_HLINE,
         0,
         0,
         price))
      {
         return;
      }
   }

   ObjectSetDouble(0,name,OBJPROP_PRICE1,price);
   ObjectSetInteger(
      0,name,OBJPROP_COLOR,
      slot==1 ? InpBuyColor : InpSelectedColor
   );
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,450);

   string side=TypeText(OrderType());
   string label=
      "T"+IntegerToString(slot)+
      " #"+IntegerToString(ticket)+
      " "+side+
      "  "+DoubleToString(price,Digits);

   ObjectSetString(
      0,name,OBJPROP_TOOLTIP,label
   );
}

void UpdateSelectedOrderLines()
{
   UpdateOrderLine(1,GetSelectedTicket(1));
   UpdateOrderLine(2,GetSelectedTicket(2));
}

//====================================================================
// RESUMO
//====================================================================

void CalculateSummary(OrderRow &rows[],
                      double &buyLots,
                      double &sellLots,
                      double &buyResult,
                      double &sellResult,
                      double &buyWinLots,
                      double &sellWinLots)
{
   buyLots=0.0;
   sellLots=0.0;
   buyResult=0.0;
   sellResult=0.0;
   buyWinLots=0.0;
   sellWinLots=0.0;

   for(int i=0;i<ArraySize(rows);i++)
   {
      if(rows[i].type==OP_BUY)
      {
         buyLots+=rows[i].lots;
         buyResult+=rows[i].result;

         if(rows[i].result>0.00000001)
            buyWinLots+=rows[i].lots;
      }
      else
      if(rows[i].type==OP_SELL)
      {
         sellLots+=rows[i].lots;
         sellResult+=rows[i].result;

         if(rows[i].result>0.00000001)
            sellWinLots+=rows[i].lots;
      }
   }

   buyLots=NormalizeLots(buyLots);
   sellLots=NormalizeLots(sellLots);
   buyWinLots=NormalizeLots(buyWinLots);
   sellWinLots=NormalizeLots(sellWinLots);
}

double CalculateReduceMax(OrderRow &rows[])
{
   double buyWin=0.0;
   double sellWin=0.0;
   double dummy1,dummy2,dummy3,dummy4;

   CalculateSummary(
      rows,
      dummy1,dummy2,dummy3,dummy4,
      buyWin,sellWin
   );

   if(buyWin<=0.0 || sellWin<=0.0)
      return 0.0;

   return NormalizeLots(MathMin(buyWin,sellWin));
}

//====================================================================
// EXECUCAO SEGURA
//====================================================================

bool ClosePartial(int ticket,double requestedLots)
{
   if(ticket<=0 || requestedLots<=0.0)
      return false;

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return false;

   if(!IsManagedMarketOrder())
      return false;

   double available=OrderLots();
   double closeLots=NormalizeLots(MathMin(requestedLots,available));

   if(closeLots<=0.0)
      return false;

   RefreshRates();

   double price=
      OrderType()==OP_BUY ? Bid : Ask;

   ResetLastError();

   return OrderClose(
      ticket,
      closeLots,
      price,
      30,
      clrNONE
   );
}

bool FindBestWinningTicket(int type,int &ticket,double &lots,double &profit)
{
   ticket=-1;
   lots=0.0;
   profit=-DBL_MAX;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(!IsManagedMarketOrder())
         continue;

      if(OrderType()!=type)
         continue;

      double result=OrderNetResult();

      if(result<=0.00000001)
         continue;

      if(result>profit)
      {
         profit=result;
         ticket=OrderTicket();
         lots=OrderLots();
      }
   }

   return ticket>0;
}

bool ReduceBestBuySell()
{
   int buyTicket=-1;
   int sellTicket=-1;
   double buyLots=0.0;
   double sellLots=0.0;
   double buyProfit=0.0;
   double sellProfit=0.0;

   if(!FindBestWinningTicket(OP_BUY,buyTicket,buyLots,buyProfit))
      return false;

   if(!FindBestWinningTicket(OP_SELL,sellTicket,sellLots,sellProfit))
      return false;

   double lots=NormalizeLots(
      MathMin(
         InpReduceLots,
         MathMin(buyLots,sellLots)
      )
   );

   if(lots<=0.0)
      return false;

   // Revalida cada ordem no momento da execucao.
   if(!ClosePartial(buyTicket,lots))
      return false;

   if(!ClosePartial(sellTicket,lots))
      return false;

   return true;
}

bool ReduceSelected()
{
   int t1=GetSelectedTicket(1);

   if(t1<=0)
      return false;

   int t2=GetSelectedTicket(2);

   // Uma selecao: reduz apenas essa ordem.
   if(t2<=0)
      return ClosePartial(t1,InpReduceLots);

   // Duas selecoes: somente executa par WIN x WIN.
   // Nao fecha LOSS automaticamente.
   if(!OrderSelect(t1,SELECT_BY_TICKET,MODE_TRADES))
      return false;

   double r1=OrderNetResult();
   int type1=OrderType();

   if(!OrderSelect(t2,SELECT_BY_TICKET,MODE_TRADES))
      return false;

   double r2=OrderNetResult();
   int type2=OrderType();

   if(type1==type2)
      return false;

   if(r1<=0.00000001 || r2<=0.00000001)
      return false;

   double lots1=OrderLots();

   if(!OrderSelect(t1,SELECT_BY_TICKET,MODE_TRADES))
      return false;

   lots1=OrderLots();

   if(!OrderSelect(t2,SELECT_BY_TICKET,MODE_TRADES))
      return false;

   double lots2=OrderLots();

   double lots=NormalizeLots(
      MathMin(
         InpReduceLots,
         MathMin(lots1,lots2)
      )
   );

   if(lots<=0.0)
      return false;

   if(!ClosePartial(t1,lots))
      return false;

   if(!ClosePartial(t2,lots))
      return false;

   return true;
}

//====================================================================
// RENDER
//====================================================================

void Render()
{
   DeleteRows();

   CreatePanel();

   int baseX=InpPanelX;
   int baseY=InpPanelY;

   CreateLabel(
      OBJ_TITLE,
      "ORDER MANAGER",
      baseX+10,
      baseY+8,
      InpTitleColor,
      InpTitleSize
   );

   OrderRow rows[];
   int count=CollectOrders(rows);

   double buyLots,sellLots,buyResult,sellResult,buyWinLots,sellWinLots;

   CalculateSummary(
      rows,
      buyLots,sellLots,
      buyResult,sellResult,
      buyWinLots,sellWinLots
   );

   double net=buyResult+sellResult;
   double netLots=buyLots-sellLots;
   double reduceMax=CalculateReduceMax(rows);

   string summary=
      "BUY "+LotsText(buyLots)+"  "+MoneyText(buyResult)+
      "    SELL "+LotsText(sellLots)+"  "+MoneyText(sellResult)+
      "    NET "+DoubleToString(netLots,2)+"  "+MoneyText(net);

   CreateLabel(
      OBJ_SUMMARY,
      summary,
      baseX+10,
      baseY+30,
      net>=0.0 ? InpProfitColor : InpLossColor,
      InpTextSize
   );

   int y=baseY+58;

   CreateLabel(
      PREFIX+"HDR_BUY",
      "BUY",
      baseX+10,
      y,
      InpBuyColor,
      InpTextSize
   );

   CreateLabel(
      PREFIX+"HDR_SELL",
      "SELL",
      baseX+200,
      y,
      InpSellColor,
      InpTextSize
   );

   y+=20;

   int buyRow=0;
   int sellRow=0;

   for(int i=0;i<count;i++)
   {
      int x=
         rows[i].type==OP_BUY ?
         baseX+8 :
         baseX+198;

      int row=
         rows[i].type==OP_BUY ?
         buyRow++ :
         sellRow++;

      string name=
         PREFIX+"ROW_"+IntegerToString(i);

      string prefix=
         IsSelected(rows[i].ticket) ? "[T"+IntegerToString(FindSelectedSlot(rows[i].ticket))+"] " : "";

      string ticketText=
         InpShowTickets ?
         "#"+IntegerToString(rows[i].ticket)+" " :
         "";

      string text=
         prefix+
         ticketText+
         LotsText(rows[i].lots)+
         "  "+
         MoneyText(rows[i].result);

      color rowColor=
         IsSelected(rows[i].ticket) ?
         InpSelectedColor :
         (rows[i].result>=0.0 ? InpProfitColor : InpLossColor);

      CreateButton(
         name,
         text,
         x,
         y+row*InpRowHeight,
         180,
         InpRowHeight-2,
         IsSelected(rows[i].ticket) ? InpSelectedColor : InpButtonColor,
         IsSelected(rows[i].ticket) ? clrBlack : rowColor
      );

      ObjectSetString(
         0,
         name,
         OBJPROP_TOOLTIP,
         IntegerToString(rows[i].ticket)
      );
   }

   int maxRows=MathMax(buyRow,sellRow);
   if(maxRows<1) maxRows=1;

   int sepY=y+maxRows*InpRowHeight+6;

   CreateLabel(
      PREFIX+"SEP",
      "────────────────────────────────────────",
      baseX+10,
      sepY,
      InpPanelBorder,
      8
   );

   int selectedY=sepY+18;

   int t1=GetSelectedTicket(1);
   int t2=GetSelectedTicket(2);

   string selectionText=
      "T1 "+(t1>0 ? "#"+IntegerToString(t1) : "--")+
      "      T2 "+(t2>0 ? "#"+IntegerToString(t2) : "--");

   CreateLabel(
      PREFIX+"SELECTION",
      selectionText,
      baseX+10,
      selectedY,
      InpTitleColor,
      InpTextSize
   );

   double selectedNet=0.0;
   double selectedLots=0.0;

   if(t1>0 && OrderSelect(t1,SELECT_BY_TICKET,MODE_TRADES))
   {
      selectedNet+=OrderNetResult();
      selectedLots+=OrderLots();
   }

   if(t2>0 && OrderSelect(t2,SELECT_BY_TICKET,MODE_TRADES))
   {
      selectedNet+=OrderNetResult();
      selectedLots+=OrderLots();
   }

   CreateLabel(
      PREFIX+"SELECTED_RESULT",
      "SELECTED  "+
      LotsText(selectedLots)+
      " LOT   "+
      MoneyText(selectedNet),
      baseX+10,
      selectedY+18,
      selectedNet>=0.0 ? InpProfitColor : InpLossColor,
      InpTextSize
   );

   int buttonY=selectedY+43;

   CreateButton(
      OBJ_REDUCE,
      "REDUCE SELECTED",
      baseX+10,
      buttonY,
      140,
      24,
      InpAccentColor,
      clrBlack
   );

   CreateButton(
      OBJ_CLEAR,
      "LIMPAR",
      baseX+158,
      buttonY,
      80,
      24,
      InpButtonColor,
      clrWhite
   );

   CreateButton(
      OBJ_REDUCE_BXS,
      "REDUCE BxS  "+LotsText(reduceMax),
      baseX+244,
      buttonY,
      136,
      24,
      reduceMax>0.0 ? InpAccentColor : InpButtonColor,
      reduceMax>0.0 ? clrBlack : InpMutedColor
   );

   CreateLabel(
      OBJ_STATUS,
      "Selecione ate 2 ordens",
      baseX+10,
      buttonY+30,
      InpMutedColor,
      8
   );

   UpdateSelectedOrderLines();

   ChartRedraw();
}

//====================================================================
// EVENTOS
//====================================================================

void OnChartEvent(
   const int id,
   const long &lparam,
   const double &dparam,
   const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK)
      return;

   if(StringFind(sparam,PREFIX+"ROW_",0)==0)
   {
      string ticketText=ObjectGetString(
         0,
         sparam,
         OBJPROP_TOOLTIP
      );

      int ticket=(int)StringToInteger(ticketText);

      if(ticket>0)
         ToggleSelection(ticket);

      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      Render();
      return;
   }

   if(sparam==OBJ_CLEAR)
   {
      ClearSelection();
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      Render();
      return;
   }

   if(sparam==OBJ_REDUCE)
   {
      bool ok=ReduceSelected();

      SetText(
         OBJ_STATUS,
         ok ? "REDUCE executado." : "REDUCE nao executado: revalide a selecao.",
         ok ? InpProfitColor : InpLossColor,
         8
      );

      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      Render();
      return;
   }

   if(sparam==OBJ_REDUCE_BXS)
   {
      bool ok=ReduceBestBuySell();

      SetText(
         OBJ_STATUS,
         ok ? "REDUCE BxS executado." : "REDUCE BxS indisponivel.",
         ok ? InpProfitColor : InpLossColor,
         8
      );

      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      Render();
      return;
   }
}

//====================================================================
// CICLO DE VIDA
//====================================================================

int OnInit()
{
   EventSetTimer(MathMax(1,InpRefreshSeconds));
   Render();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   DeleteObjectSafe(OBJ_PANEL);
   DeleteObjectSafe(OBJ_TITLE);
   DeleteObjectSafe(OBJ_SUMMARY);
   DeleteObjectSafe(OBJ_STATUS);
   DeleteObjectSafe(OBJ_CLEAR);
   DeleteObjectSafe(OBJ_REDUCE);
   DeleteObjectSafe(OBJ_REDUCE_BXS);
   DeleteOrderLine(1);
   DeleteOrderLine(2);

   for(int i=0;i<150;i++)
   {
      DeleteObjectSafe(PREFIX+"ROW_"+IntegerToString(i));
   }

   DeleteObjectSafe(PREFIX+"HDR_BUY");
   DeleteObjectSafe(PREFIX+"HDR_SELL");
   DeleteObjectSafe(PREFIX+"SEP");
   DeleteObjectSafe(PREFIX+"SELECTION");
   DeleteObjectSafe(PREFIX+"SELECTED_RESULT");

   ChartRedraw();
}

void OnTimer()
{
   Render();
}

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
   return rates_total;
}
//+------------------------------------------------------------------+
