//+------------------------------------------------------------------+
//|                                                   SENTINEL.mq4   |
//|                    SENTINEL Operational Panel                    |
//|                                                                  |
//| Version 1.45                                                      |
//|                                                                  |
//| - BUY / SELL                                                     |
//| - REDUCE BxS / CURRENT GROUP                                         |
//| - CLOSE ALL                                                       |
//| - Cesta dinamica                                                  |
//| - Realizado / Aberto / Total                                      |
//| - Medio dinamico                                                  |
//| - BE dinamico                                                      |
//| - TAKE / STOP como linhas pontilhadas                                |
//| - TAKE / STOP controlados por +/- pontos                                         |
//| - Painel compacto, opaco e reorganizado                          
//| - Alteracao de TAKE/STOP no painel recalcula imediatamente       |
//+------------------------------------------------------------------+
#property strict
#property version "1.45"



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
input bool     InpTestMode          = false;

// Comentario gravado nas novas ordens do SENTINEL.
// RED acrescenta automaticamente " RED" ao final.
input string   InpOrderComment      = "SENTINEL";
input double   InpDefaultLots       = 0.02;

input bool     InpAutoReduceDefault   = false;
input double   InpAutoReduceMinProfit = 20.0;
input double   InpAutoReduceLots      = 0.10;

input double   InpTargetPoints     = 32000.0;
input double   InpStopPoints       = 32000.0;
input double   InpPointsStep        = 5.0;
input double   InpMinimumPoints     = 1.0;

// Passo dos botoes TAKE/STOP por ativo.
input double   InpLevelStepDefault = 5.0;
input double   InpLevelStepXAUUSD  = 2000.0;
input double   InpLevelStepBTCUSD  = 2000.0;

//====================================================================
// RECOVERY / TRAILING
//====================================================================
// Recovery uses the LAST MARKET ORDER of each direction as reference.
// No FirstStep is used here. Distances are in symbol points.
input double   InpRecoveryTriggerDistance = 280.0;
input double   InpRecoveryStepDistance    = 340.0;
input double   InpRecoveryStepMultiplier  = 1.15;
input double   InpRecoveryStepMax         = 500.0;
input double   InpRecoveryLotMultiplier   = 1.10;
input double   InpRecoveryLotIncrement    = 0.02;
input double   InpRecoveryMaxLot          = 3.00;
input bool     InpRecoveryTrailingDefault = true;
input double   InpRecoveryTrailingStep   = 50.0;

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

input int InpPanelX      = 4;
input int InpPanelY      = 4;
input int InpPanelWidth  = 300;
input int InpPanelHeight = 560;

#define UI_COLOR_CARD          C'30,30,30'
#define UI_COLOR_CARD_BORDER   C'48,52,62'
#define UI_COLOR_TEXT_MAIN     C'240,240,240'
#define UI_COLOR_TEXT_MUTED    C'150,150,150'
#define UI_COLOR_NEUTRAL       C'60,60,60'
#define UI_COLOR_ACCENT        C'210,153,34'

input color InpPanelColor     = C'20,20,20';
input color InpBuyColor       = C'38,160,76';
input color InpSellColor      = C'210,62,58';
input color InpProfitColor    = C'57,180,96';

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

#define OBJ_BTN_AUTO_MIN_MINUS_10 PREFIX+"BTN_AUTO_MIN_MINUS_10"
#define OBJ_BTN_AUTO_MIN_MINUS_1  PREFIX+"BTN_AUTO_MIN_MINUS_1"
#define OBJ_BTN_AUTO_MIN_PLUS_1   PREFIX+"BTN_AUTO_MIN_PLUS_1"
#define OBJ_BTN_AUTO_MIN_PLUS_10  PREFIX+"BTN_AUTO_MIN_PLUS_10"

#define OBJ_EDIT_TARGET        PREFIX+"EDIT_TARGET"
#define OBJ_EDIT_STOP          PREFIX+"EDIT_STOP"

#define OBJ_BTN_BUY            PREFIX+"BTN_BUY"
#define OBJ_BTN_SELL           PREFIX+"BTN_SELL"

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
#define OBJ_LBL_SELECTED_3    PREFIX+"LBL_SELECTED_3"
#define OBJ_LBL_SELECTED_CALC PREFIX+"LBL_SELECTED_CALC"
#define OBJ_LBL_SELECTED_SOURCE PREFIX+"LBL_SELECTED_SOURCE"
#define OBJ_LBL_SELECTED_EXPOSURE PREFIX+"LBL_SELECTED_EXPOSURE"
#define OBJ_BTN_REDUCE_SELECTED PREFIX+"BTN_REDUCE_SELECTED"
#define OBJ_BTN_CLEAR_SELECTED PREFIX+"BTN_CLEAR_SELECTED"
#define OBJ_BTN_AUTO_REDUCE      PREFIX+"BTN_AUTO_REDUCE"
#define OBJ_BTN_RECOVERY          PREFIX+"BTN_RECOVERY"
#define OBJ_LBL_RECOVERY_TELEMETRY PREFIX+"LBL_RECOVERY_TELEMETRY"
#define OBJ_EDIT_AUTO_MIN        PREFIX+"EDIT_AUTO_MIN"
#define OBJ_LBL_GROUP_TITLE    PREFIX+"LBL_GROUP_TITLE"
#define OBJ_LBL_GROUP_TARGET   PREFIX+"LBL_GROUP_TARGET"
#define OBJ_LBL_GROUP_REFERENCE PREFIX+"LBL_GROUP_REFERENCE"
#define OBJ_LBL_GROUP_NET      PREFIX+"LBL_GROUP_NET"
#define OBJ_LBL_GROUP_EXPOSURE PREFIX+"LBL_GROUP_EXPOSURE"
#define OBJ_LBL_GROUP_RESULT   PREFIX+"LBL_GROUP_RESULT"
#define OBJ_LBL_GROUP_CALC     PREFIX+"LBL_GROUP_CALC"
#define OBJ_LBL_GROUP_WIN      PREFIX+"LBL_GROUP_WIN"
#define OBJ_LBL_GROUP_NEED     PREFIX+"LBL_GROUP_NEED"

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
#define OBJ_LINE_SELECTED_TARGET PREFIX+"LINE_SELECTED_TARGET"
#define OBJ_LINE_SELECTED_REFERENCE PREFIX+"LINE_SELECTED_REFERENCE"
#define OBJ_TXT_SELECTED_TARGET PREFIX+"TXT_SELECTED_TARGET"
#define OBJ_TXT_SELECTED_REFERENCE PREFIX+"TXT_SELECTED_REFERENCE"
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

bool g_recoveryEnabled = false;
bool g_recoveryTrailingEnabled = true;
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

// CREDITO DUPLO:
// T1 + T2 podem ser duas ordens vencedoras distintas que formam
// um unico pool financeiro para financiar o REDUCE de uma LOSS.
bool   g_selectedCreditMode=false;
int    g_selectedCreditTicket1=-1;
int    g_selectedCreditTicket2=-1;
double g_selectedCreditLots1=0.0;
double g_selectedCreditLots2=0.0;
double g_selectedCreditResult1=0.0;
double g_selectedCreditResult2=0.0;
double g_selectedCreditExecutionLots1=0.0;
double g_selectedCreditExecutionLots2=0.0;
double g_selectedCreditMoney=0.0;
double g_selectedCreditRequiredMoney=0.0;
double g_selectedCreditProjectedProfit=0.0;
bool   g_selectedCreditReady=false;

// Planejamento economico da reducao WIN + LOSS.
double g_selectedLossCloseLots=0.0;
double g_selectedWinRequiredMoney=0.0;
double g_selectedWinCalculatedLots=0.0;
double g_selectedWinExecutionLots=0.0;
double g_selectedProjectedProfit=0.0;
bool   g_selectedEconomicReady=false;

bool   g_autoReduceEnabled=false;
double g_autoReduceMinProfit=20.0;
double g_autoReduceLots=0.10;
bool   g_autoReduceExecuted=false;
string g_autoReduceGroupSignature="";

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
   int maxSlot=(IsTesting() || InpTestMode) ? 3 : 2;

   if(slot<1 || slot>maxSlot)
      return -1;

   string name=SelectedGlobalName(slot);

   if(!GlobalVariableCheck(name))
   {
      // Cesta Manager com InpMagicNumber=-1 publica uma selecao
      // generica do simbolo. O SENTINEL aceita esse fallback.
      string fallback=
         "SENTINEL_SELECTED_"+
         Symbol()+
         "_-1_"+
         IntegerToString(slot);

      if(!GlobalVariableCheck(fallback))
         return -1;

      name=fallback;
   }

   int ticket=(int)GlobalVariableGet(name);

   if(ticket<=0)
      return -1;

   return ticket;
}

