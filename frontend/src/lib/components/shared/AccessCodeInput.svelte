<script lang="ts">
  let { value = $bindable(''), disabled = false, label = 'Access code' }: { value?: string; disabled?: boolean; label?: string } = $props();
  let digits = $state<string[]>(Array(6).fill(''));
  const inputs: HTMLInputElement[] = [];
  $effect(() => {
    if (value !== digits.join('')) digits = Array.from({ length: 6 }, (_, i) => value[i] || '');
  });
  function numeric(text: string) {
    return text.replace(/[\u0660-\u0669]/g, d => String(d.charCodeAt(0) - 0x0660))
      .replace(/[\u06f0-\u06f9]/g, d => String(d.charCodeAt(0) - 0x06f0)).replace(/\D/g, '');
  }
  function focus(index: number) { inputs[index]?.focus(); inputs[index]?.select(); }
  function fill(text: string, index: number) {
    const next = [...digits], chars = numeric(text).slice(0, 6);
    if (!chars) return;
    const start = chars.length === 6 ? 0 : index;
    for (let i = 0; i < chars.length && start + i < 6; i++) next[start + i] = chars[i];
    digits = next; value = next.join(''); focus(Math.min(start + chars.length, 5));
  }
  function input(event: Event, index: number) {
    const target = event.currentTarget as HTMLInputElement;
    const chars = numeric(target.value);
    if (chars.length > 1) { fill(chars, index); return; }
    digits[index] = chars; value = digits.join(''); target.value = chars;
    if (chars && index < 5) focus(index + 1);
  }
  function keydown(event: KeyboardEvent, index: number) {
    if (event.key === 'Backspace') {
      event.preventDefault();
      const target = digits[index] ? index : Math.max(0, index - 1);
      digits[target] = ''; value = digits.join(''); focus(Math.max(0, index - 1));
    } else if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault(); focus(Math.max(0, Math.min(5, index + (event.key === 'ArrowLeft' ? -1 : 1))));
    }
  }
</script>

<div class="otp-input" dir="ltr" role="group" aria-label={label}>
  {#each [0, 1, 2, 3, 4, 5] as index}
    <input class="otp-box" bind:this={inputs[index]} value={digits[index]} type="password" inputmode="numeric"
      maxlength="1" pattern="[0-9]" required {disabled} autocomplete={index === 0 ? 'one-time-code' : 'off'}
      aria-label={`${label} ${index + 1}`} oninput={event => input(event, index)}
      onkeydown={event => keydown(event, index)} onfocus={event => event.currentTarget.select()}
      onpaste={event => { event.preventDefault(); fill(event.clipboardData?.getData('text') || '', index); }} />
  {/each}
</div>

<style>
  .otp-input{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:8px;width:100%;min-width:0}
  .otp-input .otp-box{width:100%;min-width:0;height:64px;margin:0;padding:0;border:1px solid #cfdfec;border-radius:9px;background:#fff;text-align:center;font-size:28px;line-height:1;letter-spacing:0;caret-color:#0789b2}
  .otp-input .otp-box:focus{border-color:#0789b2;outline:2px solid #b6e8f1;outline-offset:1px}
  @media(max-width:900px),(max-height:650px){.otp-input{gap:6px}.otp-input .otp-box{height:52px;font-size:24px;border-radius:7px}}
</style>
