import React, { useState, useEffect } from 'react';

const AdminReports = ({ isDarkMode }) => {
  const [reports, setReports] = useState([]);
  const [selectedReport, setSelectedReport] = useState(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [dateFilter, setDateFilter] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const [reportsPerPage] = useState(4);
  const [loading, setLoading] = useState(true);

  const fetchReports = async () => {
    const token = localStorage.getItem('token');
    try {
      // المسار الجديد لجلب جميع التقارير (للمسؤول)
      const response = await fetch('http://localhost:5001/api/admin/reports', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();
      // نتوقع من الخادم إرجاع مصفوفة من التقارير بالشكل:
      // { id, email1, email2, reason, description, created_at }
      setReports(data.reports || []);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching reports:', error);
      setLoading(false);
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

  const filteredReports = reports.filter(report => {
    const matchesSearch = 
      report.email1?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      report.email2?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      report.reason?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      report.description?.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesDate = dateFilter === "" || report.created_at?.split('T')[0] === dateFilter;
    
    return matchesSearch && matchesDate;
  });

  const indexOfLastReport = currentPage * reportsPerPage;
  const indexOfFirstReport = indexOfLastReport - reportsPerPage;
  const currentReports = filteredReports.slice(indexOfFirstReport, indexOfLastReport);
  const totalPages = Math.ceil(filteredReports.length / reportsPerPage);

  const paginate = (pageNumber) => setCurrentPage(pageNumber);
  const uniqueDates = [...new Set(reports.map(r => r.created_at?.split('T')[0]))].filter(Boolean).sort().reverse();

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading reports...</div>;
  }

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div style={{ marginBottom: '25px' }}>
        <h2 style={{color: '#1a2e05', fontSize: '24px', fontWeight: '800', letterSpacing: '-0.5px' }}>System Reports</h2>
        <p style={{ color: '#737373', fontSize: '13px' }}>User reports (email based)</p>
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
          placeholder="Search by reporter, reported, reason..." 
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
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Reporter (email1)</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Reported (email2)</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Reason</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Date</th>
              <th style={{ padding: '15px 20px', textAlign: 'center', fontSize: '11px', textTransform: 'uppercase' }}>Action</th>
              </tr>
          </thead>
          <tbody>
            {currentReports.map(rep => (
              <tr key={rep.id} style={{ borderBottom: `1px solid ${theme.border}` }}>
                <td style={{ padding: '12px 20px' }}>
                  <div style={{ fontWeight: '700', fontSize: '13px' }}>{rep.email1}</div>
                </td>
                <td style={{ padding: '12px 20px' }}>
                  <div style={{ fontWeight: '700', fontSize: '13px' }}>{rep.email2}</div>
                </td>
                <td style={{ padding: '12px 20px', fontWeight: '500' }}>{rep.reason}</td>
                <td style={{ padding: '12px 20px', opacity: 0.5, fontSize: '11px' }}>
                  {rep.created_at ? new Date(rep.created_at).toLocaleDateString() : 'N/A'}
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

      {/* Modal for report details */}
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
            <h3 style={{ color: theme.accent, marginBottom: '15px', fontSize: '22px' }}>Report Details</h3>
            <div style={{ backgroundColor: '#050505', padding: '20px', borderRadius: '15px', textAlign: 'left', marginBottom: '30px', border: '1px solid #1f1f1f' }}>
              <label style={{ fontSize: '10px', color: theme.accent, display: 'block', marginBottom: '10px', letterSpacing: '1px' }}>REPORT INFORMATION</label>
              <p style={{ fontSize: '13px', margin: '5px 0' }}><strong>Reporter (email1):</strong> {selectedReport.email1}</p>
              <p style={{ fontSize: '13px', margin: '5px 0' }}><strong>Reported (email2):</strong> {selectedReport.email2}</p>
              <p style={{ fontSize: '13px', margin: '5px 0' }}><strong>Reason:</strong> {selectedReport.reason}</p>
              <p style={{ fontSize: '13px', margin: '5px 0' }}><strong>Description:</strong> {selectedReport.description || 'No description provided'}</p>
              <p style={{ fontSize: '13px', margin: '5px 0' }}><strong>Date:</strong> {selectedReport.created_at ? new Date(selectedReport.created_at).toLocaleString() : 'N/A'}</p>
            </div>
            
            <button 
              onClick={() => setSelectedReport(null)} 
              style={{ marginTop: '20px', background: 'none', border: 'none', color: '#737373', cursor: 'pointer', fontSize: '12px', fontWeight: '600' }}
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminReports;