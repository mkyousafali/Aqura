// Delivery Settings Store
// Manages delivery fee tiers and service settings

import { writable, derived, get } from 'svelte/store';
import { supabase, supabaseAdmin } from '$lib/utils/supabase';

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
  // Load all delivery tiers from database
  async loadTiers() {
    deliveryDataLoading.set(true);
    try {
      const { data, error } = await supabase.rpc('get_all_delivery_tiers');
      
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
  async getDeliveryFee(orderAmount) {
    try {
      const { data, error } = await supabase.rpc('get_delivery_fee_for_amount', {
        order_amount: orderAmount
      });
      
      if (error) throw error;
      
      return data || 0;
    } catch (error) {
      console.error('Error calculating delivery fee:', error);
      return 0;
    }
  },

  // Get delivery fee using local tiers (faster, no DB call)
  getDeliveryFeeLocal(orderAmount) {
    const tiers = get(deliveryTiers);
    
    // Find the appropriate tier
    for (let i = tiers.length - 1; i >= 0; i--) {
      const tier = tiers[i];
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
  async getNextTier(currentAmount) {
    try {
      const { data, error } = await supabase.rpc('get_next_delivery_tier', {
        current_amount: currentAmount
      });
      
      if (error) throw error;
      
      return data && data.length > 0 ? data[0] : null;
    } catch (error) {
      console.error('Error getting next tier:', error);
      return null;
    }
  },

  // Get next tier using local tiers (faster)
  getNextTierLocal(currentAmount) {
    const tiers = get(deliveryTiers);
    const currentFee = this.getDeliveryFeeLocal(currentAmount);
    
    // Find next tier with lower fee and higher min amount
    for (const tier of tiers) {
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
  async addTier(tierData) {
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
          is_active: true
        }])
        .select();
      
      if (error) throw error;
      
      // Reload tiers
      await this.loadTiers();
      return { success: true, data };
    } catch (error) {
      console.error('Error adding tier:', error);
      return { success: false, error: error.message };
    }
  },

  // Update tier (admin only)
  async updateTier(tierId, tierData) {
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
      await this.loadTiers();
      return { success: true, data };
    } catch (error) {
      console.error('Error updating tier:', error);
      return { success: false, error: error.message };
    }
  },

  // Delete tier (admin only)
  async deleteTier(tierId) {
    try {
      const { error } = await supabaseAdmin
        .from('delivery_fee_tiers')
        .delete()
        .eq('id', tierId);
      
      if (error) throw error;
      
      // Reload tiers
      await this.loadTiers();
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
    await Promise.all([
      this.loadTiers(),
      this.loadSettings()
    ]);
  }
};

// Derived store for free delivery threshold (highest tier with 0 fee)
export const freeDeliveryThreshold = derived(deliveryTiers, ($tiers) => {
  const freeTier = $tiers.find(t => t.is_active && t.delivery_fee === 0);
  return freeTier ? freeTier.min_order_amount : 500; // Default to 500 if not found
});

// Initialize on module load
if (typeof window !== 'undefined') {
  deliveryActions.initialize().catch(console.error);
}
