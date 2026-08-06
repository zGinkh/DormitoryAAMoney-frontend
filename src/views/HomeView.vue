<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { getIndexPeople, submitBillEntry } from '../api/indexApi.js'
import builtInDefaults from '../assets/default-data/bill-entry-defaults.json'
import { getPeopleAvatars, saveCalculationResult } from '../utils/storage.js'

const DEFAULT_ITEMS = [
  { key: 'water', name: '水费' },
  { key: 'electricity', name: '电费' },
  { key: 'phone', name: '话费' },
]
const BILL_DEFAULTS_KEY = 'dormitory-aa-money:bill-entry-defaults'

const avatarModules = import.meta.glob('../assets/avatars/*.{png,jpg,jpeg,webp,svg}', {
  eager: true,
  import: 'default',
})
const avatarUrlMap = new Map(
  Object.entries(avatarModules).map(([path, url]) => [path.split('/').pop(), url]),
)
const defaultAvatarColors = ['#409eff', '#67c23a', '#e6a23c', '#f56c6c', '#7c6ee6', '#2f9b95']

const router = useRouter()
const currentDate = new Date()
const defaultBillMonth = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}`

const billMonth = ref(defaultBillMonth)
const calculationMode = ref(0)
const peopleList = ref([])
const peopleLoading = ref(false)
const loadError = ref('')
const peopleAvatars = ref(getPeopleAvatars())
const defaultDialogVisible = ref(false)
const defaultSaving = ref(false)
const defaultDraft = ref({ items: [] })
const submitLoading = ref(false)
const stayDaysByPeopleId = ref({})
const waterUnitPrice = ref(8)
const waterOrderDates = ref([])
const electricityPayments = ref([])
const billItems = ref(
  DEFAULT_ITEMS.map((item) => ({
    ...item,
    totalAmount: null,
    weights: {},
  })),
)

const billMonthDays = computed(() => {
  const [year, month] = String(billMonth.value || '').split('-').map(Number)
  if (!year || !month) {
    return 0
  }

  return new Date(year, month, 0).getDate()
})

const billMonthStartDate = computed(() => {
  const [year, month] = String(billMonth.value || '').split('-').map(Number)
  return year && month ? new Date(year, month - 1, 1) : new Date()
})

const entryTableRows = computed(() => {
  if (calculationMode.value !== 1) {
    return billItems.value
  }

  return [
    {
      key: 'stay-days',
      name: '入住天数',
      isStayDays: true,
    },
    ...billItems.value,
  ]
})

const waterTotalAmount = computed(() => {
  const unitPrice = Number(waterUnitPrice.value)
  if (!Number.isFinite(unitPrice) || unitPrice < 0) {
    return 0
  }

  return unitPrice * waterOrderDates.value.length
})

const selectedWaterOrderDays = computed(() =>
  waterOrderDates.value
    .map((dateValue) => {
      if (dateValue instanceof Date) {
        return dateValue.getDate()
      }

      const day = Number(String(dateValue).slice(-2))
      return Number.isInteger(day) ? day : null
    })
    .filter((day) => day !== null)
    .sort((first, second) => first - second),
)

const electricityPaymentDates = computed(() =>
  electricityPayments.value.map((payment) => payment.date),
)

const sortedElectricityPayments = computed(() =>
  [...electricityPayments.value].sort((first, second) =>
    String(first.date).localeCompare(String(second.date)),
  ),
)

const electricityTotalAmount = computed(() =>
  electricityPayments.value.reduce((total, payment) => {
    const amount = Number(payment.amount)
    return total + (Number.isFinite(amount) && amount >= 0 ? amount : 0)
  }, 0),
)

const defaultEditTableRows = computed(() => {
  if (defaultDraft.value.calculationMode !== 1) {
    return defaultDraft.value.items
  }

  return [
    {
      key: 'stay-days',
      name: '入住天数',
      isStayDays: true,
    },
    ...defaultDraft.value.items,
  ]
})

const defaultWaterTotalAmount = computed(() => {
  const unitPrice = Number(defaultDraft.value.waterUnitPrice)
  const dates = Array.isArray(defaultDraft.value.waterOrderDates)
    ? defaultDraft.value.waterOrderDates
    : []

  return Number.isFinite(unitPrice) && unitPrice >= 0 ? unitPrice * dates.length : 0
})

const defaultElectricityPaymentDates = computed(() =>
  Array.isArray(defaultDraft.value.electricityPayments)
    ? defaultDraft.value.electricityPayments.map((payment) => payment.date)
    : [],
)

const sortedDefaultElectricityPayments = computed(() =>
  Array.isArray(defaultDraft.value.electricityPayments)
    ? [...defaultDraft.value.electricityPayments].sort((first, second) =>
        String(first.date).localeCompare(String(second.date)),
      )
    : [],
)

const defaultElectricityTotalAmount = computed(() =>
  (defaultDraft.value.electricityPayments || []).reduce((total, payment) => {
    const amount = Number(payment.amount)
    return total + (Number.isFinite(amount) && amount >= 0 ? amount : 0)
  }, 0),
)

const getErrorMessage = (error) => error?.message || '人员信息加载失败，请稍后重试'

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

const rebuildWeights = (people) => {
  billItems.value.forEach((item) => {
    item.weights = Object.fromEntries(
      people.map((person) => [String(person.id), item.weights[String(person.id)] ?? null]),
    )
  })

  stayDaysByPeopleId.value = Object.fromEntries(
    people.map((person) => [
      String(person.id),
      stayDaysByPeopleId.value[String(person.id)] ?? null,
    ]),
  )
}

const isOutsideBillMonth = (date) => {
  const [year, month] = String(billMonth.value || '').split('-').map(Number)
  return date.getFullYear() !== year || date.getMonth() + 1 !== month
}

const updateWaterOrderDates = (dates) => {
  waterOrderDates.value = Array.isArray(dates)
    ? [...new Set(dates.filter(Boolean))]
    : []
}

const clearWaterOrderDates = () => {
  waterOrderDates.value = []
}

const buildElectricityPayments = (dates, currentPayments = []) => {
  const existingPayments = new Map(
    currentPayments.map((payment) => [String(payment.date), payment]),
  )

  return [...new Set((Array.isArray(dates) ? dates : []).filter(Boolean).map(String))].map(
    (date) => ({
      date,
      amount: existingPayments.get(date)?.amount ?? null,
    }),
  )
}

const updateElectricityPaymentDates = (dates) => {
  electricityPayments.value = buildElectricityPayments(dates, electricityPayments.value)
}

const clearElectricityPayments = () => {
  electricityPayments.value = []
}

const updateDefaultWaterOrderDates = (dates) => {
  defaultDraft.value.waterOrderDates = Array.isArray(dates)
    ? [...new Set(dates.filter(Boolean))]
    : []
}

const clearDefaultWaterOrderDates = () => {
  defaultDraft.value.waterOrderDates = []
}

const updateDefaultElectricityPaymentDates = (dates) => {
  defaultDraft.value.electricityPayments = buildElectricityPayments(
    dates,
    defaultDraft.value.electricityPayments,
  )
}

const clearDefaultElectricityPayments = () => {
  defaultDraft.value.electricityPayments = []
}

const getEntryRowClassName = ({ row }) => (row.isStayDays ? 'stay-days-row' : '')

const getModeDefaultStorageKey = (mode) => `${BILL_DEFAULTS_KEY}:mode-${mode}`

const readDefaultData = (mode = calculationMode.value) => {
  try {
    const savedModeDefaults = localStorage.getItem(getModeDefaultStorageKey(mode))
    if (savedModeDefaults) {
      return JSON.parse(savedModeDefaults)
    }

    if (mode === 0) {
      const legacyDefaults = localStorage.getItem(BILL_DEFAULTS_KEY)
      if (legacyDefaults) {
        return JSON.parse(legacyDefaults)
      }
    }

    return builtInDefaults?.modes?.[String(mode)] || builtInDefaults
  } catch {
    return builtInDefaults?.modes?.[String(mode)] || builtInDefaults
  }
}

const createDefaultDraft = (
  source = readDefaultData(calculationMode.value),
  mode = calculationMode.value,
) => {
  const peopleCount = peopleList.value.length
  const baseWeight = peopleCount ? Math.floor(100 / peopleCount) : 0
  const remainingWeight = peopleCount ? 100 - baseWeight * peopleCount : 0
  const usesPercent = source?.weightUnit === 'PERCENT'

  return {
    billMonth:
      source?.billMonth && source.billMonth !== 'CURRENT'
        ? source.billMonth
        : defaultBillMonth,
    calculationMode: Number(mode) === 1 ? 1 : 0,
    waterUnitPrice:
      source?.waterUnitPrice === null || source?.waterUnitPrice === undefined
        ? 8
        : Number(source.waterUnitPrice),
    waterOrderDates: Array.isArray(source?.waterOrderDates)
      ? [...new Set(source.waterOrderDates.filter(Boolean))]
      : [],
    electricityPayments: Array.isArray(source?.electricityPayments)
      ? source.electricityPayments
          .filter((payment) => payment?.date)
          .map((payment) => ({
            date: String(payment.date),
            amount:
              payment.amount === null || payment.amount === undefined
                ? null
                : Number(payment.amount),
          }))
      : [],
    stayDaysByPeopleId: Object.fromEntries(
      peopleList.value.map((person) => {
        const savedDays = source?.stayDaysByPeopleId?.[String(person.id)]
        const normalizedDays = Number(savedDays)

        return [
          String(person.id),
          savedDays === null || savedDays === undefined
            ? billMonthDays.value
            : Math.min(billMonthDays.value, Math.max(0, Math.round(normalizedDays))),
        ]
      }),
    ),
    items: DEFAULT_ITEMS.map((defaultItem) => {
      const savedItem = source?.items?.find((item) => item.key === defaultItem.key)
      const savedWeights = savedItem?.weights || {}

      return {
        ...defaultItem,
        totalAmount:
          savedItem?.totalAmount === null || savedItem?.totalAmount === undefined
            ? 0
            : Number(savedItem.totalAmount),
        weights: Object.fromEntries(
          peopleList.value.map((person, index) => {
            const savedWeight = savedWeights[String(person.id)]
            const numericWeight = Number(savedWeight)
            const normalizedWeight = usesPercent
              ? Math.round(numericWeight)
              : Math.round(numericWeight * 100)

            return [
              String(person.id),
              savedWeight === null || savedWeight === undefined
                ? baseWeight + (index < remainingWeight ? 1 : 0)
                : Math.min(100, Math.max(0, normalizedWeight)),
            ]
          }),
        ),
      }
    }),
  }
}

const applyDefaultData = () => {
  const defaults = createDefaultDraft(readDefaultData(calculationMode.value), calculationMode.value)
  billMonth.value = defaults.billMonth

  billItems.value.forEach((item) => {
    const defaultItem = defaults.items.find((candidate) => candidate.key === item.key)
    item.totalAmount = defaultItem?.totalAmount ?? 0
    item.weights = { ...(defaultItem?.weights || {}) }
  })

  if (calculationMode.value === 1) {
    stayDaysByPeopleId.value = { ...defaults.stayDaysByPeopleId }
    waterUnitPrice.value = defaults.waterUnitPrice
    updateWaterOrderDates(defaults.waterOrderDates)
    electricityPayments.value = defaults.electricityPayments.map((payment) => ({ ...payment }))
  }

  ElMessage.success(`${calculationMode.value === 1 ? '部分人员不在' : '全员在住'}默认数据已填充`)
}

const openDefaultDialog = () => {
  defaultDraft.value = createDefaultDraft(
    readDefaultData(calculationMode.value),
    calculationMode.value,
  )
  defaultDialogVisible.value = true
}

const saveDefaultData = () => {
  if (defaultSaving.value) {
    return
  }

  defaultSaving.value = true

  try {
    const dataToSave = {
      billMonth: 'CURRENT',
      calculationMode: defaultDraft.value.calculationMode,
      weightUnit: 'PERCENT',
      waterUnitPrice: defaultDraft.value.waterUnitPrice ?? 8,
      waterOrderDates: [...(defaultDraft.value.waterOrderDates || [])],
      electricityPayments: (defaultDraft.value.electricityPayments || []).map((payment) => ({
        date: payment.date,
        amount: payment.amount ?? 0,
      })),
      stayDaysByPeopleId: { ...(defaultDraft.value.stayDaysByPeopleId || {}) },
      items: defaultDraft.value.items.map((item) => ({
        key: item.key,
        name: item.name,
        totalAmount: item.totalAmount ?? 0,
        weights: { ...item.weights },
      })),
    }

    localStorage.setItem(
      getModeDefaultStorageKey(defaultDraft.value.calculationMode),
      JSON.stringify(dataToSave),
    )
    defaultDialogVisible.value = false
    ElMessage.success(
      `${defaultDraft.value.calculationMode === 1 ? '部分人员不在' : '全员在住'}默认数据已保存`,
    )
  } catch {
    ElMessage.error('默认数据保存失败，请检查浏览器存储权限')
  } finally {
    defaultSaving.value = false
  }
}

const validateItemAmount = (item) => {
  if (item.totalAmount === null || item.totalAmount === undefined || item.totalAmount === '') {
    ElMessage.warning(`请输入${item.name}总金额`)
    return false
  }

  if (!Number.isFinite(Number(item.totalAmount)) || Number(item.totalAmount) < 0) {
    ElMessage.warning(`${item.name}总金额不能小于 0`)
    return false
  }

  return true
}

const validateItemWeights = (item) => {
  let totalWeight = 0

  for (const person of peopleList.value) {
    const weight = item.weights[String(person.id)]
    const numericWeight = Number(weight)

    if (weight === null || weight === undefined || weight === '') {
      ElMessage.warning(`请填写${item.name}中“${person.name}”的权重`)
      return false
    }

    if (!Number.isInteger(numericWeight) || numericWeight < 0 || numericWeight > 100) {
      ElMessage.warning(`${item.name}中“${person.name}”的权重必须是 0 到 100 的整数`)
      return false
    }

    totalWeight += numericWeight
  }

  if (totalWeight !== 100) {
    ElMessage.warning(`${item.name}的人员权重合计必须为 100%，当前为 ${totalWeight}%`)
    return false
  }

  return true
}

const validateModeZeroBillEntry = () =>
  billItems.value.every((item) => validateItemAmount(item) && validateItemWeights(item))

const validateModeOneBillEntry = () => {
  const unitPrice = Number(waterUnitPrice.value)
  if (
    waterUnitPrice.value === null ||
    waterUnitPrice.value === undefined ||
    waterUnitPrice.value === '' ||
    !Number.isFinite(unitPrice) ||
    unitPrice < 0
  ) {
    ElMessage.warning('每桶水单价不能为空或小于 0')
    return false
  }

  const normalizedWaterDates = waterOrderDates.value.map(String)
  if (new Set(normalizedWaterDates).size !== normalizedWaterDates.length) {
    ElMessage.warning('订水日期不能重复')
    return false
  }
  if (normalizedWaterDates.some((date) => !date.startsWith(`${billMonth.value}-`))) {
    ElMessage.warning('订水日期必须属于当前账单月份')
    return false
  }

  const electricityDates = new Set()
  for (const payment of electricityPayments.value) {
    if (!payment?.date || !String(payment.date).startsWith(`${billMonth.value}-`)) {
      ElMessage.warning('电费日期必须属于当前账单月份')
      return false
    }
    if (electricityDates.has(String(payment.date))) {
      ElMessage.warning(`电费日期不能重复：${payment.date}`)
      return false
    }
    electricityDates.add(String(payment.date))

    if (
      payment.amount === null ||
      payment.amount === undefined ||
      payment.amount === '' ||
      !Number.isFinite(Number(payment.amount)) ||
      Number(payment.amount) < 0
    ) {
      ElMessage.warning(`请填写 ${payment.date} 的有效电费金额`)
      return false
    }
  }

  for (const person of peopleList.value) {
    const stayDays = stayDaysByPeopleId.value[String(person.id)]
    const numericStayDays = Number(stayDays)
    if (
      stayDays === null ||
      stayDays === undefined ||
      stayDays === '' ||
      !Number.isInteger(numericStayDays) ||
      numericStayDays < 0 ||
      numericStayDays > billMonthDays.value
    ) {
      ElMessage.warning(`“${person.name}”的入住天数必须是 0 到 ${billMonthDays.value} 的整数`)
      return false
    }
  }

  const phoneItem = billItems.value.find((item) => item.key === 'phone')
  return Boolean(
    phoneItem && validateItemAmount(phoneItem) && validateItemWeights(phoneItem),
  )
}

const validateBillEntry = () => {
  if (!peopleList.value.length) {
    ElMessage.warning('请先添加宿舍成员')
    return false
  }

  return calculationMode.value === 1
    ? validateModeOneBillEntry()
    : validateModeZeroBillEntry()
}

const buildBillEntryPayload = () => {
  const [billYear, month] = billMonth.value.split('-').map(Number)

  if (calculationMode.value === 1) {
    const phoneItem = billItems.value.find((item) => item.key === 'phone')

    return {
      billYear,
      billMonth: month,
      calculationMode: 1,
      stayDaysByPeopleId: Object.fromEntries(
        peopleList.value.map((person) => [
          String(person.id),
          Number(stayDaysByPeopleId.value[String(person.id)]),
        ]),
      ),
      waterUnitPrice: Number(waterUnitPrice.value),
      waterOrderDates: waterOrderDates.value.map(String),
      electricityPayments: electricityPayments.value.map((payment) => ({
        date: String(payment.date),
        amount: Number(payment.amount),
      })),
      items: [
        {
          itemName: phoneItem.name,
          totalAmount: Number(phoneItem.totalAmount),
          participants: peopleList.value.map((person) => ({
            peopleId: person.id,
            weight: Number(phoneItem.weights[String(person.id)]),
          })),
        },
      ],
    }
  }

  return {
    billYear,
    billMonth: month,
    calculationMode: calculationMode.value,
    items: billItems.value.map((item) => ({
      itemName: item.name,
      totalAmount: Number(item.totalAmount),
      participants: peopleList.value.map((person) => ({
        peopleId: person.id,
        weight: Number(item.weights[String(person.id)]),
      })),
    })),
  }
}

const handleCalculate = async () => {
  if (submitLoading.value || !validateBillEntry()) {
    return
  }

  submitLoading.value = true

  try {
    const calculationResult = await submitBillEntry(buildBillEntryPayload())

    if (!calculationResult || !Array.isArray(calculationResult.items)) {
      throw new Error('后端未返回有效的计算结果')
    }

    saveCalculationResult(calculationResult, peopleList.value)
    ElMessage.success('账单计算完成')
    await router.push({ name: 'result' })
  } catch (error) {
    ElMessage.error(error?.message || '账单计算失败，请稍后重试')
  } finally {
    submitLoading.value = false
  }
}

const loadPeople = async () => {
  peopleLoading.value = true
  loadError.value = ''

  try {
    const data = await getIndexPeople()
    if (!Array.isArray(data)) {
      throw new Error('人员列表数据格式不正确')
    }

    peopleList.value = data
    peopleAvatars.value = getPeopleAvatars()
    rebuildWeights(data)
  } catch (error) {
    peopleList.value = []
    loadError.value = getErrorMessage(error)
  } finally {
    peopleLoading.value = false
  }
}

const goToPeopleManage = () => router.push({ name: 'peopleManage' })

onMounted(loadPeople)
</script>

<template>
  <main class="page-shell bill-entry-page">
    <header class="page-heading bill-page-heading">
      <div>
        <p class="page-eyebrow">Bill Entry</p>
        <h1>账单录入</h1>
        <p class="page-description">填写本月费用和每位成员的分摊权重。</p>
      </div>
      <el-tag class="page-tag" effect="dark" round>3 个费用项目</el-tag>
    </header>

    <section class="content-card entry-settings-card">
      <div class="section-header settings-section-header">
        <div>
          <h2>账单设置</h2>
        </div>
      </div>

      <div class="setting-grid">
        <div class="setting-field month-field">
          <span class="setting-label">账单月份</span>
          <div class="month-display" aria-label="当前账单月份">
            <strong>
              {{ billMonth.slice(0, 4) }} 年 {{ billMonth.slice(5, 7) }} 月
              <small>（共 {{ billMonthDays }} 天）</small>
            </strong>
            <span class="current-month-badge">本月</span>
          </div>
        </div>

        <div class="setting-field mode-field">
          <span class="setting-label">计算模式</span>
          <div class="mode-control-row">
            <el-radio-group v-model="calculationMode" class="mode-choice-group">
              <el-radio-button :value="0">全员在住</el-radio-button>
              <el-radio-button :value="1">部分人员不在</el-radio-button>
            </el-radio-group>
            <div class="mode-descriptions">
              <p :class="{ 'is-active': calculationMode === 0 }">
                <strong>全员在住：</strong>
                所有成员整月在住，费用只按整数百分比权重分摊。
              </p>
              <p :class="{ 'is-active': calculationMode === 1 }">
                <strong>部分人员不在：</strong>
                填写从月初开始的入住天数，并记录本月订水日期。
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="content-card cost-entry-card">
      <div class="section-header cost-section-header">
        <div>
          <h2>费用与权重</h2>
          <p v-if="calculationMode === 0">
            金额单位为元，人员权重填写 0 到 100 的整数百分比
          </p>
          <p v-else>水费和电费按日期及在住情况自动分摊，话费填写整数百分比权重</p>
        </div>
        <div class="entry-actions">
          <el-button
            type="primary"
            plain
            :disabled="peopleLoading || !peopleList.length"
            @click="applyDefaultData"
          >
            默认数据
          </el-button>
          <el-button
            :disabled="peopleLoading || !peopleList.length"
            @click="openDefaultDialog"
          >
            编辑默认
          </el-button>
          <el-button :loading="peopleLoading" @click="loadPeople">刷新人员</el-button>
        </div>
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
          <el-button link type="primary" :loading="peopleLoading" @click="loadPeople">
            重新加载
          </el-button>
        </template>
      </el-alert>

      <div
        v-if="calculationMode === 1 && peopleList.length"
        class="utility-record-grid"
      >
      <section class="water-order-panel" aria-labelledby="water-order-title">
        <div class="water-order-heading">
          <div>
            <h3 id="water-order-title">订水记录</h3>
            <p>每选择一个日期代表订购 1 桶水，日期不可重复。</p>
          </div>
          <div class="water-order-summary">
            <span>已选 {{ waterOrderDates.length }} 天 / {{ waterOrderDates.length }} 桶</span>
            <strong>水费合计 ￥{{ waterTotalAmount.toFixed(2) }}</strong>
          </div>
        </div>

        <div class="water-order-fields">
          <div class="water-order-field unit-price-field">
            <label for="water-unit-price">每桶单价</label>
            <div class="water-price-input-wrap">
              <el-input-number
                id="water-unit-price"
                v-model="waterUnitPrice"
                :min="0"
                :precision="2"
                :step="1"
                controls-position="right"
              />
              <span>元 / 桶</span>
            </div>
          </div>

          <div class="water-order-field order-date-field">
            <label for="water-order-dates">订水日期</label>
            <el-date-picker
              id="water-order-dates"
              :model-value="waterOrderDates"
              class="water-date-picker"
              type="dates"
              value-format="YYYY-MM-DD"
              format="MM 月 DD 日"
              placeholder="选择订水日期（可多选）"
              :default-value="billMonthStartDate"
              :disabled-date="isOutsideBillMonth"
              clearable
              @update:model-value="updateWaterOrderDates"
              @clear="clearWaterOrderDates"
            />
          </div>
        </div>

        <div class="selected-water-days">
          <span v-if="!selectedWaterOrderDays.length" class="no-water-days">
            暂未选择订水日期
          </span>
          <template v-else>
            <el-tag
              v-for="day in selectedWaterOrderDays"
              :key="day"
              size="small"
              effect="plain"
              round
            >
              {{ day }} 日
            </el-tag>
          </template>
        </div>
      </section>

      <section class="electricity-payment-panel" aria-labelledby="electricity-payment-title">
        <div class="electricity-payment-heading">
          <div>
            <h3 id="electricity-payment-title">电费缴费记录</h3>
            <p>选择本月缴费日期后，分别填写每次实际支付的金额。</p>
          </div>
          <div class="electricity-payment-summary">
            <span>共 {{ electricityPayments.length }} 笔</span>
            <strong>电费合计 ￥{{ electricityTotalAmount.toFixed(2) }}</strong>
          </div>
        </div>

        <div class="electricity-date-field">
          <label for="electricity-payment-dates">电费支付日期</label>
          <el-date-picker
            id="electricity-payment-dates"
            :model-value="electricityPaymentDates"
            class="electricity-date-picker"
            type="dates"
            value-format="YYYY-MM-DD"
            format="MM/DD"
            placeholder="选择电费支付日期（可多选）"
            :default-value="billMonthStartDate"
            :disabled-date="isOutsideBillMonth"
            clearable
            @update:model-value="updateElectricityPaymentDates"
            @clear="clearElectricityPayments"
          />
        </div>

        <div v-if="sortedElectricityPayments.length" class="electricity-payment-list">
          <div
            v-for="payment in sortedElectricityPayments"
            :key="payment.date"
            class="electricity-payment-item"
          >
            <el-tag size="small" effect="plain" round>{{ payment.date.slice(-2) }} 日</el-tag>
            <div class="electricity-amount-input-wrap">
              <el-input-number
                v-model="payment.amount"
                size="small"
                :min="0"
                :precision="2"
                :step="1"
                controls-position="right"
                placeholder="支付金额"
              />
              <span>元</span>
            </div>
          </div>
        </div>
        <p v-else class="no-electricity-payments">暂未选择电费支付日期</p>
      </section>
      </div>

      <div v-if="peopleLoading && !peopleList.length" class="initial-loading" v-loading="true">
        正在加载宿舍成员…
      </div>

      <el-empty
        v-else-if="!loadError && !peopleList.length"
        description="暂无宿舍成员，请先添加人员"
        :image-size="88"
      >
        <el-button type="primary" @click="goToPeopleManage">前往人员管理</el-button>
      </el-empty>

      <div v-else-if="peopleList.length" class="table-scroll">
        <el-table
          v-loading="peopleLoading"
          class="bill-entry-table"
          :data="entryTableRows"
          :row-class-name="getEntryRowClassName"
          row-key="key"
          border
          table-layout="fixed"
        >
          <el-table-column
            prop="name"
            label="费用项目"
            width="110"
            :resizable="false"
          >
            <template #default="{ row }">
              <strong class="item-name">{{ row.name }}</strong>
            </template>
          </el-table-column>

          <el-table-column label="总金额（元）" width="185" :resizable="false">
            <template #default="{ row }">
              <span v-if="row.isStayDays" class="stay-days-hint">从本月 1 日开始</span>
              <div
                v-else-if="calculationMode === 1 && row.key === 'water'"
                class="derived-water-amount"
              >
                <strong>￥{{ waterTotalAmount.toFixed(2) }}</strong>
                <small>{{ waterOrderDates.length }} 桶 × ￥{{ Number(waterUnitPrice || 0).toFixed(2) }}</small>
              </div>
              <div
                v-else-if="calculationMode === 1 && row.key === 'electricity'"
                class="derived-water-amount"
              >
                <strong>￥{{ electricityTotalAmount.toFixed(2) }}</strong>
                <small>{{ electricityPayments.length }} 笔缴费记录</small>
              </div>
              <el-input-number
                v-else
                v-model="row.totalAmount"
                class="amount-input"
                :min="0"
                :precision="2"
                :step="1"
                controls-position="right"
                placeholder="请输入金额"
              />
            </template>
          </el-table-column>

          <el-table-column
            v-for="person in peopleList"
            :key="person.id"
            min-width="140"
            align="center"
            :resizable="false"
          >
            <template #header>
              <div class="person-header">
                <el-avatar
                  class="entry-avatar"
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
              <div v-if="row.isStayDays" class="stay-days-input-wrap">
                <el-input-number
                  v-model="stayDaysByPeopleId[String(person.id)]"
                  class="stay-days-input"
                  :min="0"
                  :max="billMonthDays"
                  :step="1"
                  :precision="0"
                  :controls="false"
                  placeholder="0"
                />
                <span>天</span>
              </div>
              <span
                v-else-if="calculationMode === 1 && ['water', 'electricity'].includes(row.key)"
                class="water-share-hint"
              >
                自动分摊
              </span>
              <div v-else class="weight-input-wrap">
                <el-input-number
                  v-model="row.weights[String(person.id)]"
                  class="weight-input"
                  :min="0"
                  :max="100"
                  :step="1"
                  :precision="0"
                  :controls="false"
                  placeholder="0"
                />
                <span>%</span>
              </div>
            </template>
          </el-table-column>
        </el-table>
      </div>

      <div class="entry-footer">
        <p v-if="calculationMode === 0">
          提交前会检查每项费用的人员权重合计是否为 100%。
        </p>
        <p v-else>水费和电费按在住日期平均分摊，话费按权重及入住天数计算。</p>
        <el-button
          type="primary"
          size="large"
          :loading="submitLoading"
          :disabled="peopleLoading || !peopleList.length"
          @click="handleCalculate"
        >
          开始计算
        </el-button>
      </div>
    </section>

    <el-dialog
      v-model="defaultDialogVisible"
      :title="`编辑${calculationMode === 1 ? '部分人员不在' : '全员在住'}默认数据`"
      width="min(900px, calc(100vw - 32px))"
      :close-on-click-modal="!defaultSaving"
      :close-on-press-escape="!defaultSaving"
      :show-close="!defaultSaving"
    >
      <p class="default-dialog-description">
        当前编辑的是“{{ calculationMode === 1 ? '部分人员不在' : '全员在住' }}”模式，
        两种模式的默认数据会分别保存。
      </p>

      <div v-if="defaultDraft.calculationMode === 1" class="default-water-settings">
        <div class="water-order-field unit-price-field">
          <label for="default-water-unit-price">默认每桶单价</label>
          <div class="water-price-input-wrap">
            <el-input-number
              id="default-water-unit-price"
              v-model="defaultDraft.waterUnitPrice"
              :min="0"
              :precision="2"
              :step="1"
              controls-position="right"
            />
            <span>元 / 桶</span>
          </div>
        </div>

        <div class="water-order-field order-date-field">
          <label for="default-water-order-dates">默认订水日期</label>
          <el-date-picker
            id="default-water-order-dates"
            :model-value="defaultDraft.waterOrderDates"
            class="water-date-picker"
            type="dates"
            value-format="YYYY-MM-DD"
            format="MM 月 DD 日"
            placeholder="选择默认订水日期（可多选）"
            :default-value="billMonthStartDate"
            :disabled-date="isOutsideBillMonth"
            clearable
            @update:model-value="updateDefaultWaterOrderDates"
            @clear="clearDefaultWaterOrderDates"
          />
        </div>
      </div>

      <div v-if="defaultDraft.calculationMode === 1" class="default-electricity-settings">
        <div class="default-electricity-heading">
          <div>
            <strong>默认电费缴费记录</strong>
            <p>选择日期后，为每一笔填写默认支付金额。</p>
          </div>
          <span>合计 ￥{{ defaultElectricityTotalAmount.toFixed(2) }}</span>
        </div>

        <el-date-picker
          :model-value="defaultElectricityPaymentDates"
          class="electricity-date-picker"
          type="dates"
          value-format="YYYY-MM-DD"
          format="MM/DD"
          placeholder="选择默认支付日期（可多选）"
          :default-value="billMonthStartDate"
          :disabled-date="isOutsideBillMonth"
          clearable
          @update:model-value="updateDefaultElectricityPaymentDates"
          @clear="clearDefaultElectricityPayments"
        />

        <div
          v-if="sortedDefaultElectricityPayments.length"
          class="electricity-payment-list default-electricity-payment-list"
        >
          <div
            v-for="payment in sortedDefaultElectricityPayments"
            :key="payment.date"
            class="electricity-payment-item"
          >
            <el-tag size="small" effect="plain" round>{{ payment.date.slice(-2) }} 日</el-tag>
            <div class="electricity-amount-input-wrap">
              <el-input-number
                v-model="payment.amount"
                size="small"
                :min="0"
                :precision="2"
                :step="1"
                controls-position="right"
                placeholder="支付金额"
              />
              <span>元</span>
            </div>
          </div>
        </div>
      </div>

      <div class="default-table-scroll">
        <el-table
          class="default-edit-table"
          :data="defaultEditTableRows"
          row-key="key"
          border
          table-layout="fixed"
        >
          <el-table-column prop="name" label="费用项目" width="100" :resizable="false" />
          <el-table-column label="默认金额（元）" width="180" :resizable="false">
            <template #default="{ row }">
              <span v-if="row.isStayDays" class="stay-days-hint">从本月 1 日开始</span>
              <div
                v-else-if="defaultDraft.calculationMode === 1 && row.key === 'water'"
                class="derived-water-amount"
              >
                <strong>￥{{ defaultWaterTotalAmount.toFixed(2) }}</strong>
                <small>
                  {{ defaultDraft.waterOrderDates.length }} 桶 ×
                  ￥{{ Number(defaultDraft.waterUnitPrice || 0).toFixed(2) }}
                </small>
              </div>
              <div
                v-else-if="defaultDraft.calculationMode === 1 && row.key === 'electricity'"
                class="derived-water-amount"
              >
                <strong>￥{{ defaultElectricityTotalAmount.toFixed(2) }}</strong>
                <small>{{ defaultDraft.electricityPayments.length }} 笔缴费记录</small>
              </div>
              <el-input-number
                v-else
                v-model="row.totalAmount"
                class="amount-input"
                :min="0"
                :precision="2"
                :step="1"
                controls-position="right"
              />
            </template>
          </el-table-column>
          <el-table-column
            v-for="person in peopleList"
            :key="person.id"
            min-width="125"
            align="center"
            :resizable="false"
          >
            <template #header>
              <span class="default-person-name" :title="person.name">{{ person.name }}</span>
            </template>
            <template #default="{ row }">
              <div v-if="row.isStayDays" class="stay-days-input-wrap">
                <el-input-number
                  v-model="defaultDraft.stayDaysByPeopleId[String(person.id)]"
                  class="stay-days-input"
                  :min="0"
                  :max="billMonthDays"
                  :step="1"
                  :precision="0"
                  :controls="false"
                  placeholder="0"
                />
                <span>天</span>
              </div>
              <span
                v-else-if="defaultDraft.calculationMode === 1 && ['water', 'electricity'].includes(row.key)"
                class="water-share-hint"
              >
                自动分摊
              </span>
              <div v-else class="weight-input-wrap">
                <el-input-number
                  v-model="row.weights[String(person.id)]"
                  class="weight-input"
                  :min="0"
                  :max="100"
                  :step="1"
                  :precision="0"
                  :controls="false"
                  placeholder="0"
                />
                <span>%</span>
              </div>
            </template>
          </el-table-column>
        </el-table>
      </div>

      <template #footer>
        <el-button :disabled="defaultSaving" @click="defaultDialogVisible = false">
          取消
        </el-button>
        <el-button type="primary" :loading="defaultSaving" @click="saveDefaultData">
          保存默认数据
        </el-button>
      </template>
    </el-dialog>
  </main>
</template>

<style scoped>
.bill-entry-page {
  width: min(1120px, calc(100% - 40px));
}

.entry-settings-card {
  width: 100%;
  margin-bottom: 20px;
}

.settings-section-header {
  margin-bottom: 18px;
}

.setting-grid {
  display: grid;
  grid-template-columns: 250px minmax(0, 1fr);
  align-items: flex-start;
  gap: 28px;
  padding: 14px 16px;
  border: 1px solid rgba(163, 185, 205, 0.68);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.42);
  box-shadow: inset 0 1px rgba(255, 255, 255, 0.7);
}

.setting-field {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 9px;
}

.month-field {
  width: 250px;
}

.mode-field {
  flex: 1;
}

.setting-field label,
.setting-label {
  color: #34465c;
  font-size: 14px;
  font-weight: 700;
}

.month-display {
  display: flex;
  min-height: 34px;
  align-items: center;
  justify-content: flex-start;
  gap: 8px;
  padding: 0 11px 0 13px;
  border: 1px solid #b8c8d8;
  border-radius: 7px;
  background: #f7fafc;
  white-space: nowrap;
}

.month-display strong {
  display: flex;
  min-width: 0;
  align-items: baseline;
  color: #2c455f;
  font-size: 14px;
  font-weight: 600;
  white-space: nowrap;
}

.month-display strong small {
  margin-left: 3px;
  color: #6f8194;
  font-size: 12px;
  font-weight: 500;
  white-space: nowrap;
}

.current-month-badge {
  flex: 0 0 auto;
  padding: 2px 7px;
  border-radius: 9px;
  color: #3478b5;
  background: #e1edf7;
  font-size: 12px;
  font-weight: 700;
  line-height: 1.35;
}

.mode-control-row {
  display: flex;
  align-items: flex-start;
  gap: 20px;
}

.mode-choice-group {
  display: grid;
  width: 330px;
  flex: 0 0 330px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.mode-choice-group :deep(.el-radio-button) {
  width: 100%;
}

.mode-choice-group :deep(.el-radio-button__inner) {
  display: flex;
  min-height: 34px;
  width: 100%;
  align-items: center;
  justify-content: center;
  padding: 7px 10px;
  font-size: 15px;
}

.mode-descriptions {
  display: grid;
  min-width: 0;
  flex: 1;
  grid-template-columns: 1fr;
  gap: 5px;
}

.mode-descriptions p {
  margin: 0;
  color: #8795a5;
  font-size: 13px;
  line-height: 1.45;
}

.mode-descriptions p.is-active {
  color: #54718e;
}

.mode-descriptions strong {
  color: inherit;
}

.utility-record-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  align-items: start;
  gap: 16px;
  margin-bottom: 18px;
}

.water-order-panel {
  min-width: 0;
  margin-bottom: 0;
  padding: 18px;
  border: 1px solid #a9c4dc;
  border-radius: 13px;
  background: linear-gradient(145deg, #f4f9fd 0%, #e7f1f8 100%);
  box-shadow: 0 5px 15px rgba(45, 82, 113, 0.08);
}

.water-order-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 22px;
  margin-bottom: 15px;
}

.water-order-heading h3,
.water-order-heading p {
  margin: 0;
}

.water-order-heading h3 {
  color: #244663;
  font-size: 17px;
}

.water-order-heading p {
  margin-top: 5px;
  color: #718297;
  font-size: 12px;
}

.water-order-summary {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
}

.water-order-summary span {
  color: #6b7f93;
  font-size: 12px;
}

.water-order-summary strong {
  color: #236493;
  font-size: 16px;
}

.water-order-fields {
  display: grid;
  grid-template-columns: 155px minmax(0, 1fr);
  gap: 12px;
}

.water-order-field {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 7px;
}

.water-order-field label {
  color: #40566d;
  font-size: 13px;
  font-weight: 700;
}

.water-order-panel .order-date-field {
  margin-left: 28px;
}

.water-price-input-wrap {
  display: flex;
  align-items: center;
  gap: 8px;
}

.water-price-input-wrap .el-input-number {
  width: 108px;
}

.water-price-input-wrap span {
  color: #65798d;
  font-size: 12px;
  white-space: nowrap;
}

.water-date-picker.el-date-editor {
  width: 100%;
}

.selected-water-days {
  display: flex;
  min-height: 24px;
  flex-wrap: wrap;
  align-items: center;
  gap: 7px;
  margin: 12px 0 0 195px;
}

.no-water-days {
  color: #8a98a8;
  font-size: 12px;
}

.electricity-payment-panel {
  min-width: 0;
  margin-bottom: 0;
  padding: 18px;
  border: 1px solid #b7c8e2;
  border-radius: 13px;
  background: linear-gradient(145deg, #f7f9fd 0%, #edf2fa 100%);
  box-shadow: 0 5px 15px rgba(55, 75, 113, 0.07);
}

.electricity-payment-heading,
.default-electricity-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20px;
  margin-bottom: 14px;
}

.electricity-payment-heading h3,
.electricity-payment-heading p,
.default-electricity-heading p {
  margin: 0;
}

.electricity-payment-heading h3 {
  color: #334e73;
  font-size: 17px;
}

.electricity-payment-heading p,
.default-electricity-heading p {
  margin-top: 5px;
  color: #718297;
  font-size: 12px;
}

.electricity-payment-summary {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
}

.electricity-payment-summary span {
  color: #6b7f93;
  font-size: 12px;
}

.electricity-payment-summary strong,
.default-electricity-heading > span {
  color: #416c9c;
  font-size: 16px;
  font-weight: 700;
  white-space: nowrap;
}

.electricity-date-field {
  display: flex;
  flex-direction: column;
  gap: 7px;
}

.electricity-date-field label,
.default-electricity-heading strong {
  color: #40566d;
  font-size: 13px;
  font-weight: 700;
}

.electricity-date-picker.el-date-editor {
  width: 100%;
  min-height: 42px;
}

.electricity-date-picker.el-date-editor :deep(.el-input__wrapper) {
  min-height: 42px;
  padding-right: 13px;
  padding-left: 13px;
}

.electricity-date-picker.el-date-editor :deep(.el-input__inner) {
  font-size: 13px;
}

.electricity-payment-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(190px, 210px));
  column-gap: 16px;
  row-gap: 10px;
  margin-top: 12px;
}

.electricity-payment-item {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 7px;
  padding: 5px 7px;
  border: 1px solid #ccd8e8;
  border-radius: 7px;
  background: rgba(255, 255, 255, 0.72);
}

.electricity-payment-item .el-tag {
  flex: 0 0 auto;
}

.electricity-amount-input-wrap {
  display: flex;
  min-width: 0;
  flex: 1;
  align-items: center;
  gap: 7px;
}

.electricity-amount-input-wrap .el-input-number {
  width: 100%;
}

.electricity-amount-input-wrap span {
  flex: 0 0 auto;
  color: #65798d;
  font-size: 12px;
}

.no-electricity-payments {
  margin: 12px 0 0;
  color: #8a98a8;
  font-size: 12px;
}

.initial-loading {
  display: flex;
  min-height: 250px;
  align-items: center;
  justify-content: center;
  color: #718297;
  font-size: 14px;
}

.entry-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 10px;
}

.entry-actions .el-button + .el-button {
  margin-left: 0;
}

.table-scroll {
  width: 100%;
  max-width: 100%;
  overflow-x: auto;
  border-radius: 12px;
}

.bill-entry-table.el-table {
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

.bill-entry-table.el-table :deep(th.el-table__cell) {
  height: 64px;
  border-right-color: #91a6bd;
  border-bottom: 2px solid #91a6bd;
  background: #c8d9ea;
  font-weight: 700;
}

.bill-entry-table.el-table :deep(th.el-table__cell .cell) {
  cursor: default;
}

.bill-entry-table.el-table :deep(td.el-table__cell) {
  height: 70px;
  border-right-color: #a6b7c9;
  border-bottom-color: #a6b7c9;
  background: #f9fbfd;
}

.bill-entry-table.el-table--enable-row-hover :deep(.el-table__body tr:hover > td.el-table__cell) {
  background: #dceafa;
}

.bill-entry-table.el-table :deep(.stay-days-row td.el-table__cell) {
  border-bottom: 2px solid #91a6bd;
  background: #edf5fb;
}

.bill-entry-table :deep(.el-table-fixed-column--left) {
  background: #edf3f8 !important;
}

.item-name {
  color: #253a53;
  font-size: 15px;
}

.person-header {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.person-header span {
  overflow: hidden;
  color: #2d425c;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.entry-avatar {
  flex: 0 0 auto;
  border: 2px solid #fff;
  box-shadow: 0 2px 7px rgba(31, 45, 61, 0.15);
}

.amount-input,
.weight-input,
.stay-days-input {
  width: 100%;
}

.weight-input-wrap,
.stay-days-input-wrap {
  position: relative;
  width: 100%;
}

.weight-input-wrap > span,
.stay-days-input-wrap > span {
  position: absolute;
  top: 50%;
  right: 11px;
  z-index: 2;
  color: #65768b;
  font-size: 13px;
  pointer-events: none;
  transform: translateY(-50%);
}

.weight-input-wrap :deep(.el-input__inner),
.stay-days-input-wrap :deep(.el-input__inner) {
  padding-right: 28px;
}

.stay-days-hint {
  color: #667b8f;
  font-size: 12px;
}

.water-share-hint {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 68px;
  min-height: 28px;
  padding: 0 10px;
  border: 1px solid #b9d3e7;
  border-radius: 14px;
  color: #39739f;
  background: #edf6fc;
  font-size: 12px;
  font-weight: 700;
  white-space: nowrap;
}

.derived-water-amount {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.derived-water-amount strong {
  color: #245f8f;
  font-size: 15px;
}

.derived-water-amount small {
  color: #75869a;
  font-size: 11px;
  white-space: nowrap;
}

.entry-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 18px;
  padding-top: 22px;
}

.entry-footer p {
  margin: 0;
  color: #77879a;
  font-size: 13px;
}

.entry-footer > .el-button {
  min-width: 128px;
}

.default-dialog-description {
  margin: -2px 0 16px;
  color: #68798d;
  font-size: 13px;
}

.default-water-settings {
  display: grid;
  grid-template-columns: 210px minmax(280px, 1fr);
  gap: 18px;
  margin-bottom: 16px;
  padding: 14px;
  border: 1px solid #c4d4e3;
  border-radius: 10px;
  background: #f3f8fc;
}

.default-electricity-settings {
  margin-bottom: 16px;
  padding: 14px;
  border: 1px solid #ccd7e7;
  border-radius: 10px;
  background: #f6f8fc;
}

.default-electricity-payment-list {
  grid-template-columns: repeat(auto-fill, minmax(190px, 210px));
}

.default-table-scroll {
  max-width: 100%;
  overflow-x: auto;
  border-radius: 10px;
}

.default-edit-table.el-table {
  --el-table-border-color: #a6b7c9;
  --el-table-header-bg-color: #d8e5f1;
  --el-table-header-text-color: #2d425c;
  min-width: 100%;
  border-radius: 10px;
}

.default-edit-table.el-table :deep(th.el-table__cell) {
  height: 52px;
  cursor: default;
  background: #d8e5f1;
}

.default-edit-table.el-table :deep(td.el-table__cell) {
  height: 62px;
  background: #f8fafc;
}

.default-person-name {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

@media (max-width: 980px) {
  .utility-record-grid {
    grid-template-columns: 1fr;
  }

  .water-order-fields {
    grid-template-columns: 210px minmax(280px, 1fr);
    gap: 18px;
  }

  .water-price-input-wrap .el-input-number {
    width: 145px;
  }

  .selected-water-days {
    margin-left: 256px;
  }
}

@media (max-width: 760px) {
  .bill-entry-page {
    width: min(100% - 24px, 1120px);
  }

  .bill-page-heading,
  .cost-section-header {
    align-items: flex-start;
  }

  .cost-section-header,
  .entry-actions {
    width: 100%;
  }

  .cost-section-header {
    flex-direction: column;
  }

  .entry-actions {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
  }

  .setting-grid {
    grid-template-columns: 1fr;
    gap: 16px;
  }

  .month-field {
    width: 100%;
    flex-basis: auto;
  }

  .mode-descriptions {
    grid-template-columns: 1fr;
    gap: 5px;
  }

  .mode-control-row {
    flex-direction: column;
    gap: 9px;
  }

  .mode-choice-group {
    width: 100%;
    flex-basis: auto;
  }

  .water-order-heading,
  .electricity-payment-heading,
  .default-electricity-heading {
    flex-direction: column;
    gap: 10px;
  }

  .water-order-summary,
  .electricity-payment-summary {
    align-items: flex-start;
  }

  .water-order-fields,
  .default-water-settings {
    grid-template-columns: 1fr;
  }

  .water-order-panel .order-date-field {
    margin-left: 8px;
  }

  .selected-water-days {
    margin-left: 8px;
  }

  .water-price-input-wrap .el-input-number {
    width: min(180px, calc(100% - 58px));
  }

  .electricity-payment-list {
    grid-template-columns: repeat(auto-fill, minmax(190px, 210px));
  }

  .entry-footer {
    align-items: stretch;
    flex-direction: column;
  }

  .entry-footer p {
    text-align: center;
  }

  .entry-footer > .el-button {
    width: 100%;
  }
}

@media (max-width: 420px) {
  .current-month-badge {
    display: none;
  }

  .month-display strong {
    font-size: 13px;
  }

  .month-display strong small {
    font-size: 11px;
  }
}
</style>
