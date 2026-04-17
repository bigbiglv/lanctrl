<script setup lang="ts">
import Sidebar from './Sidebar.vue'
import TopBar from './TopBar.vue'
</script>

<template>
  <div class="app-layout">
    <Sidebar />
    <main class="main-content">
      <TopBar />
      <div class="content-area">
        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </div>
    </main>
  </div>
</template>

<style scoped lang="scss">
.app-layout {
  display: flex;
  width: 100%;
  height: 100%;
  padding: 1.5rem;
  gap: 1.5rem;
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.content-area {
  flex: 1;
  border-radius: var(--radius-lg);
  overflow: hidden;
  position: relative;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity var(--transition-fast);
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
