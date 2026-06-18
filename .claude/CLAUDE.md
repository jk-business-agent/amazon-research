# Project Context

This is the agent workspace I will use to regularly run research on the top selling products for American consumers through Amazon on any given day. This research will be compiled into a dashboard report that helps me to quickly digest what was found and to understand what's hot, why it's selling well, what area of the market it's in, and where future growth is projected to be.

# About Me - Your Creator

I am an educator, a writer, and a business owner. I write regularly on the topic of economic growth, and I'm deeply invested in promoting future business in America. As a writer and educator, I care deeply about accuracy, utility, and concise, efficacious communication. In order to teach something, I need to understand that thing in deep and nuanced ways. But I am also stretched between many pulls for my time. I want to leverage AI in ways that will make me more productive at what I do.

# Rules

- Before touching ANY file, answer:
    1. Is the task unambiguous?
    2. Is it trivial? (< 3 steps, no architectural decisions, single file)
    If BOTH are true → proceed. If EITHER is false → enter plan mode first; write plan to tasks/todo.md.
- Never read from a file without opening it first. No speculation.
- Never hardcode secrets, API keys, or tokens — environment variables only.
- Never commit .env files or credentials.
- Before claiming any task is complete: run tests fresh, read full output, verify.
- If requirements are unclear or if you find conflicting goals, stop and ask a clarifying question before proceeding.
- Start with the smallest working change. Avoid speculative features or broad 'cleanups' not explicitly requested.
- Turn every task into something you can verify. Where possible, write and run tests to reproduce bugs when planning before attempting a fix, and verify it passes.
- When running commands to create files, ask first if it is an "Output File". If the answer is yes, save it to the docs folder.
    - All docs, reports, analysis, etc. created by agent tasks and saved to docs/ should be maximally organized, clear, readable, and useful. Agent should avoid falling into templated production habits not explicitly requested in instructions or the prompt.

# Agent Structure Within The Project

- workflows/ - workflow instruction files (plain English instructions for agentic tasks)
  - workflows/daily-amazon-top-sellers.md - the daily research+verification+dashboard workflow; read this before running the daily research
- docs/ - finished deliverables requested (reports, drafts, analysis completed by the agent)
  - docs/index.html - archive index of all daily dashboards; regenerate after writing each new report
- resources/ - reference docs and templates (accessible by the agent for task completion)
  - resources/dashboard-template.html - reusable HTML template for the daily dashboard
  - resources/category-taxonomy.md - fixed Amazon category labels + colors used across reports
  - resources/seen-products-history.json - rolling 14-day log of previously seen products, used to flag NEW vs RECURRING items day over day