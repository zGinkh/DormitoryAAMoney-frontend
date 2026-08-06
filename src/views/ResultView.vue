<script setup>
import { computed, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useRouter } from 'vue-router'
import { saveHistoryBill } from '../api/historyApi.js'
import { formatMoney } from '../utils/money.js'
import {
  getCalculationResult,
  getPeopleAvatars,
  markCalculationResultSaved,
} from '../utils/storage.js'

const router = useRouter()
const storedData = getCalculationResult()
const calculationResult = storedData?.calculationResult || null
const storedPeopleList = Array.isArray(storedData?.peopleList) ? storedData.peopleList : []
const peopleAvatars = getPeopleAvatars()
const isSaving = ref(false)
const isSaved = ref(Boolean(storedData?.isSaved))

const avatarModules = import.meta.glob('../assets/avatars/*.{png,jpg,jpeg,webp,svg}', {
  eager: true,
  import: 'default',
})
const avatarUrlMap = new Map(
  Object.entries(avatarModules).map(([path, url]) => [path.split('/').pop(), url]),
)
const defaultAvatarColors = ['#409eff', '#67c23a', '#e6a23c', '#f56c6c', '#7c6ee6', '#2f9b95']

const peopleIdsInResult = computed(() => {
  const ids = new Set()

  calculationResult?.items?.forEach((item) => {
    item.participants?.forEach((participant) => ids.add(String(participant.peopleId)))
  })

  Object.keys(calculationResult?.personTotals || {}).forEach((id) => ids.add(String(id)))
  return ids
})

const peopleList = computed(() => {
  const peopleMap = new Map(
    storedPeopleList.map((person) => [String(person.id), person]),
  )

  return Array.from(peopleIdsInResult.value).map((id) =>
    peopleMap.get(id) || {
      id: Number(id),
      name: `成员 #${id}`,
    },
  )
})

const tableRows = computed(() => {
  if (!calculationResult) {
    return []
  }

  const itemRows = Array.isArray(calculationResult.items)
    ? calculationResult.items.map((item) => ({ ...item, isTotal: false }))
    : []

  return [
    ...itemRows,
    {
      itemName: '合计',
      totalAmount: calculationResult.totalAmount,
      isTotal: true,
    },
  ]
})

const billPeriod = computed(() => {
  if (!calculationResult) {
    return ''
  }

  return `${calculationResult.billYear}-${String(calculationResult.billMonth).padStart(2, '0')}`
})

const calculationModeLabel = computed(() =>
  calculationResult?.calculationMode === 1
    ? '部分人员不在，按天数和权重分摊'
    : '全员在住，按权重分摊',
)

const getPersonAmount = (row, peopleId) => {
  if (row.isTotal) {
    return calculationResult?.personTotals?.[String(peopleId)] ?? 0
  }

  return row.participants?.find(
    (participant) => String(participant.peopleId) === String(peopleId),
  )?.amount ?? 0
}

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
  const avatarKey = peopleAvatars[String(peopleId)]
  return avatarUrlMap.get(avatarKey) || ''
}

const getRowClassName = ({ row }) => (row.isTotal ? 'result-total-row' : '')

const saveBill = async () => {
  if (!calculationResult || isSaving.value) {
    return false
  }

  if (isSaved.value) {
    return true
  }

  isSaving.value = true

  try {
    await saveHistoryBill(calculationResult)
    isSaved.value = true
    markCalculationResultSaved()
    ElMessage.success('账单保存成功')
    return true
  } catch (error) {
    ElMessage.error(error?.message || '账单保存失败，请稍后重试')
    return false
  } finally {
    isSaving.value = false
  }
}

const goBack = async () => {
  if (!calculationResult || isSaved.value) {
    await router.push({ name: 'home' })
    return
  }

  try {
    await ElMessageBox.confirm(
      '该账单尚未保存。是否先保存到账单历史，再返回账单录入页面？',
      '账单尚未保存',
      {
        confirmButtonText: '保存并返回',
        cancelButtonText: '不保存直接返回',
        type: 'warning',
        distinguishCancelAndClose: true,
        closeOnClickModal: false,
        closeOnPressEscape: true,
      },
    )

    const saved = await saveBill()
    if (saved) {
      await router.push({ name: 'home' })
    }
  } catch (action) {
    if (action === 'cancel') {
      await router.push({ name: 'home' })
    }
  }
}
</script>

