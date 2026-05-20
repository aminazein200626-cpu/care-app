import React, { useState, useEffect } from 'react';

const ConsultCategories = ({ isDarkMode }) => {
  const [categories, setCategories] = useState([]);
  const [editingCategory, setEditingCategory] = useState(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(null);
  const [loading, setLoading] = useState(true);

  // Fetch categories from API
  const fetchCategories = async () => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch('http://localhost:5001/api/admin/categories', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();
      
      // Convert API data to same format as original
      const formattedCategories = data.map(cat => ({
        id: cat.id,
        name: cat.name,
        description: cat.description,
        date: cat.createdAt ? cat.createdAt.split('T')[0] : '2026-03-01'
      }));
      
      setCategories(formattedCategories);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching categories:', error);
      setLoading(false);
    }
  };

  // Add new category (via AddCategory page - will be called from there)
  const addCategory = async (name, description) => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch('http://localhost:5001/api/admin/categories', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name, description })
      });
      const data = await response.json();
      fetchCategories(); // Refresh list
      return data;
    } catch (error) {
      console.error('Error adding category:', error);
    }
  };

  // Update category
  const updateCategory = async (id, name, description) => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch(`http://localhost:5001/api/admin/categories/${id}`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name, description })
      });
      const data = await response.json();
      fetchCategories(); // Refresh list
      return data;
    } catch (error) {
      console.error('Error updating category:', error);
    }
  };

  // Delete category
  const deleteCategory = async (id) => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch(`http://localhost:5001/api/admin/categories/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      fetchCategories(); // Refresh list
    } catch (error) {
      console.error('Error deleting category:', error);
    }
  };

  useEffect(() => {
    fetchCategories();
  }, []);

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    accent: '#a3e635',
    primary: '#1a2e05'
  };

  const handleDelete = (category) => {
    setShowDeleteConfirm(category);
  };

  const confirmDelete = () => {
    deleteCategory(showDeleteConfirm.id);
    setShowDeleteConfirm(null);
  };

  const handleUpdate = (category) => {
    setEditingCategory({ ...category });
  };

  const saveUpdate = () => {
    updateCategory(editingCategory.id, editingCategory.name, editingCategory.description);
    setEditingCategory(null);
  };

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading categories...</div>;
  }

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div style={{ marginBottom: '30px' }}>
        <h2 style={{ color: '#1a2e05', fontSize: '24px', fontWeight: '800' }}>📁 Categories Management</h2>
        <p style={{ color: '#737373', fontSize: '14px' }}>Manage service categories, update descriptions, or remove categories</p>
      </div>

      <div style={{ 
        backgroundColor: theme.card, 
        borderRadius: '25px', 
        border: `1px solid ${theme.border}`, 
        overflow: 'hidden',
        boxShadow: '0 10px 30px rgba(0,0,0,0.1)'
      }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
          <thead>
            <tr style={{ backgroundColor: theme.primary, color: theme.accent, textAlign: 'left' }}>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '1px' }}>Category Name</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '1px' }}>Description</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '1px' }}>Created At</th>
              <th style={{ padding: '15px 20px', textAlign: 'center', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '1px' }}>Actions</th>
              </tr>
          </thead>
          <tbody>
            {categories.map(cat => (
              <tr key={cat.id} style={{ borderBottom: `1px solid ${theme.border}` }}>
                <td style={{ padding: '15px 20px', fontWeight: '700', color: theme.text }}>{cat.name}</td>
                <td style={{ padding: '15px 20px', opacity: 0.7, color: theme.text }}>{cat.description}</td>
                <td style={{ padding: '15px 20px', opacity: 0.5, fontSize: '11px', color: theme.text }}>{cat.date}</td>
                <td style={{ padding: '15px 20px', textAlign: 'center' }}>
                  <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
                    <button 
                      onClick={() => handleUpdate(cat)}
                      style={{ 
                        background: 'none', 
                        border: `1px solid ${theme.accent}`, 
                        color: theme.accent, 
                        padding: '6px 12px', 
                        borderRadius: '8px', 
                        cursor: 'pointer', 
                        fontSize: '11px',
                        fontWeight: '600'
                      }}
                    >
                      ✏️ Edit
                    </button>
                    <button 
                      onClick={() => handleDelete(cat)}
                      style={{ 
                        background: 'none', 
                        border: `1px solid #dc2626`, 
                        color: '#dc2626', 
                        padding: '6px 12px', 
                        borderRadius: '8px', 
                        cursor: 'pointer', 
                        fontSize: '11px',
                        fontWeight: '600'
                      }}
                    >
                      🗑️ Delete
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Edit Modal */}
      {editingCategory && (
        <div style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.9)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 2000, backdropFilter: 'blur(8px)' }}>
          <div style={{ backgroundColor: theme.card, padding: '40px', borderRadius: '30px', width: '500px', border: `1px solid ${theme.accent}` }}>
            <h3 style={{ color: theme.accent, marginBottom: '25px', fontSize: '22px' }}>Edit Category</h3>
            <label style={{ fontSize: '11px', color: '#737373', marginBottom: '5px', display: 'block' }}>CATEGORY NAME</label>
            <input 
              type="text" 
              value={editingCategory.name} 
              onChange={(e) => setEditingCategory({...editingCategory, name: e.target.value})} 
              style={{ width: '100%', padding: '14px', marginBottom: '20px', borderRadius: '12px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, outline: 'none' }} 
            />
            <label style={{ fontSize: '11px', color: '#737373', marginBottom: '5px', display: 'block' }}>DESCRIPTION</label>
            <textarea 
              value={editingCategory.description} 
              onChange={(e) => setEditingCategory({...editingCategory, description: e.target.value})} 
              style={{ width: '100%', padding: '14px', marginBottom: '25px', borderRadius: '12px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, outline: 'none', minHeight: '100px', resize: 'vertical' }} 
            />
            <div style={{ display: 'flex', gap: '15px' }}>
              <button onClick={saveUpdate} style={{ flex: 1, padding: '14px', backgroundColor: theme.accent, color: '#000', border: 'none', borderRadius: '15px', fontWeight: 'bold', cursor: 'pointer' }}>
                Save Changes
              </button>
              <button onClick={() => setEditingCategory(null)} style={{ flex: 1, padding: '14px', backgroundColor: '#333', color: '#fff', border: 'none', borderRadius: '15px', cursor: 'pointer' }}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.9)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 2000, backdropFilter: 'blur(8px)' }}>
          <div style={{ backgroundColor: theme.card, padding: '40px', borderRadius: '30px', width: '400px', textAlign: 'center', border: `1px solid ${theme.accent}` }}>
            <span style={{ fontSize: '50px' }}>⚠️</span>
            <h3 style={{ color: theme.text, marginBottom: '10px' }}>Delete Category</h3>
            <p style={{ color: '#737373', marginBottom: '15px' }}>
              Are you sure you want to delete "{showDeleteConfirm.name}"?
            </p>
            <p style={{ color: '#f59e0b', fontSize: '12px', marginBottom: '30px' }}>
              Warning: Services under this category will also be removed.
            </p>
            <div style={{ display: 'flex', gap: '15px' }}>
              <button onClick={confirmDelete} style={{ flex: 1, padding: '12px', backgroundColor: '#dc2626', color: '#fff', border: 'none', borderRadius: '12px', fontWeight: 'bold', cursor: 'pointer' }}>
                Yes, Delete
              </button>
              <button onClick={() => setShowDeleteConfirm(null)} style={{ flex: 1, padding: '12px', backgroundColor: '#333', color: '#fff', border: 'none', borderRadius: '12px', cursor: 'pointer' }}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ConsultCategories;