//+------------------------------------------------------------------+
//|                                                   SENTINEL.mq4   |
//|                    SENTINEL Operational Panel                    |
//|                                                                  |
//| Version 1.12                                                      |
//|                                                                  |
//| - BUY / SELL                                                     |
//| - REDUCE BUY / SELL / BxS                                         |
//| - CLOSE ALL                                                       |
//| - Cesta dinamica                                                  |
//| - Realizado / Aberto / Total                                      |
//| - Medio dinamico                                                  |
//| - BE dinamico                                                      |
//| - TAKE / STOP como linhas pontilhadas                                |
//| - TAKE / STOP controlados por +/- pontos                                         |
//| - Painel compacto e opaco                          
//| - Alteracao de TAKE/STOP no painel recalcula imediatamente       |
//+------------------------------------------------------------------+
#property strict
#property version "1.41"



//====================================================================
// LUCRO/PREJUIZO REALIZADO DO DIA
//====================================================================

double GetTodayRealizedProfit()
{
   datetime now = TimeCurrent();

   MqlDateTime dt;
   TimeToStruct(now, dt);

   dt.hour   = 0;
   dt.min    = 0;
   dt.sec    = 0;

   datetime dayStart = StructToTime(dt);

   double total = 0.0;

   int historyTotal = OrdersHistoryTotal();

   for(int i = historyTotal - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderType() != OP_BUY &&
         OrderType() != OP_SELL)
         continue;

      if(InpMagicNumber >= 0 &&
         OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderCloseTime() < dayStart)
         continue;

      total +=
         OrderProfit() +
         OrderSwap() +
         OrderCommission();
   }

   return total;
}

string FormatMoney(double value)
{
   string sign = "";

   if(value > 0.0000001)
      sign = "+";
   else
   if(value < -0.0000001)
      sign = "-";

   return sign +
          DoubleToString(
             MathAbs(value),
             2
          ) +
          " " +
          AccountCurrency();
}

double GetTodayTotalProfit();

// Macro usada pelo resultado realizado do dia.
// Declarada antes da função que a utiliza.
#define OBJ_LBL_TODAY_RESULT "SENTINEL_LBL_TODAY_RESULT"

//====================================================================
// SALDO TOTAL DO DIA
//====================================================================
//
// DIA = resultado ja realizado no pregao.
//
// O valor NAO varia com o lucro/prejuizo flutuante das ordens abertas.
// O resultado da cesta em aberto fica exclusivamente em ABERTO.
//
// REALIZADO continua separado e representa a cesta operacional atual.
//====================================================================

double GetTodayTotalProfit()
{
   // DIA representa somente o resultado ja realizado no pregao.
   // O resultado flutuante permanece exclusivamente em ABERTO.
   return GetTodayRealizedProfit();
}

void UpdateTodayRealizedPanel()
{
   if(ObjectFind(0, OBJ_LBL_TODAY_RESULT) < 0)
      return;

   double result = GetTodayTotalProfit();

   string text =
      "DIA: " +
      FormatMoney(result);

   color c = InpProfitColor;

   if(result < -0.0000001)
      c = InpStopColor;

   ObjectSetString(
      0,
      OBJ_LBL_TODAY_RESULT,
      OBJPROP_TEXT,
      text
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_TODAY_RESULT,
      OBJPROP_COLOR,
      c
   );
}

//====================================================================
// INPUTS
//====================================================================

// -1 = reconhecer qualquer Magic Number do simbolo,
//      inclusive ordens manuais com Magic Number 0.
input int      InpMagicNumber       = 1001;

// Comentario gravado nas novas ordens do SENTINEL.
// RED acrescenta automaticamente " RED" ao final.
input string   InpOrderComment      = "SENTINEL";
input double   InpDefaultLots       = 0.02;

input double   InpTargetPoints     = 32000.0;
input double   InpStopPoints       = 32000.0;
input double   InpPointsStep        = 5.0;
input double   InpMinimumPoints     = 1.0;

// Passo dos botoes TAKE/STOP por ativo.
input double   InpLevelStepDefault = 5.0;
input double   InpLevelStepXAUUSD  = 2000.0;
input double   InpLevelStepBTCUSD  = 2000.0;

//====================================================================
// PASSO DOS NIVEIS POR ATIVO
//====================================================================

double GetLevelStepPoints()
{
   string symbol = Symbol();
   string upper  = symbol;
   StringToUpper(upper);

   // Aceita nomes como XAUUSD, XAUUSDm, XAUUSD.a, BTCUSD, BTCUSDm etc.
   if(StringFind(upper,"XAUUSD",0)>=0)
      return MathMax(0.1,InpLevelStepXAUUSD);

   if(StringFind(upper,"BTCUSD",0)>=0)
      return MathMax(0.1,InpLevelStepBTCUSD);

   return MathMax(0.1,InpLevelStepDefault);
}


input bool     InpAutoCloseTarget   = false;
input bool     InpAutoCloseStop     = false;

input int      InpSlippage          = 30;

//====================================================================
// ATR — CONTEXTO OPERACIONAL (INFORMATIVO)
//====================================================================

input bool     InpShowATRContext      = true;
input int      InpATRPeriod           = 14;
input double   InpATRLowFactor        = 0.70;
input double   InpATRHighFactor       = 1.30;


//====================================================================
// LIBERACAO DE NOVA ENTRADA — THRESHOLD M5
//====================================================================
// A leitura estrutural/score continua no InpEntryTF (M15 por padrao).
// A LIBERACAO de uma nova parcela, entretanto, usa obrigatoriamente
// ATR(14) do M5, barra fechada shift 1, com multiplicador 1.50.
//
// BUY adicional:
//   ASK deve estar >= ATR(M5)*1.50 abaixo da MENOR BUY aberta.
//
// SELL adicional:
//   BID deve estar >= ATR(M5)*1.50 acima da MAIOR SELL aberta.
//
// Primeira ordem do lado: liberada, pois ainda nao existe escada
// para medir a distancia.
//====================================================================

input bool             InpUseATRPositionGate = true;
input ENUM_TIMEFRAMES  InpATRTimeframe       = PERIOD_M5;
input int              InpATRShift           = 1;
input double           InpATRMultiplier      = 1.50;


//====================================================================
// ENTRY ENGINE — NOVA ENTRADA
//====================================================================

input bool     InpShowEntryEngine      = true;
input ENUM_TIMEFRAMES InpEntryTF       = PERIOD_M15;
input bool     InpUseM5Confirmation    = true;
input double   InpMinEntrySpacingATR   = 0.50;
input bool     InpUseEntrySpacing      = true;
input int      InpEntryCooldownMinutes = 0;


//====================================================================
// ENTRY ENGINE — NOVA ENTRADA COMPRADA
//====================================================================

//====================================================================
// ENTRY ENGINE — ESTADO
//====================================================================

int    g_entryScore         = 0;
string g_entryContext       = "SEM DADOS";
string g_entryQuality       = "AGUARDAR";
string g_entryAction        = "AGUARDAR";
double g_entryATRPoints     = 0.0;
double g_entryATRReference  = 0.0;
double g_entryDistanceLast  = 0.0;
bool   g_entrySpacingOK     = true;
bool   g_entryConfirmed     = false;

double g_m5GateATRPoints     = 0.0;
double g_m5GateRequired      = 0.0;
double g_m5BuyDistance       = 0.0;
double g_m5SellDistance      = 0.0;
bool   g_m5BuyAllowed        = true;
bool   g_m5SellAllowed       = true;

//====================================================================
// OBJETOS DO ENTRY ENGINE
//====================================================================

#define OBJ_LBL_ENTRY_CONTEXT  "SENTINEL_LBL_ENTRY_CONTEXT"
#define OBJ_LBL_ENTRY_SIGNAL   "SENTINEL_LBL_ENTRY_SIGNAL"
#define OBJ_LBL_ENTRY_SCORE    "SENTINEL_LBL_ENTRY_SCORE"

double EntryMA(int tf,int period,int shift)
{
   return iMA(
      Symbol(),
      tf,
      period,
      0,
      MODE_SMA,
      PRICE_CLOSE,
      shift
   );
}

double EntryATR(int tf,int period,int shift)
{
   return iATR(
      Symbol(),
      tf,
      period,
      shift
   );
}

double EntryRSI(int tf,int shift)
{
   return iRSI(
      Symbol(),
      tf,
      14,
      PRICE_CLOSE,
      shift
   );
}

double EntryBBUpper(int tf,int shift)
{
   return iBands(
      Symbol(),
      tf,
      20,
      2.0,
      0,
      PRICE_CLOSE,
      MODE_UPPER,
      shift
   );
}

double EntryBBMiddle(int tf,int shift)
{
   return iBands(
      Symbol(),
      tf,
      20,
      2.0,
      0,
      PRICE_CLOSE,
      MODE_MAIN,
      shift
   );
}

double EntryBBLower(int tf,int shift)
{
   return iBands(
      Symbol(),
      tf,
      20,
      2.0,
      0,
      PRICE_CLOSE,
      MODE_LOWER,
      shift
   );
}

bool EntryMABullSlope(int tf,int period)
{
   double a=EntryMA(tf,period,1);
   double b=EntryMA(tf,period,2);

   return (a>b);
}

bool EntryMABearSlope(int tf,int period)
{
   double a=EntryMA(tf,period,1);
   double b=EntryMA(tf,period,2);

   return (a<b);
}

double EntryATRReference(int tf)
{
   int bars=iBars(Symbol(),tf);

   if(bars<=InpATRPeriod+2)
      return 0.0;

   int samples=MathMin(50,bars-InpATRPeriod-1);

   if(samples<1)
      return 0.0;

   double sum=0.0;
   int used=0;

   for(int i=2;i<samples+2;i++)
   {
      double a=EntryATR(
         tf,
         InpATRPeriod,
         i
      );

      if(a<=0.0)
         continue;

      sum+=a;
      used++;
   }

   if(used<=0)
      return 0.0;

   return sum/used;
}

string EntryClassifyContext(
   bool ma9Up,
   bool ma21Up,
   bool ma34Up,
   bool ma21Below34,
   bool priceAbove34,
   bool priceAbove21,
   bool stretched,
   bool compression,
   bool transition)
{
   if(ma21Below34 && !ma34Up)
      return "BAIXA ESTRUTURAL";

   if(transition)
      return "TRANSICAO";

   if(stretched)
      return "ALTA ESTICADA";

   if(compression)
      return "EQUILIBRIO";

   if(ma9Up && ma21Up && ma34Up && priceAbove34)
      return "ALTA ESTRUTURAL";

   if(ma21Up && ma34Up && priceAbove34)
      return "ALTA EM PULLBACK";

   return "REVERSAO INCERTA";
}

double EntryClampScore(double value)
{
   if(value<0.0)
      return 0.0;

   if(value>100.0)
      return 100.0;

   return value;
}

double EntryLastBuyPrice()
{
   datetime latest=0;
   double price=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()!=OP_BUY)
         continue;

      if(OrderOpenTime()>=latest)
      {
         latest=OrderOpenTime();
         price=OrderOpenPrice();
      }
   }

   return price;
}

datetime EntryLastBuyTime()
{
   datetime latest=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()!=OP_BUY)
         continue;

      if(OrderOpenTime()>latest)
         latest=OrderOpenTime();
   }

   return latest;
}

bool EntrySpacingOK(
   double closePrice,
   double atr)
{
   g_entryDistanceLast=0.0;

   if(!InpUseEntrySpacing)
      return true;

   double last=EntryLastBuyPrice();

   if(last<=0.0 || atr<=0.0)
      return true;

   g_entryDistanceLast=
      (double)MathAbs(closePrice-last);

   double minimum=
      atr*InpMinEntrySpacingATR;

   return (g_entryDistanceLast>=minimum);
}

bool EntryCooldownOK()
{
   if(InpEntryCooldownMinutes<=0)
      return true;

   datetime last=EntryLastBuyTime();

   if(last<=0)
      return true;

   return (
      (TimeCurrent()-last) >=
      InpEntryCooldownMinutes*60
   );
}

//====================================================================
// ENTRY GATE — ATR M5
//====================================================================

double GetM5GateATRPoints()
{
   double point=AssetPoint();

   if(point<=0.0)
      return 0.0;

   int shift=MathMax(1,InpATRShift);

   double atr=iATR(
      Symbol(),
      InpATRTimeframe,
      InpATRPeriod,
      shift
   );

   if(atr<=0.0)
      return 0.0;

   return atr/point;
}

double GetM5GateRequiredPoints()
{
   double atrPoints=GetM5GateATRPoints();

   if(atrPoints<=0.0)
      return 0.0;

   return atrPoints*MathMax(
      0.0,
      InpATRMultiplier
   );
}

double GetLowestBuyOpenPriceEntry()
{
   double lowest=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()!=OP_BUY)
         continue;

      double price=OrderOpenPrice();

      if(lowest<=0.0 || price<lowest)
         lowest=price;
   }

   return lowest;
}

double GetHighestSellOpenPriceEntry()
{
   double highest=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()!=OP_SELL)
         continue;

      double price=OrderOpenPrice();

      if(highest<=0.0 || price>highest)
         highest=price;
   }

   return highest;
}

bool IsM5BuyEntryAllowed()
{
   g_m5BuyDistance=0.0;

   if(!InpUseATRPositionGate)
      return true;

   double buyLots=GetBuyLots();

   // Primeira BUY: nao existe escada para medir distancia.
   if(buyLots<=0.00000001)
      return true;

   double lowestBuy=GetLowestBuyOpenPriceEntry();

   if(lowestBuy<=0.0)
      return false;

   double required=GetM5GateRequiredPoints();

   if(required<=0.0)
      return false;

   RefreshRates();

   double point=AssetPoint();

   if(point<=0.0)
      return false;

   g_m5BuyDistance=
      (lowestBuy-Ask)/point;

   return (
      g_m5BuyDistance+0.00000001>=
      required
   );
}

bool IsM5SellEntryAllowed()
{
   g_m5SellDistance=0.0;

   if(!InpUseATRPositionGate)
      return true;

   double sellLots=GetSellLots();

   // Primeira SELL: nao existe escada para medir distancia.
   if(sellLots<=0.00000001)
      return true;

   double highestSell=GetHighestSellOpenPriceEntry();

   if(highestSell<=0.0)
      return false;

   double required=GetM5GateRequiredPoints();

   if(required<=0.0)
      return false;

   RefreshRates();

   double point=AssetPoint();

   if(point<=0.0)
      return false;

   g_m5SellDistance=
      (Bid-highestSell)/point;

   return (
      g_m5SellDistance+0.00000001>=
      required
   );
}

void UpdateM5EntryThreshold()
{
   g_m5GateATRPoints=GetM5GateATRPoints();
   g_m5GateRequired=GetM5GateRequiredPoints();

   g_m5BuyAllowed=IsM5BuyEntryAllowed();
   g_m5SellAllowed=IsM5SellEntryAllowed();
}

void CalculateEntryEngine()
{
   g_entryScore=0;
   g_entryContext="SEM DADOS";
   g_entryQuality="AGUARDAR";
   g_entryAction="AGUARDAR";
   g_entryATRPoints=0.0;
   g_entryATRReference=0.0;
   g_entryDistanceLast=0.0;
   g_entrySpacingOK=true;
   g_entryConfirmed=false;

   g_m5GateATRPoints=0.0;
   g_m5GateRequired=0.0;
   g_m5BuyDistance=0.0;
   g_m5SellDistance=0.0;
   g_m5BuyAllowed=true;
   g_m5SellAllowed=true;

   if(!InpShowEntryEngine)
      return;

   int tf=(int)InpEntryTF;

   if(iBars(Symbol(),tf)<100)
      return;

   // SOMENTE VELAS FECHADAS.
   int s=1;

   double close=iClose(
      Symbol(),
      tf,
      s
   );

   double high=iHigh(
      Symbol(),
      tf,
      s
   );

   double low=iLow(
      Symbol(),
      tf,
      s
   );

   double open=iOpen(
      Symbol(),
      tf,
      s
   );

   double ma9=EntryMA(tf,9,s);
   double ma21=EntryMA(tf,21,s);
   double ma34=EntryMA(tf,34,s);

   double ma9Prev=EntryMA(tf,9,2);
   double ma21Prev=EntryMA(tf,21,2);
   double ma34Prev=EntryMA(tf,34,2);

   double atr=EntryATR(
      tf,
      InpATRPeriod,
      s
   );

   double atrRef=EntryATRReference(tf);

   double upper=EntryBBUpper(tf,s);
   double middle=EntryBBMiddle(tf,s);
   double lower=EntryBBLower(tf,s);

   double rsi=EntryRSI(tf,s);

   if(close<=0.0 ||
      ma9<=0.0 ||
      ma21<=0.0 ||
      ma34<=0.0 ||
      atr<=0.0)
      return;

   g_entryATRPoints=
      (double)(atr/AssetPoint());

   g_entryATRReference=
      (double)(atrRef/AssetPoint());

   //===============================================================
   // ESTRUTURA — 30
   //===============================================================

   bool ma9Up=(ma9>ma9Prev);
   bool ma21Up=(ma21>ma21Prev);
   bool ma34Up=(ma34>ma34Prev);

   bool ma21Below34=(ma21<ma34);
   bool priceAbove34=(close>ma34);
   bool priceAbove21=(close>ma21);

   if(ma34Up)
      g_entryScore+=15;

   if(ma21Up)
      g_entryScore+=10;

   if(priceAbove34)
      g_entryScore+=5;

   //===============================================================
   // LOCALIZACAO — 25
   //===============================================================

   double d21=MathAbs(close-ma21);
   double d34=MathAbs(close-ma34);

   bool near21=(d21<=atr*0.50);
   bool near34=(d34<=atr*0.60);

   if(near21)
      g_entryScore+=10;

   if(near34)
      g_entryScore+=15;

   // Preco muito acima das medias: penalizacao por esticamento.
   bool stretched=
      (close>ma21+atr*1.20) ||
      (close>ma34+atr*1.80);

   if(stretched)
      g_entryScore-=12;

   //===============================================================
   // BOLLINGER / COMPRESSAO
   //===============================================================

   double bandWidth=upper-lower;

   bool compression=
      (atrRef>0.0 &&
       atr<atrRef*InpATRLowFactor) ||
      (bandWidth>0.0 &&
       bandWidth<=atr*1.60);

   //===============================================================
   // MOMENTUM — 15
   //===============================================================

   double rsiPrev=EntryRSI(tf,2);

   bool rsiRecover=
      (rsi>rsiPrev);

   if(rsiRecover &&
      rsi>=30.0 &&
      rsi<=55.0)
      g_entryScore+=10;

   if(rsi>=50.0 &&
      rsi<=65.0 &&
      ma21Up)
      g_entryScore+=5;

   // Penalizacao de esticamento.
   if(rsi>70.0)
      g_entryScore-=8;

   //===============================================================
   // BANDAS — 15
   //===============================================================

   bool nearMiddle=
      MathAbs(close-middle)<=atr*0.35;

   bool nearLower=
      MathAbs(close-lower)<=atr*0.35;

   if(nearMiddle)
      g_entryScore+=5;

   if(nearLower &&
      ma34Up &&
      priceAbove34)
      g_entryScore+=10;

   // Preco muito acima da banda media.
   if(close>middle+atr*1.0)
      g_entryScore-=5;

   //===============================================================
   // VOLATILIDADE — 15
   //===============================================================

   if(atrRef>0.0)
   {
      if(atr<=atrRef*1.20 &&
         atr>=atrRef*0.70)
         g_entryScore+=10;

      if(atr>atrRef*1.20 &&
         close>open)
         g_entryScore+=5;

      if(atr>atrRef*1.80)
         g_entryScore-=8;
   }

   //===============================================================
   // CONFIRMACAO DA VELA
   //===============================================================
   //
   // Confirmacao NAO aumenta o score. O score permanece exatamente
   // na estrutura 30 + 25 + 15 + 15 + 15 = 100.
   // A confirmacao funciona como condicao final para liberar A/B.
   //===============================================================

   double range=high-low;

   bool bullishClose=
      (range>0.0 &&
       close>open &&
       close>=low+range*0.60);

   bool recoverMA9=
      (close>ma9);

   bool m5Confirmed=true;

   // M5 usa somente velas fechadas.
   if(InpUseM5Confirmation)
   {
      double m5Close=iClose(
         Symbol(),
         PERIOD_M5,
         1
      );

      double m5MA9=EntryMA(
         PERIOD_M5,
         9,
         1
      );

      double m5MA21=EntryMA(
         PERIOD_M5,
         21,
         1
      );

      double m5ClosePrev=iClose(
         Symbol(),
         PERIOD_M5,
         2
      );

      m5Confirmed=
         (m5Close>m5MA9 &&
          m5Close>m5ClosePrev &&
          m5Close>m5MA21);
   }

   g_entryConfirmed=
      bullishClose &&
      recoverMA9 &&
      m5Confirmed;

   //===============================================================
   // CLASSIFICACAO DE CONTEXTO
   //===============================================================

   bool transition=
      (ma9<ma21 && ma21>ma34) ||
      (ma9>ma21 && ma21<ma34);

   g_entryContext=
      EntryClassifyContext(
         ma9Up,
         ma21Up,
         ma34Up,
         ma21Below34,
         priceAbove34,
         priceAbove21,
         stretched,
         compression,
         transition
      );

   //===============================================================
   // PENALIZACOES ESTRUTURAIS
   //===============================================================

   if(g_entryContext=="BAIXA ESTRUTURAL")
      g_entryScore-=20;

   if(g_entryContext=="REVERSAO INCERTA")
      g_entryScore-=8;

   if(g_entryContext=="ALTA ESTICADA")
      g_entryScore-=8;

   if(g_entryContext=="EQUILIBRIO" &&
      !near21 &&
      !near34)
      g_entryScore-=5;

   // Nao permitir pontuacao fora da escala.
   g_entryScore=(int)MathRound(
      EntryClampScore((double)g_entryScore)
   );

   //===============================================================
   // THRESHOLD DE NOVA ENTRADA — M5
   //===============================================================
   //
   // IMPORTANTE:
   // O score pode ser calculado no M15, mas a liberacao da nova
   // parcela respeita o ATR(14) M5 * 1.50 da regra original.
   //===============================================================

   UpdateM5EntryThreshold();

   // Para compatibilidade visual com o Entry Engine, "spacing" passa
   // a representar o threshold real de distancia do M5.
   g_entrySpacingOK=
      g_m5BuyAllowed;

   bool cooldownOK=
      EntryCooldownOK();

   //===============================================================
   // QUALIDADE
   //===============================================================

   if(g_entryScore>=80)
      g_entryQuality="A";
   else if(g_entryScore>=65)
      g_entryQuality="B";
   else if(g_entryScore>=50)
      g_entryQuality="AGUARDAR";
   else
      g_entryQuality="DESCARTAR";

   //===============================================================
   // ACAO
   //===============================================================

   if(g_entryContext=="BAIXA ESTRUTURAL" ||
      g_entryContext=="REVERSAO INCERTA")
   {
      g_entryAction="NAO ADICIONAR";
   }
   else if(g_entryQuality=="A")
   {
      if(!g_entryConfirmed)
         g_entryAction="AGUARDAR CONFIRMACAO";
      else if(g_m5BuyAllowed && cooldownOK)
         g_entryAction="NOVA ENTRADA A";
      else
         g_entryAction="ESPERAR M5";
   }
   else if(g_entryQuality=="B")
   {
      if(!g_entryConfirmed)
         g_entryAction="AGUARDAR CONFIRMACAO";
      else if(g_m5BuyAllowed && cooldownOK)
         g_entryAction="NOVA ENTRADA B";
      else
         g_entryAction="ESPERAR M5";
   }
   else if(g_entryQuality=="AGUARDAR")
   {
      g_entryAction="AGUARDAR";
   }
   else
   {
      g_entryAction="NAO ADICIONAR";
   }
}

