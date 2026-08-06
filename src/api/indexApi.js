import request from './request.js'

export const getIndexPeople = () => request.get('/index')

export const submitBillEntry = (billEntry) => request.post('/index', billEntry)