void ClearSelectedTickets()
{
   GlobalVariableDel(SelectedGlobalName(1));
   GlobalVariableDel(SelectedGlobalName(2));
   GlobalVariableDel(SelectedGlobalName(3));

   string fallbackPrefix=
      "SENTINEL_SELECTED_"+
      Symbol()+
      "_-1_";

   GlobalVariableDel(fallbackPrefix+"1");
   GlobalVariableDel(fallbackPrefix+"2");
   GlobalVariableDel(fallbackPrefix+"3");

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

//====================================================================
// PLANO DE REDUCAO
//
// WIN + LOSS:
//   REDUCE = lote que queremos retirar da LOSS.
//   MIN PROFIT = lucro liquido minimo da realizacao.
//   A WIN fornece a contrapartida necessaria.
//
// A quantidade da WIN pode ser diferente da quantidade da LOSS.
//====================================================================

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

   g_selectedCreditMode=false;
   g_selectedCreditTicket1=-1;
   g_selectedCreditTicket2=-1;
   g_selectedCreditLots1=0.0;
   g_selectedCreditLots2=0.0;
   g_selectedCreditResult1=0.0;
   g_selectedCreditResult2=0.0;
   g_selectedCreditExecutionLots1=0.0;
   g_selectedCreditExecutionLots2=0.0;
   g_selectedCreditMoney=0.0;
   g_selectedCreditRequiredMoney=0.0;
   g_selectedCreditProjectedProfit=0.0;
   g_selectedCreditReady=false;

   g_selectedLossCloseLots=0.0;
   g_selectedWinRequiredMoney=0.0;
   g_selectedWinCalculatedLots=0.0;
   g_selectedWinExecutionLots=0.0;
   g_selectedProjectedProfit=0.0;
   g_selectedEconomicReady=false;

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

   if(!GetSelectedOrderSnapshot(ticket1,type1,lots1,result1))
      return false;

   //===============================================================
   // CREDITO DUPLO: T1 + T2 sao duas WINs distintas.
   // O SENTINEL procura automaticamente a LOSS mais negativa da
   // cesta e usa o lucro das duas WINs como pool de credito.
   //===============================================================
   if(ticket2>0 &&
      result1>0.00000001 &&
      result2>0.00000001)
   {
      g_selectedCreditMode=true;
      g_selectedCreditTicket1=ticket1;
      g_selectedCreditTicket2=ticket2;
      g_selectedCreditLots1=lots1;
      g_selectedCreditLots2=lots2;
      g_selectedCreditResult1=result1;
      g_selectedCreditResult2=result2;
      g_selectedCreditMoney=result1+result2;

      int lossTicket=-1;
      double lossLots=0.0;
      double lossResult=0.0;

      // No modo de teste, T3 representa explicitamente a LOSS
      // que sera reduzida. Fora do modo de teste, preserva-se
      // integralmente o comportamento atual: a LOSS mais negativa
      // da cesta e encontrada automaticamente.
      if((IsTesting() || InpTestMode))
      {
         int ticket3=GetSelectedTicket(3);

         if(ticket3<=0)
            return false;

         int type3=-1;

         if(!GetSelectedOrderSnapshot(
            ticket3,
            type3,
            lossLots,
            lossResult))
            return false;

         if(lossResult>=-0.00000001)
            return false;

         lossTicket=ticket3;
      }

      if(lossTicket<0)
      for(int i=OrdersTotal()-1;i>=0;i--)
      {
         if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
            continue;

         if(!IsOurOrder())
            continue;

         int type=OrderType();

         if(type!=OP_BUY && type!=OP_SELL)
            continue;

         int currentTicket=OrderTicket();

         // As duas ordens selecionadas sao somente credito.
         if(currentTicket==ticket1 || currentTicket==ticket2)
            continue;

         double currentResult=
            OrderProfit()+
            OrderSwap()+
            OrderCommission();

         if(currentResult>=-0.00000001)
            continue;

         if(lossTicket<0 || currentResult<lossResult)
         {
            lossTicket=currentTicket;
            lossLots=OrderLots();
            lossResult=currentResult;
         }
      }

      if(lossTicket<0 || lossLots<=0.0)
         return false;

      double requested=NormalizeLots(g_selectedLots);

      if(requested<=0.0)
         return false;

      g_selectedTargetTicket=lossTicket;
      g_selectedTargetLots=lossLots;
      g_selectedTargetResult=lossResult;
      g_selectedReferenceTicket=ticket1;
      g_selectedReferenceLots=lots1;
      g_selectedReferenceResult=result1;

      g_selectedLossCloseLots=
         NormalizeLots(
            MathMin(
               requested,
               lossLots
            )
         );

      if(g_selectedLossCloseLots<=0.0)
         return false;

      double lossRealized=
         lossResult*
         g_selectedLossCloseLots/
         lossLots;

      g_selectedCreditRequiredMoney=
         MathAbs(lossRealized)+
         MathMax(0.0,g_autoReduceMinProfit);

      if(g_selectedCreditMoney<=0.0)
         return false;

      // Distribui a necessidade de credito proporcionalmente entre
      // as duas WINs. Assim, quando houver credito suficiente,
      // ambas participam da realizacao.
      double totalCreditLots=
         lots1+lots2;

      if(totalCreditLots<=0.0)
         return false;

      double desired1=
         g_selectedCreditRequiredMoney*
         lots1/
         totalCreditLots;

      double desired2=
         g_selectedCreditRequiredMoney*
         lots2/
         totalCreditLots;

      double profitPerLot1=
         result1/lots1;

      double profitPerLot2=
         result2/lots2;

      if(profitPerLot1<=0.0 || profitPerLot2<=0.0)
         return false;

      g_selectedCreditExecutionLots1=
         MathMin(
            lots1,
            NormalizeLotsUp(
               desired1/profitPerLot1
            )
         );

      g_selectedCreditExecutionLots2=
         MathMin(
            lots2,
            NormalizeLotsUp(
               desired2/profitPerLot2
            )
         );

      g_selectedCreditExecutionLots1=
         NormalizeLots(g_selectedCreditExecutionLots1);

      g_selectedCreditExecutionLots2=
         NormalizeLots(g_selectedCreditExecutionLots2);

      double creditExecution=
         result1*
         g_selectedCreditExecutionLots1/
         lots1+
         result2*
         g_selectedCreditExecutionLots2/
         lots2;

      // Se o arredondamento/limite deixou credito insuficiente,
      // completa a necessidade usando a segunda WIN.
      double remaining=
         g_selectedCreditRequiredMoney-
         creditExecution;

      if(remaining>0.00000001)
      {
         double extra2=
            NormalizeLotsUp(
               remaining/profitPerLot2
            );

         double available2=
            NormalizeLots(
               MathMax(
                  0.0,
                  lots2-
                  g_selectedCreditExecutionLots2
               )
            );

         extra2=MathMin(extra2,available2);

         g_selectedCreditExecutionLots2=
            NormalizeLots(
               g_selectedCreditExecutionLots2+
               extra2
            );

         creditExecution=
            result1*
            g_selectedCreditExecutionLots1/
            lots1+
            result2*
            g_selectedCreditExecutionLots2/
            lots2;
      }

      g_selectedCreditProjectedProfit=
         creditExecution+
         lossRealized;

      g_selectedCreditReady=
         (creditExecution+0.00000001>=
          g_selectedCreditRequiredMoney &&
          g_selectedCreditProjectedProfit>=
          g_autoReduceMinProfit-0.00000001);

      g_selectedEconomicReady=
         g_selectedCreditReady;

      g_selectedPlanValid=true;
      return true;
   }

   if(ticket2<=0)
   {
      g_selectedTargetTicket=ticket1;
      g_selectedTargetLots=lots1;
      g_selectedTargetResult=result1;
   }
   else
   {
      if(!GetSelectedOrderSnapshot(ticket2,type2,lots2,result2))
         return false;

      if(result1>0.00000001 && result2<-0.00000001)
      {
         g_selectedTargetTicket=ticket2;
         g_selectedReferenceTicket=ticket1;
         g_selectedTargetLots=lots2;
         g_selectedReferenceLots=lots1;
         g_selectedTargetResult=result2;
         g_selectedReferenceResult=result1;
      }
      else
      if(result2>0.00000001 && result1<-0.00000001)
      {
         g_selectedTargetTicket=ticket1;
         g_selectedReferenceTicket=ticket2;
         g_selectedTargetLots=lots1;
         g_selectedReferenceLots=lots2;
         g_selectedTargetResult=result1;
         g_selectedReferenceResult=result2;
      }
      else
      if(result1>0.00000001 && result2>0.00000001)
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
         g_selectedTargetTicket=ticket1;
         g_selectedReferenceTicket=ticket2;
         g_selectedTargetLots=lots1;
         g_selectedReferenceLots=lots2;
         g_selectedTargetResult=result1;
         g_selectedReferenceResult=result2;
      }
   }

   double requested=NormalizeLots(g_selectedLots);

   if(requested<=0.0)
      return false;

   bool winLossPair=
      (g_selectedReferenceTicket>0 &&
       g_selectedTargetResult<-0.00000001 &&
       g_selectedReferenceResult>0.00000001);

   if(winLossPair)
   {
      g_selectedLossCloseLots=
         NormalizeLots(
            MathMin(
               requested,
               g_selectedTargetLots
            )
         );

      if(g_selectedLossCloseLots<=0.0)
         return false;

      double lossRealized=
         g_selectedTargetResult*
         g_selectedLossCloseLots/
         g_selectedTargetLots;

      g_selectedWinRequiredMoney=
         MathAbs(lossRealized)+
         MathMax(0.0,g_autoReduceMinProfit);

      double winMoneyPerLot=
         g_selectedReferenceResult/
         g_selectedReferenceLots;

      if(winMoneyPerLot<=0.0)
         return false;

      g_selectedWinCalculatedLots=
         g_selectedWinRequiredMoney/
         winMoneyPerLot;

      g_selectedWinExecutionLots=
         NormalizeLotsUp(
            g_selectedWinCalculatedLots
         );

      if(g_selectedWinExecutionLots<=0.0)
         return false;

      g_selectedProjectedProfit=
         g_selectedReferenceResult*
         MathMin(
            g_selectedWinExecutionLots,
            g_selectedReferenceLots
         )/
         g_selectedReferenceLots+
         lossRealized;

      g_selectedEconomicReady=
         (g_selectedWinExecutionLots<=
          g_selectedReferenceLots+0.00000001 &&
          g_selectedProjectedProfit>=
          g_autoReduceMinProfit-0.00000001);

      g_selectedPlanValid=true;
      return true;
   }

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

void UpdateAutoReducePanel()
{
   if(ObjectFind(0,OBJ_BTN_AUTO_REDUCE)>=0)
   {
      ObjectSetString(
         0,
         OBJ_BTN_AUTO_REDUCE,
         OBJPROP_TEXT,
         g_autoReduceEnabled ? "AUTO ON" : "AUTO OFF"
      );

      ObjectSetInteger(
         0,
         OBJ_BTN_AUTO_REDUCE,
         OBJPROP_BGCOLOR,
         g_autoReduceEnabled ?
         InpProfitColor :
         UI_COLOR_NEUTRAL
      );
   }

   // Os campos MIN e LOT sao editaveis pelo usuario.
   // Nao reescrever o texto a cada tick: isso interrompe a edicao
   // e devolve o valor persistido antes do CHARTEVENT_OBJECT_ENDEDIT.
   // O texto inicial e carregado na criacao do objeto e, apos a edicao,
   // ProcessEdit() normaliza e grava o novo valor.
}