color EntryActionColor()
{
   if(g_entryAction=="NOVA ENTRADA A")
      return clrLimeGreen;

   if(g_entryAction=="NOVA ENTRADA B")
      return clrGreenYellow;

   if(g_entryAction=="AGUARDAR" ||
      g_entryAction=="AGUARDAR CONFIRMACAO" ||
      g_entryAction=="ESPERAR ESPACO" ||
      g_entryAction=="ESPERAR M5")
      return clrGold;

   if(g_entryAction=="NAO ADICIONAR" ||
      g_entryAction=="DESCARTAR")
      return clrTomato;

   return clrSilver;
}


void UpdateEntryEnginePanel()
{
   if(!InpShowEntryEngine)
   {
      DeleteObjectSafe(OBJ_LBL_ENTRY_CONTEXT);
      DeleteObjectSafe(OBJ_LBL_ENTRY_SIGNAL);
      DeleteObjectSafe(OBJ_LBL_ENTRY_SCORE);
      return;
   }

   CalculateEntryEngine();

   UpdateLabel(
      OBJ_LBL_ENTRY_CONTEXT,
      "CONTEXTO: "+g_entryContext,
      clrSilver
   );

   UpdateLabel(
      OBJ_LBL_ENTRY_SIGNAL,
      g_entryAction,
      EntryActionColor()
   );

   string scoreText=
      "NOVA: "+
      IntegerToString(g_entryScore)+
      "  |  "+
      g_entryQuality;

   if(!g_entryConfirmed &&
      (g_entryQuality=="A" ||
       g_entryQuality=="B"))
      scoreText+=" | CONF";

   if(!g_m5BuyAllowed &&
      (g_entryQuality=="A" ||
       g_entryQuality=="B"))
      scoreText+=" | M5";

   UpdateLabel(
      OBJ_LBL_ENTRY_SCORE,
      scoreText,
      clrSilver
   );
}

//====================================================================
// ATR — CONTEXTO OPERACIONAL (INFORMATIVO)
//====================================================================
// O ATR serve como indicador de contexto. Ele NAO bloqueia BUY/SELL.
// A leitura usa o timeframe atual do grafico.
//====================================================================

//====================================================================
// ENTRY ENGINE — NOVA ENTRADA COMPRADA
//====================================================================
// Baseado na especificacao fornecida:
// ESTRUTURA -> LOCALIZACAO -> MOMENTUM -> VOLATILIDADE -> CONFIRMACAO
//
// Importante:
// - analisa somente velas fechadas (shift >= 1);
// - nao envia ordens;
// - nao bloqueia o botao COMPRAR;
// - serve como indicacao de que uma nova parcela de 0.01 lote
//   pode ser considerada.
//====================================================================

//====================================================================
// CORES
//====================================================================

//====================================================================
// POSICAO DO PAINEL
//====================================================================
// 0 = superior esquerdo
// 1 = superior direito
// 2 = inferior esquerdo
// 3 = inferior direito
input ENUM_BASE_CORNER InpPanelCorner = CORNER_LEFT_UPPER;

input int InpPanelWidth  = 300;
input int InpPanelHeight = 500;

input color InpPanelColor     = clrBlack;
input color InpBuyColor       = clrDodgerBlue;
input color InpSellColor      = clrRed;
input color InpProfitColor    = clrLimeGreen;

// Cores independentes dos precos medios reais.
input color InpBuyAverageColor  = clrLimeGreen;
input color InpSellAverageColor = clrTomato;

input color InpBEColor        = clrOrange;

//====================================================================
// MEDIO REAL + MEDIO PROJETADO
//====================================================================

// Mostra as linhas projetadas a partir do lote selecionado na boleta.
input bool  InpShowProjectedAverage = true;

// Cores das projeções. Deixamos separadas para permitir ajuste visual.
input color InpProjectedBuyColor  = clrAqua;
input color InpProjectedSellColor = clrMagenta;

// A projeção usa uma linha curta, na mesma filosofia visual do BE.
// Comprimento direto da linha projetada em pixels.
// Isso deixa a referencia pequena e previsivel, independentemente
// da largura/zoom do grafico.
input int   InpProjectedLinePixels = 45;

// Espessura das linhas projetadas.
input int   InpProjectedLineWidth = 1;

input color InpTakeColor      = clrLimeGreen;
input color InpStopColor      = clrRed;

//====================================================================
// PREFIXO
//====================================================================

#define PREFIX "SENTINEL_"
//====================================================================
// OBJETOS DO PAINEL
//====================================================================

#define OBJ_PANEL              PREFIX+"PANEL"

#define OBJ_LBL_TITLE          PREFIX+"LBL_TITLE"
#define OBJ_LBL_SYMBOL         PREFIX+"LBL_SYMBOL"
#define OBJ_LBL_MAGIC          PREFIX+"LBL_MAGIC"

#define OBJ_LBL_BUY            PREFIX+"LBL_BUY"
#define OBJ_LBL_SELL           PREFIX+"LBL_SELL"
#define OBJ_LBL_NET            PREFIX+"LBL_NET"
#define OBJ_LBL_EXPOSURE       PREFIX+"LBL_EXPOSURE"

#define OBJ_LBL_REALIZED       PREFIX+"LBL_REALIZED"
#define OBJ_LBL_OPEN           PREFIX+"LBL_OPEN"

#define OBJ_LBL_REDUCE         PREFIX+"LBL_REDUCE"

#define OBJ_LBL_TARGET_MONEY   PREFIX+"LBL_TARGET_MONEY"
#define OBJ_LBL_STOP_MONEY     PREFIX+"LBL_STOP_MONEY"


#define OBJ_EDIT_LOTS          PREFIX+"EDIT_LOTS"

#define OBJ_BTN_LOTS_MINUS_10  PREFIX+"BTN_LOTS_MINUS_10"
#define OBJ_BTN_LOTS_MINUS_1   PREFIX+"BTN_LOTS_MINUS_1"
#define OBJ_BTN_LOTS_PLUS_1    PREFIX+"BTN_LOTS_PLUS_1"
#define OBJ_BTN_LOTS_PLUS_10   PREFIX+"BTN_LOTS_PLUS_10"

#define OBJ_EDIT_TARGET        PREFIX+"EDIT_TARGET"
#define OBJ_EDIT_STOP          PREFIX+"EDIT_STOP"

#define OBJ_BTN_BUY            PREFIX+"BTN_BUY"
#define OBJ_BTN_SELL           PREFIX+"BTN_SELL"

#define OBJ_BTN_REDUCE_BUY_WIN     PREFIX+"BTN_REDUCE_BUY_WIN"
#define OBJ_BTN_REDUCE_BUY_LOSS    PREFIX+"BTN_REDUCE_BUY_LOSS"
#define OBJ_BTN_REDUCE_SELL_WIN    PREFIX+"BTN_REDUCE_SELL_WIN"
#define OBJ_BTN_REDUCE_SELL_LOSS   PREFIX+"BTN_REDUCE_SELL_LOSS"
#define OBJ_BTN_REDUCE_BOTH        PREFIX+"BTN_REDUCE_BOTH"

#define OBJ_BTN_CLOSE_ALL      PREFIX+"BTN_CLOSE_ALL"
#define OBJ_BTN_RED             PREFIX+"BTN_RED"

#define OBJ_BTN_TARGET_MINUS   PREFIX+"BTN_TARGET_MINUS"
#define OBJ_BTN_TARGET_PLUS    PREFIX+"BTN_TARGET_PLUS"
#define OBJ_BTN_STOP_MINUS     PREFIX+"BTN_STOP_MINUS"
// REGRA STOP v1.47:
// '+' aproxima o STOP do preço atual (reduz a distância em pontos).
// '-' afasta o STOP do preço atual (aumenta a distância em pontos).
// STOP NEGATIVO = nivel acima do medio para BUY ou abaixo do medio para SELL.
// Isso permite BE e trailing stop manual com os botoes/linha.
#define OBJ_BTN_STOP_PLUS      PREFIX+"BTN_STOP_PLUS"

#define OBJ_EDIT_SELECTED_1   PREFIX+"EDIT_SELECTED_1"
#define OBJ_EDIT_SELECTED_2   PREFIX+"EDIT_SELECTED_2"
#define OBJ_LBL_SELECTED_1    PREFIX+"LBL_SELECTED_1"
#define OBJ_LBL_SELECTED_2    PREFIX+"LBL_SELECTED_2"
#define OBJ_LBL_SELECTED_CALC PREFIX+"LBL_SELECTED_CALC"
#define OBJ_LBL_SELECTED_EXPOSURE PREFIX+"LBL_SELECTED_EXPOSURE"
#define OBJ_BTN_REDUCE_SELECTED PREFIX+"BTN_REDUCE_SELECTED"
#define OBJ_BTN_CLEAR_SELECTED PREFIX+"BTN_CLEAR_SELECTED"

#define OBJ_LBL_STATUS         PREFIX+"LBL_STATUS"
#define OBJ_LBL_CHART_PROFIT   PREFIX+"LBL_CHART_PROFIT"

#define OBJ_LBL_ATR              PREFIX+"LBL_ATR"
#define OBJ_LBL_ATR_REGIME       PREFIX+"LBL_ATR_REGIME"
#define OBJ_LBL_SIGNAL_BUY       PREFIX+"LBL_SIGNAL_BUY"
#define OBJ_LBL_SIGNAL_SELL      PREFIX+"LBL_SIGNAL_SELL"

//====================================================================
// OBJETOS DO GRAFICO
//====================================================================

#define OBJ_LINE_AVG_BUY        PREFIX+"LINE_AVG_BUY"
#define OBJ_LINE_AVG_SELL       PREFIX+"LINE_AVG_SELL"
#define OBJ_LINE_PROJ_BUY       PREFIX+"LINE_PROJ_BUY"
#define OBJ_LINE_PROJ_SELL      PREFIX+"LINE_PROJ_SELL"
#define OBJ_LINE_BE             PREFIX+"LINE_BE"

#define OBJ_TXT_PROJ_BUY        PREFIX+"TXT_PROJ_BUY"
#define OBJ_TXT_PROJ_SELL       PREFIX+"TXT_PROJ_SELL"
#define OBJ_TXT_BE              PREFIX+"TXT_BE"

//====================================================================
// TAKE / STOP
//====================================================================

#define OBJ_LINE_TARGET       PREFIX+"LINE_TARGET"
#define OBJ_LINE_STOP         PREFIX+"LINE_STOP"

#define OBJ_TXT_TARGET        PREFIX+"TXT_TARGET"
#define OBJ_TXT_STOP          PREFIX+"TXT_STOP"
#define LEVEL_BOX_WIDTH        105
#define LEVEL_BOX_HEIGHT       52
#define LEVEL_RIGHT_MARGIN     20
#define LEVEL_LABEL_GAP        10
#define LEVEL_LABEL_Y_OFFSET   22


//====================================================================
// VARIAVEIS
//====================================================================

double g_targetMoney = 0.0;   // resultado estimado no nivel, apenas informativo
double g_stopMoney   = 0.0;   // resultado estimado no nivel, apenas informativo

// Lote selecionado no painel. Persistido por simbolo + magic para
// sobreviver a troca de timeframe, reinicializacao e troca de grafico.
double g_selectedLots = 0.0;

double g_targetPoints = 0.0;
double g_stopPoints   = 0.0;

double g_targetPrice = 0.0;
double g_stopPrice   = 0.0;

bool g_targetUserSet = false;
bool g_stopUserSet   = false;

bool g_processing = false;

// Feedback visual dos botoes REDUCE.
// Verde = reducao executada; vermelho = reducao nao executada.
// Depois de 2 segundos, retorna a cor original.
string g_reduceFeedbackButton = "";
datetime g_reduceFeedbackUntil = 0;
color g_reduceFeedbackNormal = clrNONE;


// Protecao contra fechamento involuntario na inicializacao/troca de ativo.
datetime g_autoCloseBlockedUntil = 0;

bool g_targetAutoArmed = false;
bool g_stopAutoArmed   = false;

// Estado original do grafico.
// Quando CHART_FOREGROUND=true, o MT4 pode desenhar as velas
// por cima dos objetos. Para o painel funcionar como overlay,
// desligamos temporariamente essa opcao e restauramos no deinit.
bool g_chartForegroundOriginal = false;
bool g_chartForegroundCaptured = false;

//====================================================================
// CONTROLE DA CESTA
//====================================================================

bool   g_basketActive         = false;
double g_basketBaseHistory    = 0.0;
double g_basketReduceExcluded = 0.0;
bool g_selectedPlanValid=false;
int  g_selectedTargetTicket=-1;
int  g_selectedReferenceTicket=-1;
double g_selectedTargetLots=0.0;
double g_selectedReferenceLots=0.0;
double g_selectedTargetResult=0.0;
double g_selectedReferenceResult=0.0;
double g_selectedReduceLots=0.0;

string SelectedGlobalPrefix()
{
   return PREFIX+
          "SELECTED_"+
          Symbol()+
          "_"+
          IntegerToString(InpMagicNumber)+
          "_";
}

string SelectedGlobalName(int slot)
{
   return SelectedGlobalPrefix()+
          IntegerToString(slot);
}

int GetSelectedTicket(int slot)
{
   if(slot<1 || slot>2)
      return -1;

   string name=SelectedGlobalName(slot);

   if(!GlobalVariableCheck(name))
      return -1;

   int ticket=(int)GlobalVariableGet(name);

   if(ticket<=0)
      return -1;

   return ticket;
}

void ClearSelectedTickets()
{
   GlobalVariableSet(SelectedGlobalName(1),0.0);
   GlobalVariableSet(SelectedGlobalName(2),0.0);
   GlobalVariablesFlush();
}

bool GetSelectedOrderSnapshot(
   int ticket,
   int &type,
   double &lots,
   double &result)
{
   type=-1;
   lots=0.0;
   result=0.0;

   if(ticket<=0)
      return false;

   if(!OrderSelect(
      ticket,
      SELECT_BY_TICKET,
      MODE_TRADES))
      return false;

   if(!IsOurOrder())
      return false;

   type=OrderType();

   if(type!=OP_BUY && type!=OP_SELL)
      return false;

   lots=OrderLots();

   result=
      OrderProfit()+
      OrderSwap()+
      OrderCommission();

   return lots>0.0;
}

bool BuildSelectedReductionPlan()
{
   g_selectedPlanValid=false;
   g_selectedTargetTicket=-1;
   g_selectedReferenceTicket=-1;
   g_selectedTargetLots=0.0;
   g_selectedReferenceLots=0.0;
   g_selectedTargetResult=0.0;
   g_selectedReferenceResult=0.0;
   g_selectedReduceLots=0.0;

   int ticket1=GetSelectedTicket(1);
   int ticket2=GetSelectedTicket(2);

   if(ticket1<=0)
      return false;

   int type1=-1;
   int type2=-1;
   double lots1=0.0;
   double lots2=0.0;
   double result1=0.0;
   double result2=0.0;

   if(!GetSelectedOrderSnapshot(
      ticket1,
      type1,
      lots1,
      result1))
      return false;

   if(ticket2<=0)
   {
      g_selectedTargetTicket=ticket1;
      g_selectedTargetLots=lots1;
      g_selectedTargetResult=result1;
   }
   else
   {
      if(!GetSelectedOrderSnapshot(
         ticket2,
         type2,
         lots2,
         result2))
         return false;

      // Uma WIN e uma LOSS: a LOSS e o alvo.
      if(result1>0.00000001 &&
         result2<-0.00000001)
      {
         g_selectedTargetTicket=ticket2;
         g_selectedReferenceTicket=ticket1;
         g_selectedTargetLots=lots2;
         g_selectedReferenceLots=lots1;
         g_selectedTargetResult=result2;
         g_selectedReferenceResult=result1;
      }
      else
      if(result2>0.00000001 &&
         result1<-0.00000001)
      {
         g_selectedTargetTicket=ticket1;
         g_selectedReferenceTicket=ticket2;
         g_selectedTargetLots=lots1;
         g_selectedReferenceLots=lots2;
         g_selectedTargetResult=result1;
         g_selectedReferenceResult=result2;
      }
      // Duas WIN: reduz a menor ordem; a maior permanece aberta.
      else
      if(result1>0.00000001 &&
         result2>0.00000001)
      {
         if(lots1<=lots2)
         {
            g_selectedTargetTicket=ticket1;
            g_selectedReferenceTicket=ticket2;
            g_selectedTargetLots=lots1;
            g_selectedReferenceLots=lots2;
            g_selectedTargetResult=result1;
            g_selectedReferenceResult=result2;
         }
         else
         {
            g_selectedTargetTicket=ticket2;
            g_selectedReferenceTicket=ticket1;
            g_selectedTargetLots=lots2;
            g_selectedReferenceLots=lots1;
            g_selectedTargetResult=result2;
            g_selectedReferenceResult=result1;
         }
      }
      else
      {
         // Duas LOSS nao sao uma operacao de reducao dirigida valida.
         return false;
      }
   }

   double requested=
      NormalizeLots(
         g_selectedLots
      );

   if(requested<=0.0)
      return false;

   g_selectedReduceLots=
      NormalizeLots(
         MathMin(
            requested,
            g_selectedTargetLots
         )
      );

   if(g_selectedReduceLots<=0.0)
      return false;

   g_selectedPlanValid=true;
   return true;
}

string SelectedTypeText(int ticket)
{
   int type=-1;
   double lots=0.0;
   double result=0.0;

   if(!GetSelectedOrderSnapshot(
      ticket,
      type,
      lots,
      result))
      return "INVALIDA";

   return type==OP_BUY ? "BUY" : "SELL";
}

void UpdateSelectedReductionPanel()
{
   int ticket1=GetSelectedTicket(1);
   int ticket2=GetSelectedTicket(2);

   string t1=ticket1>0 ?
      IntegerToString(ticket1) :
      "--";

   string t2=ticket2>0 ?
      IntegerToString(ticket2) :
      "--";

   if(ObjectFind(0,OBJ_EDIT_SELECTED_1)>=0)
      ObjectSetString(
         0,
         OBJ_EDIT_SELECTED_1,
         OBJPROP_TEXT,
         t1
      );

   if(ObjectFind(0,OBJ_EDIT_SELECTED_2)>=0)
      ObjectSetString(
         0,
         OBJ_EDIT_SELECTED_2,
         OBJPROP_TEXT,
         t2
      );

   bool valid=BuildSelectedReductionPlan();

   if(!valid)
   {
      UpdateLabel(
         OBJ_LBL_SELECTED_CALC,
         ticket1<=0 ?
         "SELECIONE ORDEM" :
         "SELECAO NAO ELEGIVEL",
         clrGold
      );

      UpdateLabel(
         OBJ_LBL_SELECTED_EXPOSURE,
         "RED: -- | EXP: -- -> --",
         clrSilver
      );

      if(ObjectFind(0,OBJ_BTN_REDUCE_SELECTED)>=0)
      {
         ObjectSetInteger(
            0,
            OBJ_BTN_REDUCE_SELECTED,
            OBJPROP_BGCOLOR,
            clrDimGray
         );

         ObjectSetString(
            0,
            OBJ_BTN_REDUCE_SELECTED,
            OBJPROP_TEXT,
            "REDUCE SELECIONADO"
         );
      }

      return;
   }

   double buyBefore=GetBuyLots();
   double sellBefore=GetSellLots();
   double exposureBefore=buyBefore+sellBefore;

   double buyAfter=buyBefore;
   double sellAfter=sellBefore;

   int targetType=-1;
   double tmpLots=0.0;
   double tmpResult=0.0;

   GetSelectedOrderSnapshot(
      g_selectedTargetTicket,
      targetType,
      tmpLots,
      tmpResult
   );

   if(targetType==OP_BUY)
      buyAfter-=g_selectedReduceLots;
   else
   if(targetType==OP_SELL)
      sellAfter-=g_selectedReduceLots;

   if(buyAfter<0.0) buyAfter=0.0;
   if(sellAfter<0.0) sellAfter=0.0;

   double netBefore=buyBefore-sellBefore;
   double netAfter=buyAfter-sellAfter;
   double exposureAfter=buyAfter+sellAfter;

   string targetText=
      IntegerToString(g_selectedTargetTicket)+
      " "+SelectedTypeText(g_selectedTargetTicket)+
      " "+
      DoubleToString(g_selectedTargetLots,2)+
      " -> "+
      DoubleToString(
         g_selectedTargetLots-g_selectedReduceLots,
         2
      );

   UpdateLabel(
      OBJ_LBL_SELECTED_CALC,
      "ALVO: "+targetText+
      " | RED: "+DoubleToString(g_selectedReduceLots,2),
      g_selectedTargetResult>=0.0 ?
      InpProfitColor :
      InpStopColor
   );

   UpdateLabel(
      OBJ_LBL_SELECTED_EXPOSURE,
      "NET "+
      DoubleToString(netBefore,2)+
      " -> "+
      DoubleToString(netAfter,2)+
      " | EXP "+
      DoubleToString(exposureBefore,2)+
      " -> "+
      DoubleToString(exposureAfter,2),
      clrSilver
   );

   if(ObjectFind(0,OBJ_BTN_REDUCE_SELECTED)>=0)
   {
      ObjectSetInteger(
         0,
         OBJ_BTN_REDUCE_SELECTED,
         OBJPROP_BGCOLOR,
         clrDarkGoldenrod
      );

      ObjectSetString(
         0,
         OBJ_BTN_REDUCE_SELECTED,
         OBJPROP_TEXT,
         "REDUCE "+DoubleToString(g_selectedReduceLots,2)
      );
   }
}

