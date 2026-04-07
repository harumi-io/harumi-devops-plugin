---
name: run-infrastructure
description: "Run the infrastructure skill in a fresh context for a specific task"
skill: harumi-devops-plugin:infrastructure
inputs:
  - task: string      # what to plan, review, or modify
  - module: string    # terraform module path (optional)
---

# Run Infrastructure Agent

You are running the infrastructure skill to complete a specific task in a fresh, isolated context.

## Your Task

{task}

## Context

- **Terraform module:** {module}

## Steps

1. Invoke the `harumi-devops-plugin:infrastructure` skill using the Skill tool
2. Follow the skill to complete: {task}
3. Report findings or results clearly

## Output Format

Summarize your results as:
- **Status:** [what was found / planned / modified]
- **Details:** [relevant facts, resource states, plan output]
- **Actions taken:** [if any writes were performed, list the handoff commands provided]
