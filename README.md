# Dormitory AA Money Frontend

宿舍 AA 记账前端。目前已完成人员管理页面，支持人员查询、新增、编辑、删除和本地头像选择。

## 技术栈

- Vue 3
- Vite
- Vue Router
- Element Plus
- Axios

## 本地运行

要求 Node.js 18+。

```bash
npm install
npm run dev
```

默认开发地址由 Vite 输出。访问根路径后会自动进入 `/poeples` 人员管理页面。

## 后端配置

复制 `.env.example` 为 `.env` 后可修改：

```dotenv
VITE_API_BASE_URL=/api
VITE_API_PROXY_TARGET=http://localhost:8080
```

开发环境中，前端会将 `/api` 请求代理到后端，并在转发时移除 `/api` 前缀。例如前端请求 `/api/peoples`，后端实际收到 `/peoples`。

## 人员头像

可选择的头像图片放在 `src/assets/avatars` 目录中，支持 PNG、JPG、JPEG、WebP 和 SVG。图片与人员 ID 的关联保存在当前浏览器，不会上传到后端；未选择图片时显示带有昵称首字的纯色头像。

## 构建

```bash
npm run build
npm run preview
```
