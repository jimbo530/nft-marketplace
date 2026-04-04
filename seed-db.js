#!/usr/bin/env node
/**
 * Seed nft_d20_stats in Supabase from local stats-cache.json
 *
 * Usage:
 *   node seed-db.js <SUPABASE_SERVICE_ROLE_KEY>
 *
 * Get your service role key from:
 *   Supabase Dashboard → Settings → API → service_role (secret)
 *
 * This reads stats-cache.json from either Tales-of-Tasern or nft-game
 * and upserts all NFT backing data into the nft_d20_stats table.
 */

const fs = require('fs');
const path = require('path');

const SUPABASE_URL = "https://yxtejarmzzbwgckvhqdx.supabase.co";
const SERVICE_KEY = process.argv[2];

if (!SERVICE_KEY) {
  console.error("Usage: node seed-db.js <SUPABASE_SERVICE_ROLE_KEY>");
  console.error("\nGet your service role key from:");
  console.error("  Supabase Dashboard → Settings → API → service_role (secret)");
  process.exit(1);
}

// Try to find stats-cache.json
const paths = [
  path.join(__dirname, '..', 'Tales-of-Tasern', 'public', 'stats-cache.json'),
  path.join(__dirname, '..', 'nft-game', 'public', 'stats-cache.json'),
];

let data = null;
let usedPath = null;
for (const p of paths) {
  try {
    data = JSON.parse(fs.readFileSync(p, 'utf8'));
    usedPath = p;
    break;
  } catch (e) { /* try next */ }
}

if (!data || !data.characters) {
  console.error("Could not find stats-cache.json in Tales-of-Tasern or nft-game");
  process.exit(1);
}

console.log(`Read ${data.characters.length} NFTs from ${usedPath}`);
console.log(`Updated: ${data.updatedAt}`);

async function seed() {
  // Build rows matching the schema the refresh cron uses
  const rows = data.characters.map(c => ({
    key: c.contractAddress.toLowerCase(),
    data: c,
    updated_at: new Date().toISOString(),
  }));

  // Add summary row
  rows.push({
    key: "__summary__",
    data: {
      assetTotals: data.assetTotals,
      tokenBreakdown: data.tokenBreakdown,
      prices: data.prices,
      updatedAt: data.updatedAt,
    },
    updated_at: new Date().toISOString(),
  });

  console.log(`Upserting ${rows.length} rows to nft_d20_stats...`);

  let written = 0;
  // Batch in chunks of 50 (Supabase REST limit is generous but let's be safe)
  for (let i = 0; i < rows.length; i += 50) {
    const chunk = rows.slice(i, i + 50);

    const res = await fetch(`${SUPABASE_URL}/rest/v1/nft_d20_stats`, {
      method: 'POST',
      headers: {
        'apikey': SERVICE_KEY,
        'Authorization': `Bearer ${SERVICE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: JSON.stringify(chunk),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error(`  Chunk ${i}-${i + chunk.length}: FAILED (${res.status}): ${err}`);
    } else {
      written += chunk.length;
      console.log(`  Chunk ${i}-${i + chunk.length}: OK`);
    }
  }

  console.log(`\nDone! Wrote ${written}/${rows.length} rows.`);

  // Verify by reading back
  const check = await fetch(
    `${SUPABASE_URL}/rest/v1/nft_d20_stats?select=key&key=neq.__summary__`,
    {
      headers: {
        'apikey': SERVICE_KEY,
        'Authorization': `Bearer ${SERVICE_KEY}`,
      },
    }
  );
  if (check.ok) {
    const result = await check.json();
    console.log(`Verification: ${result.length} NFT rows in database.`);
  }

  console.log("\n✓ Marketplace will now show real USD backing values!");
  console.log("\nIMPORTANT: To keep data fresh, add SUPABASE_SERVICE_ROLE_KEY to Vercel:");
  console.log("  cd C:\\Users\\bigji\\Documents\\Tales-of-Tasern");
  console.log("  npx vercel env add SUPABASE_SERVICE_ROLE_KEY");
  console.log("  (paste the same key, select Production environment)");
  console.log("  npx vercel --prod   # redeploy");
}

seed().catch(e => {
  console.error("Failed:", e);
  process.exit(1);
});
