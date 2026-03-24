import { X, Download, FileJson, FileCode, CheckCircle2, Copy, Image as ImageIcon } from 'lucide-react';
import { useState } from 'react';
import { buildGenericJSON } from '../../utils/exportJson';
import { buildGodotZip } from '../../utils/exportGodot';

interface ExportModalProps {
  tiles: any;
  nodes: any;
  edges: any;
  projectName: string;
  onClose: () => void;
  onExportPNG: (transparent: boolean) => void;
}

export default function ExportModal({ tiles, nodes, edges, projectName, onClose, onExportPNG }: ExportModalProps) {
  const [activeTab, setActiveTab] = useState<'JSON' | 'PNG' | 'Godot' | 'Unity' | 'Unreal'>('JSON');
  const [copied, setCopied] = useState(false);
  const [pngTransparent, setPngTransparent] = useState(false);

  const handleCopy = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const downloadFile = (blob: Blob, filename: string) => {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  };

  const exportJSON = () => {
    const data = buildGenericJSON(tiles, nodes, edges, projectName);
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    downloadFile(blob, `${projectName.toLowerCase().replace(/\s+/g, '_')}_tree.json`);
  };

  const exportGodot = async () => {
    const blob = await buildGodotZip(tiles, nodes, edges, projectName);
    downloadFile(blob, `${projectName.toLowerCase().replace(/\s+/g, '_')}_godot.zip`);
  };

  return (
    <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white w-full max-w-3xl rounded-3xl border border-[#e2e0da] shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        <div className="p-6 border-b border-zinc-100 flex items-center justify-between">
          <div>
            <h2 className="text-xl font-bold text-zinc-900">Export Project</h2>
            <p className="text-sm text-zinc-500">Choose your target game engine or format</p>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-zinc-100 rounded-xl text-zinc-400">
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 flex overflow-hidden">
          {/* Sidebar Tabs */}
          <div className="w-48 bg-zinc-50 border-r border-zinc-100 p-2 space-y-1">
            {(['JSON', 'PNG', 'Godot', 'Unity', 'Unreal'] as const).map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`w-full px-4 py-3 rounded-xl text-sm font-semibold flex items-center gap-3 transition-all ${
                  activeTab === tab 
                    ? 'bg-white text-emerald-700 shadow-sm border border-zinc-200' 
                    : 'text-zinc-500 hover:bg-zinc-100'
                }`}
              >
                {tab === 'JSON' ? <FileJson size={18} /> : 
                 tab === 'PNG' ? <ImageIcon size={18} /> :
                 <FileCode size={18} />}
                {tab}
              </button>
            ))}
          </div>

          {/* Content */}
          <div className="flex-1 p-8 overflow-y-auto">
            {activeTab === 'JSON' && (
              <div className="space-y-6">
                <div className="p-6 bg-emerald-50 rounded-2xl border border-emerald-100">
                  <h3 className="font-bold text-emerald-900 mb-2">Generic JSON Export</h3>
                  <p className="text-sm text-emerald-700 leading-relaxed">
                    A universal data format containing all nodes, edges, and metadata. Perfect for custom game engines or web integrations.
                  </p>
                </div>
                
                <div className="bg-zinc-900 rounded-2xl p-4 relative group">
                  <pre className="text-[10px] text-emerald-400 font-mono overflow-x-auto h-48">
                    {JSON.stringify(buildGenericJSON(tiles, nodes, edges, projectName), null, 2)}
                  </pre>
                  <button 
                    onClick={() => handleCopy(JSON.stringify(buildGenericJSON(tiles, nodes, edges, projectName), null, 2))}
                    className="absolute top-4 right-4 p-2 bg-white/10 hover:bg-white/20 text-white rounded-lg transition-all"
                  >
                    {copied ? <CheckCircle2 size={16} /> : <Copy size={16} />}
                  </button>
                </div>

                <button 
                  onClick={exportJSON}
                  className="w-full py-4 bg-emerald-700 hover:bg-emerald-800 text-white font-bold rounded-2xl transition-all shadow-lg shadow-emerald-700/20 flex items-center justify-center gap-2"
                >
                  <Download size={20} /> Download JSON
                </button>
              </div>
            )}

            {activeTab === 'PNG' && (
              <div className="space-y-6">
                <div className="p-6 bg-amber-50 rounded-2xl border border-amber-100">
                  <h3 className="font-bold text-amber-900 mb-2">High-Resolution PNG</h3>
                  <p className="text-sm text-amber-700 leading-relaxed">
                    Export the current view of your skill tree as a high-quality PNG image. Perfect for sharing or documentation.
                  </p>
                </div>
                
                <div className="flex flex-col items-center justify-center py-8 border-2 border-dashed border-zinc-100 rounded-2xl space-y-4">
                  <ImageIcon size={48} className="text-zinc-200" />
                  <div className="text-center">
                    <p className="text-sm text-zinc-400">Current viewport will be captured at 4x resolution</p>
                  </div>
                  
                  <label className="flex items-center gap-3 cursor-pointer p-3 bg-zinc-50 rounded-xl hover:bg-zinc-100 transition-colors">
                    <input 
                      type="checkbox" 
                      checked={pngTransparent} 
                      onChange={(e) => setPngTransparent(e.target.checked)}
                      className="w-4 h-4 accent-emerald-600 rounded"
                    />
                    <span className="text-xs font-bold text-zinc-600 uppercase tracking-tight">Transparent Background</span>
                  </label>
                </div>

                <button 
                  onClick={() => onExportPNG(pngTransparent)}
                  className="w-full py-4 bg-amber-600 hover:bg-amber-700 text-white font-bold rounded-2xl transition-all shadow-lg shadow-amber-600/20 flex items-center justify-center gap-2"
                >
                  <Download size={20} /> Download PNG
                </button>
              </div>
            )}

            {activeTab === 'Godot' && (
              <div className="space-y-6">
                <div className="p-6 bg-blue-50 rounded-2xl border border-blue-100">
                  <h3 className="font-bold text-blue-900 mb-2">Godot 4 Bundle</h3>
                  <p className="text-sm text-blue-700 leading-relaxed">
                    Includes a <code className="bg-blue-100 px-1 rounded">skill_tree.json</code> and a <code className="bg-blue-100 px-1 rounded">skill_tree_loader.gd</code> AutoLoad script.
                  </p>
                </div>

                <div className="space-y-4">
                  <h4 className="text-sm font-bold text-zinc-900">Setup Instructions</h4>
                  <ol className="text-xs text-zinc-500 space-y-3 list-decimal pl-4">
                    <li>Copy the exported files into your Godot project.</li>
                    <li>Go to Project &gt; Project Settings &gt; AutoLoad.</li>
                    <li>Add <code className="text-zinc-900">skill_tree_loader.gd</code> as "SkillTreeLoader".</li>
                    <li>Access your tree anywhere: <code className="text-zinc-900">SkillTreeLoader.unlock("node_id")</code></li>
                  </ol>
                </div>

                <button 
                  onClick={exportGodot}
                  className="w-full py-4 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-2xl transition-all shadow-lg shadow-blue-600/20 flex items-center justify-center gap-2"
                >
                  <Download size={20} /> Download Godot ZIP
                </button>
              </div>
            )}

            {(activeTab === 'Unity' || activeTab === 'Unreal') && (
              <div className="flex flex-col items-center justify-center py-12 text-center">
                <div className="w-16 h-16 bg-zinc-50 rounded-2xl flex items-center justify-center mb-4">
                  <Zap size={32} className="text-zinc-300" />
                </div>
                <h3 className="font-bold text-zinc-900">Coming Soon</h3>
                <p className="text-sm text-zinc-500 max-w-xs mt-2">
                  Unity and Unreal Engine export bundles are currently in development. Use JSON export for now.
                </p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

import { Zap } from 'lucide-react';
