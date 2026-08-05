<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getHistoryDetail, getHistoryList } from '../api/historyApi.js'
import { getPeopleList } from '../api/peopleApi.js'
import { getPeopleAvatars } from '../utils/storage.js'
import { formatMoney, toMoneyNumber } from '../utils/money.js'

const route = useRoute()
const router = useRouter()

const avatarModules = import.meta.glob('../assets/avatars/*.{png,jpg,jpeg,webp,svg}', {
  eager: true,
  import: 'default',
})
const avatarUrlMap = new Map(
  Object.entries(avatarModules).map(([path, url]) => [path.split('/').pop(), url]),
)
const defaultAvatarColors = ['#409eff', '#67c23a', '#e6a23c', '#f56c6c', '#7c6ee6', '#2f9b95']

const billId = computed(() => String(route.params.id || ''))
const validBillId = computed(() => /^\d+$/.test(billId.value) && Number(billId.value) > 0)

const detailList = ref([])
const billSummary = ref(null)
const peopleList = ref([])
const peopleAvatars = ref(getPeopleAvatars())
const detailLoading = ref(false)
const loadError = ref('')
const lookupWarning = ref('')

const peopleMap = computed(
  () => new Map(peopleList.value.map((people) => [String(people.id), people])),
)

const billPeriod = computed(() => {
  if (!billSummary.value) {
    return `账单 #${billId.value}`
  }

  const year = String(billSummary.value.bill_year || '').padStart(4, '0')
  const month = String(billSummary.value.bill_month || '').padStart(2, '0')
  return `${year}-${month}`
})

const calculatedTotal = computed(() =>
  detailList.value.reduce((total, item) => total + toMoneyNumber(item.total_amount), 0),
)

const billTotal = computed(() =>
  billSummary.value ? billSummary.value.total_amount : calculatedTotal.value,
)

const getErrorMessage = (error) => error?.message || '账单详情加载失败，请稍后重试'

const getPeopleName = (peopleId) =>
  peopleMap.value.get(String(peopleId))?.name || `成员 #${peopleId}`

const getNameInitial = (name) => {
  const normalizedName = String(name || '').trim()
  if (!normalizedName) {
    return '?'
  }

  const firstCharacter = Array.from(normalizedName)[0]
  return /^[a-z]$/i.test(firstCharacter) ? firstCharacter.toUpperCase() : firstCharacter
}

const getDefaultAvatarColor = (name) => {
  const normalizedName = String(name || '?')
  const hash = Array.from(normalizedName).reduce(
    (total, character) => total + character.codePointAt(0),
    0,
  )
  return defaultAvatarColors[hash % defaultAvatarColors.length]
}

const getAvatarUrl = (peopleId) => {
  const avatarKey = peopleAvatars.value[String(peopleId)]
  return avatarUrlMap.get(avatarKey) || ''
}

const getSummaries = ({ columns, data }) =>
  columns.map((column, index) => {
    if (index === 0) {
      return '合计'
    }

    const amountProperties = [
      'water_fee',
      'electricity_fee',
      'phone_fee',
      'total_amount',
    ]
    if (!amountProperties.includes(column.property)) {
      return ''
    }

    const total = data.reduce(
      (sum, item) => sum + toMoneyNumber(item[column.property]),
      0,
    )
    return formatMoney(total)
  })

const loadDetail = async () => {
  if (!validBillId.value) {
    loadError.value = '账单地址无效，请返回历史账单列表后重新选择。'
    return
  }

  detailLoading.value = true
  loadError.value = ''
  lookupWarning.value = ''

  const [detailResult, historyResult, peopleResult] = await Promise.allSettled([
    getHistoryDetail(billId.value),
    getHistoryList(),
    getPeopleList(),
  ])

  try {
    if (detailResult.status === 'rejected') {
      throw detailResult.reason
    }
    if (!Array.isArray(detailResult.value)) {
      throw new Error('账单详情数据格式不正确')
    }

    detailList.value = detailResult.value

    if (historyResult.status === 'fulfilled' && Array.isArray(historyResult.value)) {
      billSummary.value =
        historyResult.value.find((bill) => String(bill.id) === billId.value) || null
    }

    if (peopleResult.status === 'fulfilled' && Array.isArray(peopleResult.value)) {
      peopleList.value = peopleResult.value
    } else {
      peopleList.value = []
      lookupWarning.value = '人员信息暂时无法加载，当前使用成员编号展示。'
    }
  } catch (error) {
    detailList.value = []
    loadError.value = getErrorMessage(error)
  } finally {
    detailLoading.value = false
  }
}

const goBack = () => router.push({ name: 'history' })

onMounted(loadDetail)
</script>

