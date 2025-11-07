import { writable, get } from 'svelte/store';

// Cart store
export const cartStore = writable([]);
export const cartCount = writable(0);
export const cartTotal = writable(0);

// Cart actions
export const cartActions = {
  // Add item to cart
  addToCart(product, selectedUnit, quantity = 1) {
    cartStore.update(cart => {
      const existingItem = cart.find(item => 
        item.id === product.id && item.selectedUnit?.id === selectedUnit?.id
      );

      if (existingItem) {
        existingItem.quantity += quantity;
      } else {
        cart.push({
          id: product.id,
          name: product.nameAr || product.name,
          nameEn: product.nameEn || product.name,
          selectedUnit,
          quantity,
          price: selectedUnit?.basePrice || product.basePrice || 0,
          originalPrice: selectedUnit?.originalPrice || product.originalPrice,
          image: product.image || selectedUnit?.photo,
          barcode: selectedUnit?.barcode || product.barcode
        });
      }

      return cart;
    });
    this.updateCartSummary();
    this.saveToStorage();
  },

  // Remove item from cart
  removeFromCart(productId, unitId) {
    cartStore.update(cart => {
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

  // Update cart summary (count and total)
  updateCartSummary() {
    const cart = get(cartStore);
    const count = cart.reduce((sum, item) => sum + item.quantity, 0);
    const total = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    
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