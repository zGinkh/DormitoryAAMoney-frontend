<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const menuItems = [
  {
    path: '/index',
    label: '账单录入',
    section: 'bill-entry',
    icon: 'bill',
  },
  {
    path: '/poeples',
    label: '人员管理',
    section: 'people',
    icon: 'people',
  },
  {
    path: '/history',
    label: '历史账单',
    section: 'history',
    icon: 'history',
  },
]

const currentSection = computed(() => route.meta.section)
</script>

<template>
  <div class="app-layout">
    <aside class="app-sidebar">
      <div class="brand-block">
        <div class="brand-mark">¥</div>
        <div class="brand-copy">
          <strong>宿舍AA系统</strong>
          <span>Dormitory AA Money</span>
        </div>
      </div>

      <nav class="sidebar-nav" aria-label="功能目录">
        <p class="nav-title">功能目录</p>
        <div class="nav-list">
          <RouterLink
            v-for="item in menuItems"
            :key="item.path"
            :to="item.path"
            class="nav-item"
            :class="{ 'is-active': currentSection === item.section }"
          >
            <svg v-if="item.icon === 'bill'" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M7 3h10a2 2 0 0 1 2 2v16l-3-2-4 2-4-2-3 2V5a2 2 0 0 1 2-2Z" />
              <path d="M9 8h6M9 12h6M9 16h3" />
            </svg>
            <svg v-else-if="item.icon === 'people'" viewBox="0 0 24 24" aria-hidden="true">
              <circle cx="9" cy="8" r="3" />
              <path d="M3.5 19a5.5 5.5 0 0 1 11 0M16 5.5a3 3 0 0 1 0 5.5M17 14a5 5 0 0 1 3.5 5" />
            </svg>
            <svg v-else viewBox="0 0 24 24" aria-hidden="true">
              <path d="M12 8v5l3 2" />
              <circle cx="12" cy="12" r="8" />
              <path d="M5.5 5.5 3 8M18.5 5.5 21 8" />
            </svg>
            <span>{{ item.label }}</span>
          </RouterLink>
        </div>
      </nav>

      <div class="sidebar-footer">
        <span class="status-dot"></span>
        宿舍共同记账
      </div>
    </aside>

    <section class="app-workspace">
      <RouterView v-slot="{ Component, route: currentRoute }">
        <Transition name="page-switch" mode="out-in">
          <component :is="Component" :key="currentRoute.path" />
        </Transition>
      </RouterView>
    </section>
  </div>
</template>

<style scoped>
.app-layout {
  display: grid;
  min-height: 100vh;
  grid-template-columns: 236px minmax(0, 1fr);
}

.app-sidebar {
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  height: 100vh;
  flex-direction: column;
  padding: 28px 18px 20px;
  color: #dce8f5;
  background:
    radial-gradient(circle at 15% 10%, rgba(91, 155, 213, 0.22), transparent 28%),
    linear-gradient(180deg, #1c3554 0%, #172b45 56%, #12243a 100%);
  box-shadow: 8px 0 30px rgba(24, 45, 70, 0.18);
}

.brand-block {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 0 8px 28px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.brand-mark {
  display: flex;
  width: 45px;
  height: 45px;
  flex: 0 0 45px;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(255, 255, 255, 0.28);
  border-radius: 13px;
  color: #fff;
  background: linear-gradient(145deg, #4f9cdd, #3473ad);
  box-shadow: 0 8px 18px rgba(4, 18, 34, 0.25);
  font-family: Arial, "Microsoft YaHei", sans-serif;
  font-size: 24px;
  font-weight: 700;
  line-height: 1;
}

.brand-copy {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.brand-copy strong {
  color: #fff;
  font-size: 17px;
  letter-spacing: 0.04em;
}

.brand-copy span {
  margin-top: 3px;
  color: #8faac5;
  font-size: 10px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.sidebar-nav {
  flex: 1;
  padding-top: 26px;
}

.nav-title {
  margin: 0 12px 10px;
  color: #7894af;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.12em;
}

.nav-list {
  display: flex;
  flex-direction: column;
  gap: 7px;
}

.nav-item {
  position: relative;
  display: flex;
  height: 48px;
  align-items: center;
  gap: 13px;
  padding: 0 14px;
  border: 1px solid transparent;
  border-radius: 11px;
  color: #aebfd1;
  text-decoration: none;
  transition:
    color 0.2s ease,
    background 0.2s ease,
    border-color 0.2s ease,
    transform 0.2s ease,
    box-shadow 0.2s ease;
}

.nav-item svg {
  width: 21px;
  height: 21px;
  fill: none;
  stroke: currentColor;
  stroke-linecap: round;
  stroke-linejoin: round;
  stroke-width: 1.8;
  transition: transform 0.2s ease;
}

.nav-item span {
  font-size: 14px;
  font-weight: 600;
}

.nav-item:hover {
  color: #fff;
  background: rgba(255, 255, 255, 0.07);
  transform: translateX(2px);
}

.nav-item.is-active {
  border-color: rgba(132, 193, 243, 0.28);
  color: #fff;
  background: linear-gradient(90deg, rgba(62, 137, 198, 0.42), rgba(70, 147, 207, 0.18));
  box-shadow: inset 3px 0 #62b0ec;
}

.nav-item.is-active svg {
  transform: scale(1.08);
}

.sidebar-footer {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 18px 8px 0;
  padding-top: 18px;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  color: #7f99b2;
  font-size: 12px;
}

.status-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #58c58b;
  box-shadow: 0 0 0 4px rgba(88, 197, 139, 0.1);
}

.app-workspace {
  min-width: 0;
}

:global(.page-switch-enter-active),
:global(.page-switch-leave-active) {
  transition:
    opacity 0.2s ease,
    transform 0.2s ease;
}

:global(.page-switch-enter-from) {
  opacity: 0;
  transform: translateY(7px);
}

:global(.page-switch-leave-to) {
  opacity: 0;
  transform: translateY(-4px);
}

@media (max-width: 800px) {
  .app-layout {
    grid-template-columns: 1fr;
  }

  .app-sidebar {
    position: sticky;
    height: auto;
    padding: 14px 14px 12px;
  }

  .brand-block {
    padding: 0 2px 12px;
    border-bottom: 0;
  }

  .brand-mark {
    width: 38px;
    height: 38px;
    flex-basis: 38px;
    border-radius: 11px;
    font-size: 21px;
  }

  .brand-copy span,
  .nav-title,
  .sidebar-footer {
    display: none;
  }

  .sidebar-nav {
    overflow-x: auto;
    padding-top: 0;
  }

  .nav-list {
    flex-direction: row;
    gap: 6px;
  }

  .nav-item {
    height: 40px;
    flex: 1 0 auto;
    justify-content: center;
    gap: 7px;
    padding: 0 12px;
    border-radius: 9px;
  }

  .nav-item svg {
    width: 18px;
    height: 18px;
  }

  .nav-item.is-active {
    box-shadow: inset 0 -3px #62b0ec;
  }

  .nav-item:hover {
    transform: translateY(-1px);
  }
}

@media (prefers-reduced-motion: reduce) {
  .nav-item,
  .nav-item svg,
  :global(.page-switch-enter-active),
  :global(.page-switch-leave-active) {
    transition: none;
  }
}
</style>