<template>
  <main class="page-shell">
    <header class="page-heading detail-page-heading">
      <div>
        <p class="page-eyebrow">Bill Detail</p>
        <h1>账单详情</h1>
        <p class="page-description">查看每位成员在本期账单中的费用明细。</p>
      </div>
      <el-button class="back-button" @click="goBack">返回历史账单</el-button>
    </header>

    <section class="content-card detail-card">
      <el-result
        v-if="loadError && !detailLoading"
        icon="warning"
        title="无法显示账单详情"
        :sub-title="loadError"
      >
        <template #extra>
          <el-button v-if="validBillId" type="primary" @click="loadDetail">
            重新加载
          </el-button>
          <el-button @click="goBack">返回列表</el-button>
        </template>
      </el-result>

      <template v-else>
        <div class="detail-overview">
          <div>
            <p class="overview-label">账单月份</p>
            <h2>{{ billPeriod }}</h2>
          </div>
          <div class="overview-stats">
            <div class="stat-item">
              <span>参与人数</span>
              <strong>{{ detailList.length }} 人</strong>
            </div>
            <div class="stat-item stat-item--amount">
              <span>账单总额</span>
              <strong>{{ formatMoney(billTotal) }}</strong>
            </div>
          </div>
        </div>

        <el-alert
          v-if="lookupWarning"
          class="lookup-alert"
          :title="lookupWarning"
          type="info"
          :closable="false"
          show-icon
        />

        <el-table
          class="history-detail-table"
          v-loading="detailLoading"
          :data="detailList"
          row-key="id"
          empty-text="该账单暂无费用明细"
          border
          stripe
          show-summary
          :summary-method="getSummaries"
        >
          <el-table-column label="成员" min-width="190">
            <template #default="{ row }">
              <div class="member-cell">
                <el-avatar
                  class="detail-avatar"
                  :size="40"
                  :src="getAvatarUrl(row.people_id)"
                  :style="getAvatarUrl(row.people_id)
                    ? undefined
                    : { backgroundColor: getDefaultAvatarColor(getPeopleName(row.people_id)) }"
                >
                  {{ getNameInitial(getPeopleName(row.people_id)) }}
                </el-avatar>
                <span>{{ getPeopleName(row.people_id) }}</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column prop="water_fee" label="水费" min-width="130" align="right">
            <template #default="{ row }">{{ formatMoney(row.water_fee) }}</template>
          </el-table-column>
          <el-table-column
            prop="electricity_fee"
            label="电费"
            min-width="130"
            align="right"
          >
            <template #default="{ row }">{{ formatMoney(row.electricity_fee) }}</template>
          </el-table-column>
          <el-table-column prop="phone_fee" label="话费" min-width="130" align="right">
            <template #default="{ row }">{{ formatMoney(row.phone_fee) }}</template>
          </el-table-column>
          <el-table-column
            prop="total_amount"
            label="个人合计"
            min-width="150"
            align="right"
          >
            <template #default="{ row }">
              <strong class="detail-total">{{ formatMoney(row.total_amount) }}</strong>
            </template>
          </el-table-column>
        </el-table>
      </template>
    </section>
  </main>
</template>

<style scoped>
.back-button {
  border-color: #9eb2c7;
  color: #2e5f8d;
  background: rgba(255, 255, 255, 0.55);
}

.detail-card {
  min-height: 390px;
}

.detail-overview {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 30px;
  margin-bottom: 22px;
  padding: 2px 2px 20px;
  border-bottom: 1px solid #cbd6e2;
}

.overview-label {
  margin: 0 0 7px;
  color: #6d7d91;
  font-size: 13px;
}

.detail-overview h2 {
  margin: 0;
  color: #203a59;
  font-size: 26px;
}

.overview-stats {
  display: flex;
  gap: 14px;
}

.stat-item {
  display: flex;
  min-width: 116px;
  flex-direction: column;
  gap: 5px;
  padding: 12px 16px;
  border: 1px solid #bdcbda;
  border-radius: 12px;
  background: #e5edf5;
}

.stat-item span {
  color: #68798d;
  font-size: 12px;
}

.stat-item strong {
  color: #294966;
  font-size: 16px;
}

.stat-item--amount {
  min-width: 145px;
  border-color: #9fc1de;
  background: #dcebf7;
}

.stat-item--amount strong {
  color: #225d91;
}

.lookup-alert {
  margin-bottom: 18px;
}

.history-detail-table.el-table {
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

.history-detail-table.el-table :deep(th.el-table__cell) {
  height: 52px;
  border-right-color: #91a6bd;
  border-bottom: 2px solid #91a6bd;
  background: #c8d9ea;
  font-weight: 700;
}

.history-detail-table.el-table :deep(td.el-table__cell) {
  height: 64px;
  border-right-color: #a6b7c9;
  border-bottom-color: #a6b7c9;
  background: #f9fbfd;
}

.history-detail-table.el-table--striped :deep(.el-table__body tr.el-table__row--striped td.el-table__cell) {
  background: #eaf1f8;
}

.history-detail-table :deep(.el-table__footer-wrapper td.el-table__cell) {
  border-color: #91a6bd;
  color: #203a59;
  background: #d5e3f0;
  font-weight: 700;
}

.member-cell {
  display: flex;
  align-items: center;
  gap: 11px;
  color: #253a53;
  font-weight: 600;
}

.detail-avatar {
  flex: 0 0 auto;
  border: 2px solid #fff;
  box-shadow: 0 2px 8px rgba(31, 45, 61, 0.16);
}

.detail-total {
  display: inline-block;
  min-width: 90px;
  padding: 5px 10px;
  border-radius: 7px;
  color: #fff;
  background: #3478b5;
  font-size: 15px;
  font-weight: 800;
  text-align: right;
}

@media (max-width: 640px) {
  .detail-page-heading,
  .detail-overview {
    align-items: flex-start;
    flex-direction: column;
  }

  .detail-page-heading {
    gap: 14px;
  }

  .detail-overview {
    gap: 16px;
  }

  .overview-stats {
    width: 100%;
  }

  .stat-item {
    min-width: 0;
    flex: 1;
  }
}
</style>
