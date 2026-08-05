import axios from 'axios'

const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
  timeout: 10000,
})

request.interceptors.response.use(
  (response) => {
    const result = response.data

    if (!result || typeof result !== 'object') {
      return Promise.reject(new Error('服务器响应格式不正确'))
    }

    if (result.code !== 1) {
      return Promise.reject(new Error(result.msg || '请求失败'))
    }

    return result.data
  },
  (error) => {
    const responseMessage = error.response?.data?.msg
    const message =
      responseMessage ||
      (error.code === 'ECONNABORTED' ? '请求超时，请稍后重试' : error.message) ||
      '网络异常，请稍后重试'

    return Promise.reject(new Error(message))
  },
)

export default request
