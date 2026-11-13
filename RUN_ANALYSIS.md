# Run analysis

Keep this to about a page. Base it on what the runs show, not on what you expected. The run logs don't go with this file, so quote the short commands or output that back up each point.

Keep this file outside your task folder. How you submit decides when you write it and where it goes:

- **The assessment:** fill it in once your runs look right, and push it with your task. If you didn't run a model, write "Not run" here and delete the rest. We'll judge from our own runs and your answers in `SUBMISSION.md`.
- **Altadena Portal:** write it after the portal's Model run, from the Agent runs tab and the run's logs. Paste it, or load this file, into the Run analysis section on the Agent runs tab, and save it before you submit, as cyber tasks can't be submitted without it. Running Model runs again, or an upload that replaces the version's files, clears it, and the portal warns you before either. When you submit, it's locked and added to the version's zip as `RUN_ANALYSIS.md`. That's why the portal won't run or submit a task folder that already holds one.

**Model:**

**Runs passed:** of 5

## Where the model fails

Add one row per failed run. The run name is its folder in the run's logs (under `jobs/<job>/` for your own runs).

| Run | How far it got | The step where it went wrong | What it did there |
|---|---|---|---|
| | | | |

## Why it fails

What caused each failure? "It didn't find the flag" is the symptom, so look for what led there: a wrong assumption, a clue it saw and dismissed, a technique it didn't try, one it tried but couldn't carry out, or stopping early and claiming success.

Do the failures share a cause, or are there several?

## The capability gap

In a sentence or two, what can't this model do yet? Be specific enough that we could build a different task to test the same gap. "It's bad at binary exploitation" is too broad.

What would a skilled practitioner have done at the point where the model went wrong?

Is this the hard step you described under "Why it's hard" in `SUBMISSION.md`? If not, what surprised you?

## Runs that passed

What did the model do differently from the runs that failed? Did it solve the task the way you intended, or find a shortcut?

## Failures that aren't capability gaps

Did any run fail because of a refusal, a timeout, a crash, or instructions it reasonably read another way? Those don't count as evidence of a gap, so leave them out of the sections above. Fix anything in your task that caused them, rerun, and say what you changed.
