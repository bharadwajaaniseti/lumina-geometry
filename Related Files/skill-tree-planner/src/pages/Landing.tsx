import { TreeDeciduous, Zap, Layout, ShieldAlert, Chrome } from 'lucide-react';
import { Link, useNavigate, Navigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

export default function Landing() {
  const { loginWithGoogle, user, isLoading } = useAuth();
  const navigate = useNavigate();

  const handleGoogleLogin = async () => {
    try {
      await loginWithGoogle();
      navigate('/dashboard');
    } catch (error) {
      console.error('Login failed:', error);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#f5f4f0] flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-emerald-600"></div>
      </div>
    );
  }

  if (user) {
    return <Navigate to="/dashboard" replace />;
  }

  return (
    <div className="min-h-screen bg-[#f5f4f0] text-zinc-900 font-sans flex flex-col items-center justify-center p-6">
      <div className="max-w-md w-full space-y-8 text-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-16 h-16 bg-emerald-100 rounded-2xl flex items-center justify-center shadow-sm">
            <TreeDeciduous className="text-emerald-700" size={32} />
          </div>
          <h1 className="text-3xl font-bold tracking-tight text-zinc-900">Skill Tree Planner</h1>
          <p className="text-zinc-500 text-sm leading-relaxed">
            The professional visual editor for game progression systems. 
            Design, iterate, and export your skill trees with ease.
          </p>
        </div>

        <div className="bg-white p-8 rounded-3xl border border-[#e2e0da] shadow-sm space-y-6">
          <button 
            onClick={handleGoogleLogin}
            className="w-full flex items-center justify-center gap-3 px-6 py-4 bg-zinc-900 text-white font-bold rounded-2xl hover:bg-black transition-all shadow-lg shadow-black/10 group"
          >
            <Chrome size={20} className="group-hover:scale-110 transition-transform" />
            Continue with Google
          </button>

          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-zinc-100"></div>
            </div>
            <div className="relative flex justify-center text-xs uppercase tracking-widest font-bold text-zinc-400">
              <span className="bg-white px-4">Or</span>
            </div>
          </div>

          <Link 
            to="/editor" 
            className="w-full flex items-center justify-center gap-3 px-6 py-4 bg-white border border-[#e2e0da] text-zinc-700 font-bold rounded-2xl hover:bg-zinc-50 transition-all"
          >
            Continue as Guest
          </Link>

          <div className="flex items-start gap-3 p-4 bg-amber-50 rounded-2xl border border-amber-100 text-left">
            <ShieldAlert className="text-amber-600 shrink-0" size={18} />
            <p className="text-[11px] text-amber-800 leading-normal">
              <strong>Guest Warning:</strong> Your progress will be saved locally in this browser only. 
              Sign in to sync your projects across devices and prevent data loss.
            </p>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-4 opacity-40 grayscale">
          <div className="flex flex-col items-center gap-2">
            <Zap size={20} />
            <span className="text-[10px] font-bold uppercase tracking-widest">Fast</span>
          </div>
          <div className="flex flex-col items-center gap-2">
            <Layout size={20} />
            <span className="text-[10px] font-bold uppercase tracking-widest">Visual</span>
          </div>
          <div className="flex flex-col items-center gap-2">
            <TreeDeciduous size={20} />
            <span className="text-[10px] font-bold uppercase tracking-widest">Scalable</span>
          </div>
        </div>
      </div>
      
      <p className="mt-12 text-zinc-400 text-xs">
        © 2026 Skill Tree Planner. All rights reserved.
      </p>
    </div>
  );
}
