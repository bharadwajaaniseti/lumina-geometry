import { 
  Paintbrush, 
  Eraser, 
  PlusCircle, 
  Link as LinkIcon, 
  MousePointer2, 
  Undo2, 
  Redo2, 
  Save, 
  Download, 
  Settings,
  TreeDeciduous,
  ArrowLeft,
  ChevronDown,
  AlertTriangle,
  X
} from 'lucide-react';
import { Tool, TileStyle, Edge } from './SkillTreeCanvas';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import { useState } from 'react';

interface ToolbarProps {
  tool: Tool;
  setTool: (tool: Tool) => void;
  onUndo: () => void;
  onRedo: () => void;
  canUndo: boolean;
  canRedo: boolean;
  onSave: () => void;
  saveStatus: string;
  defaultTile: TileStyle;
  setDefaultTile: (tile: TileStyle) => void;
  defaultEdge: Omit<Edge, 'id' | 'from' | 'to'>;
  setDefaultEdge: (edge: Omit<Edge, 'id' | 'from' | 'to'>) => void;
  onExport: () => void;
  onClear: () => void;
  bgColor: string;
  setBgColor: (color: string) => void;
}

export default function Toolbar({
  tool, setTool,
  onUndo, onRedo, canUndo, canRedo,
  onSave, saveStatus,
  defaultTile, setDefaultTile,
  defaultEdge, setDefaultEdge,
  onExport, onClear,
  bgColor, setBgColor
}: ToolbarProps) {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [showExitModal, setShowExitModal] = useState(false);

  const handleBack = () => {
    if (!user) {
      setShowExitModal(true);
    } else {
      navigate('/dashboard');
    }
  };

  const confirmExit = () => {
    navigate('/');
  };

  const tools: { id: Tool; icon: any; label: string }[] = [
    { id: 'P', icon: Paintbrush, label: 'Paint (P)' },
    { id: 'E', icon: Eraser, label: 'Erase (E)' },
    { id: 'N', icon: PlusCircle, label: 'Node (N)' },
    { id: 'C', icon: LinkIcon, label: 'Connect (C)' },
    { id: 'S', icon: MousePointer2, label: 'Select (S)' },
  ];

  return (
    <div className="h-14 bg-white border-b border-[#e2e0da] px-4 flex items-center justify-between shadow-sm z-20 sticky top-0">
      <div className="flex items-center gap-4">
        <button 
          onClick={handleBack}
          className="p-2 hover:bg-zinc-100 rounded-lg text-zinc-500 transition-colors"
        >
          <ArrowLeft size={20} />
        </button>
        <div className="flex items-center gap-2 pr-4 border-r border-zinc-200">
          <div className="w-8 h-8 bg-emerald-100 rounded-lg flex items-center justify-center">
            <TreeDeciduous className="text-emerald-700" size={18} />
          </div>
          <span className="font-semibold text-zinc-900 hidden sm:inline">Editor</span>
        </div>

        <div className="flex items-center bg-zinc-100 p-1 rounded-xl">
          {tools.map(t => (
            <button
              key={t.id}
              onClick={() => setTool(t.id)}
              title={t.label}
              className={`p-1.5 rounded-lg transition-all flex items-center gap-2 px-3 ${
                tool === t.id 
                  ? 'bg-white text-emerald-700 shadow-sm' 
                  : 'text-zinc-500 hover:text-zinc-700'
              }`}
            >
              <t.icon size={18} />
              <span className="text-xs font-medium hidden lg:inline">{t.label.split(' ')[0]}</span>
            </button>
          ))}
        </div>

        <div className="hidden md:flex items-center gap-3 px-4 border-l border-zinc-200 ml-2">
          <div className="flex flex-col">
            <span className="text-[9px] font-bold text-zinc-400 uppercase tracking-widest leading-none mb-1.5">Tile Color</span>
            <div className="flex items-center gap-1.5">
              {['#b8b4aa', '#f59e0b', '#10b981', '#3b82f6', '#ef4444', '#8b5cf6'].map(c => (
                <button
                  key={c}
                  onClick={() => setDefaultTile({ ...defaultTile, color: c })}
                  className={`w-5 h-5 rounded-md border-2 transition-all ${
                    defaultTile.color === c ? 'border-zinc-900 scale-110 shadow-sm' : 'border-white'
                  }`}
                  style={{ backgroundColor: c }}
                />
              ))}
            </div>
          </div>
        </div>

        <div className="hidden xl:flex items-center gap-3 px-4 border-l border-zinc-200 ml-2">
          <div className="flex flex-col">
            <span className="text-[9px] font-bold text-zinc-400 uppercase tracking-widest leading-none mb-1.5">Canvas BG</span>
            <div className="flex items-center gap-1.5">
              {['#f5f4f0', '#ffffff', '#18181b', '#164e63', '#4c1d95', '#701a75'].map(c => (
                <button
                  key={c}
                  onClick={() => setBgColor(c)}
                  className={`w-5 h-5 rounded-md border-2 transition-all ${
                    bgColor === c ? 'border-zinc-900 scale-110 shadow-sm' : 'border-white'
                  }`}
                  style={{ backgroundColor: c }}
                />
              ))}
              <input 
                type="color" 
                value={bgColor} 
                onChange={(e) => setBgColor(e.target.value)}
                className="w-5 h-5 rounded-md border-2 border-white cursor-pointer p-0 overflow-hidden"
              />
            </div>
          </div>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <div className="flex items-center gap-1 mr-2 px-2 border-r border-zinc-200">
          <button 
            onClick={onUndo} 
            disabled={!canUndo}
            className="p-2 text-zinc-500 hover:bg-zinc-100 rounded-lg disabled:opacity-30"
          >
            <Undo2 size={18} />
          </button>
          <button 
            onClick={onRedo} 
            disabled={!canRedo}
            className="p-2 text-zinc-500 hover:bg-zinc-100 rounded-lg disabled:opacity-30"
          >
            <Redo2 size={18} />
          </button>
        </div>

        <div className="flex items-center gap-2">
          <button 
            onClick={onSave}
            className={`flex items-center gap-2 px-4 py-1.5 rounded-xl text-sm font-medium transition-all ${
              saveStatus === 'saving' 
                ? 'bg-zinc-100 text-zinc-400' 
                : saveStatus === 'saved'
                ? 'bg-emerald-50 text-emerald-700'
                : 'bg-emerald-700 text-white hover:bg-emerald-800'
            }`}
          >
            <Save size={16} />
            {saveStatus === 'saving' ? 'Saving...' : saveStatus === 'saved' ? 'Saved ✓' : 'Save'}
          </button>
          
          <button 
            onClick={onExport}
            className="flex items-center gap-2 px-4 py-1.5 bg-zinc-900 text-white hover:bg-black rounded-xl text-sm font-medium transition-all"
          >
            <Download size={16} />
            Export
          </button>
        </div>
      </div>

      {/* Exit Confirmation Modal */}
      {showExitModal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
          <div className="bg-white w-full max-w-sm rounded-3xl border border-[#e2e0da] p-8 shadow-2xl animate-in zoom-in-95 duration-200">
            <div className="flex flex-col items-center text-center">
              <div className="w-16 h-16 bg-amber-100 rounded-2xl flex items-center justify-center mb-6">
                <AlertTriangle className="text-amber-600" size={32} />
              </div>
              <h2 className="text-xl font-bold text-zinc-900 mb-2">Unsaved Progress</h2>
              <p className="text-zinc-500 text-sm mb-8 leading-relaxed">
                You are currently in guest mode. If you leave now, your progress will only be saved in this browser's local storage.
              </p>
              
              <div className="flex flex-col w-full gap-3">
                <button 
                  onClick={confirmExit}
                  className="w-full py-3.5 bg-zinc-900 text-white font-bold rounded-2xl hover:bg-black transition-all shadow-lg shadow-black/10"
                >
                  Leave Editor
                </button>
                <button 
                  onClick={() => setShowExitModal(false)}
                  className="w-full py-3.5 bg-white border border-[#e2e0da] text-zinc-700 font-bold rounded-2xl hover:bg-zinc-50 transition-all"
                >
                  Stay and Design
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
