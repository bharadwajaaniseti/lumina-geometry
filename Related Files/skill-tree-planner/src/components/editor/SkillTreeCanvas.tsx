import React, { useRef, useEffect, useState, useMemo, useCallback, useImperativeHandle, forwardRef } from 'react';
import { 
  Point, 
  Cell, 
  CELL_SIZE, 
  cellToWorld, 
  worldToScreen, 
  screenToWorld, 
  screenToCell, 
  getCellKey, 
  parseCellKey 
} from '../../utils/canvasMath';

export type Tool = 'P' | 'E' | 'N' | 'C' | 'S';

export interface TileStyle {
  color: string;
  lineWidth: number;
  dotSize: number;
}

export interface Node {
  id: string;
  label: string;
  description?: string;
  icon?: string;
  baseValue?: number;
  buyValue?: number;
  maxLevel?: number;
  shape: 'circle' | 'square' | 'hexagon' | 'image';
  color: string;
  labelColor?: string;
  borderWidth: number;
  state: 'locked' | 'available' | 'unlocked';
  imageUrl?: string;
  onClickMeta?: string;
  hoverMeta?: string;
}

export interface Edge {
  id: string;
  from: string; // cell key
  to: string;   // cell key
  color: string;
  width: number;
  style: 'solid' | 'dashed' | 'dotted';
  curveType?: 'straight' | 'curved' | 'stepped' | 'angled';
}

interface SkillTreeCanvasProps {
  tiles: Record<string, TileStyle>;
  setTiles: React.Dispatch<React.SetStateAction<Record<string, TileStyle>>>;
  nodes: Record<string, Node>;
  setNodes: React.Dispatch<React.SetStateAction<Record<string, Node>>>;
  edges: Edge[];
  setEdges: React.Dispatch<React.SetStateAction<Edge[]>>;
  pan: Point;
  setPan: React.Dispatch<React.SetStateAction<Point>>;
  zoom: number;
  setZoom: React.Dispatch<React.SetStateAction<number>>;
  tool: Tool;
  defaultTile: TileStyle;
  defaultEdge: Omit<Edge, 'id' | 'from' | 'to'>;
  onSelectNode: (key: string | null) => void;
  onSelectEdge: (id: string | null) => void;
  onSelectTile: (key: string | null) => void;
  bgColor?: string;
}

export interface SkillTreeCanvasHandle {
  exportToPNG: (transparent?: boolean) => void;
}

