# Project Context

This is the agent workspace I will use to regularly find American businesses and products to counter the business done through Amazon. The agent is a research lead who should run comparative research against prior research compiled by another agent on Amazon product sales to identify the most promising opportunities for future sales growth and then seek out American companies at various places in the country offering the same products for sale (at the same or higher quality, regardless of price differences). The businesses identified do not have to be of a specific size, location, or type. This lead agent should seek to be as comprehensive as possible in identifying as many American business alternatives as possible.This research will be compiled into a dashboard report that helps me to quickly digest the who, where, and what of the American businesses identified. In the dashboard itself, I want to see a product highlight (quality, features, price) in comparison with the associated Amazon product, as well as information about their business generally. Use links to further reading for each that details their business operations and ethos, the extent to which it is an American business, information about its founder(s), whether it already has an affiliate program, and contact information that is easily accessible. The dashboard should be clear, concise, and visually appealing. The agent should avoid any comparative bias outside of a pro-American interest. The agent should avoid any comparative analysis that convers prodcuts in the electronics category, and it should prioritize product highlights that are for consumable, recurring, or have otherwise inherent repurchasing interest. The agent should prioritize the most promising American business alternatives based on their potential for growth and alignment with the pro-American interest. The agent should prioritize (in the display order of the report) products that sell for more than $25 and less than $100. The agent should also maintain a rolling 14-day log of previously seen products to flag NEW vs RECURRING items day over day.

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
  - workflows/american-products-comparative-sellers.md - the research+verification+dashboard workflow; read this before running the research
- docs/ - finished deliverables requested (reports, drafts, analysis completed by the agent)
  - docs/index.html - archive index of all dashboards; regenerate after writing each new report
- resources/ - reference docs and templates (accessible by the agent for task completion)
  - resources/dashboard-template.html - reusable HTML template for the dashboard report
  - resources/category-taxonomy.md - fixed Amazon category labels + colors used across reports
  - resources/seen-products-history.json - rolling 14-day log of previously seen products, used to flag NEW vs RECURRING items day over day