void UpdateSelectedReductionPanel()
{
   UpdateAutoReducePanel();

   int ticket1=GetSelectedTicket(1);
   int ticket2=GetSelectedTicket(2);

   UpdateLabel(
      OBJ_LBL_SELECTED_1,
      ticket1>0 ?
      "T1 #"+IntegerToString(ticket1)+" "+SelectedTypeText(ticket1) :
      "T1 --",
      ticket1>0 ? UI_COLOR_TEXT_MAIN : UI_COLOR_TEXT_MUTED
   );

   UpdateLabel(
      OBJ_LBL_SELECTED_2,
      ticket2>0 ?
      "T2 #"+IntegerToString(ticket2)+" "+SelectedTypeText(ticket2) :
      "T2 --",
      ticket2>0 ? UI_COLOR_TEXT_MAIN : UI_COLOR_TEXT_MUTED
   );

   if(IsTesting() || InpTestMode)
   {
      int ticket3=GetSelectedTicket(3);

      UpdateLabel(
         OBJ_LBL_SELECTED_3,
         ticket3>0 ?
         "T3 #"+IntegerToString(ticket3)+" "+SelectedTypeText(ticket3) :
         "T3 --",
         ticket3>0 ? UI_COLOR_TEXT_MAIN : UI_COLOR_TEXT_MUTED
      );
   }

   bool valid=BuildSelectedReductionPlan();

   if(!valid)
   {
      UpdateLabel(OBJ_LBL_GROUP_TARGET,"LOSS --",InpStopColor);
      UpdateLabel(OBJ_LBL_GROUP_REFERENCE,"WIN --",InpProfitColor);
      UpdateLabel(OBJ_LBL_GROUP_NET,"NET --",UI_COLOR_TEXT_MAIN);
      UpdateLabel(OBJ_LBL_GROUP_EXPOSURE,"EXP --",UI_COLOR_TEXT_MUTED);
      UpdateLabel(OBJ_LBL_GROUP_RESULT,"RESULT --",UI_COLOR_TEXT_MAIN);
      UpdateLabel(OBJ_LBL_GROUP_WIN,"WIN --",InpProfitColor);
      UpdateLabel(OBJ_LBL_GROUP_NEED,"NEED --",InpStopColor);
      UpdateLabel(OBJ_LBL_GROUP_CALC,"LOT --",UI_COLOR_TEXT_MUTED);

      if(ObjectFind(0,OBJ_BTN_REDUCE_SELECTED)>=0)
      {
         ObjectSetInteger(0,OBJ_BTN_REDUCE_SELECTED,OBJPROP_BGCOLOR,clrDimGray);
         ObjectSetString(0,OBJ_BTN_REDUCE_SELECTED,OBJPROP_TEXT,"REDUCE GROUP");
      }
      return;
   }

   double buyBefore=GetBuyLots();
   double sellBefore=GetSellLots();
   double exposureBefore=buyBefore+sellBefore;
   double buyAfter=buyBefore;
   double sellAfter=sellBefore;

   int targetType=-1;
   double targetLiveLots=0.0;
   double targetLiveResult=0.0;

   if(!GetSelectedOrderSnapshot(
      g_selectedTargetTicket,
      targetType,
      targetLiveLots,
      targetLiveResult))
      return;

   // CREDITO DUPLO: duas WINs financiam uma LOSS.
   if(g_selectedCreditMode)
   {
      double buyBefore=GetBuyLots();
      double sellBefore=GetSellLots();
      double exposureBefore=buyBefore+sellBefore;
      double buyAfter=buyBefore;
      double sellAfter=sellBefore;

      int targetType=OrderType();
      if(OrderSelect(g_selectedTargetTicket,SELECT_BY_TICKET,MODE_TRADES))
         targetType=OrderType();

      if(targetType==OP_BUY)
         buyAfter-=g_selectedLossCloseLots;
      else
      if(targetType==OP_SELL)
         sellAfter-=g_selectedLossCloseLots;

      if(OrderSelect(g_selectedCreditTicket1,SELECT_BY_TICKET,MODE_TRADES))
      {
         if(OrderType()==OP_BUY) buyAfter-=g_selectedCreditExecutionLots1;
         else if(OrderType()==OP_SELL) sellAfter-=g_selectedCreditExecutionLots1;
      }

      if(OrderSelect(g_selectedCreditTicket2,SELECT_BY_TICKET,MODE_TRADES))
      {
         if(OrderType()==OP_BUY) buyAfter-=g_selectedCreditExecutionLots2;
         else if(OrderType()==OP_SELL) sellAfter-=g_selectedCreditExecutionLots2;
      }

      if(buyAfter<0.0) buyAfter=0.0;
      if(sellAfter<0.0) sellAfter=0.0;

      double netBefore=buyBefore-sellBefore;
      double netAfter=buyAfter-sellAfter;
      double exposureAfter=buyAfter+sellAfter;

      UpdateLabel(
         OBJ_LBL_GROUP_TARGET,
         "LOSS #"+IntegerToString(g_selectedTargetTicket)+
         " "+SelectedTypeText(g_selectedTargetTicket)+
         " "+DoubleToString(g_selectedTargetLots,2)+
         " > "+DoubleToString(g_selectedLossCloseLots,2),
         InpStopColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_REFERENCE,
         "CREDITO #"+IntegerToString(g_selectedCreditTicket1)+
         " + #"+IntegerToString(g_selectedCreditTicket2),
         InpProfitColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_RESULT,
         "RESULT "+FormatMoney(g_selectedCreditProjectedProfit),
         g_selectedCreditReady ? InpProfitColor : InpStopColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_WIN,
         "CREDITO "+FormatMoney(g_selectedCreditMoney),
         InpProfitColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_NEED,
         "NEED "+FormatMoney(g_selectedCreditRequiredMoney),
         g_selectedCreditReady ? InpProfitColor : InpStopColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_CALC,
         "LOT "+
         DoubleToString(g_selectedCreditExecutionLots1,2)+
         " + "+
         DoubleToString(g_selectedCreditExecutionLots2,2),
         g_selectedCreditReady ? InpProfitColor : UI_COLOR_TEXT_MUTED
      );

      UpdateLabel(
         OBJ_LBL_GROUP_NET,
         "NET "+DoubleToString(netBefore,2)+
         " > "+DoubleToString(netAfter,2),
         netAfter>=0.0 ? InpProfitColor : InpStopColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_EXPOSURE,
         "EXP "+DoubleToString(exposureBefore,2)+
         " > "+DoubleToString(exposureAfter,2),
         clrSilver
      );

      if(ObjectFind(0,OBJ_BTN_REDUCE_SELECTED)>=0)
      {
         ObjectSetInteger(
            0,OBJ_BTN_REDUCE_SELECTED,OBJPROP_BGCOLOR,
            g_selectedCreditReady ? clrDarkGoldenrod : clrDimGray
         );

         ObjectSetString(
            0,OBJ_BTN_REDUCE_SELECTED,OBJPROP_TEXT,
            g_selectedCreditReady ?
            "REDUCE 2 WIN + LOSS" :
            "AGUARDAR CREDITO"
         );
      }

      return;
   }

   // CREDITO DUPLO: T1 e T2 sao duas WINs que financiam
   // a reducao automatica da LOSS escolhida pelo plano.
   if(g_selectedCreditMode)
   {
      if(!g_selectedCreditReady)
      {
         SetStatus(
            "REDUCE AGUARDAR "+FormatMoney(g_selectedCreditRequiredMoney),
            InpStopColor
         );
         return;
      }

      int lossTicket=g_selectedTargetTicket;
      int creditTicket1=g_selectedCreditTicket1;
      int creditTicket2=g_selectedCreditTicket2;

      double closeCredit1=g_selectedCreditExecutionLots1;
      double closeCredit2=g_selectedCreditExecutionLots2;
      double closeLoss=g_selectedLossCloseLots;

      if(!OrderSelect(creditTicket1,SELECT_BY_TICKET,MODE_TRADES) ||
         !IsOurOrder() ||
         (OrderType()!=OP_BUY && OrderType()!=OP_SELL) ||
         OrderLots()<closeCredit1)
      {
         SetStatus("CREDITO T1 INVALIDO",InpStopColor);
         return;
      }

      if(!OrderSelect(creditTicket2,SELECT_BY_TICKET,MODE_TRADES) ||
         !IsOurOrder() ||
         (OrderType()!=OP_BUY && OrderType()!=OP_SELL) ||
         OrderLots()<closeCredit2)
      {
         SetStatus("CREDITO T2 INVALIDO",InpStopColor);
         return;
      }

      if(!OrderSelect(lossTicket,SELECT_BY_TICKET,MODE_TRADES) ||
         !IsOurOrder() ||
         (OrderType()!=OP_BUY && OrderType()!=OP_SELL) ||
         OrderLots()<closeLoss)
      {
         SetStatus("LOSS INVALIDA",InpStopColor);
         return;
      }

      if(closeCredit1>0.0 && !PartialCloseTicket(creditTicket1,closeCredit1))
      {
         SetStatus("CREDITO T1 ERRO "+IntegerToString(GetLastError()),InpStopColor);
         return;
      }

      if(closeCredit2>0.0 && !PartialCloseTicket(creditTicket2,closeCredit2))
      {
         SetStatus("CREDITO T2 ERRO "+IntegerToString(GetLastError()),InpStopColor);
         return;
      }

      if(!PartialCloseTicket(lossTicket,closeLoss))
      {
         SetStatus("CREDITO OK LOSS ERRO "+IntegerToString(GetLastError()),InpStopColor);
         return;
      }

      SetStatus(
         "REDUCE 2 WIN + LOSS  "+
         "WIN1 "+DoubleToString(closeCredit1,2)+
         " WIN2 "+DoubleToString(closeCredit2,2)+
         " LOSS "+DoubleToString(closeLoss,2)+
         " RESULT "+DoubleToString(g_selectedCreditProjectedProfit,2),
         InpProfitColor
      );

      ClearSelectedTickets();
      return;
   }

   bool economicPair=
      (g_selectedReferenceTicket>0 &&
       g_selectedTargetResult<-0.00000001 &&
       g_selectedReferenceResult>0.00000001);

   if(economicPair)
   {
      if(targetType==OP_BUY)
         buyAfter-=g_selectedLossCloseLots;
      else
      if(targetType==OP_SELL)
         sellAfter-=g_selectedLossCloseLots;

      int refType=-1;
      double refLiveLots=0.0;
      double refLiveResult=0.0;

      if(GetSelectedOrderSnapshot(
         g_selectedReferenceTicket,
         refType,
         refLiveLots,
         refLiveResult))
      {
         if(refType==OP_BUY)
            buyAfter-=g_selectedWinExecutionLots;
         else
         if(refType==OP_SELL)
            sellAfter-=g_selectedWinExecutionLots;
      }
   }
   else
   {
      if(targetType==OP_BUY)
         buyAfter-=g_selectedReduceLots;
      else
      if(targetType==OP_SELL)
         sellAfter-=g_selectedReduceLots;
   }

   if(buyAfter<0.0) buyAfter=0.0;
   if(sellAfter<0.0) sellAfter=0.0;

   double netBefore=buyBefore-sellBefore;
   double netAfter=buyAfter-sellAfter;
   double exposureAfter=buyAfter+sellAfter;

   if(economicPair)
   {
      UpdateLabel(
         OBJ_LBL_GROUP_TARGET,
         "LOSS #"+IntegerToString(g_selectedTargetTicket)+
         " "+SelectedTypeText(g_selectedTargetTicket)+
         " "+DoubleToString(g_selectedTargetLots,2)+
         " > "+DoubleToString(g_selectedLossCloseLots,2),
         InpStopColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_REFERENCE,
         "WIN #"+IntegerToString(g_selectedReferenceTicket)+
         " "+SelectedTypeText(g_selectedReferenceTicket)+
         " "+DoubleToString(g_selectedReferenceLots,2)+
         " > "+DoubleToString(g_selectedWinExecutionLots,2),
         InpProfitColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_RESULT,
         "RESULT "+FormatMoney(g_selectedProjectedProfit),
         g_selectedProjectedProfit>=g_autoReduceMinProfit ?
         InpProfitColor :
         InpStopColor
      );

      double winCurrentMoney=g_selectedReferenceResult;

      // Economia da reducao em duas colunas: WIN e NEED.
      // O lote calculado fica isolado na linha seguinte para nao
      // comprimir a leitura no painel estreito.
      UpdateLabel(
         OBJ_LBL_GROUP_WIN,
         "WIN "+FormatMoney(winCurrentMoney),
         InpProfitColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_NEED,
         "NEED "+FormatMoney(g_selectedWinRequiredMoney),
         g_selectedEconomicReady ? InpProfitColor : InpStopColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_CALC,
         "LOT "+
         DoubleToString(g_selectedWinCalculatedLots,3)+
         " > "+
         DoubleToString(g_selectedWinExecutionLots,2),
         g_selectedEconomicReady ? InpProfitColor : UI_COLOR_TEXT_MUTED
      );
   }
   else
   {
      UpdateLabel(
         OBJ_LBL_GROUP_TARGET,
         "TARGET #"+IntegerToString(g_selectedTargetTicket)+
         " "+SelectedTypeText(g_selectedTargetTicket)+
         " "+DoubleToString(g_selectedTargetLots,2)+
         " > "+DoubleToString(g_selectedReduceLots,2),
         g_selectedTargetResult<0.0 ?
         InpStopColor :
         InpProfitColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_REFERENCE,
         g_selectedReferenceTicket>0 ?
         "REFERENCE #"+IntegerToString(g_selectedReferenceTicket)+
         " "+SelectedTypeText(g_selectedReferenceTicket)+
         " "+DoubleToString(g_selectedReferenceLots,2) :
         "REFERENCE --",
         g_selectedReferenceTicket>0 ?
         (g_selectedReferenceResult>=0.0 ? InpProfitColor : InpStopColor) :
         clrSilver
      );

      UpdateLabel(
         OBJ_LBL_GROUP_RESULT,
         "RESULT "+
         FormatMoney(
            g_selectedTargetResult+
            g_selectedReferenceResult
         ),
         (g_selectedTargetResult+g_selectedReferenceResult)>=0.0 ?
         InpProfitColor :
         InpStopColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_WIN,
         "WIN "+FormatMoney(MathMax(0.0,g_selectedReferenceResult)),
         g_selectedReferenceResult>=0.0 ? InpProfitColor : InpStopColor
      );

      UpdateLabel(
         OBJ_LBL_GROUP_NEED,
         "NEED --",
         UI_COLOR_TEXT_MUTED
      );

      UpdateLabel(
         OBJ_LBL_GROUP_CALC,
         "LOT "+DoubleToString(g_selectedReduceLots,2),
         UI_COLOR_TEXT_MAIN
      );
   }

   UpdateLabel(
      OBJ_LBL_GROUP_NET,
      "NET "+DoubleToString(netBefore,2)+
      " > "+DoubleToString(netAfter,2),
      netAfter>=0.0 ? InpProfitColor : InpStopColor
   );

   UpdateLabel(
      OBJ_LBL_GROUP_EXPOSURE,
      "EXP "+DoubleToString(exposureBefore,2)+
      " > "+DoubleToString(exposureAfter,2),
      clrSilver
   );

   if(ObjectFind(0,OBJ_BTN_REDUCE_SELECTED)>=0)
   {
      bool buttonReady=
         economicPair ?
         g_selectedEconomicReady :
         true;

      ObjectSetInteger(
         0,
         OBJ_BTN_REDUCE_SELECTED,
         OBJPROP_BGCOLOR,
         buttonReady ? clrDarkGoldenrod : clrDimGray
      );

      ObjectSetString(
         0,
         OBJ_BTN_REDUCE_SELECTED,
         OBJPROP_TEXT,
         economicPair ?
         (g_selectedEconomicReady ?
          "REDUCE WIN+LOSS" :
          "AGUARDAR") :
         "REDUCE "+DoubleToString(g_selectedReduceLots,2)
      );
   }
}

bool ExecuteSelectedReduction()
{
   if(!BuildSelectedReductionPlan())
   {
      SetStatus("SELECAO INVALIDA",InpStopColor);
      return false;
   }

   bool economicPair=
      (g_selectedReferenceTicket>0 &&
       g_selectedTargetResult<-0.00000001 &&
       g_selectedReferenceResult>0.00000001);

   if(economicPair)
   {
      if(!g_selectedEconomicReady)
      {
         SetStatus(
            "REDUCE AGUARDAR "+FormatMoney(g_selectedWinRequiredMoney),
            InpStopColor
         );
         return false;
      }

      int lossTicket=g_selectedTargetTicket;
      int winTicket=g_selectedReferenceTicket;

      double winCloseLots=g_selectedWinExecutionLots;
      double lossCloseLots=g_selectedLossCloseLots;

      if(!OrderSelect(winTicket,SELECT_BY_TICKET,MODE_TRADES) ||
         !IsOurOrder() ||
         (OrderType()!=OP_BUY && OrderType()!=OP_SELL) ||
         OrderLots()<winCloseLots)
      {
         SetStatus("WIN INVALIDA",InpStopColor);
         return false;
      }

      ResetLastError();

      if(!PartialCloseTicket(winTicket,winCloseLots))
      {
         int errWin=GetLastError();
         SetStatus(
            "REDUCE WIN ERRO "+IntegerToString(errWin),
            InpStopColor
         );
         return false;
      }

      if(!OrderSelect(lossTicket,SELECT_BY_TICKET,MODE_TRADES) ||
         !IsOurOrder() ||
         (OrderType()!=OP_BUY && OrderType()!=OP_SELL) ||
         OrderLots()<lossCloseLots)
      {
         SetStatus(
            "REDUCE WIN OK LOSS INVALIDA",
            InpStopColor
         );
         return false;
      }

      ResetLastError();

      if(!PartialCloseTicket(lossTicket,lossCloseLots))
      {
         int errLoss=GetLastError();
         SetStatus(
            "REDUCE WIN OK LOSS ERRO "+IntegerToString(errLoss),
            InpStopColor
         );
         return false;
      }

      SetStatus(
         "REDUCE +"+DoubleToString(g_selectedProjectedProfit,2)+
         " WIN "+DoubleToString(winCloseLots,2)+
         " LOSS "+DoubleToString(lossCloseLots,2),
         InpProfitColor
      );

      ClearSelectedTickets();
      return true;
   }

   int ticket=g_selectedTargetTicket;

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
   {
      SetStatus("TICKET NAO ENCONTRADO",InpStopColor);
      return false;
   }

   if(!IsOurOrder())
   {
      SetStatus("TICKET FORA DA CESTA",InpStopColor);
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
      SetStatus("LOTE INVALIDO",InpStopColor);
      return false;
   }

   if(!PartialCloseTicket(ticket,closeLots))
   {
      SetStatus(
         "REDUCE SELECIONADO ERRO "+IntegerToString(GetLastError()),
         InpStopColor
      );
      return false;
   }

   SetStatus(
      "REDUCE T"+IntegerToString(ticket)+
      " "+DoubleToString(closeLots,2),
      InpProfitColor
   );

   ClearSelectedTickets();
   return true;
}

