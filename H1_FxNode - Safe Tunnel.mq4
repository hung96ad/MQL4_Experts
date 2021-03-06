//+------------------------------------------------------------------+
//|                                         FxNode - Safe Tunnel.mq4 |
//|                                     Copyright 2018, FxNode Group |
//|                                            https://www.FxNode.ir |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, FxNode Group"
#property link      "https://www.FxNode.ir"
#property version   "1.0"
#property strict

#define RETRYCOUNT    10
#define RETRYDELAY    500

enum mytrend {
   BUY=0,      // Buy
   SELL=1,     // Sell
   None=2,     // Buy And Sell
  };
enum ColorSelect
  {
   COLOR_RED_GREEN,  //Red/Green
   COLOR_FOREGROUND, //Foreground
  };

input mytrend   TrendType               = None;       // Prefered Order Type
input int       TakeProfit              = 800;        // Profit in points
input int       MaxStopLoss             = 200;        // Max Stop Loss
input float     FixTakeProfit           = 0;          // Profit in points to take away
input float     TouchPipBuy             = 20;         // Pip Distance to touch trend line
input float     TouchPipSell            = 20;         // Pip Distance to touch trend line
input int       SlTrail                 = 50;         // Trail in point
input double    StaticLot               = 1;          // Position static size if you have no risk  
input double    MinLot                  = 0.05;       // Minimum Position size
input double    MaxLot                  = 0.1;          // Maximum Position size
input double    MaxSpread               = 15;         // Max Spread to allow tradeing            
extern int      Risk_Percentage         = 30;         // Money Management Risk Percent
input int       MaxOpenPosition         = 1;          // Maximum Opened Position
input int       MagicNumber             = 303030;     // Your Magic Number

extern string   desc1="========= Trade Line =====";  //=========================
input int       InpDepth                = 5;  // Depth
input int       InpDeviation            = 3;   // Deviation
input int       InpBackstep             = 1;   // Backstep
extern int      ZigZagNum               = 10;  // Number Of High And Low
input color     Color_UPLine            = clrOrange;    // Color Of Sell Line
input color     Color_DWLine            = clrDarkTurquoise;    // Color Of Buy Line

extern string   desc2="========= Time managment =====";  //=========================
input bool      TimeManagment           = false;          // Activate Time Managment
input string    EndOrderTime            = "06:00";
input string    StartOrderTime          = "24:00";
input bool      WeekenClose             = false;          // Close Opened Order in weekends.
   
extern string   desc3="========= Indicators =====";  //=========================
input int InpAtrPeriod       = 14; // ATR Period
input int StochasticKperiod  = 5; // Stochastic K Period
input int StochasticDperiod  = 3; // Stochastic D Period
input int StochasticSlowing  = 3; // Stochastic Slowing
input int BuyZone            = 30; // Stochastic Low Zone line
input int SellZone           = 70; // Stochastic High Zone line
input int CCIperiod          = 12; // CCI Period
input int RSIperiod          = 14; // RSI Period

int   Offset=100; // Distante to show text obove the order line
bool linecrosedbuy = false, outlinebuy = false, linecrosedsell = false, outlinesell = false;
string  MODE = "none"; //trendLine mode
double Price, SL, TP, Margin_Required, Lots, Lot_Step, lotmin, lotmax, Lot_Size, Tick_Value, minSLTPdstnc, Spread;
double Bullish = EMPTY_VALUE, Bearish = EMPTY_VALUE, ZigZagHigh[], ZigZagLow[],LineValLow=0,LineValHigh=0;
int ticket,try;
int error_array=0,message_num=1; string error_msg[]; datetime error_show_time;
datetime LastOrderTime;
bool DrawLine = false;
int  First_Low_Candel=0,Secund_Low_Candel=3,First_High_Candel=0,Secund_High_Candel=3,ZigHCandel[],ZigLCandel[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //EventSetTimer(1);
   Comment("");
   ArrayResize(error_msg,11,100);
   //ChartSetSymbolPeriod(0,NULL,30);
   GetMarketInfo();  // Analyse market To get necessary data
   TrendLine();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "FXNODE");
   //EventKillTimer();
   for(int i=ObjectsTotal(); i>=0; i--) 
     {
      if(StringSubstr(ObjectName(i),0,7)=="XBoard_") 
        {
         ObjectDelete(ObjectName(i));
        }
     }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  TrendLine();
    
  if ( isNewBar()==true )
   {
     GetMarketInfo();
   }
   
   
   if (AllowToOrder() == true && CheckTime(StartOrderTime,EndOrderTime) == true )
   {
    CheckToOpen();
   }
       
   if (OrdersTotal() > 0) 
   {
    TrailsCheck();  // Change SL TP Of Open Order in Every Tick
    CheckToClose();
    //WeekendClose();
   }
   
  }