bool ExecuteSelectedReduction()
{
   if(!BuildSelectedReductionPlan())
   {
      SetStatus(
         "SELECAO INVALIDA",
         InpStopColor
      );
      return false;
   }

   int ticket=g_selectedTargetTicket;

   // Revalida o ticket imediatamente antes da execucao.
   if(!OrderSelect(
      ticket,
      SELECT_BY_TICKET,
      MODE_TRADES))
   {
      SetStatus(
         "TICKET NAO ENCONTRADO",
         InpStopColor
      );
      return false;
   }

   if(!IsOurOrder())
   {
      SetStatus(
         "TICKET FORA DA CESTA",
         InpStopColor
      );
      return false;
   }

   double available=OrderLots();

   double closeLots=
      NormalizeLots(
         MathMin(
            g_selectedReduceLots,
            available
         )
      );

   if(closeLots<=0.0)
   {
      SetStatus(
         "LOTE INVALIDO",
         InpStopColor
      );
      return false;
   }

   if(!PartialCloseTicket(
      ticket,
      closeLots))
   {
      SetStatus(
         "REDUCE SELECIONADO ERRO "+
         IntegerToString(GetLastError()),
         InpStopColor
      );
      return false;
   }

   SetStatus(
      "REDUCE T"+IntegerToString(ticket)+
      " "+DoubleToString(closeLots,2),
      InpProfitColor
   );

   // A operacao consumiu a selecao. O Cesta Manager continuara
   // mostrando a nova situacao da ordem.
   ClearSelectedTickets();

   return true;
}


//====================================================================
// GLOBAL DA CESTA
//====================================================================

string BasketGlobalName()
{
   return PREFIX+
          "BASE_"+
          Symbol()+
          "_"+
          IntegerToString(InpMagicNumber);
}

string BasketReduceExcludedGlobalName()
{
   return PREFIX+
          "REDUCE_EXCLUDED_"+
          Symbol()+
          "_"+
          IntegerToString(InpMagicNumber);
}

string TodayReduceExcludedGlobalName()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);

   return PREFIX+
          "REDUCE_DAY_"+
          Symbol()+
          "_"+
          IntegerToString(InpMagicNumber)+
          "_"+
          IntegerToString(dt.year)+
          IntegerToString(dt.mon,2)+
          IntegerToString(dt.day,2);
}

double GetTodayReduceExcluded()
{
   string gv=TodayReduceExcludedGlobalName();

   if(!GlobalVariableCheck(gv))
      return 0.0;

   return GlobalVariableGet(gv);
}

void AddReduceExcludedResult(double amount)
{
   if(MathAbs(amount)<=0.00000001)
      return;

   g_basketReduceExcluded+=amount;

   GlobalVariableSet(
      BasketReduceExcludedGlobalName(),
      g_basketReduceExcluded
   );

   GlobalVariableSet(
      TodayReduceExcludedGlobalName(),
      GetTodayReduceExcluded()+amount
   );
}


//====================================================================
// GLOBALS DOS NIVEIS TAKE / STOP
//
// Os pontos ficam gravados por SIMBOLO + MAGIC, independentemente do
// timeframe. Assim, ao trocar M1/M5/M15/H1, os valores da cesta atual
// permanecem os mesmos.
//====================================================================

string TargetPointsGlobalName()
{
   return PREFIX+
          "TARGET_PTS_"+
          Symbol()+
          "_"+
          IntegerToString(InpMagicNumber);
}

string StopPointsGlobalName()
{
   return PREFIX+
          "STOP_PTS_"+
          Symbol()+
          "_"+
          IntegerToString(InpMagicNumber);
}

//====================================================================
// GLOBAL DO LOTE SELECIONADO
//====================================================================

string SelectedLotsGlobalName()
{
   return PREFIX+
          "LOTS_"+
          Symbol()+
          "_"+
          IntegerToString(InpMagicNumber);
}

//====================================================================
// PERSISTENCIA DOS PARAMETROS DO PAINEL
//
// Estes valores sao CONFIGURACAO DO PAINEL, e nao propriedade do
// timeframe. Portanto permanecem mesmo sem posicoes abertas.
//====================================================================

void SavePanelSettingsToGlobals()
{
   if(g_selectedLots<=0.0)
      g_selectedLots=InpDefaultLots;

   g_selectedLots=NormalizeLots(g_selectedLots);

   if(g_selectedLots<=0.0)
      g_selectedLots=MinLot();

   GlobalVariableSet(
      SelectedLotsGlobalName(),
      g_selectedLots
   );

   if(g_targetPoints<InpMinimumPoints)
      g_targetPoints=InpMinimumPoints;

   if(g_stopPoints<InpMinimumPoints)
      g_stopPoints=InpMinimumPoints;

   GlobalVariableSet(
      TargetPointsGlobalName(),
      g_targetPoints
   );

   GlobalVariableSet(
      StopPointsGlobalName(),
      g_stopPoints
   );
}

void LoadPanelSettingsFromGlobals()
{
   // INPUTS sao somente fallback para a primeira execucao.
   // Em qualquer refresh/reload do EA, se a Global Variable existir,
   // ela tem prioridade absoluta sobre o valor do INPUT.
   double lots=NormalizeLots(InpDefaultLots);
   if(lots<=0.0)
      lots=MinLot();

   double target=MathMax(InpMinimumPoints,InpTargetPoints);
   double stop=MathMax(InpMinimumPoints,InpStopPoints);

   string lotsGV=SelectedLotsGlobalName();
   string targetGV=TargetPointsGlobalName();
   string stopGV=StopPointsGlobalName();

   if(GlobalVariableCheck(lotsGV))
   {
      double stored=GlobalVariableGet(lotsGV);
      double normalized=NormalizeLots(stored);
      if(normalized>0.0)
         lots=normalized;
   }

   if(GlobalVariableCheck(targetGV))
   {
      double stored=GlobalVariableGet(targetGV);
      if(stored>=InpMinimumPoints)
         target=stored;
   }

   if(GlobalVariableCheck(stopGV))
   {
      double stored=GlobalVariableGet(stopGV);
      if(stored>=InpMinimumPoints)
         stop=stored;
   }

   g_selectedLots=lots;
   g_targetPoints=target;
   g_stopPoints=stop;
}

void SaveLevelPointsToGlobals()
{
   // TAKE/STOP sao configuracoes persistentes do painel.
   // Nao dependem da existencia de uma cesta aberta.
   if(g_targetPoints>=InpMinimumPoints)
      GlobalVariableSet(
         TargetPointsGlobalName(),
         g_targetPoints
      );

   if(g_stopPoints>=InpMinimumPoints)
      GlobalVariableSet(
         StopPointsGlobalName(),
         g_stopPoints
      );
}

void LoadLevelPointsFromGlobals()
{
   LoadPanelSettingsFromGlobals();
}

// Nao apagar TAKE/STOP ao terminar uma cesta. Os valores sao
// preferencias persistentes do painel e devem sobreviver a troca
// de timeframe e a novas cestas.
void DeleteLevelPointsGlobals()
{
   // Intencionalmente vazio.
   // Mantido para compatibilidade com chamadas antigas.
}

//====================================================================
// NORMALIZA PRECO
//====================================================================

double NormalizePrice(double price)
{
   return NormalizeDouble(price,Digits);
}

//====================================================================
// STEP DE LOTE
//====================================================================

double LotStep()
{
   double step=MarketInfo(Symbol(),MODE_LOTSTEP);

   if(step<=0.0)
      step=0.01;

   return step;
}

//====================================================================
// MINIMO LOTE
//====================================================================

double MinLot()
{
   double value=MarketInfo(Symbol(),MODE_MINLOT);

   if(value<=0.0)
      value=0.01;

   return value;
}

//====================================================================
// MAXIMO LOTE
//====================================================================

double MaxLot()
{
   double value=MarketInfo(Symbol(),MODE_MAXLOT);

   if(value<=0.0)
      value=100.0;

   return value;
}

//====================================================================
// NORMALIZA LOTES
//====================================================================

double NormalizeLots(double lots)
{
   double step=LotStep();

   if(lots<=0.0)
      return 0.0;

   double result=
      MathFloor(
         (lots+0.00000001)/step
      )*step;

   int lotDigits=2;

   if(step>=1.0)
      lotDigits=0;
   else
   if(step>=0.1)
      lotDigits=1;
   else
   if(step>=0.01)
      lotDigits=2;
   else
      lotDigits=3;

   result=NormalizeDouble(
      result,
      lotDigits
   );

   if(result<MinLot())
      return 0.0;

   if(result>MaxLot())
      result=MaxLot();

   return result;
}

//====================================================================
// VERIFICA ORDEM DO SENTINEL
//====================================================================

bool IsOurOrder()
{
   if(OrderSymbol()!=Symbol())
      return false;

   // Magic = -1 = qualquer Magic Number do simbolo,
   // inclusive ordens manuais (Magic 0).
   if(InpMagicNumber!=-1)
   {
      if(OrderMagicNumber()!=InpMagicNumber)
         return false;
   }

   int type=OrderType();

   if(type!=OP_BUY &&
      type!=OP_SELL)
      return false;

   return true;
}

//====================================================================
// BUY LOTS
//====================================================================

double GetBuyLots()
{
   double lots=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()==OP_BUY)
         lots+=OrderLots();
   }

   return NormalizeDouble(
      lots,
      2
   );
}

//====================================================================
// SELL LOTS
//====================================================================

double GetSellLots()
{
   double lots=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()==OP_SELL)
         lots+=OrderLots();
   }

   return NormalizeDouble(
      lots,
      2
   );
}

//====================================================================
// NET
//====================================================================

double GetNetLots()
{
   return GetBuyLots()-
          GetSellLots();
}

//====================================================================
// EXPOSICAO
//====================================================================

double GetGrossLots()
{
   return GetBuyLots()+
          GetSellLots();
}

//====================================================================
// CONTAGEM
//====================================================================

int CountOpenPositions()
{
   int count=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(IsOurOrder())
         count++;
   }

   return count;
}

//====================================================================
// HISTORICO
//====================================================================

double GetHistoricalProfitTotal()
{
   double result=0.0;

   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_HISTORY))
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      // Magic = -1 = qualquer Magic Number, inclusive 0.
      if(InpMagicNumber!=-1 &&
         OrderMagicNumber()!=InpMagicNumber)
         continue;

      int type=OrderType();

      if(type!=OP_BUY &&
         type!=OP_SELL)
         continue;

      result+=OrderProfit();
      result+=OrderSwap();
      result+=OrderCommission();
   }

   return result;
}

//====================================================================
// INICIA CESTA
//====================================================================

void StartBasketIfNeeded()
{
   if(CountOpenPositions()<=0)
      return;

   // Se a cesta ja esta ativa, nao reinicializa os niveis.
   // Isso e importante para preservar TAKE/STOP ao trocar o timeframe.
   if(g_basketActive)
      return;

   string gv=
      BasketGlobalName();

   if(GlobalVariableCheck(gv))
   {
      g_basketBaseHistory=
         GlobalVariableGet(gv);
   }
   else
   {
      g_basketBaseHistory=
         GetHistoricalProfitTotal();

      GlobalVariableSet(
         gv,
         g_basketBaseHistory
      );
   }

   string reduceGV=
      BasketReduceExcludedGlobalName();

   if(GlobalVariableCheck(reduceGV))
   {
      g_basketReduceExcluded=
         GlobalVariableGet(reduceGV);
   }
   else
   {
      g_basketReduceExcluded=0.0;

      GlobalVariableSet(
         reduceGV,
         g_basketReduceExcluded
      );
   }

   // Recupera os pontos da cesta atual.
   LoadLevelPointsFromGlobals();

   g_targetUserSet=false;
   g_stopUserSet=false;

   g_basketActive=true;
}

//====================================================================
// FINALIZA CESTA
//====================================================================

void EndBasketIfNeeded()
{
   if(CountOpenPositions()>0)
      return;

   if(!g_basketActive)
      return;

   g_basketActive=false;

   g_basketBaseHistory=0.0;

   string gv=
      BasketGlobalName();

   if(GlobalVariableCheck(gv))
      GlobalVariableDel(gv);

   string reduceGV=
      BasketReduceExcludedGlobalName();

   if(GlobalVariableCheck(reduceGV))
      GlobalVariableDel(reduceGV);

   g_basketReduceExcluded=0.0;

   // TAKE/STOP/LOTE sao configuracoes persistentes do painel.
   // Nao sao apagados quando a cesta termina.

   g_targetPrice=0.0;
   g_stopPrice=0.0;

   g_targetUserSet=false;
   g_stopUserSet=false;

   // Recupera LOTES, TAKE e STOP antes de construir o painel.
   // Assim o campo ja nasce com o valor persistido, sem piscar
   // para o valor dos inputs ao trocar o timeframe.
   LoadPanelSettingsFromGlobals();
   SavePanelSettingsToGlobals();

   g_targetAutoArmed=false;
   g_stopAutoArmed=false;
}

//====================================================================
// REALIZADO
//====================================================================

double GetBasketRealized()
{
   if(!g_basketActive)
      return 0.0;

   return
      GetHistoricalProfitTotal()-
      g_basketBaseHistory-
      g_basketReduceExcluded;
}

//====================================================================
// ABERTO
//====================================================================

double GetOpenProfit()
{
   double result=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      result+=OrderProfit();
      result+=OrderSwap();
      result+=OrderCommission();
   }

   return result;
}

//====================================================================
// TOTAL
//====================================================================

double GetBasketTotal()
{
   return GetBasketRealized()+
          GetOpenProfit();
}

// O TOTAL continua existindo internamente para os calculos da cesta
// e dos niveis TAKE/STOP. Ele nao e mais exibido no painel.
// O indicador DIA possui outra finalidade: mostrar o saldo efetivo
// do pregao, incluindo o resultado flutuante atual.

//====================================================================
// PRECO MEDIO
//====================================================================

double GetBuyAverageOpenPrice()
{
   double lots=0.0;
   double value=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()!=OP_BUY)
         continue;

      lots+=OrderLots();
      value+=OrderOpenPrice()*OrderLots();
   }

   if(lots<=0.0)
      return 0.0;

   return NormalizePrice(value/lots);
}

double GetSellAverageOpenPrice()
{
   double lots=0.0;
   double value=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()!=OP_SELL)
         continue;

      lots+=OrderLots();
      value+=OrderOpenPrice()*OrderLots();
   }

   if(lots<=0.0)
      return 0.0;

   return NormalizePrice(value/lots);
}

// Calcula o preco medio que teriamos depois de adicionar
// o lote selecionado na boleta ao lado correspondente.
double GetProjectedBuyAverage()
{
   double currentLots=GetBuyLots();
   double currentAverage=GetBuyAverageOpenPrice();
   double addLots=g_selectedLots;

   if(addLots<=0.0)
      return 0.0;

   RefreshRates();

   if(currentLots<=0.0)
      return NormalizePrice(Ask);

   return NormalizePrice(
      (
         currentAverage*currentLots+
         Ask*addLots
      )/
      (currentLots+addLots)
   );
}

double GetProjectedSellAverage()
{
   double currentLots=GetSellLots();
   double currentAverage=GetSellAverageOpenPrice();
   double addLots=g_selectedLots;

   if(addLots<=0.0)
      return 0.0;

   RefreshRates();

   if(currentLots<=0.0)
      return NormalizePrice(Bid);

   return NormalizePrice(
      (
         currentAverage*currentLots+
         Bid*addLots
      )/
      (currentLots+addLots)
   );
}

double GetAverageOpenPrice()
{
   double buyLots=0.0;
   double sellLots=0.0;

   double buyValue=0.0;
   double sellValue=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      double lots=
         OrderLots();

      double price=
         OrderOpenPrice();

      if(OrderType()==OP_BUY)
      {
         buyLots+=lots;
         buyValue+=
            price*lots;
      }
      else
      if(OrderType()==OP_SELL)
      {
         sellLots+=lots;
         sellValue+=
            price*lots;
      }
   }

   if(buyLots<=0.0 &&
      sellLots<=0.0)
      return 0.0;

   // Exposicao liquida comprada
   if(buyLots>sellLots)
   {
      if(buyLots<=0.0)
         return 0.0;

      return NormalizePrice(
         buyValue/buyLots
      );
   }

   // Exposicao liquida vendida
   if(sellLots>buyLots)
   {
      if(sellLots<=0.0)
         return 0.0;

      return NormalizePrice(
         sellValue/sellLots
      );
   }

   // Hedge equilibrado
   double totalLots=
      buyLots+
      sellLots;

   if(totalLots<=0.0)
      return 0.0;

   return NormalizePrice(
      (buyValue+sellValue)/
      totalLots
   );
}

//====================================================================
// VALOR DE PRECO POR LOTE
//====================================================================

double PriceValuePerLot()
{
   double tickValue=
      MarketInfo(
         Symbol(),
         MODE_TICKVALUE
      );

   double tickSize=
      MarketInfo(
         Symbol(),
         MODE_TICKSIZE
      );

   if(tickValue<=0.0 ||
      tickSize<=0.0)
      return 0.0;

   return tickValue/
          tickSize;
}

//====================================================================
// RESULTADO DA CESTA EM DETERMINADO PRECO
//====================================================================

double BasketProfitAtPrice(
   double price)
{
   RefreshRates();

   double current=
      GetBasketTotal();

   double buyLots=
      GetBuyLots();

   double sellLots=
      GetSellLots();

   double value=
      PriceValuePerLot();

   if(value<=0.0)
      return current;

   double buyVariation=
      (price-Bid)*
      buyLots*
      value;

   double sellVariation=
      (Ask-price)*
      sellLots*
      value;

   return current+
          buyVariation+
          sellVariation;
}

//====================================================================
// NORMALIZACAO DE PRECO PARA O ATIVO
//====================================================================

double AssetPoint()
{
   double p=MarketInfo(
      Symbol(),
      MODE_POINT
   );

   if(p<=0.0)
      p=Point;

   return p;
}

//====================================================================
// DISTANCIA DE PRECO -> PONTOS DO ATIVO
//====================================================================

double PriceDistanceToPoints(
   double distance)
{
   double p=AssetPoint();

   if(p<=0.0)
      return 0.0;

   return MathAbs(distance)/p;
}

//====================================================================
// DINHEIRO -> PONTOS DO ATIVO
//
// Usa o valor monetario real do tick e o tamanho do tick do simbolo.
//====================================================================

double MoneyToAssetPoints(
   double money,
   double lots)
{
   double value=
      PriceValuePerLot();

   double point=
      AssetPoint();

   if(money<=0.0 ||
      lots<=0.0 ||
      value<=0.0 ||
      point<=0.0)
      return 0.0;

   return money/
          (value*
           lots*
           point);
}

//====================================================================
// TEXTO DO NIVEL
//====================================================================

string LevelText(
   string label,
   double price,
   double money)
{
   double points=0.0;

   if(label=="TAKE")
      points=g_targetPoints;

   if(label=="STOP")
      points=g_stopPoints;

   return
      label+
      " "+
      DoubleToString(
         price,
         Digits
      )+
      " | "+
      DoubleToString(
         points,
         0
      )+
      " pts";
}

//====================================================================
// RESULTADO DAS OPERACOES ABERTAS EM UM PRECO HIPOTETICO
//====================================================================
//
// IMPORTANTE:
// Esta funcao considera SOMENTE as ordens que ainda estao abertas.
// Nao utiliza GetBasketTotal() e, portanto, nao incorpora lucro/prejuizo
// realizado de operacoes que ja foram fechadas.
//
// Para cada ordem:
// BUY  -> variacao hipotetica = (preco - Bid)
// SELL -> variacao hipotetica = (Ask - preco)
//
// Swap e commission da ordem aberta tambem permanecem considerados.
//====================================================================