const SkillTreeCanvas = forwardRef<SkillTreeCanvasHandle, SkillTreeCanvasProps>(({
  tiles, setTiles,
  nodes, setNodes,
  edges, setEdges,
  pan, setPan,
  zoom, setZoom,
  tool,
  defaultTile,
  defaultEdge,
  onSelectNode,
  onSelectEdge,
  onSelectTile,
  bgColor = '#f5f4f0'
}, ref) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const requestRef = useRef<number>(0);
  const imgCache = useRef<Map<string, HTMLImageElement>>(new Map());
  
  // Interaction state
  const ptr = useRef({
    down: false,
    spaceDown: false,
    isPanning: false,
    dragKey: null as string | null,
    lastCell: null as string | null,
    clientX: 0,
    clientY: 0,
    linkSrc: null as string | null,
  });

  const [hoverKey, setHoverKey] = useState<string | null>(null);
  const [hoverEdgeId, setHoverEdgeId] = useState<string | null>(null);
  const [selNodeKey, setSelNodeKey] = useState<string | null>(null);
  const [selEdgeId, setSelEdgeId] = useState<string | null>(null);
  const [selTileKey, setSelTileKey] = useState<string | null>(null);
  const [tooltip, setTooltip] = useState<{ key: string, x: number, y: number } | null>(null);

  useImperativeHandle(ref, () => ({
    exportToPNG: (transparent: boolean = false) => {
      const canvas = canvasRef.current;
      if (!canvas) return;

      const scale = 4; // 4x for high quality
      const tempCanvas = document.createElement('canvas');
      tempCanvas.width = canvas.width * scale;
      tempCanvas.height = canvas.height * scale;
      const ctx = tempCanvas.getContext('2d');
      if (!ctx) return;

      // Re-render the scene at 4x scale
      const exportPan = { x: pan.x * scale, y: pan.y * scale };
      const exportZoom = zoom * scale;
      
      renderScene(ctx, tempCanvas.width, tempCanvas.height, exportPan, exportZoom, true, transparent);
      
      const dataUrl = tempCanvas.toDataURL('image/png');
      const link = document.createElement('a');
      link.download = `skill_tree_${Date.now()}.png`;
      link.href = dataUrl;
      link.click();
    }
  }));

  // Sync selection state with parent
  useEffect(() => onSelectNode(selNodeKey), [selNodeKey]);
  useEffect(() => onSelectEdge(selEdgeId), [selEdgeId]);
  useEffect(() => onSelectTile(selTileKey), [selTileKey]);

  // Drawing functions
  const renderScene = useCallback((
    ctx: CanvasRenderingContext2D, 
    width: number, 
    height: number, 
    currentPan: Point, 
    currentZoom: number,
    isExport: boolean = false,
    transparent: boolean = false
  ) => {
    if (transparent && isExport) {
      ctx.clearRect(0, 0, width, height);
    } else {
      ctx.fillStyle = bgColor;
      ctx.fillRect(0, 0, width, height);
    }

    // 1. Draw Grid
    const step = CELL_SIZE * currentZoom;
    if (step > 10) {
      ctx.beginPath();
      ctx.fillStyle = '#d9d6ce';
      const startX = currentPan.x % step;
      const startY = currentPan.y % step;
      for (let x = startX; x < width; x += step) {
        for (let y = startY; y < height; y += step) {
          ctx.moveTo(x, y);
          ctx.arc(x, y, 1.2 * currentZoom, 0, Math.PI * 2);
        }
      }
      ctx.fill();
    }

    // 2. Draw Tiles & Lanes
    Object.entries(tiles).forEach(([key, tileObj]) => {
      const tile = tileObj as TileStyle;
      if (!tile) return;
      const { col, row } = parseCellKey(key);
      const world = cellToWorld(col, row);
      const screen = worldToScreen(world.x, world.y, currentPan, currentZoom);

      // Draw Lanes to neighbors (right and down)
      const neighbors = [
        { c: col + 1, r: row }, // Right
        { c: col, r: row + 1 }, // Down
        { c: col + 1, r: row + 1, diag: true }, // Down-Right
        { c: col - 1, r: row + 1, diag: true }, // Down-Left
      ];

      neighbors.forEach(n => {
        const nKey = getCellKey(n.c, n.r);
        if (tiles[nKey]) {
          const nWorld = cellToWorld(n.c, n.r);
          const nScreen = worldToScreen(nWorld.x, nWorld.y, currentPan, currentZoom);
          
          ctx.beginPath();
          if (tile.color === tiles[nKey].color) {
            ctx.strokeStyle = tile.color;
          } else {
            const grad = ctx.createLinearGradient(screen.x, screen.y, nScreen.x, nScreen.y);
            grad.addColorStop(0, tile.color);
            grad.addColorStop(1, tiles[nKey].color);
            ctx.strokeStyle = grad;
          }
          
          ctx.lineWidth = tile.lineWidth * currentZoom;
          ctx.lineCap = 'round';
          if (n.diag) ctx.globalAlpha = 0.35;
          ctx.moveTo(screen.x, screen.y);
          ctx.lineTo(nScreen.x, nScreen.y);
          ctx.stroke();
          ctx.globalAlpha = 1.0;
        }
      });

      // Draw dot if not a node
      if (!nodes[key]) {
        ctx.beginPath();
        ctx.fillStyle = tile.color;
        ctx.arc(screen.x, screen.y, tile.dotSize * currentZoom, 0, Math.PI * 2);
        ctx.fill();

        if (!isExport && selTileKey === key) {
          ctx.beginPath();
          ctx.strokeStyle = '#15803d';
          ctx.setLineDash([4 * currentZoom, 4 * currentZoom]);
          ctx.arc(screen.x, screen.y, (tile.dotSize + 4) * currentZoom, 0, Math.PI * 2);
          ctx.stroke();
          ctx.setLineDash([]);
        }
      }
    });

    // 3. Draw Edges
    edges.forEach(edge => {
      if (!edge) return;
      const fromCell = parseCellKey(edge.from);
      const toCell = parseCellKey(edge.to);
      const s1 = worldToScreen(cellToWorld(fromCell.col, fromCell.row).x, cellToWorld(fromCell.col, fromCell.row).y, currentPan, currentZoom);
      const s2 = worldToScreen(cellToWorld(toCell.col, toCell.row).x, cellToWorld(toCell.col, toCell.row).y, currentPan, currentZoom);

      ctx.beginPath();
      ctx.strokeStyle = edge.color;
      ctx.lineWidth = (!isExport && selEdgeId === edge.id ? edge.width + 2 : edge.width) * currentZoom;
      
      if (edge.style === 'dashed') ctx.setLineDash([10 * currentZoom, 6 * currentZoom]);
      else if (edge.style === 'dotted') ctx.setLineDash([2 * currentZoom, 6 * currentZoom]);
      else ctx.setLineDash([]);

      if (!isExport && selEdgeId === edge.id) {
        ctx.lineDashOffset = -(Date.now() * 0.05) % 100;
      }

      const curveType = edge.curveType || 'curved';
      let arrowPoint = s2;
      let arrowAngle = 0;

      if (curveType === 'straight') {
        ctx.moveTo(s1.x, s1.y);
        ctx.lineTo(s2.x, s2.y);
        arrowAngle = Math.atan2(s2.y - s1.y, s2.x - s1.x);
        const t = 0.86;
        arrowPoint = {
          x: s1.x + (s2.x - s1.x) * t,
          y: s1.y + (s2.y - s1.y) * t
        };
      } else if (curveType === 'curved') {
        const cp = {
          x: (s1.x + s2.x) / 2 + (s2.y - s1.y) * 0.25,
          y: (s1.y + s2.y) / 2 - (s2.x - s1.x) * 0.25
        };
        ctx.moveTo(s1.x, s1.y);
        ctx.quadraticCurveTo(cp.x, cp.y, s2.x, s2.y);
        
        const t = 0.86;
        arrowPoint = {
          x: (1 - t) * (1 - t) * s1.x + 2 * (1 - t) * t * cp.x + t * t * s2.x,
          y: (1 - t) * (1 - t) * s1.y + 2 * (1 - t) * t * cp.y + t * t * s2.y
        };
        const dx = 2 * (1 - t) * (cp.x - s1.x) + 2 * t * (s2.x - cp.x);
        const dy = 2 * (1 - t) * (cp.y - s1.y) + 2 * t * (s2.y - cp.y);
        arrowAngle = Math.atan2(dy, dx);
      } else if (curveType === 'stepped') {
        ctx.moveTo(s1.x, s1.y);
        ctx.lineTo(s2.x, s1.y);
        ctx.lineTo(s2.x, s2.y);
        arrowAngle = Math.atan2(s2.y - s1.y, 0);
        const t = 0.86;
        arrowPoint = { x: s2.x, y: s1.y + (s2.y - s1.y) * t };
      } else if (curveType === 'angled') {
        const midX = (s1.x + s2.x) / 2;
        const midY = (s1.y + s2.y) / 2;
        const cp = {
          x: midX + (s2.y - s1.y) * 0.2,
          y: midY - (s2.x - s1.x) * 0.2
        };
        ctx.moveTo(s1.x, s1.y);
        ctx.lineTo(cp.x, cp.y);
        ctx.lineTo(s2.x, s2.y);
        arrowAngle = Math.atan2(s2.y - cp.y, s2.x - cp.x);
        const t = 0.86;
        arrowPoint = {
          x: cp.x + (s2.x - cp.x) * t,
          y: cp.y + (s2.y - cp.y) * t
        };
      }

      ctx.stroke();
      ctx.setLineDash([]);
      ctx.lineDashOffset = 0;

      // Arrowhead
      ctx.beginPath();
      ctx.fillStyle = edge.color;
      ctx.moveTo(arrowPoint.x, arrowPoint.y);
      const size = 8 * currentZoom;
      ctx.lineTo(
        arrowPoint.x - size * Math.cos(arrowAngle - Math.PI/6),
        arrowPoint.y - size * Math.sin(arrowAngle - Math.PI/6)
      );
      ctx.lineTo(
        arrowPoint.x - size * Math.cos(arrowAngle + Math.PI/6),
        arrowPoint.y - size * Math.sin(arrowAngle + Math.PI/6)
      );
      ctx.closePath();
      ctx.fill();
    });

    // 4. Draw Nodes
    Object.entries(nodes).forEach(([key, nodeObj]) => {
      const node = nodeObj as Node;
      if (!node) return;
      const { col, row } = parseCellKey(key);
      const world = cellToWorld(col, row);
      const screen = worldToScreen(world.x, world.y, currentPan, currentZoom);
      const size = 18 * currentZoom;

      // Draw Node Shape
      ctx.beginPath();
      ctx.fillStyle = node.color;
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = node.borderWidth * currentZoom;

      if (node.shape === 'circle') {
        ctx.arc(screen.x, screen.y, size, 0, Math.PI * 2);
      } else if (node.shape === 'square') {
        ctx.rect(screen.x - size, screen.y - size, size * 2, size * 2);
      } else if (node.shape === 'hexagon') {
        for (let i = 0; i < 6; i++) {
          const angle = (i * Math.PI) / 3;
          const x = screen.x + size * Math.cos(angle);
          const y = screen.y + size * Math.sin(angle);
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.closePath();
      } else if (node.shape === 'image' && node.imageUrl) {
        const img = imgCache.current.get(node.imageUrl);
        if (img && img.complete) {
          ctx.save();
          ctx.beginPath();
          ctx.arc(screen.x, screen.y, size, 0, Math.PI * 2);
          ctx.clip();
          ctx.drawImage(img, screen.x - size, screen.y - size, size * 2, size * 2);
          ctx.restore();
          ctx.beginPath();
          ctx.arc(screen.x, screen.y, size, 0, Math.PI * 2);
        } else {
          ctx.arc(screen.x, screen.y, size, 0, Math.PI * 2);
          if (node.imageUrl && !imgCache.current.has(node.imageUrl)) {
            const newImg = new Image();
            newImg.src = node.imageUrl;
            newImg.onload = () => {
              imgCache.current.set(node.imageUrl!, newImg);
            };
            imgCache.current.set(node.imageUrl, newImg);
          }
        }
      }

      ctx.fill();
      ctx.stroke();

      // Label
      if (node.label) {
        ctx.fillStyle = node.labelColor || '#1a1a1a';
        ctx.font = `bold ${10 * currentZoom}px Inter, sans-serif`;
        ctx.textAlign = 'center';
        ctx.fillText(node.label, screen.x, screen.y + size + 14 * currentZoom);
      }

      // Selection indicator
      if (!isExport && selNodeKey === key) {
        ctx.beginPath();
        ctx.strokeStyle = '#15803d';
        ctx.lineWidth = 2 * currentZoom;
        ctx.setLineDash([4 * currentZoom, 4 * currentZoom]);
        ctx.arc(screen.x, screen.y, size + 6 * currentZoom, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);
      }
    });

    // 5. Draw Preview Box (Paint Tool)
    if (!isExport && (tool === 'P' || tool === 'N')) {
      const rect = canvasRef.current?.getBoundingClientRect();
      if (rect) {
        const sx = ptr.current.clientX - rect.left;
        const sy = ptr.current.clientY - rect.top;
        const cell = screenToCell(sx, sy, currentPan, currentZoom);
        const world = cellToWorld(cell.col, cell.row);
        const screen = worldToScreen(world.x, world.y, currentPan, currentZoom);
        
        ctx.beginPath();
        ctx.strokeStyle = '#d1d1d1';
        ctx.setLineDash([4 * currentZoom, 4 * currentZoom]);
        ctx.lineWidth = 1 * currentZoom;
        const size = CELL_SIZE * currentZoom;
        ctx.rect(screen.x - size / 2, screen.y - size / 2, size, size);
        ctx.stroke();
        ctx.setLineDash([]);
      }
    }
  }, [tiles, nodes, edges, selNodeKey, selEdgeId, selTileKey, tool, bgColor]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    renderScene(ctx, canvas.width, canvas.height, pan, zoom);
    requestRef.current = requestAnimationFrame(draw);
  }, [renderScene, pan, zoom]);

  useEffect(() => {
    requestRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(requestRef.current);
  }, [draw]);

  // Event Handlers
  const handleMouseDown = (e: React.MouseEvent) => {
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return;
    
    const sx = e.clientX - rect.left;
    const sy = e.clientY - rect.top;
    const cell = screenToCell(sx, sy, pan, zoom);
    const key = getCellKey(cell.col, cell.row);

    ptr.current.down = true;
    ptr.current.clientX = e.clientX;
    ptr.current.clientY = e.clientY;

    if (e.button === 1 || ptr.current.spaceDown) {
      ptr.current.isPanning = true;
      return;
    }

    if (tool === 'P') {
      setTiles(prev => ({ ...prev, [key]: { ...defaultTile } }));
    } else if (tool === 'E') {
      setTiles(prev => {
        const next = { ...prev };
        delete next[key];
        return next;
      });
      setNodes(prev => {
        const next = { ...prev };
        delete next[key];
        return next;
      });
      setEdges(prev => prev.filter(e => e.from !== key && e.to !== key));
    } else if (tool === 'N') {
      if (!nodes[key]) {
        setNodes(prev => ({
          ...prev,
          [key]: {
            id: `node_${Date.now()}`,
            label: 'New Node',
            shape: 'circle',
            color: '#15803d',
            borderWidth: 2,
            state: 'locked'
          }
        }));
        if (!tiles[key]) setTiles(prev => ({ ...prev, [key]: { ...defaultTile } }));
      }
      setSelNodeKey(key);
      setSelEdgeId(null);
      setSelTileKey(null);
    } else if (tool === 'C') {
      if (nodes[key]) {
        if (!ptr.current.linkSrc) {
          ptr.current.linkSrc = key;
        } else if (ptr.current.linkSrc !== key) {
          setEdges(prev => [
            ...prev,
            {
              id: `edge_${Date.now()}`,
              from: ptr.current.linkSrc!,
              to: key,
              ...defaultEdge
            }
          ]);
          ptr.current.linkSrc = null;
        }
      }
    } else if (tool === 'S') {
      if (nodes[key]) {
        setSelNodeKey(key);
        setSelEdgeId(null);
        setSelTileKey(null);
        ptr.current.dragKey = key;
      } else {
        // Edge hit test (improved for all curve types)
        const hitEdge = edges.find(edge => {
          const from = parseCellKey(edge.from);
          const to = parseCellKey(edge.to);
          const type = edge.curveType || 'curved';
          
          // Helper to check distance to a point in cell coordinates
          const checkPoint = (px: number, py: number) => Math.hypot(cell.col - px, cell.row - py) < 0.4;

          if (type === 'straight') {
            return distToSegment(cell.col, cell.row, from.col, from.row, to.col, to.row) < 0.4;
          } else if (type === 'curved') {
            const cpCol = (from.col + to.col) / 2 + (to.row - from.row) * 0.25;
            const cpRow = (from.row + to.row) / 2 - (to.col - from.col) * 0.25;
            // Sample points along the curve
            for (let t = 0; t <= 1; t += 0.05) {
              const px = (1 - t) * (1 - t) * from.col + 2 * (1 - t) * t * cpCol + t * t * to.col;
              const py = (1 - t) * (1 - t) * from.row + 2 * (1 - t) * t * cpRow + t * t * to.row;
              if (checkPoint(px, py)) return true;
            }
          } else if (type === 'stepped') {
            const cornerCol = from.col;
            const cornerRow = to.row;
            return distToSegment(cell.col, cell.row, from.col, from.row, cornerCol, cornerRow) < 0.4 ||
                   distToSegment(cell.col, cell.row, cornerCol, cornerRow, to.col, to.row) < 0.4;
          } else if (type === 'angled') {
            const midCol = (from.col + to.col) / 2;
            const midRow = (from.row + to.row) / 2;
            const cpCol = midCol + (to.row - from.row) * 0.2;
            const cpRow = midRow - (to.col - from.col) * 0.2;
            return distToSegment(cell.col, cell.row, from.col, from.row, cpCol, cpRow) < 0.4 ||
                   distToSegment(cell.col, cell.row, cpCol, cpRow, to.col, to.row) < 0.4;
          }
          return false;
        });

        if (hitEdge) {
          setSelEdgeId(hitEdge.id);
          setSelNodeKey(null);
          setSelTileKey(null);
        } else if (tiles[key]) {
          setSelTileKey(key);
          setSelNodeKey(null);
          setSelEdgeId(null);
        } else {
          setSelNodeKey(null);
          setSelEdgeId(null);
          setSelTileKey(null);
        }
      }
    }
  };

  const distToSegment = (px: number, py: number, x1: number, y1: number, x2: number, y2: number) => {
    const l2 = (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
    if (l2 === 0) return Math.hypot(px - x1, py - y1);
    let t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / l2;
    t = Math.max(0, Math.min(1, t));
    return Math.hypot(px - (x1 + t * (x2 - x1)), py - (y1 + t * (y2 - y1)));
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return;
    
    const sx = e.clientX - rect.left;
    const sy = e.clientY - rect.top;
    const cell = screenToCell(sx, sy, pan, zoom);
    const key = getCellKey(cell.col, cell.row);

    if (nodes[key]) {
      setTooltip({ key, x: sx, y: sy });
    } else {
      setTooltip(null);
    }

    const dx = e.clientX - ptr.current.clientX;
    const dy = e.clientY - ptr.current.clientY;

    ptr.current.clientX = e.clientX;
    ptr.current.clientY = e.clientY;

    setHoverKey(nodes[key] ? key : null);

    // Edge hover detection for cursor
    if (tool === 'S') {
      const hitEdge = edges.find(edge => {
        const from = parseCellKey(edge.from);
        const to = parseCellKey(edge.to);
        const type = edge.curveType || 'curved';
        const checkPoint = (px: number, py: number) => Math.hypot(cell.col - px, cell.row - py) < 0.4;

        if (type === 'straight') {
          return distToSegment(cell.col, cell.row, from.col, from.row, to.col, to.row) < 0.4;
        } else if (type === 'curved') {
          const cpCol = (from.col + to.col) / 2 + (to.row - from.row) * 0.25;
          const cpRow = (from.row + to.row) / 2 - (to.col - from.col) * 0.25;
          for (let t = 0; t <= 1; t += 0.05) {
            const px = (1 - t) * (1 - t) * from.col + 2 * (1 - t) * t * cpCol + t * t * to.col;
            const py = (1 - t) * (1 - t) * from.row + 2 * (1 - t) * t * cpRow + t * t * to.row;
            if (checkPoint(px, py)) return true;
          }
        } else if (type === 'stepped') {
          const cornerCol = from.col;
          const cornerRow = to.row;
          return distToSegment(cell.col, cell.row, from.col, from.row, cornerCol, cornerRow) < 0.4 ||
                 distToSegment(cell.col, cell.row, cornerCol, cornerRow, to.col, to.row) < 0.4;
        } else if (type === 'angled') {
          const midCol = (from.col + to.col) / 2;
          const midRow = (from.row + to.row) / 2;
          const cpCol = midCol + (to.row - from.row) * 0.2;
          const cpRow = midRow - (to.col - from.col) * 0.2;
          return distToSegment(cell.col, cell.row, from.col, from.row, cpCol, cpRow) < 0.4 ||
                 distToSegment(cell.col, cell.row, cpCol, cpRow, to.col, to.row) < 0.4;
        }
        return false;
      });
      setHoverEdgeId(hitEdge ? hitEdge.id : null);
    } else {
      setHoverEdgeId(null);
    }

    if (ptr.current.isPanning) {
      setPan(prev => ({ x: prev.x + dx, y: prev.y + dy }));
      return;
    }

    if (ptr.current.down) {
      if (tool === 'P') {
        setTiles(prev => ({ ...prev, [key]: { ...defaultTile } }));
      } else if (tool === 'E') {
        setTiles(prev => {
          const next = { ...prev };
          delete next[key];
          return next;
        });
      } else if (tool === 'S' && ptr.current.dragKey && ptr.current.dragKey !== key) {
        // Move node
        const oldKey = ptr.current.dragKey;
        if (!nodes[key] && nodes[oldKey]) {
          // Create tile at new position if it doesn't exist
          if (!tiles[key]) {
            setTiles(prev => ({ ...prev, [key]: { ...defaultTile } }));
          }
          
          setNodes(prev => {
            const next = { ...prev };
            const node = next[oldKey];
            if (!node) return prev;
            delete next[oldKey];
            next[key] = node;
            return next;
          });
          setEdges(prev => prev.map(edge => {
            if (edge.from === oldKey) return { ...edge, from: key };
            if (edge.to === oldKey) return { ...edge, to: key };
            return edge;
          }));
          setSelNodeKey(key);
          ptr.current.dragKey = key;
        }
      }
    }
  };

  const handleMouseUp = () => {
    ptr.current.down = false;
    ptr.current.isPanning = false;
    ptr.current.dragKey = null;
  };

  const handleWheel = (e: React.WheelEvent) => {
    e.preventDefault();
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return;

    const sx = e.clientX - rect.left;
    const sy = e.clientY - rect.top;

    const delta = -e.deltaY;
    const factor = delta > 0 ? 1.12 : 1 / 1.12;
    const newZoom = Math.min(5, Math.max(0.1, zoom * factor));

    setPan(prev => ({
      x: sx - (sx - prev.x) * (newZoom / zoom),
      y: sy - (sy - prev.y) * (newZoom / zoom),
    }));
    setZoom(newZoom);
  };

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.code === 'Space') ptr.current.spaceDown = true;
      if (e.key === 'Escape') {
        ptr.current.linkSrc = null;
        setSelNodeKey(null);
        setSelEdgeId(null);
        setSelTileKey(null);
      }
    };
    const handleKeyUp = (e: KeyboardEvent) => {
      if (e.code === 'Space') ptr.current.spaceDown = false;
    };
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
    };
  }, []);

  // Resize handling
  useEffect(() => {
    const resize = () => {
      if (containerRef.current && canvasRef.current) {
        canvasRef.current.width = containerRef.current.clientWidth;
        canvasRef.current.height = containerRef.current.clientHeight;
      }
    };
    window.addEventListener('resize', resize);
    resize();
    return () => window.removeEventListener('resize', resize);
  }, []);

  return (
    <div ref={containerRef} className="w-full h-full relative bg-[#f5f4f0] overflow-hidden cursor-crosshair">
      <canvas
        ref={canvasRef}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseUp}
        onWheel={handleWheel}
        className="block"
      />

      {tooltip && nodes[tooltip.key] && (
        <div 
          className="absolute z-50 pointer-events-none bg-white/95 backdrop-blur-md border border-zinc-200 rounded-2xl p-4 shadow-2xl min-w-[220px] animate-in fade-in zoom-in duration-150"
          style={{ 
            left: tooltip.x + 20, 
            top: tooltip.y + 20,
          }}
        >
          <div className="flex items-center gap-3 mb-3">
            <div 
              className="w-10 h-10 rounded-xl flex items-center justify-center text-white font-bold text-sm shadow-lg"
              style={{ backgroundColor: nodes[tooltip.key].color }}
            >
              {nodes[tooltip.key].label.charAt(0)}
            </div>
            <div>
              <h4 className="text-sm font-bold text-zinc-900 leading-tight">{nodes[tooltip.key].label}</h4>
              <div className="flex items-center gap-1.5 mt-0.5">
                <div className={`w-1.5 h-1.5 rounded-full ${
                  nodes[tooltip.key].state === 'unlocked' ? 'bg-emerald-500' : 
                  nodes[tooltip.key].state === 'available' ? 'bg-amber-500' : 'bg-zinc-400'
                }`} />
                <span className="text-[9px] font-bold text-zinc-400 uppercase tracking-widest">
                  {nodes[tooltip.key].state}
                </span>
              </div>
            </div>
          </div>
          
          {nodes[tooltip.key].description && (
            <p className="text-[11px] text-zinc-500 leading-relaxed mb-4 italic border-l-2 border-zinc-100 pl-3">
              {nodes[tooltip.key].description}
            </p>
          )}

          <div className="grid grid-cols-3 gap-3 pt-3 border-t border-zinc-100">
            <div className="flex flex-col">
              <span className="text-[8px] font-bold text-zinc-400 uppercase tracking-widest">Base</span>
              <span className="text-xs font-bold text-zinc-900">{nodes[tooltip.key].baseValue || 0}</span>
            </div>
            <div className="flex flex-col">
              <span className="text-[8px] font-bold text-zinc-400 uppercase tracking-widest">Buy</span>
              <span className="text-xs font-bold text-zinc-900">{nodes[tooltip.key].buyValue || 0}</span>
            </div>
            <div className="flex flex-col">
              <span className="text-[8px] font-bold text-zinc-400 uppercase tracking-widest">Max</span>
              <span className="text-xs font-bold text-zinc-900">{nodes[tooltip.key].maxLevel || 1}</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
});

export default SkillTreeCanvas;
