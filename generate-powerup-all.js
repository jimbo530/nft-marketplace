const fs = require('fs');
const path = require('path');

const nations = [
  { id:'igs', sym:'IGS', binFile:'PowerUpPoly_sol_PowerUpPoly', abiFile:'PowerUpPoly_sol_PowerUpPoly', label:'Bazaar of Igypt', accent:'#c9a84c', text:'#f0d070' },
  { id:'egp', sym:'EGP', binFile:'PowerUpElven_sol_PowerUpElven', abiFile:'PowerUpElven_sol_PowerUpElven', label:'Elven Emporium', accent:'#a78bfa', text:'#c4b5fd' },
  { id:'btn', sym:'BTN', binFile:'PowerUpBTN_sol_PowerUpBTN', abiFile:'PowerUpBTN_sol_PowerUpBTN', label:'Magic Grove', accent:'#4ade80', text:'#a7f3d0' },
  { id:'lgp', sym:'LGP', binFile:'PowerUpLGP_sol_PowerUpLGP', abiFile:'PowerUpLGP_sol_PowerUpLGP', label:'Dwarven Fortress', accent:'#d97706', text:'#fbbf24' },
  { id:'ddd', sym:'DDD', binFile:'PowerUpDDD_sol_PowerUpDDD', abiFile:'PowerUpDDD_sol_PowerUpDDD', label:'Durgan Dynasty', accent:'#818cf8', text:'#c4b5fd' },
  { id:'pkt', sym:'PKT', binFile:'PowerUpPKT_sol_PowerUpPKT', abiFile:'PowerUpPKT_sol_PowerUpPKT', label:"Pirate\\'s Cove", accent:'#22d3ee', text:'#a5f3fc' },
  { id:'ogc', sym:'OGC', binFile:'PowerUpOGC_sol_PowerUpOGC', abiFile:'PowerUpOGC_sol_PowerUpOGC', label:'Ork Warcamp', accent:'#dc2626', text:'#fca5a5' },
];

let nationsJS = 'var NATIONS = [\n';
for (const n of nations) {
  const bin = fs.readFileSync(path.join(__dirname, 'contracts', n.binFile + '.bin'), 'utf8').trim();
  const abi = fs.readFileSync(path.join(__dirname, 'contracts', n.abiFile + '.abi'), 'utf8').trim();
  nationsJS += `  {id:"${n.id}",sym:"${n.sym}",label:"${n.label}",accent:"${n.accent}",text:"${n.text}",\n`;
  nationsJS += `   bytecode:"0x${bin}",\n`;
  nationsJS += `   abi:${abi}},\n`;
}
nationsJS += '];\n';

