<script lang="ts">
  export let steps: string[] = [];
  export let currentStep: number = 0;
</script>

<nav class="step-indicator">
  {#each steps as step, i}
    <div class="step {i === currentStep ? 'active' : ''} {i < currentStep ? 'completed' : ''}">
      <span class="step-number">{i + 1}</span>
      <span class="step-label">{step}</span>
      {#if i < steps.length - 1}
        <span class="step-separator">→</span>
      {/if}
    </div>
  {/each}
</nav>

<style>
.step-indicator {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1.5rem;
  margin-bottom: 2rem;
}
.step {
  display: flex;
  align-items: center;
  font-weight: 500;
  color: #888;
  position: relative;
}
.step.active {
  color: #1976d2;
}
.step.completed {
  color: #43a047;
}
.step-number {
  display: inline-block;
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  background: #e3e3e3;
  color: #333;
  text-align: center;
  line-height: 2rem;
  margin-right: 0.5rem;
  font-weight: bold;
}
.step.active .step-number {
  background: #1976d2;
  color: #fff;
  animation: heartbeat 1.2s ease-in-out infinite;
}
@keyframes heartbeat {
  0% { transform: scale(1); }
  14% { transform: scale(1.2); }
  28% { transform: scale(1); }
  42% { transform: scale(1.15); }
  56% { transform: scale(1); }
  100% { transform: scale(1); }
}
.step.completed .step-number {
  background: #43a047;
  color: #fff;
}
.step-separator {
  margin: 0 0.75rem;
  color: #bbb;
  font-size: 1.2rem;
}
</style>
