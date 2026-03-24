import { useState, useEffect, useCallback } from 'react';
import { doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase';
import { handleFirestoreError, OperationType } from './useAuth';

export function useCloudSave(projectId: string, treeData: any) {
  const [status, setStatus] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle');
  const [lastSavedAt, setLastSavedAt] = useState<Date | null>(null);

  const save = useCallback(async () => {
    if (!projectId) return;
    setStatus('saving');
    try {
      const projectRef = doc(db, 'projects', projectId);
      await updateDoc(projectRef, { 
        treeData,
        updatedAt: serverTimestamp()
      });
      setStatus('saved');
      setLastSavedAt(new Date());
      setTimeout(() => setStatus('idle'), 3000);
    } catch (error) {
      console.error('Save error:', error);
      setStatus('error');
      handleFirestoreError(error, OperationType.UPDATE, `projects/${projectId}`);
    }
  }, [projectId, treeData]);

  // Auto-save every 5 seconds
  useEffect(() => {
    const timer = setInterval(() => {
      save();
    }, 5000);
    return () => clearInterval(timer);
  }, [save]);

  return { status, lastSavedAt, save };
}
