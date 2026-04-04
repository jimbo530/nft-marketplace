-- Run this in Supabase SQL Editor
-- Creates nft_backing (shared chain data) and drops nft_d20_stats (no longer needed)

-- 1. Create nft_backing if it doesn't exist
create table if not exists nft_backing (
  key text primary key,
  data jsonb not null,
  updated_at timestamptz default now()
);

alter table nft_backing enable row level security;

-- Drop existing policy first to avoid "already exists" error
drop policy if exists "Public read nft_backing" on nft_backing;
create policy "Public read nft_backing" on nft_backing for select using (true);

-- 2. Drop the old D20-specific table (stats now computed client-side)
drop table if exists nft_d20_stats;

-- Done! Now trigger the cron to populate nft_backing:
-- https://tales-of-tasern.vercel.app/api/stats/refresh
