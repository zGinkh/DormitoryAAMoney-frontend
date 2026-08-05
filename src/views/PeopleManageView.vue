<script setup>
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  createPeople,
  deletePeople,
  getPeopleById,
  getPeopleList,
  updatePeople,
} from '../api/peopleApi.js'
import {
  getPeopleAvatars,
  removePeopleAvatar,
  savePeopleAvatar,
} from '../utils/storage.js'

const avatarModules = import.meta.glob('../assets/avatars/*.{png,jpg,jpeg,webp,svg}', {
  eager: true,
  import: 'default',
})

const avatarOptions = Object.entries(avatarModules).map(([path, url]) => {
  const key = path.split('/').pop()
  return {
    key,
    url,
    label: '自定义头像',
  }
})

const avatarUrlMap = new Map(avatarOptions.map((avatar) => [avatar.key, avatar.url]))
const defaultAvatarColors = ['#409eff', '#67c23a', '#e6a23c', '#f56c6c', '#7c6ee6', '#2f9b95']

const peopleList = ref([])
const listLoading = ref(false)
const loadError = ref('')
const dialogVisible = ref(false)
const dialogMode = ref('add')
const formRef = ref()
const submitLoading = ref(false)
const editingId = ref(null)
const deletingId = ref(null)
const peopleAvatars = ref(getPeopleAvatars())

const form = reactive({
  id: null,
  name: '',
  avatarKey: '',
})

const dialogTitle = computed(() =>
  dialogMode.value === 'add' ? '添加人员' : '编辑人员',
)

const selectedAvatarUrl = computed(() => avatarUrlMap.get(form.avatarKey) || '')

const selectedAvatarLabel = computed(() => {
  if (!form.avatarKey) {
    return '默认首字头像'
  }

  return avatarOptions.find((avatar) => avatar.key === form.avatarKey)?.label || '自定义头像'
})

const validateName = (_rule, value, callback) => {
  if (!value || !value.trim()) {
    callback(new Error('请输入人员昵称'))
    return
  }

  callback()
}

const formRules = {
  name: [{ validator: validateName, trigger: ['blur', 'change'] }],
}

const getErrorMessage = (error) => error?.message || '操作失败，请稍后重试'

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

const refreshStoredAvatars = () => {
  peopleAvatars.value = getPeopleAvatars()
}

const loadPeople = async () => {
  listLoading.value = true
  loadError.value = ''

  try {
    const data = await getPeopleList()

    if (!Array.isArray(data)) {
      throw new Error('人员列表数据格式不正确')
    }

    peopleList.value = data
    return data
  } catch (error) {
    loadError.value = getErrorMessage(error)
    return null
  } finally {
    listLoading.value = false
  }
}

const resetForm = () => {
  form.id = null
  form.name = ''
  form.avatarKey = ''
  formRef.value?.clearValidate()
}

const openAddDialog = async () => {
  dialogMode.value = 'add'
  resetForm()
  dialogVisible.value = true
  await nextTick()
  formRef.value?.clearValidate()
}

const openEditDialog = async (row) => {
  if (editingId.value !== null || deletingId.value !== null) {
    return
  }

  editingId.value = row.id

  try {
    const people = await getPeopleById(row.id)

    if (!people || typeof people !== 'object') {
      throw new Error('人员数据格式不正确')
    }

    dialogMode.value = 'edit'
    form.id = people.id
    form.name = people.name || ''
    form.avatarKey = peopleAvatars.value[String(people.id)] || ''
    dialogVisible.value = true
    await nextTick()
    formRef.value?.clearValidate()
  } catch (error) {
    ElMessage.error(getErrorMessage(error))
  } finally {
    editingId.value = null
  }
}

const submitForm = async () => {
  if (submitLoading.value) {
    return
  }

  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) {
    return
  }

  submitLoading.value = true
  const name = form.name.trim()
  const avatarKey = form.avatarKey

  try {
    if (dialogMode.value === 'add') {
      const existingPeopleIds = new Set(peopleList.value.map((people) => people.id))
      await createPeople({ name })
      const latestPeople = await loadPeople()

      if (avatarKey && latestPeople) {
        const newPeople = latestPeople
          .filter((people) => !existingPeopleIds.has(people.id) && people.name === name)
          .sort((first, second) => second.id - first.id)

        if (newPeople.length) {
          savePeopleAvatar(newPeople[0].id, avatarKey)
          refreshStoredAvatars()
        } else {
          ElMessage.warning('人员已添加，但未能关联所选头像')
        }
      }

      ElMessage.success('人员添加成功')
    } else {
      await updatePeople({ id: form.id, name })
      savePeopleAvatar(form.id, avatarKey)
      refreshStoredAvatars()
      ElMessage.success('人员信息修改成功')
      await loadPeople()
    }

    dialogVisible.value = false
  } catch (error) {
    ElMessage.error(getErrorMessage(error))
  } finally {
    submitLoading.value = false
  }
}

const handleDelete = async (row) => {
  if (deletingId.value !== null || editingId.value !== null) {
    return
  }

  try {
    await ElMessageBox.confirm(
      `确定要删除人员“${row.name}”吗？删除后无法恢复。`,
      '删除确认',
      {
        confirmButtonText: '确认删除',
        cancelButtonText: '取消',
        type: 'warning',
      },
    )

    deletingId.value = row.id
    await deletePeople(row.id)
    removePeopleAvatar(row.id)
    refreshStoredAvatars()
    ElMessage.success('人员删除成功')
    await loadPeople()
  } catch (error) {
    if (error === 'cancel' || error === 'close') {
      return
    }

    ElMessage.error(getErrorMessage(error))
  } finally {
    deletingId.value = null
  }
}

