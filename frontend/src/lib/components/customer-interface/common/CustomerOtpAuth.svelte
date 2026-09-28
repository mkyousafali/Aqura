<script lang="ts">
  import { createEventDispatcher, onDestroy } from 'svelte';
  import { supabase, getEdgeFunctionUrl } from '$lib/utils/supabase';
  import { currentLocale } from '$lib/i18n';

  export let initialView: 'login' | 'register' | 'forgot' | 'loyalty' = 'login';
  export let currentView: 'login' | 'register' | 'forgot' | 'loyalty' = initialView;
  export let showMask = false;
  export let autoLoginCode: string | null = null;
  export let hideNavButtons = false;

  const dispatch = createEventDispatcher();
  let step: 'details' | 'otp' = 'details';
  let registrationStep: 'name' | 'phone' = 'name';
  let purpose: 'registration' | 'login' = 'login';
  let name = '';
  let phone = '';
  let privacyAccepted = false;
  let otp = '';
  let loading = false;
  let error = '';
  let success = '';
  let expiresAt = 0;
  let lockedUntil = 0;
  let now = Date.now();
  let timer: ReturnType<typeof setInterval> | null = null;

  $: if (currentView === 'forgot') currentView = 'login';
  $: if (currentView === 'loyalty') currentView = 'login';
  $: expiresLeft = Math.max(0, Math.ceil((expiresAt - now) / 1000));
  $: lockoutLeft = Math.max(0, Math.ceil((lockedUntil - now) / 1000));
  $: normalizedPhone = normalizePhone(phone);

  onDestroy(() => timer && clearInterval(timer));

  function startTimer() {
    if (timer) clearInterval(timer);
    now = Date.now();
    timer = setInterval(() => {
      now = Date.now();
      if (expiresLeft === 0 && lockoutLeft === 0 && timer) {
        clearInterval(timer);
        timer = null;
      }
    }, 1000);
  }

  function normalizePhone(value: string) {
    let digits = value.replace(/\D/g, '');
    if (!digits.startsWith('966')) digits = '966' + digits.replace(/^0/, '');
    return '+' + digits;
  }

  function validPhone() {
    return /^\+9665\d{8}$/.test(normalizedPhone);
  }

  function formatPhoneInput(event: Event) {
    const input = event.target as HTMLInputElement;
    let digits = input.value.replace(/\D/g, '');
    if (digits.startsWith('966')) digits = digits.slice(3);
    if (digits.startsWith('0')) digits = digits.slice(1);
    digits = digits.slice(0, 9);
    phone = digits.length > 6
      ? `${digits.slice(0, 3)} ${digits.slice(3, 6)} ${digits.slice(6)}`
      : digits.length > 3 ? `${digits.slice(0, 3)} ${digits.slice(3)}` : digits;
  }

  function formatDuration(total: number) {
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    const mmss = `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    return h ? `${h.toString().padStart(2, '0')}:${mmss}` : mmss;
  }

  function applyLockout(value?: string) {
    lockedUntil = value ? new Date(value).getTime() : 0;
    startTimer();
  }

  async function requestOtp(requestPurpose: 'registration' | 'login') {
    if (!validPhone()) {
      error = $currentLocale === 'ar' ? 'أدخل رقم واتساب سعودي صحيح.' : 'Enter a valid Saudi WhatsApp number.';
      return;
    }
    if (requestPurpose === 'registration' && (name.trim().length < 2 || !privacyAccepted)) {
      error = $currentLocale === 'ar' ? 'أدخل الاسم ووافق على سياسة الخصوصية.' : 'Enter your name and accept the privacy policy.';
      return;
    }
    loading = true;
    error = '';
    success = '';
    try {
      const response = await fetch(getEdgeFunctionUrl('send-whatsapp'), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`
        },
        body: JSON.stringify({
          action: 'send_customer_auth_otp',
          phone_number: normalizedPhone,
          customer_name: requestPurpose === 'registration' ? name.trim() : undefined,
          purpose: requestPurpose,
          language: $currentLocale === 'ar' ? 'ar' : 'en'
        })
      });
      const result = await response.json();
      if (!response.ok || !result.success) {
        if (result.error === 'locked') applyLockout(result.locked_until);
        throw new Error(result.message || result.error || 'Unable to send OTP.');
      }
      purpose = requestPurpose;
      otp = '';
      step = 'otp';
      expiresAt = Date.now() + Number(result.expires_in_seconds || 60) * 1000;
      startTimer();
      success = $currentLocale === 'ar' ? 'تم إرسال رمز جديد عبر واتساب.' : 'A new OTP was sent through WhatsApp.';
    } catch (e: any) {
      error = e?.message || 'Unable to send OTP.';
    } finally {
      loading = false;
    }
  }

  async function verifyOtp() {
    if (!/^\d{6}$/.test(otp) || expiresLeft === 0 || lockoutLeft > 0) return;
    loading = true;
    error = '';
    try {
      const { data, error: rpcError } = await supabase.rpc('verify_customer_auth_otp', {
        p_whatsapp_number: normalizedPhone,
        p_otp: otp,
        p_purpose: purpose
      });
      if (rpcError) throw rpcError;
      if (!data?.success) {
        if (data?.error === 'locked') applyLockout(data.locked_until);
        const attempts = data?.attempts_remaining != null ? ` (${data.attempts_remaining} attempts remaining)` : '';
        throw new Error((data?.message || data?.error || 'OTP verification failed.') + attempts);
      }
      localStorage.setItem('customer_session', JSON.stringify({
        customer_id: data.customer_id,
        customer_name: data.customer_name,
        whatsapp_number: data.whatsapp_number,
        registration_status: data.registration_status,
        login_time: new Date().toISOString(),
        remember_device: false
      }));
      localStorage.removeItem('customer_access_code');
      success = $currentLocale === 'ar' ? 'تم التحقق بنجاح.' : 'Verified successfully.';
      dispatch('success', { type: purpose === 'registration' ? 'customer_register' : 'customer_login', customer_data: data });
    } catch (e: any) {
      error = e?.message || 'OTP verification failed.';
      otp = '';
    } finally {
      loading = false;
    }
  }

  function switchView(view: 'login' | 'register') {
    currentView = view;
    step = 'details';
    registrationStep = 'name';
    otp = '';
    error = '';
    success = '';
    expiresAt = 0;
  }

  function continueRegistration() {
    error = '';
    if (name.trim().length < 2) {
      error = $currentLocale === 'ar' ? 'أدخل اسماً صحيحاً.' : 'Enter a valid name.';
      return;
    }
    registrationStep = 'phone';
  }