//+------------------------------------------------------------------+
//|  Market Info analyse                                             |
//+------------------------------------------------------------------+
 bool GetMarketInfo()
  {
    minSLTPdstnc = MarketInfo(Symbol(), MODE_STOPLEVEL);
    if (Risk_Percentage>100 || Risk_Percentage<0 ) Risk_Percentage=10;
    Margin_Required=MarketInfo(Symbol(), MODE_MARGINREQUIRED);
    lotmin=MarketInfo(Symbol(), MODE_MINLOT);
    lotmax=MarketInfo(Symbol(), MODE_MAXLOT);
    Lot_Step=MarketInfo(Symbol(), MODE_LOTSTEP); 
    Lot_Size=MarketInfo(Symbol(), MODE_LOTSIZE);
    Tick_Value=MarketInfo(Symbol(), MODE_TICKVALUE);
    Spread=MarketInfo(Symbol(), MODE_SPREAD);
    return(true);
  }
//+------------------------------------------------------------------+
//|  To Run the expert once per every new Bar                        |
//+------------------------------------------------------------------+
 bool isNewBar()
  {
   static datetime TimeBar=0;
   bool flag=false;
    if(TimeBar!=Time[0])
       {
        TimeBar=Time[0];
        flag=true;
       } 
    return (flag);
  }
//+------------------------------------------------------------------+
//|  Check Conditions for Allow To Order                             |
//+------------------------------------------------------------------+ 
  bool AllowToOrder()
  {
   bool OrderAllow = true;
  //  if(DayOfWeek()==0 || DayOfWeek()==5 || DayOfWeek()==6) {OrderAllow=false;}
   if ( OrderCount() >= MaxOpenPosition ) {OrderAllow=false;}
   if ( LastOrderTime+PeriodSeconds() > TimeCurrent() ) {OrderAllow=false;}
   if ( Spread > MaxSpread ) {OrderAllow=false; error("Spred is to high.");}
   return(OrderAllow);
  }
//+------------------------------------------------------------------+
//|  Check For Open A Order                                          |
//+------------------------------------------------------------------+
 bool CheckToOpen() // MODE == "Bullish" or MODE == "Bearish"
  {
     bool TakeABuy = false; bool TakeASell = false;
     double BuyPrice=Ask;
     double SelPrice=Bid;
     
     LineValHigh = NormalizeDouble(ObjectGetValueByShift("FXNODE.HighLine", 0),Digits );
     LineValLow  = NormalizeDouble(ObjectGetValueByShift("FXNODE.LowLine", 0),Digits );

     if ( ( BuyPrice > LineValLow  ) && BuyPrice < (LineValLow+(Point*TouchPipBuy))) {TakeABuy = true;}
     if ( ( SelPrice < LineValHigh ) && SelPrice > (LineValHigh-(Point*TouchPipSell))) {TakeASell = true;} 
     
     if ( (TrendType != SELL) && TakeABuy  == true  ) {SendOrder(OP_BUY,"Safe Buy "+ string(MagicNumber));   }    // if Buy Signal //  Print("SendOrder BUY");
     if (AllowToOrder() == true) {
     if ( (TrendType != BUY ) && TakeASell == true  ) {SendOrder(OP_SELL,"Safe Sell "+ string(MagicNumber)); }    // if Sell Signal // Print("SendOrder SELL");
     }
  return(true);
 }
