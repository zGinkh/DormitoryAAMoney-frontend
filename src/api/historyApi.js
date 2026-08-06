import request from './request.js'

export const getHistoryList = () => request.get('/history')

export const getHistoryDetail = (id) => request.get(`/history/${id}`)

export const saveHistoryBill = (calculationResult) =>
  request.post('/history', calculationResult)

export const deleteHistoryBill = (id) =>
  request.delete('/history', {
    params: { id },
  })
