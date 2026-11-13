# Cyber task assessment

Thanks for your interest in Eval Labs. The next step is to build one cyber task that a frontier AI model fails most of the time, but not every time, and explain why it fails. We use tasks like this to test and train AI models on real security work.

You'll build the task with [Harbor](https://github.com/harbor-framework/harbor), an open-source framework for running AI agents on tasks like this one. Harbor builds your task's containers, runs your solutions and the model against it, and scores each run. You don't need to know it already: this repo includes an example task and a script that runs the checks for you.

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
- **Nothing real.** No real systems, real credentials, live malware or undisclosed vulnerabilities. Use `example.com`, `.test` or `.invalid` for domain names, and documentation or private IP ranges for addresses. A real CVE is fine if it's public and patched. Record its ID in `task.toml` under `[metadata]`, for example `cve = "CVE-2024-12345"`.

## Setup

You need three tools:

- **Docker**, a recent version. Tasks run without internet access, and Harbor can only enforce that if Docker's kernel supports the firewall rules it uses. `check.sh` tells you if yours doesn't.
- **[uv](https://docs.astral.sh/uv/getting-started/installation/)**, to install Harbor.
- **Harbor 0.25.0.** Use exactly this version, because these instructions and `check.sh` were written for it:

```bash
uv tool install harbor==0.25.0
```

Click **Use this template** on GitHub to make your own **private** repo, then clone it. GitHub defaults to Public, so choose Private. Check that everything works:

```bash
./check.sh example-note-share
```

You should see seven `PASS` lines, and a `WARN` that `RUN_ANALYSIS.md` isn't filled in yet. That's expected: you write it after the model runs, and the `WARN` turns into an eighth `PASS`. The first run takes a few minutes while Docker builds the images.

## Build your task

`example-note-share` only shows the format. It's deliberately simple, and we'd expect a frontier model to solve it, so a task at this level wouldn't pass. Your task doesn't have to be web or use a flag, as long as the result can be checked automatically.

Copy `example-note-share` to a new folder, then change what you need. When you're done, delete `example-note-share`, so your repo holds only your task and our files.

| File | What it does |
|---|---|
| `instruction.md` | What the model is told. Write it like a clear brief to a colleague. State what must be true when the work is done, but not where the flaw is or how to fix it |
| `task.toml` | Settings such as timeouts. Add your task type to `keywords`: `offensive` if the model attacks or extracts something, `defensive` if it fixes or hardens something, or `detection` if it analyzes evidence or writes detections |
| `SUBMISSION.md` | Your write-up of the task: answer its six questions. Keep it here, beside `instruction.md`, and never under `environment/`, where the model could read it. It goes out with the task, so leave out your name and contact details |
| `environment/Dockerfile` | The container the model works in |
| `environment/docker-compose.yaml` | Adds the target as a separate service, and puts `main` on its network with `network_mode: "service:target"`, so the model reaches it at `localhost` |
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
- **No internet access.** Keep `network_mode = "no-network"` in `task.toml`. The model and the target share one network because `main` joins the target's, with `network_mode: "service:target"` in `docker-compose.yaml`. So the model reaches the target at `http://localhost:<port>`, and can reach nothing outside the task. You need that line: without it, `localhost` reaches the target under `check.sh` but not on the portal.
- **Give the model enough time.** Keep `[agent] timeout_sec` in `task.toml` at 1800 (30 minutes) or more, and don't set tight `cpus`, `memory_mb` or `storage_mb` limits. A model should fail because the problem is hard, not because it ran out of time or memory. `check.sh` fails if the timeout is lower.
- **Score with automatic checks.** If an AI model grades a written report, the automatic checks must still decide the score, and the grading prompt must treat the report as untrusted.

### Close the shortcuts for your task type

A model will take any shortcut your check allows, so make sure it rejects these:

- **Offensive:** the flag can only be reached through the flaw you intended. Close other routes, such as default passwords, debug endpoints or readable config files.
- **Defensive:** blocking one attack string doesn't pass, because the check tries several variants of the attack. Breaking the service or rejecting every request doesn't pass either, because the check also confirms that legitimate requests still work. If you check that a secret isn't exposed, also catch encoded copies, such as base64.
- **Detection:** flagging everything doesn't pass, because the evidence includes harmless activity that looks suspicious and false alarms count against the score. The evidence must also agree with itself, with every expected answer following from it.

## Test it

Run the checks whenever you change something:

```bash
./check.sh <your-task-folder>
```

Then, if you have an API key, check your task against our rubric, `cyber-rubric.toml`:

```bash
export ANTHROPIC_API_KEY=<your-key>
harbor check -r cyber-rubric.toml -m claude-opus-5-5 <your-task-folder>
```

An AI reviewer reads every file in your task and marks each criterion `pass`, `fail` or `not_applicable`, with a reason. The results are in `jobs/<job>/check_report.json`. Every criterion should be `pass` or `not_applicable`.

Then see how our screening model, Kimi K3.1 Pro, does:

```bash
export OPENROUTER_API_KEY=<your-openrouter-key>
harbor run -p <your-task-folder> -a kimi-code -m openrouter/moonshotai/kimi-k3.1-pro --allow-agent-host openrouter.ai -k 5
harbor view jobs
```

This needs an [OpenRouter](https://openrouter.ai) API key, separate from the Anthropic key the rubric check above uses. `--allow-agent-host` lets the model reach OpenRouter while the task itself stays offline. `-k 5` runs it five times, and your task should pass 1 or 2 of them. `harbor view` shows what the model did on each run, which you need for the run analysis below.

These steps cost money on your own key. If you don't have a key, skip them, because we run our own rubric check and model tests on every submission.

## Analyze the model's runs

A pass rate shows that your task is hard, but not what makes it hard for the model. We want to understand the capability gap: what the model can't do yet, and why.

Once your runs look right, read through each one in `harbor view` and fill in `RUN_ANALYSIS.md`, at the top of your repo, outside your task folder. Keep it to about a page, covering:

1. **Where the model fails:** the step where each failed run went wrong, and how far it got before that.
2. **Why it fails:** the cause behind each failure, such as a wrong assumption or a technique it couldn't carry out, and whether the failures share one.
3. **The capability gap:** the specific thing the model can't do yet, and what a skilled practitioner would have done instead.

You can use an LLM to help you go through the run logs in `jobs/<job>/` and draft this. Check its conclusions against the runs yourself, because we'll hold you to what the file says.

If you didn't run a model, write "Not run" in the file.

On Altadena Portal, you write it from the portal's own Model run instead. See [On Altadena Portal](#on-altadena-portal).

## How we judge it

1. It builds and runs from a clean clone.
2. The reference solution scores 1 every time, and doing nothing scores 0.
3. Your wrong solution scores 0.
4. Every criterion in `cyber-rubric.toml` is `pass` or `not_applicable`.
5. Kimi K3.1 Pro passes 1 or 2 of 5 runs and fails the rest. A refusal doesn't count as a failure.
6. Nothing is cheating its way past the check, and the task isn't a copy.
7. A security reviewer on our side agrees it's realistic.
8. If you ran a model, `RUN_ANALYSIS.md` names a specific capability gap and backs it up with evidence from your runs.

## Submit

1. Fill in your task's `SUBMISSION.md` and the `RUN_ANALYSIS.md` at the top of your repo, then push.
2. Add `aaron-bench` to your repo as a collaborator (**Settings → Collaborators → Add people**).
3. Fill in the form, with your name and the hours you spent: https://tally.so/r/jeZv7J.

Keep your repo private.

### On Altadena Portal

If you submit a task through Altadena Portal:

1. Upload your task folder with its `SUBMISSION.md`. If that file is missing, isn't UTF-8 text, is blank or is over 100 KB, or has a copy under `environment/`, the portal stores the version but blocks Run and Submit until an upload with a fixed `SUBMISSION.md` replaces it. `check.sh` catches all of these. The portal's review checks your answers against the task's files, and flags any name or contact details.
2. After the portal's Model run, write your run analysis from the Agent runs tab and the run's logs. Paste it, or load your `RUN_ANALYSIS.md`, into the Run analysis section on the Agent runs tab, and save it. Cyber tasks can't be submitted without it. Running Model runs again, or an upload that replaces the version's files, clears it, and the portal warns you before either.
3. Submit. Your run analysis is then locked, and added to the version's zip as `RUN_ANALYSIS.md`, in place of any copy at the top of your task folder.

### Passes locally, fails on the portal?

`check.sh` runs your task on your own Docker, while the portal runs it in a sandbox of its own. Four things differ there:

- **Each container has its own `localhost`.** Locally, Harbor puts `main` and your other services on one shared `localhost`, as a side effect of how it blocks the internet. The portal's sandbox runs `docker-compose.yaml` as written, so `main` reaches the target at `localhost` only through the `network_mode: "service:target"` line under `main`. Keep it, with your service's name. Don't give `target` its own `networks` or `network_mode`: locally, that takes it, and `main` with it, out of Harbor's block on the internet. With several services, make one the hub, and have every other service, `main` included, join it with `network_mode: "service:<hub>"`, each on a port of its own. We haven't tested that yet.
- **No internet at all.** Nothing in your task reaches the internet while it runs there, whatever its compose file says. Install what you need when the images are built.
- **Your declared CPU and memory are enforced.** The sandbox is sized from the `cpus` and `memory_mb` in your `task.toml`, shared by all your containers, and a task that declares none gets 1 CPU and 1 GB. Locally, only `main` is limited, and only when you declare a size. So declare what your containers need together, up to 4 CPUs and 16 GB.
- **Time limits.** The portal blocks Run and Submit when `[agent] timeout_sec` is over 7200 (two hours). Your other timeouts hold there too, but the images are built again for each Model run, without your machine's Docker cache, and everything runs on the sandbox's CPUs. Leave room in `build_timeout_sec` and `[verifier] timeout_sec`.

Questions? Reply to the message that brought you here.
