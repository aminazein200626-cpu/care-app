import React, { useState, useEffect } from 'react';

const InscriptionRequests = ({ isDarkMode }) => {
  const [requests, setRequests] = useState([]);
  const [selectedReq, setSelectedReq] = useState(null);
  const [previewDocument, setPreviewDocument] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const fetchRequests = async () => {
    const token = localStorage.getItem('token');
    if (!token) {
      setError('No authentication token found. Please login again.');
      setLoading(false);
      return;
    }
    try {
      const response = await fetch('http://localhost:5001/api/admin/requests', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      const data = await response.json();
      console.log('Raw API response:', data);

      // البيانات تأتي في data.requests (مصفوفة)
      const requestsArray = data.requests || data;
      if (!Array.isArray(requestsArray)) {
        throw new Error('Invalid response format: expected array');
      }

      const formattedRequests = requestsArray.map(req => {
        // استخراج معرف الطلب (قد يكون req._id أو req.id)
        const requestId = req._id || req.id;
        
        let providerDetails = req.providerDetails || {};
        if (typeof providerDetails === 'string') {
          try { providerDetails = JSON.parse(providerDetails); } catch(e) { providerDetails = {}; }
        }
        
        // معالجة المستندات والشهادات (قد تكون مصفوفة أو كائنات)
        const documents = providerDetails.documents && Array.isArray(providerDetails.documents) 
          ? providerDetails.documents 
          : (providerDetails.documents ? [providerDetails.documents] : []);
        const certificates = providerDetails.certificates && Array.isArray(providerDetails.certificates)
          ? providerDetails.certificates
          : (providerDetails.certificates ? [providerDetails.certificates] : []);
        
        return {
          id: requestId,
          name: req.fullName || providerDetails.fullName || 'N/A',
          email: req.email || providerDetails.email || 'N/A',
          phoneNumber: providerDetails.phoneNumber || req.phoneNumber || 'N/A',
          wilaya: providerDetails.wilaya || req.wilaya || 'N/A',
          address: providerDetails.address || req.address || 'N/A',
          postalCode: providerDetails.postalCode || req.postalCode || 'N/A',
          gender: providerDetails.gender || req.gender || 'N/A',
          nationalId: providerDetails.nationalId || req.nationalId || 'N/A',
          dateOfBirth: providerDetails.dateOfBirth 
            ? new Date(providerDetails.dateOfBirth).toISOString().split('T')[0] 
            : (req.dateOfBirth ? new Date(req.dateOfBirth).toISOString().split('T')[0] : 'N/A'),
          service: (providerDetails.services && providerDetails.services[0]) 
            || providerDetails.serviceType 
            || req.service 
            || 'N/A',
          date: req.createdAt ? new Date(req.createdAt).toISOString().split('T')[0] : 'N/A',
          experience: providerDetails.yearsOfExperience || providerDetails.years_of_exp || 'N/A',
          hourlyRate: providerDetails.hourlyRate || 0,
          bio: providerDetails.bio || 'N/A',
          workHours: providerDetails.workHours || 'N/A',
          travelDistance: providerDetails.travelDistance || 'Local Only',
          travelCost: providerDetails.travelCost || 0,
          motivation: providerDetails.motivation || 'N/A',
          status: providerDetails.status || 'pending',
          profileImage: req.profilePicture || providerDetails.profilePicture || '/images/default-avatar.jpg',
          documents: documents,
          certificates: certificates,
        };
      });

      setRequests(formattedRequests);
      setError('');
      setLoading(false);
    } catch (error) {
      console.error('Error fetching requests:', error);
      setError(error.message);
      setLoading(false);
    }
  };

  const handleDecision = async (id, decision, rejectionReason = '') => {
    const token = localStorage.getItem('token');
    if (!token) {
      alert('Please login again');
      return;
    }
    try {
      const response = await fetch(`http://localhost:5001/api/admin/requests/${id}/verify`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ 
          status: decision === 'Accepted' ? 'approved' : 'rejected',
          rejectionReason: rejectionReason 
        })
      });
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || 'Request failed');
      }
      alert(`Request has been ${decision}`);
      fetchRequests(); // تحديث القائمة
      setSelectedReq(null);
    } catch (error) {
      console.error('Error updating request:', error);
      alert('Failed to update request: ' + error.message);
    }
  };

  useEffect(() => {
    fetchRequests();
  }, []);

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    primary: '#1a2e05',
    accent: '#a3e635',
    danger: '#450a0a',
  };

  const openDocumentPreview = (docName, docUrl, docType) => {
    setPreviewDocument({ name: docName, url: docUrl, type: docType });
  };

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading requests...</div>;
  }

  if (error) {
    return (
      <div style={{ textAlign: 'center', padding: '50px', color: 'red' }}>
        <p>Error loading requests: {error}</p>
        <button onClick={fetchRequests} style={{ marginTop: '10px', padding: '8px 16px' }}>Retry</button>
      </div>
    );
  }

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div style={{ marginBottom: '30px' }}>
        <h2 style={{ color: '#1a2e05', fontSize: '26px', fontWeight: '800', letterSpacing: '-1px' }}>Provider Applications</h2>
        <p style={{ color: '#1a2e05', fontSize: '14px' }}>Review and verify new provider applications with all supporting documents</p>
      </div>

      {requests.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '100px', backgroundColor: theme.card, borderRadius: '30px', border: `1px dashed #333` }}>
          <span style={{ fontSize: '50px' }}>📁</span>
          <h3 style={{ color: '#737373', marginTop: '20px' }}>No pending requests found</h3>
        </div>
      ) : (
        <div style={{ backgroundColor: theme.card, borderRadius: '25px', border: `1px solid ${theme.border}`, overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ backgroundColor: theme.primary, color: theme.accent, textAlign: 'left' }}>
                <th style={{ padding: '20px' }}>Provider</th>
                <th style={{ padding: '20px' }}>Service Type</th>
                <th style={{ padding: '20px' }}>Experience (Years)</th>
                <th style={{ padding: '20px' }}>Submitted</th>
                <th style={{ padding: '20px', textAlign: 'center' }}>Action</th>
               </tr>
            </thead>
            <tbody>
              {requests.map(req => (
                <tr key={req.id} style={{ borderBottom: `1px solid ${theme.border}` }}>
                  <td style={{ padding: '20px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <div style={{ width: '40px', height: '40px', borderRadius: '50%', overflow: 'hidden', backgroundColor: theme.input }}>
                        <img src={req.profileImage} alt={req.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      </div>
                      <div>
                        <div style={{ fontWeight: '700' }}>{req.name}</div>
                        <div style={{ fontSize: '12px', opacity: 0.6 }}>{req.email}</div>
                      </div>
                    </div>
                   </td>
                  <td style={{ padding: '20px' }}>
                    <span style={{ backgroundColor: 'rgba(163, 230, 53, 0.1)', color: theme.accent, padding: '5px 12px', borderRadius: '10px', fontSize: '12px' }}>
                      {req.service}
                    </span>
                   </td>
                  <td style={{ padding: '20px', fontWeight: '500' }}>{req.experience}</td>
                  <td style={{ padding: '20px', opacity: 0.8 }}>{req.date}</td>
                  <td style={{ padding: '20px', textAlign: 'center' }}>
                    <button 
                      onClick={() => setSelectedReq(req)}
                      style={{ backgroundColor: 'transparent', border: `1px solid ${theme.accent}`, color: theme.accent, padding: '8px 18px', borderRadius: '12px', cursor: 'pointer', fontWeight: '600' }}
                    >
                      Verify Documents
                    </button>
                   </td>
                 </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {selectedReq && (
        <div style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.95)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 2000, backdropFilter: 'blur(10px)', overflow: 'auto' }}>
          <div style={{ backgroundColor: theme.card, padding: '40px', borderRadius: '35px', width: '900px', maxHeight: '90vh', overflowY: 'auto', border: `1px solid ${theme.accent}` }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '25px' }}>
              <h3 style={{ color: theme.accent, fontSize: '22px' }}>Provider Verification</h3>
              <button onClick={() => setSelectedReq(null)} style={{ background: 'none', border: 'none', color: '#737373', fontSize: '24px', cursor: 'pointer' }}>✕</button>
            </div>
            
            <div style={{ marginBottom: '30px', padding: '20px', backgroundColor: theme.input, borderRadius: '20px' }}>
              <h4 style={{ color: theme.accent, marginBottom: '15px' }}>📋 Personal Information</h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <p><strong>Full Name:</strong> {selectedReq.name}</p>
                <p><strong>Email:</strong> {selectedReq.email}</p>
                <p><strong>Phone:</strong> {selectedReq.phoneNumber}</p>
                <p><strong>Gender:</strong> {selectedReq.gender}</p>
                <p><strong>National ID:</strong> {selectedReq.nationalId}</p>
                <p><strong>Date of Birth:</strong> {selectedReq.dateOfBirth}</p>
                <p><strong>Wilaya:</strong> {selectedReq.wilaya}</p>
                <p><strong>Address:</strong> {selectedReq.address}</p>
                <p><strong>Postal Code:</strong> {selectedReq.postalCode}</p>
              </div>
            </div>

            <div style={{ marginBottom: '30px', padding: '20px', backgroundColor: theme.input, borderRadius: '20px' }}>
              <h4 style={{ color: theme.accent, marginBottom: '15px' }}>💼 Professional Information</h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <p><strong>Experience (Years):</strong> {selectedReq.experience}</p>
                <p><strong>Hourly Rate:</strong> {selectedReq.hourlyRate} DZD</p>
                <p><strong>Work Hours:</strong> {selectedReq.workHours}</p>
                <p><strong>Travel Distance:</strong> {selectedReq.travelDistance}</p>
                <p><strong>Travel Cost:</strong> {selectedReq.travelCost} DZD</p>
                <p><strong>Services:</strong> {selectedReq.service}</p>
              </div>
              <p><strong>Bio:</strong> {selectedReq.bio}</p>
              <p><strong>Motivation:</strong> {selectedReq.motivation}</p>
            </div>

            <div style={{ marginBottom: '30px' }}>
              <h4 style={{ color: theme.accent, marginBottom: '15px' }}>📎 Verification Documents</h4>
              
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px', marginBottom: '15px' }}>
                <div style={{ padding: '15px', backgroundColor: theme.input, borderRadius: '15px', border: `1px solid ${theme.border}` }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div><span style={{ fontSize: '20px', marginRight: '10px' }}>🪪</span><span style={{ fontWeight: 'bold' }}>National ID Card</span></div>
                    <button onClick={() => openDocumentPreview('ID Card', selectedReq.documents?.find(d => d.type === 'idCard')?.path || '#', 'pdf')} style={{ padding: '6px 12px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '8px', cursor: 'pointer', fontSize: '11px' }}>Preview</button>
                  </div>
                </div>
                <div style={{ padding: '15px', backgroundColor: theme.input, borderRadius: '15px', border: `1px solid ${theme.border}` }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div><span style={{ fontSize: '20px', marginRight: '10px' }}>📜</span><span style={{ fontWeight: 'bold' }}>Professional License</span></div>
                    <button onClick={() => openDocumentPreview('License', selectedReq.documents?.find(d => d.type === 'license')?.path || '#', 'pdf')} style={{ padding: '6px 12px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '8px', cursor: 'pointer', fontSize: '11px' }}>Preview</button>
                  </div>
                </div>
              </div>

              <div style={{ padding: '15px', backgroundColor: theme.input, borderRadius: '15px', border: `1px solid ${theme.border}` }}>
                <div style={{ marginBottom: '10px' }}>
                  <span style={{ fontSize: '20px', marginRight: '10px' }}>🏅</span>
                  <span style={{ fontWeight: 'bold' }}>Certificates ({selectedReq.certificates && selectedReq.certificates.length ? selectedReq.certificates.length : 0})</span>
                </div>
                {selectedReq.certificates && selectedReq.certificates.length > 0 ? (
                  selectedReq.certificates.map((cert, idx) => (
                    <div key={idx} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '10px', paddingTop: '10px', borderTop: `1px solid ${theme.border}` }}>
                      <div style={{ fontSize: '13px' }}>📄 {cert.name || `Certificate ${idx+1}`}</div>
                      <button onClick={() => openDocumentPreview(cert.name || 'Certificate', cert.path || cert.url, 'pdf')} style={{ padding: '4px 10px', backgroundColor: 'transparent', color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '6px', cursor: 'pointer', fontSize: '10px' }}>View</button>
                    </div>
                  ))
                ) : <p style={{ fontSize: '12px', opacity: 0.6 }}>No certificates uploaded</p>}
              </div>
            </div>

            <div style={{ display: 'flex', gap: '15px', marginTop: '20px' }}>
              <button onClick={() => handleDecision(selectedReq.id, 'Accepted')} style={{ flex: 1, padding: '16px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '15px', fontWeight: 'bold', cursor: 'pointer' }}>✅ APPROVE PROVIDER</button>
              <button onClick={() => { const reason = prompt('Enter rejection reason:'); handleDecision(selectedReq.id, 'Rejected', reason || 'No reason provided'); }} style={{ flex: 1, padding: '16px', backgroundColor: theme.danger, color: '#fecaca', border: 'none', borderRadius: '15px', fontWeight: 'bold', cursor: 'pointer' }}>❌ REJECT</button>
            </div>
          </div>
        </div>
      )}

      {previewDocument && (
        <div style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.98)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 3000, backdropFilter: 'blur(8px)' }}>
          <div style={{ backgroundColor: theme.card, padding: '30px', borderRadius: '30px', width: '80%', maxWidth: '800px', maxHeight: '80vh', border: `1px solid ${theme.accent}` }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <h3 style={{ color: theme.accent, margin: 0 }}>{previewDocument.name}</h3>
              <button onClick={() => setPreviewDocument(null)} style={{ background: 'none', border: 'none', color: '#fff', fontSize: '24px', cursor: 'pointer' }}>✕</button>
            </div>
            <div style={{ backgroundColor: theme.input, borderRadius: '15px', padding: '20px', minHeight: '400px', display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
              {previewDocument.type === 'image' ? (
                <img src={previewDocument.url} alt={previewDocument.name} style={{ maxWidth: '100%', maxHeight: '60vh', borderRadius: '8px' }} />
              ) : (
                <div style={{ textAlign: 'center' }}>
                  <span style={{ fontSize: '60px' }}>📄</span>
                  <p style={{ marginTop: '15px', color: theme.accent }}>PDF Document</p>
                  <a href={previewDocument.url} target="_blank" rel="noopener noreferrer" style={{ color: theme.accent, textDecoration: 'underline' }}>Download {previewDocument.name}</a>
                </div>
              )}
            </div>
            <button onClick={() => setPreviewDocument(null)} style={{ width: '100%', marginTop: '20px', padding: '12px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '12px', cursor: 'pointer' }}>Close Preview</button>
          </div>
        </div>
      )}
    </div>
  );
};

export default InscriptionRequests;