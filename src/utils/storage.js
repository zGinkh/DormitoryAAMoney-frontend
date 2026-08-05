const PEOPLE_AVATARS_KEY = 'dormitory-aa-money:people-avatars'

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
