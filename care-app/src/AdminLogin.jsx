import React, { useState } from 'react';

const AdminLogin = ({ onLogin }) => {
  const [email, setEmail] = useState('admin@careapp.com');
  const [password, setPassword] = useState('admin123');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await fetch('http://localhost:5001/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || 'Login failed');
      }

      if (data.role !== 'Admin') {
        setError('Access denied. Admin only.');
        setLoading(false);
        return;
      }

      localStorage.setItem('token', data.token);
      localStorage.setItem('user', JSON.stringify({ userId: data.userId, name: data.name, role: data.role }));

      onLogin();
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  };

  const styles = {
    container: {
      height: '100vh',
      width: '100vw',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      backgroundColor: '#050505',
      fontFamily: "'Plus Jakarta Sans', sans-serif"
    },
    card: {
      backgroundColor: '#0a0a0a',
      padding: '60px 50px',
      borderRadius: '40px',
      width: '420px',
      border: '1px solid #1f1f1f',
      textAlign: 'center'
    },
    logoWrapper: {
      width: '100px',
      height: '100px',
      backgroundColor: '#1a2e05',
      borderRadius: '30px',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      margin: '0 auto 25px',
      border: '1px solid #a3e635'
    },
    title: {
      color: '#ffffff',
      fontSize: '32px',
      fontWeight: '800',
      marginBottom: '10px'
    },
    input: {
      width: '100%',
      padding: '18px 20px',
      marginBottom: '20px',
      borderRadius: '18px',
      border: '1px solid #1f1f1f',
      backgroundColor: '#050505',
      color: '#ffffff',
      fontSize: '15px',
      outline: 'none',
      boxSizing: 'border-box'
    },
    button: {
      width: '100%',
      padding: '18px',
      backgroundColor: '#1a2e05',
      color: '#a3e635',
      border: 'none',
      borderRadius: '18px',
      fontWeight: '800',
      fontSize: '16px',
      cursor: 'pointer',
      marginTop: '10px'
    },
    error: {
      color: '#ef4444',
      fontSize: '12px',
      marginBottom: '15px'
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <div style={styles.logoWrapper}>
          <img src="/health.jpg" alt="Care Logo" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        </div>
        
        <h1 style={styles.title}>CARE<span style={{ color: '#a3e635' }}>APP</span></h1>
        <p style={{ color: '#737373', fontSize: '14px', marginBottom: '40px' }}>Security Portal Management</p>
        
        <form onSubmit={handleLogin}>
          {error && <div style={styles.error}>{error}</div>}
          <input 
            type="email" 
            placeholder="Admin Email" 
            style={styles.input} 
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <input 
            type="password" 
            placeholder="Password" 
            style={styles.input} 
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          
          <button type="submit" style={styles.button} disabled={loading}>
            {loading ? 'LOADING...' : 'AUTHORIZE ENTRY'}
          </button>
        </form>
        
        <div style={{ marginTop: '30px', fontSize: '11px', color: '#404040', letterSpacing: '1px' }}>
          ENCRYPTED CONNECTION ACTIVE
        </div>
      </div>
    </div>
  );
};

export default AdminLogin;