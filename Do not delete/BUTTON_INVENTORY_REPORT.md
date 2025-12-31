# Button Inventory Report

**Generated:** 30/12/2025, 1:55:54 pm  
**Total Components:** 206  
**Total Buttons:** 1444  
**Buttons With Permission Checks:** 12  
**Buttons Without Permission Checks:** 1432

---

## 📊 Summary Statistics

### By Interface
| Interface | Button Count |
|-----------|--------------|
| desktop | 944 |
| mobile | 92 |
| mobileComponents | 26 |
| customer | 78 |
| customerComponents | 9 |
| cashier | 7 |
| adminCustomer | 102 |
| marketing | 186 |

### By Action Type

| Action Type | Button Count |
|-------------|--------------|n| OTHER | 658 |
| CREATE | 185 |
| SAVE | 64 |
| VIEW | 114 |
| APPROVE | 21 |
| EDIT | 121 |
| DELETE | 150 |
| UPLOAD | 37 |
| EXPORT | 32 |
| ASSIGN | 54 |
| SEND | 8 |

---

## 📋 Complete Button Inventory

**Format:** Interface | Component Name | Button Purpose | Location (File:Line)

| Interface | Component | Button Purpose | Location | Has Permission |
|-----------|-----------|----------------|----------|----------------|
| Desktop | AdManager | OTHER: 🖼️ Home Page Screen Manager Man | AdManager.svelte:42 | ❌ |
| Desktop | BundleCreator | CREATE: + {isRTL ? 'إضافة حزمة' : 'Add Bundle'} | BundleCreator.svelte:219 | ❌ |
| Desktop | BundleCreator | DELETE: removeBundle(bundleIndex)} title={isRTL ? ' | BundleCreator.svelte:235 | ❌ |
| Desktop | BundleCreator | CREATE: addProductToBundle(bundleIndex)} >  | BundleCreator.svelte:271 | ❌ |
| Desktop | BundleCreator | DELETE: removeProductFromBundle(bundleIndex, productIndex) | BundleCreator.svelte:315 | ❌ |
| Desktop | BundleCreator | OTHER: openPricingModal(bundleIndex)} disabled={bu | BundleCreator.svelte:331 | ❌ |
| Desktop | BundleCreator | OTHER: ✕ | BundleCreator.svelte:358 | ❌ |
| Desktop | BundleCreator | OTHER: {isRTL ? 'إلغاء' : 'Cancel'} | BundleCreator.svelte:399 | ❌ |
| Desktop | BundleCreator | SAVE: {isRTL ? 'حفظ' : 'Save'} | BundleCreator.svelte:402 | ❌ |
| Desktop | CategoriesManager | CREATE: ➕ Create Category | CategoriesManager.svelte:205 | ❌ |
| Desktop | CategoriesManager | CREATE: Create First Category | CategoriesManager.svelte:220 | ❌ |
| Desktop | CategoriesManager | OTHER: toggleActive(category.id, category.is_active)}  | CategoriesManager.svelte:266 | ❌ |
| Desktop | CategoriesManager | EDIT: openEditCategory(category)} title="Edit | CategoriesManager.svelte:277 | ❌ |
| Desktop | CategoriesManager | DELETE: deleteCategory(category.id, category.name_en)}  | CategoriesManager.svelte:284 | ❌ |
| Desktop | CustomerAccountRecoveryManager | CREATE: {loading ? ($_('admin.loading') || 'Loading...') : | CustomerAccountRecoveryManager.svelte:310 | ❌ |
| Desktop | CustomerAccountRecoveryManager | SAVE: { const whatsapp = getRequestWhatsA | CustomerAccountRecoveryManager.svelte:376 | ❌ |
| Desktop | CustomerAccountRecoveryManager | CREATE: { const customerId = getRequestCust | CustomerAccountRecoveryManager.svelte:389 | ❌ |
| Desktop | CustomerAccountRecoveryManager | OTHER: markAsResolved(request.id)} >  | CustomerAccountRecoveryManager.svelte:403 | ❌ |
| Desktop | CustomerAccountRecoveryManager | CREATE: { const customerId = getRequestCusto | CustomerAccountRecoveryManager.svelte:453 | ❌ |
| Desktop | CustomerAccountRecoveryManager | OTHER: markAsResolved(request.id)} >  | CustomerAccountRecoveryManager.svelte:463 | ❌ |
| Desktop | CustomerAccountRecoveryManager | OTHER: × | CustomerAccountRecoveryManager.svelte:489 | ❌ |
| Desktop | CustomerAccountRecoveryManager | CREATE: { navigator.clipboard.writeText(newAccess | CustomerAccountRecoveryManager.svelte:501 | ❌ |
| Desktop | CustomerAccountRecoveryManager | CREATE: { shareViaWhatsApp(selectedCustomer, newAc | CustomerAccountRecoveryManager.svelte:516 | ❌ |
| Desktop | CustomerAccountRecoveryManager | OTHER: {$_('admin.customerAccountRecoveryManager.close')  | CustomerAccountRecoveryManager.svelte:525 | ❌ |
| Desktop | CustomerMaster | OTHER: 🔐 {t('admin.accountRecovery') || 'Acco | CustomerMaster.svelte:543 | ❌ |
| Desktop | CustomerMaster | VIEW: openLocationModal(customer)}>📍 {t('admin.viewLoca | CustomerMaster.svelte:632 | ❌ |
| Desktop | CustomerMaster | APPROVE: openApprovalModal(customer, "approve")}  | CustomerMaster.svelte:638 | ❌ |
| Desktop | CustomerMaster | APPROVE: openApprovalModal(customer, "reject")}  | CustomerMaster.svelte:644 | ❌ |
| Desktop | CustomerMaster | OTHER: ✕ | CustomerMaster.svelte:687 | ❌ |
| Desktop | CustomerMaster | OTHER: {#if isGeneratingCode} {t('admi | CustomerMaster.svelte:712 | ❌ |
| Desktop | CustomerMaster | OTHER: 📱 {t('admin.shareViaWhatsApp') || 'Share Login vi | CustomerMaster.svelte:743 | ❌ |
| Desktop | CustomerMaster | OTHER: {t('admin.done') || 'Done'} | CustomerMaster.svelte:746 | ❌ |
| Desktop | CustomerMaster | OTHER: {t('admin.cancel') || 'Cancel'} | CustomerMaster.svelte:751 | ❌ |
| Desktop | CustomerMaster | APPROVE: {#if isSavingApproval} {t('admin.sa | CustomerMaster.svelte:754 | ❌ |
| Desktop | CustomerMaster | OTHER: ✕ | CustomerMaster.svelte:777 | ❌ |
| Desktop | CustomerMaster | EDIT: currentEditingLocation = 1}> 📍 {t('a | CustomerMaster.svelte:786 | ❌ |
| Desktop | CustomerMaster | EDIT: currentEditingLocation = 2}> 📍 {t('a | CustomerMaster.svelte:789 | ❌ |
| Desktop | CustomerMaster | EDIT: currentEditingLocation = 3}> 📍 {t('a | CustomerMaster.svelte:792 | ❌ |
| Desktop | CustomerMaster | OTHER: {t('admin.close') || 'Close'} | CustomerMaster.svelte:877 | ❌ |
| Desktop | DeliverySettings | OTHER: activeTab = 'tiers'} > 💰 Fee Tiers | DeliverySettings.svelte:231 | ❌ |
| Desktop | DeliverySettings | OTHER: activeTab = 'settings'} > ⚙️ General Settin | DeliverySettings.svelte:238 | ❌ |
| Desktop | DeliverySettings | OTHER: activeTab = 'branches'} > 🏢 Branch Service | DeliverySettings.svelte:245 | ❌ |
| Desktop | DeliverySettings | CREATE: openTierModal()} disabled={!tierBranchId}>  | DeliverySettings.svelte:268 | ❌ |
| Desktop | DeliverySettings | EDIT: openTierModal(tier)}>✏️ | DeliverySettings.svelte:316 | ❌ |
| Desktop | DeliverySettings | DELETE: deleteTier(tier)}>🗑️ | DeliverySettings.svelte:317 | ❌ |
| Desktop | DeliverySettings | SAVE: 💾 Save Settings | DeliverySettings.svelte:333 | ❌ |
| Desktop | DeliverySettings | OTHER: selectBranch(branch)} > {branch.b | DeliverySettings.svelte:348 | ❌ |
| Desktop | DeliverySettings | OTHER: toggleBranchService(branch.branch_id, 'delivery')} | DeliverySettings.svelte:477 | ❌ |
| Desktop | DeliverySettings | OTHER: toggleBranchService(branch.branch_id, 'pickup')}  | DeliverySettings.svelte:485 | ❌ |
| Desktop | DeliverySettings | OTHER: ✕ | DeliverySettings.svelte:508 | ❌ |
| Desktop | DeliverySettings | OTHER: Cancel | DeliverySettings.svelte:556 | ❌ |
| Desktop | DeliverySettings | CREATE: {isEditMode ? 'Update' : 'Add'} Tier | DeliverySettings.svelte:557 | ❌ |
| Desktop | HomePageScreenManager | UPLOAD: 🎥 Video Templates Manage  | HomePageScreenManager.svelte:65 | ❌ |
| Desktop | HomePageScreenManager | UPLOAD: 🖼️ Image Templates Manage | HomePageScreenManager.svelte:85 | ❌ |
| Desktop | ImageTemplatesManager | VIEW: previewImage(slot)}> Preview | ImageTemplatesManager.svelte:298 | ❌ |
| Desktop | ImageTemplatesManager | EDIT: saveSlot(slot.slot_number)} disabled={slot | ImageTemplatesManager.svelte:397 | ❌ |
| Desktop | ImageTemplatesManager | OTHER: toggleActive(slot.slot_number)} disabled= | ImageTemplatesManager.svelte:406 | ❌ |
| Desktop | ImageTemplatesManager | VIEW: × | ImageTemplatesManager.svelte:428 | ❌ |
| Desktop | OfferForm | CREATE: + {isRTL ? 'اختيار المنتجات' : 'Select Prod | OfferForm.svelte:767 | ❌ |
| Desktop | OfferForm | OTHER: {isRTL ? 'السابق' : 'Previous'} | OfferForm.svelte:943 | ❌ |
| Desktop | OfferForm | OTHER: {isRTL ? 'إلغاء' : 'Cancel'} | OfferForm.svelte:947 | ❌ |
| Desktop | OfferForm | OTHER: {isRTL ? 'التالي' : 'Next'} | OfferForm.svelte:951 | ❌ |
| Desktop | OfferForm | CREATE: {#if loading} {/if} {isRTL ? (edi | OfferForm.svelte:955 | ❌ |
| Desktop | OfferManagement | OTHER: 🔄 {texts.refresh} | OfferManagement.svelte:970 | ❌ |
| Desktop | OfferManagement | CREATE: createOfferWithType('percentage')}> 📊 {l | OfferManagement.svelte:973 | ❌ |
| Desktop | OfferManagement | CREATE: createOfferWithType('special_price')}> 💰 | OfferManagement.svelte:976 | ❌ |
| Desktop | OfferManagement | CREATE: createOfferWithType('bogo')}> 🎁 {locale  | OfferManagement.svelte:979 | ❌ |
| Desktop | OfferManagement | CREATE: createOfferWithType('bundle')}> 📦 {local | OfferManagement.svelte:982 | ❌ |
| Desktop | OfferManagement | CREATE: createOfferWithType('cart')}> 🛒 {locale  | OfferManagement.svelte:985 | ❌ |
| Desktop | OfferManagement | CREATE: ➕ {texts.createNew} | OfferManagement.svelte:1080 | ❌ |
| Desktop | OfferManagement | EDIT: editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1147 | ❌ |
| Desktop | OfferManagement | OTHER: toggleOfferStatus(offer.id, offer.is_active)}  | OfferManagement.svelte:1150 | ❌ |
| Desktop | OfferManagement | DELETE: deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1158 | ❌ |
| Desktop | OfferManagement | EDIT: editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1217 | ❌ |
| Desktop | OfferManagement | OTHER: toggleOfferStatus(offer.id, offer.is_active)}  | OfferManagement.svelte:1220 | ❌ |
| Desktop | OfferManagement | DELETE: deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1228 | ❌ |
| Desktop | OfferManagement | EDIT: editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1288 | ❌ |
| Desktop | OfferManagement | OTHER: toggleOfferStatus(offer.id, offer.is_active)}  | OfferManagement.svelte:1291 | ❌ |
| Desktop | OfferManagement | DELETE: deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1299 | ❌ |
| Desktop | OfferManagement | EDIT: editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1405 | ❌ |
| Desktop | OfferManagement | VIEW: viewAnalytics(offer.id)} title={texts.analytics}>  | OfferManagement.svelte:1408 | ❌ |
| Desktop | OfferManagement | DELETE: deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1411 | ❌ |
| Desktop | OfferTypeSelector | OTHER: selectType(offerType.type)} > {offerType. | OfferTypeSelector.svelte:68 | ❌ |
| Desktop | OrdersManager | DELETE: {t('orders.filters.clear', 'Clear')} | OrdersManager.svelte:426 | ❌ |
| Desktop | OrdersManager | OTHER: action-btn | OrdersManager.svelte:488 | ❌ |
| Desktop | ProductsManager | OTHER: 📦 Manage Products | ProductsManager.svelte:193 | ❌ |
| Desktop | ProductsManager | OTHER: 🏷️ Manage Categories | ProductsManager.svelte:197 | ❌ |
| Desktop | ProductsManager | OTHER: selectCardType('active')}> ✅ { | ProductsManager.svelte:210 | ❌ |
| Desktop | ProductsManager | OTHER: selectCardType('minimumAlert')}> ⚠️  | ProductsManager.svelte:217 | ❌ |
| Desktop | ProductsManager | OTHER: selectCardType('minimumQty')}> 🔴  | ProductsManager.svelte:224 | ❌ |
| Desktop | ProductsManagerNew | OTHER: 📦 Manage Products | ProductsManagerNew.svelte:59 | ❌ |
| Desktop | ProductsManagerNew | OTHER: 🏷️ Manage Categories | ProductsManagerNew.svelte:63 | ❌ |
| Desktop | TaxManager | CREATE: ➕ Add Tax Category | TaxManager.svelte:112 | ❌ |
| Desktop | TaxManager | CREATE: Create First Tax Category | TaxManager.svelte:128 | ❌ |
| Desktop | TaxManager | OTHER: toggleActive(tax)} > {tax.is_ac | TaxManager.svelte:150 | ❌ |
| Desktop | TaxManager | DELETE: deleteTax(tax)} title="Delete"  | TaxManager.svelte:161 | ❌ |
| Desktop | TierManager | CREATE: + {isRTL ? 'إضافة مستوى' : 'Add Tier'} | TierManager.svelte:58 | ❌ |
| Desktop | TierManager | DELETE: removeTier(index)} title={isRTL ? 'حذف ال | TierManager.svelte:134 | ❌ |
| Desktop | VideoTemplatesManager | VIEW: previewVideo(slot)}> Preview | VideoTemplatesManager.svelte:336 | ❌ |
| Desktop | VideoTemplatesManager | EDIT: saveSlot(slot.slot_number)} disabled={slot | VideoTemplatesManager.svelte:435 | ❌ |
| Desktop | VideoTemplatesManager | OTHER: toggleActive(slot.slot_number)} disabled= | VideoTemplatesManager.svelte:444 | ❌ |
| Desktop | VideoTemplatesManager | VIEW: × | VideoTemplatesManager.svelte:466 | ❌ |
| Cashier | CashierInterface | OTHER: 🎁 {t('coupon.redeemCoupon') || 'Redeem Coupo | CashierInterface.svelte:84 | ❌ |
| Cashier | CashierInterface | OTHER: {$currentLocale === 'en' ? 'العربية' : 'English'} | CashierInterface.svelte:91 | ❌ |
| Cashier | CashierInterface | OTHER: {t('auth.logout') || 'Logout'} | CashierInterface.svelte:99 | ❌ |
| Cashier | CouponRedemption | OTHER: {#if loading} {t('common.validating | CouponRedemption.svelte:417 | ❌ |
| Cashier | CouponRedemption | OTHER: {printDisabled ? (t('common.printed') || 'Printed' | CouponRedemption.svelte:484 | ❌ |
| Cashier | CouponRedemption | CREATE: {t('coupon.newRedemption') || 'New Redemption'} | CouponRedemption.svelte:492 | ❌ |
| Cashier | CouponRedemption | OTHER: {t('common.tryAgain') || 'Try Again'} | CouponRedemption.svelte:507 | ❌ |
| Other | +page | OTHER: ✕ | +page.svelte:722 | ❌ |
| Other | +page | VIEW: 📺 Show Advertisements | +page.svelte:1093 | ❌ |
| Other | +page | OTHER: 🛒 {texts.shopNow} | +page.svelte:1107 | ❌ |
| Other | +page | OTHER: {texts.continueShopping} | +page.svelte:344 | ❌ |
| Other | +page | DELETE: removeItem(item)}> ✕ | +page.svelte:410 | ❌ |
| Other | +page | DELETE: removeItem(item)}> ✕ | +page.svelte:456 | ❌ |
| Other | +page | EDIT: updateItemQuantity(item, -1)} > | +page.svelte:495 | ❌ |
| Other | +page | EDIT: updateItemQuantity(item, 1)} >  | +page.svelte:502 | ❌ |
| Other | +page | DELETE: removeItem(item)}> ✕ | +page.svelte:522 | ❌ |
| Other | +page | DELETE: {texts.clearCart} | +page.svelte:597 | ❌ |
| Other | +page | OTHER: {texts.checkout} | +page.svelte:600 | ❌ |
| Other | +page | OTHER: {texts.shopNow} | +page.svelte:1147 | ❌ |
| Other | +page | DELETE: removeItem(item)}> 🗑️ | +page.svelte:1218 | ❌ |
| Other | +page | DELETE: removeItem(item)}> 🗑️ | +page.svelte:1264 | ❌ |
| Other | +page | OTHER: decreaseQuantity(item)} >− | +page.svelte:1311 | ❌ |
| Other | +page | OTHER: increaseQuantity(item)} >+ | +page.svelte:1316 | ❌ |
| Other | +page | DELETE: removeItem(item)}> 🗑️ | +page.svelte:1334 | ❌ |
| Other | +page | CREATE: { // Find first empty slot  | +page.svelte:1457 | ❌ |
| Other | +page | VIEW: { showSlotSelector = true;  | +page.svelte:1473 | ❌ |
| Other | +page | OTHER: {texts.cancelOrder} | +page.svelte:1532 | ❌ |
| Other | +page | SAVE: {texts.confirmOrder} | +page.svelte:1535 | ❌ |
| Other | +page | CREATE: 🛒 {texts.newOrder} | +page.svelte:1543 | ❌ |
| Other | +page | OTHER: 📦 {texts.trackOrder} | +page.svelte:1546 | ❌ |
| Other | +page | VIEW: { showSlotSelector = false; }}>✕ | +page.svelte:1580 | ❌ |
| Other | +page | VIEW: { const slotNumber = parseInt(loc.k | +page.svelte:1584 | ❌ |
| Other | +page | OTHER: ✕ | +page.svelte:1618 | ❌ |
| Other | +page | OTHER: {currentLanguage === 'ar' ? 'إلغاء' : 'Cancel'} | +page.svelte:1646 | ❌ |
| Other | +page | SAVE: {savingLocation ? (currentLanguage === 'ar' ? 'جار | +page.svelte:1647 | ❌ |
| Other | +page | VIEW: { showMapPopup = false; mapPopupLocation = null; } | +page.svelte:1661 | ❌ |
| Other | +page | OTHER: {t('common.back')} | +page.svelte:66 | ❌ |
| Other | +page | OTHER: { switchLocale($currentLocale === 'ar' ? ' | +page.svelte:81 | ❌ |
| Other | +page | OTHER: {texts.markAllRead} | +page.svelte:144 | ❌ |
| Other | +page | OTHER: markAsRead(notification.id)} >  | +page.svelte:159 | ❌ |
| Other | +page | OTHER: ← {texts.backToProfile} | +page.svelte:170 | ❌ |
| Other | +page | OTHER: 🛒 {texts.startShopping} | +page.svelte:186 | ❌ |
| Other | +page | VIEW: {texts.viewDetails} | +page.svelte:221 | ❌ |
| Other | +page | OTHER: ← {texts.backToFinalize} | +page.svelte:63 | ❌ |
| Other | +page | OTHER: {texts.completeOrder} | +page.svelte:103 | ❌ |
| Other | +page | VIEW: (showCategoryMenu = true)} title={texts.categories | +page.svelte:687 | ❌ |
| Other | +page | OTHER: selectCategory(category.id)} type="bu | +page.svelte:692 | ❌ |
| Other | +page | VIEW: (showSearch = !showSearch)} aria-label="Search" ti | +page.svelte:705 | ❌ |
| Other | +page | CREATE: addBogoToCart(bogoOffer)} disabled={ | +page.svelte:817 | ❌ |
| Other | +page | CREATE: addBundleToCart(bundleOffer)} disabl | +page.svelte:907 | ❌ |
| Other | +page | CREATE: addToCart(product)} disabled={out} type="button" a | +page.svelte:1042 | ❌ |
| Other | +page | EDIT: updateQuantity(product, -1)} aria-label="Decrease" | +page.svelte:1045 | ❌ |
| Other | +page | EDIT: updateQuantity(product, 1)} aria-label="Increase"  | +page.svelte:1047 | ❌ |
| Other | +page | VIEW: (showSearch = false)} aria-label={texts.close}>✕ | +page.svelte:1067 | ❌ |
| Other | +page | VIEW: (showCategoryMenu = false)} aria-label={texts.clos | +page.svelte:1076 | ❌ |
| Other | +page | OTHER: selectCategory(category.id)}> {curr | +page.svelte:1080 | ❌ |
| Other | +page | VIEW: { showBogoModal = false; selectedBogoOffer = null; | +page.svelte:1095 | ❌ |
| Other | +page | CREATE: { const newLanguage = currentLanguage = | +page.svelte:500 | ❌ |
| Other | +page | SAVE: selectLocation(loc.key)}> {inde | +page.svelte:566 | ❌ |
| Other | +page | EDIT: openLocationPicker(index + 1)} title={texts.editLo | +page.svelte:570 | ❌ |
| Other | +page | CREATE: openLocationPicker(slotNum)}> ➕  | +page.svelte:586 | ❌ |
| Other | +page | OTHER: goto('/customer-interface/track-order')}>  | +page.svelte:612 | ❌ |
| Other | +page | OTHER: goto('/customer-interface/orders')}> 📋 | +page.svelte:616 | ❌ |
| Other | +page | OTHER: 💬 {texts.chatSupport} › | +page.svelte:629 | ❌ |
| Other | +page | OTHER: 📞 {texts.callSupport} › | +page.svelte:633 | ❌ |
| Other | +page | OTHER: 🚪 {texts.logout} | +page.svelte:643 | ❌ |
| Other | +page | OTHER: ✕ | +page.svelte:655 | ❌ |
| Other | +page | OTHER: {texts.cancel} | +page.svelte:683 | ❌ |
| Other | +page | SAVE: {savingLocation ? texts.saving : texts.saveLocatio | +page.svelte:684 | ❌ |
| Other | +page | OTHER: العربية | +page.svelte:27 | ❌ |
| Other | +page | OTHER: chooseService(branch, 'delivery')}  | +page.svelte:229 | ❌ |
| Other | +page | OTHER: chooseService(branch, 'pickup')} ty | +page.svelte:259 | ❌ |
| Other | +page | OTHER: ← {texts.backToHome} | +page.svelte:140 | ❌ |
| Other | +page | OTHER: openWhatsAppSupport()}> {texts.openWhatsA | +page.svelte:155 | ❌ |
| Other | +page | SEND: openEmail()}> {texts.sendEmail} | +page.svelte:166 | ❌ |
| Other | +page | OTHER: openWhatsAppSupport(texts.orderHelp)}> 📦 | +page.svelte:177 | ❌ |
| Other | +page | OTHER: openWhatsAppSupport(texts.accountHelp)}>  | +page.svelte:183 | ❌ |
| Other | +page | OTHER: openWhatsAppSupport(texts.productHelp)}>  | +page.svelte:189 | ❌ |
| Other | +page | OTHER: openWhatsAppSupport(texts.technicalHelp)}>  | +page.svelte:195 | ❌ |
| Other | +page | OTHER: openWhatsAppSupport(texts.reportProblem)}>  | +page.svelte:206 | ❌ |
| Other | +page | OTHER: openWhatsAppSupport(texts.requestRefund)}>  | +page.svelte:211 | ❌ |
| Other | +page | OTHER: 📍 {texts.trackOrder} | +page.svelte:216 | ❌ |
| Other | +page | CREATE: openWhatsAppSupport(texts.changeAddress)}>  | +page.svelte:221 | ❌ |
| Other | +page | OTHER: ← {texts.backToProfile} | +page.svelte:136 | ❌ |
| Other | +page | SAVE: {loading ? '...' : `🔍 ${texts.trackButton}`} | +page.svelte:154 | ❌ |
| Other | BottomCartBar | OTHER: {texts.checkout} | BottomCartBar.svelte:352 | ❌ |
| Other | BottomCartBar | OTHER: × | BottomCartBar.svelte:363 | ❌ |
| Other | BottomCartBar | OTHER: {currentLanguage === 'ar' ? 'إغلاق' : 'Close'} | BottomCartBar.svelte:381 | ❌ |
| Other | FeaturedOffers | CREATE: { // Dispatch event to parent to open of | FeaturedOffers.svelte:242 | ❌ |
| Other | FeaturedOffers | OTHER: prevSlide | FeaturedOffers.svelte:262 | ❌ |
| Other | FeaturedOffers | OTHER: nextSlide | FeaturedOffers.svelte:271 | ❌ |
| Other | FeaturedOffers | OTHER: goToSlide(index)} aria-label="Go to slide { | FeaturedOffers.svelte:287 | ❌ |
| Other | OfferDetailModal | OTHER: onClose | OfferDetailModal.svelte:87 | ❌ |
| Other | OfferDetailModal | OTHER: {getTranslation('offers.modal.shopNow')} | OfferDetailModal.svelte:277 | ❌ |
| Desktop | ActiveFinesView | OTHER: Refresh | ActiveFinesView.svelte:257 | ❌ |
| Desktop | ActiveFinesView | VIEW: viewWarningDetails(fine)} class="action- | ActiveFinesView.svelte:380 | ❌ |
| Desktop | ActiveFinesView | OTHER: openPaymentModal(fine)} class="action-bt | ActiveFinesView.svelte:390 | ❌ |
| Desktop | ActiveFinesView | OTHER: goToPage(currentPage - 1)} disabled={current | ActiveFinesView.svelte:418 | ❌ |
| Desktop | ActiveFinesView | OTHER: goToPage(i + 1)} class="pagination-btn {cur | ActiveFinesView.svelte:427 | ❌ |
| Desktop | ActiveFinesView | OTHER: goToPage(currentPage + 1)} disabled={current | ActiveFinesView.svelte:435 | ❌ |
| Desktop | ActiveFinesView | OTHER: closePaymentModal | ActiveFinesView.svelte:453 | ❌ |
| Desktop | ActiveFinesView | OTHER: Cancel | ActiveFinesView.svelte:498 | ❌ |
| Desktop | ActiveFinesView | SAVE: {#if processingPayment} Processing...  | ActiveFinesView.svelte:501 | ❌ |
| Desktop | AddOfferDialog | CREATE: {isLoading ? (isEditing ? 'Updating...' : 'Adding. | AddOfferDialog.svelte:450 | ❌ |
| Desktop | AdManager | OTHER: 🖼️ Home Page Screen Manager Man | AdManager.svelte:42 | ❌ |
| Desktop | AdminReadStatusModal | OTHER: 🔄 Refresh | AdminReadStatusModal.svelte:164 | ❌ |
| Desktop | AdminReadStatusModal | OTHER: Retry | AdminReadStatusModal.svelte:175 | ❌ |
| Desktop | AdminReadStatusModal | VIEW: viewMode = 'by-notification'} > 📢 By N | AdminReadStatusModal.svelte:189 | ❌ |
| Desktop | AdminReadStatusModal | VIEW: viewMode = 'by-user'} > 👤 By User | AdminReadStatusModal.svelte:195 | ❌ |
| Desktop | ApprovalCenter | ASSIGN: { activeSection = 'approvals'; filterRequisitions( | ApprovalCenter.svelte:1192 | ❌ |
| Desktop | ApprovalCenter | OTHER: { activeSection = 'my_requests'; filterRequisition | ApprovalCenter.svelte:1201 | ❌ |
| Desktop | ApprovalCenter | EDIT: ✅ Approve {selectedItems.size} Item(s) | ApprovalCenter.svelte:1301 | ❌ |
| Desktop | ApprovalCenter | CREATE: { selectedItems = new Set(); selectAll = false; }} | ApprovalCenter.svelte:1304 | ❌ |
| Desktop | ApprovalCenter | OTHER: ☑️ Mark All | ApprovalCenter.svelte:1308 | ❌ |
| Desktop | ApprovalCenter | OTHER: 🔄 Refresh | ApprovalCenter.svelte:1312 | ❌ |
| Desktop | ApprovalCenter | VIEW: openDetail(req)}> 👁️ View | ApprovalCenter.svelte:1397 | ❌ |
| Desktop | ApprovalCenter | VIEW: openDetail(req)}> 👁️ View | ApprovalCenter.svelte:1442 | ❌ |
| Desktop | ApprovalCenter | VIEW: openDetail(req)}> 👁️ View | ApprovalCenter.svelte:1482 | ❌ |
| Desktop | ApprovalCenter | OTHER: × | ApprovalCenter.svelte:1502 | ❌ |
| Desktop | ApprovalCenter | APPROVE: showApprovalConfirm(selectedRequisition.id)}  | ApprovalCenter.svelte:1870 | ❌ |
| Desktop | ApprovalCenter | APPROVE: showRejectionConfirm(selectedRequisition.id)}  | ApprovalCenter.svelte:1878 | ❌ |
| Desktop | ApprovalCenter | OTHER: Close | ApprovalCenter.svelte:1892 | ❌ |
| Desktop | ApprovalCenter | SAVE: Cancel | ApprovalCenter.svelte:1928 | ❌ |
| Desktop | ApprovalCenter | APPROVE: {confirmAction === 'approve' ? 'Approve' : 'Reject | ApprovalCenter.svelte:1931 | ❌ |
| Desktop | ApprovalCenter | APPROVE: × | ApprovalCenter.svelte:1951 | ❌ |
| Desktop | ApprovalCenter | APPROVE: Cancel | ApprovalCenter.svelte:1964 | ❌ |
| Desktop | ApprovalCenter | APPROVE: {#if isProcessing} Processing... {:e | ApprovalCenter.svelte:1967 | ❌ |
| Desktop | ApprovalMask | SEND: Send | ApprovalMask.svelte:35 | ❌ |
| Desktop | ApprovalPermissionsManager | SAVE: saveUserPermissions(user)} disabled={sa | ApprovalPermissionsManager.svelte:483 | ❌ |
| Desktop | ApproverListModal | OTHER: closeModal | ApproverListModal.svelte:175 | ❌ |
| Desktop | ApproverListModal | DELETE: searchQuery = ''}> | ApproverListModal.svelte:241 | ❌ |
| Desktop | ApproverListModal | OTHER: Cancel | ApproverListModal.svelte:313 | ❌ |
| Desktop | ApproverListModal | APPROVE: {#if submitting}  | ApproverListModal.svelte:316 | ❌ |
| Desktop | AssignPositions | DELETE: searchTerm = ''} title="Clear search"> × | AssignPositions.svelte:358 | ❌ |
| Desktop | BiometricData | CREATE: {t('common.retry')} | BiometricData.svelte:633 | ❌ |
| Desktop | BiometricData | EXPORT: 📊 {t('hr.exportToExcel')} | BiometricData.svelte:642 | ❌ |
| Desktop | BiometricData | OTHER: 🔄 | BiometricData.svelte:691 | ❌ |
| Desktop | BiometricData | CREATE: loadDataOnDemand('specific', specificDate)} disabl | BiometricData.svelte:769 | ❌ |
| Desktop | BiometricData | CREATE: loadDataOnDemand('range', startDate, endDate)} dis | BiometricData.svelte:790 | ❌ |
| Desktop | BiometricData | DELETE: { searchQuery = ''; }}> {t('hr.clearSearch | BiometricData.svelte:822 | ❌ |
| Desktop | BiometricData | DELETE: { selectedBranch = ''; selectedDate = ''; }}>  | BiometricData.svelte:851 | ❌ |
| Desktop | BiometricExport | EXPORT: {#if exporting} {t('hr.exporting')} | BiometricExport.svelte:191 | ❌ |
| Desktop | BranchMaster | CREATE: + Create Branch | BranchMaster.svelte:207 | ❌ |
| Desktop | BranchMaster | OTHER: Retry | BranchMaster.svelte:217 | ❌ |
| Desktop | BranchMaster | EDIT: openEditPopup(branch)} disabled={isLoading}>  | BranchMaster.svelte:276 | ❌ |
| Desktop | BranchMaster | DELETE: deleteBranch(branch.id)} disabled={isLoading}>  | BranchMaster.svelte:279 | ❌ |
| Desktop | BranchMaster | CREATE: + Create Your First Branch | BranchMaster.svelte:292 | ❌ |
| Desktop | BranchMaster | CREATE: × | BranchMaster.svelte:307 | ❌ |
| Desktop | BranchMaster | CREATE: Cancel | BranchMaster.svelte:390 | ❌ |
| Desktop | BranchMaster | SAVE: Save | BranchMaster.svelte:393 | ❌ |
| Desktop | BranchMaster | EDIT: × | BranchMaster.svelte:409 | ❌ |
| Desktop | BranchMaster | EDIT: Cancel | BranchMaster.svelte:492 | ❌ |
| Desktop | BranchMaster | EDIT: Update | BranchMaster.svelte:495 | ❌ |
| Desktop | BundleCreator | CREATE: + {isRTL ? 'إضافة حزمة' : 'Add Bundle'} | BundleCreator.svelte:219 | ❌ |
| Desktop | BundleCreator | DELETE: removeBundle(bundleIndex)} title={isRTL ? ' | BundleCreator.svelte:235 | ❌ |
| Desktop | BundleCreator | CREATE: addProductToBundle(bundleIndex)} >  | BundleCreator.svelte:271 | ❌ |
| Desktop | BundleCreator | DELETE: removeProductFromBundle(bundleIndex, productIndex) | BundleCreator.svelte:315 | ❌ |
| Desktop | BundleCreator | OTHER: openPricingModal(bundleIndex)} disabled={bu | BundleCreator.svelte:331 | ❌ |
| Desktop | BundleCreator | OTHER: ✕ | BundleCreator.svelte:358 | ❌ |
| Desktop | BundleCreator | OTHER: {isRTL ? 'إلغاء' : 'Cancel'} | BundleCreator.svelte:399 | ❌ |
| Desktop | BundleCreator | SAVE: {isRTL ? 'حفظ' : 'Save'} | BundleCreator.svelte:402 | ❌ |
| Desktop | ButtonAccessControl | DELETE: searchUsername = ''} title="Clear search"  | ButtonAccessControl.svelte:403 | ❌ |
| Desktop | ButtonAccessControl | OTHER: ← Previous | ButtonAccessControl.svelte:530 | ❌ |
| Desktop | ButtonAccessControl | OTHER: = totalUsers || usersLoading} on:click={nextPa | ButtonAccessControl.svelte:543 | ❌ |
| Desktop | ButtonAccessControl | OTHER: Proceed to Step 2 ✓ | ButtonAccessControl.svelte:551 | ❌ |
| Desktop | ButtonAccessControl | OTHER: ← Back to Step 1 | ButtonAccessControl.svelte:679 | ❌ |
| Desktop | ButtonAccessControl | SAVE: 💾 Save Changes ({selectedNonPermitted.size + sele | ButtonAccessControl.svelte:682 | ❌ |
| Desktop | ButtonGenerator | OTHER: {loading && activeSection === 'code' ? 'Generating | ButtonGenerator.svelte:400 | ❌ |
| Desktop | ButtonGenerator | OTHER: {loading && activeSection === 'database' ? 'Genera | ButtonGenerator.svelte:456 | ❌ |
| Desktop | ButtonGenerator | OTHER: ✕ | ButtonGenerator.svelte:516 | ❌ |
| Desktop | ButtonGenerator | CREATE: {loading ? 'Adding...' : '✓ Add Buttons'} | ButtonGenerator.svelte:539 | ❌ |
| Desktop | ButtonGenerator | EDIT: {loading ? 'Updating...' : '🔄 Update Permissions' | ButtonGenerator.svelte:546 | ❌ |
| Desktop | ButtonGenerator | OTHER: Close | ButtonGenerator.svelte:553 | ❌ |
| Desktop | CampaignManager | CREATE: ➕ {t('coupon.createCampaign')} | CampaignManager.svelte:298 | ❌ |
| Desktop | CampaignManager | OTHER: 🔄 {t('coupon.generate')} | CampaignManager.svelte:357 | ❌ |
| Desktop | CampaignManager | SAVE: {loading ? t('coupon.saving') : t('coupon.save')} | CampaignManager.svelte:445 | ❌ |
| Desktop | CampaignManager | OTHER: {t('coupon.cancel')} | CampaignManager.svelte:453 | ❌ |
| Desktop | CampaignManager | EDIT: openEditForm(campaign)} class="flex-1 p | CampaignManager.svelte:510 | ❌ |
| Desktop | CampaignManager | OTHER: toggleStatus(campaign)} class="flex-1 p | CampaignManager.svelte:516 | ❌ |
| Desktop | CampaignManager | DELETE: handleDelete(campaign)} class="px-3 py- | CampaignManager.svelte:522 | ❌ |
| Desktop | CategoriesManager | CREATE: ➕ Create Category | CategoriesManager.svelte:205 | ❌ |
| Desktop | CategoriesManager | CREATE: Create First Category | CategoriesManager.svelte:220 | ❌ |
| Desktop | CategoriesManager | OTHER: toggleActive(category.id, category.is_active)}  | CategoriesManager.svelte:266 | ❌ |
| Desktop | CategoriesManager | EDIT: openEditCategory(category)} title="Edit | CategoriesManager.svelte:277 | ❌ |
| Desktop | CategoriesManager | DELETE: deleteCategory(category.id, category.name_en)}  | CategoriesManager.svelte:284 | ❌ |
| Desktop | CategoryManager | CREATE: openParentModal()}> ➕ Create Parent Cate | CategoryManager.svelte:310 | ❌ |
| Desktop | CategoryManager | CREATE: openSubModal()}> ➕ Create Sub Category | CategoryManager.svelte:314 | ❌ |
| Desktop | CategoryManager | OTHER: { activeTab = 'parent'; searchQuery = ''; handleSe | CategoryManager.svelte:324 | ❌ |
| Desktop | CategoryManager | OTHER: { activeTab = 'sub'; searchQuery = ''; selectedPar | CategoryManager.svelte:330 | ❌ |
| Desktop | CategoryManager | EDIT: openParentModal(category)} title="Edit">  | CategoryManager.svelte:395 | ❌ |
| Desktop | CategoryManager | DELETE: deleteParentCategory(category)} title="Delete">  | CategoryManager.svelte:398 | ❌ |
| Desktop | CategoryManager | EDIT: openSubModal(category)} title="Edit">  | CategoryManager.svelte:441 | ❌ |
| Desktop | CategoryManager | DELETE: deleteSubCategory(category)} title="Delete">  | CategoryManager.svelte:444 | ❌ |
| Desktop | CategoryManager | OTHER: × | CategoryManager.svelte:471 | ❌ |
| Desktop | CategoryManager | OTHER: Cancel | CategoryManager.svelte:498 | ❌ |
| Desktop | CategoryManager | CREATE: {isEditMode ? 'Update' : 'Create'} | CategoryManager.svelte:499 | ❌ |
| Desktop | CategoryManager | OTHER: × | CategoryManager.svelte:513 | ❌ |
| Desktop | CategoryManager | OTHER: Cancel | CategoryManager.svelte:550 | ❌ |
| Desktop | CategoryManager | CREATE: {isEditMode ? 'Update' : 'Create'} | CategoryManager.svelte:551 | ❌ |
| Desktop | ClearanceCertificateManager | OTHER: × | ClearanceCertificateManager.svelte:1052 | ❌ |
| Desktop | ClearanceCertificateManager | DELETE: {#if isGenerating}  | ClearanceCertificateManager.svelte:1108 | ❌ |
| Desktop | ClearanceCertificateManager | UPLOAD: {#if isUploading}  | ClearanceCertificateManager.svelte:1150 | ❌ |
| Desktop | ClearanceCertificateManager | OTHER: 🖨️ Print Certificate | ClearanceCertificateManager.svelte:1214 | ❌ |
| Desktop | ClearanceCertificateManager | CREATE: {#if isGenerating}  | ClearanceCertificateManager.svelte:1221 | ❌ |
| Desktop | ClearanceCertificateManager | OTHER: Close | ClearanceCertificateManager.svelte:1344 | ❌ |
| Desktop | ClearTables | OTHER: 🔄 | ClearTables.svelte:115 | ❌ |
| Desktop | ClearTables | DELETE: {#if isClearing} {:else} � | ClearTables.svelte:123 | ❌ |
| Desktop | CommunicationCenter | OTHER: Open Notification Center | CommunicationCenter.svelte:107 | ❌ |
| Desktop | CommunicationCenter | OTHER: 👥 Read Status | CommunicationCenter.svelte:111 | ❌ |
| Desktop | CompletedTasksView | OTHER: ✕ | CompletedTasksView.svelte:426 | ❌ |
| Desktop | CompletedTasksView | OTHER: {isLoadingMore ? 'Loading...' : 'Load More Tasks'} | CompletedTasksView.svelte:503 | ❌ |
| Desktop | ContactManagement | CREATE: openContactForm(employee)} disabled={ | ContactManagement.svelte:418 | ❌ |
| Desktop | ContactManagement | SEND: openWhatsApp(employee)} disabled={is | ContactManagement.svelte:426 | ❌ |
| Desktop | ContactManagement | OTHER: ✕ | ContactManagement.svelte:461 | ❌ |
| Desktop | ContactManagement | OTHER: Cancel | ContactManagement.svelte:512 | ❌ |
| Desktop | ContactManagement | SAVE: {isLoading ? 'Saving...' : 'Save Contact'} | ContactManagement.svelte:515 | ❌ |
| Desktop | ContactManagement-old | EDIT: openContactForm(employee)} disabled={ | ContactManagement-old.svelte:537 | ❌ |
| Desktop | ContactManagement-old | OTHER: ❌ | ContactManagement-old.svelte:562 | ❌ |
| Desktop | ContactManagement-old | OTHER: Cancel | ContactManagement-old.svelte:643 | ❌ |
| Desktop | ContactManagement-old | EDIT: {#if isLoading} Updating... | ContactManagement-old.svelte:651 | ❌ |
| Desktop | CouponDashboard | CREATE: {t('coupon.createFirst') || 'Create Your First Cam | CouponDashboard.svelte:47 | ❌ |
| Desktop | CouponReports | EXPORT: 📥 {t('common.export') || 'Export CSV'} | CouponReports.svelte:147 | ❌ |
| Desktop | CreateDepartment | EDIT: Cancel | CreateDepartment.svelte:194 | ❌ |
| Desktop | CreateDepartment | CREATE: {#if isLoading} {isEditing ? 'Upd | CreateDepartment.svelte:198 | ❌ |
| Desktop | CreateDepartment | CREATE: 🔄 Refresh | CreateDepartment.svelte:215 | ❌ |
| Desktop | CreateDepartment | EDIT: editDepartment(department)} disabled= | CreateDepartment.svelte:253 | ❌ |
| Desktop | CreateDepartment | DELETE: deleteDepartment(department.id)} disa | CreateDepartment.svelte:261 | ❌ |
| Desktop | CreateLevel | EDIT: Cancel | CreateLevel.svelte:356 | ❌ |
| Desktop | CreateLevel | CREATE: {#if isLoading} {isEditing ? 'Upd | CreateLevel.svelte:360 | ❌ |
| Desktop | CreateLevel | OTHER: 🔄 Refresh | CreateLevel.svelte:378 | ❌ |
| Desktop | CreateLevel | OTHER: moveLevel(level.id, 'up')} disabled={is | CreateLevel.svelte:441 | ❌ |
| Desktop | CreateLevel | OTHER: moveLevel(level.id, 'down')} disabled={ | CreateLevel.svelte:449 | ❌ |
| Desktop | CreateLevel | EDIT: editLevel(level)} disabled={isLoading}  | CreateLevel.svelte:460 | ❌ |
| Desktop | CreateLevel | DELETE: deleteLevel(level.id)} disabled={isLoad | CreateLevel.svelte:468 | ❌ |
| Desktop | CreateNotification | OTHER: 📷 Camera | CreateNotification.svelte:489 | ❌ |
| Desktop | CreateNotification | OTHER: {filteredUsers.every(user => user.selected) ? 'Des | CreateNotification.svelte:581 | ❌ |
| Desktop | CreateNotification | OTHER: Reset | CreateNotification.svelte:650 | ❌ |
| Desktop | CreateNotification | SEND: {#if isLoading} Sending... {: | CreateNotification.svelte:653 | ❌ |
| Desktop | CreatePosition | EDIT: Cancel | CreatePosition.svelte:298 | ❌ |
| Desktop | CreatePosition | CREATE: {#if isLoading} {isEditing ? 'Upd | CreatePosition.svelte:302 | ❌ |
| Desktop | CreatePosition | CREATE: 🔄 Refresh | CreatePosition.svelte:319 | ❌ |
| Desktop | CreatePosition | EDIT: editPosition(position)} disabled={isL | CreatePosition.svelte:375 | ❌ |
| Desktop | CreatePosition | DELETE: deletePosition(position.id)} disabled | CreatePosition.svelte:383 | ❌ |
| Desktop | CreateUser | OTHER: 🔄 Retry | CreateUser.svelte:370 | ❌ |
| Desktop | CreateUser | OTHER: 🎲 | CreateUser.svelte:493 | ❌ |
| Desktop | CreateUser | DELETE: { selectedEmployee = null; formData.employeeId = ' | CreateUser.svelte:564 | ❌ |
| Desktop | CreateUser | OTHER: selectEmployee(employee)} >  | CreateUser.svelte:604 | ❌ |
| Desktop | CreateUser | DELETE: × | CreateUser.svelte:706 | ❌ |
| Desktop | CreateUser | OTHER: Cancel | CreateUser.svelte:753 | ❌ |
| Desktop | CreateUser | CREATE: {#if isLoading} Creating User...  | CreateUser.svelte:756 | ❌ |
| Desktop | CustomerAccountRecoveryManager | CREATE: {loading ? ($_('admin.loading') || 'Loading...') : | CustomerAccountRecoveryManager.svelte:310 | ❌ |
| Desktop | CustomerAccountRecoveryManager | SAVE: { const whatsapp = getRequestWhatsA | CustomerAccountRecoveryManager.svelte:376 | ❌ |
| Desktop | CustomerAccountRecoveryManager | CREATE: { const customerId = getRequestCust | CustomerAccountRecoveryManager.svelte:389 | ❌ |
| Desktop | CustomerAccountRecoveryManager | OTHER: markAsResolved(request.id)} >  | CustomerAccountRecoveryManager.svelte:403 | ❌ |
| Desktop | CustomerAccountRecoveryManager | CREATE: { const customerId = getRequestCusto | CustomerAccountRecoveryManager.svelte:453 | ❌ |
| Desktop | CustomerAccountRecoveryManager | OTHER: markAsResolved(request.id)} >  | CustomerAccountRecoveryManager.svelte:463 | ❌ |
| Desktop | CustomerAccountRecoveryManager | OTHER: × | CustomerAccountRecoveryManager.svelte:489 | ❌ |
| Desktop | CustomerAccountRecoveryManager | CREATE: { navigator.clipboard.writeText(newAccess | CustomerAccountRecoveryManager.svelte:501 | ❌ |
| Desktop | CustomerAccountRecoveryManager | CREATE: { shareViaWhatsApp(selectedCustomer, newAc | CustomerAccountRecoveryManager.svelte:516 | ❌ |
| Desktop | CustomerAccountRecoveryManager | OTHER: {$_('admin.customerAccountRecoveryManager.close')  | CustomerAccountRecoveryManager.svelte:525 | ❌ |
| Desktop | CustomerImporter | EXPORT: ⬇️ {t('coupon.downloadTemplate')} | CustomerImporter.svelte:381 | ❌ |
| Desktop | CustomerImporter | OTHER: fileInput?.click()} class="px-8 py-3 bg-g | CustomerImporter.svelte:443 | ❌ |
| Desktop | CustomerImporter | UPLOAD: {importing ? '⏳ ' + t('coupon.importing') : '🚀 '  | CustomerImporter.svelte:527 | ❌ |
| Desktop | CustomerImporter | OTHER: ↻ {t('coupon.reset')} | CustomerImporter.svelte:534 | ❌ |
| Desktop | CustomerImporter | CREATE: showAddNumberModal = true} disabled={!sele | CustomerImporter.svelte:552 | ❌ |
| Desktop | CustomerImporter | DELETE: handleDeleteCustomer(customer.id)} d | CustomerImporter.svelte:596 | ❌ |
| Desktop | CustomerImporter | CREATE: ✅ {t('coupon.add')} | CustomerImporter.svelte:643 | ❌ |
| Desktop | CustomerImporter | CREATE: { showAddNumberModal = false; newNum | CustomerImporter.svelte:649 | ❌ |
| Desktop | CustomerMaster | OTHER: 🔐 {t('admin.accountRecovery') || 'Acco | CustomerMaster.svelte:543 | ❌ |
| Desktop | CustomerMaster | VIEW: openLocationModal(customer)}>📍 {t('admin.viewLoca | CustomerMaster.svelte:632 | ❌ |
| Desktop | CustomerMaster | APPROVE: openApprovalModal(customer, "approve")}  | CustomerMaster.svelte:638 | ❌ |
| Desktop | CustomerMaster | APPROVE: openApprovalModal(customer, "reject")}  | CustomerMaster.svelte:644 | ❌ |
| Desktop | CustomerMaster | OTHER: ✕ | CustomerMaster.svelte:687 | ❌ |
| Desktop | CustomerMaster | OTHER: {#if isGeneratingCode} {t('admi | CustomerMaster.svelte:712 | ❌ |
| Desktop | CustomerMaster | OTHER: 📱 {t('admin.shareViaWhatsApp') || 'Share Login vi | CustomerMaster.svelte:743 | ❌ |
| Desktop | CustomerMaster | OTHER: {t('admin.done') || 'Done'} | CustomerMaster.svelte:746 | ❌ |
| Desktop | CustomerMaster | OTHER: {t('admin.cancel') || 'Cancel'} | CustomerMaster.svelte:751 | ❌ |
| Desktop | CustomerMaster | APPROVE: {#if isSavingApproval} {t('admin.sa | CustomerMaster.svelte:754 | ❌ |
| Desktop | CustomerMaster | OTHER: ✕ | CustomerMaster.svelte:777 | ❌ |
| Desktop | CustomerMaster | EDIT: currentEditingLocation = 1}> 📍 {t('a | CustomerMaster.svelte:786 | ❌ |
| Desktop | CustomerMaster | EDIT: currentEditingLocation = 2}> 📍 {t('a | CustomerMaster.svelte:789 | ❌ |
| Desktop | CustomerMaster | EDIT: currentEditingLocation = 3}> 📍 {t('a | CustomerMaster.svelte:792 | ❌ |
| Desktop | CustomerMaster | OTHER: {t('admin.close') || 'Close'} | CustomerMaster.svelte:877 | ❌ |
| Desktop | DayBudgetPlanner | ASSIGN: 🖨️ Generate Day Schedule | DayBudgetPlanner.svelte:861 | ❌ |
| Desktop | DayBudgetPlanner | OTHER: Select All | DayBudgetPlanner.svelte:1005 | ❌ |
| Desktop | DayBudgetPlanner | DELETE: Clear All | DayBudgetPlanner.svelte:1012 | ❌ |
| Desktop | DayBudgetPlanner | DELETE: {vendorFilter = ''; branchFilter = ''; paymentMeth | DayBudgetPlanner.svelte:1059 | ❌ |
| Desktop | DayBudgetPlanner | ASSIGN: openRescheduleModal(payment, 'vendor')}  | DayBudgetPlanner.svelte:1137 | ❌ |
| Desktop | DayBudgetPlanner | OTHER: openSplitModal(payment, 'vendor')}  | DayBudgetPlanner.svelte:1144 | ❌ |
| Desktop | DayBudgetPlanner | DELETE: {vendorFilter = ''; branchFilter = ''; paymentMeth | DayBudgetPlanner.svelte:1161 | ❌ |
| Desktop | DayBudgetPlanner | ASSIGN: Select All | DayBudgetPlanner.svelte:1181 | ❌ |
| Desktop | DayBudgetPlanner | DELETE: { selectedExpenseSchedules.clear();  | DayBudgetPlanner.svelte:1188 | ❌ |
| Desktop | DayBudgetPlanner | DELETE: {expenseDescriptionFilter = ''; expenseCategoryFil | DayBudgetPlanner.svelte:1249 | ❌ |
| Desktop | DayBudgetPlanner | ASSIGN: openRescheduleModal(expense, 'expense')}  | DayBudgetPlanner.svelte:1314 | ❌ |
| Desktop | DayBudgetPlanner | OTHER: openSplitModal(expense, 'expense')}  | DayBudgetPlanner.svelte:1321 | ❌ |
| Desktop | DayBudgetPlanner | CREATE: { nonApprovedPayments.forEach(payment => | DayBudgetPlanner.svelte:1354 | ❌ |
| Desktop | DayBudgetPlanner | DELETE: { selectedNonApprovedPayments.clear();  | DayBudgetPlanner.svelte:1365 | ❌ |
| Desktop | DayBudgetPlanner | OTHER: ✕ | DayBudgetPlanner.svelte:1443 | ❌ |
| Desktop | DayBudgetPlanner | OTHER: totalBudgetLimit = calculatedTotalBudget}  | DayBudgetPlanner.svelte:1465 | ❌ |
| Desktop | DayBudgetPlanner | OTHER: Cancel | DayBudgetPlanner.svelte:1514 | ❌ |
| Desktop | DayBudgetPlanner | SAVE: 💾 Save Budget Settings | DayBudgetPlanner.svelte:1515 | ❌ |
| Desktop | DayBudgetPlanner | ASSIGN: ✕ | DayBudgetPlanner.svelte:1527 | ❌ |
| Desktop | DayBudgetPlanner | ASSIGN: Cancel | DayBudgetPlanner.svelte:1562 | ❌ |
| Desktop | DayBudgetPlanner | ASSIGN: Confirm Reschedule | DayBudgetPlanner.svelte:1563 | ❌ |
| Desktop | DayBudgetPlanner | OTHER: ✕ | DayBudgetPlanner.svelte:1581 | ❌ |
| Desktop | DayBudgetPlanner | OTHER: Cancel | DayBudgetPlanner.svelte:1666 | ❌ |
| Desktop | DayBudgetPlanner | ASSIGN: = (splitType === 'vendor' ? (splitItem.final_bill_ | DayBudgetPlanner.svelte:1667 | ❌ |
| Desktop | DayBudgetPlanner | VIEW: &times; | DayBudgetPlanner.svelte:1685 | ❌ |
| Desktop | DayBudgetPlanner | SAVE: � Save as PDF | DayBudgetPlanner.svelte:1689 | ❌ |
| Desktop | DeliverySettings | OTHER: activeTab = 'tiers'} > 💰 Fee Tiers | DeliverySettings.svelte:231 | ❌ |
| Desktop | DeliverySettings | OTHER: activeTab = 'settings'} > ⚙️ General Settin | DeliverySettings.svelte:238 | ❌ |
| Desktop | DeliverySettings | OTHER: activeTab = 'branches'} > 🏢 Branch Service | DeliverySettings.svelte:245 | ❌ |
| Desktop | DeliverySettings | CREATE: openTierModal()} disabled={!tierBranchId}>  | DeliverySettings.svelte:268 | ❌ |
| Desktop | DeliverySettings | EDIT: openTierModal(tier)}>✏️ | DeliverySettings.svelte:316 | ❌ |
| Desktop | DeliverySettings | DELETE: deleteTier(tier)}>🗑️ | DeliverySettings.svelte:317 | ❌ |
| Desktop | DeliverySettings | SAVE: 💾 Save Settings | DeliverySettings.svelte:333 | ❌ |
| Desktop | DeliverySettings | OTHER: selectBranch(branch)} > {branch.b | DeliverySettings.svelte:348 | ❌ |
| Desktop | DeliverySettings | OTHER: toggleBranchService(branch.branch_id, 'delivery')} | DeliverySettings.svelte:477 | ❌ |
| Desktop | DeliverySettings | OTHER: toggleBranchService(branch.branch_id, 'pickup')}  | DeliverySettings.svelte:485 | ❌ |
| Desktop | DeliverySettings | OTHER: ✕ | DeliverySettings.svelte:508 | ❌ |
| Desktop | DeliverySettings | OTHER: Cancel | DeliverySettings.svelte:556 | ❌ |
| Desktop | DeliverySettings | CREATE: {isEditMode ? 'Update' : 'Add'} Tier | DeliverySettings.svelte:557 | ❌ |
| Desktop | DesignPlanner | OTHER: 🎨 Template Designer | DesignPlanner.svelte:992 | ❌ |
| Desktop | DesignPlanner | CREATE: loadOfferProducts(offer.id)} >  | DesignPlanner.svelte:1009 | ❌ |
| Desktop | DesignPlanner | OTHER: generateSizePDF('a4')} title="Generate A4 PDFs for | DesignPlanner.svelte:1052 | ❌ |
| Desktop | DesignPlanner | OTHER: generateSizePDF('a5')} title="Generate A5 PDFs for | DesignPlanner.svelte:1055 | ❌ |
| Desktop | DesignPlanner | OTHER: generateSizePDF('a6')} title="Generate A6 PDFs for | DesignPlanner.svelte:1058 | ❌ |
| Desktop | DesignPlanner | OTHER: generateSizePDF('a7')} title="Generate A7 PDFs for | DesignPlanner.svelte:1061 | ❌ |
| Desktop | DesignPlanner | OTHER: generatePDFWithTemplate(product)} title="Generate  | DesignPlanner.svelte:1272 | ❌ |
| Desktop | DesignPlanner | OTHER: generatePDF(product)}> Ge | DesignPlanner.svelte:1276 | ❌ |
| Desktop | DocumentManagement | OTHER: openDocumentWindow(employee)} disable | DocumentManagement.svelte:255 | ❌ |
| Desktop | EditUser | OTHER: Close | EditUser.svelte:404 | ✅ |
| Desktop | EditUser | OTHER: 🔐 Reset Password | EditUser.svelte:474 | ❌ |
| Desktop | EditUser | VIEW: showPasswordFields = false}> Cancel Reset | EditUser.svelte:478 | ❌ |
| Desktop | EditUser | OTHER: 🎯 Reset Quick Access | EditUser.svelte:488 | ❌ |
| Desktop | EditUser | VIEW: showQuickAccessFields = false}> Cancel Re | EditUser.svelte:492 | ❌ |
| Desktop | EditUser | OTHER: 🎲 | EditUser.svelte:578 | ❌ |
| Desktop | EditUser | OTHER: Retry | EditUser.svelte:650 | ❌ |
| Desktop | EditUser | OTHER: { selectedEmployee = null; formData.employeeId = ' | EditUser.svelte:670 | ❌ |
| Desktop | EditUser | OTHER: selectEmployee(employee)}> Sele | EditUser.svelte:709 | ❌ |
| Desktop | EditUser | DELETE: × | EditUser.svelte:795 | ❌ |
| Desktop | EditUser | OTHER: Cancel | EditUser.svelte:842 | ❌ |
| Desktop | EditUser | EDIT: {#if isLoading} Updating User...  | EditUser.svelte:845 | ❌ |
| Desktop | EditVendor | EDIT: shareLocationFromEdit(editData.location_link, edit | EditVendor.svelte:579 | ❌ |
| Desktop | EditVendor | DELETE: removeCategory(category)}>× | EditVendor.svelte:732 | ❌ |
| Desktop | EditVendor | CREATE: showNewCategoryForm = true} disabled={select | EditVendor.svelte:742 | ❌ |
| Desktop | EditVendor | CREATE: ✅ Add Category | EditVendor.svelte:764 | ❌ |
| Desktop | EditVendor | CREATE: {showNewCategoryForm = false; newCategoryName = '' | EditVendor.svelte:767 | ❌ |
| Desktop | EditVendor | DELETE: removeDeliveryMode(mode)}>× | EditVendor.svelte:824 | ❌ |
| Desktop | EditVendor | CREATE: showNewDeliveryModeForm = true} disabled={se | EditVendor.svelte:834 | ❌ |
| Desktop | EditVendor | CREATE: ✅ Add Delivery Mode | EditVendor.svelte:856 | ❌ |
| Desktop | EditVendor | CREATE: {showNewDeliveryModeForm = false; newDeliveryModeN | EditVendor.svelte:859 | ❌ |
| Desktop | EditVendor | SAVE: {#if isSaving} ⏳ Saving... {:else} � | EditVendor.svelte:1048 | ❌ |
| Desktop | EditVendor | OTHER: ❌ Cancel | EditVendor.svelte:1059 | ❌ |
| Desktop | EmployeeDocumentManager | DELETE: deleteDocument(existingDoc.id)}> 🗑️ Delet | EmployeeDocumentManager.svelte:323 | ❌ |
| Desktop | EmployeeDocumentManager | CREATE: uploadDocument(docType.key)} disabled={isU | EmployeeDocumentManager.svelte:428 | ❌ |
| Desktop | EmployeeDocumentManager | CREATE: 📋 Manage Other Documents → | EmployeeDocumentManager.svelte:453 | ❌ |
| Desktop | EmployeeSalary | OTHER: Cancel | EmployeeSalary.svelte:656 | ❌ |
| Desktop | EmployeeSalary | SAVE: {#if isLoading} Saving... {:e | EmployeeSalary.svelte:664 | ❌ |
| Desktop | ERPConnections | CREATE: showConfigForm = !showConfigForm}> {showConfig | ERPConnections.svelte:379 | ❌ |
| Desktop | ERPConnections | OTHER: {t('actions.cancel') || 'Cancel'} | ERPConnections.svelte:479 | ❌ |
| Desktop | ERPConnections | SAVE: {saving ? `💾 ${t('erp.saving') || 'Saving...'}` : | ERPConnections.svelte:480 | ❌ |
| Desktop | ERPConnections | OTHER: testConnection(config)} disabled={testing | ERPConnections.svelte:524 | ❌ |
| Desktop | ERPConnections | EDIT: editConfig(config)}> ✏️ Edit | ERPConnections.svelte:531 | ❌ |
| Desktop | ERPConnections | DELETE: deleteConfig(config.id!)}> 🗑️ Delete | ERPConnections.svelte:534 | ❌ |
| Desktop | ERPConnections | OTHER: {fetchingSales ? `⏳ ${t('erp.fetching') || 'Fetchi | ERPConnections.svelte:568 | ❌ |
| Desktop | ERPSyncButton | OTHER: {buttonText} | ERPSyncButton.svelte:138 | ❌ |
| Desktop | ExpenseTracker | OTHER: 📊 Compare | ExpenseTracker.svelte:542 | ❌ |
| Desktop | ExpenseTracker | OTHER: 🔄 Refresh | ExpenseTracker.svelte:545 | ❌ |
| Desktop | ExpenseTracker | DELETE: Clear Filters | ExpenseTracker.svelte:629 | ❌ |
| Desktop | ExpenseTracker | DELETE: Clear Filters | ExpenseTracker.svelte:635 | ❌ |
| Desktop | ExpenseTracker | OTHER: Retry | ExpenseTracker.svelte:653 | ❌ |
| Desktop | ExpenseTracker | EDIT: openEditModal(expense)}> ✏️ Edit | ExpenseTracker.svelte:706 | ✅ |
| Desktop | ExpenseTracker | VIEW: window.open(expense.bill_file_url, '_blank')}>  | ExpenseTracker.svelte:711 | ✅ |
| Desktop | ExpenseTracker | OTHER: {loadingMore ? '⏳ Loading...' : `📥 Load More (${e | ExpenseTracker.svelte:731 | ❌ |
| Desktop | ExpenseTracker | OTHER: {loadingMore ? '⏳ Loading...' : `📥 Load More (${e | ExpenseTracker.svelte:740 | ❌ |
| Desktop | ExpenseTracker | EDIT: ✕ | ExpenseTracker.svelte:760 | ❌ |
| Desktop | ExpenseTracker | EDIT: Cancel | ExpenseTracker.svelte:800 | ❌ |
| Desktop | ExpenseTracker | EDIT: Save Changes | ExpenseTracker.svelte:801 | ❌ |
| Desktop | FlyerGenerator | OTHER: activeTab = 'first'} > Fir | FlyerGenerator.svelte:1010 | ❌ |
| Desktop | FlyerGenerator | OTHER: { activeTab = 'sub'; activeSubPageIndex = 0; }}  | FlyerGenerator.svelte:1017 | ❌ |
| Desktop | FlyerGenerator | OTHER: openFieldsPopup('first', 0)} >  | FlyerGenerator.svelte:1033 | ❌ |
| Desktop | FlyerGenerator | OTHER: openFieldsPopup('sub', index)}  | FlyerGenerator.svelte:1049 | ❌ |
| Desktop | FlyerGenerator | OTHER: activeSubPageIndex = index} > | FlyerGenerator.svelte:1293 | ❌ |
| Desktop | FlyerGenerator | OTHER: closeFieldsPopup | FlyerGenerator.svelte:1528 | ❌ |
| Desktop | FlyerGenerator | ASSIGN: selectFieldFromPopup(field)} >  | FlyerGenerator.svelte:1546 | ❌ |
| Desktop | FlyerGenerator | VIEW: showProductSelector = false}> | FlyerGenerator.svelte:1594 | ❌ |
| Desktop | FlyerGenerator | ASSIGN: assignProductToField(product.barcode)}  | FlyerGenerator.svelte:1681 | ❌ |
| Desktop | FlyerGenerator | OTHER: selectedVariantImageIndex = idx}  | FlyerGenerator.svelte:1722 | ❌ |
| Desktop | FlyerGenerator | OTHER: ↔️ Move | FlyerGenerator.svelte:1738 | ❌ |
| Desktop | FlyerGenerator | OTHER: ↗️ Resize | FlyerGenerator.svelte:1743 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(-90)}>↶ -90° | FlyerGenerator.svelte:1753 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(-15)}>↶ -15° | FlyerGenerator.svelte:1754 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(-5)}>↶ -5° | FlyerGenerator.svelte:1755 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(-1)}>↶ -1° | FlyerGenerator.svelte:1756 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(1)}>↷ +1° | FlyerGenerator.svelte:1759 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(5)}>↷ +5° | FlyerGenerator.svelte:1760 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(15)}>↷ +15° | FlyerGenerator.svelte:1761 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(90)}>↷ +90° | FlyerGenerator.svelte:1762 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyFontSize(-2)}>-2 | FlyerGenerator.svelte:1785 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyFontSize(-1)}>-1 | FlyerGenerator.svelte:1786 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyFontSize(1)}>+1 | FlyerGenerator.svelte:1787 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyFontSize(2)}>+2 | FlyerGenerator.svelte:1788 | ❌ |
| Desktop | FlyerGenerator | OTHER: Close | FlyerGenerator.svelte:1793 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextScale(-10)}>-10 | FlyerGenerator.svelte:1809 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextScale(-5)}>-5 | FlyerGenerator.svelte:1810 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextScale(5)}>+5 | FlyerGenerator.svelte:1811 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextScale(10)}>+10 | FlyerGenerator.svelte:1812 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextFontSize(-2)}>-2 | FlyerGenerator.svelte:1819 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextFontSize(-1)}>-1 | FlyerGenerator.svelte:1820 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextFontSize(1)}>+1 | FlyerGenerator.svelte:1821 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextFontSize(2)}>+2 | FlyerGenerator.svelte:1822 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(-90)}>↶ -90° | FlyerGenerator.svelte:1829 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(-15)}>↶ -15° | FlyerGenerator.svelte:1830 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(15)}>↷ +15° | FlyerGenerator.svelte:1831 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(90)}>↷ +90° | FlyerGenerator.svelte:1832 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(-5)}>↶ -5° | FlyerGenerator.svelte:1835 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(-1)}>↶ -1° | FlyerGenerator.svelte:1836 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(1)}>↷ +1° | FlyerGenerator.svelte:1837 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(5)}>↷ +5° | FlyerGenerator.svelte:1838 | ❌ |
| Desktop | FlyerGenerator | OTHER: ✓ | FlyerGenerator.svelte:1857 | ❌ |
| Desktop | FlyerTemplateDesigner | CREATE: ➕ New | FlyerTemplateDesigner.svelte:577 | ❌ |
| Desktop | FlyerTemplateDesigner | OTHER: { firstPageImage = null; firstPageFile = null; }}> | FlyerTemplateDesigner.svelte:629 | ❌ |
| Desktop | FlyerTemplateDesigner | CREATE: ➕ Add Sub Page | FlyerTemplateDesigner.svelte:641 | ❌ |
| Desktop | FlyerTemplateDesigner | DELETE: removeSubPage(index)} title="Remove this page">  | FlyerTemplateDesigner.svelte:653 | ❌ |
| Desktop | FlyerTemplateDesigner | OTHER: { subPageImages[index] = null; subPageFiles[index] | FlyerTemplateDesigner.svelte:669 | ❌ |
| Desktop | FlyerTemplateDesigner | CREATE: ➕ Add Product Field | FlyerTemplateDesigner.svelte:682 | ❌ |
| Desktop | FlyerTemplateDesigner | CREATE: 🎨 Add Special Symbol | FlyerTemplateDesigner.svelte:690 | ❌ |
| Desktop | FlyerTemplateDesigner | OTHER: duplicateField(field.id)} tit | FlyerTemplateDesigner.svelte:711 | ❌ |
| Desktop | FlyerTemplateDesigner | DELETE: deleteField(field.id)} title= | FlyerTemplateDesigner.svelte:718 | ❌ |
| Desktop | FlyerTemplateDesigner | UPLOAD: {isUploading ? '⏳ Saving...' : '💾 Save Template'} | FlyerTemplateDesigner.svelte:743 | ❌ |
| Desktop | FlyerTemplateDesigner | OTHER: activeTab = 'first'} > 📄  | FlyerTemplateDesigner.svelte:755 | ❌ |
| Desktop | FlyerTemplateDesigner | OTHER: { activeTab = 'sub'; activeSubPageIndex = index; } | FlyerTemplateDesigner.svelte:763 | ❌ |
| Desktop | HomePageScreenManager | UPLOAD: 🎥 Video Templates Manage  | HomePageScreenManager.svelte:65 | ❌ |
| Desktop | HomePageScreenManager | UPLOAD: 🖼️ Image Templates Manage | HomePageScreenManager.svelte:85 | ❌ |
| Desktop | ImageTemplatesManager | VIEW: previewImage(slot)}> Preview | ImageTemplatesManager.svelte:298 | ❌ |
| Desktop | ImageTemplatesManager | EDIT: saveSlot(slot.slot_number)} disabled={slot | ImageTemplatesManager.svelte:397 | ❌ |
| Desktop | ImageTemplatesManager | OTHER: toggleActive(slot.slot_number)} disabled= | ImageTemplatesManager.svelte:406 | ❌ |
| Desktop | ImageTemplatesManager | VIEW: × | ImageTemplatesManager.svelte:428 | ❌ |
| Desktop | IncompleteTasksView | OTHER: {isLoadingMore ? 'Loading...' : 'Load More Tasks'} | IncompleteTasksView.svelte:555 | ❌ |
| Desktop | InterfaceAccessManager | OTHER: activeTab = 'users'} >  | InterfaceAccessManager.svelte:468 | ❌ |
| Desktop | InterfaceAccessManager | OTHER: activeTab = 'customers'} >  | InterfaceAccessManager.svelte:479 | ❌ |
| Desktop | InterfaceAccessManager | OTHER: activeTab = 'registration'} >  | InterfaceAccessManager.svelte:490 | ❌ |
| Desktop | InterfaceAccessManager | CREATE: Refresh | InterfaceAccessManager.svelte:524 | ❌ |
| Desktop | InterfaceAccessManager | EDIT: openPermissionModal(user)} disabled={is | InterfaceAccessManager.svelte:640 | ❌ |
| Desktop | InterfaceAccessManager | OTHER: userCurrentPage = Math.max(1, userCurrentPage - 1) | InterfaceAccessManager.svelte:671 | ❌ |
| Desktop | InterfaceAccessManager | OTHER: userCurrentPage = Math.min(userTotalPages, userCur | InterfaceAccessManager.svelte:681 | ❌ |
| Desktop | InterfaceAccessManager | CREATE: Refresh | InterfaceAccessManager.svelte:725 | ❌ |
| Desktop | InterfaceAccessManager | VIEW: action-btn view-btn | InterfaceAccessManager.svelte:800 | ❌ |
| Desktop | InterfaceAccessManager | OTHER: customerCurrentPage = Math.max(1, customerCurrentP | InterfaceAccessManager.svelte:830 | ❌ |
| Desktop | InterfaceAccessManager | OTHER: customerCurrentPage = Math.min(customerTotalPages, | InterfaceAccessManager.svelte:840 | ❌ |
| Desktop | InterfaceAccessManager | CREATE: Refresh | InterfaceAccessManager.svelte:860 | ❌ |
| Desktop | InterfaceAccessManager | OTHER: { navigator.clipboard.writeText(`${wind | InterfaceAccessManager.svelte:1051 | ❌ |
| Desktop | InterfaceAccessManager | OTHER: closePermissionModal | InterfaceAccessManager.svelte:1115 | ❌ |
| Desktop | InterfaceAccessManager | OTHER: Cancel | InterfaceAccessManager.svelte:1184 | ❌ |
| Desktop | InterfaceAccessManager | SAVE: Save Changes | InterfaceAccessManager.svelte:1187 | ❌ |
| Desktop | ManageAdminUsers | OTHER: sortOrder = sortOrder === 'asc' ? 'desc' : 'asc'}  | ManageAdminUsers.svelte:371 | ❌ |
| Desktop | ManageAdminUsers | EXPORT: 📊 Export | ManageAdminUsers.svelte:381 | ❌ |
| Desktop | ManageAdminUsers | CREATE: ➕ Create Admin | ManageAdminUsers.svelte:384 | ❌ |
| Desktop | ManageAdminUsers | DELETE: Clear | ManageAdminUsers.svelte:395 | ❌ |
| Desktop | ManageAdminUsers | OTHER: {#if isLoading} {:else} Apply | ManageAdminUsers.svelte:405 | ❌ |
| Desktop | ManageAdminUsers | EDIT: editUser(user)} disabled={!canModifyUse | ManageAdminUsers.svelte:514 | ❌ |
| Desktop | ManageAdminUsers | EDIT: assignRoles(user)} disabled={!canModify | ManageAdminUsers.svelte:522 | ❌ |
| Desktop | ManageAdminUsers | OTHER: ⋮ | ManageAdminUsers.svelte:533 | ❌ |
| Desktop | ManageAdminUsers | OTHER: handleUserAction(user, 'deactivate')}>  | ManageAdminUsers.svelte:536 | ❌ |
| Desktop | ManageAdminUsers | OTHER: handleUserAction(user, 'activate')}>  | ManageAdminUsers.svelte:540 | ❌ |
| Desktop | ManageAdminUsers | OTHER: handleUserAction(user, 'unlock')}> 🔓 | ManageAdminUsers.svelte:546 | ❌ |
| Desktop | ManageAdminUsers | OTHER: handleUserAction(user, 'lock')}> 🔒 L | ManageAdminUsers.svelte:550 | ❌ |
| Desktop | ManageAdminUsers | OTHER: handleUserAction(user, 'reset_password')}>  | ManageAdminUsers.svelte:555 | ❌ |
| Desktop | ManageAdminUsers | DELETE: handleUserAction(user, 'delete')} cla | ManageAdminUsers.svelte:560 | ❌ |
| Desktop | ManageAdminUsers | CREATE: Create First Admin User | ManageAdminUsers.svelte:581 | ❌ |
| Desktop | ManageAdminUsers | OTHER: Close Window | ManageAdminUsers.svelte:627 | ❌ |
| Desktop | ManageMasterAdmin | VIEW: activeTab = 'overview'} > 🏠 Overview | ManageMasterAdmin.svelte:371 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: activeTab = 'admins'} > 👑 Master Admins | ManageMasterAdmin.svelte:378 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: activeTab = 'security'} > 🔒 Security | ManageMasterAdmin.svelte:385 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: activeTab = 'audit'} > 📋 Audit Log | ManageMasterAdmin.svelte:392 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: 💾 Emergency Backup | ManageMasterAdmin.svelte:487 | ❌ |
| Desktop | ManageMasterAdmin | VIEW: showSecuritySettings = true}> 🔒 Security S | ManageMasterAdmin.svelte:490 | ✅ |
| Desktop | ManageMasterAdmin | CREATE: showCreateForm = true} disabled={!canCreateMore}>  | ManageMasterAdmin.svelte:493 | ✅ |
| Desktop | ManageMasterAdmin | VIEW: activeTab = 'audit'}>View All → | ManageMasterAdmin.svelte:503 | ❌ |
| Desktop | ManageMasterAdmin | CREATE: showCreateForm = true} disabled={!canCreateMore}>  | ManageMasterAdmin.svelte:529 | ✅ |
| Desktop | ManageMasterAdmin | EDIT: editMasterAdmin(admin)}> ✏️ Edit | ManageMasterAdmin.svelte:589 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: ⋮ | ManageMasterAdmin.svelte:594 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: handleMasterAdminAction(admin, 'deactivate')}>  | ManageMasterAdmin.svelte:598 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: handleMasterAdminAction(admin, 'activate')}>  | ManageMasterAdmin.svelte:603 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: handleMasterAdminAction(admin, 'unlock')}>  | ManageMasterAdmin.svelte:609 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: handleMasterAdminAction(admin, 'reset_password')}> | ManageMasterAdmin.svelte:614 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: handleMasterAdminAction(admin, 'disable_2fa')}>  | ManageMasterAdmin.svelte:619 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: handleMasterAdminAction(admin, 'enable_2fa')}>  | ManageMasterAdmin.svelte:623 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: handleMasterAdminAction(admin, 'make_primary')}>  | ManageMasterAdmin.svelte:629 | ❌ |
| Desktop | ManageMasterAdmin | DELETE: handleMasterAdminAction(admin, 'delete')} class="d | ManageMasterAdmin.svelte:635 | ❌ |
| Desktop | ManageMasterAdmin | EDIT: {#if isLoading} Updating...  | ManageMasterAdmin.svelte:736 | ❌ |
| Desktop | ManageMasterAdmin | CREATE: showCreateForm = false}>× | ManageMasterAdmin.svelte:792 | ❌ |
| Desktop | ManageMasterAdmin | CREATE: showCreateForm = false}> Cancel | ManageMasterAdmin.svelte:901 | ❌ |
| Desktop | ManageMasterAdmin | CREATE: {#if isLoading} Creating...  | ManageMasterAdmin.svelte:904 | ❌ |
| Desktop | ManageMasterAdmin | OTHER: Close Control Center | ManageMasterAdmin.svelte:933 | ❌ |
| Desktop | ManageVendor | CREATE: ➕ Create Vendor | ManageVendor.svelte:575 | ❌ |
| Desktop | ManageVendor | OTHER: 🔄 Refresh | ManageVendor.svelte:578 | ❌ |
| Desktop | ManageVendor | DELETE: searchQuery = ''}>× | ManageVendor.svelte:651 | ❌ |
| Desktop | ManageVendor | VIEW: showColumnSelector = !showColumnSelector}> 🏷 | ManageVendor.svelte:670 | ❌ |
| Desktop | ManageVendor | VIEW: toggleAllColumns(true)}>✅ Show All | ManageVendor.svelte:678 | ❌ |
| Desktop | ManageVendor | OTHER: toggleAllColumns(false)}>❌ Hide All | ManageVendor.svelte:679 | ❌ |
| Desktop | ManageVendor | OTHER: Try Again | ManageVendor.svelte:704 | ❌ |
| Desktop | ManageVendor | DELETE: searchQuery = ''}>Clear Search | ManageVendor.svelte:723 | ❌ |
| Desktop | ManageVendor | OTHER: shareLocation(vendor.location_link, vendor.vendor_ | ManageVendor.svelte:913 | ❌ |
| Desktop | ManageVendor | OTHER: cycleVendorStatus(vendor.erp_vendor_id, vendor.sta | ManageVendor.svelte:1030 | ❌ |
| Desktop | ManageVendor | OTHER: cycleVendorStatus(vendor.erp_vendor_id, vendor.sta | ManageVendor.svelte:1034 | ❌ |
| Desktop | ManageVendor | OTHER: cycleVendorStatus(vendor.erp_vendor_id, vendor.sta | ManageVendor.svelte:1038 | ❌ |
| Desktop | ManageVendor | OTHER: cycleVendorStatus(vendor.erp_vendor_id, vendor.sta | ManageVendor.svelte:1042 | ❌ |
| Desktop | ManageVendor | EDIT: openEditWindow(vendor)}>✏️ Edit | ManageVendor.svelte:1050 | ❌ |
| Desktop | ManualScheduling | DELETE: { searchTerm = ''; filterVendors(); }} > | ManualScheduling.svelte:546 | ❌ |
| Desktop | ManualScheduling | OTHER: onVendorSelect(vendor.erp_vendor_id)}  | ManualScheduling.svelte:577 | ❌ |
| Desktop | ManualScheduling | OTHER: ← Back to Selection | ManualScheduling.svelte:615 | ❌ |
| Desktop | ManualScheduling | OTHER: 📋 | ManualScheduling.svelte:665 | ❌ |
| Desktop | ManualScheduling | OTHER: 🔄 Reset Form | ManualScheduling.svelte:783 | ❌ |
| Desktop | ManualScheduling | ASSIGN: {#if isLoading} 💾 Saving... {:el | ManualScheduling.svelte:786 | ❌ |
| Desktop | MonthDetails | OTHER: {refreshing ? "⏳" : "🔄"} | MonthDetails.svelte:1666 | ❌ |
| Desktop | MonthDetails | EDIT: openPaymentMethodEdit(payment)}  | MonthDetails.svelte:1903 | ❌ |
| Desktop | MonthDetails | ASSIGN: openRescheduleModal(payment)} tit | MonthDetails.svelte:1956 | ❌ |
| Desktop | MonthDetails | OTHER: openSplitModal(payment)} title="S | MonthDetails.svelte:1963 | ❌ |
| Desktop | MonthDetails | EDIT: openEditAmountModal(payment)} tit | MonthDetails.svelte:1970 | ❌ |
| Desktop | MonthDetails | DELETE: deleteVendorPayment(payment)} tit | MonthDetails.svelte:1979 | ❌ |
| Desktop | MonthDetails | ASSIGN: openExpenseRescheduleModal(payment)}  | MonthDetails.svelte:2105 | ❌ |
| Desktop | MonthDetails | OTHER: openRequestClosureModal(payment)}  | MonthDetails.svelte:2113 | ❌ |
| Desktop | MonthDetails | DELETE: deleteExpensePayment(payment)} ti | MonthDetails.svelte:2123 | ❌ |
| Desktop | MonthDetails | OTHER: × | MonthDetails.svelte:2165 | ❌ |
| Desktop | MonthDetails | CREATE: 📦 Move Full Payment Mo | MonthDetails.svelte:2227 | ❌ |
| Desktop | MonthDetails | OTHER: Split & Move | MonthDetails.svelte:2285 | ❌ |
| Desktop | MonthDetails | EDIT: × | MonthDetails.svelte:2303 | ❌ |
| Desktop | MonthDetails | EDIT: Cancel | MonthDetails.svelte:2394 | ❌ |
| Desktop | MonthDetails | EDIT: Save Changes | MonthDetails.svelte:2395 | ❌ |
| Desktop | MonthDetails | ASSIGN: × | MonthDetails.svelte:2407 | ❌ |
| Desktop | MonthDetails | CREATE: 📦 Move Full Payment Mo | MonthDetails.svelte:2454 | ❌ |
| Desktop | MonthDetails | OTHER: Split & Move | MonthDetails.svelte:2512 | ❌ |
| Desktop | MonthDetails | EDIT: ✕ | MonthDetails.svelte:2530 | ❌ |
| Desktop | MonthDetails | EDIT: Cancel | MonthDetails.svelte:2678 | ❌ |
| Desktop | MonthDetails | SAVE: Save Adjustment | MonthDetails.svelte:2679 | ❌ |
| Desktop | MonthlyManager | EDIT: openPaymentMethodEdit(payment)} title= | MonthlyManager.svelte:862 | ❌ |
| Desktop | MonthlyManager | ASSIGN: openRescheduleModal(payment)} title="R | MonthlyManager.svelte:873 | ❌ |
| Desktop | MonthlyManager | OTHER: openSplitModal(payment)} title="Split  | MonthlyManager.svelte:884 | ❌ |
| Desktop | MonthlyManager | EDIT: openEditAmountModal(payment)} title="E | MonthlyManager.svelte:895 | ❌ |
| Desktop | MonthlyManager | DELETE: deleteVendorPayment(payment)} title="D | MonthlyManager.svelte:906 | ❌ |
| Desktop | MonthlyManager | ASSIGN: openExpenseRescheduleModal(payment)} t | MonthlyManager.svelte:1023 | ❌ |
| Desktop | MonthlyManager | OTHER: openRequestClosureModal(payment)} tit | MonthlyManager.svelte:1031 | ❌ |
| Desktop | MonthlyManager | DELETE: deleteExpensePayment(payment)} title=" | MonthlyManager.svelte:1043 | ❌ |
| Desktop | MonthlyManager | ASSIGN: showRescheduleModal = false}>Cancel | MonthlyManager.svelte:1087 | ❌ |
| Desktop | MonthlyManager | ASSIGN: Save | MonthlyManager.svelte:1088 | ❌ |
| Desktop | MonthlyManager | VIEW: showSplitModal = false}>Cancel | MonthlyManager.svelte:1125 | ❌ |
| Desktop | MonthlyManager | SAVE: Save | MonthlyManager.svelte:1126 | ❌ |
| Desktop | MonthlyManager | VIEW: showPaymentMethodModal = false}>Close | MonthlyManager.svelte:1147 | ❌ |
| Desktop | MonthlyManager | EDIT: showEditAmountModal = false}>Cancel | MonthlyManager.svelte:1201 | ❌ |
| Desktop | MonthlyManager | EDIT: Save | MonthlyManager.svelte:1202 | ❌ |
| Desktop | MonthlyManager | ASSIGN: showExpenseRescheduleModal = false}>Cancel | MonthlyManager.svelte:1238 | ❌ |
| Desktop | MonthlyManager | ASSIGN: Save | MonthlyManager.svelte:1239 | ❌ |
| Desktop | MonthlyPaidManager | OTHER: 🔄 Reset Filters | MonthlyPaidManager.svelte:333 | ❌ |
| Desktop | MonthlyPaidManager | EXPORT: 📥 Export CSV | MonthlyPaidManager.svelte:337 | ❌ |
| Desktop | MultipleBillScheduling | EDIT: ✕ | MultipleBillScheduling.svelte:985 | ❌ |
| Desktop | MultipleBillScheduling | SAVE: saveBill(activeBillIndex)} disabled={bills[activeB | MultipleBillScheduling.svelte:1184 | ❌ |
| Desktop | MultipleBillScheduling | EDIT: Close | MultipleBillScheduling.svelte:1188 | ❌ |
| Desktop | MultipleBillScheduling | OTHER: 📱 Share via WhatsApp | MultipleBillScheduling.svelte:1223 | ❌ |
| Desktop | MultipleBillScheduling | CREATE: ➕ New Schedule | MultipleBillScheduling.svelte:1227 | ❌ |
| Desktop | MultipleBillScheduling | OTHER: ← Previous | MultipleBillScheduling.svelte:1239 | ❌ |
| Desktop | MultipleBillScheduling | OTHER: Next → | MultipleBillScheduling.svelte:1242 | ❌ |
| Desktop | MyAssignmentsView | OTHER: Refresh | MyAssignmentsView.svelte:450 | ❌ |
| Desktop | MyAssignmentsView | DELETE: Clear Filters | MyAssignmentsView.svelte:541 | ❌ |
| Desktop | MyTasksView | OTHER: Refresh | MyTasksView.svelte:967 | ❌ |
| Desktop | MyTasksView | OTHER: filterTaskType = 'receiving'} class="px-4 py | MyTasksView.svelte:1072 | ❌ |
| Desktop | MyTasksView | OTHER: { console.log('🔵 [MyTasks] Complete  | MyTasksView.svelte:1221 | ❌ |
| Desktop | MyTasksView | VIEW: { console.log('🔵 [MyTasks] View Detai | MyTasksView.svelte:1235 | ❌ |
| Desktop | NotificationCenter | CREATE: 📝 Create Notification | NotificationCenter.svelte:903 | ❌ |
| Desktop | NotificationCenter | OTHER: 👥 Read Status | NotificationCenter.svelte:907 | ❌ |
| Desktop | NotificationCenter | OTHER: 🔄 {isLoading ? 'Refreshing...' : 'Refresh'} | NotificationCenter.svelte:912 | ❌ |
| Desktop | NotificationCenter | OTHER: Mark All as Read | NotificationCenter.svelte:919 | ❌ |
| Desktop | NotificationCenter | OTHER: Retry | NotificationCenter.svelte:931 | ❌ |
| Desktop | NotificationCenter | OTHER: openTaskCompletion(notification)} titl | NotificationCenter.svelte:991 | ❌ |
| Desktop | NotificationCenter | OTHER: markAsRead(notification.id)} title="Ma | NotificationCenter.svelte:1000 | ❌ |
| Desktop | NotificationCenter | DELETE: deleteNotification(notification.id)} t | NotificationCenter.svelte:1009 | ❌ |
| Desktop | NotificationCenter | VIEW: openImageModal(notification.image_url)}  | NotificationCenter.svelte:1036 | ❌ |
| Desktop | NotificationCenter | OTHER: closeImageModal | NotificationCenter.svelte:1101 | ❌ |
| Desktop | OfferForm | CREATE: + {isRTL ? 'اختيار المنتجات' : 'Select Prod | OfferForm.svelte:767 | ❌ |
| Desktop | OfferForm | OTHER: {isRTL ? 'السابق' : 'Previous'} | OfferForm.svelte:943 | ❌ |
| Desktop | OfferForm | OTHER: {isRTL ? 'إلغاء' : 'Cancel'} | OfferForm.svelte:947 | ❌ |
| Desktop | OfferForm | OTHER: {isRTL ? 'التالي' : 'Next'} | OfferForm.svelte:951 | ❌ |
| Desktop | OfferForm | CREATE: {#if loading} {/if} {isRTL ? (edi | OfferForm.svelte:955 | ❌ |
| Desktop | OfferManagement | OTHER: 🔄 {texts.refresh} | OfferManagement.svelte:970 | ❌ |
| Desktop | OfferManagement | CREATE: createOfferWithType('percentage')}> 📊 {l | OfferManagement.svelte:973 | ❌ |
| Desktop | OfferManagement | CREATE: createOfferWithType('special_price')}> 💰 | OfferManagement.svelte:976 | ❌ |
| Desktop | OfferManagement | CREATE: createOfferWithType('bogo')}> 🎁 {locale  | OfferManagement.svelte:979 | ❌ |
| Desktop | OfferManagement | CREATE: createOfferWithType('bundle')}> 📦 {local | OfferManagement.svelte:982 | ❌ |
| Desktop | OfferManagement | CREATE: createOfferWithType('cart')}> 🛒 {locale  | OfferManagement.svelte:985 | ❌ |
| Desktop | OfferManagement | CREATE: ➕ {texts.createNew} | OfferManagement.svelte:1080 | ❌ |
| Desktop | OfferManagement | EDIT: editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1147 | ❌ |
| Desktop | OfferManagement | OTHER: toggleOfferStatus(offer.id, offer.is_active)}  | OfferManagement.svelte:1150 | ❌ |
| Desktop | OfferManagement | DELETE: deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1158 | ❌ |
| Desktop | OfferManagement | EDIT: editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1217 | ❌ |
| Desktop | OfferManagement | OTHER: toggleOfferStatus(offer.id, offer.is_active)}  | OfferManagement.svelte:1220 | ❌ |
| Desktop | OfferManagement | DELETE: deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1228 | ❌ |
| Desktop | OfferManagement | EDIT: editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1288 | ❌ |
| Desktop | OfferManagement | OTHER: toggleOfferStatus(offer.id, offer.is_active)}  | OfferManagement.svelte:1291 | ❌ |
| Desktop | OfferManagement | DELETE: deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1299 | ❌ |
| Desktop | OfferManagement | EDIT: editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1405 | ❌ |
| Desktop | OfferManagement | VIEW: viewAnalytics(offer.id)} title={texts.analytics}>  | OfferManagement.svelte:1408 | ❌ |
| Desktop | OfferManagement | DELETE: deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1411 | ❌ |
| Desktop | OfferManager | OTHER: Refresh | OfferManager.svelte:145 | ❌ |
| Desktop | OfferManager | OTHER: toggleOfferStatus(offer.id, offer.is_active)}  | OfferManager.svelte:241 | ❌ |
| Desktop | OfferManager | DELETE: deleteOffer(offer.id, offer.template_name)}  | OfferManager.svelte:258 | ❌ |
| Desktop | OfferProductSelector | OTHER: Next: Select Products | OfferProductSelector.svelte:596 | ❌ |
| Desktop | OfferProductSelector | CREATE: Add Template | OfferProductSelector.svelte:613 | ❌ |
| Desktop | OfferProductSelector | DELETE: removeTemplate(template.id)} class="tex | OfferProductSelector.svelte:637 | ❌ |
| Desktop | OfferProductSelector | OTHER: Previous | OfferProductSelector.svelte:681 | ❌ |
| Desktop | OfferProductSelector | VIEW: Next: Review | OfferProductSelector.svelte:691 | ❌ |
| Desktop | OfferProductSelector | DELETE: Clear Filters | OfferProductSelector.svelte:760 | ❌ |
| Desktop | OfferProductSelector | OTHER: Previous | OfferProductSelector.svelte:884 | ❌ |
| Desktop | OfferProductSelector | SAVE: {isLoading ? 'Saving...' : 'Save Offers'} | OfferProductSelector.svelte:894 | ❌ |
| Desktop | OfferTemplates | OTHER: Refresh | OfferTemplates.svelte:263 | ❌ |
| Desktop | OfferTemplates | CREATE: selectTemplate(template)} class="bg-white  | OfferTemplates.svelte:294 | ❌ |
| Desktop | OfferTemplates | OTHER: Back to Templates | OfferTemplates.svelte:343 | ❌ |
| Desktop | OfferTemplates | SAVE: {#if isSaving}  | OfferTemplates.svelte:357 | ❌ |
| Desktop | OfferTypeSelector | OTHER: selectType(offerType.type)} > {offerType. | OfferTypeSelector.svelte:68 | ❌ |
| Desktop | OrdersManager | DELETE: {t('orders.filters.clear', 'Clear')} | OrdersManager.svelte:426 | ❌ |
| Desktop | OrdersManager | OTHER: action-btn | OrdersManager.svelte:488 | ❌ |
| Desktop | OtherDocumentsManager | CREATE: {#if isUploading} Uploading... { | OtherDocumentsManager.svelte:529 | ❌ |
| Desktop | OtherDocumentsManager | OTHER: 🔄 Reset Form | OtherDocumentsManager.svelte:542 | ❌ |
| Desktop | OtherDocumentsManager | DELETE: deleteDocument(doc.id)}> 🗑️ | OtherDocumentsManager.svelte:574 | ❌ |
| Desktop | OverduesReport | VIEW: { if (showVendorTable) { showVendorTa | OverduesReport.svelte:304 | ❌ |
| Desktop | OverduesReport | VIEW: { if (showExpenseTable) { showExpense | OverduesReport.svelte:325 | ❌ |
| Desktop | PaidManager | VIEW: ⚠️ Pending ERP References ({paidVendor | PaidManager.svelte:456 | ❌ |
| Desktop | PaidManager | EDIT: updateVendorReference(payment.id, editingVendorRef | PaidManager.svelte:528 | ❌ |
| Desktop | PaidManager | EDIT: editingVendorPaymentId = null}>✕ | PaidManager.svelte:529 | ❌ |
| Desktop | PaidManager | EDIT: updateExpenseReference(payment.id, editingExpenseR | PaidManager.svelte:628 | ❌ |
| Desktop | PaidManager | EDIT: editingExpensePaymentId = null}>✕ | PaidManager.svelte:629 | ❌ |
| Desktop | PaidManager | VIEW: showPendingModal = false}>Close | PaidManager.svelte:735 | ❌ |
| Desktop | PaidManager | EDIT: showEditPopup = false}>Cancel | PaidManager.svelte:769 | ❌ |
| Desktop | PaidManager | SAVE: Save | PaidManager.svelte:770 | ❌ |
| Desktop | PriceValidationWarning | OTHER: Cancel | PriceValidationWarning.svelte:165 | ❌ |
| Desktop | PriceValidationWarning | DELETE: { if (selectedAction === 'continue') handleC | PriceValidationWarning.svelte:172 | ❌ |
| Desktop | PricingManager | OTHER: Refresh | PricingManager.svelte:1395 | ❌ |
| Desktop | PricingManager | CREATE: loadOfferProducts(offer.id)} class="p-4 bor | PricingManager.svelte:1429 | ❌ |
| Desktop | PricingManager | OTHER: Generate Offers | PricingManager.svelte:1515 | ❌ |
| Desktop | PricingManager | OTHER: B1 | PricingManager.svelte:1526 | ❌ |
| Desktop | PricingManager | OTHER: B2 | PricingManager.svelte:1535 | ❌ |
| Desktop | PricingManager | OTHER: B3 | PricingManager.svelte:1544 | ❌ |
| Desktop | PricingManager | OTHER: B4 | PricingManager.svelte:1553 | ❌ |
| Desktop | PricingManager | OTHER: B5 | PricingManager.svelte:1562 | ❌ |
| Desktop | PricingManager | OTHER: 3x target) to target+10%'} > B6 | PricingManager.svelte:1571 | ❌ |
| Desktop | PricingManager | EXPORT: Export to Excel | PricingManager.svelte:1582 | ❌ |
| Desktop | PricingManager | UPLOAD: Import from Excel | PricingManager.svelte:1592 | ❌ |
| Desktop | PricingManager | SAVE: {#if isSavingPrices}  | PricingManager.svelte:1602 | ❌ |
| Desktop | PricingManager | VIEW: showSuccessModal = false} class="px-6 py-2.5 | PricingManager.svelte:1944 | ❌ |
| Desktop | ProductFieldConfigurator | CREATE: ➕ Add Field | ProductFieldConfigurator.svelte:95 | ❌ |
| Desktop | ProductFieldConfigurator | DELETE: deleteField(index)}>🗑️ | ProductFieldConfigurator.svelte:113 | ❌ |
| Desktop | ProductFieldConfigurator | OTHER: Cancel | ProductFieldConfigurator.svelte:260 | ❌ |
| Desktop | ProductFieldConfigurator | SAVE: 💾 Save Configuration | ProductFieldConfigurator.svelte:261 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | CREATE: ➕ Add Field | ProductFieldConfiguratorFlyer.svelte:519 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | DELETE: deleteField(fieldItem.id)}>🗑️ | ProductFieldConfiguratorFlyer.svelte:528 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | DELETE: removeIcon(fieldItem.id)}>✕ | ProductFieldConfiguratorFlyer.svelte:599 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | UPLOAD: triggerIconUpload(fieldItem.id)}>  | ProductFieldConfiguratorFlyer.svelte:639 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | DELETE: removeSymbol(fieldItem.id)}>✕ | ProductFieldConfiguratorFlyer.svelte:653 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | UPLOAD: triggerSymbolUpload(fieldItem.id)}>  | ProductFieldConfiguratorFlyer.svelte:677 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | SAVE: ✅ Apply Configuration | ProductFieldConfiguratorFlyer.svelte:692 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | OTHER: Cancel | ProductFieldConfiguratorFlyer.svelte:695 | ❌ |
| Desktop | ProductManager | SAVE: 💾 {saving ? 'Saving...' : `Save (${selectedP | ProductManager.svelte:482 | ❌ |
| Desktop | ProductManager | OTHER: Retry | ProductManager.svelte:569 | ❌ |
| Desktop | ProductManager | CREATE: { selectedProducts.clear(); sele | ProductManager.svelte:743 | ❌ |
| Desktop | ProductMaster | CREATE: closeCreatePopup | ProductMaster.svelte:1466 | ❌ |
| Desktop | ProductMaster | OTHER: {#if isCheckingImage}  | ProductMaster.svelte:1493 | ❌ |
| Desktop | ProductMaster | CREATE: Cancel | ProductMaster.svelte:1656 | ❌ |
| Desktop | ProductMaster | CREATE: {#if isSavingCreate}  | ProductMaster.svelte:1663 | ❌ |
| Desktop | ProductMaster | EDIT: closeEditPopup | ProductMaster.svelte:1702 | ❌ |
| Desktop | ProductMaster | EDIT: Cancel | ProductMaster.svelte:1834 | ❌ |
| Desktop | ProductMaster | EDIT: {#if isSavingEdit}  | ProductMaster.svelte:1841 | ❌ |
| Desktop | ProductMaster | UPLOAD: showUploadSuccessPopup = false} class="w-ful | ProductMaster.svelte:1877 | ❌ |
| Desktop | ProductMaster | VIEW: Close | ProductMaster.svelte:1899 | ❌ |
| Desktop | ProductMaster | VIEW: Cancel | ProductMaster.svelte:1924 | ❌ |
| Desktop | ProductMaster | EXPORT: {#if downloadingImage}  | ProductMaster.svelte:1933 | ❌ |
| Desktop | ProductMaster | OTHER: Close | ProductMaster.svelte:1979 | ❌ |
| Desktop | ProductMaster | EXPORT: downloadAndUploadImage(image.url || image, 'none') | ProductMaster.svelte:2039 | ❌ |
| Desktop | ProductMaster | DELETE: downloadAndUploadImage(image.url || image, 'client | ProductMaster.svelte:2051 | ❌ |
| Desktop | ProductMaster | DELETE: downloadAndUploadImage(image.url || image, 'api')} | ProductMaster.svelte:2065 | ❌ |
| Desktop | ProductMaster | UPLOAD: Cancel | ProductMaster.svelte:2104 | ❌ |
| Desktop | ProductMaster | SAVE: {#if isSavingProducts}  | ProductMaster.svelte:2158 | ❌ |
| Desktop | ProductMaster | CREATE: Create Product | ProductMaster.svelte:2178 | ❌ |
| Desktop | ProductMaster | UPLOAD: {#if isUploadingImages}  | ProductMaster.svelte:2188 | ❌ |
| Desktop | ProductMaster | EXPORT: Download Template | ProductMaster.svelte:2207 | ❌ |
| Desktop | ProductMaster | UPLOAD: Import from Excel | ProductMaster.svelte:2217 | ❌ |
| Desktop | ProductMaster | VIEW: View All | ProductMaster.svelte:2262 | ❌ |
| Desktop | ProductMaster | UPLOAD: Upload | ProductMaster.svelte:2304 | ❌ |
| Desktop | ProductMaster | VIEW: Close | ProductMaster.svelte:2353 | ❌ |
| Desktop | ProductMaster | OTHER: noImageSearchQuery = ''} class="absolute  | ProductMaster.svelte:2376 | ❌ |
| Desktop | ProductMaster | OTHER: searchWebForImages(product.barcode, 'google')}  | ProductMaster.svelte:2491 | ❌ |
| Desktop | ProductMaster | OTHER: searchWebForImages(product.barcode, 'duckduckgo')} | ProductMaster.svelte:2508 | ❌ |
| Desktop | ProductMaster | EDIT: openEditPopup(product)} class="px-3 py | ProductMaster.svelte:2523 | ❌ |
| Desktop | ProductMaster | VIEW: Close | ProductMaster.svelte:2570 | ❌ |
| Desktop | ProductMaster | EDIT: document.getElementById(`update-image-${product.ba | ProductMaster.svelte:2705 | ❌ |
| Desktop | ProductMaster | EDIT: openEditPopup(product)} class="px-3 py | ProductMaster.svelte:2724 | ❌ |
| Desktop | ProductMaster | DELETE: searchBarcode = ''} class="px-4 py-2 text-g | ProductMaster.svelte:2784 | ❌ |
| Desktop | ProductMaster | DELETE: searchBarcode = ''} class="px-6 py-2 bg-blue- | ProductMaster.svelte:2904 | ❌ |
| Desktop | ProductsManager | OTHER: 📦 Manage Products | ProductsManager.svelte:193 | ❌ |
| Desktop | ProductsManager | OTHER: 🏷️ Manage Categories | ProductsManager.svelte:197 | ❌ |
| Desktop | ProductsManager | OTHER: selectCardType('active')}> ✅ { | ProductsManager.svelte:210 | ❌ |
| Desktop | ProductsManager | OTHER: selectCardType('minimumAlert')}> ⚠️  | ProductsManager.svelte:217 | ❌ |
| Desktop | ProductsManager | OTHER: selectCardType('minimumQty')}> 🔴  | ProductsManager.svelte:224 | ❌ |
| Desktop | ProductsManagerNew | OTHER: 📦 Manage Products | ProductsManagerNew.svelte:59 | ❌ |
| Desktop | ProductsManagerNew | OTHER: 🏷️ Manage Categories | ProductsManagerNew.svelte:63 | ❌ |
| Desktop | PushNotificationSettings | OTHER: {#if isLoading} {:else}  | PushNotificationSettings.svelte:234 | ❌ |
| Desktop | PushNotificationSettings | OTHER: {#if isLoading} {:else}  | PushNotificationSettings.svelte:251 | ❌ |
| Desktop | PushNotificationSettings | OTHER: {#if isLoading} {:else}  | PushNotificationSettings.svelte:266 | ❌ |
| Desktop | PushNotificationSettings | SEND: {#if isLoading} {:else}  | PushNotificationSettings.svelte:283 | ❌ |
| Desktop | QuickTaskCompletionDialog | UPLOAD: 📸 Upload Photos | QuickTaskCompletionDialog.svelte:275 | ❌ |
| Desktop | QuickTaskCompletionDialog | DELETE: removeFile(file.id)} disabled={loading}  | QuickTaskCompletionDialog.svelte:298 | ❌ |
| Desktop | QuickTaskCompletionDialog | OTHER: dispatch('close')} disabled={loading} >  | QuickTaskCompletionDialog.svelte:320 | ❌ |
| Desktop | QuickTaskCompletionDialog | UPLOAD: {#if uploadingFiles} Uploading Files... | QuickTaskCompletionDialog.svelte:328 | ❌ |
| Desktop | QuickTaskDetailsModal | OTHER: Complete Quick Task | QuickTaskDetailsModal.svelte:267 | ❌ |
| Desktop | Receiving | OTHER: 🚀 Start Receiving | Receiving.svelte:482 | ❌ |
| Desktop | Receiving | OTHER: 📋 Receiving Records | Receiving.svelte:487 | ❌ |
| Desktop | ReceivingRecords | OTHER: generateCertificate(record)}> �  | ReceivingRecords.svelte:1169 | ❌ |
| Desktop | ReceivingRecords | EDIT: updateOriginalBill(record.id)} title="Upload updat | ReceivingRecords.svelte:1200 | ❌ |
| Desktop | ReceivingRecords | UPLOAD: uploadOriginalBill(record.id)}> 📎  | ReceivingRecords.svelte:1215 | ❌ |
| Desktop | ReceivingRecords | EXPORT: downloadPRExcel(record)} > 📊 | ReceivingRecords.svelte:1226 | ❌ |
| Desktop | ReceivingRecords | UPLOAD: uploadPRExcel(record.id)}> 📊  | ReceivingRecords.svelte:1259 | ❌ |
| Desktop | ReceivingRecords | OTHER: openErpPopup(record)} title="Click to  | ReceivingRecords.svelte:1338 | ❌ |
| Desktop | ReceivingRecords | DELETE: deleteReceivingRecord(record.id)} title | ReceivingRecords.svelte:1361 | ❌ |
| Desktop | ReceivingRecords | OTHER: { isLoadingMore = true; currentPage++; | ReceivingRecords.svelte:1380 | ❌ |
| Desktop | ReceivingRecords | OTHER: &times; | ReceivingRecords.svelte:1415 | ❌ |
| Desktop | ReceivingRecords | OTHER: Cancel | ReceivingRecords.svelte:1433 | ❌ |
| Desktop | ReceivingRecords | EDIT: {#if updatingErp} Updating...  | ReceivingRecords.svelte:1440 | ❌ |
| Desktop | ReceivingRecordsWithSync | OTHER: { // Implement bulk sync functionality  | ReceivingRecordsWithSync.svelte:120 | ❌ |
| Desktop | ReceivingTaskCompletionDialog | DELETE: removePRExcelFile | ReceivingTaskCompletionDialog.svelte:784 | ❌ |
| Desktop | ReceivingTaskCompletionDialog | DELETE: removeOriginalBillFile | ReceivingTaskCompletionDialog.svelte:832 | ❌ |
| Desktop | ReceivingTaskCompletionDialog | DELETE: removePhoto | ReceivingTaskCompletionDialog.svelte:1006 | ✅ |
| Desktop | ReceivingTaskCompletionDialog | OTHER: Cancel | ReceivingTaskCompletionDialog.svelte:1187 | ✅ |
| Desktop | ReceivingTaskCompletionDialog | OTHER: {#if loading} Completing...  | ReceivingTaskCompletionDialog.svelte:1197 | ✅ |
| Desktop | ReceivingTaskCompletionDialog | OTHER: {#if loading} Completing...  | ReceivingTaskCompletionDialog.svelte:1211 | ✅ |
| Desktop | ReceivingTaskCompletionDialog | OTHER: {#if loading} Completing...  | ReceivingTaskCompletionDialog.svelte:1225 | ✅ |
| Desktop | ReceivingTaskCompletionDialog | VIEW: closePhotoViewer | ReceivingTaskCompletionDialog.svelte:1256 | ❌ |
| Desktop | ReceivingTaskDetailsModal | OTHER: ✅ Complete Task | ReceivingTaskDetailsModal.svelte:248 | ❌ |
| Desktop | ReceivingTasksDashboard | OTHER: selectedFilter = 'all'} > All  | ReceivingTasksDashboard.svelte:458 | ❌ |
| Desktop | ReceivingTasksDashboard | OTHER: selectedFilter = 'pending'} >  | ReceivingTasksDashboard.svelte:464 | ❌ |
| Desktop | ReceivingTasksDashboard | OTHER: selectedFilter = 'completed'} >  | ReceivingTasksDashboard.svelte:470 | ❌ |
| Desktop | ReceivingTasksDashboard | OTHER: selectedFilter = 'overdue'} >  | ReceivingTasksDashboard.svelte:476 | ❌ |
| Desktop | ReceivingTasksDashboard | OTHER: completeTask(task)} >  | ReceivingTasksDashboard.svelte:573 | ❌ |
| Desktop | ReceivingTasksDashboard | OTHER: closeInventoryManagerModal | ReceivingTasksDashboard.svelte:616 | ❌ |
| Desktop | ReceivingTasksDashboard | DELETE: removePRExcelFile | ReceivingTasksDashboard.svelte:686 | ❌ |
| Desktop | ReceivingTasksDashboard | DELETE: removeOriginalBillFile | ReceivingTasksDashboard.svelte:736 | ❌ |
| Desktop | ReceivingTasksDashboard | OTHER: Cancel | ReceivingTasksDashboard.svelte:770 | ❌ |
| Desktop | ReceivingTasksDashboard | SAVE: {#if isSubmittingInventoryTask}  | ReceivingTasksDashboard.svelte:777 | ❌ |
| Desktop | RecurringExpenseScheduler | CREATE: + Add Custom Dates | RecurringExpenseScheduler.svelte:960 | ❌ |
| Desktop | RecurringExpenseScheduler | DELETE: removeCustomDate(date)}>× | RecurringExpenseScheduler.svelte:969 | ❌ |
| Desktop | RecurringExpenseScheduler | OTHER: × | RecurringExpenseScheduler.svelte:986 | ❌ |
| Desktop | RecurringExpenseScheduler | OTHER: Done | RecurringExpenseScheduler.svelte:1006 | ❌ |
| Desktop | RecurringExpenseScheduler | OTHER: 📱 Share via WhatsApp | RecurringExpenseScheduler.svelte:1022 | ❌ |
| Desktop | RecurringExpenseScheduler | CREATE: ➕ New Schedule | RecurringExpenseScheduler.svelte:1026 | ❌ |
| Desktop | RecurringExpenseScheduler | OTHER: ← Previous | RecurringExpenseScheduler.svelte:1038 | ❌ |
| Desktop | RecurringExpenseScheduler | OTHER: Next → | RecurringExpenseScheduler.svelte:1042 | ❌ |
| Desktop | RecurringExpenseScheduler | ASSIGN: {#if saving} Submitting... {:else}  | RecurringExpenseScheduler.svelte:1044 | ❌ |
| Desktop | ReportingMap | EDIT: Cancel | ReportingMap.svelte:305 | ❌ |
| Desktop | ReportingMap | EDIT: {#if isLoading} {isEditing ? 'Upd | ReportingMap.svelte:309 | ❌ |
| Desktop | ReportingMap | CREATE: 🔄 Refresh | ReportingMap.svelte:326 | ❌ |
| Desktop | ReportingMap | EDIT: editReportingMap(map)} disabled={isLo | ReportingMap.svelte:389 | ❌ |
| Desktop | ReportingMap | DELETE: deleteReportingMap(map.id)} disabled= | ReportingMap.svelte:397 | ❌ |
| Desktop | RequestClosureManager | OTHER: Next Step → | RequestClosureManager.svelte:893 | ❌ |
| Desktop | RequestClosureManager | OTHER: ← Previous | RequestClosureManager.svelte:936 | ❌ |
| Desktop | RequestClosureManager | OTHER: Next Step → | RequestClosureManager.svelte:943 | ❌ |
| Desktop | RequestClosureManager | SAVE: selectBill(index)} > Bill {bill.numbe | RequestClosureManager.svelte:991 | ❌ |
| Desktop | RequestClosureManager | EDIT: Cancel | RequestClosureManager.svelte:1269 | ❌ |
| Desktop | RequestClosureManager | EDIT: saveBill(activeBillIndex)} disabled={bil | RequestClosureManager.svelte:1276 | ❌ |
| Desktop | RequestClosureManager | OTHER: ← Previous | RequestClosureManager.svelte:1333 | ❌ |
| Desktop | RequestClosureManager | OTHER: {saving ? 'Processing...' : 'Close Request'} | RequestClosureManager.svelte:1341 | ❌ |
| Desktop | RequestGenerator | DELETE: Clear | RequestGenerator.svelte:1183 | ❌ |
| Desktop | RequestGenerator | CREATE: 💾 Save Requester | RequestGenerator.svelte:1202 | ❌ |
| Desktop | RequestGenerator | DELETE: ❌ Clear Selection | RequestGenerator.svelte:1288 | ❌ |
| Desktop | RequestGenerator | OTHER: 🎨 Generate Request | RequestGenerator.svelte:1403 | ❌ |
| Desktop | RequestGenerator | VIEW: showTemplateModal = true}> �️ View Requisit | RequestGenerator.svelte:1413 | ❌ |
| Desktop | RequestGenerator | OTHER: 📱 Share to WhatsApp | RequestGenerator.svelte:1419 | ❌ |
| Desktop | RequestGenerator | CREATE: Create New Requisition | RequestGenerator.svelte:1423 | ❌ |
| Desktop | RequestGenerator | OTHER: ← Previous | RequestGenerator.svelte:1434 | ❌ |
| Desktop | RequestGenerator | OTHER: Next → | RequestGenerator.svelte:1437 | ❌ |
| Desktop | RequestGenerator | OTHER: 🖨️ Print | RequestGenerator.svelte:1454 | ❌ |
| Desktop | RequestGenerator | OTHER: × | RequestGenerator.svelte:1457 | ❌ |
| Desktop | RequestGenerator | SAVE: {isSaving ? '💾 Saving...' : '💾 Save Requisition' | RequestGenerator.svelte:1635 | ❌ |
| Desktop | RequestGenerator | OTHER: Close | RequestGenerator.svelte:1650 | ❌ |
| Desktop | RequestsManager | EXPORT: 📥 Export CSV | RequestsManager.svelte:286 | ❌ |
| Desktop | RequestsManager | OTHER: handleStatusFilter('all')}> 📊 {s | RequestsManager.svelte:299 | ❌ |
| Desktop | RequestsManager | OTHER: handleStatusFilter('all')}> ✔️ {s | RequestsManager.svelte:307 | ❌ |
| Desktop | RequestsManager | OTHER: handleStatusFilter('all')}> 🚫 {s | RequestsManager.svelte:315 | ❌ |
| Desktop | RequestsManager | OTHER: handleStatusFilter('pending')}> ⏳  | RequestsManager.svelte:323 | ❌ |
| Desktop | RequestsManager | APPROVE: handleStatusFilter('approved')}> ✅  | RequestsManager.svelte:331 | ❌ |
| Desktop | RequestsManager | APPROVE: handleStatusFilter('rejected')}> ❌  | RequestsManager.svelte:339 | ❌ |
| Desktop | RequestsManager | VIEW: openDetail(req)}> 👁️ View | RequestsManager.svelte:439 | ❌ |
| Desktop | RequestsManager | OTHER: 🔒 Closed | RequestsManager.svelte:443 | ❌ |
| Desktop | RequestsManager | OTHER: 🔒 Closed | RequestsManager.svelte:451 | ❌ |
| Desktop | RequestsManager | OTHER: openWindow({ id: `request-closure-${ | RequestsManager.svelte:458 | ❌ |
| Desktop | RequestsManager | OTHER: × | RequestsManager.svelte:494 | ❌ |
| Desktop | SalaryManagement | DELETE: searchQuery = ''} > Clear Search | SalaryManagement.svelte:520 | ❌ |
| Desktop | SalaryManagement | EDIT: openSalaryWindow(employee)} title="Up | SalaryManagement.svelte:598 | ❌ |
| Desktop | SalesReport | OTHER: loadSalesData | SalesReport.svelte:664 | ❌ |
| Desktop | SalesReport | OTHER: loadBranchSalesData | SalesReport.svelte:728 | ❌ |
| Desktop | SalesReport | OTHER: loadYesterdayBranchSalesData | SalesReport.svelte:790 | ❌ |
| Desktop | Scheduler | ASSIGN: 📄 Single Bill Scheduling Schedule a one | Scheduler.svelte:42 | ❌ |
| Desktop | Scheduler | ASSIGN: 📋 Multiple Bill Scheduling Schedule pay | Scheduler.svelte:49 | ❌ |
| Desktop | Scheduler | ASSIGN: 🔄 Recurring Expense Scheduler Schedule re | Scheduler.svelte:56 | ❌ |
| Desktop | Scheduler | ASSIGN: ← Back to Scheduler | Scheduler.svelte:66 | ❌ |
| Desktop | Scheduler | ASSIGN: ← Back to Scheduler | Scheduler.svelte:71 | ❌ |
| Desktop | SendWarningModal | OTHER: onClose | SendWarningModal.svelte:243 | ❌ |
| Desktop | SendWarningModal | OTHER: Cancel | SendWarningModal.svelte:396 | ❌ |
| Desktop | SendWarningModal | OTHER: {#if isGenerating} Generating...  | SendWarningModal.svelte:397 | ❌ |
| Desktop | Settings | OTHER: selectCategory(category.id)} >  | Settings.svelte:69 | ❌ |
| Desktop | Settings | DELETE: {#if isClearing}  | Settings.svelte:188 | ❌ |
| Desktop | ShelfPaperTemplateDesigner | CREATE: ➕ New | ShelfPaperTemplateDesigner.svelte:423 | ❌ |
| Desktop | ShelfPaperTemplateDesigner | OTHER: { templateImage = null; fieldSelectors = []; }}>  | ShelfPaperTemplateDesigner.svelte:472 | ❌ |
| Desktop | ShelfPaperTemplateDesigner | CREATE: ➕ Add Field | ShelfPaperTemplateDesigner.svelte:482 | ❌ |
| Desktop | ShelfPaperTemplateDesigner | DELETE: deleteField(field.id)}>🗑️ | ShelfPaperTemplateDesigner.svelte:491 | ❌ |
| Desktop | ShelfPaperTemplateDesigner | UPLOAD: {isUploading ? 'Saving...' : '💾 Save Template'} | ShelfPaperTemplateDesigner.svelte:562 | ❌ |
| Desktop | SingleBillScheduling | OTHER: 📱 Share via WhatsApp | SingleBillScheduling.svelte:1165 | ❌ |
| Desktop | SingleBillScheduling | CREATE: ➕ New Schedule | SingleBillScheduling.svelte:1169 | ❌ |
| Desktop | SingleBillScheduling | OTHER: ← Previous | SingleBillScheduling.svelte:1182 | ❌ |
| Desktop | SingleBillScheduling | OTHER: Next → | SingleBillScheduling.svelte:1186 | ❌ |
| Desktop | SingleBillScheduling | ASSIGN: {#if saving || uploading} Submitting...  | SingleBillScheduling.svelte:1188 | ❌ |
| Desktop | StartReceiving | OTHER: Change Branch | StartReceiving.svelte:2498 | ❌ |
| Desktop | StartReceiving | OTHER: selectedBranchManager = null} class="change-user-b | StartReceiving.svelte:2527 | ❌ |
| Desktop | StartReceiving | VIEW: Select Responsible User Instead | StartReceiving.svelte:2545 | ❌ |
| Desktop | StartReceiving | OTHER: selectBranchManager(user)}  | StartReceiving.svelte:2604 | ❌ |
| Desktop | StartReceiving | OTHER: selectedPurchasingManager = null} class="change-pu | StartReceiving.svelte:2660 | ❌ |
| Desktop | StartReceiving | VIEW: Select Any User as Purchasing Manager | StartReceiving.svelte:2678 | ❌ |
| Desktop | StartReceiving | OTHER: selectPurchasingManager(user)}  | StartReceiving.svelte:2746 | ❌ |
| Desktop | StartReceiving | OTHER: selectedInventoryManager = null} class="change-inv | StartReceiving.svelte:2805 | ❌ |
| Desktop | StartReceiving | VIEW: Select Any User as Inventory Manager | StartReceiving.svelte:2822 | ❌ |
| Desktop | StartReceiving | OTHER: selectInventoryManager(user)}  | StartReceiving.svelte:2874 | ❌ |
| Desktop | StartReceiving | DELETE: removeNightSupervisor(supervisor.id)}  | StartReceiving.svelte:2926 | ❌ |
| Desktop | StartReceiving | VIEW: Select Any Users as Night Supervisors | StartReceiving.svelte:2952 | ❌ |
| Desktop | StartReceiving | DELETE: removeNightSupervisor(user.id)}  | StartReceiving.svelte:3006 | ❌ |
| Desktop | StartReceiving | OTHER: selectNightSupervisor(user)}  | StartReceiving.svelte:3014 | ❌ |
| Desktop | StartReceiving | DELETE: × | StartReceiving.svelte:3067 | ❌ |
| Desktop | StartReceiving | VIEW: Select Any Users as Warehouse Handlers | StartReceiving.svelte:3091 | ❌ |
| Desktop | StartReceiving | DELETE: Remove | StartReceiving.svelte:3145 | ❌ |
| Desktop | StartReceiving | OTHER: selectWarehouseHandler(user)}  | StartReceiving.svelte:3153 | ❌ |
| Desktop | StartReceiving | DELETE: × | StartReceiving.svelte:3221 | ❌ |
| Desktop | StartReceiving | VIEW: Select Any User as Shelf Stocker | StartReceiving.svelte:3246 | ❌ |
| Desktop | StartReceiving | DELETE: Remove | StartReceiving.svelte:3303 | ❌ |
| Desktop | StartReceiving | OTHER: selectShelfStocker(user)}  | StartReceiving.svelte:3311 | ❌ |
| Desktop | StartReceiving | OTHER: selectedAccountant = null} class="change-accountan | StartReceiving.svelte:3368 | ❌ |
| Desktop | StartReceiving | VIEW: Select Any User as Accountant | StartReceiving.svelte:3386 | ❌ |
| Desktop | StartReceiving | OTHER: selectAccountant(user)} > | StartReceiving.svelte:3441 | ❌ |
| Desktop | StartReceiving | OTHER: Retry | StartReceiving.svelte:3477 | ❌ |
| Desktop | StartReceiving | SAVE: ✓ Confirm Branch | StartReceiving.svelte:3497 | ❌ |
| Desktop | StartReceiving | OTHER: currentStep = 1} class="continue-step-btn" | StartReceiving.svelte:3520 | ❌ |
| Desktop | StartReceiving | OTHER: Change Vendor | StartReceiving.svelte:3543 | ❌ |
| Desktop | StartReceiving | DELETE: searchQuery = ''}>× | StartReceiving.svelte:3560 | ❌ |
| Desktop | StartReceiving | VIEW: showColumnSelector = !showColumnSelector}>  | StartReceiving.svelte:3571 | ❌ |
| Desktop | StartReceiving | VIEW: toggleAllColumns(true)}>✅ Show All | StartReceiving.svelte:3579 | ❌ |
| Desktop | StartReceiving | OTHER: toggleAllColumns(false)}>❌ Hide All | StartReceiving.svelte:3580 | ❌ |
| Desktop | StartReceiving | OTHER: Retry | StartReceiving.svelte:3607 | ❌ |
| Desktop | StartReceiving | DELETE: searchQuery = ''}>Clear Search | StartReceiving.svelte:3615 | ❌ |
| Desktop | StartReceiving | OTHER: window.open(vendor.location_link, '_blank')}>  | StartReceiving.svelte:3766 | ❌ |
| Desktop | StartReceiving | OTHER: selectVendor(vendor)}>  | StartReceiving.svelte:3877 | ❌ |
| Desktop | StartReceiving | EDIT: openEditWindow(vendor)}>  | StartReceiving.svelte:3880 | ❌ |
| Desktop | StartReceiving | OTHER: currentStep = 2} class="continue-step-btn">  | StartReceiving.svelte:3904 | ❌ |
| Desktop | StartReceiving | OTHER: ← Back to Vendor Selection | StartReceiving.svelte:4376 | ❌ |
| Desktop | StartReceiving | OTHER: Continue to Receiving → | StartReceiving.svelte:4379 | ❌ |
| Desktop | StartReceiving | OTHER: currentStep = 1}> ← Back to Vendor Select | StartReceiving.svelte:4388 | ❌ |
| Desktop | StartReceiving | SAVE: 💾 Save & Continue to Certification → | StartReceiving.svelte:4403 | ❌ |
| Desktop | StartReceiving | SAVE: 💾 Complete Step 3 to Continue → | StartReceiving.svelte:4427 | ❌ |
| Desktop | StartReceiving | DELETE: � Generate Clearance Certificate | StartReceiving.svelte:4445 | ❌ |
| Desktop | StartReceiving | DELETE: � Generate Clearance Certificate | StartReceiving.svelte:4449 | ❌ |
| Desktop | StartReceiving | OTHER: currentStep = 2}> ← Back to Bill Informat | StartReceiving.svelte:4458 | ❌ |
| Desktop | StartReceiving | EDIT: × | StartReceiving.svelte:8215 | ❌ |
| Desktop | StartReceiving | EDIT: {isUpdatingVendor ? 'Updating...' : 'Update & Cont | StartReceiving.svelte:8261 | ❌ |
| Desktop | StartReceiving | EDIT: handlePaymentUpdateCancel()}> Cancel | StartReceiving.svelte:8288 | ❌ |
| Desktop | StartReceiving | EDIT: handlePaymentUpdateConfirm()}> OK | StartReceiving.svelte:8291 | ❌ |
| Desktop | StartReceiving | EDIT: closeVendorUpdatedModal()}> OK | StartReceiving.svelte:8314 | ❌ |
| Desktop | StartReceiving | EDIT: closeVendorInfoUpdatedModal()}> OK | StartReceiving.svelte:8337 | ❌ |
| Desktop | StartReceiving | SAVE: closeReceivingSuccessModal()}> OK | StartReceiving.svelte:8360 | ❌ |
| Desktop | TaskAssignmentView | CREATE: New Task | TaskAssignmentView.svelte:816 | ❌ |
| Desktop | TaskAssignmentView | VIEW: Stats | TaskAssignmentView.svelte:826 | ❌ |
| Desktop | TaskAssignmentView | CREATE: Refresh | TaskAssignmentView.svelte:836 | ❌ |
| Desktop | TaskAssignmentView | VIEW: switchView('users')} class="flex items-center | TaskAssignmentView.svelte:852 | ❌ |
| Desktop | TaskAssignmentView | VIEW: switchView('tasks')} class="flex items-center | TaskAssignmentView.svelte:871 | ❌ |
| Desktop | TaskAssignmentView | ASSIGN: switchView('settings')} class="flex items-cen | TaskAssignmentView.svelte:890 | ❌ |
| Desktop | TaskAssignmentView | OTHER: Cancel | TaskAssignmentView.svelte:1081 | ❌ |
| Desktop | TaskAssignmentView | VIEW: switchView('tasks')} disabled={selectedUse | TaskAssignmentView.svelte:1087 | ❌ |
| Desktop | TaskAssignmentView | CREATE: New Task | TaskAssignmentView.svelte:1112 | ❌ |
| Desktop | TaskAssignmentView | CREATE: Refresh | TaskAssignmentView.svelte:1121 | ❌ |
| Desktop | TaskAssignmentView | DELETE: {taskSearchTerm = ''; taskStatusFilter = ''; taskP | TaskAssignmentView.svelte:1193 | ❌ |
| Desktop | TaskAssignmentView | CREATE: Create New Task | TaskAssignmentView.svelte:1216 | ❌ |
| Desktop | TaskAssignmentView | OTHER: openImageModal(task.image_url)} cl | TaskAssignmentView.svelte:1264 | ❌ |
| Desktop | TaskAssignmentView | EDIT: editTask(task)} class="text-purple- | TaskAssignmentView.svelte:1332 | ❌ |
| Desktop | TaskAssignmentView | VIEW: switchView('users')} class="px-6 py-2 bord | TaskAssignmentView.svelte:1350 | ❌ |
| Desktop | TaskAssignmentView | VIEW: {if (selectedTasks.size > 0) currentView = 'settin | TaskAssignmentView.svelte:1359 | ❌ |
| Desktop | TaskAssignmentView | VIEW: switchView('tasks')} class="px-6 py-2 borde | TaskAssignmentView.svelte:1737 | ❌ |
| Desktop | TaskAssignmentView | OTHER: Cancel | TaskAssignmentView.svelte:1747 | ❌ |
| Desktop | TaskAssignmentView | VIEW: currentView = 'criteria'} disabled={select | TaskAssignmentView.svelte:1754 | ❌ |
| Desktop | TaskAssignmentView | VIEW: currentView = 'settings'} class="px-6 py-2  | TaskAssignmentView.svelte:1868 | ❌ |
| Desktop | TaskAssignmentView | OTHER: Cancel | TaskAssignmentView.svelte:1878 | ❌ |
| Desktop | TaskAssignmentView | ASSIGN: {#if isAssigning}  | TaskAssignmentView.svelte:1885 | ❌ |
| Desktop | TaskAssignmentView | OTHER: closeImageModal | TaskAssignmentView.svelte:1915 | ❌ |
| Desktop | TaskAssignmentView | OTHER: closeImageModal | TaskAssignmentView.svelte:1938 | ❌ |
| Desktop | TaskAssignmentViewNew | CREATE: New Task | TaskAssignmentViewNew.svelte:431 | ❌ |
| Desktop | TaskAssignmentViewNew | VIEW: Stats | TaskAssignmentViewNew.svelte:441 | ❌ |
| Desktop | TaskAssignmentViewNew | CREATE: Refresh | TaskAssignmentViewNew.svelte:451 | ❌ |
| Desktop | TaskAssignmentViewNew | VIEW: switchView('users')} class="flex items-center | TaskAssignmentViewNew.svelte:467 | ❌ |
| Desktop | TaskAssignmentViewNew | VIEW: switchView('tasks')} class="flex items-center | TaskAssignmentViewNew.svelte:486 | ❌ |
| Desktop | TaskAssignmentViewNew | ASSIGN: switchView('settings')} class="flex items-cen | TaskAssignmentViewNew.svelte:505 | ❌ |
| Desktop | TaskAssignmentViewNew | OTHER: Cancel | TaskAssignmentViewNew.svelte:641 | ❌ |
| Desktop | TaskAssignmentViewNew | VIEW: switchView('tasks')} disabled={selectedUse | TaskAssignmentViewNew.svelte:647 | ❌ |
| Desktop | TaskAssignmentViewNew | DELETE: {taskSearchTerm = ''; taskStatusFilter = ''; taskP | TaskAssignmentViewNew.svelte:700 | ❌ |
| Desktop | TaskAssignmentViewNew | EDIT: Edit | TaskAssignmentViewNew.svelte:768 | ❌ |
| Desktop | TaskAssignmentViewNew | CREATE: Create New Task | TaskAssignmentViewNew.svelte:785 | ❌ |
| Desktop | TaskAssignmentViewNew | VIEW: switchView('users')} class="px-6 py-2 bord | TaskAssignmentViewNew.svelte:798 | ❌ |
| Desktop | TaskAssignmentViewNew | VIEW: switchView('settings')} disabled={selected | TaskAssignmentViewNew.svelte:807 | ❌ |
| Desktop | TaskAssignmentViewNew | VIEW: switchView('tasks')} class="px-6 py-2 bord | TaskAssignmentViewNew.svelte:1072 | ❌ |
| Desktop | TaskAssignmentViewNew | OTHER: Cancel | TaskAssignmentViewNew.svelte:1082 | ❌ |
| Desktop | TaskAssignmentViewNew | ASSIGN: {#if isAssigning}  | TaskAssignmentViewNew.svelte:1089 | ❌ |
| Desktop | TaskCompletionModal | OTHER: handleClose | TaskCompletionModal.svelte:883 | ❌ |
| Desktop | TaskCompletionModal | VIEW: showTaskDetails = !showTaskDetails} > { | TaskCompletionModal.svelte:901 | ❌ |
| Desktop | TaskCompletionModal | ASSIGN: 👥 Reassign Task | TaskCompletionModal.svelte:1012 | ❌ |
| Desktop | TaskCompletionModal | ASSIGN: 👥 Reassign Task | TaskCompletionModal.svelte:1041 | ❌ |
| Desktop | TaskCompletionModal | DELETE: removePhoto | TaskCompletionModal.svelte:1138 | ❌ |
| Desktop | TaskCompletionModal | OTHER: Cancel | TaskCompletionModal.svelte:1184 | ❌ |
| Desktop | TaskCompletionModal | SAVE: {#if isSubmitting} Completing... {: | TaskCompletionModal.svelte:1187 | ❌ |
| Desktop | TaskCompletionModal | ASSIGN: × | TaskCompletionModal.svelte:1208 | ❌ |
| Desktop | TaskCompletionModal | ASSIGN: Cancel | TaskCompletionModal.svelte:1232 | ❌ |
| Desktop | TaskCompletionModal | ASSIGN: {#if isSubmitting} Reassigning...  | TaskCompletionModal.svelte:1233 | ❌ |
| Desktop | TaskCompletionModal | OTHER: closeImageModal | TaskCompletionModal.svelte:1254 | ❌ |
| Desktop | TaskCreateForm | OTHER: Cancel | TaskCreateForm.svelte:302 | ❌ |
| Desktop | TaskCreateForm | CREATE: {isSubmitting ? (editMode ? 'Updating...' | TaskCreateForm.svelte:310 | ❌ |
| Desktop | TaskDetailsModal | OTHER: Complete Task | TaskDetailsModal.svelte:356 | ❌ |
| Desktop | TaskDetailsModal | OTHER: Close | TaskDetailsModal.svelte:375 | ❌ |
| Desktop | TaskDetailsView | OTHER: Select All | TaskDetailsView.svelte:1421 | ❌ |
| Desktop | TaskDetailsView | OTHER: Deselect All | TaskDetailsView.svelte:1427 | ❌ |
| Desktop | TaskDetailsView | SEND: {#if isSendingReminders}  | TaskDetailsView.svelte:1439 | ❌ |
| Desktop | TaskDetailsView | SEND: Send to All Overdue | TaskDetailsView.svelte:1458 | ❌ |
| Desktop | TaskDetailsView | OTHER: {isLoadingMore ? 'Loading...' : 'Load More Tasks'} | TaskDetailsView.svelte:1624 | ❌ |
| Desktop | TaskDetailsView | OTHER: closeTaskDetail | TaskDetailsView.svelte:1643 | ❌ |
| Desktop | TaskDetailsView | OTHER: closeReminderStats | TaskDetailsView.svelte:1726 | ❌ |
| Desktop | TaskDetailsView | OTHER: Close | TaskDetailsView.svelte:1750 | ❌ |
| Desktop | TaskMaster | OTHER: Quick Task | TaskMaster.svelte:419 | ❌ |
| Desktop | TaskMaster | OTHER: Refresh | TaskMaster.svelte:429 | ❌ |
| Desktop | TaskStatusView | CREATE: Refresh | TaskStatusView.svelte:579 | ❌ |
| Desktop | TaskStatusView | OTHER: setBranchFilter('all')} > All Branche | TaskStatusView.svelte:650 | ❌ |
| Desktop | TaskStatusView | OTHER: setBranchFilter('choose')} > Choose B | TaskStatusView.svelte:656 | ❌ |
| Desktop | TaskStatusView | ASSIGN: sendReminder(assignment)} >  | TaskStatusView.svelte:770 | ❌ |
| Desktop | TaskStatusView | ASSIGN: openWarningModal(assignment)} >  | TaskStatusView.svelte:776 | ❌ |
| Desktop | TaskViewTable | OTHER: Refresh | TaskViewTable.svelte:305 | ❌ |
| Desktop | TaskViewTable | OTHER: Search | TaskViewTable.svelte:361 | ❌ |
| Desktop | TaskViewTable | EDIT: Bulk Edit | TaskViewTable.svelte:381 | ❌ |
| Desktop | TaskViewTable | DELETE: Delete Selected | TaskViewTable.svelte:384 | ❌ |
| Desktop | TaskViewTable | OTHER: handleSort('title')} class="flex items-ce | TaskViewTable.svelte:421 | ❌ |
| Desktop | TaskViewTable | OTHER: handleSort('due_date')} class="flex items | TaskViewTable.svelte:447 | ❌ |
| Desktop | TaskViewTable | CREATE: handleSort('created_at')} class="flex ite | TaskViewTable.svelte:464 | ❌ |
| Desktop | TaskViewTable | VIEW: openImageModal(task.image_url)} class= | TaskViewTable.svelte:511 | ❌ |
| Desktop | TaskViewTable | EDIT: editTask(task)} class="text-blue-600 ho | TaskViewTable.svelte:571 | ❌ |
| Desktop | TaskViewTable | DELETE: deleteTask(task.id)} class="text-red-60 | TaskViewTable.svelte:580 | ❌ |
| Desktop | TaskViewTable | OTHER: changePage(currentPage - 1)} disabled={curre | TaskViewTable.svelte:602 | ❌ |
| Desktop | TaskViewTable | OTHER: changePage(currentPage + 1)} disabled={curre | TaskViewTable.svelte:609 | ❌ |
| Desktop | TaskViewTable | OTHER: changePage(currentPage - 1)} disabled={cur | TaskViewTable.svelte:627 | ❌ |
| Desktop | TaskViewTable | OTHER: changePage(page)} class="relative inline- | TaskViewTable.svelte:642 | ❌ |
| Desktop | TaskViewTable | OTHER: changePage(currentPage + 1)} disabled={cur | TaskViewTable.svelte:650 | ❌ |
| Desktop | TaskViewTable | OTHER: closeImageModal | TaskViewTable.svelte:680 | ❌ |
| Desktop | TaxManager | CREATE: ➕ Add Tax Category | TaxManager.svelte:112 | ❌ |
| Desktop | TaxManager | CREATE: Create First Tax Category | TaxManager.svelte:128 | ❌ |
| Desktop | TaxManager | OTHER: toggleActive(tax)} > {tax.is_ac | TaxManager.svelte:150 | ❌ |
| Desktop | TaxManager | DELETE: deleteTax(tax)} title="Delete"  | TaxManager.svelte:161 | ❌ |
| Desktop | TierManager | CREATE: + {isRTL ? 'إضافة مستوى' : 'Add Tier'} | TierManager.svelte:58 | ❌ |
| Desktop | TierManager | DELETE: removeTier(index)} title={isRTL ? 'حذف ال | TierManager.svelte:134 | ❌ |
| Desktop | TotalTasksView | OTHER: {isLoadingMore ? 'Loading...' : `Load More Tasks ( | TotalTasksView.svelte:668 | ❌ |
| Desktop | UploadEmployees | DELETE: × | UploadEmployees.svelte:254 | ❌ |
| Desktop | UploadEmployees | EXPORT: ⬇️ {t('hr.downloadTemplate')} | UploadEmployees.svelte:287 | ❌ |
| Desktop | UploadEmployees | UPLOAD: {#if isLoading} {t('hr.uploading')}  | UploadEmployees.svelte:303 | ❌ |
| Desktop | UploadFingerprint | EXPORT: 📥 Download Template | UploadFingerprint.svelte:357 | ❌ |
| Desktop | UploadFingerprint | UPLOAD: fileInput?.click()} disabled={isUploading} | UploadFingerprint.svelte:409 | ❌ |
| Desktop | UploadFingerprint | DELETE: ❌ | UploadFingerprint.svelte:427 | ❌ |
| Desktop | UploadFingerprint | UPLOAD: {#if isUploading} Processing...  | UploadFingerprint.svelte:472 | ❌ |
| Desktop | UploadFingerprint | UPLOAD: {#if isUploading} Saving... | UploadFingerprint.svelte:521 | ❌ |
| Desktop | UploadFingerprint | CREATE: 🔄 Upload New File | UploadFingerprint.svelte:540 | ❌ |
| Desktop | UploadVendor | EXPORT: 📥 Download Template | UploadVendor.svelte:387 | ❌ |
| Desktop | UploadVendor | DELETE: × | UploadVendor.svelte:426 | ❌ |
| Desktop | UploadVendor | UPLOAD: 🔄 Reset Upload | UploadVendor.svelte:555 | ❌ |
| Desktop | UploadVendor | UPLOAD: {#if isUploading} Uploading... {:else}  | UploadVendor.svelte:558 | ❌ |
| Desktop | UserManagement | CREATE: 🔄 Retry | UserManagement.svelte:169 | ❌ |
| Desktop | UserManagement | DELETE: { searchQuery = ''; branchFilter | UserManagement.svelte:214 | ❌ |
| Desktop | UserManagement | EDIT: editUser(user)} title="Edit User"  | UserManagement.svelte:307 | ❌ |
| Desktop | UserManagement | OTHER: toggleUserStatus(user)} title={user.st | UserManagement.svelte:314 | ❌ |
| Desktop | UserManagement | OTHER: toggleUserLock(user)} title={user.stat | UserManagement.svelte:324 | ❌ |
| Desktop | VariationManager | VIEW: {showGroupsView ? '📦 Products View' : '🔗 Groups  | VariationManager.svelte:664 | ❌ |
| Desktop | VariationManager | OTHER: Deselect All | VariationManager.svelte:687 | ❌ |
| Desktop | VariationManager | EDIT: Update Group ({selectedProducts.size}) | VariationManager.svelte:694 | ❌ |
| Desktop | VariationManager | EDIT: { isEditMode = false; groupParen | VariationManager.svelte:701 | ❌ |
| Desktop | VariationManager | CREATE: Create Group ({selectedProducts.size}) | VariationManager.svelte:714 | ❌ |
| Desktop | VariationManager | VIEW: Go to Products View | VariationManager.svelte:751 | ❌ |
| Desktop | VariationManager | EDIT: openEditGroupModal(group.parent.barcode, group.par | VariationManager.svelte:796 | ❌ |
| Desktop | VariationManager | DELETE: deleteGroup(group.parent.barcode, group.parent.var | VariationManager.svelte:802 | ❌ |
| Desktop | VariationManager | OTHER: ← Previous | VariationManager.svelte:872 | ❌ |
| Desktop | VariationManager | OTHER: Next → | VariationManager.svelte:879 | ❌ |
| Desktop | VariationManager | OTHER: Select All (page) | VariationManager.svelte:905 | ❌ |
| Desktop | VariationManager | OTHER: currentPage = Math.max(1, currentPage - 1)}  | VariationManager.svelte:1003 | ❌ |
| Desktop | VariationManager | OTHER: currentPage = pageNum} class="px-3 py-2 | VariationManager.svelte:1015 | ❌ |
| Desktop | VariationManager | OTHER: currentPage = Math.min(totalPages, currentPage + 1 | VariationManager.svelte:1026 | ❌ |
| Desktop | VariationManager | OTHER: Cancel | VariationManager.svelte:1163 | ❌ |
| Desktop | VariationManager | CREATE: {#if isCreatingGroup} {isEditMode ? | VariationManager.svelte:1170 | ❌ |
| Desktop | VariationSelectionModal | OTHER: cancel | VariationSelectionModal.svelte:120 | ❌ |
| Desktop | VariationSelectionModal | OTHER: {selectAll ? 'Deselect All' : 'Select All'} | VariationSelectionModal.svelte:146 | ❌ |
| Desktop | VariationSelectionModal | OTHER: In Stock Only | VariationSelectionModal.svelte:152 | ❌ |
| Desktop | VariationSelectionModal | OTHER: Cancel | VariationSelectionModal.svelte:263 | ❌ |
| Desktop | VariationSelectionModal | CREATE: Add Selected ({selectedCount}) | VariationSelectionModal.svelte:269 | ❌ |
| Desktop | VendorPendingPayments | DELETE: Clear | VendorPendingPayments.svelte:282 | ❌ |
| Desktop | VendorPendingPayments | OTHER: handleVendorSelect(vendor.vendor_id, vendor.vendor | VendorPendingPayments.svelte:297 | ❌ |
| Desktop | VendorPendingPayments | OTHER: ← Previous | VendorPendingPayments.svelte:395 | ❌ |
| Desktop | VendorPendingPayments | OTHER: Next → | VendorPendingPayments.svelte:415 | ❌ |
| Desktop | VendorRecords | OTHER: loadRecords()} disabled={loadingRecords}> {l | VendorRecords.svelte:202 | ❌ |
| Desktop | VendorRecords | OTHER: { currentPage = 1; loadRecords(); }} disabled={loa | VendorRecords.svelte:264 | ❌ |
| Desktop | VendorRecords | DELETE: Clear Filters | VendorRecords.svelte:268 | ❌ |
| Desktop | VendorRecords | OTHER: ← Previous | VendorRecords.svelte:389 | ❌ |
| Desktop | VendorRecords | OTHER: Next → | VendorRecords.svelte:411 | ❌ |
| Desktop | VideoTemplatesManager | VIEW: previewVideo(slot)}> Preview | VideoTemplatesManager.svelte:336 | ❌ |
| Desktop | VideoTemplatesManager | EDIT: saveSlot(slot.slot_number)} disabled={slot | VideoTemplatesManager.svelte:435 | ❌ |
| Desktop | VideoTemplatesManager | OTHER: toggleActive(slot.slot_number)} disabled= | VideoTemplatesManager.svelte:444 | ❌ |
| Desktop | VideoTemplatesManager | VIEW: × | VideoTemplatesManager.svelte:466 | ❌ |
| Desktop | ViewOfferManager | CREATE: ➕ Add Offer | ViewOfferManager.svelte:188 | ❌ |
| Desktop | ViewOfferManager | EDIT: openEditOfferWindow(offer.id, offer.offer_name)}  | ViewOfferManager.svelte:250 | ❌ |
| Desktop | WarningDetailsModal | OTHER: onClose | WarningDetailsModal.svelte:150 | ❌ |
| Desktop | WarningDetailsModal | OTHER: {isUpdating ? 'Processing...' : 'Mark as Paid'} | WarningDetailsModal.svelte:297 | ❌ |
| Desktop | WarningDetailsModal | EDIT: {isUpdating ? 'Updating...' : 'Update Warning'} | WarningDetailsModal.svelte:348 | ❌ |
| Desktop | WarningListView | OTHER: Refresh | WarningListView.svelte:236 | ❌ |
| Desktop | WarningListView | VIEW: viewWarningTemplate(warning)} title="Vie | WarningListView.svelte:346 | ❌ |
| Desktop | WarningListView | OTHER: changePage(currentPage - 1)} > Previous | WarningListView.svelte:367 | ❌ |
| Desktop | WarningListView | OTHER: changePage(page)} > {page} | WarningListView.svelte:376 | ❌ |
| Desktop | WarningListView | OTHER: changePage(currentPage + 1)} > Next | WarningListView.svelte:384 | ❌ |
| Desktop | WarningMaster | OTHER: Refresh | WarningMaster.svelte:202 | ❌ |
| Desktop | WarningStatistics | EXPORT: Export Report | WarningStatistics.svelte:233 | ❌ |
| Desktop | WarningStatistics | OTHER: Refresh | WarningStatistics.svelte:239 | ❌ |
| Desktop | WarningTemplate | EDIT: {#if isEditing} Sa | WarningTemplate.svelte:1014 | ❌ |
| Desktop | WarningTemplate | OTHER: {t.print} | WarningTemplate.svelte:1027 | ❌ |
| Desktop | WarningTemplate | OTHER: closeModal | WarningTemplate.svelte:1033 | ❌ |
| Desktop | WarningTemplate | SAVE: {#if isSavingImage} {:else}  | WarningTemplate.svelte:1146 | ❌ |
| Desktop | WarningTemplate | SEND: {#if isSending} {:else}  | WarningTemplate.svelte:1164 | ❌ |
| Desktop | WarningTemplate | OTHER: 📱 Share to WhatsApp | WarningTemplate.svelte:1183 | ❌ |
| Desktop | WarningTemplateImageModal | EXPORT: Download | WarningTemplateImageModal.svelte:48 | ❌ |
| Desktop | WarningTemplateImageModal | CREATE: Open | WarningTemplateImageModal.svelte:54 | ❌ |
| Desktop | AddOfferDialog | CREATE: {isLoading ? (isEditing ? 'Updating...' : 'Adding. | AddOfferDialog.svelte:450 | ❌ |
| Desktop | CampaignManager | CREATE: ➕ {t('coupon.createCampaign')} | CampaignManager.svelte:298 | ❌ |
| Desktop | CampaignManager | OTHER: 🔄 {t('coupon.generate')} | CampaignManager.svelte:357 | ❌ |
| Desktop | CampaignManager | SAVE: {loading ? t('coupon.saving') : t('coupon.save')} | CampaignManager.svelte:445 | ❌ |
| Desktop | CampaignManager | OTHER: {t('coupon.cancel')} | CampaignManager.svelte:453 | ❌ |
| Desktop | CampaignManager | EDIT: openEditForm(campaign)} class="flex-1 p | CampaignManager.svelte:510 | ❌ |
| Desktop | CampaignManager | OTHER: toggleStatus(campaign)} class="flex-1 p | CampaignManager.svelte:516 | ❌ |
| Desktop | CampaignManager | DELETE: handleDelete(campaign)} class="px-3 py- | CampaignManager.svelte:522 | ❌ |
| Desktop | CouponDashboard | CREATE: {t('coupon.createFirst') || 'Create Your First Cam | CouponDashboard.svelte:47 | ❌ |
| Desktop | CouponReports | EXPORT: 📥 {t('common.export') || 'Export CSV'} | CouponReports.svelte:147 | ❌ |
| Desktop | CustomerImporter | EXPORT: ⬇️ {t('coupon.downloadTemplate')} | CustomerImporter.svelte:381 | ❌ |
| Desktop | CustomerImporter | OTHER: fileInput?.click()} class="px-8 py-3 bg-g | CustomerImporter.svelte:443 | ❌ |
| Desktop | CustomerImporter | UPLOAD: {importing ? '⏳ ' + t('coupon.importing') : '🚀 '  | CustomerImporter.svelte:527 | ❌ |
| Desktop | CustomerImporter | OTHER: ↻ {t('coupon.reset')} | CustomerImporter.svelte:534 | ❌ |
| Desktop | CustomerImporter | CREATE: showAddNumberModal = true} disabled={!sele | CustomerImporter.svelte:552 | ❌ |
| Desktop | CustomerImporter | DELETE: handleDeleteCustomer(customer.id)} d | CustomerImporter.svelte:596 | ❌ |
| Desktop | CustomerImporter | CREATE: ✅ {t('coupon.add')} | CustomerImporter.svelte:643 | ❌ |
| Desktop | CustomerImporter | CREATE: { showAddNumberModal = false; newNum | CustomerImporter.svelte:649 | ❌ |
| Desktop | DesignPlanner | OTHER: 🎨 Template Designer | DesignPlanner.svelte:992 | ❌ |
| Desktop | DesignPlanner | CREATE: loadOfferProducts(offer.id)} >  | DesignPlanner.svelte:1009 | ❌ |
| Desktop | DesignPlanner | OTHER: generateSizePDF('a4')} title="Generate A4 PDFs for | DesignPlanner.svelte:1052 | ❌ |
| Desktop | DesignPlanner | OTHER: generateSizePDF('a5')} title="Generate A5 PDFs for | DesignPlanner.svelte:1055 | ❌ |
| Desktop | DesignPlanner | OTHER: generateSizePDF('a6')} title="Generate A6 PDFs for | DesignPlanner.svelte:1058 | ❌ |
| Desktop | DesignPlanner | OTHER: generateSizePDF('a7')} title="Generate A7 PDFs for | DesignPlanner.svelte:1061 | ❌ |
| Desktop | DesignPlanner | OTHER: generatePDFWithTemplate(product)} title="Generate  | DesignPlanner.svelte:1272 | ❌ |
| Desktop | DesignPlanner | OTHER: generatePDF(product)}> Ge | DesignPlanner.svelte:1276 | ❌ |
| Desktop | FlyerGenerator | OTHER: activeTab = 'first'} > Fir | FlyerGenerator.svelte:1010 | ❌ |
| Desktop | FlyerGenerator | OTHER: { activeTab = 'sub'; activeSubPageIndex = 0; }}  | FlyerGenerator.svelte:1017 | ❌ |
| Desktop | FlyerGenerator | OTHER: openFieldsPopup('first', 0)} >  | FlyerGenerator.svelte:1033 | ❌ |
| Desktop | FlyerGenerator | OTHER: openFieldsPopup('sub', index)}  | FlyerGenerator.svelte:1049 | ❌ |
| Desktop | FlyerGenerator | OTHER: activeSubPageIndex = index} > | FlyerGenerator.svelte:1293 | ❌ |
| Desktop | FlyerGenerator | OTHER: closeFieldsPopup | FlyerGenerator.svelte:1528 | ❌ |
| Desktop | FlyerGenerator | ASSIGN: selectFieldFromPopup(field)} >  | FlyerGenerator.svelte:1546 | ❌ |
| Desktop | FlyerGenerator | VIEW: showProductSelector = false}> | FlyerGenerator.svelte:1594 | ❌ |
| Desktop | FlyerGenerator | ASSIGN: assignProductToField(product.barcode)}  | FlyerGenerator.svelte:1681 | ❌ |
| Desktop | FlyerGenerator | OTHER: selectedVariantImageIndex = idx}  | FlyerGenerator.svelte:1722 | ❌ |
| Desktop | FlyerGenerator | OTHER: ↔️ Move | FlyerGenerator.svelte:1738 | ❌ |
| Desktop | FlyerGenerator | OTHER: ↗️ Resize | FlyerGenerator.svelte:1743 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(-90)}>↶ -90° | FlyerGenerator.svelte:1753 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(-15)}>↶ -15° | FlyerGenerator.svelte:1754 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(-5)}>↶ -5° | FlyerGenerator.svelte:1755 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(-1)}>↶ -1° | FlyerGenerator.svelte:1756 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(1)}>↷ +1° | FlyerGenerator.svelte:1759 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(5)}>↷ +5° | FlyerGenerator.svelte:1760 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(15)}>↷ +15° | FlyerGenerator.svelte:1761 | ❌ |
| Desktop | FlyerGenerator | OTHER: rotateElement(90)}>↷ +90° | FlyerGenerator.svelte:1762 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyFontSize(-2)}>-2 | FlyerGenerator.svelte:1785 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyFontSize(-1)}>-1 | FlyerGenerator.svelte:1786 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyFontSize(1)}>+1 | FlyerGenerator.svelte:1787 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyFontSize(2)}>+2 | FlyerGenerator.svelte:1788 | ❌ |
| Desktop | FlyerGenerator | OTHER: Close | FlyerGenerator.svelte:1793 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextScale(-10)}>-10 | FlyerGenerator.svelte:1809 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextScale(-5)}>-5 | FlyerGenerator.svelte:1810 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextScale(5)}>+5 | FlyerGenerator.svelte:1811 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextScale(10)}>+10 | FlyerGenerator.svelte:1812 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextFontSize(-2)}>-2 | FlyerGenerator.svelte:1819 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextFontSize(-1)}>-1 | FlyerGenerator.svelte:1820 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextFontSize(1)}>+1 | FlyerGenerator.svelte:1821 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextFontSize(2)}>+2 | FlyerGenerator.svelte:1822 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(-90)}>↶ -90° | FlyerGenerator.svelte:1829 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(-15)}>↶ -15° | FlyerGenerator.svelte:1830 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(15)}>↷ +15° | FlyerGenerator.svelte:1831 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(90)}>↷ +90° | FlyerGenerator.svelte:1832 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(-5)}>↶ -5° | FlyerGenerator.svelte:1835 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(-1)}>↶ -1° | FlyerGenerator.svelte:1836 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(1)}>↷ +1° | FlyerGenerator.svelte:1837 | ❌ |
| Desktop | FlyerGenerator | OTHER: applyTextRotation(5)}>↷ +5° | FlyerGenerator.svelte:1838 | ❌ |
| Desktop | FlyerGenerator | OTHER: ✓ | FlyerGenerator.svelte:1857 | ❌ |
| Desktop | FlyerTemplateDesigner | CREATE: ➕ New | FlyerTemplateDesigner.svelte:577 | ❌ |
| Desktop | FlyerTemplateDesigner | OTHER: { firstPageImage = null; firstPageFile = null; }}> | FlyerTemplateDesigner.svelte:629 | ❌ |
| Desktop | FlyerTemplateDesigner | CREATE: ➕ Add Sub Page | FlyerTemplateDesigner.svelte:641 | ❌ |
| Desktop | FlyerTemplateDesigner | DELETE: removeSubPage(index)} title="Remove this page">  | FlyerTemplateDesigner.svelte:653 | ❌ |
| Desktop | FlyerTemplateDesigner | OTHER: { subPageImages[index] = null; subPageFiles[index] | FlyerTemplateDesigner.svelte:669 | ❌ |
| Desktop | FlyerTemplateDesigner | CREATE: ➕ Add Product Field | FlyerTemplateDesigner.svelte:682 | ❌ |
| Desktop | FlyerTemplateDesigner | CREATE: 🎨 Add Special Symbol | FlyerTemplateDesigner.svelte:690 | ❌ |
| Desktop | FlyerTemplateDesigner | OTHER: duplicateField(field.id)} tit | FlyerTemplateDesigner.svelte:711 | ❌ |
| Desktop | FlyerTemplateDesigner | DELETE: deleteField(field.id)} title= | FlyerTemplateDesigner.svelte:718 | ❌ |
| Desktop | FlyerTemplateDesigner | UPLOAD: {isUploading ? '⏳ Saving...' : '💾 Save Template'} | FlyerTemplateDesigner.svelte:743 | ❌ |
| Desktop | FlyerTemplateDesigner | OTHER: activeTab = 'first'} > 📄  | FlyerTemplateDesigner.svelte:755 | ❌ |
| Desktop | FlyerTemplateDesigner | OTHER: { activeTab = 'sub'; activeSubPageIndex = index; } | FlyerTemplateDesigner.svelte:763 | ❌ |
| Desktop | OfferManager | OTHER: Refresh | OfferManager.svelte:145 | ❌ |
| Desktop | OfferManager | OTHER: toggleOfferStatus(offer.id, offer.is_active)}  | OfferManager.svelte:241 | ❌ |
| Desktop | OfferManager | DELETE: deleteOffer(offer.id, offer.template_name)}  | OfferManager.svelte:258 | ❌ |
| Desktop | OfferProductSelector | OTHER: Next: Select Products | OfferProductSelector.svelte:596 | ❌ |
| Desktop | OfferProductSelector | CREATE: Add Template | OfferProductSelector.svelte:613 | ❌ |
| Desktop | OfferProductSelector | DELETE: removeTemplate(template.id)} class="tex | OfferProductSelector.svelte:637 | ❌ |
| Desktop | OfferProductSelector | OTHER: Previous | OfferProductSelector.svelte:681 | ❌ |
| Desktop | OfferProductSelector | VIEW: Next: Review | OfferProductSelector.svelte:691 | ❌ |
| Desktop | OfferProductSelector | DELETE: Clear Filters | OfferProductSelector.svelte:760 | ❌ |
| Desktop | OfferProductSelector | OTHER: Previous | OfferProductSelector.svelte:884 | ❌ |
| Desktop | OfferProductSelector | SAVE: {isLoading ? 'Saving...' : 'Save Offers'} | OfferProductSelector.svelte:894 | ❌ |
| Desktop | OfferTemplates | OTHER: Refresh | OfferTemplates.svelte:263 | ❌ |
| Desktop | OfferTemplates | CREATE: selectTemplate(template)} class="bg-white  | OfferTemplates.svelte:294 | ❌ |
| Desktop | OfferTemplates | OTHER: Back to Templates | OfferTemplates.svelte:343 | ❌ |
| Desktop | OfferTemplates | SAVE: {#if isSaving}  | OfferTemplates.svelte:357 | ❌ |
| Desktop | PriceValidationWarning | OTHER: Cancel | PriceValidationWarning.svelte:165 | ❌ |
| Desktop | PriceValidationWarning | DELETE: { if (selectedAction === 'continue') handleC | PriceValidationWarning.svelte:172 | ❌ |
| Desktop | PricingManager | OTHER: Refresh | PricingManager.svelte:1395 | ❌ |
| Desktop | PricingManager | CREATE: loadOfferProducts(offer.id)} class="p-4 bor | PricingManager.svelte:1429 | ❌ |
| Desktop | PricingManager | OTHER: Generate Offers | PricingManager.svelte:1515 | ❌ |
| Desktop | PricingManager | OTHER: B1 | PricingManager.svelte:1526 | ❌ |
| Desktop | PricingManager | OTHER: B2 | PricingManager.svelte:1535 | ❌ |
| Desktop | PricingManager | OTHER: B3 | PricingManager.svelte:1544 | ❌ |
| Desktop | PricingManager | OTHER: B4 | PricingManager.svelte:1553 | ❌ |
| Desktop | PricingManager | OTHER: B5 | PricingManager.svelte:1562 | ❌ |
| Desktop | PricingManager | OTHER: 3x target) to target+10%'} > B6 | PricingManager.svelte:1571 | ❌ |
| Desktop | PricingManager | EXPORT: Export to Excel | PricingManager.svelte:1582 | ❌ |
| Desktop | PricingManager | UPLOAD: Import from Excel | PricingManager.svelte:1592 | ❌ |
| Desktop | PricingManager | SAVE: {#if isSavingPrices}  | PricingManager.svelte:1602 | ❌ |
| Desktop | PricingManager | VIEW: showSuccessModal = false} class="px-6 py-2.5 | PricingManager.svelte:1944 | ❌ |
| Desktop | ProductFieldConfigurator | CREATE: ➕ Add Field | ProductFieldConfigurator.svelte:95 | ❌ |
| Desktop | ProductFieldConfigurator | DELETE: deleteField(index)}>🗑️ | ProductFieldConfigurator.svelte:113 | ❌ |
| Desktop | ProductFieldConfigurator | OTHER: Cancel | ProductFieldConfigurator.svelte:260 | ❌ |
| Desktop | ProductFieldConfigurator | SAVE: 💾 Save Configuration | ProductFieldConfigurator.svelte:261 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | CREATE: ➕ Add Field | ProductFieldConfiguratorFlyer.svelte:519 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | DELETE: deleteField(fieldItem.id)}>🗑️ | ProductFieldConfiguratorFlyer.svelte:528 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | DELETE: removeIcon(fieldItem.id)}>✕ | ProductFieldConfiguratorFlyer.svelte:599 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | UPLOAD: triggerIconUpload(fieldItem.id)}>  | ProductFieldConfiguratorFlyer.svelte:639 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | DELETE: removeSymbol(fieldItem.id)}>✕ | ProductFieldConfiguratorFlyer.svelte:653 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | UPLOAD: triggerSymbolUpload(fieldItem.id)}>  | ProductFieldConfiguratorFlyer.svelte:677 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | SAVE: ✅ Apply Configuration | ProductFieldConfiguratorFlyer.svelte:692 | ❌ |
| Desktop | ProductFieldConfiguratorFlyer | OTHER: Cancel | ProductFieldConfiguratorFlyer.svelte:695 | ❌ |
| Desktop | ProductManager | SAVE: 💾 {saving ? 'Saving...' : `Save (${selectedP | ProductManager.svelte:482 | ❌ |
| Desktop | ProductManager | OTHER: Retry | ProductManager.svelte:569 | ❌ |
| Desktop | ProductManager | CREATE: { selectedProducts.clear(); sele | ProductManager.svelte:743 | ❌ |
| Desktop | ProductMaster | CREATE: closeCreatePopup | ProductMaster.svelte:1466 | ❌ |
| Desktop | ProductMaster | OTHER: {#if isCheckingImage}  | ProductMaster.svelte:1493 | ❌ |
| Desktop | ProductMaster | CREATE: Cancel | ProductMaster.svelte:1656 | ❌ |
| Desktop | ProductMaster | CREATE: {#if isSavingCreate}  | ProductMaster.svelte:1663 | ❌ |
| Desktop | ProductMaster | EDIT: closeEditPopup | ProductMaster.svelte:1702 | ❌ |
| Desktop | ProductMaster | EDIT: Cancel | ProductMaster.svelte:1834 | ❌ |
| Desktop | ProductMaster | EDIT: {#if isSavingEdit}  | ProductMaster.svelte:1841 | ❌ |
| Desktop | ProductMaster | UPLOAD: showUploadSuccessPopup = false} class="w-ful | ProductMaster.svelte:1877 | ❌ |
| Desktop | ProductMaster | VIEW: Close | ProductMaster.svelte:1899 | ❌ |
| Desktop | ProductMaster | VIEW: Cancel | ProductMaster.svelte:1924 | ❌ |
| Desktop | ProductMaster | EXPORT: {#if downloadingImage}  | ProductMaster.svelte:1933 | ❌ |
| Desktop | ProductMaster | OTHER: Close | ProductMaster.svelte:1979 | ❌ |
| Desktop | ProductMaster | EXPORT: downloadAndUploadImage(image.url || image, 'none') | ProductMaster.svelte:2039 | ❌ |
| Desktop | ProductMaster | DELETE: downloadAndUploadImage(image.url || image, 'client | ProductMaster.svelte:2051 | ❌ |
| Desktop | ProductMaster | DELETE: downloadAndUploadImage(image.url || image, 'api')} | ProductMaster.svelte:2065 | ❌ |
| Desktop | ProductMaster | UPLOAD: Cancel | ProductMaster.svelte:2104 | ❌ |
| Desktop | ProductMaster | SAVE: {#if isSavingProducts}  | ProductMaster.svelte:2158 | ❌ |
| Desktop | ProductMaster | CREATE: Create Product | ProductMaster.svelte:2178 | ❌ |
| Desktop | ProductMaster | UPLOAD: {#if isUploadingImages}  | ProductMaster.svelte:2188 | ❌ |
| Desktop | ProductMaster | EXPORT: Download Template | ProductMaster.svelte:2207 | ❌ |
| Desktop | ProductMaster | UPLOAD: Import from Excel | ProductMaster.svelte:2217 | ❌ |
| Desktop | ProductMaster | VIEW: View All | ProductMaster.svelte:2262 | ❌ |
| Desktop | ProductMaster | UPLOAD: Upload | ProductMaster.svelte:2304 | ❌ |
| Desktop | ProductMaster | VIEW: Close | ProductMaster.svelte:2353 | ❌ |
| Desktop | ProductMaster | OTHER: noImageSearchQuery = ''} class="absolute  | ProductMaster.svelte:2376 | ❌ |
| Desktop | ProductMaster | OTHER: searchWebForImages(product.barcode, 'google')}  | ProductMaster.svelte:2491 | ❌ |
| Desktop | ProductMaster | OTHER: searchWebForImages(product.barcode, 'duckduckgo')} | ProductMaster.svelte:2508 | ❌ |
| Desktop | ProductMaster | EDIT: openEditPopup(product)} class="px-3 py | ProductMaster.svelte:2523 | ❌ |
| Desktop | ProductMaster | VIEW: Close | ProductMaster.svelte:2570 | ❌ |
| Desktop | ProductMaster | EDIT: document.getElementById(`update-image-${product.ba | ProductMaster.svelte:2705 | ❌ |
| Desktop | ProductMaster | EDIT: openEditPopup(product)} class="px-3 py | ProductMaster.svelte:2724 | ❌ |
| Desktop | ProductMaster | DELETE: searchBarcode = ''} class="px-4 py-2 text-g | ProductMaster.svelte:2784 | ❌ |
| Desktop | ProductMaster | DELETE: searchBarcode = ''} class="px-6 py-2 bg-blue- | ProductMaster.svelte:2904 | ❌ |
| Desktop | ShelfPaperTemplateDesigner | CREATE: ➕ New | ShelfPaperTemplateDesigner.svelte:423 | ❌ |
| Desktop | ShelfPaperTemplateDesigner | OTHER: { templateImage = null; fieldSelectors = []; }}>  | ShelfPaperTemplateDesigner.svelte:472 | ❌ |
| Desktop | ShelfPaperTemplateDesigner | CREATE: ➕ Add Field | ShelfPaperTemplateDesigner.svelte:482 | ❌ |
| Desktop | ShelfPaperTemplateDesigner | DELETE: deleteField(field.id)}>🗑️ | ShelfPaperTemplateDesigner.svelte:491 | ❌ |
| Desktop | ShelfPaperTemplateDesigner | UPLOAD: {isUploading ? 'Saving...' : '💾 Save Template'} | ShelfPaperTemplateDesigner.svelte:562 | ❌ |
| Desktop | VariationManager | VIEW: {showGroupsView ? '📦 Products View' : '🔗 Groups  | VariationManager.svelte:664 | ❌ |
| Desktop | VariationManager | OTHER: Deselect All | VariationManager.svelte:687 | ❌ |
| Desktop | VariationManager | EDIT: Update Group ({selectedProducts.size}) | VariationManager.svelte:694 | ❌ |
| Desktop | VariationManager | EDIT: { isEditMode = false; groupParen | VariationManager.svelte:701 | ❌ |
| Desktop | VariationManager | CREATE: Create Group ({selectedProducts.size}) | VariationManager.svelte:714 | ❌ |
| Desktop | VariationManager | VIEW: Go to Products View | VariationManager.svelte:751 | ❌ |
| Desktop | VariationManager | EDIT: openEditGroupModal(group.parent.barcode, group.par | VariationManager.svelte:796 | ❌ |
| Desktop | VariationManager | DELETE: deleteGroup(group.parent.barcode, group.parent.var | VariationManager.svelte:802 | ❌ |
| Desktop | VariationManager | OTHER: ← Previous | VariationManager.svelte:872 | ❌ |
| Desktop | VariationManager | OTHER: Next → | VariationManager.svelte:879 | ❌ |
| Desktop | VariationManager | OTHER: Select All (page) | VariationManager.svelte:905 | ❌ |
| Desktop | VariationManager | OTHER: currentPage = Math.max(1, currentPage - 1)}  | VariationManager.svelte:1003 | ❌ |
| Desktop | VariationManager | OTHER: currentPage = pageNum} class="px-3 py-2 | VariationManager.svelte:1015 | ❌ |
| Desktop | VariationManager | OTHER: currentPage = Math.min(totalPages, currentPage + 1 | VariationManager.svelte:1026 | ❌ |
| Desktop | VariationManager | OTHER: Cancel | VariationManager.svelte:1163 | ❌ |
| Desktop | VariationManager | CREATE: {#if isCreatingGroup} {isEditMode ? | VariationManager.svelte:1170 | ❌ |
| Desktop | VariationSelectionModal | OTHER: cancel | VariationSelectionModal.svelte:120 | ❌ |
| Desktop | VariationSelectionModal | OTHER: {selectAll ? 'Deselect All' : 'Select All'} | VariationSelectionModal.svelte:146 | ❌ |
| Desktop | VariationSelectionModal | OTHER: In Stock Only | VariationSelectionModal.svelte:152 | ❌ |
| Desktop | VariationSelectionModal | OTHER: Cancel | VariationSelectionModal.svelte:263 | ❌ |
| Desktop | VariationSelectionModal | CREATE: Add Selected ({selectedCount}) | VariationSelectionModal.svelte:269 | ❌ |
| Desktop | ViewOfferManager | CREATE: ➕ Add Offer | ViewOfferManager.svelte:188 | ❌ |
| Desktop | ViewOfferManager | EDIT: openEditOfferWindow(offer.id, offer.offer_name)}  | ViewOfferManager.svelte:250 | ❌ |
| Other | +layout | OTHER: goBack | +layout.svelte:553 | ❌ |
| Other | +layout | VIEW: showMenu = !showMenu} aria-label="Menu"> | +layout.svelte:559 | ❌ |
| Other | +layout | OTHER: handleNotificationRefresh | +layout.svelte:585 | ❌ |
| Other | +layout | VIEW: { logout(); showMenu = false; }} title={getTransla | +layout.svelte:634 | ❌ |
| Other | +layout | OTHER: goto('/mobile-interface/login')} class="error-btn" | +layout.svelte:704 | ❌ |
| Other | +page | OTHER: { activeSection = 'approvals'; filterRequisitions( | +page.svelte:1076 | ❌ |
| Other | +page | OTHER: { activeSection = 'my_requests'; filterRequisition | +page.svelte:1085 | ❌ |
| Other | +page | EDIT: ✅ Approve {selectedItems.size} | +page.svelte:1138 | ❌ |
| Other | +page | CREATE: { selectedItems = new Set(); }}> ✕ Clear | +page.svelte:1141 | ❌ |
| Other | +page | OTHER: ☑️ Mark All | +page.svelte:1145 | ❌ |
| Other | +page | OTHER: ✕ | +page.svelte:1295 | ❌ |
| Other | +page | APPROVE: openConfirmModal('approve')} disabled={is | +page.svelte:1506 | ❌ |
| Other | +page | APPROVE: openConfirmModal('reject')} disabled={isP | +page.svelte:1514 | ❌ |
| Other | +page | SAVE: Cancel | +page.svelte:1564 | ❌ |
| Other | +page | APPROVE: {confirmAction === 'approve' ? 'Approve' : 'Reject | +page.svelte:1567 | ❌ |
| Other | +page | APPROVE: × | +page.svelte:1587 | ❌ |
| Other | +page | APPROVE: Cancel | +page.svelte:1600 | ❌ |
| Other | +page | APPROVE: {#if isProcessing} Processing... {:e | +page.svelte:1603 | ❌ |
| Other | +page | VIEW: {showFilters ? 'Hide' : 'Filter'} | +page.svelte:484 | ❌ |
| Other | +page | DELETE: {getTranslation('mobile.assignmentsContent.search. | +page.svelte:531 | ❌ |
| Other | +page | EXPORT: downloadFile(attachment)} title="{g | +page.svelte:667 | ❌ |
| Other | +page | EXPORT: downloadFile(attachment)} >  | +page.svelte:681 | ❌ |
| Other | +page | VIEW: × | +page.svelte:715 | ❌ |
| Other | +page | OTHER: loadBranchPerformance | +page.svelte:210 | ❌ |
| Other | +page | OTHER: goBackToMainLogin | +page.svelte:273 | ❌ |
| Other | +page | SAVE: d === '')} > {#if isLoading}  | +page.svelte:323 | ❌ |
| Other | +page | CREATE: {getTranslation('mobile.createNotificationContent. | +page.svelte:425 | ❌ |
| Other | +page | CREATE: {getTranslation('mobile.createNotificationContent. | +page.svelte:428 | ❌ |
| Other | +page | CREATE: {getTranslation('mobile.createNotificationContent. | +page.svelte:487 | ❌ |
| Other | +page | CREATE: {#if isLoading} {getTranslation('mobile.crea | +page.svelte:495 | ❌ |
| Other | +page | OTHER: goto('/mobile-interface/notifications')} aria-labe | +page.svelte:68 | ❌ |
| Other | +page | OTHER: goto('/mobile-interface/notifications')}> Ba | +page.svelte:88 | ❌ |
| Other | +page | OTHER: goto('/mobile-interface/notifications')}> Ba | +page.svelte:126 | ❌ |
| Other | +page | VIEW: showSuccessMessage = false}> | +page.svelte:706 | ❌ |
| Other | +page | OTHER: {getTranslation('mobile.quickTaskContent.success.g | +page.svelte:754 | ❌ |
| Other | +page | VIEW: {getTranslation('mobile.quickTaskContent.step1.cha | +page.svelte:775 | ❌ |
| Other | +page | SAVE: {getTranslation('mobile.quickTaskContent.step1.con | +page.svelte:791 | ❌ |
| Other | +page | VIEW: {getTranslation('mobile.quickTaskContent.step2.cha | +page.svelte:812 | ❌ |
| Other | +page | SAVE: {getTranslation('mobile.quickTaskContent.step2.con | +page.svelte:860 | ❌ |
| Other | +page | OTHER: {getTranslation('mobile.quickTaskContent.step4.cho | +page.svelte:926 | ❌ |
| Other | +page | OTHER: {getTranslation('mobile.quickTaskContent.step4.cam | +page.svelte:936 | ❌ |
| Other | +page | DELETE: removeFile(file.id)} class="remove-file-btn">  | +page.svelte:953 | ❌ |
| Other | +page | ASSIGN: {#if isSubmitting} {getTranslation( | +page.svelte:987 | ❌ |
| Other | +page | ASSIGN: goto('/mobile-interface/assignments')}> ← Ba | +page.svelte:540 | ❌ |
| Other | +page | VIEW: showTaskDetails = !showTaskDetails} > { | +page.svelte:550 | ❌ |
| Other | +page | EXPORT: downloadFile(file.fileUrl, file.fileName)}  | +page.svelte:645 | ❌ |
| Other | +page | DELETE: removePhoto | +page.svelte:735 | ❌ |
| Other | +page | ASSIGN: goto('/mobile-interface/assignments')} disabled={i | +page.svelte:786 | ❌ |
| Other | +page | SAVE: {#if isSubmitting} Completing...  | +page.svelte:789 | ❌ |
| Other | +page | OTHER: goto('/mobile-interface/tasks')}> ← Back to T | +page.svelte:208 | ❌ |
| Other | +page | OTHER: goto('/mobile-interface/tasks')}> | +page.svelte:216 | ❌ |
| Other | +page | OTHER: goto('/mobile-interface/tasks')}> ← Back to T | +page.svelte:361 | ❌ |
| Other | +page | VIEW: goto(`/mobile-interface/receiving-tasks/${taskId}/ | +page.svelte:364 | ❌ |
| Other | +page | OTHER: goto('/mobile-interface/tasks')}> ← Back to T | +page.svelte:716 | ❌ |
| Other | +page | DELETE: removePRExcelFile | +page.svelte:844 | ❌ |
| Other | +page | DELETE: removeOriginalBillFile | +page.svelte:896 | ❌ |
| Other | +page | DELETE: removePhoto | +page.svelte:1070 | ✅ |
| Other | +page | SAVE: goto('/mobile-interface/tasks')} disabled={isSubmi | +page.svelte:1290 | ❌ |
| Other | +page | SAVE: {#if isSubmitting} Completing Task... | +page.svelte:1293 | ❌ |
| Other | +page | OTHER: OK | +page.svelte:1340 | ❌ |
| Other | +page | VIEW: closePhotoViewer | +page.svelte:1354 | ❌ |
| Other | +page | EXPORT: downloadSingleAttachment(attachment)}  | +page.svelte:1060 | ❌ |
| Other | +page | EXPORT: downloadSingleAttachment(attachment)}  | +page.svelte:1089 | ❌ |
| Other | +page | OTHER: markAsComplete(task)} disabled={isLoading}>  | +page.svelte:1111 | ❌ |
| Other | +page | VIEW: navigateToTask(task)}>  | +page.svelte:1117 | ❌ |
| Other | +page | VIEW: navigateToTask(task)}>  | +page.svelte:1127 | ❌ |
| Other | +page | VIEW: closeImagePreview | +page.svelte:1147 | ❌ |
| Other | +page | CREATE: goto('/mobile-interface/tasks/create')}>  | +page.svelte:676 | ❌ |
| Other | +page | ASSIGN: {getTranslation('mobile.assignContent.actions.canc | +page.svelte:784 | ❌ |
| Other | +page | ASSIGN: {getTranslation('mobile.assignContent.actions.next | +page.svelte:792 | ❌ |
| Other | +page | ASSIGN: {getTranslation('mobile.assignContent.actions.prev | +page.svelte:846 | ❌ |
| Other | +page | ASSIGN: {getTranslation('mobile.assignContent.actions.next | +page.svelte:854 | ❌ |
| Other | +page | ASSIGN: {getTranslation('mobile.assignContent.actions.prev | +page.svelte:1023 | ❌ |
| Other | +page | ASSIGN: {getTranslation('mobile.assignContent.actions.next | +page.svelte:1031 | ❌ |
| Other | +page | ASSIGN: {getTranslation('mobile.assignContent.actions.prev | +page.svelte:1098 | ❌ |
| Other | +page | ASSIGN: {getTranslation('mobile.assignContent.actions.canc | +page.svelte:1106 | ❌ |
| Other | +page | ASSIGN: {isAssigning ? getTranslation('mobile.assignConten | +page.svelte:1116 | ❌ |
| Other | +page | OTHER: Next Step | +page.svelte:1124 | ❌ |
| Other | +page | CREATE: 📷 {getTranslation('mobile.createContent.camera')} | +page.svelte:154 | ❌ |
| Other | +page | CREATE: {getTranslation('mobile.createContent.actions.canc | +page.svelte:171 | ❌ |
| Other | +page | CREATE: {isSubmitting ? getTranslation('mobile.createConte | +page.svelte:174 | ❌ |
| Other | +page | OTHER: goto('/mobile-interface/tasks')}> Back to Tas | +page.svelte:255 | ❌ |
| Other | +page | EXPORT: downloadAttachment(attachment)} title="D | +page.svelte:396 | ❌ |
| Other | +page | EDIT: updateAssignmentStatus('in_progress')} dis | +page.svelte:419 | ❌ |
| Other | +page | EDIT: updateAssignmentStatus('completed')} disab | +page.svelte:436 | ❌ |
| Other | +page | OTHER: goto('/mobile-interface/tasks')}>  | +page.svelte:593 | ❌ |
| Other | +page | VIEW: showTaskDetails = !showTaskDetails}  | +page.svelte:603 | ❌ |
| Other | +page | EXPORT: downloadFile(attachment.fileUrl, attachment.fileNa | +page.svelte:715 | ❌ |
| Other | +page | DELETE: removePhoto | +page.svelte:804 | ❌ |
| Other | +page | SAVE: goto('/mobile-interface/tasks')} disabled={isSubmi | +page.svelte:851 | ❌ |
| Other | +page | SAVE: {#if isSubmitting}  | +page.svelte:854 | ❌ |
| Other | +page | OTHER: closeImageModal | +page.svelte:875 | ❌ |
| Other | MobileSalesReport | OTHER: loadSalesData | MobileSalesReport.svelte:429 | ❌ |
| Other | MobileSalesReport | OTHER: loadBranchSalesData | MobileSalesReport.svelte:492 | ❌ |
| Other | MobileSalesReport | OTHER: loadYesterdayBranchSalesData | MobileSalesReport.svelte:552 | ❌ |
| Other | NotificationCenter | OTHER: Retry | NotificationCenter.svelte:1198 | ❌ |
| Other | NotificationCenter | CREATE: 📝 {getTranslation('mobile.assignContent.cre | NotificationCenter.svelte:1212 | ❌ |
| Other | NotificationCenter | OTHER: Mark all {unreadCount} as read | NotificationCenter.svelte:1242 | ❌ |
| Other | NotificationCenter | EXPORT: downloadFile(attachment)} title=" | NotificationCenter.svelte:1315 | ❌ |
| Other | NotificationCenter | EXPORT: downloadFile(attachment)} title=" | NotificationCenter.svelte:1337 | ❌ |
| Other | NotificationCenter | OTHER: openTaskCompletion(notification)} >  | NotificationCenter.svelte:1360 | ❌ |
| Other | NotificationCenter | OTHER: markAsRead(notification.id)} >  | NotificationCenter.svelte:1368 | ❌ |
| Other | NotificationCenter | DELETE: deleteNotification(notification.id)} >  | NotificationCenter.svelte:1376 | ❌ |
| Other | NotificationCenter | OTHER: closeImageModal | NotificationCenter.svelte:1410 | ❌ |
| Other | QuickTaskModal | OTHER: closeModal | QuickTaskModal.svelte:599 | ❌ |
| Other | QuickTaskModal | VIEW: Change | QuickTaskModal.svelte:627 | ❌ |
| Other | QuickTaskModal | SAVE: ✓ Confirm | QuickTaskModal.svelte:643 | ❌ |
| Other | QuickTaskModal | VIEW: Change | QuickTaskModal.svelte:664 | ❌ |
| Other | QuickTaskModal | SAVE: ✓ Confirm ({selectedUsers.length} users) | QuickTaskModal.svelte:712 | ❌ |
| Other | QuickTaskModal | OTHER: Choose Files | QuickTaskModal.svelte:787 | ❌ |
| Other | QuickTaskModal | OTHER: Camera | QuickTaskModal.svelte:797 | ❌ |
| Other | QuickTaskModal | DELETE: removeFile(file.id)} class="remove-file-btn"> | QuickTaskModal.svelte:814 | ❌ |
| Other | QuickTaskModal | OTHER: Cancel | QuickTaskModal.svelte:849 | ❌ |
| Other | QuickTaskModal | ASSIGN: Assign Task | QuickTaskModal.svelte:853 | ❌ |
| Other | TaskCompletionModal | OTHER: handleClose | TaskCompletionModal.svelte:376 | ❌ |
| Other | TaskCompletionModal | DELETE: removePhoto | TaskCompletionModal.svelte:477 | ❌ |
| Other | TaskCompletionModal | OTHER: Cancel | TaskCompletionModal.svelte:526 | ❌ |
| Other | TaskCompletionModal | SAVE: {#if isSubmitting} Completing...  | TaskCompletionModal.svelte:529 | ❌ |

---

## 🔴 High Priority: CREATE/EDIT/DELETE Buttons Needing Permission Checks

| Interface | Component | Action | Button Purpose | Location |
|-----------|-----------|--------|----------------|----------|
| Desktop | BundleCreator | **CREATE** | + {isRTL ? 'إضافة حزمة' : 'Add Bundle'} | BundleCreator.svelte:219 |
| Desktop | BundleCreator | **DELETE** | removeBundle(bundleIndex)} title={isRTL ? ' | BundleCreator.svelte:235 |
| Desktop | BundleCreator | **CREATE** | addProductToBundle(bundleIndex)} >  | BundleCreator.svelte:271 |
| Desktop | BundleCreator | **DELETE** | removeProductFromBundle(bundleIndex, productIndex) | BundleCreator.svelte:315 |
| Desktop | CategoriesManager | **CREATE** | ➕ Create Category | CategoriesManager.svelte:205 |
| Desktop | CategoriesManager | **CREATE** | Create First Category | CategoriesManager.svelte:220 |
| Desktop | CategoriesManager | **EDIT** | openEditCategory(category)} title="Edit | CategoriesManager.svelte:277 |
| Desktop | CategoriesManager | **DELETE** | deleteCategory(category.id, category.name_en)}  | CategoriesManager.svelte:284 |
| Desktop | CustomerAccountRecoveryManager | **CREATE** | {loading ? ($_('admin.loading') || 'Loading...') : | CustomerAccountRecoveryManager.svelte:310 |
| Desktop | CustomerAccountRecoveryManager | **CREATE** | { const customerId = getRequestCust | CustomerAccountRecoveryManager.svelte:389 |
| Desktop | CustomerAccountRecoveryManager | **CREATE** | { const customerId = getRequestCusto | CustomerAccountRecoveryManager.svelte:453 |
| Desktop | CustomerAccountRecoveryManager | **CREATE** | { navigator.clipboard.writeText(newAccess | CustomerAccountRecoveryManager.svelte:501 |
| Desktop | CustomerAccountRecoveryManager | **CREATE** | { shareViaWhatsApp(selectedCustomer, newAc | CustomerAccountRecoveryManager.svelte:516 |
| Desktop | CustomerMaster | **APPROVE** | openApprovalModal(customer, "approve")}  | CustomerMaster.svelte:638 |
| Desktop | CustomerMaster | **APPROVE** | openApprovalModal(customer, "reject")}  | CustomerMaster.svelte:644 |
| Desktop | CustomerMaster | **APPROVE** | {#if isSavingApproval} {t('admin.sa | CustomerMaster.svelte:754 |
| Desktop | CustomerMaster | **EDIT** | currentEditingLocation = 1}> 📍 {t('a | CustomerMaster.svelte:786 |
| Desktop | CustomerMaster | **EDIT** | currentEditingLocation = 2}> 📍 {t('a | CustomerMaster.svelte:789 |
| Desktop | CustomerMaster | **EDIT** | currentEditingLocation = 3}> 📍 {t('a | CustomerMaster.svelte:792 |
| Desktop | DeliverySettings | **CREATE** | openTierModal()} disabled={!tierBranchId}>  | DeliverySettings.svelte:268 |
| Desktop | DeliverySettings | **EDIT** | openTierModal(tier)}>✏️ | DeliverySettings.svelte:316 |
| Desktop | DeliverySettings | **DELETE** | deleteTier(tier)}>🗑️ | DeliverySettings.svelte:317 |
| Desktop | DeliverySettings | **CREATE** | {isEditMode ? 'Update' : 'Add'} Tier | DeliverySettings.svelte:557 |
| Desktop | ImageTemplatesManager | **EDIT** | saveSlot(slot.slot_number)} disabled={slot | ImageTemplatesManager.svelte:397 |
| Desktop | OfferForm | **CREATE** | + {isRTL ? 'اختيار المنتجات' : 'Select Prod | OfferForm.svelte:767 |
| Desktop | OfferForm | **CREATE** | {#if loading} {/if} {isRTL ? (edi | OfferForm.svelte:955 |
| Desktop | OfferManagement | **CREATE** | createOfferWithType('percentage')}> 📊 {l | OfferManagement.svelte:973 |
| Desktop | OfferManagement | **CREATE** | createOfferWithType('special_price')}> 💰 | OfferManagement.svelte:976 |
| Desktop | OfferManagement | **CREATE** | createOfferWithType('bogo')}> 🎁 {locale  | OfferManagement.svelte:979 |
| Desktop | OfferManagement | **CREATE** | createOfferWithType('bundle')}> 📦 {local | OfferManagement.svelte:982 |
| Desktop | OfferManagement | **CREATE** | createOfferWithType('cart')}> 🛒 {locale  | OfferManagement.svelte:985 |
| Desktop | OfferManagement | **CREATE** | ➕ {texts.createNew} | OfferManagement.svelte:1080 |
| Desktop | OfferManagement | **EDIT** | editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1147 |
| Desktop | OfferManagement | **DELETE** | deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1158 |
| Desktop | OfferManagement | **EDIT** | editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1217 |
| Desktop | OfferManagement | **DELETE** | deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1228 |
| Desktop | OfferManagement | **EDIT** | editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1288 |
| Desktop | OfferManagement | **DELETE** | deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1299 |
| Desktop | OfferManagement | **EDIT** | editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1405 |
| Desktop | OfferManagement | **DELETE** | deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1411 |
| Desktop | OrdersManager | **DELETE** | {t('orders.filters.clear', 'Clear')} | OrdersManager.svelte:426 |
| Desktop | TaxManager | **CREATE** | ➕ Add Tax Category | TaxManager.svelte:112 |
| Desktop | TaxManager | **CREATE** | Create First Tax Category | TaxManager.svelte:128 |
| Desktop | TaxManager | **DELETE** | deleteTax(tax)} title="Delete"  | TaxManager.svelte:161 |
| Desktop | TierManager | **CREATE** | + {isRTL ? 'إضافة مستوى' : 'Add Tier'} | TierManager.svelte:58 |
| Desktop | TierManager | **DELETE** | removeTier(index)} title={isRTL ? 'حذف ال | TierManager.svelte:134 |
| Desktop | VideoTemplatesManager | **EDIT** | saveSlot(slot.slot_number)} disabled={slot | VideoTemplatesManager.svelte:435 |
| Cashier | CouponRedemption | **CREATE** | {t('coupon.newRedemption') || 'New Redemption'} | CouponRedemption.svelte:492 |
| Other | +page | **DELETE** | removeItem(item)}> ✕ | +page.svelte:410 |
| Other | +page | **DELETE** | removeItem(item)}> ✕ | +page.svelte:456 |
| Other | +page | **EDIT** | updateItemQuantity(item, -1)} > | +page.svelte:495 |
| Other | +page | **EDIT** | updateItemQuantity(item, 1)} >  | +page.svelte:502 |
| Other | +page | **DELETE** | removeItem(item)}> ✕ | +page.svelte:522 |
| Other | +page | **DELETE** | {texts.clearCart} | +page.svelte:597 |
| Other | +page | **DELETE** | removeItem(item)}> 🗑️ | +page.svelte:1218 |
| Other | +page | **DELETE** | removeItem(item)}> 🗑️ | +page.svelte:1264 |
| Other | +page | **DELETE** | removeItem(item)}> 🗑️ | +page.svelte:1334 |
| Other | +page | **CREATE** | { // Find first empty slot  | +page.svelte:1457 |
| Other | +page | **CREATE** | 🛒 {texts.newOrder} | +page.svelte:1543 |
| Other | +page | **CREATE** | addBogoToCart(bogoOffer)} disabled={ | +page.svelte:817 |
| Other | +page | **CREATE** | addBundleToCart(bundleOffer)} disabl | +page.svelte:907 |
| Other | +page | **CREATE** | addToCart(product)} disabled={out} type="button" a | +page.svelte:1042 |
| Other | +page | **EDIT** | updateQuantity(product, -1)} aria-label="Decrease" | +page.svelte:1045 |
| Other | +page | **EDIT** | updateQuantity(product, 1)} aria-label="Increase"  | +page.svelte:1047 |
| Other | +page | **CREATE** | { const newLanguage = currentLanguage = | +page.svelte:500 |
| Other | +page | **EDIT** | openLocationPicker(index + 1)} title={texts.editLo | +page.svelte:570 |
| Other | +page | **CREATE** | openLocationPicker(slotNum)}> ➕  | +page.svelte:586 |
| Other | +page | **CREATE** | openWhatsAppSupport(texts.changeAddress)}>  | +page.svelte:221 |
| Other | FeaturedOffers | **CREATE** | { // Dispatch event to parent to open of | FeaturedOffers.svelte:242 |
| Desktop | AddOfferDialog | **CREATE** | {isLoading ? (isEditing ? 'Updating...' : 'Adding. | AddOfferDialog.svelte:450 |
| Desktop | ApprovalCenter | **EDIT** | ✅ Approve {selectedItems.size} Item(s) | ApprovalCenter.svelte:1301 |
| Desktop | ApprovalCenter | **CREATE** | { selectedItems = new Set(); selectAll = false; }} | ApprovalCenter.svelte:1304 |
| Desktop | ApprovalCenter | **APPROVE** | showApprovalConfirm(selectedRequisition.id)}  | ApprovalCenter.svelte:1870 |
| Desktop | ApprovalCenter | **APPROVE** | showRejectionConfirm(selectedRequisition.id)}  | ApprovalCenter.svelte:1878 |
| Desktop | ApprovalCenter | **APPROVE** | {confirmAction === 'approve' ? 'Approve' : 'Reject | ApprovalCenter.svelte:1931 |
| Desktop | ApprovalCenter | **APPROVE** | × | ApprovalCenter.svelte:1951 |
| Desktop | ApprovalCenter | **APPROVE** | Cancel | ApprovalCenter.svelte:1964 |
| Desktop | ApprovalCenter | **APPROVE** | {#if isProcessing} Processing... {:e | ApprovalCenter.svelte:1967 |
| Desktop | ApproverListModal | **DELETE** | searchQuery = ''}> | ApproverListModal.svelte:241 |
| Desktop | ApproverListModal | **APPROVE** | {#if submitting}  | ApproverListModal.svelte:316 |
| Desktop | AssignPositions | **DELETE** | searchTerm = ''} title="Clear search"> × | AssignPositions.svelte:358 |
| Desktop | BiometricData | **CREATE** | {t('common.retry')} | BiometricData.svelte:633 |
| Desktop | BiometricData | **CREATE** | loadDataOnDemand('specific', specificDate)} disabl | BiometricData.svelte:769 |
| Desktop | BiometricData | **CREATE** | loadDataOnDemand('range', startDate, endDate)} dis | BiometricData.svelte:790 |
| Desktop | BiometricData | **DELETE** | { searchQuery = ''; }}> {t('hr.clearSearch | BiometricData.svelte:822 |
| Desktop | BiometricData | **DELETE** | { selectedBranch = ''; selectedDate = ''; }}>  | BiometricData.svelte:851 |
| Desktop | BranchMaster | **CREATE** | + Create Branch | BranchMaster.svelte:207 |
| Desktop | BranchMaster | **EDIT** | openEditPopup(branch)} disabled={isLoading}>  | BranchMaster.svelte:276 |
| Desktop | BranchMaster | **DELETE** | deleteBranch(branch.id)} disabled={isLoading}>  | BranchMaster.svelte:279 |
| Desktop | BranchMaster | **CREATE** | + Create Your First Branch | BranchMaster.svelte:292 |
| Desktop | BranchMaster | **CREATE** | × | BranchMaster.svelte:307 |
| Desktop | BranchMaster | **CREATE** | Cancel | BranchMaster.svelte:390 |
| Desktop | BranchMaster | **EDIT** | × | BranchMaster.svelte:409 |
| Desktop | BranchMaster | **EDIT** | Cancel | BranchMaster.svelte:492 |
| Desktop | BranchMaster | **EDIT** | Update | BranchMaster.svelte:495 |
| Desktop | BundleCreator | **CREATE** | + {isRTL ? 'إضافة حزمة' : 'Add Bundle'} | BundleCreator.svelte:219 |
| Desktop | BundleCreator | **DELETE** | removeBundle(bundleIndex)} title={isRTL ? ' | BundleCreator.svelte:235 |
| Desktop | BundleCreator | **CREATE** | addProductToBundle(bundleIndex)} >  | BundleCreator.svelte:271 |
| Desktop | BundleCreator | **DELETE** | removeProductFromBundle(bundleIndex, productIndex) | BundleCreator.svelte:315 |
| Desktop | ButtonAccessControl | **DELETE** | searchUsername = ''} title="Clear search"  | ButtonAccessControl.svelte:403 |
| Desktop | ButtonGenerator | **CREATE** | {loading ? 'Adding...' : '✓ Add Buttons'} | ButtonGenerator.svelte:539 |
| Desktop | ButtonGenerator | **EDIT** | {loading ? 'Updating...' : '🔄 Update Permissions' | ButtonGenerator.svelte:546 |
| Desktop | CampaignManager | **CREATE** | ➕ {t('coupon.createCampaign')} | CampaignManager.svelte:298 |
| Desktop | CampaignManager | **EDIT** | openEditForm(campaign)} class="flex-1 p | CampaignManager.svelte:510 |
| Desktop | CampaignManager | **DELETE** | handleDelete(campaign)} class="px-3 py- | CampaignManager.svelte:522 |
| Desktop | CategoriesManager | **CREATE** | ➕ Create Category | CategoriesManager.svelte:205 |
| Desktop | CategoriesManager | **CREATE** | Create First Category | CategoriesManager.svelte:220 |
| Desktop | CategoriesManager | **EDIT** | openEditCategory(category)} title="Edit | CategoriesManager.svelte:277 |
| Desktop | CategoriesManager | **DELETE** | deleteCategory(category.id, category.name_en)}  | CategoriesManager.svelte:284 |
| Desktop | CategoryManager | **CREATE** | openParentModal()}> ➕ Create Parent Cate | CategoryManager.svelte:310 |
| Desktop | CategoryManager | **CREATE** | openSubModal()}> ➕ Create Sub Category | CategoryManager.svelte:314 |
| Desktop | CategoryManager | **EDIT** | openParentModal(category)} title="Edit">  | CategoryManager.svelte:395 |
| Desktop | CategoryManager | **DELETE** | deleteParentCategory(category)} title="Delete">  | CategoryManager.svelte:398 |
| Desktop | CategoryManager | **EDIT** | openSubModal(category)} title="Edit">  | CategoryManager.svelte:441 |
| Desktop | CategoryManager | **DELETE** | deleteSubCategory(category)} title="Delete">  | CategoryManager.svelte:444 |
| Desktop | CategoryManager | **CREATE** | {isEditMode ? 'Update' : 'Create'} | CategoryManager.svelte:499 |
| Desktop | CategoryManager | **CREATE** | {isEditMode ? 'Update' : 'Create'} | CategoryManager.svelte:551 |
| Desktop | ClearanceCertificateManager | **DELETE** | {#if isGenerating}  | ClearanceCertificateManager.svelte:1108 |
| Desktop | ClearanceCertificateManager | **CREATE** | {#if isGenerating}  | ClearanceCertificateManager.svelte:1221 |
| Desktop | ClearTables | **DELETE** | {#if isClearing} {:else} � | ClearTables.svelte:123 |
| Desktop | ContactManagement | **CREATE** | openContactForm(employee)} disabled={ | ContactManagement.svelte:418 |
| Desktop | ContactManagement-old | **EDIT** | openContactForm(employee)} disabled={ | ContactManagement-old.svelte:537 |
| Desktop | ContactManagement-old | **EDIT** | {#if isLoading} Updating... | ContactManagement-old.svelte:651 |
| Desktop | CouponDashboard | **CREATE** | {t('coupon.createFirst') || 'Create Your First Cam | CouponDashboard.svelte:47 |
| Desktop | CreateDepartment | **EDIT** | Cancel | CreateDepartment.svelte:194 |
| Desktop | CreateDepartment | **CREATE** | {#if isLoading} {isEditing ? 'Upd | CreateDepartment.svelte:198 |
| Desktop | CreateDepartment | **CREATE** | 🔄 Refresh | CreateDepartment.svelte:215 |
| Desktop | CreateDepartment | **EDIT** | editDepartment(department)} disabled= | CreateDepartment.svelte:253 |
| Desktop | CreateDepartment | **DELETE** | deleteDepartment(department.id)} disa | CreateDepartment.svelte:261 |
| Desktop | CreateLevel | **EDIT** | Cancel | CreateLevel.svelte:356 |
| Desktop | CreateLevel | **CREATE** | {#if isLoading} {isEditing ? 'Upd | CreateLevel.svelte:360 |
| Desktop | CreateLevel | **EDIT** | editLevel(level)} disabled={isLoading}  | CreateLevel.svelte:460 |
| Desktop | CreateLevel | **DELETE** | deleteLevel(level.id)} disabled={isLoad | CreateLevel.svelte:468 |
| Desktop | CreatePosition | **EDIT** | Cancel | CreatePosition.svelte:298 |
| Desktop | CreatePosition | **CREATE** | {#if isLoading} {isEditing ? 'Upd | CreatePosition.svelte:302 |
| Desktop | CreatePosition | **CREATE** | 🔄 Refresh | CreatePosition.svelte:319 |
| Desktop | CreatePosition | **EDIT** | editPosition(position)} disabled={isL | CreatePosition.svelte:375 |
| Desktop | CreatePosition | **DELETE** | deletePosition(position.id)} disabled | CreatePosition.svelte:383 |
| Desktop | CreateUser | **DELETE** | { selectedEmployee = null; formData.employeeId = ' | CreateUser.svelte:564 |
| Desktop | CreateUser | **DELETE** | × | CreateUser.svelte:706 |
| Desktop | CreateUser | **CREATE** | {#if isLoading} Creating User...  | CreateUser.svelte:756 |
| Desktop | CustomerAccountRecoveryManager | **CREATE** | {loading ? ($_('admin.loading') || 'Loading...') : | CustomerAccountRecoveryManager.svelte:310 |
| Desktop | CustomerAccountRecoveryManager | **CREATE** | { const customerId = getRequestCust | CustomerAccountRecoveryManager.svelte:389 |
| Desktop | CustomerAccountRecoveryManager | **CREATE** | { const customerId = getRequestCusto | CustomerAccountRecoveryManager.svelte:453 |
| Desktop | CustomerAccountRecoveryManager | **CREATE** | { navigator.clipboard.writeText(newAccess | CustomerAccountRecoveryManager.svelte:501 |
| Desktop | CustomerAccountRecoveryManager | **CREATE** | { shareViaWhatsApp(selectedCustomer, newAc | CustomerAccountRecoveryManager.svelte:516 |
| Desktop | CustomerImporter | **CREATE** | showAddNumberModal = true} disabled={!sele | CustomerImporter.svelte:552 |
| Desktop | CustomerImporter | **DELETE** | handleDeleteCustomer(customer.id)} d | CustomerImporter.svelte:596 |
| Desktop | CustomerImporter | **CREATE** | ✅ {t('coupon.add')} | CustomerImporter.svelte:643 |
| Desktop | CustomerImporter | **CREATE** | { showAddNumberModal = false; newNum | CustomerImporter.svelte:649 |
| Desktop | CustomerMaster | **APPROVE** | openApprovalModal(customer, "approve")}  | CustomerMaster.svelte:638 |
| Desktop | CustomerMaster | **APPROVE** | openApprovalModal(customer, "reject")}  | CustomerMaster.svelte:644 |
| Desktop | CustomerMaster | **APPROVE** | {#if isSavingApproval} {t('admin.sa | CustomerMaster.svelte:754 |
| Desktop | CustomerMaster | **EDIT** | currentEditingLocation = 1}> 📍 {t('a | CustomerMaster.svelte:786 |
| Desktop | CustomerMaster | **EDIT** | currentEditingLocation = 2}> 📍 {t('a | CustomerMaster.svelte:789 |
| Desktop | CustomerMaster | **EDIT** | currentEditingLocation = 3}> 📍 {t('a | CustomerMaster.svelte:792 |
| Desktop | DayBudgetPlanner | **DELETE** | Clear All | DayBudgetPlanner.svelte:1012 |
| Desktop | DayBudgetPlanner | **DELETE** | {vendorFilter = ''; branchFilter = ''; paymentMeth | DayBudgetPlanner.svelte:1059 |
| Desktop | DayBudgetPlanner | **DELETE** | {vendorFilter = ''; branchFilter = ''; paymentMeth | DayBudgetPlanner.svelte:1161 |
| Desktop | DayBudgetPlanner | **DELETE** | { selectedExpenseSchedules.clear();  | DayBudgetPlanner.svelte:1188 |
| Desktop | DayBudgetPlanner | **DELETE** | {expenseDescriptionFilter = ''; expenseCategoryFil | DayBudgetPlanner.svelte:1249 |
| Desktop | DayBudgetPlanner | **CREATE** | { nonApprovedPayments.forEach(payment => | DayBudgetPlanner.svelte:1354 |
| Desktop | DayBudgetPlanner | **DELETE** | { selectedNonApprovedPayments.clear();  | DayBudgetPlanner.svelte:1365 |
| Desktop | DeliverySettings | **CREATE** | openTierModal()} disabled={!tierBranchId}>  | DeliverySettings.svelte:268 |
| Desktop | DeliverySettings | **EDIT** | openTierModal(tier)}>✏️ | DeliverySettings.svelte:316 |
| Desktop | DeliverySettings | **DELETE** | deleteTier(tier)}>🗑️ | DeliverySettings.svelte:317 |
| Desktop | DeliverySettings | **CREATE** | {isEditMode ? 'Update' : 'Add'} Tier | DeliverySettings.svelte:557 |
| Desktop | DesignPlanner | **CREATE** | loadOfferProducts(offer.id)} >  | DesignPlanner.svelte:1009 |
| Desktop | EditUser | **DELETE** | × | EditUser.svelte:795 |
| Desktop | EditUser | **EDIT** | {#if isLoading} Updating User...  | EditUser.svelte:845 |
| Desktop | EditVendor | **EDIT** | shareLocationFromEdit(editData.location_link, edit | EditVendor.svelte:579 |
| Desktop | EditVendor | **DELETE** | removeCategory(category)}>× | EditVendor.svelte:732 |
| Desktop | EditVendor | **CREATE** | showNewCategoryForm = true} disabled={select | EditVendor.svelte:742 |
| Desktop | EditVendor | **CREATE** | ✅ Add Category | EditVendor.svelte:764 |
| Desktop | EditVendor | **CREATE** | {showNewCategoryForm = false; newCategoryName = '' | EditVendor.svelte:767 |
| Desktop | EditVendor | **DELETE** | removeDeliveryMode(mode)}>× | EditVendor.svelte:824 |
| Desktop | EditVendor | **CREATE** | showNewDeliveryModeForm = true} disabled={se | EditVendor.svelte:834 |
| Desktop | EditVendor | **CREATE** | ✅ Add Delivery Mode | EditVendor.svelte:856 |
| Desktop | EditVendor | **CREATE** | {showNewDeliveryModeForm = false; newDeliveryModeN | EditVendor.svelte:859 |
| Desktop | EmployeeDocumentManager | **DELETE** | deleteDocument(existingDoc.id)}> 🗑️ Delet | EmployeeDocumentManager.svelte:323 |
| Desktop | EmployeeDocumentManager | **CREATE** | uploadDocument(docType.key)} disabled={isU | EmployeeDocumentManager.svelte:428 |
| Desktop | EmployeeDocumentManager | **CREATE** | 📋 Manage Other Documents → | EmployeeDocumentManager.svelte:453 |
| Desktop | ERPConnections | **CREATE** | showConfigForm = !showConfigForm}> {showConfig | ERPConnections.svelte:379 |
| Desktop | ERPConnections | **EDIT** | editConfig(config)}> ✏️ Edit | ERPConnections.svelte:531 |
| Desktop | ERPConnections | **DELETE** | deleteConfig(config.id!)}> 🗑️ Delete | ERPConnections.svelte:534 |
| Desktop | ExpenseTracker | **DELETE** | Clear Filters | ExpenseTracker.svelte:629 |
| Desktop | ExpenseTracker | **DELETE** | Clear Filters | ExpenseTracker.svelte:635 |
| Desktop | ExpenseTracker | **EDIT** | ✕ | ExpenseTracker.svelte:760 |
| Desktop | ExpenseTracker | **EDIT** | Cancel | ExpenseTracker.svelte:800 |
| Desktop | ExpenseTracker | **EDIT** | Save Changes | ExpenseTracker.svelte:801 |
| Desktop | FlyerTemplateDesigner | **CREATE** | ➕ New | FlyerTemplateDesigner.svelte:577 |
| Desktop | FlyerTemplateDesigner | **CREATE** | ➕ Add Sub Page | FlyerTemplateDesigner.svelte:641 |
| Desktop | FlyerTemplateDesigner | **DELETE** | removeSubPage(index)} title="Remove this page">  | FlyerTemplateDesigner.svelte:653 |
| Desktop | FlyerTemplateDesigner | **CREATE** | ➕ Add Product Field | FlyerTemplateDesigner.svelte:682 |
| Desktop | FlyerTemplateDesigner | **CREATE** | 🎨 Add Special Symbol | FlyerTemplateDesigner.svelte:690 |
| Desktop | FlyerTemplateDesigner | **DELETE** | deleteField(field.id)} title= | FlyerTemplateDesigner.svelte:718 |
| Desktop | ImageTemplatesManager | **EDIT** | saveSlot(slot.slot_number)} disabled={slot | ImageTemplatesManager.svelte:397 |
| Desktop | InterfaceAccessManager | **CREATE** | Refresh | InterfaceAccessManager.svelte:524 |
| Desktop | InterfaceAccessManager | **EDIT** | openPermissionModal(user)} disabled={is | InterfaceAccessManager.svelte:640 |
| Desktop | InterfaceAccessManager | **CREATE** | Refresh | InterfaceAccessManager.svelte:725 |
| Desktop | InterfaceAccessManager | **CREATE** | Refresh | InterfaceAccessManager.svelte:860 |
| Desktop | ManageAdminUsers | **CREATE** | ➕ Create Admin | ManageAdminUsers.svelte:384 |
| Desktop | ManageAdminUsers | **DELETE** | Clear | ManageAdminUsers.svelte:395 |
| Desktop | ManageAdminUsers | **EDIT** | editUser(user)} disabled={!canModifyUse | ManageAdminUsers.svelte:514 |
| Desktop | ManageAdminUsers | **EDIT** | assignRoles(user)} disabled={!canModify | ManageAdminUsers.svelte:522 |
| Desktop | ManageAdminUsers | **DELETE** | handleUserAction(user, 'delete')} cla | ManageAdminUsers.svelte:560 |
| Desktop | ManageAdminUsers | **CREATE** | Create First Admin User | ManageAdminUsers.svelte:581 |
| Desktop | ManageMasterAdmin | **EDIT** | editMasterAdmin(admin)}> ✏️ Edit | ManageMasterAdmin.svelte:589 |
| Desktop | ManageMasterAdmin | **DELETE** | handleMasterAdminAction(admin, 'delete')} class="d | ManageMasterAdmin.svelte:635 |
| Desktop | ManageMasterAdmin | **EDIT** | {#if isLoading} Updating...  | ManageMasterAdmin.svelte:736 |
| Desktop | ManageMasterAdmin | **CREATE** | showCreateForm = false}>× | ManageMasterAdmin.svelte:792 |
| Desktop | ManageMasterAdmin | **CREATE** | showCreateForm = false}> Cancel | ManageMasterAdmin.svelte:901 |
| Desktop | ManageMasterAdmin | **CREATE** | {#if isLoading} Creating...  | ManageMasterAdmin.svelte:904 |
| Desktop | ManageVendor | **CREATE** | ➕ Create Vendor | ManageVendor.svelte:575 |
| Desktop | ManageVendor | **DELETE** | searchQuery = ''}>× | ManageVendor.svelte:651 |
| Desktop | ManageVendor | **DELETE** | searchQuery = ''}>Clear Search | ManageVendor.svelte:723 |
| Desktop | ManageVendor | **EDIT** | openEditWindow(vendor)}>✏️ Edit | ManageVendor.svelte:1050 |
| Desktop | ManualScheduling | **DELETE** | { searchTerm = ''; filterVendors(); }} > | ManualScheduling.svelte:546 |
| Desktop | MonthDetails | **EDIT** | openPaymentMethodEdit(payment)}  | MonthDetails.svelte:1903 |
| Desktop | MonthDetails | **EDIT** | openEditAmountModal(payment)} tit | MonthDetails.svelte:1970 |
| Desktop | MonthDetails | **DELETE** | deleteVendorPayment(payment)} tit | MonthDetails.svelte:1979 |
| Desktop | MonthDetails | **DELETE** | deleteExpensePayment(payment)} ti | MonthDetails.svelte:2123 |
| Desktop | MonthDetails | **CREATE** | 📦 Move Full Payment Mo | MonthDetails.svelte:2227 |
| Desktop | MonthDetails | **EDIT** | × | MonthDetails.svelte:2303 |
| Desktop | MonthDetails | **EDIT** | Cancel | MonthDetails.svelte:2394 |
| Desktop | MonthDetails | **EDIT** | Save Changes | MonthDetails.svelte:2395 |
| Desktop | MonthDetails | **CREATE** | 📦 Move Full Payment Mo | MonthDetails.svelte:2454 |
| Desktop | MonthDetails | **EDIT** | ✕ | MonthDetails.svelte:2530 |
| Desktop | MonthDetails | **EDIT** | Cancel | MonthDetails.svelte:2678 |
| Desktop | MonthlyManager | **EDIT** | openPaymentMethodEdit(payment)} title= | MonthlyManager.svelte:862 |
| Desktop | MonthlyManager | **EDIT** | openEditAmountModal(payment)} title="E | MonthlyManager.svelte:895 |
| Desktop | MonthlyManager | **DELETE** | deleteVendorPayment(payment)} title="D | MonthlyManager.svelte:906 |
| Desktop | MonthlyManager | **DELETE** | deleteExpensePayment(payment)} title=" | MonthlyManager.svelte:1043 |
| Desktop | MonthlyManager | **EDIT** | showEditAmountModal = false}>Cancel | MonthlyManager.svelte:1201 |
| Desktop | MonthlyManager | **EDIT** | Save | MonthlyManager.svelte:1202 |
| Desktop | MultipleBillScheduling | **EDIT** | ✕ | MultipleBillScheduling.svelte:985 |
| Desktop | MultipleBillScheduling | **EDIT** | Close | MultipleBillScheduling.svelte:1188 |
| Desktop | MultipleBillScheduling | **CREATE** | ➕ New Schedule | MultipleBillScheduling.svelte:1227 |
| Desktop | MyAssignmentsView | **DELETE** | Clear Filters | MyAssignmentsView.svelte:541 |
| Desktop | NotificationCenter | **CREATE** | 📝 Create Notification | NotificationCenter.svelte:903 |
| Desktop | NotificationCenter | **DELETE** | deleteNotification(notification.id)} t | NotificationCenter.svelte:1009 |
| Desktop | OfferForm | **CREATE** | + {isRTL ? 'اختيار المنتجات' : 'Select Prod | OfferForm.svelte:767 |
| Desktop | OfferForm | **CREATE** | {#if loading} {/if} {isRTL ? (edi | OfferForm.svelte:955 |
| Desktop | OfferManagement | **CREATE** | createOfferWithType('percentage')}> 📊 {l | OfferManagement.svelte:973 |
| Desktop | OfferManagement | **CREATE** | createOfferWithType('special_price')}> 💰 | OfferManagement.svelte:976 |
| Desktop | OfferManagement | **CREATE** | createOfferWithType('bogo')}> 🎁 {locale  | OfferManagement.svelte:979 |
| Desktop | OfferManagement | **CREATE** | createOfferWithType('bundle')}> 📦 {local | OfferManagement.svelte:982 |
| Desktop | OfferManagement | **CREATE** | createOfferWithType('cart')}> 🛒 {locale  | OfferManagement.svelte:985 |
| Desktop | OfferManagement | **CREATE** | ➕ {texts.createNew} | OfferManagement.svelte:1080 |
| Desktop | OfferManagement | **EDIT** | editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1147 |
| Desktop | OfferManagement | **DELETE** | deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1158 |
| Desktop | OfferManagement | **EDIT** | editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1217 |
| Desktop | OfferManagement | **DELETE** | deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1228 |
| Desktop | OfferManagement | **EDIT** | editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1288 |
| Desktop | OfferManagement | **DELETE** | deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1299 |
| Desktop | OfferManagement | **EDIT** | editOffer(offer.id)} title={texts.edit}>  | OfferManagement.svelte:1405 |
| Desktop | OfferManagement | **DELETE** | deleteOffer(offer.id)} title={texts.delete}>  | OfferManagement.svelte:1411 |
| Desktop | OfferManager | **DELETE** | deleteOffer(offer.id, offer.template_name)}  | OfferManager.svelte:258 |
| Desktop | OfferProductSelector | **CREATE** | Add Template | OfferProductSelector.svelte:613 |
| Desktop | OfferProductSelector | **DELETE** | removeTemplate(template.id)} class="tex | OfferProductSelector.svelte:637 |
| Desktop | OfferProductSelector | **DELETE** | Clear Filters | OfferProductSelector.svelte:760 |
| Desktop | OfferTemplates | **CREATE** | selectTemplate(template)} class="bg-white  | OfferTemplates.svelte:294 |
| Desktop | OrdersManager | **DELETE** | {t('orders.filters.clear', 'Clear')} | OrdersManager.svelte:426 |
| Desktop | OtherDocumentsManager | **CREATE** | {#if isUploading} Uploading... { | OtherDocumentsManager.svelte:529 |
| Desktop | OtherDocumentsManager | **DELETE** | deleteDocument(doc.id)}> 🗑️ | OtherDocumentsManager.svelte:574 |
| Desktop | PaidManager | **EDIT** | updateVendorReference(payment.id, editingVendorRef | PaidManager.svelte:528 |
| Desktop | PaidManager | **EDIT** | editingVendorPaymentId = null}>✕ | PaidManager.svelte:529 |
| Desktop | PaidManager | **EDIT** | updateExpenseReference(payment.id, editingExpenseR | PaidManager.svelte:628 |
| Desktop | PaidManager | **EDIT** | editingExpensePaymentId = null}>✕ | PaidManager.svelte:629 |
| Desktop | PaidManager | **EDIT** | showEditPopup = false}>Cancel | PaidManager.svelte:769 |
| Desktop | PriceValidationWarning | **DELETE** | { if (selectedAction === 'continue') handleC | PriceValidationWarning.svelte:172 |
| Desktop | PricingManager | **CREATE** | loadOfferProducts(offer.id)} class="p-4 bor | PricingManager.svelte:1429 |
| Desktop | ProductFieldConfigurator | **CREATE** | ➕ Add Field | ProductFieldConfigurator.svelte:95 |
| Desktop | ProductFieldConfigurator | **DELETE** | deleteField(index)}>🗑️ | ProductFieldConfigurator.svelte:113 |
| Desktop | ProductFieldConfiguratorFlyer | **CREATE** | ➕ Add Field | ProductFieldConfiguratorFlyer.svelte:519 |
| Desktop | ProductFieldConfiguratorFlyer | **DELETE** | deleteField(fieldItem.id)}>🗑️ | ProductFieldConfiguratorFlyer.svelte:528 |
| Desktop | ProductFieldConfiguratorFlyer | **DELETE** | removeIcon(fieldItem.id)}>✕ | ProductFieldConfiguratorFlyer.svelte:599 |
| Desktop | ProductFieldConfiguratorFlyer | **DELETE** | removeSymbol(fieldItem.id)}>✕ | ProductFieldConfiguratorFlyer.svelte:653 |
| Desktop | ProductManager | **CREATE** | { selectedProducts.clear(); sele | ProductManager.svelte:743 |
| Desktop | ProductMaster | **CREATE** | closeCreatePopup | ProductMaster.svelte:1466 |
| Desktop | ProductMaster | **CREATE** | Cancel | ProductMaster.svelte:1656 |
| Desktop | ProductMaster | **CREATE** | {#if isSavingCreate}  | ProductMaster.svelte:1663 |
| Desktop | ProductMaster | **EDIT** | closeEditPopup | ProductMaster.svelte:1702 |
| Desktop | ProductMaster | **EDIT** | Cancel | ProductMaster.svelte:1834 |
| Desktop | ProductMaster | **EDIT** | {#if isSavingEdit}  | ProductMaster.svelte:1841 |
| Desktop | ProductMaster | **DELETE** | downloadAndUploadImage(image.url || image, 'client | ProductMaster.svelte:2051 |
| Desktop | ProductMaster | **DELETE** | downloadAndUploadImage(image.url || image, 'api')} | ProductMaster.svelte:2065 |
| Desktop | ProductMaster | **CREATE** | Create Product | ProductMaster.svelte:2178 |
| Desktop | ProductMaster | **EDIT** | openEditPopup(product)} class="px-3 py | ProductMaster.svelte:2523 |
| Desktop | ProductMaster | **EDIT** | document.getElementById(`update-image-${product.ba | ProductMaster.svelte:2705 |
| Desktop | ProductMaster | **EDIT** | openEditPopup(product)} class="px-3 py | ProductMaster.svelte:2724 |
| Desktop | ProductMaster | **DELETE** | searchBarcode = ''} class="px-4 py-2 text-g | ProductMaster.svelte:2784 |
| Desktop | ProductMaster | **DELETE** | searchBarcode = ''} class="px-6 py-2 bg-blue- | ProductMaster.svelte:2904 |
| Desktop | QuickTaskCompletionDialog | **DELETE** | removeFile(file.id)} disabled={loading}  | QuickTaskCompletionDialog.svelte:298 |
| Desktop | ReceivingRecords | **EDIT** | updateOriginalBill(record.id)} title="Upload updat | ReceivingRecords.svelte:1200 |
| Desktop | ReceivingRecords | **DELETE** | deleteReceivingRecord(record.id)} title | ReceivingRecords.svelte:1361 |
| Desktop | ReceivingRecords | **EDIT** | {#if updatingErp} Updating...  | ReceivingRecords.svelte:1440 |
| Desktop | ReceivingTaskCompletionDialog | **DELETE** | removePRExcelFile | ReceivingTaskCompletionDialog.svelte:784 |
| Desktop | ReceivingTaskCompletionDialog | **DELETE** | removeOriginalBillFile | ReceivingTaskCompletionDialog.svelte:832 |
| Desktop | ReceivingTasksDashboard | **DELETE** | removePRExcelFile | ReceivingTasksDashboard.svelte:686 |
| Desktop | ReceivingTasksDashboard | **DELETE** | removeOriginalBillFile | ReceivingTasksDashboard.svelte:736 |
| Desktop | RecurringExpenseScheduler | **CREATE** | + Add Custom Dates | RecurringExpenseScheduler.svelte:960 |
| Desktop | RecurringExpenseScheduler | **DELETE** | removeCustomDate(date)}>× | RecurringExpenseScheduler.svelte:969 |
| Desktop | RecurringExpenseScheduler | **CREATE** | ➕ New Schedule | RecurringExpenseScheduler.svelte:1026 |
| Desktop | ReportingMap | **EDIT** | Cancel | ReportingMap.svelte:305 |
| Desktop | ReportingMap | **EDIT** | {#if isLoading} {isEditing ? 'Upd | ReportingMap.svelte:309 |
| Desktop | ReportingMap | **CREATE** | 🔄 Refresh | ReportingMap.svelte:326 |
| Desktop | ReportingMap | **EDIT** | editReportingMap(map)} disabled={isLo | ReportingMap.svelte:389 |
| Desktop | ReportingMap | **DELETE** | deleteReportingMap(map.id)} disabled= | ReportingMap.svelte:397 |
| Desktop | RequestClosureManager | **EDIT** | Cancel | RequestClosureManager.svelte:1269 |
| Desktop | RequestClosureManager | **EDIT** | saveBill(activeBillIndex)} disabled={bil | RequestClosureManager.svelte:1276 |
| Desktop | RequestGenerator | **DELETE** | Clear | RequestGenerator.svelte:1183 |
| Desktop | RequestGenerator | **CREATE** | 💾 Save Requester | RequestGenerator.svelte:1202 |
| Desktop | RequestGenerator | **DELETE** | ❌ Clear Selection | RequestGenerator.svelte:1288 |
| Desktop | RequestGenerator | **CREATE** | Create New Requisition | RequestGenerator.svelte:1423 |
| Desktop | RequestsManager | **APPROVE** | handleStatusFilter('approved')}> ✅  | RequestsManager.svelte:331 |
| Desktop | RequestsManager | **APPROVE** | handleStatusFilter('rejected')}> ❌  | RequestsManager.svelte:339 |
| Desktop | SalaryManagement | **DELETE** | searchQuery = ''} > Clear Search | SalaryManagement.svelte:520 |
| Desktop | SalaryManagement | **EDIT** | openSalaryWindow(employee)} title="Up | SalaryManagement.svelte:598 |
| Desktop | Settings | **DELETE** | {#if isClearing}  | Settings.svelte:188 |
| Desktop | ShelfPaperTemplateDesigner | **CREATE** | ➕ New | ShelfPaperTemplateDesigner.svelte:423 |
| Desktop | ShelfPaperTemplateDesigner | **CREATE** | ➕ Add Field | ShelfPaperTemplateDesigner.svelte:482 |
| Desktop | ShelfPaperTemplateDesigner | **DELETE** | deleteField(field.id)}>🗑️ | ShelfPaperTemplateDesigner.svelte:491 |
| Desktop | SingleBillScheduling | **CREATE** | ➕ New Schedule | SingleBillScheduling.svelte:1169 |
| Desktop | StartReceiving | **DELETE** | removeNightSupervisor(supervisor.id)}  | StartReceiving.svelte:2926 |
| Desktop | StartReceiving | **DELETE** | removeNightSupervisor(user.id)}  | StartReceiving.svelte:3006 |
| Desktop | StartReceiving | **DELETE** | × | StartReceiving.svelte:3067 |
| Desktop | StartReceiving | **DELETE** | Remove | StartReceiving.svelte:3145 |
| Desktop | StartReceiving | **DELETE** | × | StartReceiving.svelte:3221 |
| Desktop | StartReceiving | **DELETE** | Remove | StartReceiving.svelte:3303 |
| Desktop | StartReceiving | **DELETE** | searchQuery = ''}>× | StartReceiving.svelte:3560 |
| Desktop | StartReceiving | **DELETE** | searchQuery = ''}>Clear Search | StartReceiving.svelte:3615 |
| Desktop | StartReceiving | **EDIT** | openEditWindow(vendor)}>  | StartReceiving.svelte:3880 |
| Desktop | StartReceiving | **DELETE** | � Generate Clearance Certificate | StartReceiving.svelte:4445 |
| Desktop | StartReceiving | **DELETE** | � Generate Clearance Certificate | StartReceiving.svelte:4449 |
| Desktop | StartReceiving | **EDIT** | × | StartReceiving.svelte:8215 |
| Desktop | StartReceiving | **EDIT** | {isUpdatingVendor ? 'Updating...' : 'Update & Cont | StartReceiving.svelte:8261 |
| Desktop | StartReceiving | **EDIT** | handlePaymentUpdateCancel()}> Cancel | StartReceiving.svelte:8288 |
| Desktop | StartReceiving | **EDIT** | handlePaymentUpdateConfirm()}> OK | StartReceiving.svelte:8291 |
| Desktop | StartReceiving | **EDIT** | closeVendorUpdatedModal()}> OK | StartReceiving.svelte:8314 |
| Desktop | StartReceiving | **EDIT** | closeVendorInfoUpdatedModal()}> OK | StartReceiving.svelte:8337 |
| Desktop | TaskAssignmentView | **CREATE** | New Task | TaskAssignmentView.svelte:816 |
| Desktop | TaskAssignmentView | **CREATE** | Refresh | TaskAssignmentView.svelte:836 |
| Desktop | TaskAssignmentView | **CREATE** | New Task | TaskAssignmentView.svelte:1112 |
| Desktop | TaskAssignmentView | **CREATE** | Refresh | TaskAssignmentView.svelte:1121 |
| Desktop | TaskAssignmentView | **DELETE** | {taskSearchTerm = ''; taskStatusFilter = ''; taskP | TaskAssignmentView.svelte:1193 |
| Desktop | TaskAssignmentView | **CREATE** | Create New Task | TaskAssignmentView.svelte:1216 |
| Desktop | TaskAssignmentView | **EDIT** | editTask(task)} class="text-purple- | TaskAssignmentView.svelte:1332 |
| Desktop | TaskAssignmentViewNew | **CREATE** | New Task | TaskAssignmentViewNew.svelte:431 |
| Desktop | TaskAssignmentViewNew | **CREATE** | Refresh | TaskAssignmentViewNew.svelte:451 |
| Desktop | TaskAssignmentViewNew | **DELETE** | {taskSearchTerm = ''; taskStatusFilter = ''; taskP | TaskAssignmentViewNew.svelte:700 |
| Desktop | TaskAssignmentViewNew | **EDIT** | Edit | TaskAssignmentViewNew.svelte:768 |
| Desktop | TaskAssignmentViewNew | **CREATE** | Create New Task | TaskAssignmentViewNew.svelte:785 |
| Desktop | TaskCompletionModal | **DELETE** | removePhoto | TaskCompletionModal.svelte:1138 |
| Desktop | TaskCreateForm | **CREATE** | {isSubmitting ? (editMode ? 'Updating...' | TaskCreateForm.svelte:310 |
| Desktop | TaskStatusView | **CREATE** | Refresh | TaskStatusView.svelte:579 |
| Desktop | TaskViewTable | **EDIT** | Bulk Edit | TaskViewTable.svelte:381 |
| Desktop | TaskViewTable | **DELETE** | Delete Selected | TaskViewTable.svelte:384 |
| Desktop | TaskViewTable | **CREATE** | handleSort('created_at')} class="flex ite | TaskViewTable.svelte:464 |
| Desktop | TaskViewTable | **EDIT** | editTask(task)} class="text-blue-600 ho | TaskViewTable.svelte:571 |
| Desktop | TaskViewTable | **DELETE** | deleteTask(task.id)} class="text-red-60 | TaskViewTable.svelte:580 |
| Desktop | TaxManager | **CREATE** | ➕ Add Tax Category | TaxManager.svelte:112 |
| Desktop | TaxManager | **CREATE** | Create First Tax Category | TaxManager.svelte:128 |
| Desktop | TaxManager | **DELETE** | deleteTax(tax)} title="Delete"  | TaxManager.svelte:161 |
| Desktop | TierManager | **CREATE** | + {isRTL ? 'إضافة مستوى' : 'Add Tier'} | TierManager.svelte:58 |
| Desktop | TierManager | **DELETE** | removeTier(index)} title={isRTL ? 'حذف ال | TierManager.svelte:134 |
| Desktop | UploadEmployees | **DELETE** | × | UploadEmployees.svelte:254 |
| Desktop | UploadFingerprint | **DELETE** | ❌ | UploadFingerprint.svelte:427 |
| Desktop | UploadFingerprint | **CREATE** | 🔄 Upload New File | UploadFingerprint.svelte:540 |
| Desktop | UploadVendor | **DELETE** | × | UploadVendor.svelte:426 |
| Desktop | UserManagement | **CREATE** | 🔄 Retry | UserManagement.svelte:169 |
| Desktop | UserManagement | **DELETE** | { searchQuery = ''; branchFilter | UserManagement.svelte:214 |
| Desktop | UserManagement | **EDIT** | editUser(user)} title="Edit User"  | UserManagement.svelte:307 |
| Desktop | VariationManager | **EDIT** | Update Group ({selectedProducts.size}) | VariationManager.svelte:694 |
| Desktop | VariationManager | **EDIT** | { isEditMode = false; groupParen | VariationManager.svelte:701 |
| Desktop | VariationManager | **CREATE** | Create Group ({selectedProducts.size}) | VariationManager.svelte:714 |
| Desktop | VariationManager | **EDIT** | openEditGroupModal(group.parent.barcode, group.par | VariationManager.svelte:796 |
| Desktop | VariationManager | **DELETE** | deleteGroup(group.parent.barcode, group.parent.var | VariationManager.svelte:802 |
| Desktop | VariationManager | **CREATE** | {#if isCreatingGroup} {isEditMode ? | VariationManager.svelte:1170 |
| Desktop | VariationSelectionModal | **CREATE** | Add Selected ({selectedCount}) | VariationSelectionModal.svelte:269 |
| Desktop | VendorPendingPayments | **DELETE** | Clear | VendorPendingPayments.svelte:282 |
| Desktop | VendorRecords | **DELETE** | Clear Filters | VendorRecords.svelte:268 |
| Desktop | VideoTemplatesManager | **EDIT** | saveSlot(slot.slot_number)} disabled={slot | VideoTemplatesManager.svelte:435 |
| Desktop | ViewOfferManager | **CREATE** | ➕ Add Offer | ViewOfferManager.svelte:188 |
| Desktop | ViewOfferManager | **EDIT** | openEditOfferWindow(offer.id, offer.offer_name)}  | ViewOfferManager.svelte:250 |
| Desktop | WarningDetailsModal | **EDIT** | {isUpdating ? 'Updating...' : 'Update Warning'} | WarningDetailsModal.svelte:348 |
| Desktop | WarningTemplate | **EDIT** | {#if isEditing} Sa | WarningTemplate.svelte:1014 |
| Desktop | WarningTemplateImageModal | **CREATE** | Open | WarningTemplateImageModal.svelte:54 |
| Desktop | AddOfferDialog | **CREATE** | {isLoading ? (isEditing ? 'Updating...' : 'Adding. | AddOfferDialog.svelte:450 |
| Desktop | CampaignManager | **CREATE** | ➕ {t('coupon.createCampaign')} | CampaignManager.svelte:298 |
| Desktop | CampaignManager | **EDIT** | openEditForm(campaign)} class="flex-1 p | CampaignManager.svelte:510 |
| Desktop | CampaignManager | **DELETE** | handleDelete(campaign)} class="px-3 py- | CampaignManager.svelte:522 |
| Desktop | CouponDashboard | **CREATE** | {t('coupon.createFirst') || 'Create Your First Cam | CouponDashboard.svelte:47 |
| Desktop | CustomerImporter | **CREATE** | showAddNumberModal = true} disabled={!sele | CustomerImporter.svelte:552 |
| Desktop | CustomerImporter | **DELETE** | handleDeleteCustomer(customer.id)} d | CustomerImporter.svelte:596 |
| Desktop | CustomerImporter | **CREATE** | ✅ {t('coupon.add')} | CustomerImporter.svelte:643 |
| Desktop | CustomerImporter | **CREATE** | { showAddNumberModal = false; newNum | CustomerImporter.svelte:649 |
| Desktop | DesignPlanner | **CREATE** | loadOfferProducts(offer.id)} >  | DesignPlanner.svelte:1009 |
| Desktop | FlyerTemplateDesigner | **CREATE** | ➕ New | FlyerTemplateDesigner.svelte:577 |
| Desktop | FlyerTemplateDesigner | **CREATE** | ➕ Add Sub Page | FlyerTemplateDesigner.svelte:641 |
| Desktop | FlyerTemplateDesigner | **DELETE** | removeSubPage(index)} title="Remove this page">  | FlyerTemplateDesigner.svelte:653 |
| Desktop | FlyerTemplateDesigner | **CREATE** | ➕ Add Product Field | FlyerTemplateDesigner.svelte:682 |
| Desktop | FlyerTemplateDesigner | **CREATE** | 🎨 Add Special Symbol | FlyerTemplateDesigner.svelte:690 |
| Desktop | FlyerTemplateDesigner | **DELETE** | deleteField(field.id)} title= | FlyerTemplateDesigner.svelte:718 |
| Desktop | OfferManager | **DELETE** | deleteOffer(offer.id, offer.template_name)}  | OfferManager.svelte:258 |
| Desktop | OfferProductSelector | **CREATE** | Add Template | OfferProductSelector.svelte:613 |
| Desktop | OfferProductSelector | **DELETE** | removeTemplate(template.id)} class="tex | OfferProductSelector.svelte:637 |
| Desktop | OfferProductSelector | **DELETE** | Clear Filters | OfferProductSelector.svelte:760 |
| Desktop | OfferTemplates | **CREATE** | selectTemplate(template)} class="bg-white  | OfferTemplates.svelte:294 |
| Desktop | PriceValidationWarning | **DELETE** | { if (selectedAction === 'continue') handleC | PriceValidationWarning.svelte:172 |
| Desktop | PricingManager | **CREATE** | loadOfferProducts(offer.id)} class="p-4 bor | PricingManager.svelte:1429 |
| Desktop | ProductFieldConfigurator | **CREATE** | ➕ Add Field | ProductFieldConfigurator.svelte:95 |
| Desktop | ProductFieldConfigurator | **DELETE** | deleteField(index)}>🗑️ | ProductFieldConfigurator.svelte:113 |
| Desktop | ProductFieldConfiguratorFlyer | **CREATE** | ➕ Add Field | ProductFieldConfiguratorFlyer.svelte:519 |
| Desktop | ProductFieldConfiguratorFlyer | **DELETE** | deleteField(fieldItem.id)}>🗑️ | ProductFieldConfiguratorFlyer.svelte:528 |
| Desktop | ProductFieldConfiguratorFlyer | **DELETE** | removeIcon(fieldItem.id)}>✕ | ProductFieldConfiguratorFlyer.svelte:599 |
| Desktop | ProductFieldConfiguratorFlyer | **DELETE** | removeSymbol(fieldItem.id)}>✕ | ProductFieldConfiguratorFlyer.svelte:653 |
| Desktop | ProductManager | **CREATE** | { selectedProducts.clear(); sele | ProductManager.svelte:743 |
| Desktop | ProductMaster | **CREATE** | closeCreatePopup | ProductMaster.svelte:1466 |
| Desktop | ProductMaster | **CREATE** | Cancel | ProductMaster.svelte:1656 |
| Desktop | ProductMaster | **CREATE** | {#if isSavingCreate}  | ProductMaster.svelte:1663 |
| Desktop | ProductMaster | **EDIT** | closeEditPopup | ProductMaster.svelte:1702 |
| Desktop | ProductMaster | **EDIT** | Cancel | ProductMaster.svelte:1834 |
| Desktop | ProductMaster | **EDIT** | {#if isSavingEdit}  | ProductMaster.svelte:1841 |
| Desktop | ProductMaster | **DELETE** | downloadAndUploadImage(image.url || image, 'client | ProductMaster.svelte:2051 |
| Desktop | ProductMaster | **DELETE** | downloadAndUploadImage(image.url || image, 'api')} | ProductMaster.svelte:2065 |
| Desktop | ProductMaster | **CREATE** | Create Product | ProductMaster.svelte:2178 |
| Desktop | ProductMaster | **EDIT** | openEditPopup(product)} class="px-3 py | ProductMaster.svelte:2523 |
| Desktop | ProductMaster | **EDIT** | document.getElementById(`update-image-${product.ba | ProductMaster.svelte:2705 |
| Desktop | ProductMaster | **EDIT** | openEditPopup(product)} class="px-3 py | ProductMaster.svelte:2724 |
| Desktop | ProductMaster | **DELETE** | searchBarcode = ''} class="px-4 py-2 text-g | ProductMaster.svelte:2784 |
| Desktop | ProductMaster | **DELETE** | searchBarcode = ''} class="px-6 py-2 bg-blue- | ProductMaster.svelte:2904 |
| Desktop | ShelfPaperTemplateDesigner | **CREATE** | ➕ New | ShelfPaperTemplateDesigner.svelte:423 |
| Desktop | ShelfPaperTemplateDesigner | **CREATE** | ➕ Add Field | ShelfPaperTemplateDesigner.svelte:482 |
| Desktop | ShelfPaperTemplateDesigner | **DELETE** | deleteField(field.id)}>🗑️ | ShelfPaperTemplateDesigner.svelte:491 |
| Desktop | VariationManager | **EDIT** | Update Group ({selectedProducts.size}) | VariationManager.svelte:694 |
| Desktop | VariationManager | **EDIT** | { isEditMode = false; groupParen | VariationManager.svelte:701 |
| Desktop | VariationManager | **CREATE** | Create Group ({selectedProducts.size}) | VariationManager.svelte:714 |
| Desktop | VariationManager | **EDIT** | openEditGroupModal(group.parent.barcode, group.par | VariationManager.svelte:796 |
| Desktop | VariationManager | **DELETE** | deleteGroup(group.parent.barcode, group.parent.var | VariationManager.svelte:802 |
| Desktop | VariationManager | **CREATE** | {#if isCreatingGroup} {isEditMode ? | VariationManager.svelte:1170 |
| Desktop | VariationSelectionModal | **CREATE** | Add Selected ({selectedCount}) | VariationSelectionModal.svelte:269 |
| Desktop | ViewOfferManager | **CREATE** | ➕ Add Offer | ViewOfferManager.svelte:188 |
| Desktop | ViewOfferManager | **EDIT** | openEditOfferWindow(offer.id, offer.offer_name)}  | ViewOfferManager.svelte:250 |
| Other | +page | **EDIT** | ✅ Approve {selectedItems.size} | +page.svelte:1138 |
| Other | +page | **CREATE** | { selectedItems = new Set(); }}> ✕ Clear | +page.svelte:1141 |
| Other | +page | **APPROVE** | openConfirmModal('approve')} disabled={is | +page.svelte:1506 |
| Other | +page | **APPROVE** | openConfirmModal('reject')} disabled={isP | +page.svelte:1514 |
| Other | +page | **APPROVE** | {confirmAction === 'approve' ? 'Approve' : 'Reject | +page.svelte:1567 |
| Other | +page | **APPROVE** | × | +page.svelte:1587 |
| Other | +page | **APPROVE** | Cancel | +page.svelte:1600 |
| Other | +page | **APPROVE** | {#if isProcessing} Processing... {:e | +page.svelte:1603 |
| Other | +page | **DELETE** | {getTranslation('mobile.assignmentsContent.search. | +page.svelte:531 |
| Other | +page | **CREATE** | {getTranslation('mobile.createNotificationContent. | +page.svelte:425 |
| Other | +page | **CREATE** | {getTranslation('mobile.createNotificationContent. | +page.svelte:428 |
| Other | +page | **CREATE** | {getTranslation('mobile.createNotificationContent. | +page.svelte:487 |
| Other | +page | **CREATE** | {#if isLoading} {getTranslation('mobile.crea | +page.svelte:495 |
| Other | +page | **DELETE** | removeFile(file.id)} class="remove-file-btn">  | +page.svelte:953 |
| Other | +page | **DELETE** | removePhoto | +page.svelte:735 |
| Other | +page | **DELETE** | removePRExcelFile | +page.svelte:844 |
| Other | +page | **DELETE** | removeOriginalBillFile | +page.svelte:896 |
| Other | +page | **CREATE** | goto('/mobile-interface/tasks/create')}>  | +page.svelte:676 |
| Other | +page | **CREATE** | 📷 {getTranslation('mobile.createContent.camera')} | +page.svelte:154 |
| Other | +page | **CREATE** | {getTranslation('mobile.createContent.actions.canc | +page.svelte:171 |
| Other | +page | **CREATE** | {isSubmitting ? getTranslation('mobile.createConte | +page.svelte:174 |
| Other | +page | **EDIT** | updateAssignmentStatus('in_progress')} dis | +page.svelte:419 |
| Other | +page | **EDIT** | updateAssignmentStatus('completed')} disab | +page.svelte:436 |
| Other | +page | **DELETE** | removePhoto | +page.svelte:804 |
| Other | NotificationCenter | **CREATE** | 📝 {getTranslation('mobile.assignContent.cre | NotificationCenter.svelte:1212 |
| Other | NotificationCenter | **DELETE** | deleteNotification(notification.id)} >  | NotificationCenter.svelte:1376 |
| Other | QuickTaskModal | **DELETE** | removeFile(file.id)} class="remove-file-btn"> | QuickTaskModal.svelte:814 |
| Other | TaskCompletionModal | **DELETE** | removePhoto | TaskCompletionModal.svelte:477 |

---

## 🟡 Medium Priority: Other Action Buttons Needing Permission Checks

| Interface | Component | Action | Button Purpose | Location |
|-----------|-----------|--------|----------------|----------|
| Desktop | HomePageScreenManager | UPLOAD | 🎥 Video Templates Manage  | HomePageScreenManager.svelte:65 |
| Desktop | HomePageScreenManager | UPLOAD | 🖼️ Image Templates Manage | HomePageScreenManager.svelte:85 |
| Other | +page | SEND | openEmail()}> {texts.sendEmail} | +page.svelte:166 |
| Desktop | ApprovalCenter | ASSIGN | { activeSection = 'approvals'; filterRequisitions( | ApprovalCenter.svelte:1192 |
| Desktop | ApprovalMask | SEND | Send | ApprovalMask.svelte:35 |
| Desktop | BiometricData | EXPORT | 📊 {t('hr.exportToExcel')} | BiometricData.svelte:642 |
| Desktop | BiometricExport | EXPORT | {#if exporting} {t('hr.exporting')} | BiometricExport.svelte:191 |
| Desktop | ClearanceCertificateManager | UPLOAD | {#if isUploading}  | ClearanceCertificateManager.svelte:1150 |
| Desktop | ContactManagement | SEND | openWhatsApp(employee)} disabled={is | ContactManagement.svelte:426 |
| Desktop | CouponReports | EXPORT | 📥 {t('common.export') || 'Export CSV'} | CouponReports.svelte:147 |
| Desktop | CreateNotification | SEND | {#if isLoading} Sending... {: | CreateNotification.svelte:653 |
| Desktop | CustomerImporter | EXPORT | ⬇️ {t('coupon.downloadTemplate')} | CustomerImporter.svelte:381 |
| Desktop | CustomerImporter | UPLOAD | {importing ? '⏳ ' + t('coupon.importing') : '🚀 '  | CustomerImporter.svelte:527 |
| Desktop | DayBudgetPlanner | ASSIGN | 🖨️ Generate Day Schedule | DayBudgetPlanner.svelte:861 |
| Desktop | DayBudgetPlanner | ASSIGN | openRescheduleModal(payment, 'vendor')}  | DayBudgetPlanner.svelte:1137 |
| Desktop | DayBudgetPlanner | ASSIGN | Select All | DayBudgetPlanner.svelte:1181 |
| Desktop | DayBudgetPlanner | ASSIGN | openRescheduleModal(expense, 'expense')}  | DayBudgetPlanner.svelte:1314 |
| Desktop | DayBudgetPlanner | ASSIGN | ✕ | DayBudgetPlanner.svelte:1527 |
| Desktop | DayBudgetPlanner | ASSIGN | Cancel | DayBudgetPlanner.svelte:1562 |
| Desktop | DayBudgetPlanner | ASSIGN | Confirm Reschedule | DayBudgetPlanner.svelte:1563 |
| Desktop | DayBudgetPlanner | ASSIGN | = (splitType === 'vendor' ? (splitItem.final_bill_ | DayBudgetPlanner.svelte:1667 |
| Desktop | FlyerGenerator | ASSIGN | selectFieldFromPopup(field)} >  | FlyerGenerator.svelte:1546 |
| Desktop | FlyerGenerator | ASSIGN | assignProductToField(product.barcode)}  | FlyerGenerator.svelte:1681 |
| Desktop | FlyerTemplateDesigner | UPLOAD | {isUploading ? '⏳ Saving...' : '💾 Save Template'} | FlyerTemplateDesigner.svelte:743 |
| Desktop | HomePageScreenManager | UPLOAD | 🎥 Video Templates Manage  | HomePageScreenManager.svelte:65 |
| Desktop | HomePageScreenManager | UPLOAD | 🖼️ Image Templates Manage | HomePageScreenManager.svelte:85 |
| Desktop | ManageAdminUsers | EXPORT | 📊 Export | ManageAdminUsers.svelte:381 |
| Desktop | ManualScheduling | ASSIGN | {#if isLoading} 💾 Saving... {:el | ManualScheduling.svelte:786 |
| Desktop | MonthDetails | ASSIGN | openRescheduleModal(payment)} tit | MonthDetails.svelte:1956 |
| Desktop | MonthDetails | ASSIGN | openExpenseRescheduleModal(payment)}  | MonthDetails.svelte:2105 |
| Desktop | MonthDetails | ASSIGN | × | MonthDetails.svelte:2407 |
| Desktop | MonthlyManager | ASSIGN | openRescheduleModal(payment)} title="R | MonthlyManager.svelte:873 |
| Desktop | MonthlyManager | ASSIGN | openExpenseRescheduleModal(payment)} t | MonthlyManager.svelte:1023 |
| Desktop | MonthlyManager | ASSIGN | showRescheduleModal = false}>Cancel | MonthlyManager.svelte:1087 |
| Desktop | MonthlyManager | ASSIGN | Save | MonthlyManager.svelte:1088 |
| Desktop | MonthlyManager | ASSIGN | showExpenseRescheduleModal = false}>Cancel | MonthlyManager.svelte:1238 |
| Desktop | MonthlyManager | ASSIGN | Save | MonthlyManager.svelte:1239 |
| Desktop | MonthlyPaidManager | EXPORT | 📥 Export CSV | MonthlyPaidManager.svelte:337 |
| Desktop | PricingManager | EXPORT | Export to Excel | PricingManager.svelte:1582 |
| Desktop | PricingManager | UPLOAD | Import from Excel | PricingManager.svelte:1592 |
| Desktop | ProductFieldConfiguratorFlyer | UPLOAD | triggerIconUpload(fieldItem.id)}>  | ProductFieldConfiguratorFlyer.svelte:639 |
| Desktop | ProductFieldConfiguratorFlyer | UPLOAD | triggerSymbolUpload(fieldItem.id)}>  | ProductFieldConfiguratorFlyer.svelte:677 |
| Desktop | ProductMaster | UPLOAD | showUploadSuccessPopup = false} class="w-ful | ProductMaster.svelte:1877 |
| Desktop | ProductMaster | EXPORT | {#if downloadingImage}  | ProductMaster.svelte:1933 |
| Desktop | ProductMaster | EXPORT | downloadAndUploadImage(image.url || image, 'none') | ProductMaster.svelte:2039 |
| Desktop | ProductMaster | UPLOAD | Cancel | ProductMaster.svelte:2104 |
| Desktop | ProductMaster | UPLOAD | {#if isUploadingImages}  | ProductMaster.svelte:2188 |
| Desktop | ProductMaster | EXPORT | Download Template | ProductMaster.svelte:2207 |
| Desktop | ProductMaster | UPLOAD | Import from Excel | ProductMaster.svelte:2217 |
| Desktop | ProductMaster | UPLOAD | Upload | ProductMaster.svelte:2304 |
| Desktop | PushNotificationSettings | SEND | {#if isLoading} {:else}  | PushNotificationSettings.svelte:283 |
| Desktop | QuickTaskCompletionDialog | UPLOAD | 📸 Upload Photos | QuickTaskCompletionDialog.svelte:275 |
| Desktop | QuickTaskCompletionDialog | UPLOAD | {#if uploadingFiles} Uploading Files... | QuickTaskCompletionDialog.svelte:328 |
| Desktop | ReceivingRecords | UPLOAD | uploadOriginalBill(record.id)}> 📎  | ReceivingRecords.svelte:1215 |
| Desktop | ReceivingRecords | EXPORT | downloadPRExcel(record)} > 📊 | ReceivingRecords.svelte:1226 |
| Desktop | ReceivingRecords | UPLOAD | uploadPRExcel(record.id)}> 📊  | ReceivingRecords.svelte:1259 |
| Desktop | RecurringExpenseScheduler | ASSIGN | {#if saving} Submitting... {:else}  | RecurringExpenseScheduler.svelte:1044 |
| Desktop | RequestsManager | EXPORT | 📥 Export CSV | RequestsManager.svelte:286 |
| Desktop | Scheduler | ASSIGN | 📄 Single Bill Scheduling Schedule a one | Scheduler.svelte:42 |
| Desktop | Scheduler | ASSIGN | 📋 Multiple Bill Scheduling Schedule pay | Scheduler.svelte:49 |
| Desktop | Scheduler | ASSIGN | 🔄 Recurring Expense Scheduler Schedule re | Scheduler.svelte:56 |
| Desktop | Scheduler | ASSIGN | ← Back to Scheduler | Scheduler.svelte:66 |
| Desktop | Scheduler | ASSIGN | ← Back to Scheduler | Scheduler.svelte:71 |
| Desktop | ShelfPaperTemplateDesigner | UPLOAD | {isUploading ? 'Saving...' : '💾 Save Template'} | ShelfPaperTemplateDesigner.svelte:562 |
| Desktop | SingleBillScheduling | ASSIGN | {#if saving || uploading} Submitting...  | SingleBillScheduling.svelte:1188 |
| Desktop | TaskAssignmentView | ASSIGN | switchView('settings')} class="flex items-cen | TaskAssignmentView.svelte:890 |
| Desktop | TaskAssignmentView | ASSIGN | {#if isAssigning}  | TaskAssignmentView.svelte:1885 |
| Desktop | TaskAssignmentViewNew | ASSIGN | switchView('settings')} class="flex items-cen | TaskAssignmentViewNew.svelte:505 |
| Desktop | TaskAssignmentViewNew | ASSIGN | {#if isAssigning}  | TaskAssignmentViewNew.svelte:1089 |
| Desktop | TaskCompletionModal | ASSIGN | 👥 Reassign Task | TaskCompletionModal.svelte:1012 |
| Desktop | TaskCompletionModal | ASSIGN | 👥 Reassign Task | TaskCompletionModal.svelte:1041 |
| Desktop | TaskCompletionModal | ASSIGN | × | TaskCompletionModal.svelte:1208 |
| Desktop | TaskCompletionModal | ASSIGN | Cancel | TaskCompletionModal.svelte:1232 |
| Desktop | TaskCompletionModal | ASSIGN | {#if isSubmitting} Reassigning...  | TaskCompletionModal.svelte:1233 |
| Desktop | TaskDetailsView | SEND | {#if isSendingReminders}  | TaskDetailsView.svelte:1439 |
| Desktop | TaskDetailsView | SEND | Send to All Overdue | TaskDetailsView.svelte:1458 |
| Desktop | TaskStatusView | ASSIGN | sendReminder(assignment)} >  | TaskStatusView.svelte:770 |
| Desktop | TaskStatusView | ASSIGN | openWarningModal(assignment)} >  | TaskStatusView.svelte:776 |
| Desktop | UploadEmployees | EXPORT | ⬇️ {t('hr.downloadTemplate')} | UploadEmployees.svelte:287 |
| Desktop | UploadEmployees | UPLOAD | {#if isLoading} {t('hr.uploading')}  | UploadEmployees.svelte:303 |
| Desktop | UploadFingerprint | EXPORT | 📥 Download Template | UploadFingerprint.svelte:357 |
| Desktop | UploadFingerprint | UPLOAD | fileInput?.click()} disabled={isUploading} | UploadFingerprint.svelte:409 |
| Desktop | UploadFingerprint | UPLOAD | {#if isUploading} Processing...  | UploadFingerprint.svelte:472 |
| Desktop | UploadFingerprint | UPLOAD | {#if isUploading} Saving... | UploadFingerprint.svelte:521 |
| Desktop | UploadVendor | EXPORT | 📥 Download Template | UploadVendor.svelte:387 |
| Desktop | UploadVendor | UPLOAD | 🔄 Reset Upload | UploadVendor.svelte:555 |
| Desktop | UploadVendor | UPLOAD | {#if isUploading} Uploading... {:else}  | UploadVendor.svelte:558 |
| Desktop | WarningStatistics | EXPORT | Export Report | WarningStatistics.svelte:233 |
| Desktop | WarningTemplate | SEND | {#if isSending} {:else}  | WarningTemplate.svelte:1164 |
| Desktop | WarningTemplateImageModal | EXPORT | Download | WarningTemplateImageModal.svelte:48 |
| Desktop | CouponReports | EXPORT | 📥 {t('common.export') || 'Export CSV'} | CouponReports.svelte:147 |
| Desktop | CustomerImporter | EXPORT | ⬇️ {t('coupon.downloadTemplate')} | CustomerImporter.svelte:381 |
| Desktop | CustomerImporter | UPLOAD | {importing ? '⏳ ' + t('coupon.importing') : '🚀 '  | CustomerImporter.svelte:527 |
| Desktop | FlyerGenerator | ASSIGN | selectFieldFromPopup(field)} >  | FlyerGenerator.svelte:1546 |
| Desktop | FlyerGenerator | ASSIGN | assignProductToField(product.barcode)}  | FlyerGenerator.svelte:1681 |
| Desktop | FlyerTemplateDesigner | UPLOAD | {isUploading ? '⏳ Saving...' : '💾 Save Template'} | FlyerTemplateDesigner.svelte:743 |
| Desktop | PricingManager | EXPORT | Export to Excel | PricingManager.svelte:1582 |
| Desktop | PricingManager | UPLOAD | Import from Excel | PricingManager.svelte:1592 |
| Desktop | ProductFieldConfiguratorFlyer | UPLOAD | triggerIconUpload(fieldItem.id)}>  | ProductFieldConfiguratorFlyer.svelte:639 |
| Desktop | ProductFieldConfiguratorFlyer | UPLOAD | triggerSymbolUpload(fieldItem.id)}>  | ProductFieldConfiguratorFlyer.svelte:677 |
| Desktop | ProductMaster | UPLOAD | showUploadSuccessPopup = false} class="w-ful | ProductMaster.svelte:1877 |
| Desktop | ProductMaster | EXPORT | {#if downloadingImage}  | ProductMaster.svelte:1933 |
| Desktop | ProductMaster | EXPORT | downloadAndUploadImage(image.url || image, 'none') | ProductMaster.svelte:2039 |
| Desktop | ProductMaster | UPLOAD | Cancel | ProductMaster.svelte:2104 |
| Desktop | ProductMaster | UPLOAD | {#if isUploadingImages}  | ProductMaster.svelte:2188 |
| Desktop | ProductMaster | EXPORT | Download Template | ProductMaster.svelte:2207 |
| Desktop | ProductMaster | UPLOAD | Import from Excel | ProductMaster.svelte:2217 |
| Desktop | ProductMaster | UPLOAD | Upload | ProductMaster.svelte:2304 |
| Desktop | ShelfPaperTemplateDesigner | UPLOAD | {isUploading ? 'Saving...' : '💾 Save Template'} | ShelfPaperTemplateDesigner.svelte:562 |
| Other | +page | EXPORT | downloadFile(attachment)} title="{g | +page.svelte:667 |
| Other | +page | EXPORT | downloadFile(attachment)} >  | +page.svelte:681 |
| Other | +page | ASSIGN | {#if isSubmitting} {getTranslation( | +page.svelte:987 |
| Other | +page | ASSIGN | goto('/mobile-interface/assignments')}> ← Ba | +page.svelte:540 |
| Other | +page | EXPORT | downloadFile(file.fileUrl, file.fileName)}  | +page.svelte:645 |
| Other | +page | ASSIGN | goto('/mobile-interface/assignments')} disabled={i | +page.svelte:786 |
| Other | +page | EXPORT | downloadSingleAttachment(attachment)}  | +page.svelte:1060 |
| Other | +page | EXPORT | downloadSingleAttachment(attachment)}  | +page.svelte:1089 |
| Other | +page | ASSIGN | {getTranslation('mobile.assignContent.actions.canc | +page.svelte:784 |
| Other | +page | ASSIGN | {getTranslation('mobile.assignContent.actions.next | +page.svelte:792 |
| Other | +page | ASSIGN | {getTranslation('mobile.assignContent.actions.prev | +page.svelte:846 |
| Other | +page | ASSIGN | {getTranslation('mobile.assignContent.actions.next | +page.svelte:854 |
| Other | +page | ASSIGN | {getTranslation('mobile.assignContent.actions.prev | +page.svelte:1023 |
| Other | +page | ASSIGN | {getTranslation('mobile.assignContent.actions.next | +page.svelte:1031 |
| Other | +page | ASSIGN | {getTranslation('mobile.assignContent.actions.prev | +page.svelte:1098 |
| Other | +page | ASSIGN | {getTranslation('mobile.assignContent.actions.canc | +page.svelte:1106 |
| Other | +page | ASSIGN | {isAssigning ? getTranslation('mobile.assignConten | +page.svelte:1116 |
| Other | +page | EXPORT | downloadAttachment(attachment)} title="D | +page.svelte:396 |
| Other | +page | EXPORT | downloadFile(attachment.fileUrl, attachment.fileNa | +page.svelte:715 |
| Other | NotificationCenter | EXPORT | downloadFile(attachment)} title=" | NotificationCenter.svelte:1315 |
| Other | NotificationCenter | EXPORT | downloadFile(attachment)} title=" | NotificationCenter.svelte:1337 |
| Other | QuickTaskModal | ASSIGN | Assign Task | QuickTaskModal.svelte:853 |

---

## 📝 Component Summary (Components with Critical Actions)

| Component Name | Interface | Total Buttons | Critical Actions | File Path |
|----------------|-----------|---------------|------------------|------------|
| BundleCreator | Desktop | 8 | 4 | `frontend\src\lib\components\desktop-interface\admin-customer-app\offers\BundleCreator.svelte` |
| CategoriesManager | Desktop | 5 | 4 | `frontend\src\lib\components\desktop-interface\admin-customer-app\products\CategoriesManager.svelte` |
| CustomerAccountRecoveryManager | Desktop | 10 | 5 | `frontend\src\lib\components\desktop-interface\admin-customer-app\CustomerAccountRecoveryManager.svelte` |
| CustomerMaster | Desktop | 15 | 6 | `frontend\src\lib\components\desktop-interface\admin-customer-app\CustomerMaster.svelte` |
| DeliverySettings | Desktop | 13 | 4 | `frontend\src\lib\components\desktop-interface\admin-customer-app\DeliverySettings.svelte` |
| ImageTemplatesManager | Desktop | 4 | 1 | `frontend\src\lib\components\desktop-interface\admin-customer-app\ImageTemplatesManager.svelte` |
| OfferForm | Desktop | 5 | 2 | `frontend\src\lib\components\desktop-interface\admin-customer-app\offers\OfferForm.svelte` |
| OfferManagement | Desktop | 19 | 14 | `frontend\src\lib\components\desktop-interface\admin-customer-app\OfferManagement.svelte` |
| OrdersManager | Desktop | 2 | 1 | `frontend\src\lib\components\desktop-interface\admin-customer-app\OrdersManager.svelte` |
| TaxManager | Desktop | 4 | 3 | `frontend\src\lib\components\desktop-interface\admin-customer-app\products\TaxManager.svelte` |
| TierManager | Desktop | 2 | 2 | `frontend\src\lib\components\desktop-interface\admin-customer-app\offers\TierManager.svelte` |
| VideoTemplatesManager | Desktop | 4 | 1 | `frontend\src\lib\components\desktop-interface\admin-customer-app\VideoTemplatesManager.svelte` |
| CouponRedemption | Cashier | 4 | 1 | `frontend\src\lib\components\cashier-interface\CouponRedemption.svelte` |
| +page | Other | 8 | 6 | `frontend\src\routes\customer-interface\cart\+page.svelte` |
| +page | Other | 18 | 5 | `frontend\src\routes\customer-interface\checkout\+page.svelte` |
| +page | Other | 12 | 5 | `frontend\src\routes\customer-interface\products\+page.svelte` |
| +page | Other | 12 | 3 | `frontend\src\routes\customer-interface\profile\+page.svelte` |
| +page | Other | 11 | 1 | `frontend\src\routes\customer-interface\support\+page.svelte` |
| FeaturedOffers | Other | 4 | 1 | `frontend\src\lib\components\customer-interface\shopping\FeaturedOffers.svelte` |
| AddOfferDialog | Desktop | 1 | 1 | `frontend\src\lib\components\desktop-interface\marketing\coupon\AddOfferDialog.svelte` |
| ApprovalCenter | Desktop | 18 | 8 | `frontend\src\lib\components\desktop-interface\master\finance\ApprovalCenter.svelte` |
| ApproverListModal | Desktop | 4 | 2 | `frontend\src\lib\components\desktop-interface\master\finance\ApproverListModal.svelte` |
| AssignPositions | Desktop | 1 | 1 | `frontend\src\lib\components\desktop-interface\master\hr\AssignPositions.svelte` |
| BiometricData | Desktop | 7 | 5 | `frontend\src\lib\components\desktop-interface\master\hr\BiometricData.svelte` |
| BranchMaster | Desktop | 11 | 9 | `frontend\src\lib\components\desktop-interface\master\BranchMaster.svelte` |
| ButtonAccessControl | Desktop | 6 | 1 | `frontend\src\lib\components\desktop-interface\settings\ButtonAccessControl.svelte` |
| ButtonGenerator | Desktop | 6 | 2 | `frontend\src\lib\components\desktop-interface\settings\ButtonGenerator.svelte` |
| CampaignManager | Desktop | 7 | 3 | `frontend\src\lib\components\desktop-interface\marketing\coupon\CampaignManager.svelte` |
| CategoryManager | Desktop | 14 | 8 | `frontend\src\lib\components\desktop-interface\master\finance\CategoryManager.svelte` |
| ClearanceCertificateManager | Desktop | 6 | 2 | `frontend\src\lib\components\desktop-interface\master\operations\receiving\ClearanceCertificateManager.svelte` |
| ClearTables | Desktop | 2 | 1 | `frontend\src\lib\components\desktop-interface\settings\ClearTables.svelte` |
| ContactManagement | Desktop | 5 | 1 | `frontend\src\lib\components\desktop-interface\master\hr\ContactManagement.svelte` |
| ContactManagement-old | Desktop | 4 | 2 | `frontend\src\lib\components\desktop-interface\master\hr\ContactManagement-old.svelte` |
| CouponDashboard | Desktop | 1 | 1 | `frontend\src\lib\components\desktop-interface\marketing\coupon\CouponDashboard.svelte` |
| CreateDepartment | Desktop | 5 | 5 | `frontend\src\lib\components\desktop-interface\master\hr\CreateDepartment.svelte` |
| CreateLevel | Desktop | 7 | 4 | `frontend\src\lib\components\desktop-interface\master\hr\CreateLevel.svelte` |
| CreatePosition | Desktop | 5 | 5 | `frontend\src\lib\components\desktop-interface\master\hr\CreatePosition.svelte` |
| CreateUser | Desktop | 7 | 3 | `frontend\src\lib\components\desktop-interface\settings\user\CreateUser.svelte` |
| CustomerImporter | Desktop | 8 | 4 | `frontend\src\lib\components\desktop-interface\marketing\coupon\CustomerImporter.svelte` |
| DayBudgetPlanner | Desktop | 26 | 7 | `frontend\src\lib\components\desktop-interface\master\finance\DayBudgetPlanner.svelte` |
| DesignPlanner | Desktop | 8 | 1 | `frontend\src\lib\components\desktop-interface\marketing\flyer\DesignPlanner.svelte` |
| EditUser | Desktop | 12 | 2 | `frontend\src\lib\components\desktop-interface\settings\user\EditUser.svelte` |
| EditVendor | Desktop | 11 | 9 | `frontend\src\lib\components\desktop-interface\master\vendor\EditVendor.svelte` |
| EmployeeDocumentManager | Desktop | 3 | 3 | `frontend\src\lib\components\desktop-interface\master\hr\EmployeeDocumentManager.svelte` |
| ERPConnections | Desktop | 7 | 3 | `frontend\src\lib\components\desktop-interface\settings\ERPConnections.svelte` |
| ExpenseTracker | Desktop | 12 | 5 | `frontend\src\lib\components\desktop-interface\master\finance\reports\ExpenseTracker.svelte` |
| FlyerTemplateDesigner | Desktop | 12 | 6 | `frontend\src\lib\components\desktop-interface\marketing\flyer\FlyerTemplateDesigner.svelte` |
| InterfaceAccessManager | Desktop | 16 | 4 | `frontend\src\lib\components\desktop-interface\settings\InterfaceAccessManager.svelte` |
| ManageAdminUsers | Desktop | 16 | 6 | `frontend\src\lib\components\desktop-interface\settings\user\ManageAdminUsers.svelte` |
| ManageMasterAdmin | Desktop | 24 | 6 | `frontend\src\lib\components\desktop-interface\settings\user\ManageMasterAdmin.svelte` |
| ManageVendor | Desktop | 14 | 4 | `frontend\src\lib\components\desktop-interface\master\vendor\ManageVendor.svelte` |
| ManualScheduling | Desktop | 6 | 1 | `frontend\src\lib\components\desktop-interface\master\finance\ManualScheduling.svelte` |
| MonthDetails | Desktop | 21 | 11 | `frontend\src\lib\components\desktop-interface\master\finance\MonthDetails.svelte` |
| MonthlyManager | Desktop | 17 | 6 | `frontend\src\lib\components\desktop-interface\master\finance\MonthlyManager.svelte` |
| MultipleBillScheduling | Desktop | 7 | 3 | `frontend\src\lib\components\desktop-interface\master\finance\MultipleBillScheduling.svelte` |
| MyAssignmentsView | Desktop | 2 | 1 | `frontend\src\lib\components\desktop-interface\master\tasks\MyAssignmentsView.svelte` |
| NotificationCenter | Desktop | 10 | 2 | `frontend\src\lib\components\desktop-interface\master\communication\NotificationCenter.svelte` |
| OfferManager | Desktop | 3 | 1 | `frontend\src\lib\components\desktop-interface\marketing\flyer\OfferManager.svelte` |
| OfferProductSelector | Desktop | 8 | 3 | `frontend\src\lib\components\desktop-interface\marketing\flyer\OfferProductSelector.svelte` |
| OfferTemplates | Desktop | 4 | 1 | `frontend\src\lib\components\desktop-interface\marketing\flyer\OfferTemplates.svelte` |
| OtherDocumentsManager | Desktop | 3 | 2 | `frontend\src\lib\components\desktop-interface\master\hr\OtherDocumentsManager.svelte` |
| PaidManager | Desktop | 8 | 5 | `frontend\src\lib\components\desktop-interface\master\finance\PaidManager.svelte` |
| PriceValidationWarning | Desktop | 2 | 1 | `frontend\src\lib\components\desktop-interface\marketing\flyer\PriceValidationWarning.svelte` |
| PricingManager | Desktop | 13 | 1 | `frontend\src\lib\components\desktop-interface\marketing\flyer\PricingManager.svelte` |
| ProductFieldConfigurator | Desktop | 4 | 2 | `frontend\src\lib\components\desktop-interface\marketing\flyer\ProductFieldConfigurator.svelte` |
| ProductFieldConfiguratorFlyer | Desktop | 8 | 4 | `frontend\src\lib\components\desktop-interface\marketing\flyer\ProductFieldConfiguratorFlyer.svelte` |
| ProductManager | Desktop | 3 | 1 | `frontend\src\lib\components\desktop-interface\marketing\coupon\ProductManager.svelte` |
| ProductMaster | Desktop | 33 | 14 | `frontend\src\lib\components\desktop-interface\marketing\flyer\ProductMaster.svelte` |
| QuickTaskCompletionDialog | Desktop | 4 | 1 | `frontend\src\lib\components\desktop-interface\master\tasks\QuickTaskCompletionDialog.svelte` |
| ReceivingRecords | Desktop | 11 | 3 | `frontend\src\lib\components\desktop-interface\master\operations\receiving\ReceivingRecords.svelte` |
| ReceivingTaskCompletionDialog | Desktop | 8 | 2 | `frontend\src\lib\components\desktop-interface\master\operations\receiving\ReceivingTaskCompletionDialog.svelte` |
| ReceivingTasksDashboard | Desktop | 10 | 2 | `frontend\src\lib\components\desktop-interface\master\operations\receiving\ReceivingTasksDashboard.svelte` |
| RecurringExpenseScheduler | Desktop | 9 | 3 | `frontend\src\lib\components\desktop-interface\master\finance\RecurringExpenseScheduler.svelte` |
| ReportingMap | Desktop | 5 | 5 | `frontend\src\lib\components\desktop-interface\master\hr\ReportingMap.svelte` |
| RequestClosureManager | Desktop | 8 | 2 | `frontend\src\lib\components\desktop-interface\master\finance\RequestClosureManager.svelte` |
| RequestGenerator | Desktop | 13 | 4 | `frontend\src\lib\components\desktop-interface\master\finance\RequestGenerator.svelte` |
| RequestsManager | Desktop | 12 | 2 | `frontend\src\lib\components\desktop-interface\master\finance\RequestsManager.svelte` |
| SalaryManagement | Desktop | 2 | 2 | `frontend\src\lib\components\desktop-interface\master\hr\SalaryManagement.svelte` |
| Settings | Desktop | 2 | 1 | `frontend\src\lib\components\desktop-interface\settings\Settings.svelte` |
| ShelfPaperTemplateDesigner | Desktop | 5 | 3 | `frontend\src\lib\components\desktop-interface\marketing\flyer\ShelfPaperTemplateDesigner.svelte` |
| SingleBillScheduling | Desktop | 5 | 1 | `frontend\src\lib\components\desktop-interface\master\finance\SingleBillScheduling.svelte` |
| StartReceiving | Desktop | 54 | 17 | `frontend\src\lib\components\desktop-interface\master\operations\receiving\StartReceiving.svelte` |
| TaskAssignmentView | Desktop | 24 | 7 | `frontend\src\lib\components\desktop-interface\master\tasks\TaskAssignmentView.svelte` |
| TaskAssignmentViewNew | Desktop | 16 | 5 | `frontend\src\lib\components\desktop-interface\master\tasks\TaskAssignmentViewNew.svelte` |
| TaskCompletionModal | Desktop | 11 | 1 | `frontend\src\lib\components\desktop-interface\master\tasks\TaskCompletionModal.svelte` |
| TaskCreateForm | Desktop | 2 | 1 | `frontend\src\lib\components\desktop-interface\master\tasks\TaskCreateForm.svelte` |
| TaskStatusView | Desktop | 5 | 1 | `frontend\src\lib\components\desktop-interface\master\tasks\TaskStatusView.svelte` |
| TaskViewTable | Desktop | 16 | 5 | `frontend\src\lib\components\desktop-interface\master\tasks\TaskViewTable.svelte` |
| UploadEmployees | Desktop | 3 | 1 | `frontend\src\lib\components\desktop-interface\master\hr\UploadEmployees.svelte` |
| UploadFingerprint | Desktop | 6 | 2 | `frontend\src\lib\components\desktop-interface\master\hr\UploadFingerprint.svelte` |
| UploadVendor | Desktop | 4 | 1 | `frontend\src\lib\components\desktop-interface\master\vendor\UploadVendor.svelte` |
| UserManagement | Desktop | 5 | 3 | `frontend\src\lib\components\desktop-interface\settings\UserManagement.svelte` |
| VariationManager | Desktop | 16 | 6 | `frontend\src\lib\components\desktop-interface\marketing\flyer\VariationManager.svelte` |
| VariationSelectionModal | Desktop | 5 | 1 | `frontend\src\lib\components\desktop-interface\marketing\flyer\VariationSelectionModal.svelte` |
| VendorPendingPayments | Desktop | 4 | 1 | `frontend\src\lib\components\desktop-interface\master\finance\reports\VendorPendingPayments.svelte` |
| VendorRecords | Desktop | 5 | 1 | `frontend\src\lib\components\desktop-interface\master\finance\reports\VendorRecords.svelte` |
| ViewOfferManager | Desktop | 2 | 2 | `frontend\src\lib\components\desktop-interface\marketing\coupon\ViewOfferManager.svelte` |
| WarningDetailsModal | Desktop | 3 | 1 | `frontend\src\lib\components\desktop-interface\master\warnings\WarningDetailsModal.svelte` |
| WarningTemplate | Desktop | 6 | 1 | `frontend\src\lib\components\desktop-interface\master\tasks\WarningTemplate.svelte` |
| WarningTemplateImageModal | Desktop | 2 | 1 | `frontend\src\lib\components\desktop-interface\master\warnings\WarningTemplateImageModal.svelte` |
| +page | Other | 13 | 8 | `frontend\src\routes\mobile-interface\approval-center\+page.svelte` |
| +page | Other | 5 | 1 | `frontend\src\routes\mobile-interface\assignments\+page.svelte` |
| +page | Other | 4 | 4 | `frontend\src\routes\mobile-interface\notifications\create\+page.svelte` |
| +page | Other | 10 | 1 | `frontend\src\routes\mobile-interface\quick-task\+page.svelte` |
| +page | Other | 6 | 1 | `frontend\src\routes\mobile-interface\quick-tasks\[id]\complete\+page.svelte` |
| +page | Other | 8 | 2 | `frontend\src\routes\mobile-interface\receiving-tasks\[id]\complete\+page.svelte` |
| +page | Other | 11 | 1 | `frontend\src\routes\mobile-interface\tasks\assign\+page.svelte` |
| +page | Other | 3 | 3 | `frontend\src\routes\mobile-interface\tasks\create\+page.svelte` |
| +page | Other | 4 | 2 | `frontend\src\routes\mobile-interface\tasks\[id]\+page.svelte` |
| +page | Other | 7 | 1 | `frontend\src\routes\mobile-interface\tasks\[id]\complete\+page.svelte` |
| NotificationCenter | Other | 9 | 2 | `frontend\src\lib\components\mobile-interface\notifications\NotificationCenter.svelte` |
| QuickTaskModal | Other | 10 | 1 | `frontend\src\lib\components\mobile-interface\tasks\QuickTaskModal.svelte` |
| TaskCompletionModal | Other | 4 | 1 | `frontend\src\lib\components\mobile-interface\tasks\TaskCompletionModal.svelte` |

---

## ✅ Next Steps

1. **Priority 1:** Fix components with CREATE/EDIT/DELETE buttons (see High Priority section)
2. **Priority 2:** Fix components with UPLOAD/EXPORT/ASSIGN buttons (see Medium Priority section)
3. **Priority 3:** Review remaining buttons for permission requirements
4. Add permission checks using:
   - `hasPermission('FUNCTION_CODE', 'can_add')` for CREATE buttons
   - `hasPermission('FUNCTION_CODE', 'can_edit')` for EDIT buttons
   - `hasPermission('FUNCTION_CODE', 'can_delete')` for DELETE buttons
   - Wrap buttons in `{#if}` blocks to hide when no permission