//+------------------------------------------------------------------+
//|  SendOrder                                                       |
//+------------------------------------------------------------------+
 bool SendOrder(int position, string comment)
  {
   datetime expiration=0;
   double price = 0;
   Lots = SL = TP = 0;
   
   for (int SO = 0; (SO < 50) && IsTradeContextBusy(); SO++) Sleep(100);
   
   RefreshRates();
   double LinesHeight = NormalizeDouble(High[ZigHCandel[0]]-Low[ZigLCandel[0]], Digits);
   
   if (position==OP_BUY){
      price=NormalizeDouble(Ask,Digits);
      SL = NormalizeDouble(price - ATRCheck()*10, Digits); //NormalizeDouble(price - LinesHeight, Digits);  // NormalizeDouble((Low[ZigLCandel[0]]+Low[ZigLCandel[1]]+Low[ZigLCandel[2]])/3, Digits);  
      TP = price + LinesHeight;
      Lots=CheckLots(Risk_Percentage, (Bid-SL)/Point , StaticLot);
      if ( (SL/Point > MaxStopLoss*Point) && MaxStopLoss > 0 ) { error("SL is higher than MaxStopLoss.");  SL = NormalizeDouble(price - MaxStopLoss*Point, Digits); }
      if ( (TP/Point > TakeProfit*Point) && TakeProfit > 0 )   { error("TP is higher than TakeProfit.");  TP = NormalizeDouble(price + TakeProfit*Point, Digits);  }
      Print("buy price:" + DoubleToStr(price, Digits) + " SL: " + DoubleToStr(SL, Digits) + " TP: "+ DoubleToStr(TP,Digits) ); 
      expiration=0;
      }
      
   if (position==OP_SELL){
      price=NormalizeDouble(Bid,Digits);
      SL = NormalizeDouble(price + ATRCheck()*10, Digits); //NormalizeDouble(price + LinesHeight, Digits);
      TP = price - LinesHeight;
      Lots=CheckLots(Risk_Percentage, (SL-Ask)/Point, StaticLot);
      Print("sell price:" + DoubleToStr(price, Digits) + " SL: " + DoubleToStr(SL, Digits) + " TP: "+ DoubleToStr(TP,Digits) );  
      if ( ( SL-price > MaxStopLoss*Point ) && MaxStopLoss >0 ) {   SL = NormalizeDouble(price + MaxStopLoss*Point, Digits);  }
      if ( ( TP > TakeProfit*Point  ) && TakeProfit  >0 ) {   TP = NormalizeDouble(price - TakeProfit*Point, Digits);   }
      expiration=0;
      }
      
   if (position==OP_BUY)
    ticket=OrderSend( Symbol(), OP_BUY,   Lots, price, 5, 0, 0, comment, MagicNumber, 0     , Green );
   if (position==OP_SELL)
    ticket=OrderSend( Symbol(), OP_SELL,  Lots, price, 5, 0, 0, comment, MagicNumber, 0     , Red   );
   try=1;
   while(ticket < 0 )
    {
      try++;
      if (try==RETRYCOUNT) { Print( "OrderSend Error: ",GetLastError()," SL=",SL," TP=",TP ); return(false);    }
      Sleep(RETRYDELAY);
      RefreshRates();
      if (position==OP_BUY)
         ticket=OrderSend( Symbol(), OP_BUY,       Lots, Ask, 5, 0, 0, comment, MagicNumber, 0     , Green );
      if (position==OP_SELL)
         ticket=OrderSend( Symbol(), OP_SELL,      Lots, Bid, 5, 0, 0, comment, MagicNumber, 0     , Red   );
     }
    if (ticket > 0) LastOrderTime = TimeCurrent();   
    try=1;
    if (SL>0 || TP>0)
    while(  !OrderModify(ticket, price, SL, TP, expiration) )
     {
      if (try==RETRYCOUNT) {    Print( "OrderSend Error: ",GetLastError()," SL=",SL," TP=",TP ); return(false);    }
      try++;
      Sleep(RETRYDELAY);
     }
      return(true);
} 
//+------------------------------------------------------------------+
//|  Check To Close A Order                                          |
//+------------------------------------------------------------------+
 bool CheckToClose()
 {
 int closecheck = 0;
  for ( int z = OrdersTotal() - 1; z >= 0; z -- )
   {  
    if ( !OrderSelect( z, SELECT_BY_POS ) ) { Print( "OrderSelect Error #:", GetLastError());  continue;  }
    if ( OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber ) continue; 
    if ( (OrderType() == OP_BUY || OrderType() == OP_BUYSTOP || OrderType() == OP_BUYLIMIT) )
    
     if (FixTakeProfit > 0 && OrderProfit()/OrderLots()/MarketInfo(Symbol(),MODE_TICKVALUE) >= FixTakeProfit ) {
       Print( "Decided to Close ticket "+IntegerToString(OrderTicket())+" :: Profite is "+DoubleToString(OrderProfit()) );
       error ("Decided to Close ticket "+IntegerToString(OrderTicket()));
       int CTC=0;
       while ( !OrderClose( OrderTicket(), OrderLots(), Bid, 10, Red ) )
       {
        Print( "OrderClose Error: ", GetLastError() );
        CTC++;
        if (CTC==RETRYCOUNT) return(false);
        RefreshRates();
       }
     }
      
    if ( (OrderType() == OP_SELL || OrderType() == OP_SELLSTOP || OrderType() == OP_SELLLIMIT)  )
     if (FixTakeProfit > 0 && OrderProfit()/OrderLots()/MarketInfo(Symbol(),MODE_TICKVALUE) >= FixTakeProfit ) {
      Print( "Decided to Close ticket "+IntegerToString(OrderTicket())+" :: Profite is "+DoubleToString(OrderProfit()) ); 
      error ("Decided to Close ticket "+IntegerToString(OrderTicket()));
      int CTC=0;
       while ( !OrderClose( OrderTicket(), OrderLots(), Ask, 10, Red ) )
       { 
        Print( "OrderClose Error: ", GetLastError() );
        CTC++;
        if (CTC==RETRYCOUNT) return(false);
        RefreshRates();
       }
     }
   }
  return (true);
 }
 //+------------------------------------------------------------------+