string GetAutoReduceGroupSignature()
{
   int ticket1=GetSelectedTicket(1);
   int ticket2=GetSelectedTicket(2);

   if(ticket1<=0)
      return "";

   return IntegerToString(ticket1)+
          ":"+
          IntegerToString(ticket2);
}

void EvaluateAutoReduce()
{
   if(!g_autoReduceEnabled || g_processing)
      return;

   if(GetSelectedTicket(1)<=0)
   {
      g_autoReduceExecuted=false;
      g_autoReduceGroupSignature="";
      return;
   }

   string signature=GetAutoReduceGroupSignature();

   if(signature=="")
      return;

   if(signature!=g_autoReduceGroupSignature)
   {
      g_autoReduceGroupSignature=signature;
      g_autoReduceExecuted=false;
   }

   if(g_autoReduceExecuted)
      return;

   if(!BuildSelectedReductionPlan())
      return;

   bool economicPair=
      (g_selectedReferenceTicket>0 &&
       g_selectedTargetResult<-0.00000001 &&
       g_selectedReferenceResult>0.00000001);

   if(economicPair)
   {
      if(!g_selectedEconomicReady)
         return;

      g_processing=true;

      SetStatus(
         "AUTO REDUCE WIN "+
         DoubleToString(g_selectedWinExecutionLots,2)+
         " LOSS "+
         DoubleToString(g_selectedLossCloseLots,2),
         InpProfitColor
      );

      bool ok=ExecuteSelectedReduction();

      g_processing=false;

      if(ok)
      {
         g_autoReduceExecuted=true;
         SetStatus(
            "AUTO REDUCE EXECUTADO "+
            DoubleToString(g_selectedLots,2),
            InpProfitColor
         );
      }
      else
      {
         SetStatus("AUTO REDUCE FALHOU",InpStopColor);
      }

      return;
   }

   // Cenarios fora de WIN + LOSS preservam o comportamento anterior.
   double groupResult=
      g_selectedTargetResult+
      g_selectedReferenceResult;

   if(groupResult<g_autoReduceMinProfit)
      return;

   double autoAvailableLots=g_selectedTargetLots;

   if(g_selectedReferenceTicket>0 &&
      g_selectedTargetResult*g_selectedReferenceResult<0.0)
   {
      autoAvailableLots=
         MathMin(
            g_selectedTargetLots,
            g_selectedReferenceLots
         );
   }

   // Todas as reducoes devem respeitar exclusivamente o lote
   // definido no campo SENTINEL_EDIT_LOTS.
   //
   // AUTO REDUCE controla apenas a automatizacao da decisao;
   // nao possui mais um lote de execucao independente.
   double requestedLots=
      NormalizeLots(
         MathMin(
            g_selectedLots,
            autoAvailableLots
         )
      );

   if(requestedLots<=0.0)
      return;

   g_processing=true;

   bool okLegacy=ExecuteSelectedReduction();

   g_processing=false;

   if(okLegacy)
   {
      g_autoReduceExecuted=true;
      SetStatus("AUTO REDUCE EXECUTADO",InpProfitColor);
   }
   else
   {
      SetStatus("AUTO REDUCE FALHOU",InpStopColor);
   }
}

//====================================================================
// LINHAS DA REDUCAO SELECIONADA
//====================================================================
//
// TARGET = ordem que o plano pretende reduzir.
// REFERENCE = ordem usada como referencia estrutural.
// As linhas sao somente visuais e nao participam da execucao.
//
//====================================================================

double GetSelectedOrderOpenPrice(int ticket)
{
   if(ticket<=0)
      return 0.0;

   if(!OrderSelect(
      ticket,
      SELECT_BY_TICKET,
      MODE_TRADES))
      return 0.0;

   if(!IsOurOrder())
      return 0.0;

   int type=OrderType();

   if(type!=OP_BUY && type!=OP_SELL)
      return 0.0;

   return NormalizePrice(OrderOpenPrice());
}

void DeleteSelectedReductionLines()
{
   DeleteObjectSafe(OBJ_LINE_SELECTED_TARGET);
   DeleteObjectSafe(OBJ_LINE_SELECTED_REFERENCE);
   DeleteObjectSafe(PREFIX+"LINE_SELECTED_CREDIT_2");
   DeleteObjectSafe(OBJ_TXT_SELECTED_TARGET);
   DeleteObjectSafe(OBJ_TXT_SELECTED_REFERENCE);
   DeleteObjectSafe(PREFIX+"TXT_SELECTED_CREDIT_2");
   DeleteObjectSafe(PREFIX+"LINE_SELECTED_CREDIT_2");
   DeleteObjectSafe(PREFIX+"TXT_SELECTED_CREDIT_2");
}

