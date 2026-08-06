const PEOPLE_AVATARS_KEY = 'dormitory-aa-money:people-avatars'
const CALCULATION_RESULT_KEY = 'dormitory-aa-money:calculation-result'

export const getPeopleAvatars = () => {
  try {
    const value = localStorage.getItem(PEOPLE_AVATARS_KEY)
    return value ? JSON.parse(value) : {}
  } catch {
    return {}
  }
}

export const savePeopleAvatar = (peopleId, avatarKey) => {
  const avatars = getPeopleAvatars()

  if (avatarKey) {
    avatars[String(peopleId)] = avatarKey
  } else {
    delete avatars[String(peopleId)]
  }

  localStorage.setItem(PEOPLE_AVATARS_KEY, JSON.stringify(avatars))
}

export const removePeopleAvatar = (peopleId) => {
  savePeopleAvatar(peopleId, '')
}

export const saveCalculationResult = (calculationResult, peopleList) => {
  sessionStorage.setItem(
    CALCULATION_RESULT_KEY,
    JSON.stringify({
      calculationResult,
      peopleList,
      isSaved: false,
    }),
  )
}

export const getCalculationResult = () => {
  try {
    const value = sessionStorage.getItem(CALCULATION_RESULT_KEY)
    return value ? JSON.parse(value) : null
  } catch {
    return null
  }
}

export const markCalculationResultSaved = () => {
  try {
    const storedData = getCalculationResult()
    if (!storedData) {
      return
    }

    sessionStorage.setItem(
      CALCULATION_RESULT_KEY,
      JSON.stringify({
        ...storedData,
        isSaved: true,
      }),
    )
  } catch {
    // 保存状态失败不影响账单本身已经写入后端
  }
}
