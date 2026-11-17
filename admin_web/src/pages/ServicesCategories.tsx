import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { ServiceCategory } from '../types';
import { Badge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { EmptyState } from '../components/common/EmptyState';
import {
  FolderTree,
  Plus,
  ChevronRight,
  ChevronDown,
  Edit2,
  Trash2,
  Layers,
  Box,
  Wrench,
  Check,
} from 'lucide-react';

export const ServicesCategories: React.FC = () => {
  const [tree, setTree] = useState<ServiceCategory[]>([]);
  const [flatList, setFlatList] = useState<ServiceCategory[]>([]);
  const [expandedNodes, setExpandedNodes] = useState<Record<string, boolean>>({});
  const [isLoading, setIsLoading] = useState(false);

  // Add/Edit Modal
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState<ServiceCategory | null>(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [parentId, setParentId] = useState<string>('');
  const [categoryType, setCategoryType] = useState<'container' | 'product_category' | 'bookable_service' | 'hybrid'>('container');
  const [allowListings, setAllowListings] = useState(false);
  const [sortOrder, setSortOrder] = useState(0);

  const fetchCategories = async () => {
    setIsLoading(true);
    try {
      const data: ServiceCategory[] = await api.getCategories();
      setTree(data);

      // Flatten for parent selection dropdown
      const flattened: ServiceCategory[] = [];
      const traverse = (nodes: ServiceCategory[]) => {
        nodes.forEach((n) => {
          flattened.push(n);
          if (n.children && n.children.length > 0) {
            traverse(n.children);
          }
        });
      };
      traverse(data);
      setFlatList(flattened);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchCategories();
  }, []);

  const toggleExpand = (id: string) => {
    setExpandedNodes((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  const openCreateModal = (parent?: ServiceCategory) => {
    setEditingCategory(null);
    setName('');
    setDescription('');
    setParentId(parent ? parent.id : '');
    setCategoryType(parent ? 'product_category' : 'container');
    setAllowListings(false);
    setSortOrder(0);
    setIsModalOpen(true);
  };

  const openEditModal = (cat: ServiceCategory) => {
    setEditingCategory(cat);
    setName(cat.name);
    setDescription(cat.description || '');
    setParentId(cat.parent_id || '');
    setCategoryType(cat.category_type);
    setAllowListings(cat.allow_listings);
    setSortOrder(cat.sort_order);
    setIsModalOpen(true);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    const payload = {
      name,
      description,
      parent_id: parentId || null,
      category_type: categoryType,
      allow_listings: allowListings,
      sort_order: Number(sortOrder) || 0,
      is_active: editingCategory ? editingCategory.is_active : true,
    };

    try {
      if (editingCategory) {
        await api.updateCategory(editingCategory.id, payload);
      } else {
        await api.createCategory(payload);
      }
      setIsModalOpen(false);
      await fetchCategories();
    } catch (err: any) {
      alert(err.message || 'Failed to save category');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this category? All nested subcategories will also be deleted.')) return;
    try {
      await api.deleteCategory(id);
      await fetchCategories();
    } catch (err: any) {
      alert(err.message || 'Failed to delete category');
    }
  };

  const renderCategoryNode = (node: ServiceCategory, depth = 0) => {
    const hasChildren = node.children && node.children.length > 0;
    const isExpanded = expandedNodes[node.id];

    return (
      <div key={node.id} className="space-y-1">
        <div
          style={{ paddingLeft: `${depth * 28 + 12}px` }}
          className="flex items-center justify-between py-2.5 pr-4 rounded-xl hover:bg-slate-50 border border-transparent hover:border-slate-200 transition-all group"
        >
          <div className="flex items-center gap-2">
            {hasChildren ? (
              <button
                onClick={() => toggleExpand(node.id)}
                className="p-1 rounded text-slate-400 hover:text-slate-600 hover:bg-slate-200/50"
              >
                {isExpanded ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
              </button>
            ) : (
              <span className="w-6" />
            )}

            {node.category_type === 'container' ? (
              <Layers className="w-4 h-4 text-pine-700 shrink-0" />
            ) : node.category_type === 'bookable_service' ? (
              <Wrench className="w-4 h-4 text-amber-600 shrink-0" />
            ) : (
              <Box className="w-4 h-4 text-sky-600 shrink-0" />
            )}

            <span className="text-xs font-bold text-slate-800">{node.name}</span>
            <span className="text-[10px] text-slate-400 font-mono">({node.slug})</span>

            <Badge status={node.category_type} className="scale-90" />
            {node.allow_listings && (
              <span className="text-[10px] font-semibold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                Listings Allowed
              </span>
            )}
          </div>

          <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
            <button
              onClick={() => openCreateModal(node)}
              className="p-1.5 text-slate-400 hover:text-pine-700 hover:bg-pine-50 rounded-lg transition"
              title="Add Nested Child Category"
            >
              <Plus className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => openEditModal(node)}
              className="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition"
              title="Edit Category"
            >
              <Edit2 className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => handleDelete(node.id)}
              className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
              title="Delete Category"
            >
              <Trash2 className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

        {hasChildren && isExpanded && (
          <div className="space-y-1">
            {node.children!.map((child) => renderCategoryNode(child, depth + 1))}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-slate-800">Unlimited Services & Categories Hierarchy</h2>
          <p className="text-xs text-slate-500">
            Define container categories, bookable services, and product categories at infinite nesting depths.
          </p>
        </div>

        <button
          onClick={() => openCreateModal()}
          className="px-4 py-2 bg-pine-700 hover:bg-pine-800 text-white rounded-xl text-xs font-bold transition flex items-center gap-2 shadow-sm"
        >
          <Plus className="w-4 h-4" />
          Create Root Service / Category
        </button>
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
        {isLoading ? (
          <div className="py-12 text-center text-slate-400 text-xs">Loading hierarchical category tree...</div>
        ) : tree.length === 0 ? (
          <EmptyState
            title="No services or categories configured yet"
            description="Create your initial service containers and nested product categories to organize platform listings."
            action={
              <button
                onClick={() => openCreateModal()}
                className="px-4 py-2 bg-pine-700 text-white rounded-xl text-xs font-bold hover:bg-pine-800 transition"
              >
                Create First Category
              </button>
            }
          />
        ) : (
          <div className="space-y-1">{tree.map((node) => renderCategoryNode(node, 0))}</div>
        )}
      </div>

      {/* Add / Edit Category Modal */}
      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title={editingCategory ? 'Edit Category' : 'Create New Category'}
        maxWidth="lg"
      >
        <form onSubmit={handleSave} className="space-y-4 text-xs">
          <div>
            <label className="block font-bold text-slate-700 mb-1">Category Name</label>
            <input
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Red Clay Bricks, Electrical Repairs..."
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:ring-2 focus:ring-pine-500/20 focus:outline-none"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Parent Category (Nesting Level)</label>
            <select
              value={parentId}
              onChange={(e) => setParentId(e.target.value)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:ring-2 focus:ring-pine-500/20 focus:outline-none"
            >
              <option value="">(None - Top-level Root Category)</option>
              {flatList
                .filter((c) => !editingCategory || c.id !== editingCategory.id)
                .map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name} ({c.category_type})
                  </option>
                ))}
            </select>
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Category Classification</label>
            <select
              value={categoryType}
              onChange={(e) => setCategoryType(e.target.value as any)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:ring-2 focus:ring-pine-500/20 focus:outline-none"
            >
              <option value="container">Container (Folder for subcategories only)</option>
              <option value="product_category">Product Category (Goods, materials, bricks, etc.)</option>
              <option value="bookable_service">Bookable Service (Electrician, plumbing, etc.)</option>
              <option value="hybrid">Hybrid (Product + Transportation / Services)</option>
            </select>
          </div>

          <div className="flex items-center gap-2 p-3 bg-slate-50 border border-slate-200 rounded-xl">
            <input
              type="checkbox"
              id="allowListings"
              checked={allowListings}
              onChange={(e) => setAllowListings(e.target.checked)}
              className="w-4 h-4 text-pine-700 rounded border-slate-300 focus:ring-pine-500"
            />
            <label htmlFor="allowListings" className="font-semibold text-slate-700 cursor-pointer">
              Allow vendors to publish listings directly under this category
            </label>
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Description (Optional)</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Short description for customer and vendor guidance..."
              rows={2}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:ring-2 focus:ring-pine-500/20 focus:outline-none"
            />
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
            <button
              type="button"
              onClick={() => setIsModalOpen(false)}
              className="px-4 py-2 border border-slate-200 rounded-xl text-slate-600 hover:bg-slate-50 font-semibold"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-5 py-2 bg-pine-700 hover:bg-pine-800 text-white rounded-xl font-bold transition shadow-sm"
            >
              {editingCategory ? 'Update Category' : 'Save Category'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
};
