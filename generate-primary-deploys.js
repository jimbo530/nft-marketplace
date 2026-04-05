// Generate deploy-primary-*.html for all 8 nations
const fs = require('fs');
const path = require('path');

const BYTECODE = fs.readFileSync(path.join(__dirname, 'contracts/NFTMarketplacePoly_sol_NFTMarketplacePoly.bin'), 'utf8').trim();
const ABI = fs.readFileSync(path.join(__dirname, 'contracts/NFTMarketplacePoly_sol_NFTMarketplacePoly.abi'), 'utf8').trim();

const nations = [
  { id:'igs', sym:'IGS', addr:'0xE302672798D12e7F68c783dB2c2d5E6B48ccf3ce', label:"Bazaar of Igypt", accent:'#c9a84c', textCol:'#f0d070' },
  { id:'egp', sym:'EGP', addr:'0x64f6F111E9Fdb753877f17f399b759De97379170', label:"Elven Emporium", accent:'#a78bfa', textCol:'#c4b5fd' },
  { id:'btn', sym:'BTN', addr:'0xD7C584D40216576f1d8651Eab8bEF9DE69497666', label:"Magic Grove", accent:'#4ade80', textCol:'#a7f3d0' },
  { id:'lgp', sym:'LGP', addr:'0xdDc330761761751e005333208889bfe36C6E6760', label:"Dwarven Fortress", accent:'#d97706', textCol:'#fbbf24' },
  { id:'dhg', sym:'DHG', addr:'0x75C0A194cD8B4F01D5eD58be5B7C5b61A9C69D0a', label:"Dragon's Nest", accent:'#ef4444', textCol:'#f0d070' },
  { id:'ddd', sym:'DDD', addr:'0x4BF82cF0d6b2afC87367052B793097153C859D38', label:"Durgan Dynasty", accent:'#818cf8', textCol:'#c4b5fd' },
  { id:'pkt', sym:'PKT', addr:'0x8a088dCEEcbCF457762EB7C66F78ffF27dC0C04a', label:"Pirate's Cove", accent:'#22d3ee', textCol:'#a5f3fc' },
  { id:'ogc', sym:'OGC', addr:'0xCcF37622E6B72352e7b410481dD4913563038B7c', label:"Ork Warcamp", accent:'#dc2626', textCol:'#fca5a5' },
];

