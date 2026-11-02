# Cyber task assessment

Thanks for your interest in Eval Labs. The next step is to build one cyber task that a frontier AI model can't solve. We use tasks like this to test and train AI models on real security work.

If you pass, we'll onboard you.

## What we're looking for

Build one original task based on real security work, in any area: web, binary exploitation, reverse engineering, crypto, forensics, detection, incident response or anything else you know well.

A good task:

- Reflects something a skilled practitioner would actually do
- Has one clear, checkable result
- Can be solved, and your reference solution proves it
- Makes a frontier model fail because the problem is hard, not because the instructions are vague or the setup is broken

## Rules

- **Original work only.** Take inspiration from benchmarks like [CyberStrike](https://huggingface.co/datasets/TuringFrontierResearchLab/CyberStrike) for the kind of task we're after, but don't copy a public CTF challenge or benchmark task. Tell us about any public sources you drew on.
- **Self-contained.** Everything runs in Docker, and targets live inside the task.
- **Nothing real.** No real systems, real credentials or undisclosed vulnerabilities.

## Setup

You need Docker (a recent version) and [uv](https://docs.astral.sh/uv/getting-started/installation/).

```bash
uv tool install harbor==0.25.0
```

Click **Use this template** on GitHub to make your own **private** repo, then clone it. GitHub defaults to Public, so choose Private. Check that everything works:

```bash
./check.sh example-note-share
```

You should see four `PASS` lines. The first run takes a few minutes while Docker builds the images.

## Build your task

`example-note-share` only shows the format. It's deliberately simple, and we'd expect a frontier model to solve it, so a task at this level wouldn't pass. Your task doesn't have to be web or use a flag, as long as the result can be checked automatically.

Copy `example-note-share` to a new folder, then change what you need. When you're done, delete `example-note-share`, so your repo holds only your task.

| File | What it does |
|---|---|
| `instruction.md` | What the model is told. Write it like a clear brief to a colleague |
| `task.toml` | Settings such as timeouts |
| `environment/Dockerfile` | The container the model works in |
| `environment/docker-compose.yaml` | Adds the target as a separate service |
| `environment/target/` | The target itself. The model can't see these files, only the running service |
| `solution/solve.sh` | Your reference solution. It must earn a score of 1 |
| `wrong_solution/solve.sh` | A tempting wrong approach. It must earn a score of 0 |
| `tests/test.sh` | The check. It writes `1` or `0` to `/logs/verifier/reward.txt` |

### Keep the check honest

The example does all of this, so keep these parts of its structure:

- **Run the model as a non-root user** (`user = "agent"` in `task.toml`).
- **Keep secrets out of the model's container.** A flag on its disk can simply be read, so put secrets in the target service.
- **Keep answers out of the check.** Store a hash, not the flag itself, in `tests/`.
- **Have the model write its answer to `/logs/artifacts/`.** The check runs in a separate container and reads it from there.
- **Assume the model has internet access.** It may search for your task, which is another reason to keep it original.

## Test it

Run the checks whenever you change something:

```bash
./check.sh <your-task-folder>
```

Then, if you have an API key, see how a frontier model does:

```bash
export ANTHROPIC_API_KEY=<your-key>
harbor run -p <your-task-folder> -a claude-code -m anthropic/claude-opus-5-5 -k 5
harbor view jobs
```

`-k 5` runs it five times. `harbor view` shows what the model did on each run. These runs cost money on your own key. If you don't have a key, skip this step, because we run our own model tests on every submission.

## How we judge it

1. It builds and runs from a clean clone.
2. The reference solution scores 1, and doing nothing scores 0.
3. Your wrong solution scores 0.
4. Frontier models fail most of 5 runs. A refusal doesn't count as a failure.
5. Nothing is cheating its way past the check, and the task isn't a copy.
6. A security reviewer on our side agrees it's realistic.

## Submit

1. Fill in `SUBMISSION.md` and push.
2. Add `aaron-bench` to your repo as a collaborator (**Settings → Collaborators → Add people**).
3. Fill in the form: https://tally.so/r/jeZv7J.

Keep your repo private.

Questions? Reply to the message that brought you here.