//|  Close Opened Order if Weekend                                   |
//+------------------------------------------------------------------+
 bool WeekendClose()
 {
  if (DayOfWeek()==5 && TimeCurrent()>=StrToTime("23:50") && WeekenClose==True )
   {
    for(int pos=OrdersTotal()-1; pos>=0; pos--)
     {
     
     int closecheck = 0;
     for ( int z = OrdersTotal() - 1; z >= 0; z -- )
      {  
       if ( !OrderSelect( z, SELECT_BY_POS ) ) { Print( "OrderSelect Error #:", GetLastError());  continue;  }
       if ( OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber ) continue;
       if ( (OrderType() == OP_BUY || OrderType() == OP_BUYSTOP || OrderType() == OP_BUYLIMIT) ) {
          error( "Its Weekend. Decided to Close ticket "+IntegerToString(OrderTicket()) ); 
          int CTC=0;
          while ( !OrderClose( OrderTicket(), OrderLots(), Bid, 10, Red ) )
          {
           Print( "OrderClose Error: ", GetLastError() );
          CTC++;
           if (CTC==RETRYCOUNT) return(false);
          RefreshRates();
          }
       }
       
       if ( (OrderType() == OP_SELL || OrderType() == OP_SELLSTOP || OrderType() == OP_SELLLIMIT)  ) {
         error( "Its Weekend. Decided to Close ticket "+IntegerToString(OrderTicket())+" :: Profite is "+DoubleToString(OrderProfit()) ); 
         int CTC=0;
          while ( !OrderClose( OrderTicket(), OrderLots(), Ask, 10, Red ) )
          { 
           Print( "OrderClose Error: ", GetLastError() );
           CTC++;
           if (CTC==RETRYCOUNT) return(false);
           RefreshRates();
          }
        }
        
      }       
     }
   }
   return(true);
 }