for (const n of nations) {
  const html = `<!DOCTYPE html><html><head><title>Deploy NFT Primary \u2014 ${n.label} (${n.sym}/PR25)</title><script src="https://cdnjs.cloudflare.com/ajax/libs/ethers/6.13.1/ethers.umd.min.js"><\/script></head>
<body style="background:#0a0608;color:#e8d5b0;font-family:Georgia;padding:30px;text-align:center;max-width:900px;margin:0 auto;">
<h1 style="color:${n.accent};">${n.label} \u2014 Primary NFT Market</h1>
<p>Polygon \u2014 WETH payments, ${n.sym}/PR25 LP building</p>
<p style="color:#888;font-size:13px;">50% LP&rarr;NFT | 20% artist | 30% LP&rarr;community | No platform fee</p>

<div style="margin:20px 0;text-align:left;max-width:600px;margin:20px auto;">
  <label style="color:${n.accent};">${n.sym} Token (auto-filled):</label><br>
  <input id="tokenAAddr" type="text" value="${n.addr}" readonly style="background:#1a1418;color:#888;border:1px solid ${n.accent}44;padding:10px;font-size:13px;width:100%;margin:5px 0 15px;font-family:monospace;box-sizing:border-box;" />
  <label style="color:${n.accent};">Community Wallet:</label><br>
  <input id="communityWallet" type="text" placeholder="0x..." style="background:#1a1418;color:${n.textCol};border:1px solid ${n.accent}44;padding:10px;font-size:13px;width:100%;margin:5px 0 15px;font-family:monospace;box-sizing:border-box;" />
</div>

<div style="margin:20px 0;">
  <button onclick="deploy()" id="btnDeploy" style="background:${n.accent};color:#0a0608;border:none;padding:14px 30px;font-size:15px;font-weight:bold;border-radius:8px;cursor:pointer;">Deploy ${n.sym} Primary Contract</button>
</div>

<div style="margin:20px 0;text-align:left;max-width:600px;margin:20px auto;">
  <label style="color:${n.accent};">Or reconnect to existing contract:</label><br>
  <input id="existingAddr" type="text" placeholder="0x..." style="background:#1a1418;color:${n.textCol};border:1px solid ${n.accent}44;padding:10px;font-size:13px;width:100%;margin:5px 0 10px;font-family:monospace;box-sizing:border-box;" />
  <button onclick="reconnect()" style="background:#4ade80;color:#0a0608;border:none;padding:10px 20px;font-size:14px;font-weight:bold;border-radius:8px;cursor:pointer;">Reconnect</button>
</div>

<p id="status" style="margin:20px;color:#4ade80;"></p>

<div id="postDeploy" style="display:none;margin:30px auto;max-width:700px;">
  <h2 style="color:${n.accent};">${n.sym} Primary Contract Active</h2>
  <p>Contract: <span id="contractAddr" style="color:${n.textCol};font-family:monospace;"></span></p>

  <hr style="border-color:${n.accent}44;margin:25px 0;">
  <h3 style="color:${n.accent};">List an NFT for Primary Sale</h3>
  <div style="text-align:left;">
    <label style="color:${n.accent};">NFT Contract (ERC-1155):</label><br>
    <input id="nftAddr" type="text" placeholder="0x..." style="background:#1a1418;color:${n.textCol};border:1px solid ${n.accent}44;padding:8px;font-size:13px;width:100%;margin:5px 0 10px;font-family:monospace;box-sizing:border-box;" />
    <label style="color:${n.accent};">Token ID:</label><br>
    <input id="tokenId" type="text" value="1" style="background:#1a1418;color:${n.textCol};border:1px solid ${n.accent}44;padding:8px;font-size:13px;width:200px;margin:5px 0 10px;font-family:monospace;" />
    <label style="color:${n.accent};">Amount:</label><br>
    <input id="amount" type="text" value="1" style="background:#1a1418;color:${n.textCol};border:1px solid ${n.accent}44;padding:8px;font-size:13px;width:200px;margin:5px 0 10px;font-family:monospace;" />
    <label style="color:${n.accent};">Price (WETH):</label><br>
    <input id="price" type="text" value="0.001" style="background:#1a1418;color:${n.textCol};border:1px solid ${n.accent}44;padding:8px;font-size:13px;width:200px;margin:5px 0 10px;font-family:monospace;" />
    <label style="color:${n.accent};">Artist Wallet:</label><br>
    <input id="artistWallet" type="text" placeholder="0x..." style="background:#1a1418;color:${n.textCol};border:1px solid ${n.accent}44;padding:8px;font-size:13px;width:100%;margin:5px 0 10px;font-family:monospace;box-sizing:border-box;" />
  </div>
  <div style="margin:15px 0;">
    <button onclick="approveNft()" style="background:${n.accent};color:#0a0608;border:none;padding:10px 20px;font-size:14px;font-weight:bold;border-radius:8px;cursor:pointer;">1. Approve NFT</button>
    <button onclick="listNft()" style="background:#4ade80;color:#0a0608;border:none;padding:10px 20px;font-size:14px;font-weight:bold;border-radius:8px;cursor:pointer;margin-left:10px;">2. List NFT</button>
  </div>

  <hr style="border-color:${n.accent}44;margin:25px 0;">
  <h3 style="color:${n.accent};">Buy a Listed NFT</h3>
  <div style="text-align:left;">
    <label style="color:${n.accent};">Listing ID:</label><br>
    <input id="buyListingId" type="text" value="0" style="background:#1a1418;color:${n.textCol};border:1px solid ${n.accent}44;padding:8px;font-size:13px;width:200px;margin:5px 0 10px;font-family:monospace;" />
    <p id="totalCostDisplay" style="color:${n.textCol};font-family:monospace;margin:5px 0;"></p>
  </div>
  <div style="margin:15px 0;">
    <button onclick="showTotalCost()" style="background:${n.accent};color:#0a0608;border:none;padding:10px 20px;font-size:14px;font-weight:bold;border-radius:8px;cursor:pointer;">Check Price</button>
    <button onclick="approveWeth()" style="background:${n.accent};color:#0a0608;border:none;padding:10px 20px;font-size:14px;font-weight:bold;border-radius:8px;cursor:pointer;margin-left:10px;">1. Approve WETH</button>
    <button onclick="buyNft()" style="background:#4ade80;color:#0a0608;border:none;padding:10px 20px;font-size:14px;font-weight:bold;border-radius:8px;cursor:pointer;margin-left:10px;">2. Buy NFT</button>
  </div>

  <hr style="border-color:${n.accent}44;margin:25px 0;">
  <h3 style="color:${n.accent};">Cancel Listing</h3>
  <div style="text-align:left;">
    <label style="color:${n.accent};">Listing ID:</label><br>
    <input id="cancelListingId" type="text" value="0" style="background:#1a1418;color:${n.textCol};border:1px solid ${n.accent}44;padding:8px;font-size:13px;width:200px;margin:5px 0 10px;font-family:monospace;" />
  </div>
  <button onclick="cancelListing()" style="background:${n.accent};color:#fff;border:none;padding:10px 20px;font-size:14px;font-weight:bold;border-radius:8px;cursor:pointer;">Cancel Listing</button>
</div>

<div id="log" style="margin:20px 0;padding:15px;background:#1a1418;border:1px solid ${n.accent}44;border-radius:8px;text-align:left;font-family:monospace;font-size:11px;max-height:400px;overflow-y:auto;display:none;"></div>

<script>
var WETH = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";

var BYTECODE = "0x${BYTECODE}";

var ABI = ${ABI};

var ERC20_ABI = [
  {"inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"account","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
];

var ERC1155_ABI = [
  {"inputs":[{"name":"operator","type":"address"},{"name":"approved","type":"bool"}],"name":"setApprovalForAll","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"account","type":"address"},{"name":"operator","type":"address"}],"name":"isApprovedForAll","outputs":[{"name":"","type":"bool"}],"stateMutability":"view","type":"function"}
];

var contractAddr = null;
var signer = null;

function log(msg, color) {
  var el = document.getElementById("log");
  el.style.display = "block";
  el.innerHTML += "<div style='margin:3px 0;color:" + (color || "#e8d5b0") + ";'>" + msg + "</div>";
  el.scrollTop = el.scrollHeight;
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
  log("Wallet: " + await signer.getAddress(), "#4ade80");
  return signer;
}

async function reconnect() {
  var addr = document.getElementById("existingAddr").value.trim();
  if (!addr) { document.getElementById("status").innerText = "Enter contract address"; return; }
  await getSigner();
  contractAddr = addr;
  document.getElementById("contractAddr").innerText = contractAddr;
  document.getElementById("postDeploy").style.display = "block";
  document.getElementById("status").innerHTML = "Reconnected to <span style='color:${n.textCol};font-family:monospace;'>" + contractAddr + "</span>";
  log("Reconnected to " + contractAddr, "#4ade80");
}

async function deploy() {
  var s = document.getElementById("status");
  var btn = document.getElementById("btnDeploy");
  btn.disabled = true;
  try {
    var ta = document.getElementById("tokenAAddr").value.trim();
    var cw = document.getElementById("communityWallet").value.trim();
    if (!cw) { s.innerText = "Enter community wallet address"; btn.disabled = false; return; }
    s.innerText = "Connecting wallet...";
    var sig = await getSigner();
    s.innerText = "Deploying ${n.sym} primary contract on Polygon... confirm in wallet";
    log("Deploying with tokenA=" + ta + ", communityWallet=" + cw);
    var f = new ethers.ContractFactory(ABI, BYTECODE, sig);
    var c = await f.deploy(ta, cw);
    s.innerText = "Waiting for confirmation...";
    await c.waitForDeployment();
    contractAddr = await c.getAddress();
    log("${n.sym} primary contract deployed: " + contractAddr, "#4ade80");
    s.innerHTML = "Deployed at <span style='color:${n.textCol};font-family:monospace;'>" + contractAddr + "</span>";
    document.getElementById("contractAddr").innerText = contractAddr;
    document.getElementById("postDeploy").style.display = "block";
  } catch(e) {
    s.innerHTML = "Error: " + e.message;
    log("Deploy error: " + e.message, "#ef4444");
    btn.disabled = false;
  }
}

async function approveNft() {
  var s = document.getElementById("status");
  try {
    await getSigner();
    var nftAddr = document.getElementById("nftAddr").value.trim();
    if (!nftAddr || !contractAddr) { s.innerText = "Missing NFT address or contract"; return; }
    s.innerText = "Approving marketplace for your NFTs...";
    var nft = new ethers.Contract(nftAddr, ERC1155_ABI, signer);
    var tx = await nft.setApprovalForAll(contractAddr, true);
    log("Approval tx: " + tx.hash);
    await tx.wait();
    log("NFT approved!", "#4ade80");
    s.innerText = "NFT approved! Now click List NFT.";
  } catch(e) {
    s.innerText = "Approve error: " + e.message;
    log("Approve error: " + e.message, "#ef4444");
  }
}

async function listNft() {
  var s = document.getElementById("status");
  try {
    await getSigner();
    var nftAddr = document.getElementById("nftAddr").value.trim();
    var tokenId = document.getElementById("tokenId").value.trim();
    var amount = document.getElementById("amount").value.trim();
    var price = document.getElementById("price").value.trim();
    var artist = document.getElementById("artistWallet").value.trim();
    if (!nftAddr || !tokenId || !amount || !price || !artist) { s.innerText = "Fill all fields"; return; }
    var priceWei = ethers.parseUnits(price, 18);
    s.innerText = "Listing NFT for " + price + " WETH...";
    var market = new ethers.Contract(contractAddr, ABI, signer);
    var tx = await market.list(nftAddr, tokenId, amount, priceWei, artist);
    log("List tx: " + tx.hash);
    var receipt = await tx.wait();
    var iface = new ethers.Interface(ABI);
    for (var l of receipt.logs) {
      try {
        var parsed = iface.parseLog(l);
        if (parsed && parsed.name === "Listed") {
          log("Listed! ID=" + parsed.args.listingId.toString(), "#4ade80");
        }
      } catch(e) {}
    }
    s.innerText = "NFT listed!";
  } catch(e) {
    s.innerText = "List error: " + e.message;
    log("List error: " + e.message, "#ef4444");
  }
}

async function showTotalCost() {
  try {
    await getSigner();
    var listingId = document.getElementById("buyListingId").value.trim();
    var market = new ethers.Contract(contractAddr, ABI, signer);
    var cost = await market.totalCost(listingId);
    var formatted = ethers.formatUnits(cost, 18);
    document.getElementById("totalCostDisplay").innerHTML = "Total cost (no platform fee): <span style='color:#4ade80;'>" + formatted + " WETH</span>";
    log("Listing #" + listingId + " cost: " + formatted + " WETH");
  } catch(e) {
    document.getElementById("totalCostDisplay").innerText = "Error: " + e.message;
  }
}

async function approveWeth() {
  var s = document.getElementById("status");
  try {
    await getSigner();
    var listingId = document.getElementById("buyListingId").value.trim();
    var market = new ethers.Contract(contractAddr, ABI, signer);
    var cost = await market.totalCost(listingId);
    var formatted = ethers.formatUnits(cost, 18);
    s.innerText = "Approving " + formatted + " WETH...";
    var weth = new ethers.Contract(WETH, ERC20_ABI, signer);
    var tx = await weth.approve(contractAddr, cost);
    log("WETH approve tx: " + tx.hash);
    await tx.wait();
    log("WETH approved for " + formatted + "!", "#4ade80");
    s.innerText = "WETH approved! Now click Buy NFT.";
  } catch(e) {
    s.innerText = "Approve error: " + e.message;
    log("WETH approve error: " + e.message, "#ef4444");
  }
}

async function buyNft() {
  var s = document.getElementById("status");
  try {
    await getSigner();
    var listingId = document.getElementById("buyListingId").value.trim();
    s.innerText = "Buying listing #" + listingId + "...";
    var market = new ethers.Contract(contractAddr, ABI, signer);
    var tx = await market.buy(listingId);
    log("Buy tx: " + tx.hash);
    var receipt = await tx.wait();
    var iface = new ethers.Interface(ABI);
    for (var l of receipt.logs) {
      try {
        var parsed = iface.parseLog(l);
        if (parsed && parsed.name === "Sold") {
          log("Sold! LP to NFT: " + parsed.args.lpToNft.toString() + " | LP to community: " + parsed.args.lpToCommunity.toString() + " | Artist: " + ethers.formatUnits(parsed.args.toArtist, 18) + " WETH", "#4ade80");
        }
      } catch(e) {}
    }
    s.innerText = "Purchase complete!";
  } catch(e) {
    s.innerText = "Buy error: " + e.message;
    log("Buy error: " + e.message, "#ef4444");
  }
}

async function cancelListing() {
  var s = document.getElementById("status");
  try {
    await getSigner();
    var listingId = document.getElementById("cancelListingId").value.trim();
    s.innerText = "Cancelling listing #" + listingId + "...";
    var market = new ethers.Contract(contractAddr, ABI, signer);
    var tx = await market.cancel(listingId);
    log("Cancel tx: " + tx.hash);
    await tx.wait();
    log("Listing #" + listingId + " cancelled!", "#4ade80");
    s.innerText = "Listing cancelled!";
  } catch(e) {
    s.innerText = "Cancel error: " + e.message;
    log("Cancel error: " + e.message, "#ef4444");
  }
}
<\/script>
</body></html>`;

  const filename = `deploy-primary-${n.id}.html`;
  fs.writeFileSync(path.join(__dirname, filename), html);
  console.log(`Created ${filename}`);
}

console.log('Done! All 8 deploy pages generated.');
