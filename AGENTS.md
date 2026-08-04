# 宿舍 AA 记账前端开发标准

## 1. 项目背景

本项目用于宿舍成员之间按费用项目进行 AA 分摊。常见费用包括水费、电费、话费等。

前端主要负责：

- 管理宿舍人员信息，包括昵称和头像。
- 录入每月账单项目、项目金额、本月天数。
- 根据不同计算模式填写人员权重或入住天数。
- 计算每个人在每个项目中需要支付的金额。
- 展示结果表格和历史账单。

项目面向新手开发，代码应保持简单、清晰、容易维护。

## 2. 技术栈

默认使用：

- Vue 3
- JavaScript
- Vite
- Vue Router
- Element Plus
- Axios

暂不使用：

- TypeScript
- Pinia
- Vuex
- 复杂工程化配置

数据存储约定：

- 人员昵称、历史账单等正式业务数据保存到后端 MySQL。
- 人员头像只保存在本地磁盘。
- 前端不直接连接 MySQL，只通过 Axios 调用后端接口。

## 3. 核心页面

### 3.1 主页面

主页面用于录入账单数据

需要包含：

- 人员昵称和头像。
- 费用项目，例如水费、电费、话费(部分人员不在模式下,需要单独配置水费,具体而言,需要配置一共多少桶水,一桶水默认8块钱,以及水点单的时间)
- 每个项目的总金额。
- 计算模式选择。
- 每个人在每个项目下的权重(所有人权重和为 1)。
- 在“部分人员不在”模式下，每个人还需要填写入住天数。
- “开始计算”按钮。

点击“开始计算”后，先校验输入数据。校验通过后跳转到结果页面。

### 3.2 结果页面

结果页面使用表格展示计算结果。

表格规则：

- 第一行展示人员昵称和头像。
- 后续行展示每个费用项目下，每个人需要支付的钱。
- 最后一行展示每个人的总计应付金额。
- 最后一列显示“总”

金额统一保留两位小数。

### 3.3 人员管理页面

人员管理页面用于管理宿舍成员。

是列表形态,显示人员昵称和头像,后面有两个按钮"编辑"和"删除"
删除人员时必须有确认提示。
左上角有一个按钮"添加"


### 3.4 历史账单页面

历史账单页面用于查看已经计算过的账单。

需要支持：

- 按时间倒序展示历史账单(显示年-月)。
- 查看历史账单详情。
- 删除历史账单。

删除历史账单时必须有确认提示。

## 4. 路由规范

建议路由如下：

```text
/index           主页面
/result          结果页面
/poeples         人员管理页面
/history         历史账单页面
/history/:id     历史账单详情页面
```

页面文件统一放在 `src/views` 目录下。

## 5. 推荐目录结构

```text
src/
  api/              后端接口请求
  assets/           静态资源
  components/       公共组件
  router/           页面路由
  styles/           全局样式
  utils/            工具函数
  views/            页面
```

建议核心文件：

```text
src/views/HomeView.vue
src/views/ResultView.vue
src/views/PeopleManageView.vue
src/views/HistoryView.vue
src/components/PeopleList.vue
src/components/ProjectCostTable.vue
src/components/ResultTable.vue
src/utils/calculate.js
src/utils/storage.js
src/api/peopleApi.js
src/api/billApi.js
```

## 6. 命名规范

文件夹使用小写加横线：

```text
bill-history
poeple-manage
```

Vue 组件使用大驼峰：

```text
PeopleList.vue
ProjectCostTable.vue
ResultTable.vue
```

页面组件以 `View` 结尾：

```text
HomeView.vue
ResultView.vue
PeopleManageView.vue
HistoryView.vue
```

变量和函数使用小驼峰：

```js
const totalAmount = 100
const calculateResult = () => {}
```

常量使用全大写加下划线：

```js
const DEFAULT_ITEMS = ['水费', '电费', '话费']
```

工具函数文件使用小写：

```text
money.js
storage.js
calculate.js
```


## 7. 开发约定

- Vue 文件统一使用 `<script setup>`。
- 主页面只负责录入数据和触发计算。
- 计算逻辑统一放到 `src/utils/calculate.js`。
- 本地头像存储逻辑统一放到 `src/utils/storage.js`。
- 人员昵称和历史账单通过后端接口保存到 MySQL。
- 前端不直接操作 MySQL。
- 默认费用项目包括水费、电费、话费。
- 费用项目允许新增、编辑、删除。
- 删除人员、删除项目、删除历史账单时必须弹出确认提示。
- 页面跳转统一使用 Vue Router。
- 页面 UI 优先使用 Element Plus 组件。

## 8. 表单校验规则

主页面计算前必须校验：

- 至少需要有 1 个宿舍人员。
- 至少需要有 1 个费用项目。
- 项目金额不能为空。
- 项目金额不能小于 0。
- 人员权重不能小于 0。
- 每个费用项目至少需要有 1 个参与分摊的人。
- 权重不能大于 1。

按权重分摊模式还需要校验：

- 每个费用项目的人员权重总和必须大于 0。

按天数和权重分摊模式还需要校验：

- 本月天数不能为空。
- 本月天数必须大于 0。
- 入住天数不能小于 0。
- 入住天数不能大于本月天数。
- 每个费用项目的人员计算权重总和必须大于 0。


## 9. UI 规范

- 主页面以表格形式录入项目金额、人员权重和入住天数。
- 计算模式使用清晰的单选项或切换按钮。
- 选择“全员在住，按权重分摊”时，不显示入住天数输入框。
- 选择“部分人员不在，按天数和权重分摊”时，显示入住天数输入框和本月天数输入框。
- 人员展示必须包含头像和昵称。
- 结果页面使用表格展示，每一列对应一个人员。
- 结果页面最后一行固定为“合计”。
- 人员管理页面使用列表或表格展示人员。
- 历史账单页面按时间倒序展示(年-月)。
- 按钮文案要直接清楚，例如“开始计算”“添加人员”“保存账单”。

## 10. 数据存储与接口约定

人员昵称、历史账单由后端保存到 MySQL 数据库，前端通过接口进行增删改查。

人员头像由前端保存到本地磁盘，不上传到 MySQL。

建议人员管理接口：

```text
GET    /peoples            获取人员列表
GET    /peoples/{id}       根据 ID 获取人员
POST   /peoples            新增人员
PUT    /peoples            编辑人员
DELETE /peoples?id={id}    删除人员
```

建议历史账单接口：

```text
GET    /bills              获取历史账单列表
GET    /bills/{id}         获取账单详情
POST   /bills              保存账单
DELETE /bills?id={id}      删除账单
```