//--------------------------------------------------------
// Function: Time Of trade
//--------------------------------------------------------
bool CheckTime(string StartHour, string StopHour)
{
  //------------------------------------------------------------------
  bool AllowTrade = true;
  {
    bool allow1=true;
    string sh1, eh1;
    sh1 = StartHour; eh1 = StopHour;
    //------------------------------------------------------------------
    if (sh1 < eh1)
      if (TimeToStr(TimeCurrent(), TIME_MINUTES) < sh1 || TimeToStr(TimeCurrent(), TIME_MINUTES) > eh1)
        allow1 = false;
    if (sh1 > eh1)
      if (TimeToStr(TimeCurrent(), TIME_MINUTES) < sh1 && TimeToStr(TimeCurrent(), TIME_MINUTES) > eh1)
        allow1 = false;
    if (sh1 == eh1) allow1 = false;
    //------------------------------------------------------------------
    if (!allow1) AllowTrade = false;
  }
  //------------------------------------------------------------------
  return (AllowTrade);
  //------------------------------------------------------------------
}
//+------------------------------------------------------------------+
//|  Measure Orders Lot                                              |
//+------------------------------------------------------------------+ 
 double CheckLots (int risk_percent,double sl_size, double Static_Lot) {
   if (risk_percent<=0) return (Static_Lot);
   if (risk_percent>100 || risk_percent<0 ) risk_percent=10;
   double lots=0;
   lots=NormalizeDouble( (AccountBalance()*risk_percent/100) / (Tick_Value*sl_size), 2 );
   if (lots*Margin_Required>AccountFreeMargin()) {
      error("Not enough money to take " + DoubleToStr(lots,2) +" lots.");
      lots=AccountFreeMargin()/Margin_Required;
      }
   lots=MathFloor(lots/Lot_Step + 0.5)* Lot_Step;   
   if ( lots < lotmin ) lots = lotmin;
   if ( lots > lotmax ) lots = lotmax;
   if ( lots > MaxLot)  lots = MaxLot;
   if ( lots < MinLot ) lots = MinLot;
   
   return(lots);
}
//+------------------------------------------------------------------+
//|  SL_Trail                                                        |
//+------------------------------------------------------------------+
double SL_Trail(string SymboL,int position, double pos_sl, double pos_open_price,int trail, int Time_Frame)
{
   double new_sl=pos_sl;
   double price=0;
   double point    =        MarketInfo(SymboL, MODE_POINT);
   int    digit    =  (int) MarketInfo(SymboL, MODE_DIGITS);
   if      (position==OP_BUY)  price=MarketInfo(SymboL, MODE_BID);
   else if (position==OP_SELL) price=MarketInfo(SymboL, MODE_ASK);
   else new_sl=pos_sl;
   if (position==OP_BUY)
      if (price-pos_open_price>trail*point)
         if ( (price-(trail*point)>pos_sl) ) new_sl=price-(trail*point);
   if (position==OP_SELL)
      if (pos_open_price-price>trail*point)
         if ( (price+(trail*point)<pos_sl) ) new_sl=price+(trail*point);
   if ( MathAbs(new_sl-pos_sl)<10*point ) new_sl=pos_sl;
   if (new_sl < 0) new_sl = pos_sl;
   return (NormalizeDouble(new_sl,digit));
}
//+------------------------------------------------------------------+
//|  TrailsCheck                                                     |
//+------------------------------------------------------------------+
void TrailsCheck()
{
   for ( int TrC = OrdersTotal() - 1; TrC >= 0; TrC -- )
   {  
      if ( !OrderSelect( TrC, SELECT_BY_POS ) ) { Print( "OrderSelect Error #:", GetLastError());  continue;  }
      if ( OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber ) continue;
      if ( OrderType() != OP_BUY && OrderType() != OP_SELL ) continue;
      SL = OrderStopLoss(); TP = OrderTakeProfit();
      if ( (OrderType() == OP_BUY) && OrderProfit()> 0 )
         { 
            if ( SlTrail > 0 ){
               SL=SL_Trail(Symbol(),OP_BUY, OrderStopLoss(), OrderOpenPrice() ,SlTrail, PERIOD_CURRENT);
               }
            if (SL==OrderStopLoss() ) continue;
            if ( OrderModify(OrderTicket(), OrderOpenPrice(), SL, TP, 0)==false ) Print ("Modify Error: SL ", SL," TP ", TP)  ;
         }
  
         if ( (OrderType() == OP_SELL) && OrderProfit()> 0 )
         { 
            if ( SlTrail >0 ){
               SL=SL_Trail(Symbol(),OP_SELL, OrderStopLoss(), OrderOpenPrice() ,SlTrail, PERIOD_CURRENT);
               }
            if (SL==OrderStopLoss() && TP==OrderTakeProfit() ) continue;
            if ( OrderModify(OrderTicket(), OrderOpenPrice(), SL, TP, 0)==false ) Print ("Modify Error: SL ", SL," TP ", TP)  ;
         }

   }//End of OTC LOOP  
}
//+------------------------------------------------------------------+
//|  Count Opened Order                                              |
//+------------------------------------------------------------------+
int OrderCount()
{
    int count=0;
    for ( int z=OrdersTotal()-1; z>=0; z-- )
      {
       if ( !OrderSelect( z, SELECT_BY_POS ) )
        {
            Print( "OrderSelect( " ,z, ", SELECT_BY_POS ) - Error #", GetLastError());
            continue;
        }
  
        if ( OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber ) 
           count++;
      }
  return(count);     
}
  