double OpenProfitAtPrice(
   double price)
{
   RefreshRates();

   double value=
      PriceValuePerLot();

   if(value<=0.0)
      return 0.0;

   double result=0.0;

   for(int i=OrdersTotal()-1;
       i>=0;
       i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      int type=
         OrderType();

      double lots=
         OrderLots();

      // Resultado atual da ordem aberta.
      result+=OrderProfit();
      result+=OrderSwap();
      result+=OrderCommission();

      // Leva o resultado da ordem do preco atual para o preco
      // hipotetico informado.
      if(type==OP_BUY)
      {
         result+=
            (price-Bid)*
            lots*
            value;
      }
      else
      if(type==OP_SELL)
      {
         result+=
            (Ask-price)*
            lots*
            value;
      }
   }

   return result;
}

//====================================================================
// CALCULA BE SOMENTE DAS OPERACOES ABERTAS
//====================================================================
//
// O BE e o preco em que o conjunto das ordens ainda abertas chega a
// resultado financeiro zero.
//
// Operacoes fechadas anteriormente NAO participam do calculo.
//
// Exemplo:
//   fechada anteriormente = +R$ 100
//   abertas              = -R$ 30
//
// O BE continua sendo calculado para as abertas, e nao para +100-30.
//====================================================================

double SolveOpenBreakevenPrice(
   bool &valid)
{
   valid=false;

   RefreshRates();

   double buyLots=
      GetBuyLots();

   double sellLots=
      GetSellLots();

   double netLots=
      buyLots-
      sellLots;

   double value=
      PriceValuePerLot();

   if(value<=0.0)
      return 0.0;

   // Sem exposicao liquida nao existe um unico preco de BE para
   // o conjunto, pois BUY e SELL se compensam.
   if(MathAbs(netLots)<0.00000001)
      return 0.0;

   // Resultado financeiro SOMENTE das ordens abertas no preco atual.
   double openCurrent=
      GetOpenProfit();

   // Resolve:
   //
   // openCurrent
   // + (price-Bid) * buyLots  * value
   // + (Ask-price) * sellLots * value
   // = 0
   //
   double numerator=
      -openCurrent+
      Bid*buyLots*value-
      Ask*sellLots*value;

   double denominator=
      netLots*value;

   if(MathAbs(denominator)<0.00000001)
      return 0.0;

   double price=
      numerator/
      denominator;

   if(price<=0.0)
      return 0.0;

   valid=true;

   return NormalizePrice(price);
}

//====================================================================
// CALCULA PRECO PARA RESULTADO
//====================================================================

double SolvePriceForProfit(
   double desiredProfit,
   bool &valid)
{
   valid=false;

   RefreshRates();

   double buyLots=
      GetBuyLots();

   double sellLots=
      GetSellLots();

   double netLots=
      buyLots-
      sellLots;

   double value=
      PriceValuePerLot();

   if(value<=0.0)
      return 0.0;

   // Hedge perfeitamente equilibrado:
   // movimento do preco nao altera o resultado liquido.
   if(MathAbs(netLots)<0.00000001)
      return 0.0;

   double current=
      GetBasketTotal();

   double numerator=
      desiredProfit-
      current+
      Bid*buyLots*value-
      Ask*sellLots*value;

   double denominator=
      netLots*value;

   if(MathAbs(denominator)<0.00000001)
      return 0.0;

   double price=
      numerator/
      denominator;

   if(price<=0.0)
      return 0.0;

   valid=true;

   return NormalizePrice(price);
}

//====================================================================
// CRIA HLINE
//====================================================================

void CreateHLine(
   string name,
   double price,
   color lineColor,
   ENUM_LINE_STYLE style,
   int width)
{
   if(price<=0.0)
      return;

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

   ObjectSetDouble(
      0,
      name,
      OBJPROP_PRICE1,
      price
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      lineColor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_STYLE,
      style
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_WIDTH,
      width
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      true
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
      OBJPROP_BACK,
      true
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ZORDER,
      InpPanelHeight
   );
}

//====================================================================
// TEXTO DO NIVEL
//====================================================================

void CreatePriceText(
   string name,
   string text,
   double price,
   color textColor)
{
   if(price<=0.0)
      return;

   datetime t=
      Time[0];

   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_TEXT,
         0,
         t,
         price
      );
   }

   ObjectMove(
      0,
      name,
      0,
      t,
      price
   );

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
      8
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
      OBJPROP_SELECTABLE,
      false
   );

   // Texto dos niveis fica atras do painel.
   ObjectSetInteger(
      0,
      name,
      OBJPROP_BACK,
      true
   );
}

//====================================================================
// CONVERTE PRECO PARA Y EM PIXEL
//
// IMPORTANTE:
// A caixa usa CORNER_RIGHT_UPPER.
// Portanto:
//
// preco -> Y do grafico -> YDISTANCE da caixa
//
// O X nunca depende da conversao.
//====================================================================

int PriceToScreenY(
   double price)
{
   int px=0;
   int py=0;

   if(!ChartTimePriceToXY(
      0,
      0,
      Time[0],
      price,
      px,
      py))
   {
      return -1;
   }

   return py;
}

//====================================================================
// LIMITA Y DA CAIXA
//====================================================================

int ClampBoxY(int y)
{
   int chartHeight=
      (int)ChartGetInteger(
         0,
         CHART_HEIGHT_IN_PIXELS,
         0
      );

   int maxY=
      chartHeight-
      LEVEL_BOX_HEIGHT-
      8;

   if(maxY<8)
      maxY=8;

   if(y<8)
      y=8;

   if(y>maxY)
      y=maxY;

   return y;
}

//====================================================================
// CRIA / ATUALIZA CAIXA
//
// NOVA GEOMETRIA:
// CORNER_RIGHT_UPPER
// X fixo = 12
// Y = preco convertido para pixel
//====================================================================

void CreatePriceBox(
   string name,
   double price,
   color background,
   color borderColor)
{
   if(price<=0.0)
      return;

   int screenY=
      PriceToScreenY(
         price
      );

   if(screenY<0)
   {
      // Nao apaga a referencia financeira; apenas o desenho fica fora
      // da area atualmente visivel.
      return;
   }

   int y=
      screenY-
      LEVEL_BOX_HEIGHT/2;

   y=ClampBoxY(y);

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
         Print(
            "SENTINEL erro criando ",
            name,
            " erro=",
            GetLastError()
         );
         return;
      }
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      CORNER_RIGHT_UPPER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      LEVEL_RIGHT_MARGIN
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XSIZE,
      LEVEL_BOX_WIDTH
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YSIZE,
      LEVEL_BOX_HEIGHT
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BGCOLOR,
      background
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BORDER_COLOR,
      borderColor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      borderColor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      true
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
      OBJPROP_BACK,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ZORDER,
      100
   );
}

//====================================================================
// PONTEIRO DO TAKE / STOP
//
// Agora ele e somente um pequeno segmento horizontal na regiao
// direita do grafico.
//====================================================================

void UpdatePointer(
   string name,
   double price)
{
   if(price<=0.0)
      return;

   int px=0;
   int py=0;

   if(!ChartTimePriceToXY(
      0,
      0,
      Time[0],
      price,
      px,
      py))
      return;

   int chartWidth=
      (int)ChartGetInteger(
         0,
         CHART_WIDTH_IN_PIXELS,
         0
      );

   int x1=
      chartWidth-
      LEVEL_BOX_WIDTH-
      LEVEL_RIGHT_MARGIN-
      8;

   int x2=
      chartWidth-
      5;

   if(x1<5)
      x1=5;

   if(x2<x1)
      x2=x1+20;

   datetime t1;
   datetime t2;

   double p1;
   double p2;

   int subWindow=0;

   if(!ChartXYToTimePrice(
      0,
      x1,
      py,
      subWindow,
      t1,
      p1))
      return;

   subWindow=0;

   if(!ChartXYToTimePrice(
      0,
      x2,
      py,
      subWindow,
      t2,
      p2))
      return;

   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_TREND,
         0,
         t1,
         price,
         t2,
         price
      );
   }

   ObjectMove(
      0,
      name,
      0,
      t1,
      price
   );

   ObjectMove(
      0,
      name,
      1,
      t2,
      price
   );

   color c=
      InpTakeColor;

   if(name==OBJ_LINE_STOP)
      c=InpStopColor;

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      c
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_STYLE,
      STYLE_DOT
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_WIDTH,
      1
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_RAY,
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
      OBJPROP_BACK,
      true
   );
}

//====================================================================
// TEXTO DA CAIXA
//
// O texto fica imediatamente a esquerda da caixa, mantendo a mesma
// referencia visual validada no modulo isolado.
//====================================================================

void UpdateLevelLabel(
   string name,
   string text,
   double price,
   color textColor)
{
   if(price<=0.0)
      return;

   int screenY=
      PriceToScreenY(
         price
      );

   if(screenY<0)
      return;

   int y=
      screenY-
      LEVEL_LABEL_Y_OFFSET;

   int chartHeight=
      (int)ChartGetInteger(
         0,
         CHART_HEIGHT_IN_PIXELS,
         0
      );

   if(y<5)
      y=5;

   if(y>chartHeight-55)
      y=chartHeight-55;

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
         Print(
            "SENTINEL erro criando texto ",
            name,
            " erro=",
            GetLastError()
         );
         return;
      }
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      CORNER_RIGHT_UPPER
   );

   // Para CORNER_RIGHT_UPPER, X e contado a partir da direita.
   // O texto termina alguns pixels antes da caixa.
   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      LEVEL_RIGHT_MARGIN+
      LEVEL_BOX_WIDTH+
      LEVEL_LABEL_GAP
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
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
      OBJPROP_FONTSIZE,
      8
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ZORDER,
      10
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );

   // Linha puramente visual: nunca fica selecionavel e nunca mostra
   // os pontos de controle nas extremidades.
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
      OBJPROP_BACK,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ZORDER,
      101
   );
}

//====================================================================
// LINHA TAKE / STOP ARRASTAVEL
//
// Agora TAKE e STOP usam exatamente a mesma filosofia visual do
// MEDIO / BE: uma linha horizontal simples no grafico.
//
// A linha e arrastavel. Ao arrastar:
//   preco -> recalcula valor em R$ -> atualiza painel.
//
// Nao usamos mais caixas.
//====================================================================

void CreateDraggableHLine(
   string lineName,
   string textName,
   double price,
   color lineColor,
   string label)
{
   if(price<=0.0)
      return;

   // Linha pontilhada e arrastavel.
   CreateHLine(
      lineName,
      price,
      lineColor,
      STYLE_DASH,
      1
   );

   ObjectSetInteger(
      0,
      lineName,
      OBJPROP_SELECTABLE,
      true
   );

   ObjectSetInteger(
      0,
      lineName,
      OBJPROP_SELECTED,
      false
   );

   double points=0.0;

   if(label=="TAKE")
      points=g_targetPoints;

   if(label=="STOP")
      points=g_stopPoints;

   string text=
      label+
      " "+
      DoubleToString(
         price,
         Digits
      )+
      " | "+
      DoubleToString(
         points,
         0
      )+
      " pts";

   CreatePriceText(
      textName,
      text,
      price,
      lineColor
   );
}

//====================================================================
// APAGA ANTIGOS OBJETOS DE CAIXA
//
// Serve tambem para limpar objetos deixados por versoes anteriores.
//====================================================================

void RemoveLegacyLevelObjects()
{
   DeleteObjectSafe("SLT2_TAKE_BOX");
   DeleteObjectSafe("SLT2_STOP_BOX");
   DeleteObjectSafe("SLT2_TAKE_POINTER");
   DeleteObjectSafe("SLT2_STOP_POINTER");

   DeleteObjectSafe("SLT3_TAKE_BOX");
   DeleteObjectSafe("SLT3_STOP_BOX");
   DeleteObjectSafe("SLT3_TAKE_POINTER");
   DeleteObjectSafe("SLT3_STOP_POINTER");

   DeleteObjectSafe("SLT4_TAKE_BOX");
   DeleteObjectSafe("SLT4_STOP_BOX");
   DeleteObjectSafe("SLT4_TAKE_POINTER");
   DeleteObjectSafe("SLT4_STOP_POINTER");

   DeleteObjectSafe("SLT5_TAKE_BOX");
   DeleteObjectSafe("SLT5_STOP_BOX");
   DeleteObjectSafe("SLT5_TAKE_POINTER");
   DeleteObjectSafe("SLT5_STOP_POINTER");

   DeleteObjectSafe("SLT4_TAKE_TITLE");
   DeleteObjectSafe("SLT4_TAKE_MONEY");
   DeleteObjectSafe("SLT4_TAKE_PRICE");
   DeleteObjectSafe("SLT4_STOP_TITLE");
   DeleteObjectSafe("SLT4_STOP_MONEY");
   DeleteObjectSafe("SLT4_STOP_PRICE");

   DeleteObjectSafe("SLT5_TAKE_TITLE");
   DeleteObjectSafe("SLT5_TAKE_MONEY");
   DeleteObjectSafe("SLT5_TAKE_PRICE");
   DeleteObjectSafe("SLT5_STOP_TITLE");
   DeleteObjectSafe("SLT5_STOP_MONEY");
   DeleteObjectSafe("SLT5_STOP_PRICE");
}

//====================================================================
// PRECO TAKE/STOP NO PAINEL
//====================================================================

void UpdateLevelPanelPrice(
   string labelObject,
   string levelName,
   double price,
   color levelColor)
{
   if(ObjectFind(0,labelObject)<0)
      return;

   double money=0.0;

   if(levelName=="TAKE")
      money=g_targetMoney;

   if(levelName=="STOP")
      money=g_stopMoney;

   string text=
      levelName+
      " "+
      LevelMoneyText(
         money
      );

   ObjectSetString(
      0,
      labelObject,
      OBJPROP_TEXT,
      text
   );

   ObjectSetInteger(
      0,
      labelObject,
      OBJPROP_COLOR,
      levelColor
   );
}

//====================================================================
// RESULTADO FINANCEIRO NO NIVEL
//====================================================================

string LevelMoneyText(double money)
{
   string currency=
      AccountCurrency();

   if(currency=="")
      currency="";

   string sign="";

   if(money>0.0000001)
      sign="+";
   else
   if(money< -0.0000001)
      sign="-";

   return sign+
          DoubleToString(
             MathAbs(money),
             2
          )+
          " "+
          currency;
}

//====================================================================
// TAKE LEVEL
//====================================================================

void UpdateTargetBox()
{
   if(g_targetPrice<=0.0)
   {
      DeleteObjectSafe(OBJ_LINE_TARGET);
      DeleteObjectSafe(OBJ_TXT_TARGET);
      return;
   }

   //-----------------------------------------------------------------
   // IMPORTANTE:
   // Se a linha ja existe, NAO recriar o objeto.
   // Recriar a HLINE a cada tick fazia o MT4 perder a selecao,
   // obrigando o usuario a clicar duas vezes para arrastar.
   //-----------------------------------------------------------------

   if(ObjectFind(0,OBJ_LINE_TARGET)<0)
   {
      CreateDraggableHLine(
         OBJ_LINE_TARGET,
         OBJ_TXT_TARGET,
         g_targetPrice,
         InpTakeColor,
         "TAKE"
      );
   }
   else
   {
      bool selected=
         (bool)ObjectGetInteger(
            0,
            OBJ_LINE_TARGET,
            OBJPROP_SELECTED
         );

      // Durante o arraste, o MT4 e a fonte de verdade.
      // Nao sobrescrever a posicao enquanto o objeto esta selecionado.
      if(!selected)
      {
         ObjectSetDouble(
            0,
            OBJ_LINE_TARGET,
            OBJPROP_PRICE1,
            g_targetPrice
         );
      }

      ObjectSetInteger(
         0,
         OBJ_LINE_TARGET,
         OBJPROP_SELECTABLE,
         true
      );
   }

   // O texto pode ser atualizado sem tocar na selecao da linha.
   string text=
      "TAKE "+
      DoubleToString(
         g_targetPrice,
         Digits
      )+
      " | "+
      LevelMoneyText(
         g_targetMoney
      );

   if(ObjectFind(0,OBJ_TXT_TARGET)<0)
   {
      CreatePriceText(
         OBJ_TXT_TARGET,
         text,
         g_targetPrice,
         InpTakeColor
      );
   }
   else
   {
      ObjectSetDouble(
         0,
         OBJ_TXT_TARGET,
         OBJPROP_PRICE1,
         g_targetPrice
      );

      ObjectSetString(
         0,
         OBJ_TXT_TARGET,
         OBJPROP_TEXT,
         text
      );
   }

   UpdateLevelPanelPrice(
      OBJ_LBL_TARGET_MONEY,
      "TAKE",
      g_targetPrice,
      InpTakeColor
   );
}

//====================================================================
// STOP LEVEL
//====================================================================

void UpdateStopBox()
{
   if(g_stopPrice<=0.0)
   {
      DeleteObjectSafe(OBJ_LINE_STOP);
      DeleteObjectSafe(OBJ_TXT_STOP);
      return;
   }

   //-----------------------------------------------------------------
   // IMPORTANTE:
   // Nunca recriar a HLINE a cada tick.
   //-----------------------------------------------------------------

   if(ObjectFind(0,OBJ_LINE_STOP)<0)
   {
      CreateDraggableHLine(
         OBJ_LINE_STOP,
         OBJ_TXT_STOP,
         g_stopPrice,
         InpStopColor,
         "STOP"
      );
   }
   else
   {
      bool selected=
         (bool)ObjectGetInteger(
            0,
            OBJ_LINE_STOP,
            OBJPROP_SELECTED
         );

      if(!selected)
      {
         ObjectSetDouble(
            0,
            OBJ_LINE_STOP,
            OBJPROP_PRICE1,
            g_stopPrice
         );
      }

      ObjectSetInteger(
         0,
         OBJ_LINE_STOP,
         OBJPROP_SELECTABLE,
         true
      );
   }

   string text=
      "STOP "+
      DoubleToString(
         g_stopPrice,
         Digits
      )+
      " | "+
      LevelMoneyText(
         g_stopMoney
      );

   if(ObjectFind(0,OBJ_TXT_STOP)<0)
   {
      CreatePriceText(
         OBJ_TXT_STOP,
         text,
         g_stopPrice,
         InpStopColor
      );
   }
   else
   {
      ObjectSetDouble(
         0,
         OBJ_TXT_STOP,
         OBJPROP_PRICE1,
         g_stopPrice
      );

      ObjectSetString(
         0,
         OBJ_TXT_STOP,
         OBJPROP_TEXT,
         text
      );
   }

   UpdateLevelPanelPrice(
      OBJ_LBL_STOP_MONEY,
      "STOP",
      g_stopPrice,
      InpStopColor
   );
}

//====================================================================
// REMOVE OBJETO
//====================================================================

void DeleteObjectSafe(
   string name)
{
   if(ObjectFind(0,name)>=0)
      ObjectDelete(
         0,
         name
      );
}

//====================================================================
// CRIA LINHA HORIZONTAL SEGMENTADA
//====================================================================
//
// Diferente de OBJ_HLINE, esta linha nao atravessa todo o chart.
// Ela ocupa somente a area visivel dos candles, do inicio ao fim
// da janela atual.
//
// Isso deixa o BE como uma referencia visual local, sem criar uma
// linha infinita pelo grafico.
//====================================================================

void CreateSegmentHLine(
   string name,
   double price,
   color lineColor,
   ENUM_LINE_STYLE style,
   int width)
{
   if(price<=0.0)
      return;

   long chartWidth=
      ChartGetInteger(
         0,
         CHART_WIDTH_IN_PIXELS,
         0
      );

   if(chartWidth<100)
      chartWidth=100;

   // BE curto:
   // inicia aproximadamente em 60% da largura visivel
   // e termina em 90%, sem atravessar o grafico inteiro.
   int x1=(int)(chartWidth*0.60);
   int x2=(int)(chartWidth*0.90);

   if(x2<=x1+20)
      x2=x1+20;

   int subWindow1=0;
   int subWindow2=0;

   datetime timeLeft=0;
   datetime timeRight=0;

   double dummyPrice=0.0;

   if(!ChartXYToTimePrice(
      0,
      x1,
      0,
      subWindow1,
      timeLeft,
      dummyPrice))
   {
      return;
   }

   if(!ChartXYToTimePrice(
      0,
      x2,
      0,
      subWindow2,
      timeRight,
      dummyPrice))
   {
      return;
   }

   if(timeLeft<=0 || timeRight<=0)
      return;

   if(ObjectFind(0,name)<0)
   {
      ResetLastError();

      if(!ObjectCreate(
         0,
         name,
         OBJ_TREND,
         0,
         timeLeft,
         price,
         timeRight,
         price))
      {
         return;
      }
   }
   else
   {
      ObjectSetInteger(0,name,OBJPROP_TIME1,timeLeft);
      ObjectSetDouble(0,name,OBJPROP_PRICE1,price);

      ObjectSetInteger(0,name,OBJPROP_TIME2,timeRight);
      ObjectSetDouble(0,name,OBJPROP_PRICE2,price);
   }

   ObjectSetInteger(0,name,OBJPROP_COLOR,lineColor);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);

   // IMPORTANTE: em OBJ_TREND do MT4, use OBJPROP_RAY=false.
   // Isso impede que o segmento continue como uma linha infinita.
   ObjectSetInteger(0,name,OBJPROP_RAY,false);

   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,50);
}


//====================================================================
// LINHA CURTA PARA MEDIO / PROJECAO
//====================================================================

