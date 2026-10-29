// Runs the MoonBit++ checker, interpreter and compiler off the main thread,
// so that a program that loops forever can be stopped.
import { check, run, compile, runtime } from "./mbtpp.js";

const ops = { check, run, compile, runtime };

self.onmessage = (e) => {
  const { id, op, src } = e.data;
  let result;
  try {
    result = ops[op](src);
  } catch (err) {
    result =
      err instanceof RangeError
        ? "error: stack overflow (the browser's stack is small; try a smaller input)"
        : "error: " + String(err && err.message ? err.message : err);
  }
  self.postMessage({ id, result });
};

// the imports above are loaded: calls are timed from now on
self.postMessage({ ready: true });
