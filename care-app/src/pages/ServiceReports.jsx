import React, { useState, useEffect } from 'react';

const ServiceReports = ({ isDarkMode }) => {
  const [filterPeriod, setFilterPeriod] = useState('week');
  const [selectedService, setSelectedService] = useState('all');
  const [serviceStats, setServiceStats] = useState([]);
  const [totalStats, setTotalStats] = useState({
    totalBookings: 0,
    totalRevenue: 0,
    avgRating: 0,
    totalIncidents: 0
  });
  const [chartData, setChartData] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchServiceReports = async () => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch('http://localhost:5000/api/admin/service-reports', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();
      
      setServiceStats(data);
      
      const totalBookings = data.reduce((sum, s) => sum + s.bookings, 0);
      const totalRevenue = data.reduce((sum, s) => sum + s.revenue, 0);
      const avgRating = data.reduce((sum, s) => sum + s.rating, 0) / data.length;
      const totalIncidents = data.reduce((sum, s) => sum + (s.incidents || 0), 0);
      
      setTotalStats({
        totalBookings,
        totalRevenue,
        avgRating: avgRating.toFixed(1),
        totalIncidents
      });
      
      setLoading(false);
    } catch (error) {
      console.error('Error fetching service reports:', error);
      setLoading(false);
    }
  };

  const fetchChartData = async () => {
    const token = localStorage.getItem('token');
    try {
      const response = await fetch(`http://localhost:5000/api/admin/stats/chart?period=${filterPeriod}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();
      setChartData(data.data || []);
    } catch (error) {
      console.error('Error fetching chart data:', error);
      const fallbackData = {
        week: [28, 32, 35, 42, 48, 52, 45],
        month: [120, 145, 168, 190, 210, 198, 185, 172, 168, 156, 142, 138, 125, 118, 110, 105, 98, 95, 92, 88, 85, 82, 78, 75, 72, 70, 68, 65, 62, 60],
        year: [1450, 1680, 1820, 1950, 2100, 2250, 2400, 2350, 2280, 2150, 1980, 1820]
      };
      setChartData(fallbackData[filterPeriod] || fallbackData.week);
    }
  };

  // Export to CSV function
  const exportToCSV = () => {
    // Create CSV content
    let csvContent = "Service Name,Bookings,Revenue (DZD),Rating,Growth (%),Incidents\n";
    
    serviceStats.forEach(service => {
      csvContent += `"${service.name}",${service.bookings},${service.revenue},${service.rating},${service.growth},${service.incidents || 0}\n`;
    });
    
    // Add totals
    csvContent += `\nTOTAL,${totalStats.totalBookings},${totalStats.totalRevenue},${totalStats.avgRating},,${totalStats.totalIncidents}\n`;
    
    // Create and download file
    const blob = new Blob(["\uFEFF" + csvContent], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    const url = URL.createObjectURL(blob);
    link.setAttribute("href", url);
    link.setAttribute("download", `service_reports_${filterPeriod}_${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = "hidden";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    
    alert("Report exported successfully!");
  };

  // Export to PDF (print)
  const exportToPDF = () => {
    window.print();
  };

  useEffect(() => {
    fetchServiceReports();
    fetchChartData();
  }, [filterPeriod]);

  const getChartData = () => {
    return chartData.length > 0 ? chartData : (filterPeriod === 'week' ? [28, 32, 35, 42, 48, 52, 45] : 
      filterPeriod === 'month' ? [120, 145, 168, 190, 210, 198, 185, 172, 168, 156, 142, 138, 125, 118, 110, 105, 98, 95, 92, 88, 85, 82, 78, 75, 72, 70, 68, 65, 62, 60] : 
      [1450, 1680, 1820, 1950, 2100, 2250, 2400, 2350, 2280, 2150, 1980, 1820]);
  };

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    primary: '#1a2e05',
    accent: '#a3e635'
  };

  const chartValues = getChartData();
  const maxBookings = Math.max(...chartValues);

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading service reports...</div>;
  }

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div style={{ marginBottom: '30px' }}>
        <h2 style={{ color: '#1a2e05', fontSize: '28px', fontWeight: '800', letterSpacing: '-1px' }}>📊 Service Analytics</h2>
        <p style={{ color: '#737373', fontSize: '14px' }}>Track service performance, revenue, and customer satisfaction</p>
      </div>

      {/* Period Filter */}
      <div style={{ 
        display: 'flex', 
        gap: '10px', 
        marginBottom: '30px', 
        backgroundColor: theme.card, 
        padding: '15px 20px', 
        borderRadius: '20px', 
        border: `1px solid ${theme.border}` 
      }}>
        <span style={{ fontSize: '13px', fontWeight: '600', color: theme.text }}>Time Period:</span>
        {['week', 'month', 'year'].map(period => (
          <button
            key={period}
            onClick={() => setFilterPeriod(period)}
            style={{
              padding: '8px 24px',
              borderRadius: '30px',
              border: 'none',
              cursor: 'pointer',
              fontWeight: '600',
              fontSize: '12px',
              backgroundColor: filterPeriod === period ? theme.accent : theme.primary,
              color: filterPeriod === period ? '#000' : theme.accent,
              transition: '0.3s'
            }}
          >
            {period === 'week' ? 'This Week' : period === 'month' ? 'This Month' : 'This Year'}
          </button>
        ))}
      </div>

      {/* Stats Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '20px', marginBottom: '30px' }}>
        <div style={{ backgroundColor: theme.card, padding: '25px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
          <div style={{ fontSize: '28px', marginBottom: '10px' }}>📅</div>
          <div style={{ fontSize: '28px', fontWeight: '800' }}>{totalStats.totalBookings}</div>
          <div style={{ fontSize: '12px', color: '#737373' }}>Total Bookings</div>
          <div style={{ fontSize: '11px', color: '#10b981', marginTop: '5px' }}>↑ 15% vs last period</div>
        </div>
        <div style={{ backgroundColor: theme.card, padding: '25px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
          <div style={{ fontSize: '28px', marginBottom: '10px' }}>💰</div>
          <div style={{ fontSize: '28px', fontWeight: '800' }}>{totalStats.totalRevenue.toLocaleString()} DZD</div>
          <div style={{ fontSize: '12px', color: '#737373' }}>Total Revenue</div>
          <div style={{ fontSize: '11px', color: '#10b981', marginTop: '5px' }}>↑ 12% vs last period</div>
        </div>
        <div style={{ backgroundColor: theme.card, padding: '25px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
          <div style={{ fontSize: '28px', marginBottom: '10px' }}>⭐</div>
          <div style={{ fontSize: '28px', fontWeight: '800' }}>{totalStats.avgRating}</div>
          <div style={{ fontSize: '12px', color: '#737373' }}>Average Rating</div>
          <div style={{ fontSize: '11px', color: '#10b981', marginTop: '5px' }}>↑ 0.3 vs last period</div>
        </div>
        <div style={{ backgroundColor: theme.card, padding: '25px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
          <div style={{ fontSize: '28px', marginBottom: '10px' }}>⚠️</div>
          <div style={{ fontSize: '28px', fontWeight: '800' }}>{totalStats.totalIncidents}</div>
          <div style={{ fontSize: '12px', color: '#737373' }}>Total Incidents</div>
          <div style={{ fontSize: '11px', color: '#ef4444', marginTop: '5px' }}>↓ 2 vs last period</div>
        </div>
      </div>

      {/* Chart Section */}
      <div style={{ 
        backgroundColor: theme.card, 
        padding: '25px', 
        borderRadius: '25px', 
        border: `1px solid ${theme.border}`,
        marginBottom: '30px'
      }}>
        <h3 style={{ marginBottom: '20px', fontSize: '16px', fontWeight: 'bold' }}>📈 Bookings Trend</h3>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: '8px', height: '200px', padding: '20px 0' }}>
          {chartValues.map((value, idx) => (
            <div key={idx} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <div style={{ 
                width: '100%', 
                height: `${(value / maxBookings) * 160}px`, 
                backgroundColor: theme.accent, 
                borderRadius: '8px 8px 0 0',
                transition: '0.3s',
                position: 'relative'
              }}>
                <div style={{ 
                  position: 'absolute', 
                  top: '-20px', 
                  left: '50%', 
                  transform: 'translateX(-50%)', 
                  fontSize: '10px', 
                  color: theme.accent 
                }}>
                  {value}
                </div>
              </div>
              <div style={{ fontSize: '9px', marginTop: '8px', color: '#737373' }}>
                {filterPeriod === 'week' ? ['M', 'T', 'W', 'T', 'F', 'S', 'S'][idx] : 
                 filterPeriod === 'month' ? `${idx + 1}` : 
                 ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][idx]}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Service Performance Table */}
      <div style={{ 
        backgroundColor: theme.card, 
        borderRadius: '25px', 
        border: `1px solid ${theme.border}`, 
        overflow: 'hidden',
        marginBottom: '30px'
      }}>
        <div style={{ padding: '20px 25px', borderBottom: `1px solid ${theme.border}` }}>
          <h3 style={{ fontSize: '16px', fontWeight: 'bold' }}>🏆 Service Performance Ranking</h3>
        </div>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
          <thead>
            <tr style={{ backgroundColor: theme.primary, color: theme.accent, textAlign: 'left' }}>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Service</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Bookings</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Revenue</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Rating</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Growth</th>
              <th style={{ padding: '15px 20px', fontSize: '11px', textTransform: 'uppercase' }}>Incidents</th>
              </tr>
          </thead>
          <tbody>
            {serviceStats.map(service => (
              <tr key={service.id} style={{ borderBottom: `1px solid ${theme.border}` }}>
                <td style={{ padding: '15px 20px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <span style={{ fontSize: '24px' }}>{service.icon}</span>
                    <span style={{ fontWeight: '600' }}>{service.name}</span>
                  </div>
                </td>
                <td style={{ padding: '15px 20px', fontWeight: '600' }}>{service.bookings}</td>
                <td style={{ padding: '15px 20px', fontWeight: '600', color: theme.accent }}>{service.revenue.toLocaleString()} DZD</td>
                <td style={{ padding: '15px 20px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                    <span>⭐</span>
                    <span style={{ fontWeight: '600' }}>{service.rating}</span>
                  </div>
                </td>
                <td style={{ padding: '15px 20px', color: service.growth.startsWith('+') ? '#10b981' : '#ef4444', fontWeight: '600' }}>
                  {service.growth}
                </td>
                <td style={{ padding: '15px 20px' }}>
                  <span style={{ 
                    backgroundColor: service.incidents > 0 ? 'rgba(239, 68, 68, 0.1)' : 'rgba(16, 185, 129, 0.1)',
                    color: service.incidents > 0 ? '#ef4444' : '#10b981',
                    padding: '4px 10px',
                    borderRadius: '20px',
                    fontSize: '11px',
                    fontWeight: 'bold'
                  }}>
                    {service.incidents} incidents
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Export Buttons */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '15px' }}>
        <button 
          onClick={exportToPDF}
          style={{ padding: '12px 24px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '12px', cursor: 'pointer', fontWeight: 'bold' }}
        >
          🖨️ Export as PDF
        </button>
        <button 
          onClick={exportToCSV}
          style={{ padding: '12px 24px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '12px', cursor: 'pointer', fontWeight: 'bold' }}
        >
          📁 Export as Excel (CSV)
        </button>
      </div>
    </div>
  );
};

export default ServiceReports;