# Profit-Corp 通讯模板
[简体中文] | [English](TEMPLATES.md)

## [Scout] PAIN_POINTS.md (痛点报告)
```markdown
# 每日情报报告 - {{date}}
## 机会
### 机会: {{title}}
- **问题**: {{description}}
- **证据**: {{url}}
- **紧急程度**: {{1-10}}
- **变现能力**: {{why_pay}}
```

## [CMO] MARKET_PLAN.md (市场计划)
```markdown
# 市场策略: {{project_name}}
- **核心卖点 (USP)**: {{unique_selling_point}}
- **定价**: {{model_and_price}}
- **分发**: {{where_to_find_customers}}
- **风险等级**: {{low/med/high}}
```

## [Architect] TECH_SPEC.md (技术规范)
```markdown
# 技术规范: {{project_name}}
- **技术栈**: {{frontend/backend/db}}
- **文件树**:
  ```
  {{directory_structure}}
  ```
- **MVP 功能**: {{list}}
- **构建时长**: {{estimated_hours}}
```

## [CEO/Accountant] CORP_CULTURE.md (企业记忆条目)
```markdown
# 企业记忆
## 条目: {{project_name}} - {{date}}
- **结果**: {{success/fail/reset}}
- **教训**: {{what_did_we_learn}}
- **动作**: {{strategy_change}}
```

## [CEO/Accountant] KNOWLEDGE_BASE.md 知识卡片
主要决策后追加至 `shared/KNOWLEDGE_BASE.md`：
```markdown
## 卡片：{{project_or_event_name}} — {{YYYY-MM-DD}}
- **类型**: decision | failure | pattern | milestone
- **结果**: {{GO/NO-GO/revenue/veto/archive/milestone}}
- **教训**: {{one-line key insight}}
- **标签**: #{{tag1}} #{{tag2}}
```
