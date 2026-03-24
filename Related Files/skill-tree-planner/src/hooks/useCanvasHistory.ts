import { useState, useEffect, useRef } from 'react';

export function useCanvasHistory<T>(initialState: T) {
  const [history, setHistory] = useState<T[]>([initialState]);
  const [index, setIndex] = useState(0);

  const push = (state: T) => {
    const next = history.slice(0, index + 1);
    next.push(JSON.parse(JSON.stringify(state)));
    if (next.length > 50) next.shift();
    setHistory(next);
    setIndex(next.length - 1);
  };

  const undo = () => {
    if (index > 0) {
      setIndex(index - 1);
      return history[index - 1];
    }
    return null;
  };

  const redo = () => {
    if (index < history.length - 1) {
      setIndex(index + 1);
      return history[index + 1];
    }
    return null;
  };

  return { push, undo, redo, canUndo: index > 0, canRedo: index < history.length - 1 };
}