<template>
  <main class="page-shell result-page">
    <header class="page-heading result-page-heading">
      <div>
        <p class="page-eyebrow">Calculation Result</p>
        <h1>计算结果</h1>
        <p class="page-description">查看本月每项费用和每位成员的应付金额。</p>
      </div>
      <div class="result-heading-actions">
        <el-button class="back-button" @click="goBack">返回账单录入</el-button>
        <el-button
          type="primary"
          :loading="isSaving"
          :disabled="isSaved"
          @click="saveBill"
        >
          {{ isSaved ? '账单已保存' : '保存账单' }}
        </el-button>
      </div>
    </header>

    <el-result
      v-if="!calculationResult"
      class="missing-result"
      icon="warning"
      title="暂无计算结果"
      sub-title="请先返回账单录入页面完成一次计算。"
    >
      <template #extra>
        <el-button type="primary" @click="goBack">返回账单录入</el-button>
      </template>
    </el-result>

    <template v-else>
      <section class="result-overview">
        <div class="overview-primary">
          <span>账单月份</span>
          <strong>{{ billPeriod }}</strong>
        </div>
        <div class="overview-item">
          <span>计算模式</span>
          <strong>{{ calculationModeLabel }}</strong>
        </div>
        <div class="overview-item">
          <span>参与人数</span>
          <strong>{{ peopleList.length }} 人</strong>
        </div>
        <div class="overview-total">
          <span>账单总额</span>
          <strong>{{ formatMoney(calculationResult.totalAmount) }}</strong>
        </div>
      </section>

      <section class="content-card result-card">
        <div class="section-header">
          <div>
            <h2>费用分摊明细</h2>
            <p>金额统一保留两位小数</p>
          </div>
        </div>

        <div class="result-table-scroll">
          <el-table
            class="result-table"
            :data="tableRows"
            :row-class-name="getRowClassName"
            row-key="itemName"
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
                <strong class="result-item-name">{{ row.itemName }}</strong>
              </template>
            </el-table-column>

            <el-table-column
              v-for="person in peopleList"
              :key="person.id"
              min-width="145"
              align="right"
              :resizable="false"
            >
              <template #header>
                <div class="result-person-header">
                  <el-avatar
                    class="result-avatar"
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
.result-page {
  width: min(1120px, calc(100% - 40px));
}

.back-button {
  border-color: #9eb2c7;
  color: #2e5f8d;
  background: rgba(255, 255, 255, 0.55);
}

.result-heading-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.missing-result {
  min-height: 430px;
  border: 1px solid #c6d1df;
  border-radius: 18px;
  background: #edf3f8;
  box-shadow: 0 14px 34px rgba(42, 61, 83, 0.13);
}

.result-overview {
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

.result-overview span {
  color: #718196;
  font-size: 12px;
}

.result-overview strong {
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

.result-table-scroll {
  max-width: 100%;
  overflow-x: auto;
  border-radius: 12px;
}

.result-table.el-table {
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

.result-table.el-table :deep(th.el-table__cell) {
  height: 64px;
  border-right-color: #91a6bd;
  border-bottom: 2px solid #91a6bd;
  background: #c8d9ea;
  cursor: default;
}

.result-table.el-table :deep(td.el-table__cell) {
  height: 66px;
  border-right-color: #a6b7c9;
  border-bottom-color: #a6b7c9;
  background: #f9fbfd;
}

.result-table.el-table :deep(.result-total-row td.el-table__cell) {
  border-top: 2px solid #91a6bd;
  background: linear-gradient(180deg, #edf4f9 0%, #dfeaf3 100%);
}

.result-person-header {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
}

.result-person-header span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.result-avatar {
  flex: 0 0 auto;
  border: 2px solid #fff;
  box-shadow: 0 2px 7px rgba(31, 45, 61, 0.15);
}

.result-item-name {
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

.result-table.el-table :deep(.result-total-row .result-item-name) {
  color: #1e527e;
  font-size: 15px;
}

.result-table.el-table :deep(.result-total-row .row-total) {
  color: #174d7a;
  font-size: 15px;
  font-weight: 800;
}

@media (max-width: 860px) {
  .result-overview {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 640px) {
  .result-page {
    width: min(100% - 24px, 1120px);
  }

  .result-page-heading {
    align-items: flex-start;
    flex-direction: column;
    gap: 14px;
  }

  .result-heading-actions {
    width: 100%;
  }

  .result-heading-actions .el-button {
    flex: 1;
  }

  .result-overview {
    grid-template-columns: 1fr;
  }
}
</style>