void CreateProjectedSegmentHLine(
   string name,
   double price,
   color lineColor,
   ENUM_LINE_STYLE style,
   int width)
{
   if(price<=0.0)
      return;

   long chartWidth=
      ChartGetInteger(
         0,
         CHART_WIDTH_IN_PIXELS,
         0
      );

   if(chartWidth<100)
      chartWidth=100;

   int linePixels=
      MathMax(
         10,
         MathMin(
            500,
            InpProjectedLinePixels
         )
      );

   // A linha fica ancorada proximo ao lado direito do grafico,
   // exatamente como a referencia visual desejada.
   int x2=(int)(chartWidth-20);
   int x1=x2-linePixels;

   if(x1<0)
      x1=0;

   datetime time1=0;
   datetime time2=0;
   double dummy=0.0;
   int sub1=0;
   int sub2=0;

   if(!ChartXYToTimePrice(
      0,x1,0,sub1,time1,dummy))
      return;

   if(!ChartXYToTimePrice(
      0,x2,0,sub2,time2,dummy))
      return;

   if(time1<=0 || time2<=0)
      return;

   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(
         0,
         name,
         OBJ_TREND,
         0,
         time1,
         price,
         time2,
         price))
         return;
   }
   else
   {
      ObjectSetInteger(
         0,name,OBJPROP_TIME1,time1
      );

      ObjectSetDouble(
         0,name,OBJPROP_PRICE1,price
      );

      ObjectSetInteger(
         0,name,OBJPROP_TIME2,time2
      );

      ObjectSetDouble(
         0,name,OBJPROP_PRICE2,price
      );
   }

   ObjectSetInteger(
      0,name,OBJPROP_COLOR,lineColor
   );

   ObjectSetInteger(
      0,name,OBJPROP_STYLE,style
   );

   ObjectSetInteger(
      0,name,OBJPROP_WIDTH,width
   );

   ObjectSetInteger(
      0,name,OBJPROP_RAY_LEFT,false
   );

   ObjectSetInteger(
      0,name,OBJPROP_RAY_RIGHT,false
   );

   ObjectSetInteger(
      0,name,OBJPROP_SELECTABLE,false
   );

   ObjectSetInteger(
      0,name,OBJPROP_SELECTED,false
   );

   ObjectSetInteger(
      0,name,OBJPROP_BACK,true
   );

   ObjectSetInteger(
      0,name,OBJPROP_ZORDER,50
   );
}

//====================================================================
// MEDIO / BE / PROJECAO
//====================================================================

void UpdateTradingReferenceLines()
{
   if(CountOpenPositions()<=0)
   {
      DeleteObjectSafe(OBJ_LINE_AVG_BUY);
      DeleteObjectSafe(OBJ_LINE_AVG_SELL);
      DeleteObjectSafe(OBJ_LINE_PROJ_BUY);
      DeleteObjectSafe(OBJ_LINE_PROJ_SELL);
      DeleteObjectSafe(OBJ_LINE_BE);

      DeleteObjectSafe(OBJ_TXT_PROJ_BUY);
      DeleteObjectSafe(OBJ_TXT_PROJ_SELL);
      DeleteObjectSafe(OBJ_TXT_BE);

      return;
   }

   //-----------------------------------------------------------------
   // MEDIO BUY REAL
   //-----------------------------------------------------------------

   double buyAverage=
      GetBuyAverageOpenPrice();

   if(buyAverage>0.0)
   {
      CreateSegmentHLine(
         OBJ_LINE_AVG_BUY,
         buyAverage,
         InpBuyAverageColor,
         STYLE_SOLID,
         1
      );
   }
   else
   {
      DeleteObjectSafe(OBJ_LINE_AVG_BUY);
   }

   //-----------------------------------------------------------------
   // MEDIO SELL REAL
   //-----------------------------------------------------------------

   double sellAverage=
      GetSellAverageOpenPrice();

   if(sellAverage>0.0)
   {
      CreateSegmentHLine(
         OBJ_LINE_AVG_SELL,
         sellAverage,
         InpSellAverageColor,
         STYLE_SOLID,
         1
      );
   }
   else
   {
      DeleteObjectSafe(OBJ_LINE_AVG_SELL);
   }

   //-----------------------------------------------------------------
   // MEDIO PROJETADO BUY / SELL
   //
   // A linha projetada usa o lote atualmente selecionado na boleta.
   // BUY usa ASK; SELL usa BID.
   //-----------------------------------------------------------------

   if(InpShowProjectedAverage &&
      g_selectedLots>0.0)
   {
      double projectedBuy=
         GetProjectedBuyAverage();

      double projectedSell=
         GetProjectedSellAverage();

      if(projectedBuy>0.0)
      {
         CreateProjectedSegmentHLine(
            OBJ_LINE_PROJ_BUY,
            projectedBuy,
            InpProjectedBuyColor,
            STYLE_DASH,
            InpProjectedLineWidth
         );
      }
      else
      {
         DeleteObjectSafe(
            OBJ_LINE_PROJ_BUY
         );
      }

      if(projectedSell>0.0)
      {
         CreateProjectedSegmentHLine(
            OBJ_LINE_PROJ_SELL,
            projectedSell,
            InpProjectedSellColor,
            STYLE_DASH,
            InpProjectedLineWidth
         );
      }
      else
      {
         DeleteObjectSafe(
            OBJ_LINE_PROJ_SELL
         );
      }
   }
   else
   {
      DeleteObjectSafe(OBJ_LINE_PROJ_BUY);
      DeleteObjectSafe(OBJ_LINE_PROJ_SELL);
   }

   //-----------------------------------------------------------------
   // BE
   //-----------------------------------------------------------------

   bool valid=false;

   double be=
      SolveOpenBreakevenPrice(
         valid
      );

   if(valid)
   {
      CreateSegmentHLine(
         OBJ_LINE_BE,
         be,
         InpBEColor,
         STYLE_DASH,
         1
      );
   }
   else
   {
      DeleteObjectSafe(OBJ_LINE_BE);
      DeleteObjectSafe(OBJ_TXT_BE);
   }
}

//====================================================================
// TAKE / STOP
//====================================================================

void UpdateTradingLevels()
{
   if(CountOpenPositions()<=0)
   {
      DeleteObjectSafe(OBJ_LINE_TARGET);
      DeleteObjectSafe(OBJ_LINE_STOP);
      DeleteObjectSafe(OBJ_TXT_TARGET);
      DeleteObjectSafe(OBJ_TXT_STOP);
      DeleteObjectSafe(OBJ_LBL_CHART_PROFIT);

      g_targetPrice=0.0;
      g_stopPrice=0.0;

      return;
   }

   double buyLots=GetBuyLots();
   double sellLots=GetSellLots();
   double netLots=buyLots-sellLots;

   // Sem exposicao liquida nao existe um alvo/stop de preco unico.
   if(MathAbs(netLots)<0.00000001)
   {
      DeleteObjectSafe(OBJ_LINE_TARGET);
      DeleteObjectSafe(OBJ_LINE_STOP);
      DeleteObjectSafe(OBJ_TXT_TARGET);
      DeleteObjectSafe(OBJ_TXT_STOP);

      g_targetPrice=0.0;
      g_stopPrice=0.0;

      return;
   }

   double average=GetAverageOpenPrice();

   if(average<=0.0)
      return;

   double point=AssetPoint();

   if(point<=0.0)
      return;

   g_targetPoints=
      MathMax(
         InpMinimumPoints,
         g_targetPoints
      );
   // STOP pode ser negativo: permite BE e stop em lucro.
//-----------------------------------------------------------------
   // REGRA PRINCIPAL v1.26
   //
   // Se o operador arrastou TAKE/STOP, preservamos o PRECO arrastado.
   // Nao recalculamos o nivel a cada tick a partir de g_*Points.
   //
   // Se o nivel ainda nao foi arrastado/configurado manualmente,
   // usamos a distancia em pontos normalmente.
   //-----------------------------------------------------------------

   if(!g_targetUserSet)
   {
      if(netLots>0.0)
      {
         g_targetPrice=
            NormalizePrice(
               average+
               g_targetPoints*point
            );
      }
      else
      {
         g_targetPrice=
            NormalizePrice(
               average-
               g_targetPoints*point
            );
      }
   }
   else
   {
      g_targetPrice=
         NormalizePrice(
            g_targetPrice
         );

      // Mantem o campo em pontos sincronizado com o preco real.
      g_targetPoints=
         MathMax(
            InpMinimumPoints,
            MathAbs(
               g_targetPrice-average
            )/point
         );

      g_targetPoints=
         NormalizeDouble(
            g_targetPoints,
            1
         );
   }

   if(!g_stopUserSet)
   {
      if(netLots>0.0)
      {
         g_stopPrice=
            NormalizePrice(
               average-
               g_stopPoints*point
            );
      }
      else
      {
         g_stopPrice=
            NormalizePrice(
               average+
               g_stopPoints*point
            );
      }
   }
   else
   {
      g_stopPrice=
         NormalizePrice(
            g_stopPrice
         );

      // Mantem o campo em pontos sincronizado com o preco real.
      g_stopPoints = (g_stopPrice-average)/point;
g_stopPoints=
         NormalizeDouble(
            g_stopPoints,
            1
         );
   }

   //-----------------------------------------------------------------
   // RESULTADO FINANCEIRO
   //-----------------------------------------------------------------

   g_targetMoney=
      BasketProfitAtPrice(
         g_targetPrice
      );

   g_stopMoney=
      BasketProfitAtPrice(
         g_stopPrice
      );

   //-----------------------------------------------------------------
   // DESENHO
   //-----------------------------------------------------------------

   UpdateTargetBox();
   UpdateStopBox();

   //-----------------------------------------------------------------
   // SINCRONIZA CAMPOS DO PAINEL
   //-----------------------------------------------------------------

   if(ObjectFind(0,OBJ_EDIT_TARGET)>=0)
   {
      ObjectSetString(
         0,
         OBJ_EDIT_TARGET,
         OBJPROP_TEXT,
         DoubleToString(
            g_targetPoints,
            0
         )
      );
   }

   if(ObjectFind(0,OBJ_EDIT_STOP)>=0)
   {
      ObjectSetString(
         0,
         OBJ_EDIT_STOP,
         OBJPROP_TEXT,
         DoubleToString(
            g_stopPoints,
            0
         )
      );
   }
}

//====================================================================
// ATUALIZA OBJETOS
//====================================================================


//====================================================================
// PROFIT FLUTUANTE NO LADO DIREITO DO GRAFICO
//====================================================================
//
// Mostra somente o resultado das OPERACOES ABERTAS.
// O objeto fica ancorado no canto direito e acompanha verticalmente
// o preco atual.
//
// Exemplo:
//                  PROFIT +22.07 USD
//
// Quando nao existem posicoes abertas, o objeto e removido.
//====================================================================

void UpdateChartProfitLabel()
{
   int openCount=
      CountOpenPositions();

   if(openCount<=0)
   {
      DeleteObjectSafe(
         OBJ_LBL_CHART_PROFIT
      );

      return;
   }

   double profit=
      GetOpenProfit();

   double referencePrice=
      GetAverageOpenPrice();

   if(referencePrice<=0.0)
      return;

   int x=0;
   int yAvg=0;
   int yBE=0;

   // Referencia principal: MEDIO.
   if(!ChartTimePriceToXY(
      0,
      0,
      Time[0],
      referencePrice,
      x,
      yAvg))
      return;

   // Descobre a posicao do BE para evitar sobreposicao.
   bool beValid=false;
   double bePrice=
      SolveOpenBreakevenPrice(
         beValid
      );

   if(beValid &&
      bePrice>0.0)
   {
      int dummyX=0;

      ChartTimePriceToXY(
         0,
         0,
         Time[0],
         bePrice,
         dummyX,
         yBE
      );
   }
   else
   {
      yBE=-100000;
   }

   long chartHeight=
      ChartGetInteger(
         0,
         CHART_HEIGHT_IN_PIXELS,
         0
      );

   if(chartHeight<=0)
      chartHeight=500;

   // O PROFIT fica acima do bloco MEDIO/BE.
   // Se MEDIO e BE estiverem muito proximos, usamos o que estiver
   // mais acima na tela e abrimos uma distancia minima de 28 px.
   int highestReference=
      MathMin(
         yAvg,
         yBE
      );

   if(yBE<-50000)
      highestReference=yAvg;

   int y=
      highestReference-28;

   y=
      MathMax(
         8,
         MathMin(
            y,
            (int)chartHeight-8
         )
      );

   // O contexto do valor ja e implicito no local do indicador.
   string text=
      FormatMoney(
         profit
      );

   color clr=
      clrSilver;

   if(profit>0.0000001)
      clr=InpProfitColor;
   else
   if(profit< -0.0000001)
      clr=InpStopColor;

   if(ObjectFind(
      0,
      OBJ_LBL_CHART_PROFIT
   )<0)
   {
      ObjectCreate(
         0,
         OBJ_LBL_CHART_PROFIT,
         OBJ_LABEL,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_CORNER,
      CORNER_RIGHT_UPPER
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_ANCHOR,
      ANCHOR_RIGHT
   );

   // Mantemos o PROFIT na mesma regiao horizontal dos demais niveis,
   // mas com margem suficiente para nao encostar no eixo de preco.
   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      // Aproximado fortemente da margem direita.
      // v1.57 = 205 px; agora 85 px.
      OBJPROP_XDISTANCE,
      85
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_YDISTANCE,
      y
   );

   ObjectSetString(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_TEXT,
      text
   );

   ObjectSetString(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_FONT,
      "Arial"
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_FONTSIZE,
      9
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_COLOR,
      clr
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_SELECTED,
      false
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_HIDDEN,
      false
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_BACK,
      false
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_CHART_PROFIT,
      OBJPROP_ZORDER,
      1200
   );
}


void UpdateTradingObjects()
{
   StartBasketIfNeeded();

   EndBasketIfNeeded();

   // Quando nao existem mais posicoes, todas as referencias
   // operacionais devem desaparecer imediatamente do grafico.
   if(CountOpenPositions()<=0)
   {
      DeleteObjectSafe(OBJ_LINE_AVG_BUY);
      DeleteObjectSafe(OBJ_LINE_BE);
      DeleteObjectSafe(OBJ_TXT_BE);

      DeleteObjectSafe(OBJ_LINE_TARGET);
      DeleteObjectSafe(OBJ_LINE_STOP);
      DeleteObjectSafe(OBJ_TXT_TARGET);
      DeleteObjectSafe(OBJ_TXT_STOP);

      g_targetPrice=0.0;
      g_stopPrice=0.0;

      return;
   }

   UpdateTradingReferenceLines();

   UpdateTradingLevels();

   UpdateChartProfitLabel();
}

//====================================================================
// RED - REBALANCEAR
//====================================================================
//
// Deixa BUY e SELL com a mesma quantidade de lotes.
// Fecha somente o lado que estiver excedente.
//
// Exemplo:
// BUY 0.10 / SELL 0.04 -> fecha 0.06 de BUY
// BUY 0.04 / SELL 0.10 -> fecha 0.06 de SELL
//====================================================================

bool RebalanceSides()
{
   double redBuyLots=
      GetBuyLots();

   double redSellLots=
      GetSellLots();

   // RED = HEDGE / TRAVAR.
   // Nao fecha o excedente: abre o lado contrario
   // na quantidade necessaria para igualar BUY e SELL.

   double redDifference=
      MathAbs(
         redBuyLots-
         redSellLots
      );

   redDifference=
      NormalizeLots(
         redDifference
      );

   if(redDifference<=0.0)
   {
      SetStatus(
         "RED: JA TRAVADO",
         InpProfitColor
      );

      return true;
   }

   bool redResult=false;

   if(redBuyLots>redSellLots)
   {
      // Excesso de BUY -> abre SELL.
      redResult=
         ExecuteSell(
            redDifference,
            true
         );
   }
   else
   if(redSellLots>redBuyLots)
   {
      // Excesso de SELL -> abre BUY.
      redResult=
         ExecuteBuy(
            redDifference,
            true
         );
   }

   if(redResult)
   {
      SetStatus(
         "RED: OPERACAO TRAVADA",
         InpProfitColor
      );
   }
   else
   {
      SetStatus(
         "RED: FALHA AO TRAVAR",
         InpStopColor
      );
   }

   return redResult;
}

//====================================================================
// CLOSE ALL
//====================================================================

bool CloseAllPositions()
{
   bool success=true;

   for(int pass=0;
       pass<3;
       pass++)
   {
      for(int i=OrdersTotal()-1;
          i>=0;
          i--)
      {
         if(!OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_TRADES))
            continue;

         if(!IsOurOrder())
            continue;

         int ticket=
            OrderTicket();

         int type=
            OrderType();

         double lots=
            OrderLots();

         RefreshRates();

         double price=0.0;

         if(type==OP_BUY)
            price=Bid;
         else
         if(type==OP_SELL)
            price=Ask;

         ResetLastError();

         bool result=
            OrderClose(
               ticket,
               lots,
               price,
               InpSlippage,
               clrNONE
            );

         if(!result)
         {
            int error=
               GetLastError();

            Print(
               "SENTINEL CLOSE ALL ticket=",
               ticket,
               " erro=",
               error
            );

            success=false;
         }
      }

      if(CountOpenPositions()==0)
         break;

      Sleep(100);
   }

   if(success)
   {
      SetStatus(
         "CLOSE ALL EXECUTADO",
         InpProfitColor
      );
   }

   return success;
}

//====================================================================
// ESTRUTURA DE POSICAO
//====================================================================

struct PositionInfo
{
   int ticket;
   int type;

   double lots;
   double price;
   double distance;
};

//====================================================================
// CARREGA POSICOES
//====================================================================

int GetOurPositions(
   PositionInfo &positions[])
{
   ArrayResize(
      positions,
      0
   );

   RefreshRates();

   double current=
      (Bid+Ask)/2.0;

   int count=0;

   for(int i=OrdersTotal()-1;
       i>=0;
       i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      PositionInfo p;

      p.ticket=
         OrderTicket();

      p.type=
         OrderType();

      p.lots=
         OrderLots();

      p.price=
         OrderOpenPrice();

      p.distance=
         MathAbs(
            current-p.price
         );

      ArrayResize(
         positions,
         count+1
      );

      positions[count]=p;

      count++;
   }

   return count;
}

//====================================================================
// CLOSE PARCIAL
//====================================================================

bool PartialCloseTicket(
   int ticket,
   double lots)
{
   if(!OrderSelect(
      ticket,
      SELECT_BY_TICKET))
      return false;

   if(!IsOurOrder())
      return false;

   double available=
      OrderLots();

   if(lots>available)
      lots=available;

   lots=
      NormalizeLots(
         lots
      );

   if(lots<=0.0)
      return false;

   int type=
      OrderType();

   for(int attempt=0;
       attempt<3;
       attempt++)
   {
      RefreshRates();

      double price=0.0;

      if(type==OP_BUY)
         price=Bid;
      else
      if(type==OP_SELL)
         price=Ask;

      ResetLastError();

      bool result=
         OrderClose(
            ticket,
            lots,
            price,
            InpSlippage,
            clrNONE
         );

      if(result)
         return true;

      Sleep(100);
   }

   return false;
}

//====================================================================
// REDUCE DE UM LADO
//====================================================================

//====================================================================
// REDUCE DE UM LADO POR RESULTADO
//
// modeWinner=true  -> somente ordens abertas com lucro > 0
// modeWinner=false -> somente ordens abertas com prejuizo < 0
//
// A reducao e parcial quando necessario. A ordem nao precisa ser
// encerrada integralmente.
//====================================================================

bool PartialCloseAndCaptureResult(
   int ticket,
   double closeLots,
   double &closedResult)
{
   closedResult=0.0;

   double historyBefore=
      GetHistoricalProfitTotal();

   if(!PartialCloseTicket(
      ticket,
      closeLots))
   {
      return false;
   }

   double historyAfter=
      GetHistoricalProfitTotal();

   closedResult=
      historyAfter-historyBefore;

   return true;
}

