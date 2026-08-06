<template>
  <main class="page-shell guide-page">
    <header class="page-heading">
      <div>
        <p class="page-eyebrow">User Guide</p>
        <h1>使用说明</h1>
        <p class="page-description">从人员设置到账单保存，快速了解宿舍 AA 记账的完整流程。</p>
      </div>
      <el-tag class="page-tag" effect="dark" round>新手指南</el-tag>
    </header>

    <section class="content-card quick-start-card">
      <div class="section-header">
        <div>
          <h2>快速开始</h2>
          <p>依次完成以下步骤，即可生成一份宿舍账单</p>
        </div>
      </div>

      <ol class="guide-steps">
        <li>
          <span class="step-number">1</span>
          <div>
            <h3>添加宿舍成员</h3>
            <p>进入“人员管理”，点击“添加人员”，填写昵称并选择头像。人员发生变化时，也可以在这里编辑或删除。</p>
          </div>
        </li>
        <li>
          <span class="step-number">2</span>
          <div>
            <h3>选择计算模式</h3>
            <p>进入“账单录入”，确认账单月份，再根据本月人员是否全程在住选择合适的计算模式。</p>
          </div>
        </li>
        <li>
          <span class="step-number">3</span>
          <div>
            <h3>填写费用数据</h3>
            <p>录入各项费用、人员权重以及需要的入住或缴费日期。填写完成后，点击“开始计算”。</p>
          </div>
        </li>
        <li>
          <span class="step-number">4</span>
          <div>
            <h3>核对并保存</h3>
            <p>在计算结果页核对每个人的分摊金额，确认无误后点击“保存账单”，账单会出现在“历史账单”中。</p>
          </div>
        </li>
      </ol>
    </section>

    <section class="guide-grid">
      <article class="content-card guide-card">
        <div class="guide-card-title">
          <span class="guide-card-icon">全</span>
          <div>
            <h2>全员在住</h2>
            <p>适合所有成员整月在住宿舍的情况</p>
          </div>
        </div>
        <ul>
          <li>填写水费、电费、话费等项目的总金额。</li>
          <li>为每项费用填写人员权重，权重使用 0～100 的整数。</li>
          <li>每项费用的人员权重合计必须等于 100%。</li>
          <li>不参与某项费用的人员，将该项权重填写为 0。</li>
        </ul>
      </article>

      <article class="content-card guide-card">
        <div class="guide-card-title">
          <span class="guide-card-icon">缺</span>
          <div>
            <h2>部分人员不在</h2>
            <p>适合有人月中离开或未住满整月的情况</p>
          </div>
        </div>
        <ul>
          <li>填写每个人从月初开始计算的实际入住天数。</li>
          <li>订水记录中，每选择一个日期代表当天订购 1 桶水。</li>
          <li>填写每桶水单价；水费会根据桶数自动计算。</li>
          <li>按实际支付日期录入电费金额；水费和电费按当天在住人员平均分摊。</li>
          <li>话费会结合人员权重和入住天数进行计算。</li>
        </ul>
      </article>
    </section>

    <section class="content-card history-help-card">
      <div class="section-header">
        <div>
          <h2>历史账单与注意事项</h2>
          <p>保存后的账单可长期查看和管理</p>
        </div>
      </div>

      <div class="tip-list">
        <div class="tip-item">
          <strong>查看账单</strong>
          <span>历史账单按年月从新到旧排列，点击“查看详情”可查看各项目及每位成员的应付金额。</span>
        </div>
        <div class="tip-item">
          <strong>默认数据</strong>
          <span>常用金额和权重可以保存为默认数据；两种计算模式的默认数据会分别保存。</span>
        </div>
        <div class="tip-item is-warning">
          <strong>谨慎删除</strong>
          <span>删除人员或历史账单前，系统会再次确认。删除后的历史账单无法恢复。</span>
        </div>
      </div>
    </section>

  </main>
</template>

<style scoped>
.guide-page {
  max-width: 1080px;
}

.guide-steps {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.guide-steps li {
  display: flex;
  gap: 14px;
  padding: 18px;
  border: 1px solid #c7d5e4;
  border-radius: 14px;
  background: #f8fbfe;
}

.step-number {
  display: flex;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  align-items: center;
  justify-content: center;
  border-radius: 11px;
  color: #fff;
  background: linear-gradient(145deg, #4f9cdd, #3473ad);
  box-shadow: 0 5px 12px rgba(52, 120, 181, 0.22);
  font-weight: 700;
}

.guide-steps h3,
.guide-steps p,
.guide-card h2,
.guide-card p {
  margin: 0;
}

.guide-steps h3 {
  color: #253a53;
  font-size: 16px;
}

.guide-steps p {
  margin-top: 7px;
  color: #65768b;
  font-size: 13px;
  line-height: 1.7;
}

.guide-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 22px;
  margin-top: 22px;
}

.guide-card {
  padding-bottom: 26px;
}

.guide-card-title {
  display: flex;
  align-items: center;
  gap: 14px;
}

.guide-card-icon {
  display: flex;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  align-items: center;
  justify-content: center;
  border-radius: 13px;
  color: #fff;
  background: #3478b5;
  font-size: 16px;
  font-weight: 700;
}

.guide-card h2 {
  color: #21344d;
  font-size: 19px;
}

.guide-card p {
  margin-top: 5px;
  color: #748397;
  font-size: 13px;
}

.guide-card ul {
  margin: 20px 0 0;
  padding-left: 21px;
  color: #53677e;
}

.guide-card li {
  padding-left: 4px;
  line-height: 1.8;
}

.guide-card li + li {
  margin-top: 5px;
}

.history-help-card {
  margin-top: 22px;
}

.tip-list {
  display: grid;
  gap: 11px;
}

.tip-item {
  display: grid;
  grid-template-columns: 92px minmax(0, 1fr);
  gap: 14px;
  padding: 14px 16px;
  border: 1px solid #c7d5e4;
  border-radius: 12px;
  color: #5d7087;
  background: #f8fbfe;
  font-size: 13px;
  line-height: 1.65;
}

.tip-item strong {
  color: #2e5f8d;
}

.tip-item.is-warning {
  border-color: #e2cfae;
  background: #fff9ef;
}

.tip-item.is-warning strong {
  color: #9a6a20;
}

@media (max-width: 720px) {
  .guide-steps,
  .guide-grid {
    grid-template-columns: 1fr;
  }

  .guide-grid {
    gap: 16px;
    margin-top: 16px;
  }

  .history-help-card {
    margin-top: 16px;
  }

  .tip-item {
    grid-template-columns: 1fr;
    gap: 3px;
  }
}
</style>
