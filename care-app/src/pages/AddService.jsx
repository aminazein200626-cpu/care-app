import React, { useState, useEffect } from 'react';

const AddService = ({ isDarkMode }) => {
  const [selectedSlots, setSelectedSlots] = useState([]);
  const [serviceImage, setServiceImage] = useState(null);
  const [policyFile, setPolicyFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");
  
  const [serviceName, setServiceName] = useState("");
  const [basePrice, setBasePrice] = useState("");
  const [description, setDescription] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("");
  const [categories, setCategories] = useState([]);

  const fetchCategories = async () => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch('http://localhost:5000/api/admin/categories', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();
      setCategories(data);
      if (data.length > 0) setSelectedCategory(data[0]._id);
    } catch (error) {
      console.error('Error fetching categories:', error);
    }
  };

  useEffect(() => {
    fetchCategories();
  }, []);

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    accent: '#a3e635',
    primary: '#1a2e05'
  };

  const toggleSlot = (slot) => {
    if (selectedSlots.includes(slot)) {
      setSelectedSlots(selectedSlots.filter(s => s !== slot));
    } else {
      setSelectedSlots([...selectedSlots, slot]);
    }
  };

  const handleImageChange = (e) => {
    if (e.target.files[0]) {
      setServiceImage(URL.createObjectURL(e.target.files[0]));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!serviceName.trim()) {
      setError("Service name is required");
      return;
    }
    if (!basePrice.trim()) {
      setError("Base price is required");
      return;
    }
    if (!selectedCategory) {
      setError("Please select a category");
      return;
    }
    
    setLoading(true);
    setError("");
    setSuccess(false);
    
    const token = localStorage.getItem('token');
    const selectedCategoryObj = categories.find(c => c._id === selectedCategory);
    
    try {
      const response = await fetch('http://localhost:5000/api/admin/services', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          name: serviceName,
          price: parseInt(basePrice),
          categoryId: selectedCategory,
          category: selectedCategoryObj?.name || '',
          description: description,
          slots: selectedSlots.join(', ')
        })
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        // إذا كان الخطأ بسبب اسم مكرر
        if (data.message && data.message.includes('already exists')) {
          setError(`Service "${serviceName}" already exists. Please use a different name.`);
        } else {
          throw new Error(data.message || 'Failed to create service');
        }
        setLoading(false);
        return;
      }
      
      setSuccess(true);
      setServiceName("");
      setBasePrice("");
      setDescription("");
      setSelectedSlots([]);
      setServiceImage(null);
      setPolicyFile(null);
      
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", maxWidth: '1000px', margin: '0 auto' }}>
      <div style={{ marginBottom: '30px' }}>
        <h2 style={{ color: '#1a2e05', fontSize: '28px', fontWeight: '800', letterSpacing: '-1px' }}>Deploy New Service</h2>
        <p style={{ color: '#737373', fontSize: '14px' }}>Configure service details, pricing, and availability</p>
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
          ✅ Service created successfully!
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

      <form onSubmit={handleSubmit}>
        <div style={{ 
          backgroundColor: theme.card, 
          padding: '40px', 
          borderRadius: '35px', 
          border: `1px solid ${theme.border}`,
          boxShadow: '0 10px 30px rgba(0,0,0,0.05)'
        }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '30px' }}>
            
            {/* Left Column */}
            <div>
              <label style={{ fontSize: '12px', fontWeight: '600', color: theme.accent, display: 'block', marginBottom: '8px', letterSpacing: '0.5px' }}>
                SERVICE IMAGE
              </label>
              <div
                onClick={() => document.getElementById('imgUpload').click()}
                style={{
                  width: '100%',
                  height: '160px',
                  backgroundColor: theme.input,
                  border: `2px dashed ${theme.accent}`,
                  borderRadius: '20px',
                  display: 'flex',
                  flexDirection: 'column',
                  justifyContent: 'center',
                  alignItems: 'center',
                  overflow: 'hidden',
                  cursor: 'pointer',
                  marginBottom: '25px',
                  transition: 'all 0.2s'
                }}
              >
                {serviceImage ? (
                  <img src={serviceImage} alt="Preview" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                ) : (
                  <>
                    <span style={{ fontSize: '32px' }}>🖼️</span>
                    <p style={{ fontSize: '12px', color: theme.accent, marginTop: '8px' }}>Click to upload image</p>
                  </>
                )}
                <input type="file" id="imgUpload" hidden accept="image/*" onChange={handleImageChange} />
              </div>

              <label style={{ fontSize: '12px', fontWeight: '600', color: theme.accent, display: 'block', marginBottom: '8px', letterSpacing: '0.5px' }}>
                TIME SLOTS
              </label>
              <div style={{ display: 'flex', gap: '12px', marginBottom: '25px' }}>
                {['Morning', 'Afternoon', 'Evening', 'Night'].map(time => {
                  const isActive = selectedSlots.includes(time);
                  return (
                    <button 
                      key={time} 
                      type="button"
                      onClick={() => toggleSlot(time)}
                      style={{ 
                        flex: 1, 
                        padding: '10px', 
                        backgroundColor: isActive ? theme.accent : theme.primary, 
                        border: `1px solid ${theme.accent}`, 
                        color: isActive ? '#000' : theme.accent, 
                        borderRadius: '12px', 
                        fontSize: '11px', 
                        fontWeight: '600', 
                        cursor: 'pointer',
                        transition: 'all 0.2s'
                      }}>
                      {time}
                    </button>
                  );
                })}
              </div>

              <label style={{ fontSize: '12px', fontWeight: '600', color: theme.accent, display: 'block', marginBottom: '8px', letterSpacing: '0.5px' }}>
                CATEGORY
              </label>
              <select 
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                style={{ 
                  width: '100%', 
                  padding: '14px 16px', 
                  backgroundColor: theme.input, 
                  border: `1px solid ${theme.border}`, 
                  borderRadius: '14px', 
                  color: theme.text, 
                  outline: 'none',
                  fontSize: '14px',
                  marginBottom: '25px',
                  cursor: 'pointer'
                }}
              >
                {categories.map(cat => (
                  <option key={cat._id} value={cat._id}>{cat.name}</option>
                ))}
              </select>
            </div>

            {/* Right Column */}
            <div>
              <label style={{ fontSize: '12px', fontWeight: '600', color: theme.accent, display: 'block', marginBottom: '8px', letterSpacing: '0.5px' }}>
                SERVICE NAME
              </label>
              <input 
                type="text" 
                placeholder="e.g., Newborn Specialist, Night Nurse..." 
                value={serviceName}
                onChange={(e) => setServiceName(e.target.value)}
                style={{ 
                  width: '100%', 
                  padding: '14px 16px', 
                  backgroundColor: theme.input, 
                  border: `1px solid ${theme.border}`, 
                  borderRadius: '14px', 
                  color: theme.text, 
                  marginBottom: '25px', 
                  outline: 'none',
                  fontSize: '14px'
                }} 
              />

              <label style={{ fontSize: '12px', fontWeight: '600', color: theme.accent, display: 'block', marginBottom: '8px', letterSpacing: '0.5px' }}>
                BASE PRICE (DZD)
              </label>
              <input 
                type="number" 
                placeholder="e.g., 3500" 
                value={basePrice}
                onChange={(e) => setBasePrice(e.target.value)}
                style={{ 
                  width: '100%', 
                  padding: '14px 16px', 
                  backgroundColor: theme.input, 
                  border: `1px solid ${theme.border}`, 
                  borderRadius: '14px', 
                  color: theme.text, 
                  marginBottom: '25px', 
                  outline: 'none',
                  fontSize: '14px'
                }} 
              />

              <label style={{ fontSize: '12px', fontWeight: '600', color: theme.accent, display: 'block', marginBottom: '8px', letterSpacing: '0.5px' }}>
                LEGAL POLICY (PDF)
              </label>
              <div style={{ 
                padding: '14px', 
                backgroundColor: theme.input, 
                border: `1px dashed ${theme.accent}`, 
                borderRadius: '14px', 
                textAlign: 'center',
                marginBottom: '25px',
                cursor: 'pointer'
              }}>
                <input type="file" id="policyUp" hidden accept=".pdf" onChange={(e) => setPolicyFile(e.target.files[0]?.name)} />
                <label htmlFor="policyUp" style={{ cursor: 'pointer', color: policyFile ? theme.accent : '#737373', fontSize: '13px', fontWeight: '500' }}>
                  {policyFile ? `✅ ${policyFile}` : '📁 Upload Terms & Conditions (PDF)'}
                </label>
              </div>

              <label style={{ fontSize: '12px', fontWeight: '600', color: theme.accent, display: 'block', marginBottom: '8px', letterSpacing: '0.5px' }}>
                SERVICE DESCRIPTION
              </label>
              <textarea 
                placeholder="Describe what this service includes, special features, requirements..." 
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                style={{ 
                  width: '100%', 
                  height: '100px', 
                  padding: '14px 16px', 
                  backgroundColor: theme.input, 
                  border: `1px solid ${theme.border}`, 
                  borderRadius: '14px', 
                  color: theme.text, 
                  resize: 'vertical', 
                  outline: 'none',
                  fontSize: '13px',
                  fontFamily: 'inherit'
                }} 
              />
            </div>
          </div>

          <button 
            type="submit"
            disabled={loading}
            style={{ 
              width: '100%', 
              padding: '18px', 
              backgroundColor: theme.accent, 
              color: '#000', 
              border: 'none', 
              borderRadius: '22px', 
              fontWeight: '800', 
              fontSize: '16px', 
              cursor: loading ? 'not-allowed' : 'pointer', 
              marginTop: '30px',
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
                <span>⏳</span> PUBLISHING...
              </>
            ) : (
              <>
                <span>✨</span> AUTHORIZE & PUBLISH SERVICE
              </>
            )}
          </button>
        </div>
      </form>
    </div>
  );
};

export default AddService;