void UpdateSelectedReductionLines()
{
   // Nao existe plano valido: nenhuma referencia visual deve permanecer.
   if(!BuildSelectedReductionPlan())
   {
      DeleteSelectedReductionLines();
      return;
   }

   double targetPrice=
      GetSelectedOrderOpenPrice(
         g_selectedTargetTicket
      );

   if(targetPrice<=0.0)
   {
      DeleteSelectedReductionLines();
      return;
   }

   //===============================================================
   // TARGET
   //===============================================================

   CreateSegmentHLine(
      OBJ_LINE_SELECTED_TARGET,
      targetPrice,
      clrGold,
      STYLE_SOLID,
      2
   );

   string targetText=
      "TARGET  T"+
      IntegerToString(g_selectedTargetTicket)+
      " | "+
      SelectedTypeText(g_selectedTargetTicket)+
      " | RED "+
      DoubleToString(g_selectedReduceLots,2);

   if(ObjectFind(0,OBJ_TXT_SELECTED_TARGET)<0)
   {
      CreatePriceText(
         OBJ_TXT_SELECTED_TARGET,
         targetText,
         targetPrice,
         clrGold
      );
   }
   else
   {
      ObjectSetDouble(
         0,
         OBJ_TXT_SELECTED_TARGET,
         OBJPROP_PRICE1,
         targetPrice
      );

      ObjectSetString(
         0,
         OBJ_TXT_SELECTED_TARGET,
         OBJPROP_TEXT,
         targetText
      );

      ObjectSetInteger(
         0,
         OBJ_TXT_SELECTED_TARGET,
         OBJPROP_COLOR,
         clrGold
      );
   }

   //===============================================================
   // CREDITO DUPLO
   //===============================================================
   if(g_selectedCreditMode)
   {
      double credit1Price=GetSelectedOrderOpenPrice(g_selectedCreditTicket1);
      double credit2Price=GetSelectedOrderOpenPrice(g_selectedCreditTicket2);

      if(credit1Price>0.0)
      {
         CreateSegmentHLine(
            OBJ_LINE_SELECTED_REFERENCE,
            credit1Price,
            InpProfitColor,
            STYLE_DASH,
            1
         );

         string credit1Text=
            "CREDITO T1  #"+IntegerToString(g_selectedCreditTicket1)+
            " | "+DoubleToString(g_selectedCreditExecutionLots1,2);

         if(ObjectFind(0,OBJ_TXT_SELECTED_REFERENCE)<0)
         {
            CreatePriceText(
               OBJ_TXT_SELECTED_REFERENCE,
               credit1Text,
               credit1Price,
               InpProfitColor
            );
         }
         else
         {
            ObjectSetDouble(0,OBJ_TXT_SELECTED_REFERENCE,OBJPROP_PRICE1,credit1Price);
            ObjectSetString(0,OBJ_TXT_SELECTED_REFERENCE,OBJPROP_TEXT,credit1Text);
            ObjectSetInteger(0,OBJ_TXT_SELECTED_REFERENCE,OBJPROP_COLOR,InpProfitColor);
         }
      }

      if(credit2Price>0.0)
      {
         string credit2Name=PREFIX+"LINE_SELECTED_CREDIT_2";
         string credit2TextName=PREFIX+"TXT_SELECTED_CREDIT_2";

         CreateSegmentHLine(
            credit2Name,
            credit2Price,
            InpProfitColor,
            STYLE_DASH,
            1
         );

         string credit2Text=
            "CREDITO T2  #"+IntegerToString(g_selectedCreditTicket2)+
            " | "+DoubleToString(g_selectedCreditExecutionLots2,2);

         if(ObjectFind(0,credit2TextName)<0)
         {
            CreatePriceText(
               credit2TextName,
               credit2Text,
               credit2Price,
               InpProfitColor
            );
         }
         else
         {
            ObjectSetDouble(0,credit2TextName,OBJPROP_PRICE1,credit2Price);
            ObjectSetString(0,credit2TextName,OBJPROP_TEXT,credit2Text);
            ObjectSetInteger(0,credit2TextName,OBJPROP_COLOR,InpProfitColor);
         }
      }

      return;
   }

   //===============================================================
   // REFERENCE
   //===============================================================

   DeleteObjectSafe(PREFIX+"LINE_SELECTED_CREDIT_2");
   DeleteObjectSafe(PREFIX+"TXT_SELECTED_CREDIT_2");

   if(g_selectedReferenceTicket>0)
   {
      double referencePrice=
         GetSelectedOrderOpenPrice(
            g_selectedReferenceTicket
         );

      if(referencePrice>0.0)
      {
         CreateSegmentHLine(
            OBJ_LINE_SELECTED_REFERENCE,
            referencePrice,
            clrSilver,
            STYLE_DASH,
            1
         );

         string referenceText=
            "REF  T"+
            IntegerToString(g_selectedReferenceTicket)+
            " | "+
            SelectedTypeText(g_selectedReferenceTicket);

         if(ObjectFind(0,OBJ_TXT_SELECTED_REFERENCE)<0)
         {
            CreatePriceText(
               OBJ_TXT_SELECTED_REFERENCE,
               referenceText,
               referencePrice,
               clrSilver
            );
         }
         else
         {
            ObjectSetDouble(
               0,
               OBJ_TXT_SELECTED_REFERENCE,
               OBJPROP_PRICE1,
               referencePrice
            );

            ObjectSetString(
               0,
               OBJ_TXT_SELECTED_REFERENCE,
               OBJPROP_TEXT,
               referenceText
            );

            ObjectSetInteger(
               0,
               OBJ_TXT_SELECTED_REFERENCE,
               OBJPROP_COLOR,
               clrSilver
            );
         }
      }
      else
      {
         DeleteObjectSafe(OBJ_LINE_SELECTED_REFERENCE);
         DeleteObjectSafe(OBJ_TXT_SELECTED_REFERENCE);
      }
   }
   else
   {
      DeleteObjectSafe(OBJ_LINE_SELECTED_REFERENCE);
      DeleteObjectSafe(OBJ_TXT_SELECTED_REFERENCE);
   }
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

string AutoReduceEnabledGlobalName()
{
   return PREFIX+
          "AUTO_REDUCE_"+
          Symbol()+
          "_"+
          IntegerToString(InpMagicNumber);
}

string AutoReduceMinProfitGlobalName()
{
   return PREFIX+
          "AUTO_REDUCE_MIN_"+
          Symbol()+
          "_"+
          IntegerToString(InpMagicNumber);
}

string AutoReduceLotsGlobalName()
{
   return PREFIX+
          "AUTO_REDUCE_LOTS_"+
          Symbol()+
          "_"+
          IntegerToString(InpMagicNumber);
}

string RecoveryEnabledGlobalName()
{
   return PREFIX+
          "RECOVERY_ENABLED_"+
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

   GlobalVariableSet(
      AutoReduceEnabledGlobalName(),
      g_autoReduceEnabled ? 1.0 : 0.0
   );

   GlobalVariableSet(
      AutoReduceMinProfitGlobalName(),
      g_autoReduceMinProfit
   );

   GlobalVariableSet(
      AutoReduceLotsGlobalName(),
      g_autoReduceLots
   );

   GlobalVariableSet(
      RecoveryEnabledGlobalName(),
      g_recoveryEnabled ? 1.0 : 0.0
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

   g_autoReduceEnabled=InpAutoReduceDefault;
   g_autoReduceMinProfit=MathMax(0.0,InpAutoReduceMinProfit);
   g_autoReduceLots=NormalizeLots(InpAutoReduceLots);
   g_recoveryEnabled=false;
   g_recoveryTrailingEnabled=InpRecoveryTrailingDefault;

   string autoGV=AutoReduceEnabledGlobalName();
   string minGV=AutoReduceMinProfitGlobalName();
   string autoLotsGV=AutoReduceLotsGlobalName();

   if(GlobalVariableCheck(autoGV))
      g_autoReduceEnabled=(GlobalVariableGet(autoGV)>0.5);

   if(GlobalVariableCheck(minGV))
      g_autoReduceMinProfit=MathMax(0.0,GlobalVariableGet(minGV));

   if(GlobalVariableCheck(autoLotsGV))
   {
      double storedLots=NormalizeLots(GlobalVariableGet(autoLotsGV));
      if(storedLots>0.0)
         g_autoReduceLots=storedLots;
   }

   if(g_autoReduceLots<=0.0)
      g_autoReduceLots=MinLot();

   string recoveryGV=RecoveryEnabledGlobalName();

   if(GlobalVariableCheck(recoveryGV))
      g_recoveryEnabled=(GlobalVariableGet(recoveryGV)>0.5);
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
// NORMALIZA LOTES PARA CIMA
//
// Usada no calculo economico: o lote da WIN deve ser arredondado para
// o proximo passo executavel para nao ficar abaixo do MIN PROFIT.
//====================================================================

double NormalizeLotsUp(double lots)
{
   double step=LotStep();

   if(lots<=0.0 || step<=0.0)
      return 0.0;

   double result=
      MathCeil(
         (lots-0.00000001)/step
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

   result=NormalizeDouble(result,lotDigits);

   if(result<MinLot())
      result=MinLot();

   if(result>MaxLot())
      return 0.0;

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

   DeleteRecoveryPendingOrders();

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

   UpdateSelectedReductionLines();

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
   // CLOSE ALL precisa ser confirmado pela quantidade real de
   // posicoes abertas. Uma falha transitoria em OrderClose nao pode
   // deixar a cesta parcialmente aberta sem nova tentativa.
   bool success=true;

   DeleteRecoveryPendingOrders();

   for(int pass=0;
       pass<10;
       pass++)
   {
      bool passHadFailure=false;
      bool passHadOrder=false;

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

         int type=OrderType();

         // CLOSE ALL trata somente ordens de mercado.
         if(type!=OP_BUY && type!=OP_SELL)
            continue;

         passHadOrder=true;

         int ticket=OrderTicket();
         double lots=OrderLots();

         if(lots<=0.0)
            continue;

         RefreshRates();

         double price=
            (type==OP_BUY) ? Bid : Ask;

         ResetLastError();

         if(!OrderClose(
            ticket,
            lots,
            price,
            InpSlippage,
            clrNONE))
         {
            int error=GetLastError();

            passHadFailure=true;
            success=false;

            Print(
               "SENTINEL CLOSE ALL ticket=",
               ticket,
               " tentativa=",
               pass+1,
               " erro=",
               error
            );
         }
      }

      // A cada passada verificamos o estado REAL da cesta.
      if(CountOpenPositions()==0)
      {
         SetStatus(
            "CLOSE ALL EXECUTADO",
            InpProfitColor
         );

         return true;
      }

      // Ainda existem posicoes. Damos uma pequena janela para o
      // terminal atualizar o pool de ordens antes da nova tentativa.
      if(passHadOrder)
         Sleep(100);

      // Se nao houve ordem processavel, nao adianta repetir.
      if(!passHadOrder && !passHadFailure)
         break;
   }

   // Nunca reportar sucesso enquanto ainda houver posicao aberta.
   int remaining=CountOpenPositions();

   if(remaining>0)
   {
      SetStatus(
         "CLOSE ALL INCOMPLETO "+IntegerToString(remaining),
         InpStopColor
      );

      Print(
         "SENTINEL CLOSE ALL INCOMPLETO posicoes_restantes=",
         remaining
      );

      return false;
   }

   SetStatus(
      "CLOSE ALL EXECUTADO",
      InpProfitColor
   );

   return true;
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
// RECOVERY ENGINE
//====================================================================
//
// Usa a ULTIMA ordem MARKET aberta do lado como referencia.
// Sem FirstStep: o gatilho e medido diretamente contra essa ultima ordem.
//
// Ao atingir o gatilho:
// BUY  -> BUYSTOP acima do ASK
// SELL -> SELLSTOP abaixo do BID
//
// O step cresce por nivel e multiplicador, limitado por StepMax.
// O lote progride a partir do lote da ultima ordem, limitado por MaxLot.
//
// Trailing atua exclusivamente sobre as pendencias Recovery:
// quando a pendencia se distancia do preco corrente pelo menos
// PendingStep Trail (InpRecoveryTrailingStep), ela e reposicionada
// para o step dinamico atual. A Recovery ativada nao recebe trailing.
//====================================================================

string RecoveryComment(int direction)
{
   if(direction==OP_BUY)
      return InpOrderComment+" RECOVERY BUY";

   return InpOrderComment+" RECOVERY SELL";
}

bool IsRecoveryComment(string comment)
{
   return (
      StringFind(comment,"RECOVERY BUY",0)>=0 ||
      StringFind(comment,"RECOVERY SELL",0)>=0
   );
}

double RecoveryStepForLevel(int level)
{
   double base=MathMax(0.0,InpRecoveryStepDistance);
   double mult=MathMax(1.0,InpRecoveryStepMultiplier);
   double cap=MathMax(base,InpRecoveryStepMax);

   if(base<=0.0)
      return 0.0;

   if(level<1)
      level=1;

   double step=base*MathPow(mult,level-1);

   if(step>cap)
      step=cap;

   return step;
}

int RecoveryMarketCount(int direction)
{
   int count=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()!=direction)
         continue;

      count++;
   }

   return count;
}

bool RecoveryLastMarketOrder(
   int direction,
   int &ticket,
   double &lots,
   double &price,
   datetime &openTime)
{
   ticket=-1;
   lots=0.0;
   price=0.0;
   openTime=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(!IsOurOrder())
         continue;

      if(OrderType()!=direction)
         continue;

      if(ticket<0 ||
         OrderOpenTime()>openTime ||
         (OrderOpenTime()==openTime && OrderTicket()>ticket))
      {
         ticket=OrderTicket();
         lots=OrderLots();
         price=OrderOpenPrice();
         openTime=OrderOpenTime();
      }
   }

   return (ticket>0);
}

int RecoveryPendingTicket(int direction)
{
   int pendingType=
      direction==OP_BUY ? OP_BUYSTOP : OP_SELLSTOP;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      if(InpMagicNumber!=-1 &&
         OrderMagicNumber()!=InpMagicNumber)
         continue;

      if(OrderType()!=pendingType)
         continue;

      if(!IsRecoveryComment(OrderComment()))
         continue;

      return OrderTicket();
   }

   return -1;
}

double RecoveryNextLot(double previousLots)
{
   double lot=
      previousLots*MathMax(1.0,InpRecoveryLotMultiplier)+
      MathMax(0.0,InpRecoveryLotIncrement);

   double cap=MathMax(0.0,InpRecoveryMaxLot);

   if(cap>0.0 && lot>cap)
      lot=cap;

   return NormalizeLots(lot);
}

bool RecoveryTriggerReached(
   int direction,
   double referencePrice,
   double &adversePoints)
{
   adversePoints=0.0;

   double point=AssetPoint();

   if(point<=0.0 || referencePrice<=0.0)
      return false;

   RefreshRates();

   if(direction==OP_BUY)
      adversePoints=(referencePrice-Ask)/point;
   else
      adversePoints=(Bid-referencePrice)/point;

   return (
      adversePoints+0.00000001>=
      MathMax(0.0,InpRecoveryTriggerDistance)
   );
}

double RecoveryMinimumPendingDistance()
{
   double stopLevel=MarketInfo(Symbol(),MODE_STOPLEVEL);

   return MathMax(1.0,stopLevel+1.0);
}

bool RecoveryPlacePending(int direction)
{
   if(!g_recoveryEnabled)
      return false;

   if(RecoveryPendingTicket(direction)>0)
      return false;

   int referenceTicket=-1;
   double referenceLots=0.0;
   double referencePrice=0.0;
   datetime referenceTime=0;

   if(!RecoveryLastMarketOrder(
      direction,
      referenceTicket,
      referenceLots,
      referencePrice,
      referenceTime))
      return false;

   double adversePoints=0.0;

   if(!RecoveryTriggerReached(
      direction,
      referencePrice,
      adversePoints))
      return false;

   int level=RecoveryMarketCount(direction);

   double step=RecoveryStepForLevel(level);
   double lot=RecoveryNextLot(referenceLots);

   if(step<=0.0 || lot<=0.0)
      return false;

   double point=AssetPoint();

   if(point<=0.0)
      return false;

   double minimumDistance=
      RecoveryMinimumPendingDistance()*point;

   double minimumStep=
      RecoveryMinimumPendingDistance();

   if(step<minimumStep)
      step=minimumStep;

   RefreshRates();

   int type=
      direction==OP_BUY ?
      OP_BUYSTOP :
      OP_SELLSTOP;

   double price=
      direction==OP_BUY ?
      Ask+step*point :
      Bid-step*point;

   price=NormalizePrice(price);

   if(direction==OP_BUY &&
      price<=Ask+minimumDistance)
      return false;

   if(direction==OP_SELL &&
      price>=Bid-minimumDistance)
      return false;

   ResetLastError();

   int ticket=
      OrderSend(
         Symbol(),
         type,
         lot,
         price,
         InpSlippage,
         0,
         0,
         RecoveryComment(direction),
         InpMagicNumber,
         0,
         direction==OP_BUY ? InpBuyColor : InpSellColor
      );

   if(ticket<0)
   {
      Print(
         "SENTINEL RECOVERY OrderSend erro=",
         GetLastError(),
         " dir=",
         direction==OP_BUY ? "BUY" : "SELL",
         " ref=",
         referenceTicket
      );

      return false;
   }

   SetStatus(
      direction==OP_BUY ?
      "RECOVERY BUY #"+IntegerToString(ticket) :
      "RECOVERY SELL #"+IntegerToString(ticket),
      UI_COLOR_ACCENT
   );

   return true;
}

