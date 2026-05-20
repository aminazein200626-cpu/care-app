import React, { useState, useEffect } from 'react';

const BookingTracking = ({ isDarkMode }) => {
  const [bookings, setBookings] = useState([]);
  const [selectedBooking, setSelectedBooking] = useState(null);
  const [filterStatus, setFilterStatus] = useState("All");
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);

  // Fetch bookings from API
  const fetchBookings = async () => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch('http://localhost:5001/api/admin/bookings', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();
      
      // ✅ التصحيح: data.bookings هي المصفوفة
      const bookingsArray = data.bookings || [];
      
      const formattedBookings = bookingsArray.map(booking => ({
        id: booking._id,
        client: booking.client,
        clientPhone: booking.clientPhone,
        provider: booking.provider,
        providerPhone: booking.providerPhone,
        service: booking.service,
        startTime: booking.startTime,
        endTime: booking.endTime,
        status: booking.status,
        location: booking.location,
        lat: booking.lat,
        lng: booking.lng,
        dependent: booking.dependent,
        notes: booking.notes
      }));
      
      setBookings(formattedBookings);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching bookings:', error);
      setLoading(false);
    }
  };

  // Update booking status
  const updateBookingStatus = async (bookingId, newStatus) => {
    const token = localStorage.getItem('token');
    setUpdating(true);
    try {
      const response = await fetch(`http://localhost:5001/api/admin/bookings/${bookingId}/status`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ status: newStatus })
      });
      
      const data = await response.json();
      console.log('Update response:', data);
      
      if (response.ok) {
        await fetchBookings();
        alert(`Booking status updated to: ${newStatus}`);
      } else {
        throw new Error(data.message || 'Failed to update status');
      }
    } catch (error) {
      console.error('Error updating booking status:', error);
      alert('Failed to update booking status: ' + error.message);
    } finally {
      setUpdating(false);
    }
  };

  useEffect(() => {
    fetchBookings();
  }, []);

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    accent: '#a3e635',
    primary: '#1a2e05',
    warning: '#f59e0b',
    success: '#10b981'
  };

  const getStatusColor = (status) => {
    switch(status) {
      case 'In Progress': return '#f59e0b';
      case 'Completed': return '#10b981';
      case 'Pending': return '#3b82f6';
      case 'Cancelled': return '#ef4444';
      default: return '#6b7280';
    }
  };

  const getStatusBgColor = (status) => {
    switch(status) {
      case 'In Progress': return 'rgba(245, 158, 11, 0.1)';
      case 'Completed': return 'rgba(16, 185, 129, 0.1)';
      case 'Pending': return 'rgba(59, 130, 246, 0.1)';
      case 'Cancelled': return 'rgba(239, 68, 68, 0.1)';
      default: return 'rgba(107, 114, 128, 0.1)';
    }
  };

  const filteredBookings = filterStatus === "All" 
    ? bookings 
    : bookings.filter(b => b.status === filterStatus);

  const handleTrackUpdate = async (bookingId, newStatus) => {
    await updateBookingStatus(bookingId, newStatus);
  };

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading bookings...</div>;
  }

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div style={{ marginBottom: '30px' }}>
        <h2 style={{ color: '#1a2e05', fontSize: '28px', fontWeight: '800', letterSpacing: '-1px' }}>📍 Live Booking Tracking</h2>
        <p style={{ color: '#737373', fontSize: '14px' }}>Monitor active services, track locations, and update service status</p>
      </div>

      {/* Filter Bar */}
      <div style={{ 
        display: 'flex', gap: '10px', marginBottom: '30px', 
        backgroundColor: theme.card, padding: '15px 20px', borderRadius: '20px', 
        border: `1px solid ${theme.border}`, alignItems: 'center', flexWrap: 'wrap'
      }}>
        <span style={{ fontSize: '12px', fontWeight: '600', color: theme.text }}>Filter by Status:</span>
        {['All', 'In Progress', 'Completed', 'Pending', 'Cancelled'].map(status => (
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

      {/* Bookings Grid */}
      <div style={{ display: 'grid', gap: '20px' }}>
        {filteredBookings.map(booking => (
          <div 
            key={booking.id} 
            style={{ 
              backgroundColor: theme.card, 
              padding: '25px', 
              borderRadius: '25px', 
              border: `1px solid ${theme.border}`,
              transition: '0.3s',
              cursor: 'pointer',
              boxShadow: selectedBooking?.id === booking.id ? `0 0 0 2px ${theme.accent}` : 'none'
            }}
            onClick={() => setSelectedBooking(selectedBooking?.id === booking.id ? null : booking)}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '15px' }}>
              <div style={{ flex: 2 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '15px', flexWrap: 'wrap', marginBottom: '10px' }}>
                  <h3 style={{ margin: 0, fontSize: '18px', fontWeight: '800' }}>{booking.service}</h3>
                  <span style={{ 
                    backgroundColor: getStatusBgColor(booking.status), 
                    color: getStatusColor(booking.status), 
                    padding: '4px 12px', 
                    borderRadius: '20px', 
                    fontSize: '11px', 
                    fontWeight: 'bold' 
                  }}>
                    {booking.status}
                  </span>
                </div>
                <div style={{ display: 'flex', gap: '30px', fontSize: '13px', color: '#737373', flexWrap: 'wrap', marginBottom: '10px' }}>
                  <span>👤 {booking.client}</span>
                  <span>👨‍⚕️ {booking.provider}</span>
                  <span>👶 {booking.dependent}</span>
                </div>
                <div style={{ display: 'flex', gap: '30px', fontSize: '12px', color: '#737373', flexWrap: 'wrap' }}>
                  <span>🕒 {booking.startTime} → {booking.endTime}</span>
                  <span>📍 {booking.location}</span>
                </div>
              </div>
              <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                {booking.status === 'In Progress' && (
                  <button 
                    onClick={async (e) => { 
                      e.stopPropagation(); 
                      await handleTrackUpdate(booking.id, 'Completed');
                    }}
                    disabled={updating}
                    style={{ 
                      padding: '10px 20px', 
                      backgroundColor: updating ? '#cccccc' : theme.success, 
                      color: '#fff', 
                      border: 'none', 
                      borderRadius: '12px', 
                      fontWeight: 'bold', 
                      cursor: updating ? 'not-allowed' : 'pointer', 
                      fontSize: '12px',
                      opacity: updating ? 0.6 : 1
                    }}
                  >
                    {updating ? 'Updating...' : 'Mark Complete'}
                  </button>
                )}
                <span style={{ fontSize: '24px' }}>▼</span>
              </div>
            </div>

            {/* Expanded Details */}
            {selectedBooking?.id === booking.id && (
              <div style={{ 
                marginTop: '20px', 
                paddingTop: '20px', 
                borderTop: `1px solid ${theme.border}`,
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
                gap: '20px'
              }}>
                <div>
                  <h4 style={{ color: theme.accent, fontSize: '12px', marginBottom: '10px' }}>CLIENT INFORMATION</h4>
                  <p style={{ margin: '5px 0', fontSize: '13px' }}><strong>Name:</strong> {booking.client}</p>
                  <p style={{ margin: '5px 0', fontSize: '13px' }}><strong>Phone:</strong> {booking.clientPhone}</p>
                  <p style={{ margin: '5px 0', fontSize: '13px' }}><strong>Dependent:</strong> {booking.dependent}</p>
                </div>
                <div>
                  <h4 style={{ color: theme.accent, fontSize: '12px', marginBottom: '10px' }}>PROVIDER INFORMATION</h4>
                  <p style={{ margin: '5px 0', fontSize: '13px' }}><strong>Name:</strong> {booking.provider}</p>
                  <p style={{ margin: '5px 0', fontSize: '13px' }}><strong>Phone:</strong> {booking.providerPhone}</p>
                </div>
                <div>
                  <h4 style={{ color: theme.accent, fontSize: '12px', marginBottom: '10px' }}>SERVICE DETAILS</h4>
                  <p style={{ margin: '5px 0', fontSize: '13px' }}><strong>Time:</strong> {booking.startTime} - {booking.endTime}</p>
                  <p style={{ margin: '5px 0', fontSize: '13px' }}><strong>Special Notes:</strong> {booking.notes}</p>
                </div>
                <div>
                  <h4 style={{ color: theme.accent, fontSize: '12px', marginBottom: '10px' }}>LOCATION TRACKING</h4>
                  <div style={{ 
                    backgroundColor: theme.input, 
                    padding: '15px', 
                    borderRadius: '15px', 
                    textAlign: 'center',
                    border: `1px solid ${theme.border}`
                  }}>
                    <span style={{ fontSize: '32px' }}>📍</span>
                    <p style={{ fontSize: '11px', marginTop: '5px' }}>Live GPS Tracking Active</p>
                    <p style={{ fontSize: '10px', opacity: 0.6 }}>Lat: {booking.lat}, Lng: {booking.lng}</p>
                    <button style={{ marginTop: '10px', padding: '6px 12px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '8px', fontSize: '10px', cursor: 'pointer' }}>
                      View on Map
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>

      {filteredBookings.length === 0 && (
        <div style={{ textAlign: 'center', padding: '80px', backgroundColor: theme.card, borderRadius: '30px', border: `1px dashed ${theme.border}` }}>
          <span style={{ fontSize: '60px' }}>📭</span>
          <h3 style={{ color: '#737373', marginTop: '20px' }}>No bookings found for this status</h3>
        </div>
      )}
    </div>
  );
};

export default BookingTracking;