const html = `<!DOCTYPE html><html><head><title>Deploy All Power-Up Contracts</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/ethers/6.13.1/ethers.umd.min.js"><\/script>
</head>
<body style="background:#0a0608;color:#e8d5b0;font-family:Georgia;padding:30px;max-width:900px;margin:0 auto;">
<h1 style="text-align:center;color:#22c55e;">Deploy All Power-Up Contracts</h1>
<p style="text-align:center;color:#888;">Polygon &mdash; WETH &rarr; PR25 &rarr; tokenA routing &mdash; no constructor args</p>
<p style="text-align:center;color:#666;font-size:13px;">Spend WETH to create LP tokens and send them to NFT contracts</p>

<div style="text-align:center;margin:20px 0;">
  <button onclick="deployAll()" id="btnGo" style="background:#22c55e;color:#0a0608;border:none;padding:14px 40px;font-size:16px;font-weight:bold;border-radius:8px;cursor:pointer;">Deploy All 7 Power-Ups</button>
  <p style="color:#666;font-size:12px;margin-top:8px;">DHG skipped &mdash; no PR25 pool yet</p>
</div>

<div id="nations" style="margin:20px auto;max-width:700px;"></div>

<div id="summary" style="display:none;margin:30px auto;max-width:700px;padding:20px;background:#1a1418;border:1px solid #22c55e44;border-radius:8px;">
  <h3 style="color:#4ade80;margin-top:0;">All Done! New power-up addresses:</h3>
  <pre id="summaryText" style="color:#f0d070;font-size:13px;white-space:pre-wrap;word-break:break-all;"></pre>
</div>

<script>
${nationsJS}

var signer = null;
var results = {};

function $(id){ return document.getElementById(id); }

function buildUI(){
  var wrap = $("nations");
  for(var i=0;i<NATIONS.length;i++){
    var n=NATIONS[i];
    var d=document.createElement("div");
    d.id="row-"+n.id;
    d.style.cssText="margin:12px 0;padding:16px;background:#1a1418;border:1px solid "+n.accent+"44;border-radius:8px;display:flex;align-items:center;gap:16px;";
    d.innerHTML='<div style="width:14px;height:14px;border-radius:50%;background:'+n.accent+';flex-shrink:0;"></div>'+
      '<div style="flex:1;">'+
        '<div style="font-weight:bold;color:'+n.accent+';font-size:15px;">'+n.label+' <span style="color:#888;font-weight:normal;font-size:13px;">('+n.sym+' power-up)</span></div>'+
        '<div id="addr-'+n.id+'" style="font-family:monospace;font-size:12px;color:'+n.text+';margin-top:4px;"></div>'+
      '</div>'+
      '<div id="status-'+n.id+'" style="font-size:13px;color:#888;flex-shrink:0;min-width:120px;text-align:right;">Waiting...</div>';
    wrap.appendChild(d);
  }
}

async function getSigner() {
  if (signer) return signer;
  if (!window.ethereum) throw new Error("No wallet found");
  await window.ethereum.request({method:"eth_requestAccounts"});
  try {
    await window.ethereum.request({method:"wallet_switchEthereumChain",params:[{chainId:"0x89"}]});
  } catch(e) {
    if (e.code===4902) await window.ethereum.request({method:"wallet_addEthereumChain",params:[{chainId:"0x89",chainName:"Polygon",rpcUrls:["https://polygon-rpc.com"],nativeCurrency:{name:"POL",symbol:"POL",decimals:18},blockExplorerUrls:["https://polygonscan.com"]}]});
  }
  var p = new ethers.BrowserProvider(window.ethereum);
  signer = await p.getSigner();
  return signer;
}

async function deployAll(){
  $("btnGo").disabled=true;
  $("btnGo").innerText="Deploying...";

  try{
    var sig = await getSigner();
    var wallet = await sig.getAddress();
    $("btnGo").innerText="Wallet: "+wallet.slice(0,6)+"..."+wallet.slice(-4);

    for(var i=0;i<NATIONS.length;i++){
      var n=NATIONS[i];
      var statusEl=$("status-"+n.id);
      var addrEl=$("addr-"+n.id);

      statusEl.style.color="#f0d070";
      statusEl.innerText="Deploying... sign in wallet";

      try{
        var f = new ethers.ContractFactory(n.abi, n.bytecode, sig);
        var c = await f.deploy();
        statusEl.innerText="Confirming...";
        await c.waitForDeployment();
        var addr = await c.getAddress();
        results[n.id] = addr;
        addrEl.innerHTML='powerUp: <span style="user-select:all;">'+addr+'</span>';
        statusEl.style.color="#4ade80";
        statusEl.innerText="Deployed!";
      }catch(e){
        statusEl.style.color="#ef4444";
        statusEl.innerText="Failed: "+(e.reason||e.message).slice(0,40);
      }
    }

    var txt="";
    for(var j=0;j<NATIONS.length;j++){
      var nn=NATIONS[j];
      if(results[nn.id]){
        txt+=nn.id+' ('+nn.sym+'): powerUp:"'+results[nn.id]+'"\\n';
      }
    }
    if(txt){
      $("summaryText").innerText=txt;
      $("summary").style.display="block";
    }

    $("btnGo").innerText="Done!";
  }catch(e){
    $("btnGo").innerText="Error: "+e.message;
    $("btnGo").disabled=false;
  }
}

buildUI();
<\/script>
</body></html>`;

fs.writeFileSync(path.join(__dirname, 'deploy-powerup-all.html'), html);
console.log('Created deploy-powerup-all.html (' + html.length + ' bytes)');