void RecoveryManageTrailing()
{
   // Replica a logica do EAGOLD TrailAllStopOrders() para a familia
   // RECOVERY:
   //
   // 1) PendingStep Trail e o GATILHO.
   // 2) RecoveryStepDistance e a DISTANCIA DE RESET.
   // 3) O pending somente acompanha quando:
   //       novo_preco = mercado +/- RecoveryStep
   //    resultar em um preco MAIS PROXIMO do mercado que o pending atual.
   //
   // Portanto, a ordem NAO acompanha tick a tick. Ela permanece no
   // lugar ate que o deslocamento do mercado seja suficiente para que
   // o novo reset fique atras do pending atual.
   if(!g_recoveryEnabled ||
      !g_recoveryTrailingEnabled ||
      InpRecoveryTrailingStep<=0.0)
      return;

   double point=AssetPoint();

   if(point<=0.0)
      return;

   double stopLevel=
      MarketInfo(Symbol(),MODE_STOPLEVEL)*point;

   double triggerDistance=
      InpRecoveryTrailingStep*point;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      if(InpMagicNumber!=-1 &&
         OrderMagicNumber()!=InpMagicNumber)
         continue;

      int type=OrderType();

      if(type!=OP_BUYSTOP &&
         type!=OP_SELLSTOP)
         continue;

      if(!IsRecoveryComment(OrderComment()))
         continue;

      RefreshRates();

      double current=OrderOpenPrice();
      double desired=current;
      double marketDistance=0.0;

      // IMPORTANTE: igual ao EAGOLD TrailAllStopOrders():
      // o trailing da pending Recovery NAO usa o step dinamico do
      // nivel. O reset usa sempre a distancia base RecoveryMinDistance.
      //
      // O multiplicador altera o preco de CRIACAO da nova Recovery,
      // mas nao altera a distancia usada pelo PendingStepTrail.
      double resetPoints=
         MathMax(0.0,InpRecoveryStepDistance);

      if(resetPoints<=0.0)
         continue;

      double resetDistance=
         resetPoints*point;

      if(type==OP_BUYSTOP)
      {
         // Distancia atual do pending para o ASK.
         marketDistance=current-Ask;

         if(marketDistance<triggerDistance)
            continue;

         // Exatamente como no EAGOLD:
         // reposiciona para ASK + RecoveryStep.
         desired=NormalizePrice(
            Ask+resetDistance
         );

         // Se o novo reset ainda estiver igual/acima do pending
         // atual, nao mexe. Assim o pending nunca se afasta.
         if(desired>=current)
            continue;

         if(desired<=Ask+stopLevel)
            continue;
      }
      else
      {
         // Distancia atual do pending para o BID.
         marketDistance=Bid-current;

         if(marketDistance<triggerDistance)
            continue;

         desired=NormalizePrice(
            Bid-resetDistance
         );

         // O novo reset precisa ficar abaixo do pending atual.
         if(desired<=current)
            continue;

         if(desired>=Bid-stopLevel)
            continue;
      }

      int ticket=OrderTicket();

      ResetLastError();

      if(!OrderModify(
         ticket,
         desired,
         0,
         0,
         0,
         clrNONE))
      {
         Print(
            "SENTINEL RECOVERY TRAIL FAILED ticket=",
            ticket,
            " error=",
            GetLastError(),
            " marketDistance=",
            DoubleToString(marketDistance/point,1),
            " trigger=",
            DoubleToString(InpRecoveryTrailingStep,1),
            " reset=",
            DoubleToString(resetPoints,1)
         );
      }
      else
      {
         Print(
            "SENTINEL RECOVERY TRAIL ticket=",
            ticket,
            " old=",
            DoubleToString(current,Digits),
            " new=",
            DoubleToString(desired,Digits),
            " marketDistance=",
            DoubleToString(marketDistance/point,1),
            " trigger=",
            DoubleToString(InpRecoveryTrailingStep,1),
            " reset=",
            DoubleToString(resetPoints,1)
         );
      }
   }
}

void DeleteRecoveryPendingOrders()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      if(InpMagicNumber!=-1 &&
         OrderMagicNumber()!=InpMagicNumber)
         continue;

      int type=OrderType();

      if(type!=OP_BUYSTOP &&
         type!=OP_SELLSTOP)
         continue;

      if(!IsRecoveryComment(OrderComment()))
         continue;

      int ticket=OrderTicket();

      ResetLastError();

      if(!OrderDelete(ticket,clrNONE))
      {
         Print(
            "SENTINEL RECOVERY DELETE erro=",
            GetLastError(),
            " ticket=",
            ticket
         );
      }
   }
}

void ManageRecovery()
{
   if(!g_recoveryEnabled)
      return;

   if(CountOpenPositions()<=0)
   {
      DeleteRecoveryPendingOrders();
      return;
   }

   RecoveryManageTrailing();

   RecoveryPlacePending(OP_BUY);
   RecoveryPlacePending(OP_SELL);
}

void UpdateRecoveryTelemetry()
{
   if(ObjectFind(0,OBJ_LBL_RECOVERY_TELEMETRY)<0)
      return;

   string text=
      "RECOVERY: "+
      (g_recoveryEnabled ? "ON" : "OFF")+
      " | TRAIL: "+
      (g_recoveryTrailingEnabled ? "ON" : "OFF")+
      " | "+DoubleToString(InpRecoveryTrailingStep,0);

   int buyTicket=-1;
   int sellTicket=-1;
   double buyLots=0.0;
   double sellLots=0.0;
   double buyPrice=0.0;
   double sellPrice=0.0;
   datetime buyTime=0;
   datetime sellTime=0;

   if(RecoveryLastMarketOrder(
      OP_BUY,buyTicket,buyLots,buyPrice,buyTime))
   {
      double adverse=0.0;
      RecoveryTriggerReached(OP_BUY,buyPrice,adverse);

      text+="\nBUY L"+
         IntegerToString(RecoveryMarketCount(OP_BUY))+
         " | #"+IntegerToString(buyTicket)+
         " | REF "+DoubleToString(buyPrice,Digits)+
         " | STEP "+DoubleToString(
            RecoveryStepForLevel(RecoveryMarketCount(OP_BUY)),0)+
         " | ADV "+DoubleToString(adverse,0);

      int pending=RecoveryPendingTicket(OP_BUY);

      if(pending>0 && OrderSelect(pending,SELECT_BY_TICKET))
         text+=" | P#"+IntegerToString(pending)+
            " @ "+DoubleToString(OrderOpenPrice(),Digits);
   }

   if(RecoveryLastMarketOrder(
      OP_SELL,sellTicket,sellLots,sellPrice,sellTime))
   {
      double adverse=0.0;
      RecoveryTriggerReached(OP_SELL,sellPrice,adverse);

      text+="\nSELL L"+
         IntegerToString(RecoveryMarketCount(OP_SELL))+
         " | #"+IntegerToString(sellTicket)+
         " | REF "+DoubleToString(sellPrice,Digits)+
         " | STEP "+DoubleToString(
            RecoveryStepForLevel(RecoveryMarketCount(OP_SELL)),0)+
         " | ADV "+DoubleToString(adverse,0);

      int pending=RecoveryPendingTicket(OP_SELL);

      if(pending>0 && OrderSelect(pending,SELECT_BY_TICKET))
         text+=" | P#"+IntegerToString(pending)+
            " @ "+DoubleToString(OrderOpenPrice(),Digits);
   }

   if(buyTicket<0 && sellTicket<0)
      text+="\nAGUARDANDO POSICAO";

   ObjectSetString(
      0,
      OBJ_LBL_RECOVERY_TELEMETRY,
      OBJPROP_TEXT,
      text
   );

   ObjectSetInteger(
      0,
      OBJ_LBL_RECOVERY_TELEMETRY,
      OBJPROP_COLOR,
      g_recoveryEnabled ? UI_COLOR_ACCENT : UI_COLOR_TEXT_MUTED
   );
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

int PanelToX(int relX,int objectWidth)
{
   if(InpPanelCorner==CORNER_RIGHT_UPPER ||
      InpPanelCorner==CORNER_RIGHT_LOWER)
      return MathMax(
         0,
         InpPanelX+
         InpPanelWidth-
         relX-
         objectWidth
      );

   return MathMax(
      0,
      InpPanelX+relX
   );
}

int PanelToY(int relY,int objectHeight)
{
   if(InpPanelCorner==CORNER_LEFT_LOWER ||
      InpPanelCorner==CORNER_RIGHT_LOWER)
      return MathMax(
         0,
         InpPanelY+
         InpPanelHeight-
         relY-
         objectHeight
      );

   return MathMax(
      0,
      InpPanelY+relY
   );
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

void CreatePanelCard(
   string name,
   int relX,
   int relY,
   int w,
   int h)
{
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_RECTANGLE_LABEL,
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
      PanelToX(relX,w)
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      PanelToY(relY,h)
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
      UI_COLOR_CARD
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      UI_COLOR_CARD_BORDER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BORDER_TYPE,
      BORDER_FLAT
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
      OBJPROP_BACK,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ZORDER,
      2
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
      InpPanelX
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_YDISTANCE,
      InpPanelY
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
      InpPanelHeight
   );

   // Fundo totalmente opaco.
   // Fundo SOLIDO do painel.
   // O OBJ_RECTANGLE_LABEL deve ficar na frente do grafico.
   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_BGCOLOR,
      InpPanelColor
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
      UI_COLOR_CARD_BORDER
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

   // Cards visuais alinhados com a nova hierarquia vertical.
   // O card e apenas fundo: controles permanecem acima dele por ZORDER.
   CreatePanelCard("SENTINEL_CARD_HEADER", 8, 8, 284, 42);
   CreatePanelCard("SENTINEL_CARD_TRADING", 8, 54, 284, 116);
   CreatePanelCard("SENTINEL_CARD_GROUP", 8, 176, 284, 216);
   CreatePanelCard("SENTINEL_CARD_RISK", 8, 401, 284, 89);
   CreatePanelCard("SENTINEL_CARD_FOOTER", 8, 498, 284, 54);
   DeleteObjectSafe("SENTINEL_CARD_ENTRY");

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
      OBJPROP_ANCHOR,
      ANCHOR_LEFT_UPPER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      PanelToX(x,EstimateLabelWidth(text,size))
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      PanelToY(y,size+4)
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
      "Segoe UI"
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
   ResetButtonVisualState(OBJ_BTN_REDUCE_BOTH);
   ResetButtonVisualState(OBJ_BTN_CLOSE_ALL);
   ResetButtonVisualState(OBJ_BTN_RED);
   ResetButtonVisualState(OBJ_BTN_RECOVERY);

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
      PanelToX(x,w)
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      PanelToY(y,h)
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
      OBJPROP_BORDER_COLOR,
      UI_COLOR_CARD_BORDER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      UI_COLOR_TEXT_MAIN
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      8
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Segoe UI"
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
// TESTER — CACHE DOS CAMPOS EDITAVEIS
//====================================================================
//
// No Strategy Tester Visual, o MT4 pode nao entregar
// CHARTEVENT_OBJECT_ENDEDIT/CHANGE para OBJ_EDIT. Mantemos o ultimo
// texto processado e detectamos alteracoes diretamente em OnTick().
//
string g_testerEditLastLots    = "";
string g_testerEditLastAutoMin = "";

string g_testerEditLastTarget  = "";
string g_testerEditLastStop    = "";

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
      PanelToX(x,w)
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      PanelToY(y,h)
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
      C'15,15,15'
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
      UI_COLOR_CARD_BORDER
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

   // Campos OBJ_EDIT precisam permanecer explicitamente editaveis.
   // Em especial no Strategy Tester Visual, deixar READONLY/STATE
   // implicitos pode impedir a entrada de texto mesmo com SELECTABLE=true.
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
      OBJPROP_READONLY,
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
      OBJPROP_BACK,
      false
   );

   // Campos de edicao ficam acima do painel, cards e demais objetos.
   ObjectSetInteger(
      0,
      name,
      OBJPROP_ZORDER,
      10000
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      false
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Segoe UI"
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      value
   );
}

//====================================================================
//====================================================================
// CONSTRUI INTERFACE
//====================================================================