//+------------------------------------------------------------------+ 
//| ZigZag Highest And Lowest TrendLine Show                         | 
//+------------------------------------------------------------------+ 
void TrendLine()
{
 ArrayResize(ZigZagHigh,ZigZagNum,1);
 ArrayResize(ZigZagLow,ZigZagNum,1);
 ArrayResize(ZigHCandel,ZigZagNum,1);
 ArrayResize(ZigLCandel,ZigZagNum,1);
 double high = -1, low = -1;
 double data=0;
 int    lowcount = 0, highcount = 0;

for (int i = 0; i < Bars; i++)
 {
   high = iCustom(Symbol(),PERIOD_CURRENT, "ZigZag", InpDepth,InpDeviation,InpBackstep, 1, i);
   if ( (high > 0) && ( high == iCustom(Symbol(),PERIOD_CURRENT, "ZigZag", InpDepth,InpDeviation,InpBackstep, 0, i)) ) 
   {
      ZigZagHigh[highcount] = high; ZigHCandel[highcount] = i; highcount++;
   }
   high = -1;
   if (highcount == ZigZagNum) break;
 }
 
 
 for (int i = 0; i < Bars; i++)
 {
   low = iCustom(Symbol(),PERIOD_CURRENT, "ZigZag", InpDepth,InpDeviation,InpBackstep, 2, i);
   if ( (low > 0) && ( low == iCustom(Symbol(),PERIOD_CURRENT, "ZigZag", InpDepth,InpDeviation,InpBackstep, 0, i)) ) 
   {
      ZigZagLow[lowcount] = low; ZigLCandel[lowcount] = i; lowcount++;
   }
   low = -1;
   if (lowcount == ZigZagNum) break;
 }
 
for (int j = 0; j <= ZigZagNum-1; j++) {
//ObjectDelete("FXNODE.ZigZagHigh."+IntegerToString(j));
   if(ObjectFind(0,"FXNODE.ZigZagHigh") < 0) {
   ObjectCreate(0,"FXNODE.ZigZagHigh."+IntegerToString(j),OBJ_ARROW,0,0,0,0,0);          // Create an arrow
   ObjectSetInteger(0,"FXNODE.ZigZagHigh."+IntegerToString(j),OBJPROP_ARROWCODE,238);    // Set the arrow code
   ObjectSetInteger(0,"FXNODE.ZigZagHigh."+IntegerToString(j),OBJPROP_COLOR,clrCrimson);  
   }  
   ObjectSetInteger(0,"FXNODE.ZigZagHigh."+IntegerToString(j),OBJPROP_TIME,Time[ZigHCandel[j]]);        // Set time
   ObjectSetDouble(0,"FXNODE.ZigZagHigh."+IntegerToString(j),OBJPROP_PRICE,ZigZagHigh[j]+(10+(Period()/100))*Point);// Set price
 } 
 
 for (int j = 0; j <= ZigZagNum-1; j++) {
   if(ObjectFind(0,"FXNODE.ZigZagLow") < 0) {
   ObjectDelete("FXNODE.ZigZagLow."+IntegerToString(j));
   ObjectCreate(0,"FXNODE.ZigZagLow."+IntegerToString(j),OBJ_ARROW,0,0,0,0,0);          // Create an arrow
   ObjectSetInteger(0,"FXNODE.ZigZagLow."+IntegerToString(j),OBJPROP_ARROWCODE,236);    // Set the arrow code
   ObjectSetInteger(0,"FXNODE.ZigZagLow."+IntegerToString(j),OBJPROP_COLOR,clrOliveDrab);
   }
   ObjectSetInteger(0,"FXNODE.ZigZagLow."+IntegerToString(j),OBJPROP_TIME,Time[ZigLCandel[j]]);        // Set time
   ObjectSetDouble(0,"FXNODE.ZigZagLow."+IntegerToString(j),OBJPROP_PRICE,ZigZagLow[j]-(10+(Period()/250))*Point);// Set price
 }
 DrawLine = true;
 First_Low_Candel=0;  Secund_Low_Candel=3;
 First_High_Candel=0; Secund_High_Candel=3;
 MODE = "none";
 
/////////////////////////////////////////////////////////////////////////////////////////////


 if ( (highcount > 2) && (DrawLine == true))
 {
   
   ObjectDelete("FXNODE.HighLine");
   ObjectCreate("FXNODE.HighLine", OBJ_TREND, 0, Time[ZigHCandel[Secund_High_Candel]],ZigZagHigh[Secund_High_Candel],Time[ZigHCandel[First_High_Candel]],ZigZagHigh[First_High_Candel]);
   ObjectSet   ("FXNODE.HighLine", OBJPROP_COLOR, Color_UPLine);
   ObjectSet   ("FXNODE.HighLine", OBJPROP_STYLE, STYLE_DASH);
   ObjectSet   ("FXNODE.HighLine", OBJPROP_WIDTH, 1);
   ObjectSet   ("FXNODE.HighLine", OBJPROP_RAY,   true);
   ObjectSet   ("FXNODE.HighLine", OBJPROP_BACK,  true);
 }
 if ( (lowcount > 2) && (DrawLine == true))
 {
   ObjectDelete("FXNODE.LowLine");
   ObjectCreate("FXNODE.LowLine", OBJ_TREND, 0, Time[ZigLCandel[Secund_Low_Candel]],ZigZagLow[Secund_Low_Candel],Time[ZigLCandel[First_Low_Candel]],ZigZagLow[First_Low_Candel]);
   ObjectSet   ("FXNODE.LowLine", OBJPROP_COLOR, Color_DWLine);
   ObjectSet   ("FXNODE.LowLine", OBJPROP_STYLE, STYLE_DASH);
   ObjectSet   ("FXNODE.LowLine", OBJPROP_WIDTH, 1);
   ObjectSet   ("FXNODE.LowLine", OBJPROP_RAY,   true);
   ObjectSet   ("FXNODE.LowLine", OBJPROP_BACK,  true);
 }
}