bool ReduceSideByResult(
   int sideType,
   double lotsToReduce,
   bool modeWinner,
   bool excludeFromRealized=false)
{
   lotsToReduce=NormalizeLots(lotsToReduce);

   if(lotsToReduce<=0.0)
   {
      SetStatus(
         modeWinner ?
         "SEM LOTE PARA WIN" :
         "SEM LOTE PARA LOSS",
         InpStopColor
      );

      return false;
   }

   PositionInfo positions[];
   int count=GetOurPositions(positions);

   if(count<=0)
   {
      SetStatus(
         "SEM POSICOES",
         InpStopColor
      );

      return false;
   }

   // Ordena por distancia do preco atual, mais distante primeiro.
   // Isso preserva a regra operacional existente.
   for(int i=0;i<count-1;i++)
   {
      for(int j=i+1;j<count;j++)
      {
         if(positions[j].distance>positions[i].distance)
         {
            PositionInfo temp=positions[i];
            positions[i]=positions[j];
            positions[j]=temp;
         }
      }
   }

   double remaining=lotsToReduce;
   double closed=0.0;

   for(int i=0;
       i<count && remaining>0.00000001;
       i++)
   {
      if(positions[i].type!=sideType)
         continue;

      int ticket=positions[i].ticket;

      // Releitura do ticket imediatamente antes da decisao.
      if(!OrderSelect(
         ticket,
         SELECT_BY_TICKET,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      int currentType=OrderType();

      if(currentType!=sideType)
         continue;

      double orderResult=
         OrderProfit()+
         OrderSwap()+
         OrderCommission();

      bool qualifies=
         modeWinner ?
         (orderResult>0.00000001) :
         (orderResult<-0.00000001);

      if(!qualifies)
         continue;

      // Usa o lote atual do ticket, nao o valor armazenado no array.
      double available=OrderLots();

      if(available<=0.0)
         continue;

      double closeLots=
         MathMin(
            available,
            remaining
         );

      closeLots=
         NormalizeLots(
            closeLots
         );

      if(closeLots<=0.0)
         continue;

      double closedResult=0.0;
      bool closedOk=false;

      // Primeira tentativa.
      if(PartialCloseAndCaptureResult(
         ticket,
         closeLots,
         closedResult))
      {
         closedOk=true;
      }
      else
      {
         // Fallback: rele o ticket. Se o lote pedido cobre a ordem,
         // tenta explicitamente o fechamento integral.
         if(OrderSelect(
            ticket,
            SELECT_BY_TICKET,
            MODE_TRADES) &&
            IsOurOrder() &&
            OrderType()==sideType)
         {
            double retryLots=OrderLots();

            if(retryLots>0.0 &&
               closeLots>=retryLots-0.00000001)
            {
               retryLots=
                  NormalizeLots(
                     retryLots
                  );

               if(retryLots>0.0)
               {
                  closedResult=0.0;

                  if(PartialCloseAndCaptureResult(
                     ticket,
                     retryLots,
                     closedResult))
                  {
                     closeLots=retryLots;
                     closedOk=true;
                  }
               }
            }
         }
      }

      if(!closedOk)
         continue;

      remaining-=closeLots;
      closed+=closeLots;

      if(excludeFromRealized)
      {
         AddReduceExcludedResult(
            closedResult
         );
      }
   }

   if(closed>0.0)
   {
      string sideText=
         sideType==OP_BUY ?
         "BUY" :
         "SELL";

      string resultText=
         modeWinner ?
         " WIN" :
         " LOSS";

      SetStatus(
         "DESF "+
         sideText+
         resultText+
         " "+
         DoubleToString(
            closed,
            2
         ),
         InpProfitColor
      );

      return true;
   }

   SetStatus(
      modeWinner ?
      "SEM POSICAO VENCEDORA" :
      "SEM POSICAO PERDEDORA",
      InpStopColor
   );

   return false;
}

bool ReduceSide(
   int sideType,
   double lotsToReduce)
{
   lotsToReduce=
      NormalizeLots(
         lotsToReduce
      );

   if(lotsToReduce<=0.0)
      return false;

   PositionInfo positions[];

   int count=
      GetOurPositions(
         positions
      );

   if(count<=0)
      return false;

   //-----------------------------------------------------------------
   // MAIS DISTANTE PRIMEIRO
   //-----------------------------------------------------------------

   for(int i=0;
       i<count-1;
       i++)
   {
      for(int j=i+1;
          j<count;
          j++)
      {
         if(positions[j].distance>
            positions[i].distance)
         {
            PositionInfo temp=
               positions[i];

            positions[i]=
               positions[j];

            positions[j]=
               temp;
         }
      }
   }

   //-----------------------------------------------------------------
   // EXECUTA REDUCAO
   //-----------------------------------------------------------------

   double remaining=
      lotsToReduce;

   double closed=0.0;

   for(int i=0;
       i<count &&
       remaining>0.00000001;
       i++)
   {
      if(positions[i].type!=sideType)
         continue;

      double closeLots=
         MathMin(
            positions[i].lots,
            remaining
         );

      closeLots=
         NormalizeLots(
            closeLots
         );

      if(closeLots<=0.0)
         continue;

      if(PartialCloseTicket(
         positions[i].ticket,
         closeLots))
      {
         remaining-=closeLots;

         closed+=
            closeLots;
      }
   }

   if(closed>0.0)
   {
      SetStatus(
         "REDUCE OK "+
         DoubleToString(
            closed,
            2
         ),
         InpProfitColor
      );

      return true;
   }

   SetStatus(
      "REDUCE NAO EXECUTADO",
      InpStopColor
   );

   return false;
}

//====================================================================
// REDUCE BxS
//====================================================================
//
// Somente quando existe BUY vencedora E SELL vencedora.
// O resultado dos fechamentos do REDUCE e excluido do REALIZADO
// operacional do Sentinel, embora o MT4 registre o fechamento.
//====================================================================

double GetWinningLotsBySide(int sideType)
{
   double lots=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(
         i,
         SELECT_BY_POS,
         MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()!=sideType)
         continue;

      double orderResult=
         OrderProfit()+
         OrderSwap()+
         OrderCommission();

      if(orderResult>0.00000001)
         lots+=OrderLots();
   }

   return NormalizeLots(lots);
}

bool ReduceBothSides(
   double lots)
{
   lots=NormalizeLots(lots);

   if(lots<=0.0)
      return false;

   double buyWinningLots=
      GetWinningLotsBySide(OP_BUY);

   double sellWinningLots=
      GetWinningLotsBySide(OP_SELL);

   if(buyWinningLots<=0.0 ||
      sellWinningLots<=0.0)
   {
      SetStatus(
         "REDUCE: SEM 2 LADOS WIN",
         InpStopColor
      );

      return false;
   }

   double possible=
      MathMin(
         buyWinningLots,
         sellWinningLots
      );

   double amount=
      NormalizeLots(
         MathMin(
            lots,
            possible
         )
      );

   if(amount<=0.0)
      return false;

   bool buyResult=
      ReduceSideByResult(
         OP_BUY,
         amount,
         true,
         true
      );

   bool sellResult=
      ReduceSideByResult(
         OP_SELL,
         amount,
         true,
         true
      );

   if(buyResult &&
      sellResult)
   {
      SetStatus(
         "REDUCE BxS "+
         DoubleToString(
            amount,
            2
         ),
         InpProfitColor
      );

      return true;
   }

   SetStatus(
      "REDUCE PARCIAL",
      InpStopColor
   );

   return false;
}

//====================================================================
// COMENTARIO DAS ORDENS
//====================================================================

string BuildOrderComment(bool isRed)
{
   string baseComment=InpOrderComment;

   // Remove espacos nas extremidades para evitar comentarios
   // desnecessariamente vazios.
   StringTrimLeft(baseComment);
   StringTrimRight(baseComment);

   if(isRed)
   {
      if(baseComment=="")
         return "RED";

      return baseComment+" RED";
   }

   if(baseComment=="")
      return "SENTINEL";

   return baseComment;
}

//====================================================================
// BUY
//====================================================================

bool ExecuteBuy(
   double lots,
   bool isRed=false)
{
   lots=
      NormalizeLots(
         lots
      );

   if(lots<=0.0)
   {
      SetStatus(
         "LOTE BUY INVALIDO",
         InpStopColor
      );

      return false;
   }

   RefreshRates();

   ResetLastError();

   int ticket=
      OrderSend(
         Symbol(),
         OP_BUY,
         lots,
         Ask,
         InpSlippage,
         0,
         0,
         BuildOrderComment(isRed),
         InpMagicNumber,
         0,
         InpBuyColor
      );

   if(ticket<0)
   {
      SetStatus(
         "BUY ERRO "+
         IntegerToString(
            GetLastError()
         ),
         InpStopColor
      );

      return false;
   }

   StartBasketIfNeeded();

   SetStatus(
      "BUY "+
      DoubleToString(
         lots,
         2
      ),
      InpProfitColor
   );

   return true;
}

//====================================================================
// SELL
//====================================================================

bool ExecuteSell(
   double lots,
   bool isRed=false)
{
   lots=
      NormalizeLots(
         lots
      );

   if(lots<=0.0)
   {
      SetStatus(
         "LOTE SELL INVALIDO",
         InpStopColor
      );

      return false;
   }

   RefreshRates();

   ResetLastError();

   int ticket=
      OrderSend(
         Symbol(),
         OP_SELL,
         lots,
         Bid,
         InpSlippage,
         0,
         0,
         BuildOrderComment(isRed),
         InpMagicNumber,
         0,
         InpSellColor
      );

   if(ticket<0)
   {
      SetStatus(
         "SELL ERRO "+
         IntegerToString(
            GetLastError()
         ),
         InpStopColor
      );

      return false;
   }

   StartBasketIfNeeded();

   SetStatus(
      "SELL "+
      DoubleToString(
         lots,
         2
      ),
      InpProfitColor
   );

   return true;
}

//====================================================================
// PAINEL
//====================================================================

//====================================================================
// GEOMETRIA DO PAINEL / CORNER
//====================================================================
// As coordenadas usadas no BuildInterface sao coordenadas INTERNAS,
// sempre pensadas a partir do canto superior esquerdo do painel.
// Quando o painel vai para direita/baixo, convertemos essas coordenadas
// para que TODOS os objetos mantenham exatamente o mesmo layout interno.

int PanelObjectX(int localX,int objectWidth)
{
   if(InpPanelCorner==CORNER_RIGHT_UPPER ||
      InpPanelCorner==CORNER_RIGHT_LOWER)
      return MathMax(0,InpPanelWidth-localX-objectWidth);

   return localX;
}

int PanelObjectY(int localY,int objectHeight)
{
   if(InpPanelCorner==CORNER_LEFT_LOWER ||
      InpPanelCorner==CORNER_RIGHT_LOWER)
      return MathMax(0,InpPanelHeight-localY-objectHeight);

   return localY;
}

int EstimateLabelWidth(string text,int fontSize)
{
   int n=StringLen(text);

   // Aproximacao conservadora para Arial.
   int width=(int)MathRound(n*fontSize*0.62);

   if(width<1)
      width=1;

   if(width>InpPanelWidth)
      width=InpPanelWidth;

   return width;
}

void CreatePanel()
{
   if(ObjectFind(
      0,
      OBJ_PANEL)<0)
   {
      ObjectCreate(
         0,
         OBJ_PANEL,
         OBJ_RECTANGLE_LABEL,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_CORNER,
      InpPanelCorner
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_XDISTANCE,
      4
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_YDISTANCE,
      4
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_XSIZE,
      InpPanelWidth
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_YSIZE,
      570
   );

   // Fundo totalmente opaco.
   // Fundo SOLIDO do painel.
   // O OBJ_RECTANGLE_LABEL deve ficar na frente do grafico.
   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_BGCOLOR,
      clrBlack
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_COLOR,
      clrBlack
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_BACK,
      false
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_ZORDER,
      1
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_BORDER_COLOR,
      clrDimGray
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_SELECTED,
      false
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_HIDDEN,
      false
   );

   // O painel fica na frente das velas e dos niveis.
   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_BACK,
      false
   );

   // O painel e somente o FUNDO.
   // Ele nao pode ficar acima dos botoes/campos, pois nesse caso
   // captura os cliques e impede OBJ_BUTTON/OBJ_EDIT de receberem
   // CHARTEVENT_OBJECT_CLICK / ENDEDIT.
   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_ZORDER,
      1
   );

   ChartRedraw();
}

//====================================================================
// LABEL
//====================================================================

void CreateLabel(
   string name,
   string text,
   int x,
   int y,
   int size,
   color clr)
{
   if(ObjectFind(
      0,
      name)<0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_LABEL,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      InpPanelCorner
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      PanelObjectX(x,EstimateLabelWidth(text,size))
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      PanelObjectY(y,size+4)
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clr
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      size
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
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
      false
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
      OBJPROP_ZORDER,
      10
   );
}

//====================================================================
// UPDATE LABEL
//====================================================================

void UpdateLabel(
   string name,
   string text,
   color clr)
{
   if(ObjectFind(
      0,
      name)<0)
      return;

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clr
   );
}

//====================================================================
// STATUS
//====================================================================

void SetStatus(
   string text,
   color clr)
{
   UpdateLabel(
      OBJ_LBL_STATUS,
      text,
      clr
   );
}

//====================================================================
// BUTTON: SOMENTE CLIQUE, NUNCA ARRASTE
//====================================================================

void MakeButtonNonSelectable(string name)
{
   if(ObjectFind(0,name)<0)
      return;

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
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BACK,
      false
   );

   // Mantem o objeto acima do fundo do painel.
   ObjectSetInteger(
      0,
      name,
      OBJPROP_ZORDER,
      1002
   );
}

//====================================================================
// FEEDBACK VISUAL DO REDUCE
//====================================================================

void RestoreReduceButtonColor()
{
   if(g_reduceFeedbackButton=="")
      return;

   if(ObjectFind(0,g_reduceFeedbackButton)>=0)
   {
      ObjectSetInteger(
         0,
         g_reduceFeedbackButton,
         OBJPROP_BGCOLOR,
         g_reduceFeedbackNormal
      );
   }

   g_reduceFeedbackButton="";
   g_reduceFeedbackUntil=0;
}

void ShowReduceButtonFeedback(
   string buttonName,
   bool success)
{
   if(ObjectFind(0,buttonName)<0)
      return;

   RestoreReduceButtonColor();

   g_reduceFeedbackButton=buttonName;
   g_reduceFeedbackUntil=TimeCurrent()+2;

   if(buttonName==OBJ_BTN_REDUCE_BUY_WIN ||
      buttonName==OBJ_BTN_REDUCE_BUY_LOSS)
      g_reduceFeedbackNormal=clrDarkSlateBlue;
   else
   if(buttonName==OBJ_BTN_REDUCE_SELL_WIN ||
      buttonName==OBJ_BTN_REDUCE_SELL_LOSS)
      g_reduceFeedbackNormal=clrMaroon;
   else
      g_reduceFeedbackNormal=clrDarkGoldenrod;

   ObjectSetInteger(
      0,
      buttonName,
      OBJPROP_BGCOLOR,
      success ? InpProfitColor : InpStopColor
   );

   ObjectSetInteger(
      0,
      buttonName,
      OBJPROP_STATE,
      false
   );

   ObjectSetInteger(
      0,
      buttonName,
      OBJPROP_SELECTED,
      false
   );

   ChartRedraw();
}

//====================================================================
// RESET VISUAL DO BOTAO
//
// OBJPROP_STATE e o estado pressionado do OBJ_BUTTON.
// Depois do clique, forcamos false para o botao voltar imediatamente
// ao estado normal. O botao continua clicavel.
//====================================================================

void ResetButtonVisualState(string name)
{
   if(ObjectFind(0,name)<0)
      return;

   ObjectSetInteger(
      0,
      name,
      OBJPROP_STATE,
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
      OBJPROP_SELECTABLE,
      false
   );
}

void ResetAllButtonVisualStates()
{
   ResetButtonVisualState(OBJ_BTN_BUY);
   ResetButtonVisualState(OBJ_BTN_SELL);
   ResetButtonVisualState(OBJ_BTN_REDUCE_BUY_WIN);
   ResetButtonVisualState(OBJ_BTN_REDUCE_BUY_LOSS);
   ResetButtonVisualState(OBJ_BTN_REDUCE_SELL_WIN);
   ResetButtonVisualState(OBJ_BTN_REDUCE_SELL_LOSS);
   ResetButtonVisualState(OBJ_BTN_REDUCE_BOTH);
   ResetButtonVisualState(OBJ_BTN_CLOSE_ALL);
   ResetButtonVisualState(OBJ_BTN_RED);

   ResetButtonVisualState(OBJ_BTN_LOTS_MINUS_10);
   ResetButtonVisualState(OBJ_BTN_LOTS_MINUS_1);
   ResetButtonVisualState(OBJ_BTN_LOTS_PLUS_1);
   ResetButtonVisualState(OBJ_BTN_LOTS_PLUS_10);

   ResetButtonVisualState(OBJ_BTN_TARGET_MINUS);
   ResetButtonVisualState(OBJ_BTN_TARGET_PLUS);
   ResetButtonVisualState(OBJ_BTN_STOP_MINUS);
   ResetButtonVisualState(OBJ_BTN_STOP_PLUS);
}

//====================================================================
// BUTTON
//====================================================================

void CreateButton(
   string name,
   string text,
   int x,
   int y,
   int w,
   int h,
   color bg)
{
   if(ObjectFind(
      0,
      name)<0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_BUTTON,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      InpPanelCorner
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      PanelObjectX(x,w)
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      PanelObjectY(y,h)
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XSIZE,
      w
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YSIZE,
      h
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BGCOLOR,
      bg
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clrWhite
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      7
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      true
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
      OBJPROP_STATE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      false
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
      OBJPROP_ZORDER,
      1002
   );
}

//====================================================================
// EDIT
//====================================================================

void CreateEdit(
   string name,
   string value,
   int x,
   int y,
   int w,
   int h)
{
   if(ObjectFind(
      0,
      name)<0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_EDIT,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      InpPanelCorner
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      PanelObjectX(x,w)
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      PanelObjectY(y,h)
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XSIZE,
      w
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YSIZE,
      h
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BGCOLOR,
      clrBlack
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clrWhite
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BORDER_COLOR,
      clrDimGray
   );

   // Centraliza o valor dentro do campo.
   ObjectSetInteger(
      0,
      name,
      OBJPROP_ALIGN,
      ALIGN_CENTER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      8
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      true
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
      OBJPROP_ZORDER,
      1003
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      value
   );
}

//====================================================================
// CONSTRUI INTERFACE
//====================================================================

void BuildInterface()
{
   CreatePanel();

   //===============================================================
   // CABECALHO
   //===============================================================

   CreateLabel(
      OBJ_LBL_TITLE,
      "SENTINEL",
      16,
      13,
      15,
      clrWhite
   );

   CreateLabel(
      OBJ_LBL_SYMBOL,
      Symbol()+
      " TF "+
      IntegerToString(Period()),
      16,
      34,
      8,
      clrGold
   );

   CreateLabel(
      OBJ_LBL_MAGIC,
      "MAGIC: "+
      (InpMagicNumber==-1 ?
       "TODOS" :
       IntegerToString(InpMagicNumber)),
      190,
      34,
      8,
      clrDeepSkyBlue
   );

   //===============================================================
   // EXPOSICAO
   //===============================================================

   CreateLabel(
      OBJ_LBL_BUY,
      "BUY: 0.00",
      16,
      54,
      9,
      InpBuyColor
   );

   CreateLabel(
      OBJ_LBL_SELL,
      "SELL: 0.00",
      98,
      54,
      9,
      InpSellColor
   );

   CreateLabel(
      OBJ_LBL_NET,
      "NET: 0.00",
      190,
      54,
      9,
      InpProfitColor
   );

   CreateLabel(
      OBJ_LBL_EXPOSURE,
      "EXPOSICAO: 0.00",
      16,
      73,
      8,
      clrSilver
   );

   //===============================================================
   // ATR — LINHA COMPACTA
   //===============================================================

   CreateLabel(
      OBJ_LBL_ATR,
      "ATR (M15) 14    -- pts",
      10,
      91,
      8,
      clrSilver
   );

   CreateLabel(
      OBJ_LBL_ATR_REGIME,
      "DISTANCIA ATR: --",
      180,
      91,
      8,
      clrSilver
   );

   CreateLabel(
      OBJ_LBL_SIGNAL_BUY,
      "B: OK",
      196,
      107,
      8,
      InpBuyColor
   );

   CreateLabel(
      OBJ_LBL_SIGNAL_SELL,
      "S: OK",
      252,
      107,
      8,
      InpSellColor
   );

   //===============================================================
   // ENTRY ENGINE
   //===============================================================

   CreateLabel(
      OBJ_LBL_ENTRY_CONTEXT,
      "CONTEXTO: --",
      10,
      124,
      8,
      clrSilver
   );

   CreateLabel(
      OBJ_LBL_ENTRY_SIGNAL,
      "AGUARDAR",
      10,
      140,
      10,
      clrGold
   );

   CreateLabel(
      OBJ_LBL_ENTRY_SCORE,
      "NOVA: -- | --",
      158,
      142,
      8,
      clrSilver
   );

   //===============================================================
   // ABERTO — DESTAQUE
   //===============================================================

   CreateLabel(
      OBJ_LBL_OPEN,
      "ABERTO: 0.00",
      6,
      160,
      11,
      clrLimeGreen
   );

   //===============================================================
   // LOTES
   //===============================================================

   CreateLabel(
      OBJ_LBL_REDUCE,
      "LOTES",
      16,
      180,
      8,
      clrSilver
   );

   CreateButton(
      OBJ_BTN_LOTS_MINUS_10,
      "-10",
      70,
      174,
      25,
      20,
      clrMaroon
   );

   CreateButton(
      OBJ_BTN_LOTS_MINUS_1,
      "-1",
      97,
      174,
      22,
      20,
      clrMaroon
   );

   CreateEdit(
      OBJ_EDIT_LOTS,
      DoubleToString(g_selectedLots,2),
      121,
      174,
      50,
      20
   );

   CreateButton(
      OBJ_BTN_LOTS_PLUS_1,
      "+1",
      173,
      174,
      22,
      20,
      clrDarkGreen
   );

   CreateButton(
      OBJ_BTN_LOTS_PLUS_10,
      "+10",
      197,
      174,
      28,
      20,
      clrDarkGreen
   );

   //===============================================================
   // BUY / SELL
   //===============================================================

   CreateButton(
      OBJ_BTN_BUY,
      "COMPRAR",
      10,
      198,
      132,
      25,
      clrForestGreen
   );

   CreateButton(
      OBJ_BTN_SELL,
      "VENDER",
      148,
      198,
      132,
      25,
      clrFireBrick
   );

   //===============================================================
   // REDUCE BxS
   //===============================================================

   CreateButton(
      OBJ_BTN_REDUCE_BOTH,
      "REDUCE BxS",
      10,
      228,
      270,
      24,
      clrDimGray
   );

   //===============================================================
   // WIN / LOSS
   //===============================================================

   CreateButton(
      OBJ_BTN_REDUCE_BUY_WIN,
      "BUY WIN",
      10,
      257,
      65,
      24,
      clrDarkSlateBlue
   );

   CreateButton(
      OBJ_BTN_REDUCE_BUY_LOSS,
      "BUY LOSS",
      79,
      257,
      65,
      24,
      clrDarkSlateBlue
   );

   CreateButton(
      OBJ_BTN_REDUCE_SELL_WIN,
      "SELL WIN",
      148,
      257,
      65,
      24,
      clrMaroon
   );

   CreateButton(
      OBJ_BTN_REDUCE_SELL_LOSS,
      "SELL LOSS",
      217,
      257,
      63,
      24,
      clrMaroon
   );

   //===============================================================
   // TAKE
   //===============================================================

   CreateLabel(
      OBJ_LBL_TARGET_MONEY,
      "TAKE PTS",
      10,
      289,
      8,
      InpTakeColor
   );

   CreateButton(
      OBJ_BTN_TARGET_MINUS,
      "-",
      119,
      285,
      22,
      20,
      clrDarkGreen
   );

   CreateEdit(
      OBJ_EDIT_TARGET,
      DoubleToString(g_targetPoints,0),
      143,
      285,
      60,
      20
   );

   CreateButton(
      OBJ_BTN_TARGET_PLUS,
      "+",
      207,
      285,
      22,
      20,
      clrDarkGreen
   );

   //===============================================================
   // STOP
   //===============================================================

   CreateLabel(
      OBJ_LBL_STOP_MONEY,
      "STOP PTS",
      10,
      316,
      8,
      InpStopColor
   );

   CreateButton(
      OBJ_BTN_STOP_MINUS,
      "-",
      119,
      312,
      22,
      20,
      clrMaroon
   );

   CreateEdit(
      OBJ_EDIT_STOP,
      DoubleToString(g_stopPoints,0),
      143,
      312,
      60,
      20
   );

   CreateButton(
      OBJ_BTN_STOP_PLUS,
      "+",
      207,
      312,
      22,
      20,
      clrMaroon
   );

   //===============================================================
   // CLOSE ALL
   //===============================================================

   CreateButton(
      OBJ_BTN_CLOSE_ALL,
      "CLOSE ALL",
      10,
      345,
      270,
      28,
      clrDarkRed
   );

   //===============================================================
   // SELECAO DE ORDENS - CESTA MANAGER
   //===============================================================

   CreateLabel(
      OBJ_LBL_SELECTED_1,
      "T1",
      10,
      378,
      8,
      clrSilver
   );

   CreateEdit(
      OBJ_EDIT_SELECTED_1,
      "--",
      30,
      374,
      82,
      20
   );

   ObjectSetInteger(
      0,
      OBJ_EDIT_SELECTED_1,
      OBJPROP_READONLY,
      true
   );

   CreateLabel(
      OBJ_LBL_SELECTED_2,
      "T2",
      120,
      378,
      8,
      clrSilver
   );

   CreateEdit(
      OBJ_EDIT_SELECTED_2,
      "--",
      140,
      374,
      82,
      20
   );

   ObjectSetInteger(
      0,
      OBJ_EDIT_SELECTED_2,
      OBJPROP_READONLY,
      true
   );

   CreateButton(
      OBJ_BTN_CLEAR_SELECTED,
      "LIMPAR",
      230,
      374,
      50,
      20,
      clrDimGray
   );

   CreateLabel(
      OBJ_LBL_SELECTED_CALC,
      "SELECIONE ORDEM",
      10,
      400,
      8,
      clrGold
   );

   CreateLabel(
      OBJ_LBL_SELECTED_EXPOSURE,
      "RED: -- | EXP: -- -> --",
      10,
      416,
      8,
      clrSilver
   );

   CreateButton(
      OBJ_BTN_REDUCE_SELECTED,
      "REDUCE SELECIONADO",
      10,
      438,
      270,
      24,
      clrDimGray
   );

   //===============================================================
   // RED + STATUS
   //===============================================================

   CreateButton(
      OBJ_BTN_RED,
      "RED",
      116,
      474,
      60,
      18,
      clrDarkGoldenrod
   );

   CreateLabel(
      OBJ_LBL_STATUS,
      "SENTINEL ATIVO",
      186,
      478,
      8,
      clrLimeGreen
   );

   //===============================================================
   // RESULTADO DO PREGAO
   //===============================================================

   CreateLabel(
      OBJ_LBL_REALIZED,
      "REALIZADO: 0.00",
      6,
      510,
      9,
      clrLimeGreen
   );

   CreateLabel(
      OBJ_LBL_TODAY_RESULT,
      "DIA: 0.00 USD",
      6,
      532,
      10,
      InpProfitColor
   );
}