void BuildInterface()
{
   //================================================================
   // SENTINEL UI 1.45
   //
   // Camada exclusivamente visual:
   // - nenhuma regra de negocio alterada;
   // - nenhuma funcao de execucao alterada;
   // - layout interno relativo ao painel;
   // - espacamento consistente entre grupos;
   // - cores usadas para hierarquia e estado.
   //================================================================

   CreatePanel();

   // O Entry Engine continua ativo logicamente, mas nao ocupa
   // espaco do painel operacional compacto.
   DeleteObjectSafe(OBJ_LBL_ENTRY_CONTEXT);
   DeleteObjectSafe(OBJ_LBL_ENTRY_SCORE);
   DeleteObjectSafe(OBJ_LBL_ENTRY_SIGNAL);

   int margin=10;
   int contentW=InpPanelWidth-(margin*2);
   int halfW=(contentW-8)/2;

   //===============================================================
   // 1. HEADER
   //===============================================================
   CreateLabel(OBJ_LBL_TITLE,"SENTINEL",margin,14,10,UI_COLOR_TEXT_MAIN);
   CreateLabel(OBJ_LBL_SYMBOL,Symbol()+"  TF "+IntegerToString(Period()),margin+105,16,8,UI_COLOR_ACCENT);
   CreateLabel(OBJ_LBL_MAGIC,"M:"+IntegerToString(InpMagicNumber),InpPanelWidth-58,16,8,UI_COLOR_TEXT_MUTED);

   //===============================================================
   // 2. FINANCEIRO + BOLETA
   //===============================================================
   CreateLabel(OBJ_LBL_REALIZED,"REALIZADO: 0.00",margin,61,8,UI_COLOR_TEXT_MUTED);
   CreateLabel(OBJ_LBL_OPEN,"ABERTO: 0.00",margin+145,61,8,UI_COLOR_TEXT_MUTED);
   CreateLabel(OBJ_LBL_TODAY_RESULT,"DIA: 0.00",margin,78,9,InpProfitColor);

   // Lotes: grupo centralizado e com espacamento uniforme.
   int lotGap=4;
   int lotBtnW=42;
   int lotEditW=64;
   int lotTotalW=(lotBtnW*4)+lotEditW+(lotGap*4);
   int lotX=margin+(contentW-lotTotalW)/2;

   CreateButton(OBJ_BTN_LOTS_MINUS_10,"-0.10",lotX,96,lotBtnW,21,UI_COLOR_NEUTRAL);
   lotX+=lotBtnW+lotGap;

   CreateButton(OBJ_BTN_LOTS_MINUS_1,"-0.01",lotX,96,lotBtnW,21,UI_COLOR_NEUTRAL);
   lotX+=lotBtnW+lotGap;

   CreateEdit(OBJ_EDIT_LOTS,DoubleToString(g_selectedLots,2),lotX,96,lotEditW,21);
   lotX+=lotEditW+lotGap;

   CreateButton(OBJ_BTN_LOTS_PLUS_1,"+0.01",lotX,96,lotBtnW,21,UI_COLOR_NEUTRAL);
   lotX+=lotBtnW+lotGap;

   CreateButton(OBJ_BTN_LOTS_PLUS_10,"+0.10",lotX,96,lotBtnW,21,UI_COLOR_NEUTRAL);

   // BUY / SELL: mesmo tamanho e mesmo espaco lateral.
   CreateButton(OBJ_BTN_BUY,"COMPRAR",margin+4,124,halfW,28,InpBuyColor);
   CreateButton(OBJ_BTN_SELL,"VENDER",margin+4+halfW+8,124,halfW,28,InpSellColor);

   // REDUCE BxS: acao especial, visualmente separada da abertura.
   CreateButton(OBJ_BTN_REDUCE_BOTH,"REDUCE BxS",margin+4,154,contentW-8,20,UI_COLOR_ACCENT);

   //===============================================================
   // 3. CURRENT GROUP
   //===============================================================
   CreateLabel(OBJ_LBL_GROUP_TITLE,"CURRENT GROUP",margin,184,8,UI_COLOR_TEXT_MAIN);

   CreateButton(OBJ_BTN_CLEAR_SELECTED,"LIMPAR",202,181,42,18,UI_COLOR_NEUTRAL);
   CreateButton(OBJ_BTN_AUTO_REDUCE,"AUTO OFF",248,181,42,18,UI_COLOR_NEUTRAL);

   // Tickets
   CreateLabel(OBJ_LBL_SELECTED_1,"T1 --",margin,202,8,UI_COLOR_TEXT_MUTED);
   CreateLabel(OBJ_LBL_SELECTED_2,"T2 --",margin+145,202,8,UI_COLOR_TEXT_MUTED);

   // Parametro MIN do AUTO REDUCE.
   // O valor fica centralizado com os mesmos quatro botoes usados
   // pelo controle de LOT.
   int minGap=4;
   int minBtnW=42;
   int minEditW=64;
   int minTotalW=(minBtnW*4)+minEditW+(minGap*4);
   int minX=margin+(contentW-minTotalW)/2;

   CreateButton(OBJ_BTN_AUTO_MIN_MINUS_10,"-10.0",minX,217,minBtnW,18,UI_COLOR_NEUTRAL);
   minX+=minBtnW+minGap;
   CreateButton(OBJ_BTN_AUTO_MIN_MINUS_1,"-1.0",minX,217,minBtnW,18,UI_COLOR_NEUTRAL);
   minX+=minBtnW+minGap;
   CreateEdit(OBJ_EDIT_AUTO_MIN,DoubleToString(g_autoReduceMinProfit,2),minX,217,minEditW,18);
   minX+=minEditW+minGap;
   CreateButton(OBJ_BTN_AUTO_MIN_PLUS_1,"+1.0",minX,217,minBtnW,18,UI_COLOR_NEUTRAL);
   minX+=minBtnW+minGap;
   CreateButton(OBJ_BTN_AUTO_MIN_PLUS_10,"+10.0",minX,217,minBtnW,18,UI_COLOR_NEUTRAL);

   // LOSS / WIN
   // LOSS / WIN: cor representa estado, nao simplesmente o lado da ordem.
   CreateLabel(OBJ_LBL_GROUP_TARGET,"LOSS --",margin,242,8,InpStopColor);
   CreateLabel(OBJ_LBL_GROUP_REFERENCE,"WIN --",margin,258,8,InpProfitColor);

   // NET / EXPOSICAO
   CreateLabel(OBJ_LBL_GROUP_NET,"NET --",margin,276,8,UI_COLOR_TEXT_MAIN);
   CreateLabel(OBJ_LBL_GROUP_EXPOSURE,"EXP --",margin+145,276,8,UI_COLOR_TEXT_MUTED);

   // Resultado e economia da reducao.
   CreateLabel(OBJ_LBL_GROUP_RESULT,"RESULT --",margin,293,8,UI_COLOR_TEXT_MAIN);
   CreateLabel(OBJ_LBL_GROUP_WIN,"WIN --",margin,309,7,InpProfitColor);
   CreateLabel(OBJ_LBL_GROUP_NEED,"NEED --",margin+145,309,7,InpStopColor);
   CreateLabel(OBJ_LBL_GROUP_CALC,"LOT --",margin,325,7,UI_COLOR_TEXT_MUTED);

   // Status da acao, sem transformar cada informacao em um card.
   CreateButton(OBJ_BTN_REDUCE_SELECTED,"REDUCE GROUP",margin+4,344,contentW-8,22,UI_COLOR_NEUTRAL);

   //===============================================================
   // 4. TAKE / STOP
   //===============================================================
   CreateLabel(OBJ_LBL_TARGET_MONEY,"TAKE: 0.00",margin,409,8,InpTakeColor);

   CreateButton(OBJ_BTN_TARGET_MINUS,"-",188,406,24,20,UI_COLOR_NEUTRAL);
   CreateEdit(OBJ_EDIT_TARGET,DoubleToString(g_targetPoints,0),216,406,45,20);
   CreateButton(OBJ_BTN_TARGET_PLUS,"+",265,406,24,20,UI_COLOR_NEUTRAL);

   CreateLabel(OBJ_LBL_STOP_MONEY,"STOP: 0.00",margin,436,8,InpStopColor);

   CreateButton(OBJ_BTN_STOP_MINUS,"-",188,433,24,20,UI_COLOR_NEUTRAL);
   CreateEdit(OBJ_EDIT_STOP,DoubleToString(g_stopPoints,0),216,433,45,20);
   CreateButton(OBJ_BTN_STOP_PLUS,"+",265,433,24,20,UI_COLOR_NEUTRAL);

   CreateButton(OBJ_BTN_CLOSE_ALL,"FECHAR TUDO",margin+4,461,contentW-8,22,InpSellColor);

   //===============================================================
   // 5. FOOTER / EXPOSICAO / RED
   //===============================================================
   CreateLabel(OBJ_LBL_EXPOSURE,"EXPOSICAO",margin,505,7,UI_COLOR_TEXT_MUTED);

   CreateLabel(OBJ_LBL_BUY,"BUY: 0.00",margin,518,8,InpBuyColor);
   CreateLabel(OBJ_LBL_SELL,"SELL: 0.00",margin+82,518,8,InpSellColor);
   CreateLabel(OBJ_LBL_NET,"NET: 0.00 FLAT",margin+164,518,8,UI_COLOR_TEXT_MAIN);

   CreateLabel(OBJ_LBL_STATUS,"SENTINEL ATIVO",margin,538,7,InpBuyColor);
   CreateButton(OBJ_BTN_RECOVERY,"REC OFF",168,532,58,20,UI_COLOR_NEUTRAL);
   CreateButton(OBJ_BTN_RED,"RED",232,532,58,20,UI_COLOR_ACCENT);

   // Telemetria Recovery/Trailing: somente texto, sem fundo.
   if(ObjectFind(0,OBJ_LBL_RECOVERY_TELEMETRY)<0)
      ObjectCreate(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_YDISTANCE,18);
   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_COLOR,UI_COLOR_TEXT_MUTED);
   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_BACK,true);
   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_ZORDER,1);
   ObjectSetString(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_FONT,"Segoe UI");
   ObjectSetString(0,OBJ_LBL_RECOVERY_TELEMETRY,OBJPROP_TEXT,"RECOVERY: OFF\\nAGUARDANDO POSICAO");

   ChartRedraw();
}

