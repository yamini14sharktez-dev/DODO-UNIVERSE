import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { ServiceCategory, FormDefinition, FormField } from '../types';
import { EmptyState } from '../components/common/EmptyState';
import { Badge } from '../components/common/Badge';
import {
  Plus,
  Trash2,
  MoveUp,
  MoveDown,
  Save,
  CheckCircle,
  FileText,
  Hash,
  Phone,
  Mail,
  List,
  CheckSquare,
  Calendar,
  UploadCloud,
  Image,
} from 'lucide-react';

export const FormBuilder: React.FC = () => {
  const [categories, setCategories] = useState<ServiceCategory[]>([]);
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>('');
  const [formDef, setFormDef] = useState<FormDefinition | null>(null);
  const [title, setTitle] = useState('');
  const [fields, setFields] = useState<FormField[]>([]);
  const [version, setVersion] = useState(1);
  const [status, setStatus] = useState<'draft' | 'published' | 'archived'>('draft');
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  useEffect(() => {
    const loadCategories = async () => {
      try {
        const cats: ServiceCategory[] = await api.getCategories();
        setCategories(cats);
        if (cats.length > 0 && !selectedCategoryId) {
          setSelectedCategoryId(cats[0].id);
        }
      } catch (err) {
        console.error(err);
      }
    };
    loadCategories();
  }, []);

  useEffect(() => {
    if (!selectedCategoryId) return;
    const loadForm = async () => {
      setIsLoading(true);
      setSaveSuccess(false);
      try {
        const def: FormDefinition = await api.getFormDefinition(selectedCategoryId);
        setFormDef(def);
        setTitle(def.title);
        setFields(def.schema.fields || []);
        setVersion(def.version);
        setStatus(def.status);
      } catch {
        // No form yet, initialize empty
        setFormDef(null);
        setTitle('Vendor Application Form');
        setFields([]);
        setVersion(1);
        setStatus('draft');
      } finally {
        setIsLoading(false);
      }
    };
    loadForm();
  }, [selectedCategoryId]);

  const addField = (type: FormField['type']) => {
    const newField: FormField = {
      id: `field_${Date.now()}`,
      type,
      label: `New ${type.replace(/_/g, ' ')} Field`,
      placeholder: '',
      required: false,
      options: ['dropdown', 'radio'].includes(type) ? ['Option 1', 'Option 2'] : undefined,
    };
    setFields([...fields, newField]);
  };

  const removeField = (id: string) => {
    setFields(fields.filter((f) => f.id !== id));
  };

  const moveField = (index: number, direction: 'up' | 'down') => {
    const targetIndex = direction === 'up' ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= fields.length) return;
    const updated = [...fields];
    const [moved] = updated.splice(index, 1);
    updated.splice(targetIndex, 0, moved);
    setFields(updated);
  };

  const updateField = (id: string, updates: Partial<FormField>) => {
    setFields(fields.map((f) => (f.id === id ? { ...f, ...updates } : f)));
  };

  const handleSave = async (publish = false) => {
    if (!selectedCategoryId) return;
    setIsSaving(true);
    setSaveSuccess(false);
    try {
      const payload: Partial<FormDefinition> = {
        title,
        status: publish ? 'published' : status,
        version: publish ? version + 1 : version,
        schema: {
          fields,
        },
      };
      const saved = await api.saveFormDefinition(selectedCategoryId, payload);
      setFormDef(saved);
      if (publish) setVersion((v) => v + 1);
      if (publish) setStatus('published');
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch (err: any) {
      alert(err.message || 'Failed to save form definition');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-slate-800">Dynamic Service Form Builder</h2>
          <p className="text-xs text-slate-500">
            Configure custom verification and onboarding forms for each service category without code deployment.
          </p>
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-2">
          {saveSuccess && (
            <span className="text-xs font-semibold text-emerald-700 bg-emerald-50 px-3 py-1.5 rounded-lg border border-emerald-200 flex items-center gap-1.5 animate-fade-in">
              <CheckCircle className="w-3.5 h-3.5" />
              Saved Successfully!
            </span>
          )}
          <button
            onClick={() => handleSave(false)}
            disabled={isSaving}
            className="px-4 py-2 border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 rounded-xl text-xs font-bold transition flex items-center gap-1.5"
          >
            <Save className="w-3.5 h-3.5" />
            Save Draft
          </button>
          <button
            onClick={() => handleSave(true)}
            disabled={isSaving}
            className="px-4 py-2 bg-pine-700 hover:bg-pine-800 text-white rounded-xl text-xs font-bold transition flex items-center gap-1.5 shadow-sm"
          >
            <CheckCircle className="w-3.5 h-3.5" />
            Publish Version {version + 1}
          </button>
        </div>
      </div>

      {/* Category Selector Bar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 flex flex-col sm:flex-row sm:items-center justify-between gap-4 shadow-sm text-xs">
        <div className="flex items-center gap-3">
          <label className="font-bold text-slate-700">Target Category:</label>
          <select
            value={selectedCategoryId}
            onChange={(e) => setSelectedCategoryId(e.target.value)}
            className="p-2 bg-slate-50 border border-slate-200 rounded-xl font-semibold text-slate-800 focus:outline-none focus:ring-2 focus:ring-pine-500/20"
          >
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name} ({c.category_type})
              </option>
            ))}
          </select>
        </div>

        <div className="flex items-center gap-3">
          <span className="text-slate-400">Current Form Status:</span>
          <Badge status={status} />
          <span className="text-slate-400 font-mono">v{version}.0</span>
        </div>
      </div>

      {/* Main Builder Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Available Field Palette */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm space-y-3 h-fit">
          <h3 className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
            Add Form Elements
          </h3>
          <div className="grid grid-cols-1 gap-2 text-xs">
            {[
              { type: 'text', label: 'Single-line Text', icon: FileText },
              { type: 'number', label: 'Numeric Quantity', icon: Hash },
              { type: 'phone', label: 'Phone Number', icon: Phone },
              { type: 'email', label: 'Email Address', icon: Mail },
              { type: 'dropdown', label: 'Select Dropdown', icon: List },
              { type: 'checkbox', label: 'Checkbox', icon: CheckSquare },
              { type: 'date', label: 'Date Picker', icon: Calendar },
              { type: 'document_upload', label: 'PDF / Document', icon: UploadCloud },
              { type: 'image_upload', label: 'Image Upload', icon: Image },
            ].map((f) => {
              const Icon = f.icon;
              return (
                <button
                  key={f.type}
                  onClick={() => addField(f.type as any)}
                  className="flex items-center gap-2.5 p-2.5 rounded-xl border border-slate-200 hover:border-pine-400 hover:bg-pine-50/50 text-slate-700 text-left transition group font-medium"
                >
                  <Icon className="w-4 h-4 text-slate-400 group-hover:text-pine-700 transition" />
                  <span>{f.label}</span>
                  <Plus className="w-3.5 h-3.5 ml-auto text-slate-300 group-hover:text-pine-600 transition" />
                </button>
              );
            })}
          </div>
        </div>

        {/* Dynamic Form Editor Canvas */}
        <div className="lg:col-span-3 bg-white p-6 rounded-2xl border border-slate-200 shadow-sm space-y-6">
          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1">Form Title</label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm font-bold text-slate-800 focus:bg-white focus:outline-none focus:ring-2 focus:ring-pine-500/20"
              placeholder="e.g. Electrician Verification & Compliance Form"
            />
          </div>

          <div className="space-y-4">
            <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider">
              Form Fields ({fields.length})
            </h4>

            {fields.length === 0 ? (
              <EmptyState
                title="Canvas is empty"
                description="Click any element from the left panel to insert fields into this form."
              />
            ) : (
              fields.map((field, idx) => (
                <div
                  key={field.id}
                  className="p-4 rounded-xl border border-slate-200 bg-slate-50/50 space-y-3 hover:border-slate-300 transition"
                >
                  <div className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2">
                      <span className="w-5 h-5 rounded-full bg-slate-200 text-slate-600 font-bold flex items-center justify-center text-[10px]">
                        {idx + 1}
                      </span>
                      <span className="font-bold text-slate-700 uppercase tracking-wider text-[10px]">
                        {field.type.replace(/_/g, ' ')}
                      </span>
                    </div>

                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => moveField(idx, 'up')}
                        disabled={idx === 0}
                        className="p-1 text-slate-400 hover:text-slate-600 disabled:opacity-30"
                      >
                        <MoveUp className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={() => moveField(idx, 'down')}
                        disabled={idx === fields.length - 1}
                        className="p-1 text-slate-400 hover:text-slate-600 disabled:opacity-30"
                      >
                        <MoveDown className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={() => removeField(field.id)}
                        className="p-1 text-slate-400 hover:text-rose-600 ml-1"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                    <div>
                      <label className="block text-slate-500 font-medium mb-1">Field Label</label>
                      <input
                        type="text"
                        value={field.label}
                        onChange={(e) => updateField(field.id, { label: e.target.value })}
                        className="w-full p-2 bg-white border border-slate-200 rounded-lg focus:outline-none focus:ring-1 focus:ring-pine-500"
                      />
                    </div>
                    <div>
                      <label className="block text-slate-500 font-medium mb-1">Placeholder</label>
                      <input
                        type="text"
                        value={field.placeholder || ''}
                        onChange={(e) => updateField(field.id, { placeholder: e.target.value })}
                        className="w-full p-2 bg-white border border-slate-200 rounded-lg focus:outline-none focus:ring-1 focus:ring-pine-500"
                      />
                    </div>
                  </div>

                  {/* Options editor for dropdowns */}
                  {['dropdown', 'radio'].includes(field.type) && (
                    <div className="text-xs">
                      <label className="block text-slate-500 font-medium mb-1">
                        Options (comma separated)
                      </label>
                      <input
                        type="text"
                        value={(field.options || []).join(', ')}
                        onChange={(e) =>
                          updateField(field.id, {
                            options: e.target.value.split(',').map((s) => s.trim()),
                          })
                        }
                        className="w-full p-2 bg-white border border-slate-200 rounded-lg focus:outline-none focus:ring-1 focus:ring-pine-500"
                        placeholder="Option 1, Option 2, Option 3"
                      />
                    </div>
                  )}

                  <div className="flex items-center gap-4 text-xs pt-1">
                    <label className="flex items-center gap-1.5 cursor-pointer text-slate-600 font-medium">
                      <input
                        type="checkbox"
                        checked={field.required}
                        onChange={(e) => updateField(field.id, { required: e.target.checked })}
                        className="w-3.5 h-3.5 text-pine-700 rounded border-slate-300"
                      />
                      <span>Required Field</span>
                    </label>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