const handleDialogClosed = () => {
  resetForm()
}

onMounted(loadPeople)
</script>

<template>
  <main class="page-shell">
    <header class="page-heading">
      <div>
        <p class="page-eyebrow">People Management</p>
        <h1>人员管理</h1>
        <p class="page-description">维护参与宿舍账单分摊的人员信息。</p>
      </div>
      <el-tag class="page-tag" effect="dark" round>{{ peopleList.length }} 位人员</el-tag>
    </header>

    <section class="content-card">
      <div class="section-header">
        <div>
          <h2>人员管理</h2>
          <p>维护参与账单分摊的人员信息</p>
        </div>
        <el-button type="primary" @click="openAddDialog">添加人员</el-button>
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
          <el-button link type="primary" :loading="listLoading" @click="loadPeople">
            重新加载
          </el-button>
        </template>
      </el-alert>

      <el-table
        class="people-table"
        v-loading="listLoading"
        :data="peopleList"
        row-key="id"
        empty-text="暂无人员，请点击“添加人员”创建"
        border
        stripe
      >
        <el-table-column label="编号" width="120">
          <template #default="{ $index }">
            {{ $index + 1 }}
          </template>
        </el-table-column>
        <el-table-column label="头像" width="100">
          <template #default="{ row }">
            <el-avatar
              class="people-avatar"
              :size="44"
              :src="getAvatarUrl(row.id)"
              :style="getAvatarUrl(row.id) ? undefined : { backgroundColor: getDefaultAvatarColor(row.name) }"
            >
              {{ getNameInitial(row.name) }}
            </el-avatar>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="昵称" min-width="220">
          <template #default="{ row }">
            <span class="people-name">{{ row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="190" align="right">
          <template #default="{ row }">
            <el-button
              link
              type="primary"
              :loading="editingId === row.id"
              :disabled="deletingId !== null"
              @click="openEditDialog(row)"
            >
              编辑
            </el-button>
            <el-button
              link
              type="danger"
              :loading="deletingId === row.id"
              :disabled="editingId !== null"
              @click="handleDelete(row)"
            >
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <p v-if="!listLoading && !loadError && peopleList.length" class="table-summary">
        共 {{ peopleList.length }} 位人员
      </p>
    </section>

    <el-dialog
      v-model="dialogVisible"
      :title="dialogTitle"
      width="min(440px, calc(100vw - 32px))"
      :close-on-click-modal="!submitLoading"
      :close-on-press-escape="!submitLoading"
      :show-close="!submitLoading"
      @closed="handleDialogClosed"
    >
      <el-form
        ref="formRef"
        :model="form"
        :rules="formRules"
        label-position="top"
        @submit.prevent="submitForm"
      >
        <el-form-item label="人员昵称" prop="name">
          <el-input
            v-model="form.name"
            placeholder="请输入人员昵称"
            clearable
            autofocus
            @keyup.enter="submitForm"
          />
        </el-form-item>
        <el-form-item label="头像（可选）">
          <div class="avatar-field">
            <div
              class="avatar-main-preview"
              :style="selectedAvatarUrl ? undefined : { backgroundColor: getDefaultAvatarColor(form.name) }"
            >
              <img
                v-if="selectedAvatarUrl"
                :src="selectedAvatarUrl"
                :alt="selectedAvatarLabel"
              />
              <span v-else>{{ getNameInitial(form.name) }}</span>
            </div>

            <div class="avatar-selection">
              <p class="avatar-selection-title">{{ selectedAvatarLabel }}</p>
              <div class="avatar-choice-list">
                <button
                  type="button"
                  class="avatar-choice avatar-choice--default"
                  :class="{ 'is-selected': form.avatarKey === '' }"
                  :style="{ backgroundColor: getDefaultAvatarColor(form.name) }"
                  aria-label="使用默认首字头像"
                  title="默认首字头像"
                  @click="form.avatarKey = ''"
                >
                  {{ getNameInitial(form.name) }}
                  <span v-if="form.avatarKey === ''" class="avatar-check">✓</span>
                </button>
                <button
                  v-for="avatar in avatarOptions"
                  :key="avatar.key"
                  type="button"
                  class="avatar-choice"
                  :class="{ 'is-selected': form.avatarKey === avatar.key }"
                  :aria-label="`选择${avatar.label}`"
                  :title="avatar.label"
                  @click="form.avatarKey = avatar.key"
                >
                  <img :src="avatar.url" :alt="avatar.label" />
                  <span v-if="form.avatarKey === avatar.key" class="avatar-check">✓</span>
                </button>
              </div>
              <p class="avatar-help">未选择图片时，将使用昵称首字生成头像。</p>
            </div>
          </div>
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button :disabled="submitLoading" @click="dialogVisible = false">
          取消
        </el-button>
        <el-button type="primary" :loading="submitLoading" @click="submitForm">
          {{ dialogMode === 'add' ? '确认添加' : '保存修改' }}
        </el-button>
      </template>
    </el-dialog>
  </main>
</template>
