# Failure analysis

Keep this to about a page. Base it on what the runs show, not on what you expected. `jobs/` isn't committed, so quote the short commands or output that back up each point.

If you didn't run a model, write "Not run" here and delete the rest. We'll judge from our own runs and your answers in `SUBMISSION.md`.

**Model:**

**Runs passed:** of 5

## Where the model fails

Add one row per failed run. The run name is its folder under `jobs/<job>/`.

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
