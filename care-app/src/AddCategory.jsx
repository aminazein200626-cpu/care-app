import React, { useState } from 'react';

const AddCategory = ({ isDarkMode }) => {
  const [catName, setCatName] = useState("");
  const [desc, setDesc] = useState("");
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    accent: '#a3e635',
    primary: '#1a2e05'
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!catName.trim()) {
      setError("Category name is required");
      return;
    }
    
    setLoading(true);
    setError("");
    setSuccess(false);
    
    const token = localStorage.getItem('token');
    
    try {
      const response = await fetch('http://localhost:5001/api/admin/categories', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name: catName, description: desc })
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        // Check if error is due to duplicate name
        if (data.message && data.message.includes('already exists')) {
          setError(`Category "${catName}" already exists. Please use a different name.`);
        } else {
          throw new Error(data.message || 'Failed to create category');
        }
        setLoading(false);
        return;
      }
      
      setSuccess(true);
      setCatName("");
      setDesc("");
      
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", maxWidth: '700px', margin: '0 auto' }}>
      <div style={{ marginBottom: '30px' }}>
        <h2 style={{ color: '#1a2e05', fontSize: '28px', fontWeight: '800', letterSpacing: '-1px' }}>Create New Category</h2>
        <p style={{ color: '#737373', fontSize: '14px' }}>Define a major service department for your platform</p>
      </div>

      {success && (
        <div style={{ 
          backgroundColor: '#10b981', 
          color: 'white', 
          padding: '12px 20px', 
          borderRadius: '12px', 
          marginBottom: '20px',
          fontSize: '14px'
        }}>
          ✅ Category created successfully!
        </div>
      )}
      
      {error && (
        <div style={{ 
          backgroundColor: '#ef4444', 
          color: 'white', 
          padding: '12px 20px', 
          borderRadius: '12px', 
          marginBottom: '20px',
          fontSize: '14px'
        }}>
          ❌ {error}
        </div>
      )}

      <div style={{ 
        backgroundColor: theme.card, 
        padding: '40px', 
        borderRadius: '30px', 
        border: `1px solid ${theme.border}`,
        boxShadow: '0 10px 30px rgba(0,0,0,0.05)'
      }}>
        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: '24px' }}>
            <label style={{ 
              fontSize: '13px', 
              fontWeight: '600', 
              color: theme.accent, 
              display: 'block', 
              marginBottom: '8px',
              letterSpacing: '0.5px'
            }}>
              Category Name
            </label>
            <input 
              type="text" 
              placeholder="e.g. Pediatric Nursing, Mental Health Support..." 
              value={catName}
              style={{ 
                width: '100%', 
                padding: '14px 18px', 
                backgroundColor: theme.input, 
                border: `1px solid ${theme.border}`, 
                borderRadius: '14px', 
                color: theme.text, 
                outline: 'none',
                fontSize: '15px',
                transition: 'all 0.2s'
              }}
              onChange={(e) => setCatName(e.target.value)}
              disabled={loading}
            />
          </div>

          <div style={{ marginBottom: '30px' }}>
            <label style={{ 
              fontSize: '13px', 
              fontWeight: '600', 
              color: theme.accent, 
              display: 'block', 
              marginBottom: '8px',
              letterSpacing: '0.5px'
            }}>
              Description
            </label>
            <textarea 
              placeholder="Describe the scope and purpose of this category..." 
              value={desc}
              style={{ 
                width: '100%', 
                height: '120px', 
                padding: '14px 18px', 
                backgroundColor: theme.input, 
                border: `1px solid ${theme.border}`, 
                borderRadius: '14px', 
                color: theme.text, 
                outline: 'none', 
                resize: 'vertical',
                fontSize: '14px',
                fontFamily: 'inherit'
              }}
              onChange={(e) => setDesc(e.target.value)}
              disabled={loading}
            />
          </div>

          <button 
            type="submit"
            disabled={loading}
            style={{ 
              width: '100%', 
              padding: '16px', 
              backgroundColor: theme.primary, 
              color: theme.accent, 
              border: `1px solid ${theme.accent}`, 
              borderRadius: '16px', 
              fontWeight: '700',
              fontSize: '15px',
              cursor: loading ? 'not-allowed' : 'pointer', 
              opacity: loading ? 0.6 : 1,
              transition: 'all 0.2s',
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            {loading ? (
              <>
                <span>⏳</span> CREATING...
              </>
            ) : (
              <>
                <span>✨</span> CREATE CATEGORY
              </>
            )}
          </button>
        </form>
        
        <div style={{ 
          marginTop: '24px', 
          paddingTop: '20px', 
          borderTop: `1px solid ${theme.border}`,
          fontSize: '12px',
          color: '#737373',
          textAlign: 'center'
        }}>
          <span>📌 Categories help organize services and make them easier to find</span>
        </div>
      </div>
    </div>
  );
};

export default AddCategory;