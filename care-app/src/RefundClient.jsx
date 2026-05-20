import React, { useState, useEffect } from 'react';

const RefundClient = ({ isDarkMode }) => {
  const [refundRequests, setRefundRequests] = useState([]);
  const [selectedRefund, setSelectedRefund] = useState(null);
  const [filterStatus, setFilterStatus] = useState("All");
  const [loading, setLoading] = useState(true);

  // Fetch refund requests from API
  const fetchRefundRequests = async () => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch('http://localhost:5001/api/admin/refunds', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();
      
      const formattedRequests = data.map(req => ({
        id: req._id,
        client: req.client,
        clientEmail: req.clientEmail,
        bookingId: req.bookingId,
        service: req.service,
        amount: req.amount,
        date: req.date,
        reason: req.reason,
        status: req.status,
        paymentMethod: req.paymentMethod,
        transactionId: req.transactionId,
        adminNotes: req.adminNotes,
        processedAt: req.processedAt
      }));
      
      setRefundRequests(formattedRequests);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching refund requests:', error);
      setLoading(false);
    }
  };

  // Process refund decision (Approve/Reject)
  const processRefund = async (id, decision, notes = '') => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch(`http://localhost:5001/api/admin/refunds/${id}/process`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ 
          status: decision === 'Approve' ? 'Approved' : 'Rejected',
          adminNotes: notes,
          processedAt: new Date().toISOString().split('T')[0]
        })
      });
      
      const data = await response.json();
      
      if (response.ok) {
        await fetchRefundRequests();
        alert(`Refund request has been ${decision === 'Approve' ? 'approved' : 'rejected'}`);
        setSelectedRefund(null);
      } else {
        throw new Error(data.message || 'Failed to process refund');
      }
    } catch (error) {
      console.error('Error processing refund:', error);
      alert('Failed to process refund: ' + error.message);
    }
  };

  useEffect(() => {
    fetchRefundRequests();
  }, []);

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    accent: '#a3e635',
    primary: '#1a2e05',
    warning: '#f59e0b',
    success: '#10b981',
    danger: '#ef4444'
  };

  const getStatusColor = (status) => {
    switch(status) {
      case 'Approved': return '#10b981';
      case 'Pending': return '#f59e0b';
      case 'Processing': return '#3b82f6';
      case 'Rejected': return '#ef4444';
      default: return '#6b7280';
    }
  };

  const getStatusBgColor = (status) => {
    switch(status) {
      case 'Approved': return 'rgba(16, 185, 129, 0.1)';
      case 'Pending': return 'rgba(245, 158, 11, 0.1)';
      case 'Processing': return 'rgba(59, 130, 246, 0.1)';
      case 'Rejected': return 'rgba(239, 68, 68, 0.1)';
      default: return 'rgba(107, 114, 128, 0.1)';
    }
  };

  const filteredRequests = filterStatus === "All" 
    ? refundRequests 
    : refundRequests.filter(r => r.status === filterStatus);

  const totalAmount = refundRequests.reduce((sum, r) => sum + r.amount, 0);
  const pendingCount = refundRequests.filter(r => r.status === 'Pending').length;
  const approvedCount = refundRequests.filter(r => r.status === 'Approved').length;
  const rejectedCount = refundRequests.filter(r => r.status === 'Rejected').length;

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading refund requests...</div>;
  }

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div style={{ marginBottom: '30px' }}>
        <h2 style={{ color: '#1a2e05', fontSize: '28px', fontWeight: '800', letterSpacing: '-1px' }}>💰 Refund Management</h2>
        <p style={{ color: '#737373', fontSize: '14px' }}>Process client refund requests and manage payment disputes</p>
      </div>

      {/* Statistics Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '20px', marginBottom: '30px' }}>
        <div style={{ backgroundColor: theme.card, padding: '20px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
          <div style={{ fontSize: '28px', marginBottom: '10px' }}>💰</div>
          <div style={{ fontSize: '24px', fontWeight: '800' }}>
            {totalAmount} DZD
          </div>
          <div style={{ fontSize: '12px', color: '#737373' }}>Total Requests</div>
        </div>
        <div style={{ backgroundColor: theme.card, padding: '20px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
          <div style={{ fontSize: '28px', marginBottom: '10px' }}>⏳</div>
          <div style={{ fontSize: '24px', fontWeight: '800' }}>
            {pendingCount}
          </div>
          <div style={{ fontSize: '12px', color: '#f59e0b' }}>Pending</div>
        </div>
        <div style={{ backgroundColor: theme.card, padding: '20px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
          <div style={{ fontSize: '28px', marginBottom: '10px' }}>✅</div>
          <div style={{ fontSize: '24px', fontWeight: '800' }}>
            {approvedCount}
          </div>
          <div style={{ fontSize: '12px', color: '#10b981' }}>Approved</div>
        </div>
        <div style={{ backgroundColor: theme.card, padding: '20px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
          <div style={{ fontSize: '28px', marginBottom: '10px' }}>❌</div>
          <div style={{ fontSize: '24px', fontWeight: '800' }}>
            {rejectedCount}
          </div>
          <div style={{ fontSize: '12px', color: '#ef4444' }}>Rejected</div>
        </div>
      </div>

      {/* Filter Bar */}
      <div style={{ 
        display: 'flex', gap: '10px', marginBottom: '30px', 
        backgroundColor: theme.card, padding: '15px 20px', borderRadius: '20px', 
        border: `1px solid ${theme.border}`, alignItems: 'center', flexWrap: 'wrap'
      }}>
        <span style={{ fontSize: '12px', fontWeight: '600', color: theme.text }}>Filter by Status:</span>
        {['All', 'Pending', 'Processing', 'Approved', 'Rejected'].map(status => (
          <button
            key={status}
            onClick={() => setFilterStatus(status)}
            style={{
              padding: '8px 20px',
              borderRadius: '30px',
              border: 'none',
              cursor: 'pointer',
              fontWeight: '600',
              fontSize: '12px',
              backgroundColor: filterStatus === status ? theme.accent : theme.primary,
              color: filterStatus === status ? '#000' : theme.accent,
              transition: '0.3s'
            }}
          >
            {status}
          </button>
        ))}
      </div>

      {/* Refund Requests Table */}
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
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Client</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Booking ID</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Amount</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Date</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Status</th>
              <th style={{ padding: '15px 20px', textAlign: 'center', fontSize: '11px', textTransform: 'uppercase' }}>Action</th>
              </tr>
          </thead>
          <tbody>
            {filteredRequests.map(req => (
              <tr key={req.id} style={{ borderBottom: `1px solid ${theme.border}`, transition: '0.2s' }}>
                <td style={{ padding: '15px 20px' }}>
                  <div style={{ fontWeight: '700' }}>{req.client}</div>
                  <div style={{ fontSize: '11px', opacity: 0.6 }}>{req.clientEmail}</div>
                </td>
                <td style={{ padding: '15px 20px', fontWeight: '500' }}>{req.bookingId}</td>
                <td style={{ padding: '15px 20px', fontWeight: '700', color: theme.accent }}>{req.amount} DZD</td>
                <td style={{ padding: '15px 20px', opacity: 0.6 }}>{req.date}</td>
                <td style={{ padding: '15px 20px' }}>
                  <span style={{ 
                    backgroundColor: getStatusBgColor(req.status), 
                    color: getStatusColor(req.status), 
                    padding: '4px 12px', 
                    borderRadius: '20px', 
                    fontSize: '11px', 
                    fontWeight: 'bold' 
                  }}>
                    {req.status}
                  </span>
                </td>
                <td style={{ padding: '15px 20px', textAlign: 'center' }}>
                  {req.status === 'Pending' && (
                    <button 
                      onClick={() => setSelectedRefund(req)}
                      style={{ 
                        background: 'none', 
                        border: `1px solid ${theme.accent}`, 
                        color: theme.accent, 
                        padding: '6px 14px', 
                        borderRadius: '10px', 
                        cursor: 'pointer', 
                        fontSize: '11px', 
                        fontWeight: '700'
                      }}
                    >
                      Process Refund
                    </button>
                  )}
                  {req.status !== 'Pending' && (
                    <button 
                      onClick={() => setSelectedRefund(req)}
                      style={{ 
                        background: 'none', 
                        border: `1px solid ${theme.border}`, 
                        color: theme.text, 
                        padding: '6px 14px', 
                        borderRadius: '10px', 
                        cursor: 'pointer', 
                        fontSize: '11px'
                      }}
                    >
                      View Details
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {filteredRequests.length === 0 && (
        <div style={{ textAlign: 'center', padding: '80px', backgroundColor: theme.card, borderRadius: '30px', border: `1px dashed ${theme.border}` }}>
          <span style={{ fontSize: '60px' }}>💰</span>
          <h3 style={{ color: '#737373', marginTop: '20px' }}>No refund requests found</h3>
        </div>
      )}

      {/* Refund Details Modal */}
      {selectedRefund && (
        <div style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.95)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 2000, backdropFilter: 'blur(10px)' }}>
          <div style={{ backgroundColor: theme.card, padding: '40px', borderRadius: '35px', width: '550px', maxHeight: '80vh', overflowY: 'auto', border: `1px solid ${theme.accent}` }}>
            <h3 style={{ color: theme.accent, marginBottom: '25px', fontSize: '22px' }}>
              {selectedRefund.status === 'Pending' ? 'Process Refund Request' : 'Refund Details'}
            </h3>
            
            <div style={{ display: 'grid', gap: '20px', textAlign: 'left', marginBottom: '35px' }}>
              <div>
                <label style={{ fontSize: '11px', opacity: 0.5, display: 'block', marginBottom: '5px' }}>CLIENT</label>
                <div style={{ fontSize: '16px', fontWeight: 'bold' }}>{selectedRefund.client}</div>
                <div style={{ fontSize: '13px', opacity: 0.7 }}>{selectedRefund.clientEmail}</div>
              </div>
              <div>
                <label style={{ fontSize: '11px', opacity: 0.5, display: 'block', marginBottom: '5px' }}>BOOKING REFERENCE</label>
                <div>{selectedRefund.bookingId} - {selectedRefund.service}</div>
              </div>
              <div>
                <label style={{ fontSize: '11px', opacity: 0.5, display: 'block', marginBottom: '5px' }}>REFUND AMOUNT</label>
                <div style={{ fontSize: '24px', fontWeight: '800', color: theme.accent }}>{selectedRefund.amount} DZD</div>
              </div>
              <div>
                <label style={{ fontSize: '11px', opacity: 0.5, display: 'block', marginBottom: '5px' }}>PAYMENT METHOD</label>
                <div>{selectedRefund.paymentMethod} | Transaction: {selectedRefund.transactionId}</div>
              </div>
              <div>
                <label style={{ fontSize: '11px', opacity: 0.5, display: 'block', marginBottom: '5px' }}>REFUND REASON</label>
                <div style={{ backgroundColor: theme.input, padding: '12px', borderRadius: '12px', border: `1px solid ${theme.border}` }}>
                  {selectedRefund.reason}
                </div>
              </div>
            </div>

            {selectedRefund.status === 'Pending' && (
              <div>
                <label style={{ fontSize: '11px', color: theme.accent, display: 'block', marginBottom: '10px' }}>ADMIN NOTES (Optional)</label>
                <textarea 
                  id="adminNotes"
                  placeholder="Add any notes about this refund decision..."
                  style={{ width: '100%', padding: '12px', marginBottom: '20px', borderRadius: '12px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text, outline: 'none', minHeight: '80px' }}
                />
                <div style={{ display: 'flex', gap: '15px' }}>
                  <button 
                    onClick={() => {
                      const notes = document.getElementById('adminNotes').value;
                      processRefund(selectedRefund.id, 'Approve', notes);
                    }}
                    style={{ flex: 1, padding: '16px', backgroundColor: theme.success, color: '#fff', border: 'none', borderRadius: '15px', fontWeight: 'bold', cursor: 'pointer' }}
                  >
                    ✅ Approve Refund
                  </button>
                  <button 
                    onClick={() => {
                      const notes = document.getElementById('adminNotes').value;
                      processRefund(selectedRefund.id, 'Reject', notes);
                    }}
                    style={{ flex: 1, padding: '16px', backgroundColor: theme.danger, color: '#fff', border: 'none', borderRadius: '15px', fontWeight: 'bold', cursor: 'pointer' }}
                  >
                    ❌ Reject Refund
                  </button>
                </div>
              </div>
            )}

            {selectedRefund.status !== 'Pending' && (
              <div>
                <div style={{ marginBottom: '20px' }}>
                  <label style={{ fontSize: '11px', opacity: 0.5, display: 'block', marginBottom: '5px' }}>PROCESSED AT</label>
                  <div>{selectedRefund.processedAt || 'N/A'}</div>
                </div>
                <div>
                  <label style={{ fontSize: '11px', opacity: 0.5, display: 'block', marginBottom: '5px' }}>ADMIN NOTES</label>
                  <div style={{ backgroundColor: theme.input, padding: '12px', borderRadius: '12px', border: `1px solid ${theme.border}` }}>
                    {selectedRefund.adminNotes || 'No notes provided'}
                  </div>
                </div>
              </div>
            )}
            
            <button 
              onClick={() => setSelectedRefund(null)} 
              style={{ width: '100%', marginTop: '20px', padding: '12px', backgroundColor: '#333', color: '#fff', border: 'none', borderRadius: '12px', cursor: 'pointer' }}
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default RefundClient;