import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth, OperationType, handleFirestoreError } from '../hooks/useAuth';
import { 
  collection, 
  query, 
  where, 
  orderBy, 
  onSnapshot, 
  getDoc,
  addDoc, 
  deleteDoc, 
  doc, 
  serverTimestamp,
  Timestamp
} from 'firebase/firestore';
import { db } from '../firebase';
import { 
  Plus, 
  Search, 
  LayoutGrid, 
  List, 
  MoreVertical, 
  TreeDeciduous, 
  LogOut, 
  Settings,
  Clock,
  Trash2,
  Copy,
  Download,
  Share2,
  FolderOpen,
  Zap
} from 'lucide-react';

interface Project {
  id: string;
  name: string;
  description: string | null;
  thumbnail: string | null;
  updatedAt: Timestamp | null;
  isPublic: boolean;
}

export default function Dashboard() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');
  const [searchQuery, setSearchQuery] = useState('');
  const [isNewModalOpen, setIsNewModalOpen] = useState(false);
  const [newName, setNewName] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [guestProject, setGuestProject] = useState<any>(null);
  const [isImportingGuest, setIsImportingGuest] = useState(false);
  const [projectToDelete, setProjectToDelete] = useState<string | null>(null);
  
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    const saved = localStorage.getItem('guest_project');
    if (saved) {
      try {
        setGuestProject(JSON.parse(saved));
      } catch (e) {
        console.error('Failed to parse guest project', e);
      }
    }
  }, []);

  useEffect(() => {
    if (!user) return;

    const q = query(
      collection(db, 'projects'),
      where('userId', '==', user.id),
      orderBy('updatedAt', 'desc')
    );

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const projs = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Project[];
      setProjects(projs);
      setLoading(false);
    }, (error) => {
      console.error('Error fetching projects:', error);
      setLoading(false);
      handleFirestoreError(error, OperationType.LIST, 'projects');
    });

    return () => unsubscribe();
  }, [user]);

  const handleCreateProject = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    try {
      const docRef = await addDoc(collection(db, 'projects'), {
        userId: user.id,
        name: newName,
        description: newDesc,
        isPublic: false,
        treeData: {
          tiles: {},
          nodes: {},
          edges: [],
          defaultTile: { color: "#b8b4aa", lineWidth: 2, dotSize: 5 },
          defaultEdge: { color: "#f59e0b", width: 2, style: "solid" }
        },
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      navigate(`/editor/${docRef.id}`);
    } catch (error: any) {
      console.error('Create project error:', error);
      handleFirestoreError(error, OperationType.CREATE, 'projects');
      alert(error.message || 'Failed to create project');
    }
  };

  const handleDeleteProject = async () => {
    if (!projectToDelete) return;
    try {
      await deleteDoc(doc(db, 'projects', projectToDelete));
      setProjectToDelete(null);
    } catch (error: any) {
      console.error('Delete project error:', error);
      handleFirestoreError(error, OperationType.DELETE, `projects/${projectToDelete}`);
    }
  };

  const handleDuplicateProject = async (project: Project) => {
    if (!user) return;
    try {
      const projectRef = doc(db, 'projects', project.id);
      const projectSnap = await getDoc(projectRef);
      if (!projectSnap.exists()) return;

      const originalData = projectSnap.data();
      await addDoc(collection(db, 'projects'), {
        ...originalData,
        name: `${originalData.name} (Copy)`,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    } catch (error: any) {
      console.error('Duplicate project error:', error);
      handleFirestoreError(error, OperationType.CREATE, 'projects');
    }
  };

  const handleImportGuestProject = async () => {
    if (!user || !guestProject) return;
    setIsImportingGuest(true);
    try {
      const docRef = await addDoc(collection(db, 'projects'), {
        userId: user.id,
        name: 'My Guest Project',
        description: 'Imported from guest session',
        isPublic: false,
        treeData: {
          tiles: guestProject.tiles || {},
          nodes: guestProject.nodes || {},
          edges: guestProject.edges || [],
          defaultTile: guestProject.defaultTile || { color: "#b8b4aa", lineWidth: 2, dotSize: 5 },
          defaultEdge: guestProject.defaultEdge || { color: "#f59e0b", width: 2, style: "solid" }
        },
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      localStorage.removeItem('guest_project');
      setGuestProject(null);
      navigate(`/editor/${docRef.id}`);
    } catch (error: any) {
      console.error('Import guest project error:', error);
      handleFirestoreError(error, OperationType.CREATE, 'projects');
      alert('Failed to import guest project');
    } finally {
      setIsImportingGuest(false);
    }
  };

  const filteredProjects = projects.filter(p => 
    p.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="min-h-screen bg-[#f5f4f0]">
      {/* Navbar */}
      <nav className="h-16 bg-white border-b border-[#e2e0da] px-6 flex items-center justify-between sticky top-0 z-10">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-emerald-100 rounded-lg flex items-center justify-center">
            <TreeDeciduous className="text-emerald-700" size={20} />
          </div>
          <span className="font-semibold text-zinc-900">Skill Tree Planner</span>
        </div>

        <div className="flex items-center gap-4">
          <div className="flex flex-col items-end mr-2">
            <span className="text-sm font-medium text-zinc-900">{user?.displayName}</span>
          </div>
          <div className="group relative">
            <div className="w-10 h-10 bg-zinc-100 rounded-full flex items-center justify-center cursor-pointer border border-zinc-200 overflow-hidden">
              {user?.photoURL ? (
                <img src={user.photoURL} alt="Avatar" className="w-full h-full object-cover" />
              ) : (
                <span className="text-zinc-500 font-medium">{user?.displayName[0]}</span>
              )}
            </div>
            <div className="absolute right-0 top-full pt-2 hidden group-hover:block w-48">
              <div className="bg-white rounded-xl border border-[#e2e0da] shadow-lg overflow-hidden">
                <button className="w-full px-4 py-2.5 text-left text-sm text-zinc-700 hover:bg-zinc-50 flex items-center gap-2">
                  <Settings size={16} /> Settings
                </button>
                <button 
                  onClick={logout}
                  className="w-full px-4 py-2.5 text-left text-sm text-red-600 hover:bg-red-50 flex items-center gap-2 border-t border-zinc-100"
                >
                  <LogOut size={16} /> Logout
                </button>
              </div>
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto px-6 py-8">
        {guestProject && (
          <div className="mb-8 p-6 bg-emerald-50 border border-emerald-100 rounded-3xl flex flex-col md:flex-row items-center justify-between gap-4 animate-in fade-in slide-in-from-top-4 duration-500">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-emerald-100 rounded-2xl flex items-center justify-center">
                <Zap className="text-emerald-700" size={24} />
              </div>
              <div>
                <h3 className="text-sm font-bold text-zinc-900 uppercase tracking-tight">Guest Project Detected</h3>
                <p className="text-xs text-zinc-500">You have a project from your guest session. Would you like to save it to your cloud account?</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <button 
                onClick={() => {
                  localStorage.removeItem('guest_project');
                  setGuestProject(null);
                }}
                className="px-4 py-2 text-xs font-bold text-zinc-400 hover:text-zinc-600 uppercase tracking-widest"
              >
                Discard
              </button>
              <button 
                onClick={handleImportGuestProject}
                disabled={isImportingGuest}
                className="px-6 py-2 bg-emerald-700 text-white text-xs font-bold rounded-xl hover:bg-emerald-800 transition-all shadow-sm shadow-emerald-700/20 uppercase tracking-widest disabled:opacity-50"
              >
                {isImportingGuest ? 'Importing...' : 'Save to Cloud'}
              </button>
            </div>
          </div>
        )}

        <div className="flex items-center justify-between mb-8">
          <h1 className="text-2xl font-semibold text-zinc-900">My Projects</h1>
          <button 
            onClick={() => setIsNewModalOpen(true)}
            className="flex items-center gap-2 px-4 py-2 bg-emerald-700 hover:bg-emerald-800 text-white font-medium rounded-xl transition-colors shadow-sm"
          >
            <Plus size={20} /> New Project
          </button>
        </div>

        <div className="flex flex-col md:flex-row gap-4 mb-8">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-400" size={18} />
            <input 
              type="text" 
              placeholder="Search projects..."
              className="w-full pl-10 pr-4 py-2.5 bg-white border border-[#e2e0da] rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
          <div className="flex items-center bg-white border border-[#e2e0da] rounded-xl p-1">
            <button 
              onClick={() => setViewMode('grid')}
              className={`p-1.5 rounded-lg transition-colors ${viewMode === 'grid' ? 'bg-zinc-100 text-zinc-900' : 'text-zinc-400 hover:text-zinc-600'}`}
            >
              <LayoutGrid size={20} />
            </button>
            <button 
              onClick={() => setViewMode('list')}
              className={`p-1.5 rounded-lg transition-colors ${viewMode === 'list' ? 'bg-zinc-100 text-zinc-900' : 'text-zinc-400 hover:text-zinc-600'}`}
            >
              <List size={20} />
            </button>
          </div>
        </div>

        {loading ? (
          <div className="flex flex-col items-center justify-center py-20">
            <div className="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-emerald-600 mb-4"></div>
            <p className="text-zinc-500 text-sm">Loading your projects...</p>
          </div>
        ) : filteredProjects.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 bg-white rounded-3xl border border-dashed border-zinc-300">
            <div className="w-16 h-16 bg-zinc-50 rounded-2xl flex items-center justify-center mb-4">
              <FolderOpen className="text-zinc-300" size={32} />
            </div>
            <h3 className="text-lg font-medium text-zinc-900">No projects found</h3>
            <p className="text-zinc-500 text-sm mt-1">Create your first skill tree to get started.</p>
            <button 
              onClick={() => setIsNewModalOpen(true)}
              className="mt-6 px-6 py-2 bg-emerald-700 text-white font-medium rounded-xl hover:bg-emerald-800 transition-colors"
            >
              Create Project
            </button>
          </div>
        ) : (
          <div className={viewMode === 'grid' ? 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6' : 'space-y-4'}>
            {filteredProjects.map(project => (
              <ProjectCard 
                key={project.id} 
                project={project} 
                viewMode={viewMode}
                onDelete={(id) => setProjectToDelete(id)}
                onDuplicate={handleDuplicateProject}
              />
            ))}
          </div>
        )}
      </main>

      {/* Delete Confirmation Modal */}
      {projectToDelete && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white w-full max-w-sm rounded-3xl border border-[#e2e0da] p-8 shadow-2xl animate-in zoom-in-95 duration-200">
            <div className="flex flex-col items-center text-center">
              <div className="w-16 h-16 bg-red-50 rounded-2xl flex items-center justify-center mb-6">
                <Trash2 className="text-red-600" size={32} />
              </div>
              <h2 className="text-xl font-bold text-zinc-900 mb-2">Delete Project?</h2>
              <p className="text-zinc-500 text-sm mb-8 leading-relaxed">
                This action cannot be undone. All data associated with this project will be permanently removed.
              </p>
              
              <div className="flex flex-col w-full gap-3">
                <button 
                  onClick={handleDeleteProject}
                  className="w-full py-3.5 bg-red-600 text-white font-bold rounded-2xl hover:bg-red-700 transition-all shadow-lg shadow-red-600/10"
                >
                  Delete Permanently
                </button>
                <button 
                  onClick={() => setProjectToDelete(null)}
                  className="w-full py-3.5 bg-white border border-[#e2e0da] text-zinc-700 font-bold rounded-2xl hover:bg-zinc-50 transition-all"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* New Project Modal */}
      {isNewModalOpen && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white w-full max-w-md rounded-2xl border border-[#e2e0da] p-6 shadow-2xl">
            <h2 className="text-xl font-semibold text-zinc-900 mb-4">New Project</h2>
            <form onSubmit={handleCreateProject} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-zinc-700 mb-1">Project Name</label>
                <input 
                  type="text" 
                  required
                  maxLength={60}
                  className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all"
                  placeholder="My Epic Skill Tree"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  autoFocus
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-zinc-700 mb-1">Description (Optional)</label>
                <textarea 
                  className="w-full px-4 py-2.5 bg-zinc-50 border border-zinc-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all resize-none"
                  placeholder="Briefly describe your project..."
                  rows={3}
                  maxLength={200}
                  value={newDesc}
                  onChange={(e) => setNewDesc(e.target.value)}
                />
              </div>
              <div className="flex gap-3 pt-2">
                <button 
                  type="button"
                  onClick={() => setIsNewModalOpen(false)}
                  className="flex-1 py-2.5 bg-zinc-100 hover:bg-zinc-200 text-zinc-700 font-medium rounded-xl transition-colors"
                >
                  Cancel
                </button>
                <button 
                  type="submit"
                  className="flex-1 py-2.5 bg-emerald-700 hover:bg-emerald-800 text-white font-medium rounded-xl transition-colors shadow-sm"
                >
                  Create Project
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

function ProjectCard({ project, viewMode, onDelete, onDuplicate }: { project: Project, viewMode: 'grid' | 'list', onDelete: (id: string) => void | Promise<void>, onDuplicate: (project: Project) => void | Promise<void>, key?: string }) {
  const navigate = useNavigate();
  const [showMenu, setShowMenu] = useState(false);

  const timeAgo = (timestamp: Timestamp | null) => {
    if (!timestamp) return 'just now';
    const seconds = Math.floor((new Date().getTime() - timestamp.toDate().getTime()) / 1000);
    if (seconds < 60) return 'just now';
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    return `${Math.floor(hours / 24)}d ago`;
  };

  if (viewMode === 'list') {
    return (
      <div className="bg-white border border-[#e2e0da] rounded-xl p-4 flex items-center gap-4 hover:border-emerald-500/50 transition-colors group">
        <div className="w-12 h-12 bg-zinc-50 rounded-lg flex items-center justify-center border border-zinc-100">
          <TreeDeciduous className="text-zinc-300" size={24} />
        </div>
        <div className="flex-1 min-w-0">
          <h3 className="font-medium text-zinc-900 truncate">{project.name}</h3>
          <p className="text-xs text-zinc-500 truncate">{project.description || 'No description'}</p>
        </div>
        <div className="flex items-center gap-6 text-xs text-zinc-400 whitespace-nowrap">
          <div className="flex items-center gap-1.5">
            <Clock size={14} />
            {timeAgo(project.updatedAt)}
          </div>
          {project.isPublic && (
            <div className="flex items-center gap-1.5 text-emerald-600 font-medium">
              <Share2 size={14} />
              Public
            </div>
          )}
        </div>
        <div className="flex items-center gap-2">
          <button 
            onClick={() => navigate(`/editor/${project.id}`)}
            className="px-4 py-1.5 bg-zinc-100 hover:bg-emerald-700 hover:text-white text-zinc-700 text-xs font-medium rounded-lg transition-all"
          >
            Open
          </button>
          <div className="relative">
            <button 
              onClick={() => setShowMenu(!showMenu)}
              className="p-1.5 text-zinc-400 hover:text-zinc-600 rounded-lg"
            >
              <MoreVertical size={18} />
            </button>
            {showMenu && (
              <div className="absolute right-0 top-full mt-1 w-40 bg-white rounded-xl border border-[#e2e0da] shadow-lg z-10 overflow-hidden">
                <button 
                  onClick={() => {
                    onDuplicate(project);
                    setShowMenu(false);
                  }}
                  className="w-full px-3 py-2 text-left text-xs text-zinc-700 hover:bg-zinc-50 flex items-center gap-2"
                >
                  <Copy size={14} /> Duplicate
                </button>
                <button 
                  onClick={() => onDelete(project.id)}
                  className="w-full px-3 py-2 text-left text-xs text-red-600 hover:bg-red-50 flex items-center gap-2 border-t border-zinc-100"
                >
                  <Trash2 size={14} /> Delete
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white border border-[#e2e0da] rounded-2xl overflow-hidden hover:border-emerald-500/50 transition-all group flex flex-col shadow-sm hover:shadow-md">
      <div 
        onClick={() => navigate(`/editor/${project.id}`)}
        className="h-36 bg-zinc-50 flex items-center justify-center border-b border-zinc-100 cursor-pointer relative overflow-hidden"
      >
        {project.thumbnail ? (
          <img src={project.thumbnail} alt={project.name} className="w-full h-full object-cover" />
        ) : (
          <TreeDeciduous className="text-zinc-200" size={48} />
        )}
        <div className="absolute inset-0 bg-emerald-900/0 group-hover:bg-emerald-900/5 transition-colors"></div>
      </div>
      <div className="p-4 flex-1 flex flex-col">
        <div className="flex items-start justify-between mb-1">
          <h3 className="font-semibold text-zinc-900 truncate flex-1">{project.name}</h3>
          <div className="relative">
            <button 
              onClick={() => setShowMenu(!showMenu)}
              className="p-1 text-zinc-400 hover:text-zinc-600 rounded-lg ml-2"
            >
              <MoreVertical size={16} />
            </button>
            {showMenu && (
              <div className="absolute right-0 top-full mt-1 w-40 bg-white rounded-xl border border-[#e2e0da] shadow-lg z-10 overflow-hidden">
                <button 
                  onClick={() => {
                    onDuplicate(project);
                    setShowMenu(false);
                  }}
                  className="w-full px-3 py-2 text-left text-xs text-zinc-700 hover:bg-zinc-50 flex items-center gap-2"
                >
                  <Copy size={14} /> Duplicate
                </button>
                <button 
                  onClick={() => onDelete(project.id)}
                  className="w-full px-3 py-2 text-left text-xs text-red-600 hover:bg-red-50 flex items-center gap-2 border-t border-zinc-100"
                >
                  <Trash2 size={14} /> Delete
                </button>
              </div>
            )}
          </div>
        </div>
        <p className="text-xs text-zinc-500 line-clamp-2 mb-4 h-8">{project.description || 'No description provided'}</p>
        
        <div className="mt-auto flex items-center justify-between">
          <div className="flex items-center gap-1.5 text-[10px] text-zinc-400 uppercase tracking-wider font-medium">
            <Clock size={12} />
            {timeAgo(project.updatedAt)}
          </div>
          <button 
            onClick={() => navigate(`/editor/${project.id}`)}
            className="px-4 py-1.5 bg-zinc-100 group-hover:bg-emerald-700 group-hover:text-white text-zinc-700 text-xs font-semibold rounded-lg transition-all"
          >
            Open Editor
          </button>
        </div>
      </div>
    </div>
  );
}