//====================================================================
// ATR — CONTEXTO OPERACIONAL
//====================================================================

double GetATRPoints()
{
   if(InpATRPeriod < 1)
      return 0.0;

   double atr = iATR(Symbol(), Period(), InpATRPeriod, 0);
   double point = AssetPoint();

   if(atr <= 0.0 || point <= 0.0)
      return 0.0;

   return atr / point;
}

double GetATRReferencePoints()
{
   if(InpATRPeriod < 1)
      return 0.0;

   int bars = iBars(Symbol(), Period());
   int samples = MathMin(50, MathMax(1, bars - InpATRPeriod - 1));

   if(samples <= 0)
      return 0.0;

   double sum = 0.0;
   int used = 0;
   double point = AssetPoint();

   if(point <= 0.0)
      return 0.0;

   for(int i=1; i<=samples; i++)
   {
      double atr = iATR(Symbol(), Period(), InpATRPeriod, i);

      if(atr <= 0.0)
         continue;

      sum += atr / point;
      used++;
   }

   if(used <= 0)
      return 0.0;

   return sum / used;
}

string GetATRRegime(double atrPts, double refPts)
{
   if(atrPts <= 0.0 || refPts <= 0.0)
      return "SEM DADOS";

   if(atrPts < refPts * InpATRLowFactor)
      return "BAIXO";

   if(atrPts > refPts * InpATRHighFactor)
      return "ALTO";

   return "NORMAL";
}

void UpdateATRContextPanel()
{
   if(!InpShowATRContext)
   {
      DeleteObjectSafe(OBJ_LBL_ATR);
      DeleteObjectSafe(OBJ_LBL_ATR_REGIME);
      DeleteObjectSafe(OBJ_LBL_SIGNAL_BUY);
      DeleteObjectSafe(OBJ_LBL_SIGNAL_SELL);
      return;
   }

   double atrPts = GetATRPoints();
   double refPts = GetATRReferencePoints();
   string regime = GetATRRegime(atrPts, refPts);

   color regimeColor = clrSilver;

   if(regime == "BAIXO")
      regimeColor = clrGold;
   else if(regime == "NORMAL")
      regimeColor = clrLimeGreen;
   else if(regime == "ALTO")
      regimeColor = clrOrangeRed;

   // A linha de ATR do painel passa a mostrar o ATR usado no
   // threshold de nova entrada: M5, barra fechada, multiplicador.
   double m5ATR=GetM5GateATRPoints();
   double m5Required=GetM5GateRequiredPoints();

   UpdateLabel(
      OBJ_LBL_ATR,
      "ATR M5 "+IntegerToString(InpATRPeriod)+
      "   "+DoubleToString(m5ATR,0)+" pts",
      clrSilver
   );

   string distText=
      "DIST M5: "+
      DoubleToString(m5Required,0)+
      " pts";

   UpdateLabel(
      OBJ_LBL_ATR_REGIME,
      distText,
      regimeColor
   );

   // B/S agora refletem o threshold real de nova entrada no M5.
   bool buyGate=IsM5BuyEntryAllowed();
   bool sellGate=IsM5SellEntryAllowed();

   UpdateLabel(
      OBJ_LBL_SIGNAL_BUY,
      buyGate ? "B: OK" : "B: WAIT",
      buyGate ? InpBuyColor : clrGold
   );

   UpdateLabel(
      OBJ_LBL_SIGNAL_SELL,
      sellGate ? "S: OK" : "S: WAIT",
      sellGate ? InpSellColor : clrGold
   );
}

//====================================================================
// ATUALIZA PAINEL
//====================================================================

void UpdateReduceBothAvailability()
{
   bool hasCompensation =
      (GetWinningLotsBySide(OP_BUY) > 0.00000001 &&
       GetWinningLotsBySide(OP_SELL) > 0.00000001);

   if(ObjectFind(0,OBJ_BTN_REDUCE_BOTH)<0)
      return;

   ObjectSetInteger(
      0,
      OBJ_BTN_REDUCE_BOTH,
      OBJPROP_BGCOLOR,
      hasCompensation ?
      clrDarkGoldenrod :
      clrDimGray
   );

   ObjectSetString(
      0,
      OBJ_BTN_REDUCE_BOTH,
      OBJPROP_TEXT,
      "REDUCE BxS"
   );
}

void UpdateInterface()
{
   UpdateTodayRealizedPanel();
   UpdateATRContextPanel();
   UpdateEntryEnginePanel();
   UpdateSelectedReductionPanel();

   ResetAllButtonVisualStates();
   double buy=
      GetBuyLots();

   double sell=
      GetSellLots();

   double net=
      buy-sell;

   double exposure=
      buy+sell;

   double realized=
      GetBasketRealized();

   double open=
      GetOpenProfit();

   //-----------------------------------------------------------------
   // BUY
   //-----------------------------------------------------------------

   UpdateLabel(
      OBJ_LBL_BUY,
      "BUY: "+
      DoubleToString(
         buy,
         2
      ),
      InpBuyColor
   );

   //-----------------------------------------------------------------
   // SELL
   //-----------------------------------------------------------------

   UpdateLabel(
      OBJ_LBL_SELL,
      "SELL: "+
      DoubleToString(
         sell,
         2
      ),
      InpSellColor
   );

   //-----------------------------------------------------------------
   // NET
   //-----------------------------------------------------------------

   string netText=
      "NET: "+
      DoubleToString(
         MathAbs(net),
         2
      );

   if(net>0.000001)
      netText+=" BUY";
   else
   if(net<-0.000001)
      netText+=" SELL";
   else
      netText+=" FLAT";

   UpdateLabel(
      OBJ_LBL_NET,
      netText,
      net>=0.0?
      InpProfitColor:
      InpSellColor
   );

   //-----------------------------------------------------------------
   // EXPOSICAO
   //-----------------------------------------------------------------

   UpdateLabel(
      OBJ_LBL_EXPOSURE,
      "EXPOSICAO: "+
      DoubleToString(
         exposure,
         2
      ),
      clrSilver
   );

   //-----------------------------------------------------------------
   // REALIZADO
   //-----------------------------------------------------------------

   UpdateLabel(
      OBJ_LBL_REALIZED,
      "REALIZADO: "+
      DoubleToString(
         realized,
         2
      ),
      realized>=0.0?
      InpProfitColor:
      InpSellColor
   );

   //-----------------------------------------------------------------
   // ABERTO
   //-----------------------------------------------------------------

   UpdateLabel(
      OBJ_LBL_OPEN,
      "ABERTO: "+
      DoubleToString(
         open,
         2
      ),
      open>=0.0?
      InpProfitColor:
      InpSellColor
   );

   // TOTAL foi removido da interface para evitar ambiguidade.
   // O placar do pregao e mostrado separadamente como DIA.
   UpdateReduceBothAvailability();
}


//====================================================================
// ARMA AUTO CLOSE
//====================================================================
//
// Regra de seguranca:
//
// O Sentinel NAO fecha uma cesta apenas porque, ao carregar/trocar
// o grafico, o preco atual ja esta do outro lado do TAKE/STOP.
//
// Primeiro o preco precisa estar no lado seguro do nivel.
// Depois, somente uma nova passagem pelo nivel pode disparar o
// fechamento automatico.
//====================================================================

void UpdateAutoCloseArming()
{
   if(CountOpenPositions()<=0)
   {
      g_targetAutoArmed=false;
      g_stopAutoArmed=false;
      return;
   }

   double buyLots=GetBuyLots();
   double sellLots=GetSellLots();
   double netLots=buyLots-sellLots;

   if(MathAbs(netLots)<0.00000001)
   {
      g_targetAutoArmed=false;
      g_stopAutoArmed=false;
      return;
   }

   RefreshRates();

   if(netLots>0.0)
   {
      // BUY: lado seguro = abaixo do TAKE / acima do STOP
      if(g_targetPrice>0.0 &&
         Bid<g_targetPrice)
      {
         g_targetAutoArmed=true;
      }

      if(g_stopPrice>0.0 &&
         Bid>g_stopPrice)
      {
         g_stopAutoArmed=true;
      }
   }
   else
   {
      // SELL: lado seguro = acima do TAKE / abaixo do STOP
      if(g_targetPrice>0.0 &&
         Ask>g_targetPrice)
      {
         g_targetAutoArmed=true;
      }

      if(g_stopPrice>0.0 &&
         Ask<g_stopPrice)
      {
         g_stopAutoArmed=true;
      }
   }
}

//====================================================================
// AUTO CLOSE
//====================================================================
//
// O fechamento automatico somente ocorre depois que o respectivo
// nivel foi ARMADO: primeiro o preco precisa visitar o lado seguro;
// somente uma nova passagem pelo nivel pode disparar o CLOSE ALL.
//
// Isso evita fechamento involuntario ao carregar/trocar o ativo ou
// ao alterar TAKE/STOP enquanto o preco ja esta alem do nivel.
//====================================================================

void CheckAutoClose()
{
   if(g_processing)
      return;

   // Protecao na inicializacao/recarregamento/troca de ativo.
   // O Sentinel reconhece a cesta, mas nao executa Auto Close
   // nos primeiros segundos do novo ciclo.
   if(TimeLocal()<g_autoCloseBlockedUntil)
   {
      UpdateAutoCloseArming();
      return;
   }

   UpdateAutoCloseArming();

   if(CountOpenPositions()<=0)
      return;

   double buyLots=GetBuyLots();
   double sellLots=GetSellLots();
   double netLots=buyLots-sellLots;

   if(MathAbs(netLots)<0.00000001)
      return;

   RefreshRates();

   //-----------------------------------------------------------------
   // BUY
   //-----------------------------------------------------------------

   if(netLots>0.0)
   {
      if(InpAutoCloseTarget &&
         g_targetAutoArmed &&
         g_targetPrice>0.0 &&
         Bid>=g_targetPrice)
      {
         g_processing=true;

         SetStatus(
            "TAKE ATINGIDO",
            InpTakeColor
         );

         CloseAllPositions();

         g_processing=false;

         return;
      }

      if(InpAutoCloseStop &&
         g_stopAutoArmed &&
         g_stopPrice>0.0 &&
         Bid<=g_stopPrice)
      {
         g_processing=true;

         SetStatus(
            "STOP ATINGIDO",
            InpStopColor
         );

         CloseAllPositions();

         g_processing=false;

         return;
      }
   }

   //-----------------------------------------------------------------
   // SELL
   //-----------------------------------------------------------------

   if(netLots<0.0)
   {
      if(InpAutoCloseTarget &&
         g_targetAutoArmed &&
         g_targetPrice>0.0 &&
         Ask<=g_targetPrice)
      {
         g_processing=true;

         SetStatus(
            "TAKE ATINGIDO",
            InpTakeColor
         );

         CloseAllPositions();

         g_processing=false;

         return;
      }

      if(InpAutoCloseStop &&
         g_stopAutoArmed &&
         g_stopPrice>0.0 &&
         Ask>=g_stopPrice)
      {
         g_processing=true;

         SetStatus(
            "STOP ATINGIDO",
            InpStopColor
         );

         CloseAllPositions();

         g_processing=false;

         return;
      }
   }
}

//====================================================================
// ARRASTE DA CAIXA
//
// Como a caixa usa CORNER_RIGHT_UPPER:
//
// YDISTANCE = distancia do topo.
//
// Pegamos o centro da caixa e convertemos para preco.
//
//====================================================================

void ProcessLevelLineDrag(
   string objectName)
{
   // TAKE/STOP nao sao mais arrastaveis.
   // O ajuste e feito exclusivamente pelos botoes +/- do painel.
   return;
}

//====================================================================
// PROCESSA EDICAO
//====================================================================

void ProcessEdit(
   string name)
{
   //-----------------------------------------------------------------
   // LOTES
   //-----------------------------------------------------------------

   if(name==OBJ_EDIT_LOTS)
   {
      double lots=
         StrToDouble(
            ObjectGetString(
               0,
               OBJ_EDIT_LOTS,
               OBJPROP_TEXT
            )
         );

      if(lots<MinLot())
         lots=MinLot();

      if(lots>MaxLot())
         lots=MaxLot();

      SetSelectedLots(lots);
      g_selectedLots=GetSelectedLots();
      GlobalVariableSet(SelectedLotsGlobalName(),g_selectedLots);

      SetStatus(
         "LOTE AJUSTADO",
         clrWhite
      );

      ChartRedraw();
      return;
   }

   //-----------------------------------------------------------------
   // TAKE EM PONTOS
   //-----------------------------------------------------------------

   if(name==OBJ_EDIT_TARGET)
   {
      string raw=
         ObjectGetString(
            0,
            OBJ_EDIT_TARGET,
            OBJPROP_TEXT
         );

      double value=StrToDouble(raw);

      if(value<InpMinimumPoints)
         value=InpMinimumPoints;

      g_targetPoints=value;

      ObjectSetString(
         0,
         OBJ_EDIT_TARGET,
         OBJPROP_TEXT,
         DoubleToString(
            g_targetPoints,
            0
         )
      );

      SetStatus(
         "TAKE PONTOS AJUSTADO",
         InpTakeColor
      );

      SaveLevelPointsToGlobals();
      UpdateTradingLevels();
      ChartRedraw();
      return;
   }

   //-----------------------------------------------------------------
   // STOP EM PONTOS
   //-----------------------------------------------------------------

   if(name==OBJ_EDIT_STOP)
   {
      string raw=
         ObjectGetString(
            0,
            OBJ_EDIT_STOP,
            OBJPROP_TEXT
         );

      double value=StrToDouble(raw);

      if(value<InpMinimumPoints)
         value=InpMinimumPoints;

      g_stopPoints=value;

      ObjectSetString(
         0,
         OBJ_EDIT_STOP,
         OBJPROP_TEXT,
         DoubleToString(
            g_stopPoints,
            0
         )
      );

      SetStatus(
         "STOP PONTOS AJUSTADO",
         InpStopColor
      );

      SaveLevelPointsToGlobals();
      UpdateTradingLevels();
      ChartRedraw();
      return;
   }
}

//====================================================================
// AJUSTE DOS PONTOS
//====================================================================

void AdjustTargetPoints(double delta)
{
   double step=GetLevelStepPoints();

   if(step<=0.0)
      step=1.0;

   g_targetPoints+=delta;

   if(g_targetPoints<InpMinimumPoints)
      g_targetPoints=InpMinimumPoints;

   g_targetPoints=
      MathRound(g_targetPoints/step)*
      step;

   if(g_targetPoints<InpMinimumPoints)
      g_targetPoints=InpMinimumPoints;

   ObjectSetString(
      0,
      OBJ_EDIT_TARGET,
      OBJPROP_TEXT,
      DoubleToString(
         g_targetPoints,
         0
      )
   );

   SaveLevelPointsToGlobals();
   UpdateTradingLevels();
}

void AdjustStopPoints(double delta)
{
   double step=GetLevelStepPoints();

   if(step<=0.0)
      step=1.0;

   g_stopPoints+= delta;

   if(g_stopPoints<InpMinimumPoints)
      g_stopPoints=InpMinimumPoints;

   g_stopPoints=
      MathRound(g_stopPoints/step)*
      step;

   if(g_stopPoints<InpMinimumPoints)
      g_stopPoints=InpMinimumPoints;

   ObjectSetString(
      0,
      OBJ_EDIT_STOP,
      OBJPROP_TEXT,
      DoubleToString(
         g_stopPoints,
         0
      )
   );

   SaveLevelPointsToGlobals();
   UpdateTradingLevels();
}

//====================================================================
// CONTROLE DE LOTES
//
// -1  = 1 x LOTSTEP do ativo
// -10 = 10 x LOTSTEP do ativo
// +1  = 1 x LOTSTEP do ativo
// +10 = 10 x LOTSTEP do ativo
//====================================================================

double GetSelectedLots()
{
   double lots=
      StrToDouble(
         ObjectGetString(
            0,
            OBJ_EDIT_LOTS,
            OBJPROP_TEXT
         )
      );

   if(lots<=0.0)
      lots=MinLot();

   return NormalizeLots(lots);
}

void SetSelectedLots(double lots)
{
   lots=NormalizeLots(lots);

   if(lots<=0.0)
      lots=MinLot();

   g_selectedLots=lots;

   ObjectSetString(
      0,
      OBJ_EDIT_LOTS,
      OBJPROP_TEXT,
      DoubleToString(
         lots,
         2
      )
   );
}

void AdjustLotsByStep(double multiplier)
{
   double step=LotStep();

   if(step<=0.0)
      step=0.01;

   double lots=
      GetSelectedLots();

   lots += step*multiplier;

   if(lots<MinLot())
      lots=MinLot();

   if(lots>MaxLot())
      lots=MaxLot();

   SetSelectedLots(lots);
   GlobalVariableSet(SelectedLotsGlobalName(),g_selectedLots);

   SetStatus(
      "LOTE "+
      DoubleToString(lots,2),
      clrWhite
   );

   ChartRedraw();
}

//====================================================================
// PROCESSA BOTOES
//====================================================================

