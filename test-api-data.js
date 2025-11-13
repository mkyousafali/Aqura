// Test script to verify API data fetching
import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseKey = envVars.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function testAPIData() {
  console.log('🔍 Testing API data fetching...\n');

  // Get offer 17 (bundle)
  console.log('📦 Testing Bundle Offer (ID: 17)');
  const { data: bundleOffer, error: bundleOfferError } = await supabase
    .from('offers')
    .select('*')
    .eq('id', 17)
    .single();
  
  if (bundleOfferError) {
    console.error('❌ Error fetching bundle offer:', bundleOfferError);
  } else {
    console.log('✅ Bundle offer:', bundleOffer);
    
    // Get bundles for this offer
    const { data: bundles, error: bundlesError } = await supabase
      .from('offer_bundles')
      .select('*')
      .eq('offer_id', 17);
    
    if (bundlesError) {
      console.error('❌ Error fetching bundles:', bundlesError);
    } else {
      console.log('✅ Bundles found:', bundles?.length || 0);
      console.log('Bundle data:', JSON.stringify(bundles, null, 2));
    }
  }

  console.log('\n---\n');

  // Get offer 19 (BOGO)
  console.log('🎁 Testing BOGO Offer (ID: 19)');
  const { data: bogoOffer, error: bogoOfferError } = await supabase
    .from('offers')
    .select('*')
    .eq('id', 19)
    .single();
  
  if (bogoOfferError) {
    console.error('❌ Error fetching BOGO offer:', bogoOfferError);
  } else {
    console.log('✅ BOGO offer:', bogoOffer);
    
    // Get BOGO rules for this offer
    const { data: bogoRules, error: bogoRulesError } = await supabase
      .from('bogo_offer_rules')
      .select('*')
      .eq('offer_id', 19);
    
    if (bogoRulesError) {
      console.error('❌ Error fetching BOGO rules:', bogoRulesError);
    } else {
      console.log('✅ BOGO rules found:', bogoRules?.length || 0);
      console.log('BOGO data:', JSON.stringify(bogoRules, null, 2));
    }
  }
}

testAPIData().catch(console.error);