void CreatePanelSeparator(string name,int relY)
{
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   }

   int relX=5;
   int width=InpPanelWidth-10;

   ObjectSetInteger(0,name,OBJPROP_CORNER,InpPanelCorner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,PanelToX(relX,width));
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,PanelToY(relY,1));
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,1);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,UI_COLOR_CARD_BORDER);
   ObjectSetInteger(0,name,OBJPROP_COLOR,UI_COLOR_CARD_BORDER);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,2);
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
   PublishTesterOrderBridge();
   UpdateSelectedReductionPanel();
   UpdateRecoveryTelemetry();

   ResetAllButtonVisualStates();

   if(ObjectFind(0,OBJ_BTN_RECOVERY)>=0)
   {
      ObjectSetString(0,OBJ_BTN_RECOVERY,OBJPROP_TEXT,
         g_recoveryEnabled ? "REC ON" : "REC OFF");
      ObjectSetInteger(0,OBJ_BTN_RECOVERY,OBJPROP_BGCOLOR,
         g_recoveryEnabled ? UI_COLOR_ACCENT : UI_COLOR_NEUTRAL);
   }
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
   // AUTO REDUCE — MIN PROFIT
   //-----------------------------------------------------------------

   if(name==OBJ_EDIT_AUTO_MIN)
   {
      double value=StrToDouble(
         ObjectGetString(0,OBJ_EDIT_AUTO_MIN,OBJPROP_TEXT)
      );

      if(value<0.0)
         value=0.0;

      g_autoReduceMinProfit=value;

      ObjectSetString(
         0,
         OBJ_EDIT_AUTO_MIN,
         OBJPROP_TEXT,
         DoubleToString(g_autoReduceMinProfit,2)
      );

      SavePanelSettingsToGlobals();

      SetStatus(
         "AUTO MIN "+DoubleToString(g_autoReduceMinProfit,2),
         UI_COLOR_ACCENT
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

void AdjustLotsByAmount(double amount)
{
   double lots=GetSelectedLots();

   lots += amount;

   lots=NormalizeLots(lots);

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

void AdjustAutoReduceMinByAmount(double amount)
{
   double value=g_autoReduceMinProfit+amount;

   if(value<0.0)
      value=0.0;

   g_autoReduceMinProfit=NormalizeDouble(value,2);

   ObjectSetString(
      0,
      OBJ_EDIT_AUTO_MIN,
      OBJPROP_TEXT,
      DoubleToString(g_autoReduceMinProfit,2)
   );

   SavePanelSettingsToGlobals();

   SetStatus(
      "MIN "+DoubleToString(g_autoReduceMinProfit,2),
      UI_COLOR_ACCENT
   );

   ChartRedraw();
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
   // AUTO REDUCE
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_AUTO_MIN_MINUS_10)
   {
      AdjustAutoReduceMinByAmount(-10.0);
      return;
   }

   if(name==OBJ_BTN_AUTO_MIN_MINUS_1)
   {
      AdjustAutoReduceMinByAmount(-1.0);
      return;
   }

   if(name==OBJ_BTN_AUTO_MIN_PLUS_1)
   {
      AdjustAutoReduceMinByAmount(1.0);
      return;
   }

   if(name==OBJ_BTN_AUTO_MIN_PLUS_10)
   {
      AdjustAutoReduceMinByAmount(10.0);
      return;
   }

   if(name==OBJ_BTN_RECOVERY)
   {
      g_recoveryEnabled=!g_recoveryEnabled;

      SavePanelSettingsToGlobals();

      SetStatus(
         g_recoveryEnabled ? "RECOVERY ON" : "RECOVERY OFF",
         g_recoveryEnabled ? UI_COLOR_ACCENT : UI_COLOR_TEXT_MUTED
      );

      if(!g_recoveryEnabled)
         DeleteRecoveryPendingOrders();

      UpdateRecoveryTelemetry();
      return;
   }

   if(name==OBJ_BTN_AUTO_REDUCE)
   {
      g_autoReduceEnabled=!g_autoReduceEnabled;
      g_autoReduceExecuted=false;
      g_autoReduceGroupSignature="";

      SavePanelSettingsToGlobals();

      SetStatus(
         g_autoReduceEnabled ?
         "AUTO REDUCE ON" :
         "AUTO REDUCE OFF",
         g_autoReduceEnabled ? InpProfitColor : UI_COLOR_TEXT_MUTED
      );

      UpdateSelectedReductionPanel();
      return;
   }

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
      AdjustLotsByAmount(-0.10);
      return;
   }

   // LOTES -1
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_LOTS_MINUS_1)
   {
      AdjustLotsByAmount(-0.01);
      return;
   }

   // LOTES +1
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_LOTS_PLUS_1)
   {
      AdjustLotsByAmount(0.01);
      return;
   }

   // LOTES +10
   //-----------------------------------------------------------------

   if(name==OBJ_BTN_LOTS_PLUS_10)
   {
      AdjustLotsByAmount(0.10);
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

   DeleteObjectSafe(OBJ_BTN_AUTO_MIN_MINUS_10);
   DeleteObjectSafe(OBJ_BTN_AUTO_MIN_MINUS_1);
   DeleteObjectSafe(OBJ_BTN_AUTO_MIN_PLUS_1);
   DeleteObjectSafe(OBJ_BTN_AUTO_MIN_PLUS_10);

   DeleteObjectSafe(OBJ_EDIT_TARGET);
   DeleteObjectSafe(OBJ_EDIT_STOP);

   DeleteObjectSafe(OBJ_BTN_BUY);
   DeleteObjectSafe(OBJ_BTN_SELL);

   DeleteObjectSafe(OBJ_BTN_REDUCE_BOTH);
   DeleteObjectSafe(OBJ_LBL_SELECTED_1);
   DeleteObjectSafe(OBJ_LBL_SELECTED_2);
   DeleteObjectSafe(OBJ_LBL_SELECTED_3);
   DeleteObjectSafe(OBJ_LBL_SELECTED_CALC);
   DeleteObjectSafe(OBJ_LBL_SELECTED_SOURCE);
   DeleteObjectSafe(OBJ_LBL_SELECTED_EXPOSURE);
   DeleteObjectSafe(OBJ_BTN_REDUCE_SELECTED);
   DeleteObjectSafe(OBJ_BTN_CLEAR_SELECTED);
   DeleteObjectSafe(OBJ_BTN_AUTO_REDUCE);
   DeleteObjectSafe(OBJ_BTN_RECOVERY);
   DeleteObjectSafe(OBJ_LBL_RECOVERY_TELEMETRY);
   DeleteObjectSafe(OBJ_EDIT_AUTO_MIN);
   DeleteObjectSafe(PREFIX+"LBL_AUTO_MIN");
   DeleteObjectSafe(PREFIX+"LBL_AUTO_LOTS");
   DeleteObjectSafe(OBJ_LBL_GROUP_TITLE);
   DeleteObjectSafe(OBJ_LBL_GROUP_TARGET);
   DeleteObjectSafe(OBJ_LBL_GROUP_REFERENCE);
   DeleteObjectSafe(OBJ_LBL_GROUP_NET);
   DeleteObjectSafe(OBJ_LBL_GROUP_EXPOSURE);
   DeleteObjectSafe(OBJ_LBL_GROUP_RESULT);
   DeleteObjectSafe(OBJ_LBL_GROUP_CALC);
   DeleteObjectSafe(OBJ_LBL_GROUP_WIN);
   DeleteObjectSafe(OBJ_LBL_GROUP_NEED);

   DeleteObjectSafe(PREFIX+"SEP_1");
   DeleteObjectSafe(PREFIX+"SEP_2");
   DeleteObjectSafe(PREFIX+"SEP_3");
   DeleteObjectSafe(PREFIX+"SEP_4");
   DeleteObjectSafe(PREFIX+"SEP_5");
   DeleteObjectSafe(PREFIX+"SEP_6");

   DeleteObjectSafe(OBJ_BTN_CLOSE_ALL);
   DeleteObjectSafe(OBJ_BTN_RED);

   DeleteObjectSafe(OBJ_BTN_TARGET_MINUS);
   DeleteObjectSafe(OBJ_BTN_TARGET_PLUS);
   DeleteObjectSafe(OBJ_BTN_STOP_MINUS);
   DeleteObjectSafe(OBJ_BTN_STOP_PLUS);

   DeleteObjectSafe(OBJ_LBL_STATUS);
   DeleteObjectSafe(OBJ_LBL_CHART_PROFIT);



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
      !GlobalVariableCheck(StopPointsGlobalName()) ||
      !GlobalVariableCheck(AutoReduceEnabledGlobalName()) ||
      !GlobalVariableCheck(AutoReduceMinProfitGlobalName()) ||
      !GlobalVariableCheck(AutoReduceLotsGlobalName()))
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
   if(ObjectFind(0,OBJ_BTN_REDUCE_BOTH)>=0)
      ObjectSetInteger(0,OBJ_BTN_REDUCE_BOTH,OBJPROP_FONTSIZE,7);

   MakeButtonNonSelectable(OBJ_BTN_REDUCE_BOTH);
   MakeButtonNonSelectable(OBJ_BTN_CLEAR_SELECTED);
   MakeButtonNonSelectable(OBJ_BTN_REDUCE_SELECTED);
   MakeButtonNonSelectable(OBJ_BTN_AUTO_REDUCE);
   MakeButtonNonSelectable(OBJ_BTN_RECOVERY);
   MakeButtonNonSelectable(OBJ_BTN_CLOSE_ALL);
   MakeButtonNonSelectable(OBJ_BTN_RED);

   MakeButtonNonSelectable(OBJ_BTN_LOTS_MINUS_10);
   MakeButtonNonSelectable(OBJ_BTN_LOTS_MINUS_1);
   MakeButtonNonSelectable(OBJ_BTN_LOTS_PLUS_1);
   MakeButtonNonSelectable(OBJ_BTN_LOTS_PLUS_10);

   MakeButtonNonSelectable(OBJ_BTN_AUTO_MIN_MINUS_10);
   MakeButtonNonSelectable(OBJ_BTN_AUTO_MIN_MINUS_1);
   MakeButtonNonSelectable(OBJ_BTN_AUTO_MIN_PLUS_1);
   MakeButtonNonSelectable(OBJ_BTN_AUTO_MIN_PLUS_10);

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

//====================================================================
// TESTER — POLLING DOS BOTOES
//====================================================================
//
// No Strategy Tester Visual do MT4, CHARTEVENT_OBJECT_CLICK nao e
// entregue ao EA. Em modo tester, lemos OBJPROP_STATE em OnTick()
// e encaminhamos o mesmo nome para ProcessButton().
//
// O caminho normal continua usando OnChartEvent().
//====================================================================

bool ProcessTesterButtonState(string name)
{
   if(ObjectFind(0,name)<0)
      return false;

   bool pressed=
      (bool)ObjectGetInteger(
         0,
         name,
         OBJPROP_STATE
      );

   if(!pressed)
      return false;

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

   ProcessButton(name);

   return true;
}

void PollTesterButtons()
{
   if(!IsTesting() || !IsVisualMode())
      return;

   if(ProcessTesterButtonState(OBJ_BTN_AUTO_REDUCE)) return;
   if(ProcessTesterButtonState(OBJ_BTN_RECOVERY)) return;
   if(ProcessTesterButtonState(OBJ_BTN_REDUCE_SELECTED)) return;
   if(ProcessTesterButtonState(OBJ_BTN_CLEAR_SELECTED)) return;

   if(ProcessTesterButtonState(OBJ_BTN_LOTS_MINUS_10)) return;
   if(ProcessTesterButtonState(OBJ_BTN_LOTS_MINUS_1)) return;
   if(ProcessTesterButtonState(OBJ_BTN_LOTS_PLUS_1)) return;
   if(ProcessTesterButtonState(OBJ_BTN_LOTS_PLUS_10)) return;

   if(ProcessTesterButtonState(OBJ_BTN_AUTO_MIN_MINUS_10)) return;
   if(ProcessTesterButtonState(OBJ_BTN_AUTO_MIN_MINUS_1)) return;
   if(ProcessTesterButtonState(OBJ_BTN_AUTO_MIN_PLUS_1)) return;
   if(ProcessTesterButtonState(OBJ_BTN_AUTO_MIN_PLUS_10)) return;

   if(ProcessTesterButtonState(OBJ_BTN_TARGET_MINUS)) return;
   if(ProcessTesterButtonState(OBJ_BTN_TARGET_PLUS)) return;
   if(ProcessTesterButtonState(OBJ_BTN_STOP_MINUS)) return;
   if(ProcessTesterButtonState(OBJ_BTN_STOP_PLUS)) return;

   if(ProcessTesterButtonState(OBJ_BTN_BUY)) return;
   if(ProcessTesterButtonState(OBJ_BTN_SELL)) return;
   if(ProcessTesterButtonState(OBJ_BTN_REDUCE_BOTH)) return;
   if(ProcessTesterButtonState(OBJ_BTN_CLOSE_ALL)) return;
   if(ProcessTesterButtonState(OBJ_BTN_RED)) return;
}

//====================================================================
// TESTER — POLLING DOS CAMPOS EDITAVEIS
//====================================================================
//
// No Strategy Tester Visual, a edicao de OBJ_EDIT pode alterar
// OBJPROP_TEXT sem gerar CHARTEVENT_OBJECT_ENDEDIT/CHANGE.
// Detectamos a alteracao no OnTick() e reutilizamos ProcessEdit(),
// preservando exatamente a mesma validacao e persistencia do caminho
// normal do grafico.
//====================================================================

void PollTesterEdits()
{
   if(!IsTesting() || !IsVisualMode())
      return;

   string text;

   if(ObjectFind(0,OBJ_EDIT_LOTS)>=0)
   {
      text=ObjectGetString(0,OBJ_EDIT_LOTS,OBJPROP_TEXT);
      if(text!=g_testerEditLastLots)
      {
         g_testerEditLastLots=text;
         ProcessEdit(OBJ_EDIT_LOTS);
      }
   }

   if(ObjectFind(0,OBJ_EDIT_AUTO_MIN)>=0)
   {
      text=ObjectGetString(0,OBJ_EDIT_AUTO_MIN,OBJPROP_TEXT);
      if(text!=g_testerEditLastAutoMin)
      {
         g_testerEditLastAutoMin=text;
         ProcessEdit(OBJ_EDIT_AUTO_MIN);
      }
   }

   if(ObjectFind(0,OBJ_EDIT_TARGET)>=0)
   {
      text=ObjectGetString(0,OBJ_EDIT_TARGET,OBJPROP_TEXT);
      if(text!=g_testerEditLastTarget)
      {
         g_testerEditLastTarget=text;
         ProcessEdit(OBJ_EDIT_TARGET);
      }
   }

   if(ObjectFind(0,OBJ_EDIT_STOP)>=0)
   {
      text=ObjectGetString(0,OBJ_EDIT_STOP,OBJPROP_TEXT);
      if(text!=g_testerEditLastStop)
      {
         g_testerEditLastStop=text;
         ProcessEdit(OBJ_EDIT_STOP);
      }
   }
}

//====================================================================
// PONTE TESTER -> CESTA MANAGER
//====================================================================

string TesterOrderBridgePrefix()
{
   return "SENTINEL_TEST_ORDER_"+Symbol()+"_";
}

void PublishTesterOrderBridge()
{
   if(!IsTesting())
      return;

   string prefix=TesterOrderBridgePrefix();
   int maxSlots=100;

   // Limpa o snapshot anterior.
   for(int i=0;i<maxSlots;i++)
   {
      string base=prefix+IntegerToString(i)+"_";
      GlobalVariableDel(base+"ACTIVE");
   }

   int slot=0;

   for(int i=OrdersTotal()-1;i>=0 && slot<maxSlots;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL)
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      string base=prefix+IntegerToString(slot)+"_";

      GlobalVariableSet(base+"ACTIVE",1.0);
      GlobalVariableSet(base+"TICKET",(double)OrderTicket());
      GlobalVariableSet(base+"TYPE",(double)type);
      GlobalVariableSet(base+"MAGIC",(double)OrderMagicNumber());
      GlobalVariableSet(base+"LOTS",OrderLots());
      GlobalVariableSet(base+"RESULT",OrderProfit()+OrderSwap()+OrderCommission());
      GlobalVariableSet(base+"OPENPRICE",OrderOpenPrice());
      GlobalVariableSet(base+"OPENTIME",(double)OrderOpenTime());

      slot++;
   }

   GlobalVariableSet(prefix+"COUNT",(double)slot);
   GlobalVariablesFlush();
}

void OnTick()
{
   UpdateTodayRealizedPanel();

   // No Strategy Tester Visual, OnChartEvent nao e disparado.
   // Processamos botoes e campos editaveis antes de UpdateInterface().
   PollTesterButtons();
   PollTesterEdits();

   StartBasketIfNeeded();

   EndBasketIfNeeded();

   UpdateInterface();

   UpdateTradingObjects();

   ManageRecovery();

   EvaluateAutoReduce();

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

   ManageRecovery();

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
         sparam==OBJ_EDIT_STOP ||
         sparam==OBJ_EDIT_AUTO_MIN)
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