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

const detailPeople = computed(() =>
  detailList.value.map((detail) => ({
    id: detail.people_id,
    name: getPeopleName(detail.people_id),
  })),
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

const calculationMode = computed(() => {
  const summaryMode =
    billSummary.value?.calculation_mode ?? billSummary.value?.calculationMode
  const detailMode =
    detailList.value[0]?.calculation_mode ?? detailList.value[0]?.calculationMode
  const mode = summaryMode ?? detailMode

  return mode === null || mode === undefined || mode === '' ? null : Number(mode)
})

const calculationModeLabel = computed(() => {
  if (calculationMode.value === 0) {
    return '全员在住，按权重分摊'
  }
  if (calculationMode.value === 1) {
    return '部分人员不在，按天数和权重分摊'
  }
  return '暂无记录'
})

const tableRows = computed(() => {
  if (!detailList.value.length) {
    return []
  }

  const items = [
    { property: 'water_fee', itemName: '水费' },
    { property: 'electricity_fee', itemName: '电费' },
    { property: 'phone_fee', itemName: '话费' },
  ]

  return [
    ...items.map((item) => ({
      ...item,
      totalAmount: detailList.value.reduce(
        (total, detail) => total + toMoneyNumber(detail[item.property]),
        0,
      ),
      isTotal: false,
    })),
    {
      property: 'total_amount',
      itemName: '合计',
      totalAmount: calculatedTotal.value,
      isTotal: true,
    },
  ]
})

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

const getPersonAmount = (row, peopleId) => {
  const detail = detailList.value.find(
    (item) => String(item.people_id) === String(peopleId),
  )
  return detail ? detail[row.property] : 0
}

const getRowClassName = ({ row }) => (row.isTotal ? 'history-total-row' : '')

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
  <main class="page-shell history-detail-page">
    <header class="page-heading detail-page-heading">
      <div>
        <p class="page-eyebrow">Bill Detail</p>
        <h1>账单详情</h1>
        <p class="page-description">查看每位成员在本期账单中的费用明细。</p>
      </div>
      <el-button class="back-button" @click="goBack">返回历史账单</el-button>
    </header>

    <section v-if="loadError && !detailLoading" class="content-card detail-error-card">
      <el-result
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
    </section>

    <template v-else>
      <section class="history-overview">
        <div class="overview-primary">
          <span>账单月份</span>
          <strong>{{ billPeriod }}</strong>
        </div>
        <div class="overview-item overview-mode">
          <span>计算模式</span>
          <strong>{{ calculationModeLabel }}</strong>
        </div>
        <div class="overview-item">
          <span>参与人数</span>
          <strong>{{ detailPeople.length }} 人</strong>
        </div>
        <div class="overview-total">
          <span>账单总额</span>
          <strong>{{ formatMoney(billTotal) }}</strong>
        </div>
      </section>

      <section class="content-card history-result-card">
        <div class="section-header">
          <div>
            <h2>费用分摊明细</h2>
            <p>金额统一保留两位小数</p>
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

        <div class="history-table-scroll">
          <el-table
            class="history-result-table"
            v-loading="detailLoading"
            :data="tableRows"
            :row-class-name="getRowClassName"
            row-key="property"
            empty-text="该账单暂无费用明细"
            border
            table-layout="fixed"
          >
            <el-table-column
              prop="itemName"
              label="费用项目"
              width="130"
              :resizable="false"
            >
              <template #default="{ row }">
                <strong class="history-item-name">{{ row.itemName }}</strong>
              </template>
            </el-table-column>

            <el-table-column
              v-for="person in detailPeople"
              :key="person.id"
              min-width="145"
              align="right"
              :resizable="false"
            >
              <template #header>
                <div class="history-person-header">
                  <el-avatar
                    class="history-avatar"
                    :size="34"
                    :src="getAvatarUrl(person.id)"
                    :style="getAvatarUrl(person.id)
                      ? undefined
                      : { backgroundColor: getDefaultAvatarColor(person.name) }"
                  >
                    {{ getNameInitial(person.name) }}
                  </el-avatar>
                  <span :title="person.name">{{ person.name }}</span>
                </div>
              </template>
              <template #default="{ row }">
                <strong v-if="row.isTotal" class="person-total">
                  {{ formatMoney(getPersonAmount(row, person.id)) }}
                </strong>
                <span v-else>{{ formatMoney(getPersonAmount(row, person.id)) }}</span>
              </template>
            </el-table-column>

            <el-table-column
              label="总计"
              width="150"
              align="right"
              :resizable="false"
            >
              <template #default="{ row }">
                <strong class="row-total">{{ formatMoney(row.totalAmount) }}</strong>
              </template>
            </el-table-column>
          </el-table>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.back-button {
  border-color: #9eb2c7;
  color: #2e5f8d;
  background: rgba(255, 255, 255, 0.55);
}

.history-detail-page {
  width: min(1120px, calc(100% - 40px));
}

.detail-error-card {
  min-height: 390px;
}

.history-overview {
  display: grid;
  grid-template-columns: 0.8fr 1.55fr 0.7fr 1fr;
  gap: 12px;
  margin-bottom: 20px;
}

.overview-primary,
.overview-item,
.overview-total {
  display: flex;
  min-width: 0;
  min-height: 78px;
  flex-direction: column;
  justify-content: center;
  gap: 7px;
  padding: 13px 16px;
  border: 1px solid #bdcbda;
  border-radius: 13px;
  background: #edf3f8;
  box-shadow: 0 7px 18px rgba(42, 61, 83, 0.08);
}

.history-overview span {
  color: #718196;
  font-size: 12px;
}

.history-overview strong {
  overflow: hidden;
  color: #294966;
  font-size: 16px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.overview-primary {
  border-color: #a8c5df;
  background: #e2edf7;
}

.overview-total {
  border-color: #8fb9dc;
  background: linear-gradient(145deg, #dfeefa, #d3e5f4);
}

.overview-total strong {
  color: #225d91;
  font-size: 19px;
}

.lookup-alert {
  margin-bottom: 18px;
}

.history-table-scroll {
  max-width: 100%;
  overflow-x: auto;
  border-radius: 12px;
}

.history-result-table.el-table {
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

.history-result-table.el-table :deep(th.el-table__cell) {
  height: 64px;
  border-right-color: #91a6bd;
  border-bottom: 2px solid #91a6bd;
  background: #c8d9ea;
  cursor: default;
}

.history-result-table.el-table :deep(td.el-table__cell) {
  height: 66px;
  border-right-color: #a6b7c9;
  border-bottom-color: #a6b7c9;
  background: #f9fbfd;
}

.history-result-table.el-table :deep(.history-total-row td.el-table__cell) {
  border-top: 2px solid #91a6bd;
  background: linear-gradient(180deg, #edf4f9 0%, #dfeaf3 100%);
}

.history-person-header {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
}

.history-person-header span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.history-avatar {
  flex: 0 0 auto;
  border: 2px solid #fff;
  box-shadow: 0 2px 7px rgba(31, 45, 61, 0.15);
}

.history-item-name {
  color: #253a53;
  font-size: 15px;
}

.row-total {
  color: #245b89;
  font-size: 15px;
}

.person-total {
  display: inline-block;
  padding: 3px 7px;
  border: 1px solid #b5ccde;
  border-radius: 6px;
  color: #285f89;
  background: linear-gradient(180deg, #f8fbfd 0%, #e7f1f8 100%);
  font-size: 14px;
  text-align: right;
}

.history-result-table.el-table :deep(.history-total-row .history-item-name) {
  color: #1e527e;
  font-size: 15px;
}

.history-result-table.el-table :deep(.history-total-row .row-total) {
  color: #174d7a;
  font-size: 15px;
  font-weight: 800;
}

@media (max-width: 860px) {
  .history-overview {
    grid-template-columns: repeat(3, 1fr);
  }
}

@media (max-width: 640px) {
  .detail-page-heading {
    align-items: flex-start;
    flex-direction: column;
    gap: 14px;
  }

  .history-detail-page {
    width: min(100% - 24px, 1120px);
  }

  .history-overview {
    grid-template-columns: 1fr;
  }
}
</style>
