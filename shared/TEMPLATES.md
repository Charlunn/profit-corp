# Profit-Corp Communication Templates
[English] | [简体中文](TEMPLATES_CN.md)

## [Scout] PAIN_POINTS.md
```markdown
# Daily Intelligence Report - {{date}}
## Leads (Scoring-Ready)
### Lead: {{title}}
- **Idea ID**: {{idea_id}}
- **Problem**: {{description}}
- **Target User**: {{target_user}}
- **Evidence Links**: {{url_list}}
- **Latest Evidence Age (hours)**: {{hours}}
- **Urgency Pain (0-10)**: {{score}}
- **Estimated MVP Hours**: {{hours}}
- **Monetization Signal (0-10)**: {{score}}
- **Competition Signal (0-10)**: {{score}}
- **Confidence (0-10)**: {{score}}
- **Notes**: {{assumptions_or_risks}}
```

## [CMO] Idea Scorecard (Quantitative)
```markdown
### Scorecard: {{idea_id}} - {{title}}
- **UrgencyPain (0-10, weight 25%)**: {{score}}
- **OneDayFeasibility (0-10, weight 25%)**: {{score}}
- **MonetizationSpeed (0-10, weight 20%)**: {{score}}
- **EvidenceStrength (0-10, weight 15%)**: {{score}}
- **Recency (0-10, weight 10%)**: {{score}}
- **CompetitionGap (0-10, weight 5%)**: {{score}}
- **TotalScore (0-100)**: {{total}}
- **Formula**: `Total = 10 * (0.25*UrgencyPain + 0.25*OneDayFeasibility + 0.20*MonetizationSpeed + 0.15*EvidenceStrength + 0.10*Recency + 0.05*CompetitionGap)`
- **Hard Filters Passed**: {{yes_no}}
```

## [CEO] Top3 Ranking Output
```markdown
## Top 3 Ranked Micro-SaaS Ideas (last 48h)
| Rank | idea_id | Idea | TotalScore/100 | Urgency | Feasibility | Monetization | Evidence | Recency | Competition | MVP Hours |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | {{idea_id_1}} | {{idea_1}} | {{score_1}} | {{u1}} | {{f1}} | {{m1}} | {{e1}} | {{r1}} | {{c1}} | {{h1}} |
| 2 | {{idea_id_2}} | {{idea_2}} | {{score_2}} | {{u2}} | {{f2}} | {{m2}} | {{e2}} | {{r2}} | {{c2}} | {{h2}} |
| 3 | {{idea_id_3}} | {{idea_3}} | {{score_3}} | {{u3}} | {{f3}} | {{m3}} | {{e3}} | {{r3}} | {{c3}} | {{h3}} |

**Recommended**: {{idea_id_recommended}} — {{one_line_why}}

Reply with `1/2/3` or `idea_id` to continue automatically.
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

