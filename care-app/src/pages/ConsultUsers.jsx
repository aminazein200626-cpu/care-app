import React, { useState, useEffect } from 'react';

const ConsultUsers = ({ isDarkMode }) => {
  const [users, setUsers] = useState([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedUser, setSelectedUser] = useState(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [usersPerPage] = useState(5);
  const [loading, setLoading] = useState(true);

  // جلب المستخدمين من API
  const fetchUsers = async () => {
    const token = localStorage.getItem('token');
    if (!token) {
      console.error('No token found');
      setLoading(false);
      return;
    }
    
    try {
      const response = await fetch('http://localhost:5001/api/admin/users', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      console.log('API Response:', data); // للتصحيح
      
      // ✅ التصحيح: data.users هي المصفوفة
      const usersArray = data.users || [];
      
      const formattedUsers = usersArray.map(user => ({
        id: user._id,
        name: user.fullName || user.username || 'N/A',
        email: user.email || 'N/A',
        phone: user.phoneNumber || user.tel || 'N/A',
        role: user.role || 'Client',
        status: user.isActive === undefined ? true : user.isActive,
        joined: user.createdAt ? new Date(user.createdAt).toISOString().split('T')[0] : new Date().toISOString().split('T')[0]
      }));
      
      setUsers(formattedUsers);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching users:', error);
      setLoading(false);
    }
  };

  // تحديث حالة المستخدم (حظر/تفعيل)
  const toggleStatus = async (id) => {
    const token = localStorage.getItem('token');
    if (!token) return;
    
    try {
      const response = await fetch(`http://localhost:5001/api/admin/users/${id}/block`, {
        method: 'PUT',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (response.ok) {
        // تحديث القائمة بعد التغيير
        fetchUsers();
      }
    } catch (error) {
      console.error('Error toggling user status:', error);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    primary: '#1a2e05',
    accent: '#a3e635'
  };

  // Filter users based on search term
  const filteredUsers = users.filter(user => 
    user.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.role.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Pagination logic
  const indexOfLastUser = currentPage * usersPerPage;
  const indexOfFirstUser = indexOfLastUser - usersPerPage;
  const currentUsers = filteredUsers.slice(indexOfFirstUser, indexOfLastUser);
  const totalPages = Math.ceil(filteredUsers.length / usersPerPage);

  const paginate = (pageNumber) => setCurrentPage(pageNumber);

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading users...</div>;
  }

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      {/* Header & Search Area */}
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '30px', alignItems: 'center', flexWrap: 'wrap', gap: '15px' }}>
        <h2 style={{ color: '#213a06', fontSize: '24px', fontWeight: '800' }}>Users Management</h2>
        <div style={{ display: 'flex', gap: '15px', alignItems: 'center' }}>
          <span style={{ fontSize: '13px', color: '#737373' }}>
            Total: <strong style={{ color: theme.accent }}>{filteredUsers.length}</strong> users
          </span>
          <input 
            type="text" 
            placeholder="Search by name, email or role..." 
            value={searchTerm}
            style={{ width: '300px', padding: '12px 20px', borderRadius: '14px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, outline: 'none' }}
            onChange={(e) => {
              setSearchTerm(e.target.value);
              setCurrentPage(1);
            }}
          />
        </div>
      </div>

      {/* Table Container */}
      <div style={{ backgroundColor: theme.card, borderRadius: '24px', border: `1px solid ${theme.border}`, overflow: 'hidden', boxShadow: '0 10px 30px rgba(0,0,0,0.2)' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
          <thead>
            <tr style={{ backgroundColor: theme.primary, color: theme.accent }}>
              <th style={{ padding: '20px' }}>User Name</th>
              <th style={{ padding: '20px' }}>Email Address</th>
              <th style={{ padding: '20px' }}>Type</th>
              <th style={{ padding: '20px' }}>Status</th>
              <th style={{ padding: '20px' }}>Actions</th>
             </tr>
          </thead>
          <tbody>
            {currentUsers.map(u => (
              <tr key={u.id} style={{ borderBottom: `1px solid ${theme.border}`, transition: '0.2s' }}>
                <td style={{ padding: '20px', fontWeight: '600' }}>{u.name}</td>
                <td style={{ padding: '20px', opacity: 0.7 }}>{u.email}</td>
                <td style={{ padding: '20px' }}>
                  <span style={{ fontSize: '12px', padding: '6px 12px', borderRadius: '20px', backgroundColor: 'rgba(163, 230, 53, 0.1)', color: theme.accent, border: `1px solid ${theme.accent}` }}>
                    {u.role}
                  </span>
                </td>
                <td style={{ padding: '20px' }}>
                  <button 
                    onClick={() => toggleStatus(u.id)}
                    style={{ 
                      padding: '8px 16px', borderRadius: '12px', border: 'none', cursor: 'pointer', fontWeight: 'bold', fontSize: '12px',
                      backgroundColor: u.status ? '#14532d' : '#7f1d1d', color: u.status ? '#4ade80' : '#fca5a5'
                    }}>
                    {u.status ? '● Active' : '○ Deactive'}
                  </button>
                </td>
                <td style={{ padding: '20px' }}>
                  <button 
                    onClick={() => setSelectedUser(u)}
                    style={{ background: 'none', border: `1px solid ${theme.border}`, color: theme.text, padding: '8px 15px', borderRadius: '10px', cursor: 'pointer', fontSize: '12px', fontWeight: '600' }}>
                    View Details
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {/* No Results Message */}
        {filteredUsers.length === 0 && (
          <div style={{ textAlign: 'center', padding: '60px', color: '#737373' }}>
            <span style={{ fontSize: '48px' }}>🔍</span>
            <p style={{ marginTop: '15px' }}>No users found matching "{searchTerm}"</p>
          </div>
        )}

        {/* Pagination */}
        {totalPages > 1 && (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '20px', gap: '8px', borderTop: `1px solid ${theme.border}` }}>
            <button 
              onClick={() => paginate(currentPage - 1)}
              disabled={currentPage === 1}
              style={{ padding: '8px 12px', borderRadius: '8px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, cursor: currentPage === 1 ? 'not-allowed' : 'pointer', opacity: currentPage === 1 ? 0.5 : 1 }}
            >
              ← Previous
            </button>
            {[...Array(totalPages).keys()].map(number => (
              <button
                key={number + 1}
                onClick={() => paginate(number + 1)}
                style={{ padding: '8px 14px', borderRadius: '8px', border: `1px solid ${theme.border}`, backgroundColor: currentPage === number + 1 ? theme.accent : theme.input, color: currentPage === number + 1 ? '#000' : theme.text, cursor: 'pointer', fontWeight: currentPage === number + 1 ? 'bold' : 'normal' }}
              >
                {number + 1}
              </button>
            ))}
            <button 
              onClick={() => paginate(currentPage + 1)}
              disabled={currentPage === totalPages}
              style={{ padding: '8px 12px', borderRadius: '8px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, cursor: currentPage === totalPages ? 'not-allowed' : 'pointer', opacity: currentPage === totalPages ? 0.5 : 1 }}
            >
              Next →
            </button>
          </div>
        )}
      </div>

      {/* Details Modal */}
      {selectedUser && (
        <div style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.85)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000, backdropFilter: 'blur(8px)' }}>
          <div style={{ backgroundColor: theme.card, padding: '50px', borderRadius: '35px', width: '450px', border: `1px solid ${theme.accent}`, position: 'relative' }}>
            <h3 style={{ color: theme.accent, fontSize: '24px', marginBottom: '30px' }}>User Intelligence</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', textAlign: 'left' }}>
              <div><label style={{ opacity: 0.5, fontSize: '12px' }}>FULL NAME</label><div style={{ fontSize: '18px', fontWeight: 'bold' }}>{selectedUser.name}</div></div>
              <div><label style={{ opacity: 0.5, fontSize: '12px' }}>ROLE / TYPE</label><div style={{ color: theme.accent }}>{selectedUser.role}</div></div>
              <div><label style={{ opacity: 0.5, fontSize: '12px' }}>CONTACT NUMBER</label><div>{selectedUser.phone}</div></div>
              <div><label style={{ opacity: 0.5, fontSize: '12px' }}>EMAIL ID</label><div>{selectedUser.email}</div></div>
              <div><label style={{ opacity: 0.5, fontSize: '12px' }}>REGISTRATION DATE</label><div>{selectedUser.joined}</div></div>
            </div>
            <button 
              onClick={() => setSelectedUser(null)}
              style={{ width: '100%', marginTop: '40px', padding: '16px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '15px', fontWeight: 'bold', cursor: 'pointer' }}>
              CLOSE DETAILS
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default ConsultUsers;