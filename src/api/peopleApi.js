import request from './request.js'

export const getPeopleList = () => request.get('/peoples')

export const getPeopleById = (id) => request.get(`/peoples/${id}`)

export const createPeople = (people) => request.post('/peoples', people)

export const updatePeople = (people) => request.put('/peoples', people)

export const deletePeople = (id) =>
  request.delete('/peoples', {
    params: { id },
  })
