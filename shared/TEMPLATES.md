# Profit-Corp Communication Templates

## [Scout] PAIN_POINTS.md
```markdown
# Daily Intelligence Report - {{date}}
## Leads
### Lead: {{title}}
- **Problem**: {{description}}
- **Evidence**: {{url}}
- **Urgency**: {{1-10}}
- **Monetization**: {{why_pay}}
```

## [CMO] MARKET_PLAN.md
```markdown
# Market Strategy: {{project_name}}
- **Core USP**: {{unique_selling_point}}
- **Pricing**: {{model_and_price}}
- **Distribution**: {{where_to_find_customers}}
- **Risk Level**: {{low/med/high}}
```

## [Architect] TECH_SPEC.md
```markdown
# Technical Specification: {{project_name}}
- **Stack**: {{frontend/backend/db}}
- **File Tree**:
  ```
  {{directory_structure}}
  ```
- **MVP Features**: {{list}}
- **Build Time**: {{estimated_hours}}
```

## [CEO/Accountant] CORP_CULTURE.md
```markdown
# Corporate Memory
## Entry: {{project_name}} - {{date}}
- **Outcome**: {{success/fail/reset}}
- **Lesson**: {{what_did_we_learn}}
- **Action**: {{strategy_change}}
```

## [CEO/Accountant] KNOWLEDGE_BASE.md Knowledge Card
Append to `shared/KNOWLEDGE_BASE.md` after every major decision:
```markdown
## Card: {{project_or_event_name}} — {{YYYY-MM-DD}}
- **Type**: decision | failure | pattern | milestone
- **Outcome**: {{GO/NO-GO/revenue/veto/archive/milestone}}
- **Lesson**: {{one-line key insight}}
- **Tags**: #{{tag1}} #{{tag2}}
```

