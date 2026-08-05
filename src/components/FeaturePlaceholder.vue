<script setup>
defineProps({
  eyebrow: {
    type: String,
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
})
</script>

<template>
  <main class="page-shell">
    <header class="page-heading">
      <div>
        <p class="page-eyebrow">{{ eyebrow }}</p>
        <h1>{{ title }}</h1>
        <p class="page-description">{{ description }}</p>
      </div>
    </header>

    <section class="content-card feature-placeholder">
      <div class="placeholder-mark">⌁</div>
      <h2>{{ title }}</h2>
      <p>页面结构已经建立，功能将在后续开发中补充。</p>
    </section>
  </main>
</template>

<style scoped>
.feature-placeholder {
  display: flex;
  min-height: 390px;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  text-align: center;
}

.placeholder-mark {
  display: flex;
  width: 68px;
  height: 68px;
  align-items: center;
  justify-content: center;
  border: 1px solid #a9bdd2;
  border-radius: 20px;
  color: #3975ad;
  background: #dce9f5;
  font-size: 34px;
}

h2 {
  margin: 20px 0 8px;
  color: #233a55;
}

p {
  margin: 0;
  color: #718196;
}
</style>
