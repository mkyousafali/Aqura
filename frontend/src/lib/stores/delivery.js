// Delivery Settings Store
// Manages delivery fee tiers and service settings

import { writable, derived, get } from 'svelte/store';
import { supabase, supabaseAdmin } from '$lib/utils/supabase';
import { orderFlow } from '$lib/stores/orderFlow.js';

// Store for delivery fee tiers
export const deliveryTiers = writable([]);

// Store for delivery service settings
export const deliverySettings = writable({
  minimumOrderAmount: 15.00,
  is24Hours: true,
  operatingStartTime: null,
  operatingEndTime: null,
  isActive: true,
  displayMessageAr: 'التوصيل متاح على مدار الساعة (24/7)',
  displayMessageEn: 'Delivery available 24/7'
});

// Loading state
export const deliveryDataLoading = writable(false);

// Actions
export const deliveryActions = {
  // Load delivery tiers (branch-specific if branchId provided)
  async loadTiers(branchId = null) {
    deliveryDataLoading.set(true);
    try {
      let rpcName;
      let params = {};
      if (branchId) {
        rpcName = 'get_delivery_tiers_by_branch';
        params = { p_branch_id: branchId };
      } else {
        rpcName = 'get_all_delivery_tiers';
      }
      const { data, error } = await supabase.rpc(rpcName, params);
      if (error) throw error;
      deliveryTiers.set(data || []);
      return data;
    } catch (error) {
      console.error('Error loading delivery tiers:', error);
      return [];
    } finally {
      deliveryDataLoading.set(false);
    }
  },

  // Load delivery service settings
  async loadSettings() {
    try {
      const { data, error } = await supabase.rpc('get_delivery_service_settings');
      
      if (error) throw error;
      
      if (data && data.length > 0) {
        deliverySettings.set({
          minimumOrderAmount: data[0].minimum_order_amount,
          is24Hours: data[0].is_24_hours,
          operatingStartTime: data[0].operating_start_time,
          operatingEndTime: data[0].operating_end_time,
          isActive: data[0].is_active,
          displayMessageAr: data[0].display_message_ar,
          displayMessageEn: data[0].display_message_en
        });
      }
      return data;
    } catch (error) {
      console.error('Error loading delivery settings:', error);
      return null;
    }
  },

  // Calculate delivery fee for a given amount
  async getDeliveryFee(orderAmount, branchId = null) {
    try {
      let rpcName;
      let params;
      if (branchId) {
        rpcName = 'get_delivery_fee_for_amount_by_branch';
        params = { p_branch_id: branchId, p_order_amount: orderAmount };
      } else {
        rpcName = 'get_delivery_fee_for_amount';
        params = { order_amount: orderAmount };
      }
      const { data, error } = await supabase.rpc(rpcName, params);
      if (error) throw error;
      return data || 0;
    } catch (error) {
      console.error('Error calculating delivery fee:', error);
      return 0;
    }
  },

  // Get delivery fee using local tiers (faster, no DB call)
  getDeliveryFeeLocal(orderAmount, branchId = null) {
    const tiers = get(deliveryTiers);
    let scoped = [];
    if (branchId) {
      scoped = tiers.filter(t => t.branch_id === branchId);
      if (scoped.length === 0) scoped = tiers.filter(t => t.branch_id == null);
    } else {
      scoped = tiers.filter(t => t.branch_id == null);
    }
    // Find the appropriate tier
    for (let i = scoped.length - 1; i >= 0; i--) {
      const tier = scoped[i];
      if (!tier.is_active) continue;
      const meetsMin = orderAmount >= tier.min_order_amount;
      const meetsMax = tier.max_order_amount === null || orderAmount <= tier.max_order_amount;
      if (meetsMin && meetsMax) {
        return tier.delivery_fee;
      }
    }
    return 0; // Default to 0 if no tier found
  },

  // Get next better tier
  async getNextTier(currentAmount, branchId = null) {
    try {
      let rpcName;
      let params;
      if (branchId) {
        rpcName = 'get_next_delivery_tier_by_branch';
        params = { p_branch_id: branchId, p_current_amount: currentAmount };
      } else {
        rpcName = 'get_next_delivery_tier';
        params = { current_amount: currentAmount };
      }
      const { data, error } = await supabase.rpc(rpcName, params);
      if (error) throw error;
      return data && data.length > 0 ? data[0] : null;
    } catch (error) {
      console.error('Error getting next tier:', error);
      return null;
    }
  },

  // Get next tier using local tiers (faster)
  getNextTierLocal(currentAmount, branchId = null) {
    const tiers = get(deliveryTiers);
    const currentFee = this.getDeliveryFeeLocal(currentAmount, branchId);
    let scoped = [];
    if (branchId) {
      scoped = tiers.filter(t => t.branch_id === branchId);
      if (scoped.length === 0) scoped = tiers.filter(t => t.branch_id == null);
    } else {
      scoped = tiers.filter(t => t.branch_id == null);
    }
    // Find next tier with lower fee and higher min amount
    for (const tier of scoped) {
      if (!tier.is_active) continue;
      if (tier.min_order_amount > currentAmount && tier.delivery_fee < currentFee) {
        return {
          nextTierMinAmount: tier.min_order_amount,
          nextTierDeliveryFee: tier.delivery_fee,
          amountNeeded: tier.min_order_amount - currentAmount,
          potentialSavings: currentFee - tier.delivery_fee,
          descriptionEn: tier.description_en,
          descriptionAr: tier.description_ar
        };
      }
    }
    return null;
  },

  // Add new tier (admin only)
  async addTier(tierData, branchId = null) {
    try {
      const { data, error } = await supabaseAdmin
        .from('delivery_fee_tiers')
        .insert([{
          min_order_amount: tierData.minOrderAmount,
          max_order_amount: tierData.maxOrderAmount,
          delivery_fee: tierData.deliveryFee,
          tier_order: tierData.tierOrder,
          description_en: tierData.descriptionEn,
          description_ar: tierData.descriptionAr,
          is_active: true,
          branch_id: branchId
        }])
        .select();
      
      if (error) throw error;
      
      // Reload tiers
      await this.loadTiers(branchId);
      return { success: true, data };
    } catch (error) {
      console.error('Error adding tier:', error);
      return { success: false, error: error.message };
    }
  },

  // Update tier (admin only)
  async updateTier(tierId, tierData, branchId = null) {
    try {
      const { data, error } = await supabaseAdmin
        .from('delivery_fee_tiers')
        .update({
          min_order_amount: tierData.minOrderAmount,
          max_order_amount: tierData.maxOrderAmount,
          delivery_fee: tierData.deliveryFee,
          tier_order: tierData.tierOrder,
          description_en: tierData.descriptionEn,
          description_ar: tierData.descriptionAr,
          is_active: tierData.isActive
        })
        .eq('id', tierId)
        .select();
      
      if (error) throw error;
      
      // Reload tiers
      await this.loadTiers(branchId);
      return { success: true, data };
    } catch (error) {
      console.error('Error updating tier:', error);
      return { success: false, error: error.message };
    }
  },

  // Delete tier (admin only)
  async deleteTier(tierId, branchId = null) {
    try {
      const { error } = await supabaseAdmin
        .from('delivery_fee_tiers')
        .delete()
        .eq('id', tierId);
      
      if (error) throw error;
      
      // Reload tiers
      await this.loadTiers(branchId);
      return { success: true };
    } catch (error) {
      console.error('Error deleting tier:', error);
      return { success: false, error: error.message };
    }
  },

  // Update delivery service settings (admin only)
  async updateSettings(settings) {
    try {
      const { data, error } = await supabaseAdmin
        .from('delivery_service_settings')
        .update({
          minimum_order_amount: settings.minimumOrderAmount,
          is_24_hours: settings.is24Hours,
          operating_start_time: settings.operatingStartTime,
          operating_end_time: settings.operatingEndTime,
          is_active: settings.isActive,
          display_message_ar: settings.displayMessageAr,
          display_message_en: settings.displayMessageEn
        })
        .eq('id', '00000000-0000-0000-0000-000000000001')
        .select();
      
      if (error) throw error;
      
      // Reload settings
      await this.loadSettings();
      return { success: true, data };
    } catch (error) {
      console.error('Error updating delivery settings:', error);
      return { success: false, error: error.message };
    }
  },

  // Check branch service availability
  async getBranchServices(branchId) {
    try {
      const { data, error } = await supabase.rpc('get_branch_service_availability', {
        branch_id: branchId
      });
      
      if (error) throw error;
      
      return data && data.length > 0 ? data[0] : null;
    } catch (error) {
      console.error('Error getting branch services:', error);
      return null;
    }
  },

  // Get branch delivery settings
  async getBranchDeliverySettings(branchId) {
    try {
      const { data, error } = await supabase.rpc('get_branch_delivery_settings', {
        branch_id: branchId
      });
      
      if (error) throw error;
      
      return data && data.length > 0 ? data[0] : null;
    } catch (error) {
      console.error('Error getting branch delivery settings:', error);
      return null;
    }
  },

  // Get all branches delivery settings
  async getAllBranchesSettings() {
    try {
      const { data, error } = await supabase.rpc('get_all_branches_delivery_settings');
      
      if (error) throw error;
      
      return data || [];
    } catch (error) {
      console.error('Error getting all branches settings:', error);
      return [];
    }
  },

  // Update branch delivery settings (admin only)
  async updateBranchSettings(branchId, settings) {
    try {
      const { data, error } = await supabaseAdmin
        .from('branches')
        .update({
          minimum_order_amount: settings.minimumOrderAmount,
          delivery_service_enabled: settings.deliveryServiceEnabled,
          delivery_is_24_hours: settings.deliveryIs24Hours,
          delivery_start_time: settings.deliveryStartTime,
          delivery_end_time: settings.deliveryEndTime,
          pickup_service_enabled: settings.pickupServiceEnabled,
          pickup_is_24_hours: settings.pickupIs24Hours,
          pickup_start_time: settings.pickupStartTime,
          pickup_end_time: settings.pickupEndTime,
          delivery_message_ar: settings.deliveryMessageAr,
          delivery_message_en: settings.deliveryMessageEn
        })
        .eq('id', branchId)
        .select();
      
      if (error) throw error;
      
      return { success: true, data };
    } catch (error) {
      console.error('Error updating branch settings:', error);
      return { success: false, error: error.message };
    }
  },

  // Initialize - load all data
  async initialize() {
    const flow = get(orderFlow);
    const branchId = flow?.branchId || null;
    await Promise.all([
      this.loadTiers(branchId),
      this.loadSettings()
    ]);
  }
};

// Derived store for free delivery threshold (highest tier with 0 fee)
export const freeDeliveryThreshold = derived([deliveryTiers, orderFlow], ([$tiers, $flow]) => {
  const branchId = $flow?.branchId || null;
  let scoped = [];
  if (branchId) {
    scoped = $tiers.filter(t => t.branch_id === branchId);
    if (scoped.length === 0) scoped = $tiers.filter(t => t.branch_id == null);
  } else {
    scoped = $tiers.filter(t => t.branch_id == null);
  }
  const freeTier = scoped.find(t => t.is_active && t.delivery_fee === 0);
  return freeTier ? freeTier.min_order_amount : 500;
});

// Initialize on module load
if (typeof window !== 'undefined') {
  deliveryActions.initialize().catch(console.error);
}
