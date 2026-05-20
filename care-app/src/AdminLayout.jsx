import React from 'react';

const AdminLayout = ({ children, setCurrentPage, currentPage, isDarkMode, toggleTheme, onLogout }) => {
  
  const menu = [
    { id: 'dashboard', label: 'Overview', icon: '📊' },
    { id: 'users', label: 'Clients Control', icon: '👥' },
    { id: 'requests', label: 'Join Requests', icon: '📩' },
    { id: 'tracking', label: 'Booking Tracking', icon: '📍' },
    { id: 'refund', label: 'Refund Management', icon: '💰' },
    { id: 'reports', label: 'Reports & Logs', icon: '📑' },
    { id: 'service-reports', label: 'Service Reports', icon: '📊' },
    { id: 'stats', label: 'Statistics', icon: '📈' },
    { id: 'consult-categories', label: 'Consult Categories', icon: '📁' },
    { id: 'consult-services', label: 'Consult Services', icon: '🛠️' },
    { id: 'add-category', label: 'New Category', icon: '➕📁' },
    { id: 'add-service', label: 'New Service', icon: '➕🛠️' },
  ];

  const theme = {
    sidebar: '#0a0a0a', 
    main: isDarkMode ? '#050505' : '#fcfcfc',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    primary: '#1a2e05',
    accent: '#a3e635'
  };

  return (
    <div style={{ 
      display: 'flex', 
      width: '100vw', 
      height: '100vh', 
      backgroundColor: theme.main, 
      color: theme.text, 
      fontFamily: "'Plus Jakarta Sans', sans-serif", 
      overflow: 'hidden' 
    }}>
      
      {/* Sidebar */}
      <aside style={{ 
        width: '280px', 
        backgroundColor: theme.sidebar, 
        padding: '30px 15px', 
        display: 'flex', 
        flexDirection: 'column', 
        borderRight: '1px solid #1f1f1f',
        height: '100vh',
        boxSizing: 'border-box'
      }}>
        
        {/* Logo with Image */}
        <div style={{ 
          display: 'flex', 
          alignItems: 'center', 
          gap: '12px', 
          marginBottom: '30px', 
          paddingLeft: '10px', 
          flexShrink: 0 
        }}>
          <div style={{ 
            width: '40px', 
            height: '40px', 
            backgroundColor: '#1a2e05', 
            borderRadius: '12px', 
            display: 'flex', 
            justifyContent: 'center', 
            alignItems: 'center', 
            border: '1px solid #a3e635',
            overflow: 'hidden'
          }}>
            <img 
              src="/health.jpg" 
              alt="CareApp Logo" 
              style={{ 
                width: '100%', 
                height: '100%', 
                objectFit: 'cover'
              }} 
            />
          </div>
          <div style={{ color: '#fff', fontWeight: '800', fontSize: '18px', letterSpacing: '-1px' }}>
            CARE<span style={{ color: '#a3e635' }}>APP</span>
          </div>
        </div>
        
        {/* Menu */}
        <nav style={{ 
          flex: 1, 
          overflowY: 'auto', 
          overflowX: 'hidden',
          paddingRight: '5px',
          scrollbarWidth: 'thin',
          scrollbarColor: `${theme.primary} transparent`
        }}>
          {menu.map(item => (
            <div 
              key={item.id} 
              onClick={() => setCurrentPage(item.id)} 
              style={{
                display: 'flex', 
                alignItems: 'center', 
                padding: '12px 15px', 
                marginBottom: '6px', 
                cursor: 'pointer', 
                borderRadius: '12px', 
                transition: '0.2s',
                backgroundColor: currentPage === item.id ? theme.primary : 'transparent',
                color: currentPage === item.id ? theme.accent : '#737373',
              }}
              onMouseOver={(e) => { if(currentPage !== item.id) e.currentTarget.style.backgroundColor = '#111'; }}
              onMouseOut={(e) => { if(currentPage !== item.id) e.currentTarget.style.backgroundColor = 'transparent'; }}
            >
              <span style={{ marginRight: '12px', fontSize: '16px' }}>{item.icon}</span>
              <span style={{ fontWeight: '600', fontSize: '12px' }}>{item.label}</span>
            </div>
          ))}
        </nav>

        {/* Logout Button */}
        <div style={{ 
          marginTop: '20px', 
          paddingTop: '15px', 
          borderTop: '1px solid #1f1f1f', 
          flexShrink: 0 
        }}>
          <button 
            onClick={onLogout} 
            style={{ 
              width: '100%', 
              padding: '12px', 
              backgroundColor: '#450a0a', 
              color: '#fecaca', 
              border: 'none', 
              borderRadius: '12px', 
              cursor: 'pointer', 
              fontWeight: 'bold', 
              fontSize: '11px',
              transition: '0.3s'
            }}
            onMouseOver={(e) => e.target.style.backgroundColor = '#7f1d1d'}
            onMouseOut={(e) => e.target.style.backgroundColor = '#450a0a'}
          >
            SECURE LOGOUT
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        
        {/* Header */}
        <header style={{ 
          height: '70px', 
          padding: '0 40px', 
          display: 'flex', 
          alignItems: 'center', 
          justifyContent: 'space-between', 
          borderBottom: `1px solid ${isDarkMode ? '#1f1f1f' : '#eee'}`,
          backgroundColor: theme.main
        }}>
          <div style={{ fontWeight: '800', fontSize: '14px', textTransform: 'uppercase', letterSpacing: '1px' }}>
             {menu.find(m => m.id === currentPage)?.label || 'Admin Panel'}
          </div>
          <button 
            onClick={toggleTheme} 
            style={{ 
              background: theme.primary, 
              border: `1px solid ${theme.accent}`, 
              color: theme.accent, 
              padding: '8px 16px', 
              borderRadius: '20px', 
              cursor: 'pointer', 
              fontWeight: 'bold', 
              fontSize: '11px' 
            }}
          >
             {isDarkMode ? '🌙 DARK MODE' : '☀️ LIGHT MODE'}
          </button>
        </header>

        {/* Page Content */}
        <div style={{ flex: 1, padding: '40px', overflowY: 'auto', backgroundColor: theme.main }}>
          {children}
        </div>
      </main>
    </div>
  );
};

export default AdminLayout;