//+------------------------------------------------------------------+ 
//| Get Line Value of zigzag candle                        | 
//+------------------------------------------------------------------+ 
double LineValHighBar(int bar) {
   double Highval;
   Highval= NormalizeDouble(ObjectGetValueByShift("FXNODE.HighLine", ZigHCandel[bar]),Digits );
   return(Highval);
}
double LineValLowBar(int bar) {
   double Lowval;
   Lowval  = NormalizeDouble(ObjectGetValueByShift("FXNODE.LowLine", ZigLCandel[bar]),Digits );
   return(Lowval);
}


//+------------------------------------------------------------------+ 
//| ATR Check                                                        | 
//+------------------------------------------------------------------+ 
double ATRCheck()
  {
   return(iCustom(Symbol(),PERIOD_CURRENT, "ATR", InpAtrPeriod, 0, 0));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string DaysOfWeek(int day, int word)
  {
   if (word == 1) {
   switch(day)
     {
      case 6:  return ("Sat");
      case 0:  return ("Sun");
      case 1:  return ("Mon");
      case 2:  return ("Tue");
      case 3:  return ("Wed");
      case 4:  return ("Thu");
      case 5:  return ("Fri");
     }
   }
   if (word == 0) {
   switch(day)
     {
      case 6:  return ("Saturday");
      case 0:  return ("Sunday");
      case 1:  return ("Monday");
      case 2:  return ("Tuesday");
      case 3:  return ("Wednesday");
      case 4:  return ("Thursday");
      case 5:  return ("Friday");
     }
   }
   return("TF?");
  } 

//+------------------------------------------------------------------+ 
//| Error log                                      | 
//+------------------------------------------------------------------+
void error(string error) {
 if (error != error_msg[error_array])  // If the message is duplicate
  {
   error_msg[error_array] = error;
   error_array++;
   if (error_array > 9) error_array = 1;
  }
}
//+------------------------------------------------------------------+ 
//| End of the code                                                  | 
//+------------------------------------------------------------------+