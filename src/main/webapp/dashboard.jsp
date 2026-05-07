<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.time.ZoneId,java.time.ZonedDateTime,java.time.DayOfWeek" %>
<%
    String username = (String) session.getAttribute("username");
    if(username == null){ response.sendRedirect("auth.jsp"); return; }
    ZoneId ist = ZoneId.of("Asia/Kolkata");
    ZonedDateTime now = ZonedDateTime.now(ist);
    int mins = now.getHour() * 60 + now.getMinute();
    DayOfWeek dow = now.getDayOfWeek();
    boolean open = (dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY) && (mins >= 555 && mins <= 930);
    String ctx = request.getContextPath();
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="ctx" content="<%=ctx%>">
<title>Dashboard</title>
<script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
<style>
*{margin:0;padding:0;box-sizing:border-box;font-family:Poppins,sans-serif}
body{display:flex;height:100vh;background:#1e1e2f;color:#fff;overflow:hidden}
.sidebar{width:250px;background:#25263c;padding:20px;display:flex;flex-direction:column;flex-shrink:0}
.sidebar h2{font-size:18px;margin-bottom:28px}
.sidebar a{display:block;color:#bbb;padding:12px 10px;text-decoration:none;margin-bottom:4px;border-radius:6px;transition:.2s}
.sidebar a:hover,.sidebar a.active{background:#4b4b6e;color:#fff}
.main{flex:1;padding:24px;overflow-y:auto}
.ptitle{font-size:20px;font-weight:700;margin-bottom:20px}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:22px}
.sbox{background:#2e2f45;border-radius:10px;padding:16px 18px;text-align:center}
.sbox h5{font-size:11px;color:#aaa;text-transform:uppercase;letter-spacing:.5px;margin-bottom:8px}
.sbox h3{font-size:22px;font-weight:700}
.cgrid{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin-bottom:22px}
.ccard{background:#2e2f45;border-radius:10px;padding:18px}
.ccard h4{font-size:14px;color:#ccc;margin-bottom:12px;font-weight:600}
.tcard{background:#2e2f45;border-radius:10px;padding:18px;margin-bottom:22px}
.tcard h4{font-size:14px;color:#ccc;margin-bottom:14px;font-weight:600}
table{width:100%;border-collapse:collapse}
th,td{padding:11px 12px;text-align:center;font-size:13px;color:#ddd}
th{background:#3a3c55;font-weight:600;font-size:12px;text-transform:uppercase}
td{border-top:1px solid #3a3c55}
.pos{color:#00c087;font-weight:600}
.neg{color:#ff4b4b;font-weight:600}
.wcard{background:#2e2f45;border-radius:10px;padding:18px;margin-bottom:22px}
.wcard h4{font-size:14px;color:#ccc;margin-bottom:12px;font-weight:600}
.wcard ul{list-style:none}
.wcard li{padding:8px 0;border-bottom:1px solid #3a3c55;font-size:13px}
.wcard li:last-child{border-bottom:none}
.wcard a{color:#7eb6ff;text-decoration:none}
.wcard a:hover{color:#fff}
.empty{color:#555;text-align:center;padding:50px 0;font-size:13px}
</style>
</head>
<body>
<div class="sidebar">
  <h2>Hi, <%=username%></h2>
  <a href="dashboard.jsp" class="active">Dashboard</a>
  <a href="index.jsp">Search Stocks</a>
  <a href="chat.jsp">Chat Assistant</a>
  <a href="paperTrading.jsp">Practice Trading</a>
  <a href="profile.jsp">Profile</a>
  <a href="TradeHistory.jsp">Trade History</a>
  <a href="settings.jsp">Settings</a>
  <form action="LogoutServlet" method="post" style="margin-top:auto">
    <button type="submit" style="width:100%;padding:12px;background:#dc3545;color:#fff;border:none;border-radius:6px;cursor:pointer;font-weight:600">Logout</button>
  </form>
</div>

<div class="main">
  <div class="ptitle">Trading Dashboard</div>

  <div class="stats">
    <div class="sbox">
      <h5>Market Status</h5>
      <h3 style="color:<%=open?"#28a745":"#dc3545"%>"><%=open?"Open":"Closed"%></h3>
    </div>
    <div class="sbox"><h5>Portfolio Value</h5><h3 id="portfolioVal">...</h3></div>
    <div class="sbox"><h5>Total P&amp;L</h5><h3 id="dayPnl">...</h3></div>
    <div class="sbox"><h5>Balance</h5><h3 id="balanceVal">...</h3></div>
  </div>

  <div class="cgrid">
    <div class="ccard"><h4>Cumulative P&amp;L</h4><div id="chartPerf" style="height:240px"></div></div>
    <div class="ccard"><h4>Trade Accuracy</h4><div id="chartAcc" style="height:240px"></div></div>
  </div>
  <div class="cgrid">
    <div class="ccard"><h4>Buy vs Sell Volume</h4><div id="chartVol" style="height:220px"></div></div>
    <div class="ccard"><h4>Profit per Sell</h4><div id="chartPpt" style="height:220px"></div></div>
  </div>

  <div class="tcard">
    <h4>Recent Trades</h4>
    <table>
      <thead><tr><th>Time</th><th>Symbol</th><th>Type</th><th>Qty</th><th>Price</th><th>Value</th></tr></thead>
      <tbody id="tbody"><tr><td colspan="6" style="color:#555">Loading...</td></tr></tbody>
    </table>
  </div>

  <div class="wcard">
    <h4>Watchlist</h4>
    <ul>
      <li><a href="index.jsp?symbol=TCS">TCS</a> - Tata Consultancy Services</li>
      <li><a href="index.jsp?symbol=WIPRO">WIPRO</a> - Wipro Ltd</li>
      <li><a href="index.jsp?symbol=INFY">INFY</a> - Infosys Limited</li>
      <li><a href="index.jsp?symbol=RELIND">RELIND</a> - Reliance Industries</li>
      <li><a href="index.jsp?symbol=SBIN">SBIN</a> - State Bank of India</li>
    </ul>
  </div>
</div>

<script>
var CTX  = document.querySelector('meta[name=ctx]').getAttribute('content');
var DARK = '#2e2f45', GRID = '#3a3c55', TXT = '#ccc';

function fmt(n){ return parseFloat(n||0).toLocaleString('en-IN',{minimumFractionDigits:2,maximumFractionDigits:2}); }

function loadDashboard(){
  fetch(CTX + '/PortfolioServlet')
    .then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.json(); })
    .then(function(data){
      var balance  = parseFloat(data.balance||0);
      var trades   = data.trades  || [];
      var holdings = data.holdings || {};

      document.getElementById('balanceVal').textContent = 'Rs.' + fmt(balance);

      var hVal = 0;
      Object.values(holdings).forEach(function(h){
        hVal += parseFloat(h.avgPrice||0) * parseInt(h.quantity||0);
      });
      document.getElementById('portfolioVal').textContent = 'Rs.' + fmt(balance + hVal);

      var pnl = 0;
      trades.forEach(function(t){
        var v = parseFloat(t.price||0) * parseInt(t.quantity||0);
        pnl += t.action.toUpperCase()==='SELL' ? v : -v;
      });
      var pel = document.getElementById('dayPnl');
      pel.textContent = (pnl>=0?'+':'-') + 'Rs.' + fmt(Math.abs(pnl));
      pel.style.color = pnl>=0 ? '#00c087' : '#ff4b4b';

      drawPerf(trades);
      drawAcc(trades);
      drawVol(trades);
      drawPpt(trades);
      drawTable(trades);
    })
    .catch(function(e){ console.error('Dashboard error:',e); });
}

function drawPerf(trades){
  if(!trades.length){ empty('chartPerf','Make some trades first'); return; }
  var cumPnl=0, xs=[], ys=[], colors=[];
  trades.forEach(function(t,i){
    var v = parseFloat(t.price||0)*parseInt(t.quantity||0);
    cumPnl += t.action.toUpperCase()==='SELL' ? v : -v;
    xs.push('T'+(i+1)+' '+t.action+' '+t.symbol);
    ys.push(parseFloat(cumPnl.toFixed(2)));
    colors.push(cumPnl>=0?'#00c087':'#ff4b4b');
  });
  var pos = ys[ys.length-1]>=0;
  Plotly.newPlot('chartPerf',[{
    x:xs,y:ys,type:'scatter',mode:'lines+markers',
    line:{color:pos?'#00c087':'#ff4b4b',width:2},
    marker:{color:colors,size:6},
    fill:'tozeroy',fillcolor:pos?'rgba(0,192,135,0.1)':'rgba(255,75,75,0.1)',
    hovertemplate:'%{x}<br>P&L: Rs.%{y:,.2f}<extra></extra>'
  }],{
    paper_bgcolor:DARK,plot_bgcolor:DARK,font:{color:TXT,size:11},
    xaxis:{showticklabels:false,showgrid:false,zeroline:false},
    yaxis:{tickprefix:'Rs.',showgrid:true,gridcolor:GRID,zeroline:true,zerolinecolor:'#666'},
    margin:{t:10,b:10,l:80,r:10},height:220,showlegend:false,
    hovermode:'closest',hoverlabel:{bgcolor:'#1e1e2f',font:{color:'#fff'}}
  },{responsive:true,displayModeBar:false});
}

function drawAcc(trades){
  var sells = trades.filter(function(t){ return t.action.toUpperCase()==='SELL'; });
  if(!sells.length){ empty('chartAcc','No sell trades yet'); return; }
  var buyMap={};
  trades.forEach(function(t){
    if(t.action.toUpperCase()!=='BUY') return;
    var s=t.symbol, p=parseFloat(t.price||0), q=parseInt(t.quantity||0);
    if(!buyMap[s]) buyMap[s]={cost:0,qty:0};
    buyMap[s].cost+=p*q; buyMap[s].qty+=q;
  });
  var wins=0,losses=0;
  sells.forEach(function(t){
    var avg = buyMap[t.symbol]&&buyMap[t.symbol].qty>0 ? buyMap[t.symbol].cost/buyMap[t.symbol].qty : parseFloat(t.price||0);
    if(parseFloat(t.price||0)>=avg) wins++; else losses++;
  });
  var acc = Math.round(wins/sells.length*100);
  Plotly.newPlot('chartAcc',[{
    type:'indicator',mode:'gauge+number',value:acc,
    number:{suffix:'%',font:{size:38,color:'#fff'}},
    gauge:{
      axis:{range:[0,100],tickcolor:TXT,tickfont:{color:TXT}},
      bar:{color:acc>=50?'#00c087':'#ff4b4b'},
      bgcolor:DARK,bordercolor:GRID,
      steps:[{range:[0,40],color:'rgba(255,75,75,0.15)'},{range:[40,60],color:'rgba(255,193,7,0.15)'},{range:[60,100],color:'rgba(0,192,135,0.15)'}],
      threshold:{line:{color:'#fff',width:2},thickness:0.75,value:50}
    },
    title:{text:wins+' wins / '+losses+' losses',font:{color:TXT,size:12}}
  }],{paper_bgcolor:DARK,font:{color:TXT},margin:{t:30,b:10,l:20,r:20},height:230},{responsive:true,displayModeBar:false});
}

function drawVol(trades){
  if(!trades.length){ empty('chartVol','No trades yet'); return; }
  var bv={},sv={};
  trades.forEach(function(t){
    var s=t.symbol||'?',q=parseInt(t.quantity||0);
    if(t.action.toUpperCase()==='BUY') bv[s]=(bv[s]||0)+q; else sv[s]=(sv[s]||0)+q;
  });
  var syms=[...new Set([...Object.keys(bv),...Object.keys(sv)])];
  Plotly.newPlot('chartVol',[
    {x:syms,y:syms.map(function(s){return bv[s]||0;}),type:'bar',name:'Buy',marker:{color:'#00c087'}},
    {x:syms,y:syms.map(function(s){return sv[s]||0;}),type:'bar',name:'Sell',marker:{color:'#ff4b4b'}}
  ],{
    paper_bgcolor:DARK,plot_bgcolor:DARK,barmode:'group',font:{color:TXT,size:11},
    xaxis:{showgrid:false,tickfont:{color:TXT}},
    yaxis:{showgrid:true,gridcolor:GRID,title:{text:'Units',font:{color:'#888'}}},
    legend:{font:{color:TXT},orientation:'h',x:0,y:1.15},
    margin:{t:20,b:30,l:50,r:10},height:200
  },{responsive:true,displayModeBar:false});
}

function drawPpt(trades){
  if(!trades.length){ empty('chartPpt','No trades yet'); return; }
  var buyMap={},labels=[],profits=[],colors=[];
  trades.forEach(function(t,i){
    var s=t.symbol||'?',p=parseFloat(t.price||0),q=parseInt(t.quantity||0);
    if(t.action.toUpperCase()==='BUY'){
      if(!buyMap[s]) buyMap[s]={cost:0,qty:0};
      buyMap[s].cost+=p*q; buyMap[s].qty+=q;
    } else {
      var avg=buyMap[s]&&buyMap[s].qty>0?buyMap[s].cost/buyMap[s].qty:p;
      var pnl=(p-avg)*q;
      labels.push(s+' @'+t.time);
      profits.push(parseFloat(pnl.toFixed(2)));
      colors.push(pnl>=0?'#00c087':'#ff4b4b');
    }
  });
  if(!labels.length){ empty('chartPpt','No sell trades yet'); return; }
  Plotly.newPlot('chartPpt',[{
    x:labels,y:profits,type:'bar',marker:{color:colors},
    hovertemplate:'%{x}<br>P&L: Rs.%{y:,.2f}<extra></extra>'
  }],{
    paper_bgcolor:DARK,plot_bgcolor:DARK,font:{color:TXT,size:11},
    xaxis:{showticklabels:labels.length<=6,tickfont:{color:TXT,size:10},showgrid:false},
    yaxis:{tickprefix:'Rs.',showgrid:true,gridcolor:GRID,zeroline:true,zerolinecolor:'#666'},
    margin:{t:10,b:labels.length<=6?40:20,l:80,r:10},height:200,showlegend:false
  },{responsive:true,displayModeBar:false});
}

function drawTable(trades){
  var tbody=document.getElementById('tbody');
  if(!trades.length){ tbody.innerHTML='<tr><td colspan="6" class="empty">No trades yet</td></tr>'; return; }
  tbody.innerHTML=[...trades].reverse().slice(0,15).map(function(t){
    var buy=t.action.toUpperCase()==='BUY';
    var total=(parseFloat(t.price||0)*parseInt(t.quantity||0)).toLocaleString('en-IN',{minimumFractionDigits:2});
    return '<tr><td>'+t.time+'</td><td><strong>'+t.symbol+'</strong></td>'
      +'<td><span class="'+(buy?'pos':'neg')+'">'+t.action+'</span></td>'
      +'<td>'+t.quantity+'</td><td>Rs.'+parseFloat(t.price).toFixed(2)+'</td><td>Rs.'+total+'</td></tr>';
  }).join('');
}

function empty(id,msg){ document.getElementById(id).innerHTML='<div class="empty">'+msg+'</div>'; }

loadDashboard();
setInterval(loadDashboard, 15000);
</script>
</body>
</html>
