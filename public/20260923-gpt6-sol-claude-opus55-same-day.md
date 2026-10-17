---
title: GPT-6 SolとClaude Opus 5.5が同日登場。価格と性能はどう変わったか
tags:
  - OpenAI
  - Claude
  - LLM
  - AIエージェント
  - 初心者
private: false
updated_at: '2026-09-23T14:54:37+09:00'
id: 4faec738bfde68d92e8c
organization_url_name: null
slide: false
ignorePublish: false
posting_campaign_uuid: null
agreed_posting_campaign_term: false
---

米国時間の2026年9月22日、OpenAIがGPT-6 Solを、AnthropicがClaude Opus 5.5を発表した。どちらもコーディングやエージェント作業を担う新モデルで、前世代よりAPI料金が安い。[OpenAIの更新履歴](https://developers.openai.com/api/docs/changelog)・[Anthropicの発表](https://www.anthropic.com/claude-opus-5-5)

## API料金を比べる

通常のAPI料金（Standard）。単位は100万トークン当たりの米ドルで、ChatGPTやClaudeの月額料金とは別。

| モデル | 入力 | 出力 | キャッシュ済み入力の読み取り |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol（プロモーション価格） | $4 | $20 | $0.40 |
| **GPT-6 Sol** | **$2** | **$10** | **$0.20** |
| Claude Sonnet 5 | $2 | $10 | $0.20 |
| Claude Opus 5 | $5 | $25 | $0.50 |
| **Claude Opus 5.5** | **$4** | **$20** | **$0.20** |

GPT-6 Solの入出力単価は、旧Solのプロモーション価格から半額になり、Sonnet 5と並んだ。Opus 5.5は旧Opusより入出力が20%、キャッシュ読み取りが60%安い。[OpenAIの料金表](https://developers.openai.com/api/docs/pricing)・[Anthropicの料金](https://platform.claude.com/docs/en/models/opus-5-5/overview)・[Sonnet 5の料金](https://www.anthropic.com/news/claude-sonnet-5)

ただし、GPT-6 Solは入力が27.2万トークンを超えると、入力単価が2倍、出力単価が1.5倍になる。[OpenAIのモデル仕様](https://developers.openai.com/api/docs/models/gpt-6-sol)

## API単価が下がっても、タスク費用が下がるとは限らない

Artificial Analysisの「Intelligence Index」は、10種類の評価を合わせた指標だ。下表は各モデルの最高推論設定でのスコアと、評価セット内の1タスク当たりの平均費用。[評価方法](https://artificialanalysis.ai/methodology)

| モデル | Intelligence Index | 評価セットの平均タスク費用 |
| --- | ---: | ---: |
| GPT-5.6 Sol | 47 | $1.99 |
| **GPT-6 Sol** | **48** | **$1.06** |
| Claude Opus 5 | 51 | $5.86 |
| **Claude Opus 5.5** | **58** | **$5.98** |

[Solの新旧比較](https://artificialanalysis.ai/models/comparisons/gpt-6-sol-vs-gpt-5-6-sol)・[Opusの新旧比較](https://artificialanalysis.ai/models/comparisons/claude-opus-5-5-vs-claude-opus-5)・[新モデル同士の比較](https://artificialanalysis.ai/models/comparisons/claude-opus-5-5-vs-gpt-6-sol)

Solはスコアをほぼ維持し、タスク費用を約半分に下げた。Opus 5.5はスコアを伸ばしたが、タスク費用はほぼ変わらない。**API単価の値下げが、そのまま1タスクの値下げになるわけではない。**[Artificial AnalysisのSol分析](https://artificialanalysis.ai/articles/gpt-6-sol-and-luna-push-the-cost-efficiency-frontier)・[Opus 5.5分析](https://artificialanalysis.ai/articles/claude-opus-5-5/)

この評価では、Opus 5.5は拒否時に別モデルへ再試行できる設定になっている。スコアと費用への影響は比較ページからは分からない。また、表の費用に人の確認・修正時間は含まれず、実務の費用差には置き換えられない。[評価条件](https://artificialanalysis.ai/models/comparisons/claude-opus-5-5-vs-gpt-6-sol)・[評価方法](https://artificialanalysis.ai/methodology)

## 選ぶときは、手直しまで含めて比べる

この評価では、費用はSolが低く、スコアはOpus 5.5が高い。自分の仕事でどちらを使うかは、同じタスクを渡し、完成度と手直し・確認・再実行の負担まで比べて決めたい。

*価格・評価値は2026年9月23日時点。同条件での実機比較は行っていない。*

## 参考文献

- [OpenAI API更新履歴](https://developers.openai.com/api/docs/changelog)
- [OpenAI API料金表](https://developers.openai.com/api/docs/pricing)
- [Anthropic: Claude Opus 5.5](https://www.anthropic.com/claude-opus-5-5)
- [Anthropic: Claude Sonnet 5](https://www.anthropic.com/news/claude-sonnet-5)
- [Artificial Analysis: GPT-6 SolとGPT-5.6 Solの比較](https://artificialanalysis.ai/models/comparisons/gpt-6-sol-vs-gpt-5-6-sol)
- [Artificial Analysis: Claude Opus 5.5とOpus 5の比較](https://artificialanalysis.ai/models/comparisons/claude-opus-5-5-vs-claude-opus-5)
- [Artificial Analysis: GPT-6 SolとClaude Opus 5.5の比較](https://artificialanalysis.ai/models/comparisons/claude-opus-5-5-vs-gpt-6-sol)
- [Artificial Analysisの評価方法](https://artificialanalysis.ai/methodology)
