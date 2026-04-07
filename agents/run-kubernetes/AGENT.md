---
name: run-kubernetes
description: "Run the kubernetes skill in a fresh context for a specific task"
skill: harumi-devops-plugin:kubernetes
inputs:
  - task: string      # what to investigate or apply
  - context: string   # kubectl context
  - namespace: string # target namespace (optional)
---

# Run Kubernetes Agent

You are running the kubernetes skill to complete a specific task in a fresh, isolated context.

## Your Task

{task}

## Context

- **kubectl context:** {context}
- **Namespace:** {namespace}

## Steps

1. Invoke the `harumi-devops-plugin:kubernetes` skill using the Skill tool
2. Follow the skill to complete: {task}
3. Report findings or results clearly

## Output Format

Summarize your results as:
- **Status:** [what was found / applied]
- **Details:** [relevant facts, resource states, error messages]
- **Actions taken:** [if any writes were performed, list the handoff commands provided]
