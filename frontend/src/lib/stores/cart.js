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
      
      const existingItem = cart.find(item => 
        item.id === product.id && item.selectedUnit?.id === selectedUnit?.id
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
    
    this.updateCartSummary();
    this.saveToStorage();
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
    if (quantity <= 0) {
      this.removeFromCart(productId, unitId);
      return;
    }

    cartStore.update(cart => {
      const item = cart.find(item => 
        item.id === productId && item.selectedUnit?.id === unitId
      );
      
      if (item) {
        item.quantity = quantity;
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
      if (item.offerType === 'bogo_get' && item.bogoDiscountType === 'free') {
        // For BOGO get products, calculate how many are free
        const freeQuantity = this.calculateBOGOFreeQuantity(item.selectedUnit?.id);
        const paidQuantity = Math.max(0, item.quantity - freeQuantity);
        total += paidQuantity * item.price;
      } else {
        // Regular items - full price
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

  // Get item quantity in cart
  getItemQuantity(productId, unitId) {
    const cart = get(cartStore);
    const item = cart.find(item => 
      item.id === productId && item.selectedUnit?.id === unitId
    );
    return item ? item.quantity : 0;
  }
};

// Initialize cart from storage
if (typeof window !== 'undefined') {
  cartActions.loadFromStorage();
}