import { supabase } from './supabase';

/**
 * Real-time service for Supabase
 * Manages Supabase realtime subscriptions for various tables
 */

export const realtimeService = {
  fingerprintChannel: null as any,
  receivingRecordsChannel: null as any,
  vendorPaymentChannel: null as any,

  /**
   * Subscribe to real-time receiving records changes
   * @param callback - Function to call when data changes
   * @returns Unsubscribe function
   */
  subscribeToReceivingRecordsChanges(
    callback: (payload: any) => void
  ): (() => void) | null {
    try {
      console.log('📡 Setting up real-time subscription for receiving_records...');

      const channelName = `receiving_records_${Date.now()}`;

      this.receivingRecordsChannel = supabase
        .channel(channelName)
        .on(
          'postgres_changes',
          {
            event: '*', // Listen to INSERT, UPDATE, DELETE
            schema: 'public',
            table: 'receiving_records'
          },
          (payload) => {
            console.log('📦 Real-time receiving record change detected:', {
              event: payload.eventType,
              recordId: payload.new?.id || payload.old?.id
            });
            callback(payload);
          }
        )
        .subscribe((status) => {
          console.log('📡 Receiving records subscription status:', status);
          if (status === 'SUBSCRIBED') {
            console.log('✅ Successfully subscribed to receiving_records changes');
          } else if (status === 'CHANNEL_ERROR') {
            console.warn('⚠️ Real-time subscription unavailable - data will load normally');
          } else if (status === 'TIMED_OUT') {
            console.warn('⏱️ Subscription timed out, retrying...');
            setTimeout(() => {
              this.subscribeToReceivingRecordsChanges(callback);
            }, 5000);
          }
        });

      return () => {
        if (this.receivingRecordsChannel) {
          console.log('🔌 Unsubscribing from receiving_records changes');
          supabase.removeChannel(this.receivingRecordsChannel);
          this.receivingRecordsChannel = null;
        }
      };
    } catch (error) {
      console.error('❌ Error setting up receiving_records subscription:', error);
      return null;
    }
  },

  /**
   * Subscribe to real-time vendor payment schedule changes
   * @param callback - Function to call when data changes
   * @returns Unsubscribe function
   */
  subscribeToVendorPaymentScheduleChanges(
    callback: (payload: any) => void
  ): (() => void) | null {
    try {
      console.log('📡 Setting up real-time subscription for vendor_payment_schedule...');

      const channelName = `vendor_payment_${Date.now()}`;

      this.vendorPaymentChannel = supabase
        .channel(channelName)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'vendor_payment_schedule'
          },
          (payload) => {
            console.log('💳 Real-time payment schedule change detected:', {
              event: payload.eventType,
              recordId: payload.new?.receiving_record_id || payload.old?.receiving_record_id
            });
            callback(payload);
          }
        )
        .subscribe((status) => {
          console.log('📡 Vendor payment subscription status:', status);
          if (status === 'SUBSCRIBED') {
            console.log('✅ Successfully subscribed to vendor_payment_schedule changes');
          } else if (status === 'CHANNEL_ERROR') {
            console.warn('⚠️ Real-time subscription unavailable - data will load normally');
          }
        });

      return () => {
        if (this.vendorPaymentChannel) {
          console.log('🔌 Unsubscribing from vendor_payment_schedule changes');
          supabase.removeChannel(this.vendorPaymentChannel);
          this.vendorPaymentChannel = null;
        }
      };
    } catch (error) {
      console.error('❌ Error setting up vendor_payment_schedule subscription:', error);
      return null;
    }
  },

  /**
   * Subscribe to real-time fingerprint transaction updates
   * @param callback - Function to call when data changes
   * @returns Unsubscribe function
   */
  subscribeToFingerprintChanges(
    callback: (payload: any) => void
  ): (() => void) | null {
    try {
      console.log('📡 Setting up real-time subscription for hr_fingerprint_transactions...');

      // Create a unique channel name
      const channelName = `fingerprint_changes_${Date.now()}`;

      // Subscribe to all changes on hr_fingerprint_transactions
      this.fingerprintChannel = supabase
        .channel(channelName)
        .on(
          'postgres_changes',
          {
            event: '*', // Listen to INSERT, UPDATE, DELETE
            schema: 'public',
            table: 'hr_fingerprint_transactions'
          },
          (payload) => {
            console.log('📍 Real-time punch update received:', {
              event: payload.eventType,
              new: payload.new,
              old: payload.old
            });
            callback(payload);
          }
        )
        .subscribe((status) => {
          console.log('📡 Real-time subscription status:', status);
          if (status === 'SUBSCRIBED') {
            console.log('✅ Successfully subscribed to fingerprint changes');
          } else if (status === 'CHANNEL_ERROR') {
            console.error('❌ Channel error - check Realtime settings in Supabase');
          } else if (status === 'TIMED_OUT') {
            console.warn('⏱️ Subscription timed out, retrying...');
            setTimeout(() => {
              this.subscribeToFingerprintChanges(callback);
            }, 5000);
          }
        });

      // Return unsubscribe function
      return () => {
        if (this.fingerprintChannel) {
          console.log('🔌 Unsubscribing from fingerprint changes');
          supabase.removeChannel(this.fingerprintChannel);
          this.fingerprintChannel = null;
        }
      };
    } catch (error) {
      console.error('❌ Error setting up real-time subscription:', error);
      return null;
    }
  },

  /**
   * Subscribe to fingerprint changes for a specific employee
   * @param employeeId - Employee code to filter by
   * @param callback - Function to call when data changes
   * @returns Unsubscribe function
   */
  subscribeToEmployeeFingerprintChanges(
    employeeId: string,
    callback: (payload: any) => void
  ): (() => void) | null {
    try {
      console.log(`📡 Setting up real-time subscription for employee ${employeeId}...`);

      const channelName = `fingerprint_${employeeId}_${Date.now()}`;

      this.fingerprintChannel = supabase
        .channel(channelName)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'hr_fingerprint_transactions',
            filter: `employee_id=eq.${employeeId}`
          },
          (payload) => {
            console.log(`📍 Real-time punch update for employee ${employeeId}:`, {
              event: payload.eventType,
              data: payload.new || payload.old
            });
            callback(payload);
          }
        )
        .subscribe((status) => {
          console.log(`📡 Subscription status for ${employeeId}:`, status);
          if (status === 'SUBSCRIBED') {
            console.log(`✅ Successfully subscribed to ${employeeId}'s punches`);
          }
        });

      return () => {
        if (this.fingerprintChannel) {
          console.log(`🔌 Unsubscribing from ${employeeId}'s punches`);
          supabase.removeChannel(this.fingerprintChannel);
          this.fingerprintChannel = null;
        }
      };
    } catch (error) {
      console.error(`❌ Error setting up subscription for ${employeeId}:`, error);
      return null;
    }
  },

  /**
   * Subscribe to fingerprint changes for a specific date
   * @param date - Date to filter by (YYYY-MM-DD format)
   * @param callback - Function to call when data changes
   * @returns Unsubscribe function
   */
  subscribeToDateFingerprintChanges(
    date: string,
    callback: (payload: any) => void
  ): (() => void) | null {
    try {
      console.log(`📡 Setting up real-time subscription for date ${date}...`);

      const channelName = `fingerprint_date_${date}_${Date.now()}`;

      this.fingerprintChannel = supabase
        .channel(channelName)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'hr_fingerprint_transactions',
            filter: `date=eq.${date}`
          },
          (payload) => {
            console.log(`📍 Real-time punch update for ${date}:`, {
              event: payload.eventType,
              employee_id: payload.new?.employee_id || payload.old?.employee_id,
              time: payload.new?.time || payload.old?.time
            });
            callback(payload);
          }
        )
        .subscribe((status) => {
          console.log(`📡 Subscription status for ${date}:`, status);
          if (status === 'SUBSCRIBED') {
            console.log(`✅ Successfully subscribed to ${date}'s punches`);
          }
        });

      return () => {
        if (this.fingerprintChannel) {
          console.log(`🔌 Unsubscribing from ${date}'s punches`);
          supabase.removeChannel(this.fingerprintChannel);
          this.fingerprintChannel = null;
        }
      };
    } catch (error) {
      console.error(`❌ Error setting up subscription for ${date}:`, error);
      return null;
    }
  },

  /**
   * Unsubscribe from all subscriptions
   */
  unsubscribeAll() {
    if (this.fingerprintChannel) {
      console.log('🔌 Unsubscribing from all fingerprint channels');
      supabase.removeChannel(this.fingerprintChannel);
      this.fingerprintChannel = null;
    }
    if (this.receivingRecordsChannel) {
      console.log('🔌 Unsubscribing from receiving_records channel');
      supabase.removeChannel(this.receivingRecordsChannel);
      this.receivingRecordsChannel = null;
    }
    if (this.vendorPaymentChannel) {
      console.log('🔌 Unsubscribing from vendor_payment_schedule channel');
      supabase.removeChannel(this.vendorPaymentChannel);
      this.vendorPaymentChannel = null;
    }
  }
};
