import React, { useState, useEffect } from 'react';

const Dashboard = ({ isDarkMode }) => {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalProviders: 0,
    totalClients: 0,
    pendingProviders: 0,
    activeUsers: 0
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    const token = localStorage.getItem('token');
    
    try {
      const response = await fetch('http://localhost:5001/api/admin/stats', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      
      const data = await response.json();
      setStats(data);
      setLoading(false);
    } catch (err) {
      setError('Failed to load stats');
      setLoading(false);
    }
  };

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading...</div>;
  }

  if (error) {
    return <div style={{ textAlign: 'center', padding: '50px', color: 'red' }}>{error}</div>;
  }

  const statCards = [
    { label: 'Total Users', value: stats.totalUsers, icon: '👥', color: '#a3e635' },
    { label: 'Service Providers', value: stats.totalProviders, icon: '🛡️', color: '#10b981' },
    { label: 'Total Clients', value: stats.totalClients, icon: '👤', color: '#fbbf24' },
    { label: 'Pending Requests', value: stats.pendingProviders, icon: '📩', color: '#ef4444' }
  ];

  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '30px' }}>
      {statCards.map((s, i) => (
        <div key={i} style={{ 
          backgroundColor: isDarkMode ? '#0f0f0f' : '#fff', 
          padding: '35px', 
          borderRadius: '30px', 
          border: `1px solid ${isDarkMode ? '#1f1f1f' : '#f0f0f0'}`,
          boxShadow: isDarkMode ? 'none' : '0 20px 40px rgba(0,0,0,0.02)'
        }}>
          <div style={{ fontSize: '32px', marginBottom: '20px' }}>{s.icon}</div>
          <div style={{ color: '#737373', fontSize: '14px', fontWeight: '600', textTransform: 'uppercase', letterSpacing: '1px' }}>{s.label}</div>
          <div style={{ fontSize: '38px', fontWeight: '800', margin: '10px 0', color: isDarkMode ? '#fff' : '#000' }}>{s.value}</div>
          <div style={{ color: s.color, fontSize: '13px', fontWeight: 'bold' }}>Active</div>
        </div>
      ))}
    </div>
  );
};

export default Dashboard;