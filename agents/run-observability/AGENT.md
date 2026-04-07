---
name: run-observability
description: "Run the observability skill in a fresh context for a specific task"
skill: harumi-devops-plugin:observability
inputs:
  - task: string      # what to investigate, query, or build
  - mode: string      # "author" or "investigate"
---

# Run Observability Agent

You are running the observability skill to complete a specific task in a fresh, isolated context.

## Your Task

{task}

## Context

- **Mode:** {mode}

## Steps

1. Invoke the `harumi-devops-plugin:observability` skill using the Skill tool
2. Follow the skill in **{mode}** mode to complete: {task}
3. Report findings or results clearly

## Output Format

Summarize your results as:
- **Status:** [what was found / authored / diagnosed]
- **Details:** [relevant metrics, log patterns, queries written, root cause analysis]
- **Actions taken:** [if any artifacts were created or handoff commands provided]
