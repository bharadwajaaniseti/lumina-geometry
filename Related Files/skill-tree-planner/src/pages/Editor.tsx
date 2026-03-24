import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth, OperationType, handleFirestoreError } from '../hooks/useAuth';
import SkillTreeCanvas, { Tool, TileStyle, Node, Edge, SkillTreeCanvasHandle } from '../components/editor/SkillTreeCanvas';
import Toolbar from '../components/editor/Toolbar';
import { useCanvasHistory } from '../hooks/useCanvasHistory';
import { useCloudSave } from '../hooks/useCloudSave';
import { X, Trash2, Settings, Palette, Type, Layers, Upload, Image as ImageIcon, ChevronDown } from 'lucide-react';
import ExportModal from '../components/editor/ExportModal';

export default function Editor() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const canvasHandleRef = useRef<SkillTreeCanvasHandle>(null);
  
  const [loading, setLoading] = useState(true);
  const [projectName, setProjectName] = useState('');
  
  const [tiles, setTiles] = useState<Record<string, TileStyle>>({});
  const [nodes, setNodes] = useState<Record<string, Node>>({});
  const [edges, setEdges] = useState<Edge[]>([]);
  
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [tool, setTool] = useState<Tool>('S');
  const [bgColor, setBgColor] = useState('#f5f4f0');
  
  const [defaultTile, setDefaultTile] = useState<TileStyle>({ color: "#b8b4aa", lineWidth: 2, dotSize: 5 });
  const [defaultEdge, setDefaultEdge] = useState<Omit<Edge, 'id' | 'from' | 'to'>>({ color: "#f59e0b", width: 2, style: "solid" });

  const [selNodeKey, setSelNodeKey] = useState<string | null>(null);
  const [selEdgeId, setSelEdgeId] = useState<string | null>(null);
  const [selTileKey, setSelTileKey] = useState<string | null>(null);
  const [showExport, setShowExport] = useState(false);

  const { push, undo, redo, canUndo, canRedo } = useCanvasHistory({ tiles, nodes, edges });
  const { status: saveStatus, save } = useCloudSave(id || '', { tiles, nodes, edges });

  const stats = {
    tiles: Object.keys(tiles).length,
    nodes: Object.keys(nodes).length,
    edges: edges.length,
    zoom: Math.round(zoom * 100)
  };

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      
      const key = e.key.toUpperCase();
      if (['P', 'E', 'N', 'C', 'S'].includes(key)) {
        setTool(key as Tool);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  useEffect(() => {
    const fetchProject = async () => {
      if (!id) {
        // Load from localStorage if guest
        const saved = localStorage.getItem('guest_project');
        if (saved) {
          try {
            const data = JSON.parse(saved);
            setTiles(data.tiles || {});
            setNodes(data.nodes || {});
            setEdges(data.edges || []);
            if (data.defaultTile) setDefaultTile(data.defaultTile);
            if (data.defaultEdge) setDefaultEdge(data.defaultEdge);
            if (data.bgColor) setBgColor(data.bgColor);
          } catch (e) {
            console.error('Failed to parse guest project', e);
          }
        }
        setLoading(false);
        return;
      }
      try {
        const projectRef = doc(db, 'projects', id);
        const projectSnap = await getDoc(projectRef);
        
        if (projectSnap.exists()) {
          const data = projectSnap.data();
          setProjectName(data.name);
          const treeData = data.treeData || {};
          setTiles(treeData.tiles || {});
          setNodes(treeData.nodes || {});
          setEdges(treeData.edges || []);
          if (treeData.defaultTile) setDefaultTile(treeData.defaultTile);
          if (treeData.defaultEdge) setDefaultEdge(treeData.defaultEdge);
        } else {
          console.error('Project not found');
          navigate('/dashboard');
        }
      } catch (error) {
        console.error('Failed to load project:', error);
        handleFirestoreError(error, OperationType.GET, `projects/${id}`);
        navigate('/dashboard');
      } finally {
        setLoading(false);
      }
    };
    fetchProject();
  }, [id, navigate]);

  // Save to localStorage if guest
  useEffect(() => {
    if (!id && !loading) {
      const data = { tiles, nodes, edges, defaultTile, defaultEdge, bgColor };
      localStorage.setItem('guest_project', JSON.stringify(data));
    }
  }, [id, loading, tiles, nodes, edges, defaultTile, defaultEdge, bgColor]);

  const handleUndo = () => {
    const state = undo();
    if (state) {
      setTiles(state.tiles);
      setNodes(state.nodes);
      setEdges(state.edges);
    }
  };

  const handleRedo = () => {
    const state = redo();
    if (state) {
      setTiles(state.tiles);
      setNodes(state.nodes);
      setEdges(state.edges);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-[#f5f4f0]">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-emerald-600"></div>
      </div>
    );
  }

  return (
    <div className="h-screen flex flex-col overflow-hidden bg-[#f5f4f0]">
      <Toolbar 
        tool={tool} 
        setTool={setTool}
        onUndo={handleUndo}
        onRedo={handleRedo}
        canUndo={canUndo}
        canRedo={canRedo}
        onSave={save}
        saveStatus={saveStatus}
        defaultTile={defaultTile}
        setDefaultTile={setDefaultTile}
        defaultEdge={defaultEdge}
        setDefaultEdge={setDefaultEdge}
        onExport={() => setShowExport(true)}
        onClear={() => {
          if (confirm('Clear entire canvas?')) {
            setTiles({});
            setNodes({});
            setEdges([]);
          }
        }}
        bgColor={bgColor}
        setBgColor={setBgColor}
      />
      
      <div className="flex-1 flex overflow-hidden relative">
        {/* Left Panels */}
        <div className="absolute left-6 top-6 z-10 space-y-4 pointer-events-none">
          <div className="w-56 bg-white/90 backdrop-blur-sm border border-[#e2e0da] rounded-2xl p-4 shadow-sm pointer-events-auto">
            <h4 className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest mb-3">Stats</h4>
            <div className="space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-xs text-zinc-500">Tiles</span>
                <span className="text-xs font-bold text-zinc-900">{stats.tiles}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-xs text-zinc-500">Nodes</span>
                <span className="text-xs font-bold text-zinc-900">{stats.nodes}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-xs text-zinc-500">Edges</span>
                <span className="text-xs font-bold text-zinc-900">{stats.edges}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-xs text-zinc-500">Zoom</span>
                <span className="text-xs font-bold text-zinc-900">{stats.zoom}%</span>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Workflow Bar */}
        <div className="absolute bottom-6 left-1/2 -translate-x-1/2 z-10 pointer-events-none">
          <div className="bg-white/80 backdrop-blur-sm border border-[#e2e0da] rounded-full px-6 py-3 shadow-sm pointer-events-auto flex items-center gap-8 opacity-60 hover:opacity-100 transition-opacity">
            <div className={`flex items-center gap-2 ${tool === 'P' ? 'opacity-100' : 'opacity-40'}`}>
              <span className="text-[10px] font-bold text-zinc-900">1. Paint [P]</span>
              <span className="text-[9px] text-zinc-500">Sketch skeleton</span>
            </div>
            <div className={`flex items-center gap-2 ${tool === 'N' ? 'opacity-100' : 'opacity-40'}`}>
              <span className="text-[10px] font-bold text-zinc-900">2. Node [N]</span>
              <span className="text-[9px] text-zinc-500">Stamp nodes</span>
            </div>
            <div className={`flex items-center gap-2 ${tool === 'C' ? 'opacity-100' : 'opacity-40'}`}>
              <span className="text-[10px] font-bold text-zinc-900">3. Connect [C]</span>
              <span className="text-[9px] text-zinc-500">Wire flow</span>
            </div>
            <div className={`flex items-center gap-2 ${tool === 'S' ? 'opacity-100' : 'opacity-40'}`}>
              <span className="text-[10px] font-bold text-zinc-900">4. Select [S]</span>
              <span className="text-[9px] text-zinc-500">Edit elements</span>
            </div>
          </div>
        </div>

        {/* Auto-save indicator */}
        {id ? (
          <div className="absolute bottom-4 right-4 z-10 flex items-center gap-2 px-3 py-1.5 bg-white/80 backdrop-blur-sm border border-[#e2e0da] rounded-full shadow-sm">
            <div className={`w-2 h-2 rounded-full ${saveStatus === 'saving' ? 'bg-amber-400 animate-pulse' : 'bg-emerald-400'}`} />
            <span className="text-[10px] font-medium text-zinc-500">
              {saveStatus === 'saving' ? 'Saving...' : 'Auto-saving to cloud'}
            </span>
          </div>
        ) : (
          <div className="absolute bottom-4 right-4 z-10 flex items-center gap-3 px-4 py-2 bg-zinc-900 text-white rounded-full shadow-lg">
            <span className="text-[10px] font-bold uppercase tracking-widest">Sandbox Mode</span>
            <button 
              onClick={() => navigate('/login')}
              className="px-3 py-1 bg-white text-zinc-900 rounded-full text-[10px] font-bold uppercase tracking-widest hover:bg-zinc-100 transition-colors"
            >
              Login to Save
            </button>
          </div>
        )}

        <SkillTreeCanvas 
          ref={canvasHandleRef}
          tiles={tiles} setTiles={setTiles}
          nodes={nodes} setNodes={setNodes}
          edges={edges} setEdges={setEdges}
          pan={pan} setPan={setPan}
          zoom={zoom} setZoom={setZoom}
          tool={tool}
          defaultTile={defaultTile}
          defaultEdge={defaultEdge}
          onSelectNode={setSelNodeKey}
          onSelectEdge={setSelEdgeId}
          onSelectTile={setSelTileKey}
          bgColor={bgColor}
        />

        {showExport && (
          <ExportModal 
            tiles={tiles}
            nodes={nodes}
            edges={edges}
            projectName={projectName}
            onClose={() => setShowExport(false)}
            onExportPNG={(transparent) => canvasHandleRef.current?.exportToPNG(transparent)}
          />
        )}

        {/* Right Panel (Inspector) */}
        {(selNodeKey || selEdgeId || selTileKey) && (
          <div className="w-80 bg-white border-l border-[#e2e0da] shadow-2xl z-20 flex flex-col animate-in slide-in-from-right duration-200">
            <div className="p-4 border-b border-zinc-100 flex items-center justify-between">
              <h3 className="font-bold text-zinc-900 flex items-center gap-2">
                {selNodeKey ? <Settings size={18} className="text-zinc-400" /> : 
                 selTileKey ? <Palette size={18} className="text-zinc-400" /> :
                 <Layers size={18} className="text-zinc-400" />}
                {selNodeKey ? 'Node Inspector' : selTileKey ? 'Tile Inspector' : 'Edge Inspector'}
              </h3>
              <button 
                onClick={() => {
                  setSelNodeKey(null);
                  setSelEdgeId(null);
                  setSelTileKey(null);
                }}
                className="p-1 hover:bg-zinc-100 rounded-lg text-zinc-400"
              >
                <X size={18} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-6 space-y-8">
              {selNodeKey && nodes[selNodeKey] && (
                <NodeInspector 
                  node={nodes[selNodeKey]} 
                  onUpdate={(update) => setNodes(prev => ({ ...prev, [selNodeKey]: { ...prev[selNodeKey], ...update } }))}
                  onDelete={() => {
                    setNodes(prev => {
                      const next = { ...prev };
                      delete next[selNodeKey];
                      return next;
                    });
                    setEdges(prev => prev.filter(e => e.from !== selNodeKey && e.to !== selNodeKey));
                    setSelNodeKey(null);
                  }}
                />
              )}

              {selEdgeId && edges.find(e => e.id === selEdgeId) && (
                <EdgeInspector 
                  edge={edges.find(e => e.id === selEdgeId)!}
                  onUpdate={(update) => setEdges(prev => prev.map(e => e.id === selEdgeId ? { ...e, ...update } : e))}
                  onDelete={() => {
                    setEdges(prev => prev.filter(e => e.id !== selEdgeId));
                    setSelEdgeId(null);
                  }}
                />
              )}

              {selTileKey && tiles[selTileKey] && (
                <TileInspector 
                  tile={tiles[selTileKey]}
                  cellKey={selTileKey}
                  onUpdate={(update) => setTiles(prev => ({ ...prev, [selTileKey]: { ...prev[selTileKey], ...update } }))}
                  onDelete={() => {
                    setTiles(prev => {
                      const next = { ...prev };
                      delete next[selTileKey];
                      return next;
                    });
                    setSelTileKey(null);
                  }}
                />
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function ColorPicker({ color, onChange }: { color: string, onChange: (c: string) => void }) {
  const presets = ['#b8b4aa', '#f59e0b', '#10b981', '#3b82f6', '#ef4444', '#8b5cf6', '#ec4899', '#06b6d4'];
  
  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-2">
        {presets.map(p => (
          <button
            key={p}
            onClick={() => onChange(p)}
            className={`w-6 h-6 rounded-full border-2 transition-transform hover:scale-110 ${color === p ? 'border-zinc-900 scale-110' : 'border-transparent'}`}
            style={{ backgroundColor: p }}
          />
        ))}
      </div>
      <div className="flex gap-2">
        <div 
          className="w-10 h-10 rounded-xl border border-zinc-200 shadow-sm shrink-0"
          style={{ backgroundColor: color }}
        />
        <input 
          type="text" 
          value={color} 
          onChange={(e) => onChange(e.target.value)}
          className="flex-1 px-3 py-2 bg-zinc-50 border border-zinc-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-zinc-900/5"
        />
      </div>
    </div>
  );
}

function NodeInspector({ node, onUpdate, onDelete }: { node: Node, onUpdate: (u: Partial<Node>) => void, onDelete: () => void }) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [showMeta, setShowMeta] = useState(false);

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        onUpdate({ imageUrl: reader.result as string });
      };
      reader.readAsDataURL(file);
    }
  };

  return (
    <div className="space-y-6">
      <div className="space-y-4">
        {/* Metadata Group */}
        <div className="border border-zinc-100 rounded-2xl overflow-hidden">
          <button 
            onClick={() => setShowMeta(!showMeta)}
            className="w-full px-4 py-3 bg-zinc-50 flex items-center justify-between hover:bg-zinc-100 transition-colors"
          >
            <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Game Meta Data</span>
            <ChevronDown size={14} className={`text-zinc-400 transition-transform ${showMeta ? 'rotate-180' : ''}`} />
          </button>
          
          {showMeta && (
            <div className="p-4 space-y-4 bg-white border-t border-zinc-100 animate-in slide-in-from-top-2 duration-200">
              <div className="space-y-2">
                <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Node Name</label>
                <input 
                  type="text" 
                  value={node.label} 
                  onChange={(e) => onUpdate({ label: e.target.value })}
                  placeholder="e.g. Fireball"
                  className="w-full px-3 py-2 bg-zinc-50 border border-zinc-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900/5"
                />
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Description</label>
                <textarea 
                  value={node.description || ''} 
                  onChange={(e) => onUpdate({ description: e.target.value })}
                  placeholder="What does this skill do?"
                  rows={3}
                  className="w-full px-3 py-2 bg-zinc-50 border border-zinc-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900/5 resize-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-2">
                  <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Base Value</label>
                  <input 
                    type="number" 
                    value={node.baseValue || 0} 
                    onChange={(e) => onUpdate({ baseValue: parseFloat(e.target.value) })}
                    className="w-full px-3 py-2 bg-zinc-50 border border-zinc-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900/5"
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Buy Value</label>
                  <input 
                    type="number" 
                    value={node.buyValue || 0} 
                    onChange={(e) => onUpdate({ buyValue: parseFloat(e.target.value) })}
                    className="w-full px-3 py-2 bg-zinc-50 border border-zinc-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900/5"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Max Level</label>
                <input 
                  type="number" 
                  value={node.maxLevel || 1} 
                  onChange={(e) => onUpdate({ maxLevel: parseInt(e.target.value) })}
                  className="w-full px-3 py-2 bg-zinc-50 border border-zinc-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900/5"
                />
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Label Color</label>
                <div className="flex items-center gap-3">
                  <input 
                    type="color" 
                    value={node.labelColor || '#1a1a1a'} 
                    onChange={(e) => onUpdate({ labelColor: e.target.value })}
                    className="w-10 h-10 rounded-lg cursor-pointer border-none bg-transparent"
                  />
                  <input 
                    type="text" 
                    value={node.labelColor || '#1a1a1a'} 
                    onChange={(e) => onUpdate({ labelColor: e.target.value })}
                    className="flex-1 px-3 py-2 bg-zinc-50 border border-zinc-200 rounded-xl text-sm font-mono"
                  />
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">State</label>
        <div className="grid grid-cols-3 gap-2">
          {(['locked', 'available', 'unlocked'] as const).map(s => (
            <button
              key={s}
              onClick={() => onUpdate({ state: s })}
              className={`px-2 py-1.5 rounded-lg text-[10px] font-bold uppercase tracking-tight border transition-all ${
                node.state === s 
                  ? 'bg-zinc-900 border-zinc-900 text-white shadow-sm' 
                  : 'bg-white border-zinc-200 text-zinc-400 hover:border-zinc-300'
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Shape</label>
        <div className="grid grid-cols-4 gap-2">
          {(['circle', 'square', 'hexagon', 'image'] as const).map(s => (
            <button
              key={s}
              onClick={() => onUpdate({ shape: s })}
              className={`px-2 py-1.5 rounded-lg text-[10px] font-bold uppercase tracking-tight border transition-all ${
                node.shape === s 
                  ? 'bg-zinc-900 border-zinc-900 text-white shadow-sm' 
                  : 'bg-white border-zinc-200 text-zinc-400 hover:border-zinc-300'
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      {node.shape === 'image' && (
        <div className="space-y-2">
          <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Custom Image</label>
          <input 
            type="file" 
            ref={fileInputRef}
            onChange={handleImageUpload}
            accept="image/*"
            className="hidden"
          />
          <div className="space-y-3">
            <button 
              onClick={() => fileInputRef.current?.click()}
              className="w-full px-3 py-4 border-2 border-dashed border-zinc-200 rounded-xl flex flex-col items-center gap-2 hover:border-zinc-300 transition-colors"
            >
              <Upload size={20} className="text-zinc-400" />
              <span className="text-xs text-zinc-500">Upload PNG / JPG...</span>
            </button>
            
            {node.imageUrl && (
              <div className="flex items-center gap-3 p-2 bg-zinc-50 rounded-xl border border-zinc-100">
                <img src={node.imageUrl} className="w-10 h-10 rounded-lg object-cover" alt="Preview" />
                <button 
                  onClick={() => onUpdate({ imageUrl: undefined })}
                  className="text-xs font-bold text-red-500 hover:text-red-600"
                >
                  Remove
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Color</label>
        <ColorPicker color={node.color} onChange={(color) => onUpdate({ color })} />
      </div>

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Border Thickness</label>
        <input 
          type="range" min="1" max="10" 
          value={node.borderWidth || 2} 
          onChange={(e) => onUpdate({ borderWidth: parseInt(e.target.value) })}
          className="w-full accent-zinc-900"
        />
      </div>

      <button 
        onClick={onDelete}
        className="w-full py-3 bg-red-50 text-red-500 rounded-xl text-xs font-bold hover:bg-red-100 transition-colors flex items-center justify-center gap-2"
      >
        <Trash2 size={14} />
        Delete Node
      </button>
    </div>
  );
}

function EdgeInspector({ edge, onUpdate, onDelete }: { edge: Edge, onUpdate: (u: Partial<Edge>) => void, onDelete: () => void }) {
  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Curve Type</label>
        <div className="grid grid-cols-2 gap-2">
          {(['straight', 'curved', 'stepped', 'angled'] as const).map(t => (
            <button
              key={t}
              onClick={() => onUpdate({ curveType: t })}
              className={`px-2 py-1.5 rounded-lg text-[10px] font-bold uppercase tracking-tight border transition-all ${
                (edge.curveType || 'curved') === t 
                  ? 'bg-zinc-900 border-zinc-900 text-white shadow-sm' 
                  : 'bg-white border-zinc-200 text-zinc-400 hover:border-zinc-300'
              }`}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Line Color</label>
        <ColorPicker color={edge.color} onChange={(color) => onUpdate({ color })} />
      </div>

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Line Width</label>
        <input 
          type="range" min="1" max="10" 
          value={edge.width || 2} 
          onChange={(e) => onUpdate({ width: parseInt(e.target.value) })}
          className="w-full accent-zinc-900"
        />
      </div>

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Line Style</label>
        <div className="grid grid-cols-3 gap-2">
          {(['solid', 'dashed', 'dotted'] as const).map(s => (
            <button
              key={s}
              onClick={() => onUpdate({ style: s })}
              className={`px-2 py-1.5 rounded-lg text-[10px] font-bold uppercase tracking-tight border transition-all ${
                edge.style === s 
                  ? 'bg-zinc-900 border-zinc-900 text-white shadow-sm' 
                  : 'bg-white border-zinc-200 text-zinc-400 hover:border-zinc-300'
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      <button 
        onClick={onDelete}
        className="w-full py-3 bg-red-50 text-red-500 rounded-xl text-xs font-bold hover:bg-red-100 transition-colors flex items-center justify-center gap-2"
      >
        <Trash2 size={14} />
        Delete Connection
      </button>
    </div>
  );
}

function TileInspector({ tile, cellKey, onUpdate, onDelete }: { tile: TileStyle, cellKey: string, onUpdate: (u: Partial<TileStyle>) => void, onDelete: () => void }) {
  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Cell Key</label>
        <div className="px-3 py-2 bg-zinc-50 border border-zinc-200 rounded-xl text-xs font-mono text-zinc-500">
          {cellKey}
        </div>
      </div>

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Tile Color</label>
        <ColorPicker color={tile.color} onChange={(color) => onUpdate({ color })} />
      </div>

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Lane Line Width</label>
        <input 
          type="range" min="0" max="10" 
          value={tile.lineWidth ?? 2} 
          onChange={(e) => onUpdate({ lineWidth: parseInt(e.target.value) })}
          className="w-full accent-zinc-900"
        />
      </div>

      <div className="space-y-2">
        <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Dot Size</label>
        <input 
          type="range" min="0" max="10" 
          value={tile.dotSize ?? 2} 
          onChange={(e) => onUpdate({ dotSize: parseInt(e.target.value) })}
          className="w-full accent-zinc-900"
        />
      </div>

      <button 
        onClick={onDelete}
        className="w-full py-3 bg-red-50 text-red-500 rounded-xl text-xs font-bold hover:bg-red-100 transition-colors flex items-center justify-center gap-2"
      >
        <Trash2 size={14} />
        Erase Tile
      </button>
    </div>
  );
}
