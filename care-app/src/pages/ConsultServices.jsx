import React, { useState, useEffect } from 'react';

const ConsultServices = ({ isDarkMode }) => {
  const [services, setServices] = useState([]);
  const [editingService, setEditingService] = useState(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("All");
  const [currentPage, setCurrentPage] = useState(1);
  const [servicesPerPage] = useState(6);
  const [loading, setLoading] = useState(true);

  // Fetch services from API
  const fetchServices = async () => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch('http://localhost:5000/api/admin/services', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();
      
      // Convert API data to same format as original
      const formattedServices = data.map(service => ({
        id: service._id,
        name: service.name,
        category: service.category,
        price: `${service.price} DZD`,
        slots: service.slots || 'Flexible',
        description: service.description
      }));
      
      setServices(formattedServices);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching services:', error);
      setLoading(false);
    }
  };

  // Update service
  const updateService = async (id, updatedData) => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch(`http://localhost:5000/api/admin/services/${id}`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(updatedData)
      });
      const data = await response.json();
      fetchServices(); // Refresh list
      return data;
    } catch (error) {
      console.error('Error updating service:', error);
    }
  };

  // Delete service
  const deleteService = async (id) => {
    const token = localStorage.getItem('token');
    try {
      await fetch(`http://localhost:5000/api/admin/services/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      fetchServices(); // Refresh list
    } catch (error) {
      console.error('Error deleting service:', error);
    }
  };

  useEffect(() => {
    fetchServices();
  }, []);

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    accent: '#a3e635',
    primary: '#1a2e05'
  };

  // Get unique categories for filter
  const uniqueCategories = ["All", ...new Set(services.map(s => s.category))];

  // Filter services based on search term and category
  const filteredServices = services.filter(service => {
    const matchesSearch = 
      service.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      service.description.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = categoryFilter === "All" || service.category === categoryFilter;
    return matchesSearch && matchesCategory;
  });

  // Pagination logic
  const indexOfLastService = currentPage * servicesPerPage;
  const indexOfFirstService = indexOfLastService - servicesPerPage;
  const currentServices = filteredServices.slice(indexOfFirstService, indexOfLastService);
  const totalPages = Math.ceil(filteredServices.length / servicesPerPage);

  const paginate = (pageNumber) => setCurrentPage(pageNumber);

  const handleDelete = (service) => {
    setShowDeleteConfirm(service);
  };

  const confirmDelete = () => {
    deleteService(showDeleteConfirm.id);
    setShowDeleteConfirm(null);
  };

  const handleUpdate = (service) => {
    setEditingService({ ...service });
  };

  const saveUpdate = () => {
    const updatedData = {
      name: editingService.name,
      price: parseInt(editingService.price.replace(' DZD', '')),
      category: editingService.category,
      description: editingService.description,
      slots: editingService.slots
    };
    updateService(editingService.id, updatedData);
    setEditingService(null);
  };

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading services...</div>;
  }

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div style={{ marginBottom: '30px' }}>
        <h2 style={{ color: '#1a2e05', fontSize: '24px', fontWeight: '800' }}>🛠️ Services Management</h2>
        <p style={{ color: '#737373', fontSize: '14px' }}>Manage, update, or delete existing services</p>
      </div>

      {/* Search and Filter Bar */}
      <div style={{ 
        display: 'flex', 
        gap: '15px', 
        marginBottom: '30px', 
        flexWrap: 'wrap',
        alignItems: 'center'
      }}>
        <input 
          type="text" 
          placeholder="Search by name or description..." 
          value={searchTerm}
          style={{ 
            flex: 2, 
            minWidth: '250px',
            padding: '12px 18px', 
            borderRadius: '14px', 
            border: `1px solid ${theme.border}`, 
            backgroundColor: theme.input, 
            color: theme.text, 
            outline: 'none' 
          }}
          onChange={(e) => {
            setSearchTerm(e.target.value);
            setCurrentPage(1);
          }}
        />
        
        <select 
          value={categoryFilter}
          style={{ 
            padding: '12px 18px', 
            borderRadius: '14px', 
            border: `1px solid ${theme.border}`, 
            backgroundColor: theme.input, 
            color: theme.text, 
            outline: 'none',
            cursor: 'pointer'
          }}
          onChange={(e) => {
            setCategoryFilter(e.target.value);
            setCurrentPage(1);
          }}
        >
          {uniqueCategories.map(cat => (
            <option key={cat} value={cat}>{cat}</option>
          ))}
        </select>

        <div style={{ fontSize: '13px', color: '#737373' }}>
          Total: <strong style={{ color: theme.accent }}>{filteredServices.length}</strong> services
        </div>
      </div>

      {/* Services Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '20px' }}>
        {currentServices.map(srv => (
          <div key={srv.id} style={{ backgroundColor: theme.card, padding: '25px', borderRadius: '25px', border: `1px solid ${theme.border}` }}>
            <span style={{ fontSize: '10px', color: theme.accent, fontWeight: 'bold' }}>{srv.category}</span>
            <h3 style={{ fontSize: '18px', margin: '10px 0' }}>{srv.name}</h3>
            <p style={{ fontSize: '12px', opacity: 0.7, marginBottom: '15px' }}>{srv.description}</p>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '15px' }}>
              <span style={{ fontSize: '18px', fontWeight: '800', color: theme.accent }}>{srv.price}</span>
              <span style={{ fontSize: '11px', opacity: 0.5 }}>Slots: {srv.slots}</span>
            </div>
            <div style={{ display: 'flex', gap: '10px' }}>
              <button 
                onClick={() => handleUpdate(srv)}
                style={{ flex: 1, padding: '10px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '12px', fontWeight: 'bold', cursor: 'pointer' }}
              >
                ✏️ Edit
              </button>
              <button 
                onClick={() => handleDelete(srv)}
                style={{ flex: 1, padding: '10px', backgroundColor: '#450a0a', color: '#fecaca', border: 'none', borderRadius: '12px', fontWeight: 'bold', cursor: 'pointer' }}
              >
                🗑️ Delete
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* No Results Message */}
      {filteredServices.length === 0 && (
        <div style={{ textAlign: 'center', padding: '80px', backgroundColor: theme.card, borderRadius: '30px', border: `1px dashed ${theme.border}` }}>
          <span style={{ fontSize: '60px' }}>🔍</span>
          <h3 style={{ color: '#737373', marginTop: '20px' }}>No services found matching your filters</h3>
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: '30px', gap: '8px' }}>
          <button 
            onClick={() => paginate(currentPage - 1)}
            disabled={currentPage === 1}
            style={{ padding: '10px 16px', borderRadius: '10px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, cursor: currentPage === 1 ? 'not-allowed' : 'pointer', opacity: currentPage === 1 ? 0.5 : 1 }}
          >
            ← Previous
          </button>
          {[...Array(totalPages).keys()].map(number => (
            <button
              key={number + 1}
              onClick={() => paginate(number + 1)}
              style={{ padding: '10px 18px', borderRadius: '10px', border: `1px solid ${theme.border}`, backgroundColor: currentPage === number + 1 ? theme.accent : theme.input, color: currentPage === number + 1 ? '#000' : theme.text, cursor: 'pointer', fontWeight: currentPage === number + 1 ? 'bold' : 'normal' }}
            >
              {number + 1}
            </button>
          ))}
          <button 
            onClick={() => paginate(currentPage + 1)}
            disabled={currentPage === totalPages}
            style={{ padding: '10px 16px', borderRadius: '10px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, cursor: currentPage === totalPages ? 'not-allowed' : 'pointer', opacity: currentPage === totalPages ? 0.5 : 1 }}
          >
            Next →
          </button>
        </div>
      )}

      {/* Edit Modal */}
      {editingService && (
        <div style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.9)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 2000 }}>
          <div style={{ backgroundColor: theme.card, padding: '40px', borderRadius: '30px', width: '500px', border: `1px solid ${theme.accent}` }}>
            <h3 style={{ color: theme.accent, marginBottom: '25px' }}>Edit Service</h3>
            <input 
              type="text" 
              value={editingService.name} 
              onChange={(e) => setEditingService({...editingService, name: e.target.value})} 
              style={{ width: '100%', padding: '12px', marginBottom: '15px', borderRadius: '12px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, outline: 'none' }} 
            />
            <input 
              type="text" 
              value={editingService.price.replace(' DZD', '')} 
              onChange={(e) => setEditingService({...editingService, price: e.target.value + ' DZD'})} 
              style={{ width: '100%', padding: '12px', marginBottom: '15px', borderRadius: '12px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, outline: 'none' }} 
            />
            <select 
              value={editingService.category} 
              onChange={(e) => setEditingService({...editingService, category: e.target.value})}
              style={{ width: '100%', padding: '12px', marginBottom: '15px', borderRadius: '12px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, outline: 'none' }}
            >
              <option>Nursing</option>
              <option>Babysitting</option>
              <option>Elderly Care</option>
            </select>
            <textarea 
              value={editingService.description} 
              onChange={(e) => setEditingService({...editingService, description: e.target.value})} 
              style={{ width: '100%', padding: '12px', marginBottom: '25px', borderRadius: '12px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, outline: 'none', minHeight: '80px' }} 
            />
            <div style={{ display: 'flex', gap: '15px' }}>
              <button onClick={saveUpdate} style={{ flex: 1, padding: '14px', backgroundColor: theme.accent, color: '#000', border: 'none', borderRadius: '15px', fontWeight: 'bold', cursor: 'pointer' }}>
                Save Changes
              </button>
              <button onClick={() => setEditingService(null)} style={{ flex: 1, padding: '14px', backgroundColor: '#333', color: '#fff', border: 'none', borderRadius: '15px', cursor: 'pointer' }}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.9)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 2000 }}>
          <div style={{ backgroundColor: theme.card, padding: '40px', borderRadius: '30px', width: '400px', textAlign: 'center', border: `1px solid ${theme.accent}` }}>
            <span style={{ fontSize: '50px' }}>⚠️</span>
            <h3 style={{ color: theme.text, marginBottom: '10px' }}>Confirm Deletion</h3>
            <p style={{ color: '#737373', marginBottom: '30px' }}>
              Are you sure you want to delete "{showDeleteConfirm.name}"? This action cannot be undone.
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

export default ConsultServices;