void ProcessButton(
   string name)
{
   double lots=
      StrToDouble(
         ObjectGetString(
            0,
            OBJ_EDIT_LOTS,
            OBJPROP_TEXT
         )
      );

   //-----------------------------------------------------------------
   // REDUCE SELECIONADO
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_REDUCE_SELECTED)
   {
      bool ok=ExecuteSelectedReduction();

      ShowReduceButtonFeedback(
         OBJ_BTN_REDUCE_SELECTED,
         ok
      );

      return;
   }

   //-----------------------------------------------------------------
   // LIMPAR SELECAO
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_CLEAR_SELECTED)
   {
      ClearSelectedTickets();

      SetStatus(
         "SELECAO LIMPA",
         clrSilver
      );

      return;
   }

   //-----------------------------------------------------------------
   // LOTES -10
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_LOTS_MINUS_10)
   {
      AdjustLotsByStep(-10.0);
      return;
   }

   // LOTES -1
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_LOTS_MINUS_1)
   {
      AdjustLotsByStep(-1.0);
      return;
   }

   // LOTES +1
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_LOTS_PLUS_1)
   {
      AdjustLotsByStep(1.0);
      return;
   }

   // LOTES +10
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_LOTS_PLUS_10)
   {
      AdjustLotsByStep(10.0);
      return;
   }

   // TAKE -
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_TARGET_MINUS)
   {
      AdjustTargetPoints(
         -GetLevelStepPoints()
      );
      SetStatus(
         "TAKE -",
         InpTakeColor
      );
      return;
   }

   //-----------------------------------------------------------------
   // TAKE +
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_TARGET_PLUS)
   {
      AdjustTargetPoints(
         GetLevelStepPoints()
      );
      SetStatus(
         "TAKE +",
         InpTakeColor
      );
      return;
   }

   //-----------------------------------------------------------------
   // STOP -
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_STOP_MINUS)
   {
      AdjustStopPoints(
         -GetLevelStepPoints()
      );
      SetStatus(
         "STOP -",
         InpStopColor
      );
      return;
   }

   //-----------------------------------------------------------------
   // STOP +
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_STOP_PLUS)
   {
      AdjustStopPoints(
         GetLevelStepPoints()
      );
      SetStatus(
         "STOP +",
         InpStopColor
      );
      return;
   }

   //-----------------------------------------------------------------
   // BUY
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_BUY)
   {
      ExecuteBuy(lots);
      return;
   }

   //-----------------------------------------------------------------
   // SELL
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_SELL)
   {
      ExecuteSell(lots);
      return;
   }

   //-----------------------------------------------------------------
   // DESF BUY WIN
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_REDUCE_BUY_WIN)
   {
      bool reduceResult=
         ReduceSideByResult(
            OP_BUY,
            lots,
            true
         );

      ShowReduceButtonFeedback(
         OBJ_BTN_REDUCE_BUY_WIN,
         reduceResult
      );

      return;
   }

   //-----------------------------------------------------------------
   // DESF BUY LOSS
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_REDUCE_BUY_LOSS)
   {
      bool reduceResult=
         ReduceSideByResult(
            OP_BUY,
            lots,
            false
         );

      ShowReduceButtonFeedback(
         OBJ_BTN_REDUCE_BUY_LOSS,
         reduceResult
      );

      return;
   }

   //-----------------------------------------------------------------
   // DESF SELL WIN
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_REDUCE_SELL_WIN)
   {
      bool reduceResult=
         ReduceSideByResult(
            OP_SELL,
            lots,
            true
         );

      ShowReduceButtonFeedback(
         OBJ_BTN_REDUCE_SELL_WIN,
         reduceResult
      );

      return;
   }

   //-----------------------------------------------------------------
   // DESF SELL LOSS
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_REDUCE_SELL_LOSS)
   {
      bool reduceResult=
         ReduceSideByResult(
            OP_SELL,
            lots,
            false
         );

      ShowReduceButtonFeedback(
         OBJ_BTN_REDUCE_SELL_LOSS,
         reduceResult
      );

      return;
   }

   //-----------------------------------------------------------------
   // REDUCE BxS
   //
   // So pode executar quando existe BUY e SELL simultaneamente.
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_REDUCE_BOTH)
   {
      double buyWinningLots=
         GetWinningLotsBySide(OP_BUY);

      double sellWinningLots=
         GetWinningLotsBySide(OP_SELL);

      if(buyWinningLots<=0.0 ||
         sellWinningLots<=0.0)
      {
         SetStatus(
            "REDUCE: SEM 2 LADOS WIN",
            InpStopColor
         );

         ShowReduceButtonFeedback(
            OBJ_BTN_REDUCE_BOTH,
            false
         );

         return;
      }

      bool reduceResult=
         ReduceBothSides(
            lots
         );

      ShowReduceButtonFeedback(
         OBJ_BTN_REDUCE_BOTH,
         reduceResult
      );

      return;
   }

   //-----------------------------------------------------------------
   // CLOSE ALL
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_CLOSE_ALL)
   {
      CloseAllPositions();
      return;
   }

   //-----------------------------------------------------------------
   // RED - REBALANCEAR
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_RED)
   {
      RebalanceSides();
      return;
   }
}

//====================================================================
// DELETE SENTINEL OBJECTS
//====================================================================

void DeleteAllSentinelObjects()
{
   DeleteObjectSafe(OBJ_PANEL);

   DeleteObjectSafe(OBJ_LBL_TITLE);
   DeleteObjectSafe(OBJ_LBL_SYMBOL);
   DeleteObjectSafe(OBJ_LBL_MAGIC);

   DeleteObjectSafe(OBJ_LBL_BUY);
   DeleteObjectSafe(OBJ_LBL_SELL);
   DeleteObjectSafe(OBJ_LBL_NET);
   DeleteObjectSafe(OBJ_LBL_EXPOSURE);

   DeleteObjectSafe(OBJ_LBL_REALIZED);
   DeleteObjectSafe(OBJ_LBL_OPEN);

   DeleteObjectSafe(OBJ_LBL_REDUCE);

   DeleteObjectSafe(OBJ_LBL_TARGET_MONEY);
   DeleteObjectSafe(OBJ_LBL_STOP_MONEY);

   DeleteObjectSafe(OBJ_EDIT_LOTS);

   DeleteObjectSafe(OBJ_BTN_LOTS_MINUS_10);
   DeleteObjectSafe(OBJ_BTN_LOTS_MINUS_1);
   DeleteObjectSafe(OBJ_BTN_LOTS_PLUS_1);
   DeleteObjectSafe(OBJ_BTN_LOTS_PLUS_10);

   DeleteObjectSafe(OBJ_EDIT_TARGET);
   DeleteObjectSafe(OBJ_EDIT_STOP);

   DeleteObjectSafe(OBJ_BTN_BUY);
   DeleteObjectSafe(OBJ_BTN_SELL);

   DeleteObjectSafe(OBJ_BTN_REDUCE_BUY_WIN);
   DeleteObjectSafe(OBJ_BTN_REDUCE_BUY_LOSS);
   DeleteObjectSafe(OBJ_BTN_REDUCE_SELL_WIN);
   DeleteObjectSafe(OBJ_BTN_REDUCE_SELL_LOSS);
   DeleteObjectSafe(OBJ_BTN_REDUCE_BOTH);
   DeleteObjectSafe(OBJ_EDIT_SELECTED_1);
   DeleteObjectSafe(OBJ_EDIT_SELECTED_2);
   DeleteObjectSafe(OBJ_LBL_SELECTED_1);
   DeleteObjectSafe(OBJ_LBL_SELECTED_2);
   DeleteObjectSafe(OBJ_LBL_SELECTED_CALC);
   DeleteObjectSafe(OBJ_LBL_SELECTED_EXPOSURE);
   DeleteObjectSafe(OBJ_BTN_REDUCE_SELECTED);
   DeleteObjectSafe(OBJ_BTN_CLEAR_SELECTED);

   DeleteObjectSafe(OBJ_BTN_CLOSE_ALL);
   DeleteObjectSafe(OBJ_BTN_RED);

   DeleteObjectSafe(OBJ_BTN_TARGET_MINUS);
   DeleteObjectSafe(OBJ_BTN_TARGET_PLUS);
   DeleteObjectSafe(OBJ_BTN_STOP_MINUS);
   DeleteObjectSafe(OBJ_BTN_STOP_PLUS);

   DeleteObjectSafe(OBJ_LBL_STATUS);
   DeleteObjectSafe(OBJ_LBL_CHART_PROFIT);

   DeleteObjectSafe(OBJ_LBL_ATR);
   DeleteObjectSafe(OBJ_LBL_ATR_REGIME);
   DeleteObjectSafe(OBJ_LBL_SIGNAL_BUY);
   DeleteObjectSafe(OBJ_LBL_SIGNAL_SELL);

   DeleteObjectSafe(OBJ_LBL_ENTRY_CONTEXT);
   DeleteObjectSafe(OBJ_LBL_ENTRY_SIGNAL);
   DeleteObjectSafe(OBJ_LBL_ENTRY_SCORE);

   DeleteObjectSafe(OBJ_LINE_AVG_BUY);
   DeleteObjectSafe(OBJ_LINE_BE);

   DeleteObjectSafe(OBJ_TXT_BE);

   DeleteObjectSafe(OBJ_LINE_TARGET);
   DeleteObjectSafe(OBJ_LINE_STOP);

   DeleteObjectSafe(OBJ_TXT_TARGET);
   DeleteObjectSafe(OBJ_TXT_STOP);

   DeleteObjectSafe(OBJ_TXT_TARGET);
   DeleteObjectSafe(OBJ_TXT_STOP);
}

//====================================================================
// INIT
//====================================================================

//====================================================================
// LIMPEZA DOS OBJETOS VISUAIS DO SENTINEL
//====================================================================
// Remove somente objetos pertencentes ao SENTINEL.
// Nao remove linhas/desenhos manuais do usuario que nao usem o prefixo.
void DeleteAllSentinelNamedObjects()
{
   int total=ObjectsTotal((long)0,-1,-1);

   for(int i=total-1;i>=0;i--)
   {
      string name=ObjectName(0,i);

      if(name=="")
         continue;

      if(StringFind(name,"SENTINEL",0)>=0)
         ObjectDelete(0,name);
   }
}

int OnInit()
{
   // Limpa objetos de versões anteriores antes de reconstruir o painel.
   DeleteAllSentinelNamedObjects();

   //===============================================================
   // PRIMEIRA FONTE DE VERDADE: GLOBAL VARIABLES DO MT4
   //===============================================================
   //
   // Ao trocar o timeframe o MT4 destroi e recria o EA.
   // Portanto NAO podemos inicializar o painel com os INPUTS antes
   // de consultar as Global Variables. Os INPUTS sao apenas valores
   // de bootstrap, usados quando ainda nao existe uma Global Variable.
   //
   // Ordem correta no refresh:
   //   1) ler Global Variables
   //   2) se nao existirem, usar INPUTS
   //   3) construir o painel com os valores recuperados
   //
   LoadPanelSettingsFromGlobals();

   // Garante que, na primeira execucao, os valores de bootstrap
   // tambem passam a existir nas Global Variables.
   if(!GlobalVariableCheck(SelectedLotsGlobalName()) ||
      !GlobalVariableCheck(TargetPointsGlobalName()) ||
      !GlobalVariableCheck(StopPointsGlobalName()))
   {
      SavePanelSettingsToGlobals();
   }

   g_targetMoney=0.0;
   g_stopMoney=0.0;

   g_targetPrice=0.0;
   g_stopPrice=0.0;

   g_targetUserSet=false;
   g_stopUserSet=false;

   g_targetAutoArmed=false;
   g_stopAutoArmed=false;

   //===============================================================
   // PROTECAO CONTRA AUTO CLOSE NA INICIALIZACAO
   //===============================================================
   //
   // Ao trocar de ativo, o MT4 recria o EA. Se ja existirem
   // posicoes naquele ativo, primeiro reconhecemos a cesta e
   // montamos o painel/linhas. O Auto Close fica temporariamente
   // bloqueado para evitar fechamento involuntario.
   g_autoCloseBlockedUntil=
      TimeLocal()+5;

   //===============================================================
   // FORCA O GRAFICO PARA TRAS DOS OBJETOS
   //===============================================================
   //
   // Esta e a correcao principal da v1.15.
   // CHART_FOREGROUND=true faz as velas aparecerem por cima
   // dos objetos. O painel precisa ser um overlay real.
   //
   g_chartForegroundOriginal=
      (bool)ChartGetInteger(
         0,
         CHART_FOREGROUND
      );

   g_chartForegroundCaptured=true;

   ChartSetInteger(
      0,
      CHART_FOREGROUND,
      false
   );

   // Garante que o MT4 entregue eventos de arraste dos objetos.
   ChartSetInteger(
      0,
      CHART_EVENT_MOUSE_MOVE,
      true
   );

   ChartRedraw();

   BuildInterface();
   UpdateATRContextPanel();
   UpdateEntryEnginePanel();
   // Campos TAKE/STOP: mais espaço, fonte maior e texto centralizado.
   if(ObjectFind(0,OBJ_EDIT_TARGET)>=0)
   {
      ObjectSetInteger(0,OBJ_EDIT_TARGET,OBJPROP_FONTSIZE,10);
      ObjectSetInteger(0,OBJ_EDIT_TARGET,OBJPROP_ALIGN,ALIGN_CENTER);
   }

   if(ObjectFind(0,OBJ_EDIT_STOP)>=0)
   {
      ObjectSetInteger(0,OBJ_EDIT_STOP,OBJPROP_FONTSIZE,10);
      ObjectSetInteger(0,OBJ_EDIT_STOP,OBJPROP_ALIGN,ALIGN_CENTER);
   }


   //===============================================================
   // TODOS OS BOTOES: CLICAVEIS, MAS NAO ARRASTAVEIS
   //===============================================================
   MakeButtonNonSelectable(OBJ_BTN_BUY);
   MakeButtonNonSelectable(OBJ_BTN_SELL);
   MakeButtonNonSelectable(OBJ_BTN_REDUCE_BUY_WIN);
   MakeButtonNonSelectable(OBJ_BTN_REDUCE_BUY_LOSS);
   MakeButtonNonSelectable(OBJ_BTN_REDUCE_SELL_WIN);
   MakeButtonNonSelectable(OBJ_BTN_REDUCE_SELL_LOSS);
   // Tipografia compacta dos comandos de reducao.
   if(ObjectFind(0,OBJ_BTN_REDUCE_BUY_WIN)>=0)
      ObjectSetInteger(0,OBJ_BTN_REDUCE_BUY_WIN,OBJPROP_FONTSIZE,7);
   if(ObjectFind(0,OBJ_BTN_REDUCE_BUY_LOSS)>=0)
      ObjectSetInteger(0,OBJ_BTN_REDUCE_BUY_LOSS,OBJPROP_FONTSIZE,7);
   if(ObjectFind(0,OBJ_BTN_REDUCE_SELL_WIN)>=0)
      ObjectSetInteger(0,OBJ_BTN_REDUCE_SELL_WIN,OBJPROP_FONTSIZE,7);
   if(ObjectFind(0,OBJ_BTN_REDUCE_SELL_LOSS)>=0)
      ObjectSetInteger(0,OBJ_BTN_REDUCE_SELL_LOSS,OBJPROP_FONTSIZE,7);
   if(ObjectFind(0,OBJ_BTN_REDUCE_BOTH)>=0)
      ObjectSetInteger(0,OBJ_BTN_REDUCE_BOTH,OBJPROP_FONTSIZE,7);

   MakeButtonNonSelectable(OBJ_BTN_REDUCE_BOTH);
   MakeButtonNonSelectable(OBJ_BTN_CLOSE_ALL);
   MakeButtonNonSelectable(OBJ_BTN_RED);

   MakeButtonNonSelectable(OBJ_BTN_LOTS_MINUS_10);
   MakeButtonNonSelectable(OBJ_BTN_LOTS_MINUS_1);
   MakeButtonNonSelectable(OBJ_BTN_LOTS_PLUS_1);
   MakeButtonNonSelectable(OBJ_BTN_LOTS_PLUS_10);

   MakeButtonNonSelectable(OBJ_BTN_TARGET_MINUS);
   MakeButtonNonSelectable(OBJ_BTN_TARGET_PLUS);
   MakeButtonNonSelectable(OBJ_BTN_STOP_MINUS);
   MakeButtonNonSelectable(OBJ_BTN_STOP_PLUS);

   StartBasketIfNeeded();

   UpdateInterface();

   UpdateTradingObjects();

   EventSetTimer(1);

   SetStatus(
      "SENTINEL ATIVO",
      clrLimeGreen
   );

   ChartRedraw();

   return(
      INIT_SUCCEEDED
   );
}

//====================================================================
// DEINIT
//====================================================================

void OnDeinit(
   const int reason)
{
   DeleteAllSentinelNamedObjects();

   RestoreReduceButtonColor();

   RemoveLegacyLevelObjects();
   EventKillTimer();

   DeleteAllSentinelObjects();

   // Restaura a configuracao original do grafico.
   if(g_chartForegroundCaptured)
   {
      ChartSetInteger(
         0,
         CHART_FOREGROUND,
         g_chartForegroundOriginal
      );
   }

   ChartRedraw();
   DeleteObjectSafe(OBJ_LBL_TODAY_RESULT);

   DeleteObjectSafe(OBJ_LINE_AVG_BUY);
   DeleteObjectSafe(OBJ_LINE_AVG_SELL);
   DeleteObjectSafe(OBJ_LINE_PROJ_BUY);
   DeleteObjectSafe(OBJ_LINE_PROJ_SELL);

}

//====================================================================
// TICK
//====================================================================

void OnTick()
{
   UpdateTodayRealizedPanel();

   StartBasketIfNeeded();

   EndBasketIfNeeded();

   UpdateInterface();

   UpdateTradingObjects();

   CheckAutoClose();

   ChartRedraw();
}

//====================================================================
// TIMER
//====================================================================

void OnTimer()
{
   if(g_reduceFeedbackButton!="" &&
      TimeCurrent()>=g_reduceFeedbackUntil)
   {
      RestoreReduceButtonColor();
   }

   StartBasketIfNeeded();

   EndBasketIfNeeded();

   UpdateInterface();

   UpdateTradingObjects();

   CheckAutoClose();

   ChartRedraw();
}

//====================================================================
// ARRASTE TAKE / STOP
//====================================================================

void ProcessLevelDrag(string objectName)
{
   if(objectName!=OBJ_LINE_TARGET &&
      objectName!=OBJ_LINE_STOP)
      return;

   if(CountOpenPositions()<=0)
      return;

   double average=GetAverageOpenPrice();
   double point=AssetPoint();

   if(average<=0.0 || point<=0.0)
      return;

   double newPrice=
      ObjectGetDouble(
         0,
         objectName,
         OBJPROP_PRICE1
      );

   if(newPrice<=0.0)
      return;

   newPrice=NormalizePrice(newPrice);

   double buyLots=GetBuyLots();
   double sellLots=GetSellLots();
   double netLots=buyLots-sellLots;

   if(MathAbs(netLots)<0.00000001)
      return;

   //-----------------------------------------------------------------
   // TAKE
   //-----------------------------------------------------------------

   if(objectName==OBJ_LINE_TARGET)
   {
      if(netLots>0.0)
      {
         double minPrice=
            average+
            InpMinimumPoints*point;

         if(newPrice<minPrice)
            newPrice=minPrice;
      }
      else
      {
         double maxPrice=
            average-
            InpMinimumPoints*point;

         if(newPrice>maxPrice)
            newPrice=maxPrice;
      }

      newPrice=NormalizePrice(newPrice);

      g_targetPrice=newPrice;

      g_targetPoints=
         MathMax(
            InpMinimumPoints,
            MathAbs(g_targetPrice-average)/point
         );

      g_targetPoints=
         NormalizeDouble(
            g_targetPoints,
            1
         );

      ObjectSetString(
         0,
         OBJ_EDIT_TARGET,
         OBJPROP_TEXT,
         DoubleToString(g_targetPoints,0)
      );

      SetStatus("TAKE ARRASTADO",InpTakeColor);
   }

   //-----------------------------------------------------------------
   // STOP
   //-----------------------------------------------------------------

   if(objectName==OBJ_LINE_STOP)
   {
      if(netLots>0.0)
      {
         double maxPrice=
            average-
            InpMinimumPoints*point;

         if(newPrice>maxPrice)
            newPrice=maxPrice;
      }
      else
      {
         double minPrice=
            average+
            InpMinimumPoints*point;

         if(newPrice<minPrice)
            newPrice=minPrice;
      }

      newPrice=NormalizePrice(newPrice);

      g_stopPrice=newPrice;

      g_stopPoints=
         MathMax(
            InpMinimumPoints,
            MathAbs(g_stopPrice-average)/point
         );

      g_stopPoints=
         NormalizeDouble(
            g_stopPoints,
            1
         );

      ObjectSetString(
         0,
         OBJ_EDIT_STOP,
         OBJPROP_TEXT,
         DoubleToString(g_stopPoints,0)
      );

      SetStatus("STOP ARRASTADO",InpStopColor);
   }

   g_targetMoney=BasketProfitAtPrice(g_targetPrice);
   g_stopMoney=BasketProfitAtPrice(g_stopPrice);

   SaveLevelPointsToGlobals();
   UpdateTradingLevels();

   ChartRedraw();
}

//====================================================================
// CHART EVENT
//====================================================================

void OnChartEvent(
   const int id,
   const long &lparam,
   const double &dparam,
   const string &sparam)
{
   //-----------------------------------------------------------------
   // CLIQUE
   //-----------------------------------------------------------------

   if(id==CHARTEVENT_OBJECT_CLICK)
   {
      // O fundo do painel tem ZORDER=1; somente controles ficam em
      // ZORDER alto, portanto o clique chega aqui normalmente.
      // O MT4 pode manter OBJPROP_STATE=true apos o clique.
      // Resetamos antes e depois da acao para o botao nunca ficar
      // visualmente "pressionado".
      ResetButtonVisualState(sparam);

      ProcessButton(
         sparam
      );

      ResetAllButtonVisualStates();

      UpdateInterface();

      UpdateTradingObjects();

      ChartRedraw();

      return;
   }

   //-----------------------------------------------------------------
   // FIM DA EDICAO
   //-----------------------------------------------------------------

   if(id==CHARTEVENT_OBJECT_ENDEDIT ||
      id==CHARTEVENT_OBJECT_CHANGE)
   {
      if(sparam==OBJ_EDIT_LOTS ||
         sparam==OBJ_EDIT_TARGET ||
         sparam==OBJ_EDIT_STOP)
      {
         ProcessEdit(
            sparam
         );
      }

      return;
   }

   //=================================================================
   // ARRASTE TAKE / STOP
   //=================================================================

   if(id==CHARTEVENT_OBJECT_DRAG)
   {
      if(sparam==OBJ_LINE_TARGET ||
         sparam==OBJ_LINE_STOP)
      {
         ProcessLevelDrag(sparam);
      }

      return;
   }
}

//+------------------------------------------------------------------+
//|                        FIM SENTINEL v1.30                        |
//+------------------------------------------------------------------+