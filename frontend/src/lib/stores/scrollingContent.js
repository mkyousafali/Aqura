import { writable } from 'svelte/store';

// Scrolling content store
export const scrollingContent = writable([]);

// Scrolling content actions
export const scrollingContentActions = {
  // Get active content based on language
  getActiveContent(content, language) {
    return content.filter(item => item.isActive).map(item => ({
      id: item.id,
      text: language === 'ar' ? item.textAr : item.textEn,
      color: item.color,
      backgroundColor: item.backgroundColor,
      speed: item.speed
    }));
  },

  // Add sample content
  initializeSampleContent() {
    const sampleContent = [
      {
        id: 1,
        textAr: '🎉 خصم 20% على جميع المشروبات الطبيعية - عرض محدود!',
        textEn: '🎉 20% OFF on All Natural Beverages - Limited Time!',
        color: '#FFFFFF',
        backgroundColor: '#10B300',
        speed: 50,
        isActive: true
      },
      {
        id: 2,
        textAr: '🚚 توصيل مجاني للطلبات فوق 500 ريال سعودي',
        textEn: '🚚 Free Delivery for Orders Over 500 SAR',
        color: '#FFFFFF',
        backgroundColor: '#E17739',
        speed: 45,
        isActive: true
      },
      {
        id: 3,
        textAr: '⭐ منتجات جديدة وصلت حديثاً - اكتشف مجموعتنا الحصرية!',
        textEn: '⭐ New Products Just Arrived - Discover Our Exclusive Collection!',
        color: '#FFFFFF',
        backgroundColor: '#C8A232',
        speed: 55,
        isActive: true
      }
    ];
    
    scrollingContent.set(sampleContent);
  }
};

// Initialize with sample content
if (typeof window !== 'undefined') {
  scrollingContentActions.initializeSampleContent();
}