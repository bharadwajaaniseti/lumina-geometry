export interface Point {
  x: number;
  y: number;
}

export interface Cell {
  col: number;
  row: number;
}

export const CELL_SIZE = 48;

export function cellToWorld(col: number, row: number): Point {
  return {
    x: col * CELL_SIZE + CELL_SIZE / 2,
    y: row * CELL_SIZE + CELL_SIZE / 2,
  };
}

export function worldToScreen(wx: number, wy: number, pan: Point, zoom: number): Point {
  return {
    x: wx * zoom + pan.x,
    y: wy * zoom + pan.y,
  };
}

export function screenToWorld(sx: number, sy: number, pan: Point, zoom: number): Point {
  return {
    x: (sx - pan.x) / zoom,
    y: (sy - pan.y) / zoom,
  };
}

export function screenToCell(sx: number, sy: number, pan: Point, zoom: number): Cell {
  const world = screenToWorld(sx, sy, pan, zoom);
  return {
    col: Math.floor(world.x / CELL_SIZE),
    row: Math.floor(world.y / CELL_SIZE),
  };
}

export function getCellKey(col: number, row: number): string {
  return `${col},${row}`;
}

export function parseCellKey(key: string): Cell {
  const [col, row] = key.split(',').map(Number);
  return { col, row };
}
