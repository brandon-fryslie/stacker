# Stacker Streaming Bug Root Cause Analysis

## The Problem

18 out of 41 tests are timing out when waiting for task output. Tasks start successfully, but their output never reaches the test's `wait_for` expectations.

## Root Cause: Dual-Piping Race Condition

The bug exists in ALL Node.js versions, but became more apparent in newer versions due to:
1. Faster process spawning
2. More efficient stream handling
3. echo commands completing before stream setup

### The Sequence

```
1. run_cmd() spawns process via mexpect.spawn
   └─> Creates: mproc.stdout (transformed stream)

2. run_cmd() IMMEDIATELY calls prefix_pipe_output()
   └─> Pipes: mproc.stdout -> prefix_transform -> process.stdout
   └─> Stream enters FLOWING MODE
   └─> Data starts being consumed

3. start_foreground_task() calls mproc.on_data(wait_for)
   └─> Tries to pipe: mproc.stdout -> callback_transform
   └─> BUT mproc.stdout is already flowing!
   └─> Any data that already flowed is LOST

4. Fast commands like 'echo' finish before step 3
   └─> Their output went to prefix_transform
   └─> callback_transform never sees it
   └─> wait_for never matches
   └─> Test times out
```

### Proof

```javascript
const proc = spawn('bash', ['-c', 'echo Fast']);

// First consumer (like prefix_pipe_output)
proc.stdout.pipe(transform1);  // Gets all data

// Tiny delay (microseconds in real code)
setTimeout(() => {
  // Second consumer (like on_data/wait_for)  
  proc.stdout.pipe(transform2);  // MISSES Fast, only gets later data
}, 1);
```

## Why This Wasn't a Problem Before

In Node 0.10 (when stacker was written):
- Process spawning was slower
- Stream buffering behaved differently  
- echo had enough latency that both pipes were set up before output

In Node 22:
- Processes spawn faster
- Streams are more efficient
- echo outputs immediately, before second pipe is ready

## The Fix

**Don't pipe the same Readable stream to multiple consumers with sequential setup.**

### Solution Options

1. **PassThrough Fan-Out** (BEST)
   - Insert a PassThrough stream after newline transform
   - Both prefix and callback tap into the PassThrough
   - PassThrough buffers and broadcasts to all consumers

2. **Conditional Piping**
   - Only call prefix_pipe_output if task has no wait_for
   - Skip display piping when pattern matching is needed

3. **Event-Based Instead of Pipe-Based**
   - Use 'data' events for one consumer instead of .pipe()
   - Allows multiple listeners without race condition

4. **Setup All Pipes Before Spawn**
   - Pass both callbacks to run_cmd
   - Set up all pipes before closing stdin
   - Requires architecture refactor

### Recommended Fix

Use PassThrough fan-out in mexpect.spawn:

```coffeescript
spawn: (opt) =>
  # ... existing spawn code ...
  
  # Create PassThrough for fan-out
  stdoutPassThrough = new stream.PassThrough()
  stderrPassThrough = new stream.PassThrough()
  
  # Pipe raw streams through transforms to PassThrough
  @proc.stdout
    .pipe(create_newline_transform_stream())
    .pipe(stdoutPassThrough)
    
  @proc.stderr
    .pipe(create_newline_transform_stream())
    .pipe(stderrPassThrough)
  
  # Expose PassThrough streams  
  @stdout = stdoutPassThrough
  @stderr = stderrPassThrough
```

Now multiple consumers can pipe from the PassThrough streams without missing data.

## Low-Hanging Fruit from Modern Node.js

1. **pipeline()** instead of .pipe()
   - Better error handling
   - Automatic cleanup
   - Promise-based

2. **Readable.from()** for better stream creation

3. **async iterators** for consuming streams

4. **stream.compose()** for chaining transforms

5. **AbortController** for cancellation