</script>

<div class="otp-auth" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
  {#if lockoutLeft > 0}
    <div class="lockout" role="alert">
      <strong>{$currentLocale === 'ar' ? 'تم حظر المحاولات مؤقتاً' : 'Attempts temporarily blocked'}</strong>
      <p>{$currentLocale === 'ar' ? 'يرجى التواصل مع خدمة العملاء أو المحاولة بعد انتهاء الوقت.' : 'Contact Customer Service or try again when the lockout ends.'}</p>
      <span>{formatDuration(lockoutLeft)}</span>
    </div>
  {:else if step === 'otp'}
    <form on:submit|preventDefault={verifyOtp}>
      <h2>{$currentLocale === 'ar' ? 'أدخل رمز التحقق' : 'Enter verification code'}</h2>
      <p>{$currentLocale === 'ar' ? `أرسلنا رمزاً جديداً إلى ${normalizedPhone}` : `We sent a new OTP to ${normalizedPhone}`}</p>
      <input class="otp-input" bind:value={otp} on:input={() => otp = otp.replace(/\D/g, '').slice(0, 6)} inputmode="numeric" autocomplete="one-time-code" maxlength="6" autofocus />
      <div class:expired={expiresLeft === 0} class="timer">{expiresLeft > 0 ? formatDuration(expiresLeft) : ($currentLocale === 'ar' ? 'انتهت صلاحية الرمز' : 'OTP expired')}</div>
      <button class="primary" type="submit" disabled={loading || otp.length !== 6 || expiresLeft === 0}>{loading ? '...' : ($currentLocale === 'ar' ? 'تحقق' : 'Verify OTP')}</button>
      <button class="link" type="button" disabled={loading} on:click={() => requestOtp(purpose)}>{$currentLocale === 'ar' ? 'إرسال رمز جديد' : 'Send a new OTP'}</button>
      <button class="link" type="button" on:click={() => step = 'details'}>{$currentLocale === 'ar' ? 'تغيير الرقم' : 'Change number'}</button>
    </form>
  {:else if currentView === 'register'}
    {#if registrationStep === 'name'}
      <form on:submit|preventDefault={continueRegistration}>
        <h2>{$currentLocale === 'ar' ? 'إنشاء حساب' : 'Create account'}</h2>
        <p>{$currentLocale === 'ar' ? 'أدخل اسمك للمتابعة.' : 'Enter your name to continue.'}</p>
        <label>{$currentLocale === 'ar' ? 'الاسم' : 'Name'}<input bind:value={name} autocomplete="name" autofocus /></label>
        <button class="primary" type="submit" disabled={name.trim().length < 2}>{$currentLocale === 'ar' ? 'التالي' : 'Next'}</button>
        <button class="link" type="button" on:click={() => switchView('login')}>{$currentLocale === 'ar' ? 'لدي حساب بالفعل' : 'I already have an account'}</button>
      </form>
    {:else}
      <form on:submit|preventDefault={() => requestOtp('registration')}>
        <h2>{$currentLocale === 'ar' ? 'رقم واتساب' : 'WhatsApp number'}</h2>
        <p>{$currentLocale === 'ar' ? `مرحباً ${name.trim()}، أدخل رقم واتساب لإرسال رمز التحقق.` : `Hello ${name.trim()}, enter your WhatsApp number to receive an OTP.`}</p>
        <label>{$currentLocale === 'ar' ? 'رقم واتساب' : 'WhatsApp number'}<div class="phone"><span>+966</span><input value={phone} on:input={formatPhoneInput} inputmode="tel" autocomplete="tel" autofocus /></div></label>
        <label class="privacy"><input type="checkbox" bind:checked={privacyAccepted} /> <span>{$currentLocale === 'ar' ? 'أوافق على' : 'I agree to the'} <a href="/privacy" target="_blank">{$currentLocale === 'ar' ? 'سياسة الخصوصية' : 'Privacy Policy'}</a></span></label>
        <button class="primary" type="submit" disabled={loading || !privacyAccepted || !validPhone()}>{loading ? '...' : ($currentLocale === 'ar' ? 'إرسال رمز التحقق' : 'Send OTP')}</button>
        <button class="link" type="button" on:click={() => registrationStep = 'name'}>{$currentLocale === 'ar' ? 'رجوع' : 'Back'}</button>
      </form>
    {/if}
  {:else}
    <form on:submit|preventDefault={() => requestOtp('login')}>
      <h2>{$currentLocale === 'ar' ? 'دخول العميل' : 'Customer login'}</h2>
      <p>{$currentLocale === 'ar' ? 'أدخل رقم واتساب لاستلام رمز جديد.' : 'Enter your WhatsApp number to receive a new OTP.'}</p>
      <label>{$currentLocale === 'ar' ? 'رقم واتساب' : 'WhatsApp number'}<div class="phone"><span>+966</span><input value={phone} on:input={formatPhoneInput} inputmode="tel" autocomplete="tel" /></div></label>
      <button class="primary" type="submit" disabled={loading}>{loading ? '...' : ($currentLocale === 'ar' ? 'إرسال رمز التحقق' : 'Send OTP')}</button>
      <button class="link" type="button" on:click={() => switchView('register')}>{$currentLocale === 'ar' ? 'إنشاء حساب جديد' : 'Create a new account'}</button>
    </form>
  {/if}

  {#if success}<div class="message success" role="status">{success}</div>{/if}
  {#if error}<div class="message error" role="alert">{error}</div>{/if}
</div>

<style>
  .otp-auth { width: 100%; max-width: 430px; margin: 0 auto; color: #172033; }
  form { display: flex; flex-direction: column; gap: 1rem; }
  h2 { margin: 0; font-size: 1.45rem; text-align: center; }
  p { margin: 0; color: #64748b; text-align: center; line-height: 1.5; }
  label { display: flex; flex-direction: column; gap: .45rem; font-weight: 650; }
  input { width: 100%; box-sizing: border-box; border: 1px solid #cbd5e1; border-radius: 12px; padding: .85rem 1rem; font: inherit; background: white; }
  input:focus { outline: 3px solid rgba(21,163,74,.16); border-color: #15a34a; }
  .phone { display: flex; align-items: center; direction: ltr; border: 1px solid #cbd5e1; border-radius: 12px; overflow: hidden; background: white; }
  .phone span { padding: 0 .85rem; color: #475569; border-inline-end: 1px solid #e2e8f0; }
  .phone input { border: 0; border-radius: 0; direction: ltr; text-align: left; }
  .otp-input { direction: ltr; text-align: center; font-size: 2rem; letter-spacing: .65rem; font-weight: 750; }
  .timer { text-align: center; color: #15803d; font-weight: 700; }
  .timer.expired { color: #dc2626; }
  .primary { border: 0; border-radius: 12px; padding: .9rem 1rem; background: #15a34a; color: white; font: inherit; font-weight: 750; cursor: pointer; }
  button:disabled { opacity: .55; cursor: not-allowed; }
  .link { border: 0; background: transparent; color: #15803d; font: inherit; font-weight: 650; cursor: pointer; }
  .privacy { flex-direction: row; align-items: flex-start; font-weight: 400; }
  .privacy input { width: auto; margin-top: .2rem; }
  .privacy a { color: #15803d; }
  .message, .lockout { margin-top: 1rem; border-radius: 12px; padding: .9rem 1rem; text-align: center; }
  .success { background: #ecfdf5; color: #166534; }
  .error { background: #fef2f2; color: #b91c1c; }
  .lockout { background: #fff7ed; color: #9a3412; }
  .lockout p { color: inherit; margin: .5rem 0; }
  .lockout span { display: block; font-size: 1.5rem; font-weight: 800; font-variant-numeric: tabular-nums; }
</style>
