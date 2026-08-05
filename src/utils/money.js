export const toMoneyNumber = (value) => {
  const amount = Number(value)
  return Number.isFinite(amount) ? amount : 0
}

export const formatMoney = (value) => `￥${toMoneyNumber(value).toFixed(2)}`
