<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  deleteHistoryBill,
  getHistoryList,
} from '../api/historyApi.js'
import { formatMoney } from '../utils/money.js'

const router = useRouter()

const historyList = ref([])
const listLoading = ref(false)
const loadError = ref('')
const deletingId = ref(null)

const sortedHistoryList = computed(() =>
  [...historyList.value].sort((first, second) => {
    const yearDifference = Number(second.bill_year) - Number(first.bill_year)
    if (yearDifference !== 0) {
      return yearDifference
    }

    const monthDifference = Number(second.bill_month) - Number(first.bill_month)
    if (monthDifference !== 0) {
      return monthDifference
    }

    return Number(second.id) - Number(first.id)
  }),
)

const getErrorMessage = (error) => error?.message || '操作失败，请稍后重试'

const formatBillPeriod = (bill) => {
  const year = String(bill.bill_year || '').padStart(4, '0')
  const month = String(bill.bill_month || '').padStart(2, '0')
  return `${year}-${month}`
}

const formatBillMonth = (bill) => String(bill.bill_month || '').padStart(2, '0')

const loadHistory = async () => {
  listLoading.value = true
  loadError.value = ''

  try {
    const data = await getHistoryList()
    if (!Array.isArray(data)) {
      throw new Error('历史账单数据格式不正确')
    }

    historyList.value = data
  } catch (error) {
    loadError.value = getErrorMessage(error)
  } finally {
    listLoading.value = false
  }
}

const viewDetail = (bill) => {
  if (deletingId.value !== null) {
    return
  }

  router.push({ name: 'historyDetail', params: { id: bill.id } })
}

const handleDelete = async (bill) => {
  if (deletingId.value !== null) {
    return
  }

  try {
    await ElMessageBox.confirm(
      `确定要删除 ${formatBillPeriod(bill)} 的历史账单吗？删除后无法恢复。`,
      '删除确认',
      {
        confirmButtonText: '确认删除',
        cancelButtonText: '取消',
        type: 'warning',
      },
    )

    deletingId.value = bill.id
    await deleteHistoryBill(bill.id)
    ElMessage.success('历史账单删除成功')
    await loadHistory()
  } catch (error) {
    if (error === 'cancel' || error === 'close') {
      return
    }

    ElMessage.error(getErrorMessage(error))
  } finally {
    deletingId.value = null
  }
}

onMounted(loadHistory)
</script>

<template>
  <main class="page-shell">
    <header class="page-heading history-page-heading">
      <div>
        <p class="page-eyebrow">Bill History</p>
        <h1>历史账单</h1>
        <p class="page-description">按月份查看和管理已经保存的宿舍账单。</p>
      </div>
      <el-tag class="page-tag" effect="dark" round>
        {{ historyList.length }} 份账单
      </el-tag>
    </header>

    <section class="content-card">
      <div class="section-header history-section-header">
        <div>
          <h2>账单记录</h2>
          <p>账单已按年月从新到旧排列</p>
        </div>
        <el-button :loading="listLoading" @click="loadHistory">刷新</el-button>
      </div>

      <el-alert
        v-if="loadError"
        class="load-alert"
        :title="loadError"
        type="error"
        :closable="false"
        show-icon
      >
        <template #default>
          <el-button link type="primary" :loading="listLoading" @click="loadHistory">
            重新加载
          </el-button>
        </template>
      </el-alert>

      <el-table
        class="history-table"
        v-loading="listLoading"
        :data="sortedHistoryList"
        row-key="id"
        empty-text="暂无历史账单"
        border
        stripe
      >
        <el-table-column label="账单月份" min-width="200">
          <template #default="{ row }">
            <div class="period-cell">
              <span class="period-mark">{{ formatBillMonth(row) }}</span>
              <strong>{{ formatBillPeriod(row) }}</strong>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="账单总额" min-width="180" align="right">
          <template #default="{ row }">
            <span class="amount-text">{{ formatMoney(row.total_amount) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="220" align="right">
          <template #default="{ row }">
            <el-button
              link
              type="primary"
              :disabled="deletingId !== null"
              @click="viewDetail(row)"
            >
              查看详情
            </el-button>
            <el-button
              link
              type="danger"
              :loading="deletingId === row.id"
              :disabled="deletingId !== null && deletingId !== row.id"
              @click="handleDelete(row)"
            >
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <p v-if="!listLoading && !loadError && historyList.length" class="table-summary">
        共 {{ historyList.length }} 份历史账单
      </p>
    </section>
  </main>
</template>

<style scoped>
.history-table.el-table {
  --el-table-bg-color: #f9fbfd;
  --el-table-tr-bg-color: #f9fbfd;
  --el-table-border-color: #9cafc4;
  --el-table-header-bg-color: #c8d9ea;
  --el-table-header-text-color: #2d425c;
  --el-table-row-hover-bg-color: #dceafa;
  overflow: hidden;
  border: 2px solid #91a6bd;
  border-radius: 12px;
  color: #34465c;
  box-shadow: 0 5px 16px rgba(45, 66, 92, 0.08);
}

.history-table.el-table :deep(th.el-table__cell) {
  height: 52px;
  border-right-color: #91a6bd;
  border-bottom: 2px solid #91a6bd;
  background: #c8d9ea;
  font-weight: 700;
}

.history-table.el-table :deep(td.el-table__cell) {
  height: 66px;
  border-right-color: #a6b7c9;
  border-bottom-color: #a6b7c9;
  background: #f9fbfd;
}

.history-table.el-table--striped :deep(.el-table__body tr.el-table__row--striped td.el-table__cell) {
  background: #eaf1f8;
}

.history-table.el-table--enable-row-hover :deep(.el-table__body tr:hover > td.el-table__cell) {
  background: #dceafa;
}

.period-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}

.period-mark {
  display: flex;
  width: 36px;
  height: 36px;
  align-items: center;
  justify-content: center;
  border-radius: 10px;
  color: #fff;
  background: linear-gradient(145deg, #4f9cdd, #3473ad);
  box-shadow: 0 5px 12px rgba(52, 120, 181, 0.22);
  font-size: 13px;
  font-weight: 700;
}

.period-cell strong {
  color: #253a53;
  font-size: 16px;
}

.amount-text {
  color: #203a59;
  font-size: 16px;
  font-weight: 700;
}

@media (max-width: 640px) {
  .history-page-heading {
    align-items: flex-start;
  }

  .history-section-header {
    align-items: center;
  }

  .history-table {
    width: 100%;
  }
}
</style>
