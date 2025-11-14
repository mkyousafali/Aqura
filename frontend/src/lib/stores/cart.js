import { writable, get } from 'svelte/store';

// Cart store
export const cartStore = writable([]);
export const cartCount = writable(0);
export const cartTotal = writable(0);

// Store active BOGO offers for tracking
let activeBOGOOffers = [];

// Function to set BOGO offers (called when products are loaded)
export function setActiveBOGOOffers(offers) {
  activeBOGOOffers = offers;
}

// Cart actions
export const cartActions = {
  // Add item to cart
  addToCart(product, selectedUnit, quantity = 1) {
    console.log('🛒 Adding to cart:', { 
      productId: product.id,
      unitId: selectedUnit?.id,
      productName: product.nameAr,
      unitOfferType: selectedUnit?.offerType,
      unitBogoGetProductId: selectedUnit?.bogoGetProductId 
    });
    
    cartStore.update(cart => {
      console.log('📦 Current cart:', cart.map(i => ({ 
        id: i.id,
        unitId: i.selectedUnit?.id,
        name: i.name, 
        offerType: i.offerType,
        bogoGetProductId: i.bogoGetProductId 
      })));
      
      // For BOGO get products with free discount, find non-auto-added item
      const existingItem = cart.find(item => 
        item.id === product.id && 
        item.selectedUnit?.id === selectedUnit?.id &&
        !item.isAutoAdded // Only find manually added items
      );

      if (existingItem) {
        existingItem.quantity += quantity;
        console.log('✅ Updated existing item quantity');
      } else {
        // Always use base price, BOGO discount will be calculated in summary
        let finalPrice = selectedUnit?.basePrice || product.basePrice || 0;
        let buyProductInCart = null;
        
        if (selectedUnit?.offerType === 'bogo_get') {
          console.log('🎁 This is a BOGO get product, checking for buy product in cart...');
          console.log('  Looking for buy product with bogoGetProductId:', selectedUnit?.id);
          
          // Find if the buy product is in cart (match unit UUID, not serial)
          buyProductInCart = cart.find(item => {
            console.log('  Checking item:', { 
              itemUnitId: item.selectedUnit?.id,
              itemOfferType: item.offerType,
              itemBogoGetProductId: item.bogoGetProductId,
              lookingFor: selectedUnit?.id
            });
            return item.offerType === 'bogo' && item.bogoGetProductId === selectedUnit?.id;
          });
          
          if (buyProductInCart) {
            console.log('✅ Found buy product in cart!');
          } else {
            console.log('❌ Buy product not found in cart');
          }
        }
        
        cart.push({
          id: product.id,
          name: product.nameAr || product.name,
          nameEn: product.nameEn || product.name,
          selectedUnit,
          quantity,
          price: finalPrice, // Keep original price, discount calculated in summary
          originalPrice: selectedUnit?.originalPrice || product.originalPrice,
          image: product.image || selectedUnit?.photo,
          barcode: selectedUnit?.barcode || product.barcode,
          // BOGO tracking
          offerType: selectedUnit?.offerType || null,
          bogoGetProductId: selectedUnit?.bogoGetProductId || null,
          bogoGetQuantity: selectedUnit?.bogoGetQuantity || null,
          bogoDiscountType: selectedUnit?.bogoDiscountType || null,
          linkedToBuyProductId: buyProductInCart?.id || null
        });
        
        console.log('✅ Added new item to cart with price:', finalPrice);
      }

      return cart;
    });
    
    // Auto-add free BOGO items if this is a buy product with free discount
    if (selectedUnit?.offerType === 'bogo' && 
        selectedUnit?.bogoDiscountType === 'free' && 
        selectedUnit?.bogoGetProductId) {
      // Get the total buy quantity from cart (after update)
      const cart = get(cartStore);
      const buyProduct = cart.find(item => 
        item.id === product.id && item.selectedUnit?.id === selectedUnit?.id
      );
      const totalBuyQuantity = buyProduct?.quantity || quantity;
      
      this.autoAddBOGOFreeItem(selectedUnit.bogoGetProductId, totalBuyQuantity, selectedUnit.bogoGetQuantity || 1);
    }
    
    this.updateCartSummary();
    this.saveToStorage();
  },

  // Automatically add free BOGO items when buy product is added
  autoAddBOGOFreeItem(getProductUnitId, buyQuantity, getQuantityPerBuy) {
    cartStore.update(cart => {
      // Check if auto-added get product is already in cart
      const existingGetProduct = cart.find(item => 
        item.selectedUnit?.id === getProductUnitId && 
        item.offerType === 'bogo_get' &&
        item.isAutoAdded === true
      );

      const freeQuantityNeeded = buyQuantity * getQuantityPerBuy;

      if (existingGetProduct) {
        // Update quantity if already exists
        existingGetProduct.quantity = freeQuantityNeeded;
      } else {
        // Add placeholder - will be enriched with product details
        cart.push({
          id: 'temp_bogo_' + getProductUnitId,
          name: 'BOGO Free Item',
          nameEn: 'BOGO Free Item',
          selectedUnit: { id: getProductUnitId },
          quantity: freeQuantityNeeded,
          price: 0,
          originalPrice: null,
          image: null,
          barcode: null,
          offerType: 'bogo_get',
          bogoDiscountType: 'free',
          linkedToBuyProductId: getProductUnitId,
          isAutoAdded: true
        });
      }

      return cart;
    });
  },

  // Check if a BOGO get product should be free based on cart state
  isBOGOProductFree(productId) {
    const cart = get(cartStore);
    // Check if there's a buy product in cart that makes this product free
    return cart.some(item => 
      item.offerType === 'bogo' && 
      item.bogoGetProductId === productId
    );
  },

  // Remove item from cart
  removeFromCart(productId, unitId) {
    cartStore.update(cart => {
      // Find the item being removed
      const itemToRemove = cart.find(item => 
        item.id === productId && item.selectedUnit?.id === unitId
      );
      
      // If it's a BOGO buy product with free discount, remove auto-added free items
      if (itemToRemove && 
          itemToRemove.offerType === 'bogo' && 
          itemToRemove.bogoDiscountType === 'free' && 
          itemToRemove.bogoGetProductId) {
        
        const getProductUnitId = itemToRemove.bogoGetProductId;
        
        // Remove auto-added free items
        cart = cart.filter(item => 
          !(item.selectedUnit?.id === getProductUnitId && item.isAutoAdded === true)
        );
      }
      
      // Remove the item
      const filtered = cart.filter(item => 
        !(item.id === productId && item.selectedUnit?.id === unitId)
      );
      
      return filtered;
    });
    this.updateCartSummary();
    this.saveToStorage();
  },

  // Update item quantity
  updateQuantity(productId, unitId, quantity) {
    console.log('📝 Update quantity called:', { productId, unitId, quantity });
    
    if (quantity <= 0) {
      this.removeFromCart(productId, unitId);
      return;
    }

    cartStore.update(cart => {
      const item = cart.find(item => 
        item.id === productId && 
        item.selectedUnit?.id === unitId &&
        !item.isAutoAdded // Explicitly exclude auto-added items
      );
      
      console.log('Found item:', item ? { 
        id: item.id, 
        name: item.name, 
        isAutoAdded: item.isAutoAdded,
        quantity: item.quantity 
      } : 'NOT FOUND');
      
      if (item) {
        item.quantity = quantity;
        
        // If this is a BOGO buy product with free discount, update free item quantity
        if (item.offerType === 'bogo' && 
            item.bogoDiscountType === 'free' && 
            item.bogoGetProductId) {
          
          const getProductUnitId = item.bogoGetProductId;
          const getQuantityPerBuy = item.bogoGetQuantity || 1;
          const newFreeQuantity = quantity * getQuantityPerBuy;
          
          const freeItem = cart.find(i => 
            i.selectedUnit?.id === getProductUnitId && i.isAutoAdded === true
          );
          
          if (freeItem) {
            freeItem.quantity = newFreeQuantity;
          }
        }
      }
      
      return cart;
    });
    this.updateCartSummary();
    this.saveToStorage();
  },

  // Clear cart
  clearCart() {
    cartStore.set([]);
    cartCount.set(0);
    cartTotal.set(0);
    localStorage.removeItem('cart');
  },

  // Calculate how many free items a BOGO get product should get
  calculateBOGOFreeQuantity(getProductUnitId) {
    const cart = get(cartStore);
    
    // Find the buy product in cart
    const buyProduct = cart.find(item => 
      item.offerType === 'bogo' && 
      item.bogoGetProductId === getProductUnitId
    );
    
    if (!buyProduct) return 0;
    
    // Calculate free quantity based on buy quantity and offer rules
    const buyQuantity = buyProduct.quantity || 0;
    const getQuantityPerBuy = buyProduct.bogoGetQuantity || 1;
    
    return buyQuantity * getQuantityPerBuy;
  },

  // Update cart summary (count and total)
  updateCartSummary() {
    const cart = get(cartStore);
    const count = cart.reduce((sum, item) => sum + item.quantity, 0);
    
    // Calculate total with BOGO pricing logic
    let total = 0;
    cart.forEach(item => {
      if (item.isAutoAdded && item.offerType === 'bogo_get') {
        // Auto-added free items don't count toward total
        return;
      }
      
      if (item.offerType === 'bogo_get' && item.bogoDiscountType === 'percentage' && !item.isAutoAdded) {
        // Manual BOGO with percentage discount - calculate free quantity
        const freeQuantity = this.calculateBOGOFreeQuantity(item.selectedUnit?.id);
        const paidQuantity = Math.max(0, item.quantity - freeQuantity);
        total += paidQuantity * item.price;
      } else if (!item.isAutoAdded) {
        // Regular items or manually added BOGO get items - full price
        total += item.price * item.quantity;
      }
    });
    
    cartCount.set(count);
    cartTotal.set(total);
  },

  // Save cart to localStorage
  saveToStorage() {
    const cart = get(cartStore);
    localStorage.setItem('cart', JSON.stringify(cart));
  },

  // Load cart from localStorage
  loadFromStorage() {
    try {
      const saved = localStorage.getItem('cart');
      if (saved) {
        const cart = JSON.parse(saved);
        cartStore.set(cart);
        this.updateCartSummary();
      }
    } catch (error) {
      console.error('Failed to load cart from storage:', error);
      this.clearCart();
    }
  },

  // Get item quantity in cart (excludes auto-added items)
  getItemQuantity(productId, unitId) {
    const cart = get(cartStore);
    const item = cart.find(item => 
      item.id === productId && 
      item.selectedUnit?.id === unitId &&
      !item.isAutoAdded // Only count manually added items
    );
    return item ? item.quantity : 0;
  }
};

// Initialize cart from storage
if (typeof window !== 'undefined') {
  cartActions.loadFromStorage();
}