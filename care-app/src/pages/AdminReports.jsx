import React, { useState, useEffect } from 'react';

const AdminReports = ({ isDarkMode }) => {
  const [reports, setReports] = useState([]);
  const [selectedReport, setSelectedReport] = useState(null);
  const [showWarningForm, setShowWarningForm] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const [dateFilter, setDateFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState("All");
  const [currentPage, setCurrentPage] = useState(1);
  const [reportsPerPage] = useState(4);
  const [loading, setLoading] = useState(true);

  const fetchReports = async () => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch('http://localhost:5001/api/admin/reports', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();
      setReports(data);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching reports:', error);
      setLoading(false);
    }
  };

  const resolveReport = async (id, action, warningMessage = '') => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch(`http://localhost:5000/api/admin/reports/${id}/resolve`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ action, message: warningMessage })
      });
      
      const data = await response.json();
      console.log('Response:', data);
      
      if (action === 'ban') {
        alert('User Banned Successfully');
      } else if (action === 'warning') {
        alert('Warning Sent');
      }
      
      fetchReports();
      setSelectedReport(null);
      setShowWarningForm(false);
    } catch (error) {
      console.error('Error resolving report:', error);
      alert('Failed to process report');
    }
  };

  useEffect(() => {
    fetchReports();
  }, []);

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    primary: '#1a2e05',
    accent: '#a3e635',
    danger: '#450a0a',
    warning: '#f59e0b'
  };

  const getStatusColor = (status) => {
    switch(status) {
      case 'Resolved': return '#10b981';
      case 'Pending': return '#f59e0b';
      case 'Review': return '#3b82f6';
      default: return '#6b7280';
    }
  };

  const getStatusBgColor = (status) => {
    switch(status) {
      case 'Resolved': return 'rgba(16, 185, 129, 0.1)';
      case 'Pending': return 'rgba(245, 158, 11, 0.1)';
      case 'Review': return 'rgba(59, 130, 246, 0.1)';
      default: return 'rgba(107, 114, 128, 0.1)';
    }
  };

  const filteredReports = reports.filter(report => {
    const matchesSearch = 
      report.sender.toLowerCase().includes(searchTerm.toLowerCase()) ||
      report.target.toLowerCase().includes(searchTerm.toLowerCase()) ||
      report.reason.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesDate = dateFilter === "" || report.date === dateFilter;
    const matchesStatus = statusFilter === "All" || report.status === statusFilter;
    
    return matchesSearch && matchesDate && matchesStatus;
  });

  const indexOfLastReport = currentPage * reportsPerPage;
  const indexOfFirstReport = indexOfLastReport - reportsPerPage;
  const currentReports = filteredReports.slice(indexOfFirstReport, indexOfLastReport);
  const totalPages = Math.ceil(filteredReports.length / reportsPerPage);

  const paginate = (pageNumber) => setCurrentPage(pageNumber);
  const uniqueDates = [...new Set(reports.map(r => r.date))].sort().reverse();

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading reports...</div>;
  }

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div style={{ marginBottom: '25px' }}>
        <h2 style={{color: '#1a2e05', fontSize: '24px', fontWeight: '800', letterSpacing: '-0.5px' }}>System Reports</h2>
        <p style={{ color: '#737373', fontSize: '13px' }}>Manage user complaints and tracking information</p>
      </div>

      <div style={{ 
        display: 'flex', 
        gap: '15px', 
        marginBottom: '25px', 
        flexWrap: 'wrap',
        alignItems: 'center'
      }}>
        <input 
          type="text" 
          placeholder="Search by sender, target, or reason..." 
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
          value={dateFilter}
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
            setDateFilter(e.target.value);
            setCurrentPage(1);
          }}
        >
          <option value="">All Dates</option>
          {uniqueDates.map(date => (
            <option key={date} value={date}>{date}</option>
          ))}
        </select>

        <select 
          value={statusFilter}
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
            setStatusFilter(e.target.value);
            setCurrentPage(1);
          }}
        >
          <option value="All">All Status</option>
          <option value="Pending">Pending</option>
          <option value="Review">Review</option>
          <option value="Resolved">Resolved</option>
        </select>

        <div style={{ fontSize: '13px', color: '#737373' }}>
          Total: <strong style={{ color: theme.accent }}>{filteredReports.length}</strong> reports
        </div>
      </div>

      <div style={{ 
        backgroundColor: theme.card, 
        borderRadius: '20px', 
        border: `1px solid ${theme.border}`, 
        overflow: 'hidden',
        boxShadow: '0 10px 30px rgba(0,0,0,0.1)'
      }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
          <thead>
            <tr style={{ backgroundColor: theme.primary, color: theme.accent, textAlign: 'left' }}>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>From / To</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Reason</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Date</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Status</th>
              <th style={{ padding: '15px 20px', textAlign: 'center', fontSize: '11px', textTransform: 'uppercase' }}>Action</th>
              </tr>
          </thead>
          <tbody>
            {currentReports.map(rep => (
              <tr key={rep.id} style={{ borderBottom: `1px solid ${theme.border}` }}>
                <td style={{ padding: '12px 20px' }}>
                  <div style={{ fontWeight: '700', fontSize: '14px' }}>{rep.sender}</div>
                  <div style={{ fontSize: '10px', opacity: 0.5 }}>Reporting: {rep.target}</div>
                </td>
                <td style={{ padding: '12px 20px', fontWeight: '500' }}>{rep.reason}</td>
                <td style={{ padding: '12px 20px', opacity: 0.5, fontSize: '11px' }}>{rep.date}</td>
                <td style={{ padding: '12px 20px' }}>
                  <span style={{ 
                    color: getStatusColor(rep.status), 
                    fontSize: '10px', 
                    fontWeight: '800', 
                    backgroundColor: getStatusBgColor(rep.status), 
                    padding: '4px 10px', 
                    borderRadius: '20px' 
                  }}>
                    {rep.status}
                  </span>
                </td>
                <td style={{ padding: '12px 20px', textAlign: 'center' }}>
                  <button 
                    onClick={() => setSelectedReport(rep)} 
                    style={{ 
                      background: 'none', 
                      border: `1px solid ${theme.border}`, 
                      color: theme.text, 
                      padding: '6px 14px', 
                      borderRadius: '10px', 
                      cursor: 'pointer', 
                      fontSize: '11px', 
                      fontWeight: '700'
                    }}
                  >
                    Details
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {filteredReports.length === 0 && (
          <div style={{ textAlign: 'center', padding: '60px', color: '#737373' }}>
            <span style={{ fontSize: '48px' }}>🔍</span>
            <p style={{ marginTop: '15px' }}>No reports found matching your filters</p>
          </div>
        )}

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
                style={{ padding: '8px 14px', borderRadius: '8px', border: `1px solid ${theme.border}`, backgroundColor: currentPage === number + 1 ? theme.accent : theme.input, color: currentPage === number + 1 ? '#000' : theme.text, cursor: 'pointer' }}
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

      {selectedReport && (
        <div style={{ 
          position: 'fixed', inset: 0, 
          backgroundColor: 'rgba(0,0,0,0.92)', 
          display: 'flex', justifyContent: 'center', alignItems: 'center', 
          zIndex: 2000, backdropFilter: 'blur(12px)' 
        }}>
          <div style={{ 
            backgroundColor: theme.card, padding: '40px', borderRadius: '30px', 
            width: '500px', border: `1px solid ${theme.accent}`, textAlign: 'center' 
          }}>
            <h3 style={{ color: theme.accent, marginBottom: '15px', fontSize: '22px' }}>Incident Tracking</h3>
            <div style={{ backgroundColor: '#050505', padding: '20px', borderRadius: '15px', textAlign: 'left', marginBottom: '30px', border: '1px solid #1f1f1f' }}>
              <label style={{ fontSize: '10px', color: theme.accent, display: 'block', marginBottom: '10px', letterSpacing: '1px' }}>TRACKING INFORMATION</label>
              <p style={{ fontSize: '14px', lineHeight: '1.6', opacity: 0.8, margin: 0 }}>{selectedReport.details}</p>
            </div>
            
            {!showWarningForm ? (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
                <button 
                  onClick={() => resolveReport(selectedReport.id, 'ban')}
                  style={{ padding: '16px', backgroundColor: theme.danger, color: '#fecaca', border: 'none', borderRadius: '16px', fontWeight: '800', cursor: 'pointer', fontSize: '12px' }}>
                  VALIDATE & BAN
                </button>
                <button 
                  onClick={() => setShowWarningForm(true)}
                  style={{ padding: '16px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '16px', fontWeight: '800', cursor: 'pointer', fontSize: '12px' }}>
                  SEND WARNING
                </button>
              </div>
            ) : (
              <div style={{ textAlign: 'left' }}>
                <textarea 
                  id="warningMessage"
                  placeholder="Type the warning message..." 
                  style={{ width: '100%', height: '100px', backgroundColor: '#050505', border: '1px solid #333', borderRadius: '15px', padding: '15px', color: '#fff', outline: 'none', boxSizing: 'border-box' }} 
                />
                <button 
                  onClick={() => {
                    const message = document.getElementById('warningMessage').value;
                    resolveReport(selectedReport.id, 'warning', message);
                  }} 
                  style={{ width: '100%', marginTop: '15px', padding: '16px', backgroundColor: theme.accent, color: '#000', borderRadius: '16px', fontWeight: '800', border: 'none', cursor: 'pointer' }}>
                  CONFIRM & SEND
                </button>
              </div>
            )}
            
            <button 
              onClick={() => {setSelectedReport(null); setShowWarningForm(false)}} 
              style={{ marginTop: '20px', background: 'none', border: 'none', color: '#737373', cursor: 'pointer', fontSize: '12px', fontWeight: '600' }}
            >
              Cancel Review
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminReports;