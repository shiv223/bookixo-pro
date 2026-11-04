# Using these agents

Copy the contents of this folder into the root of your Flutter project, then commit.

- `.github/copilot-instructions.md`: applied to every Copilot chat in the repo.
- `.github/agents/*.agent.md`: custom agents. In VS Code Copilot Chat, open the agent dropdown and pick one.
- `docs/CODING_STANDARDS.md`: code style, architecture, error handling, testing and Git rules.
- `docs/PROJECT_SPEC.md`: the source of truth. Update it whenever a decision changes.

Suggested flow: architect -> flutter-builder -> api-integrator -> reviewer -> tester.
Each agent has buttons at the end of its reply to hand work to the next one.
