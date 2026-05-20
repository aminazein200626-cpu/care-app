import React, { useState, useEffect } from 'react';

const AdminStats = ({ isDarkMode }) => {
  const [filter, setFilter] = useState("period");
  const [dateRange, setDateRange] = useState({ start: "2026-03-01", end: "2026-03-31" });
  const [platformStats, setPlatformStats] = useState({
    totalUsers: 0,
    totalProviders: 0,
    totalBookings: 0,
    totalRevenue: 0,
    avgRating: 0,
    pendingRequests: 0,
    activeServices: 0,
    completionRate: 0,
    userGrowth: "+0%",
    revenueGrowth: "+0%"
  });
  const [periodData, setPeriodData] = useState({
    week: { bookings: 0, revenue: 0, newUsers: 0, activeProviders: 0 },
    month: { bookings: 0, revenue: 0, newUsers: 0, activeProviders: 0 },
    year: { bookings: 0, revenue: 0, newUsers: 0, activeProviders: 0 }
  });
  const [serviceData, setServiceData] = useState([]);
  const [incidentData, setIncidentData] = useState([]);
  const [loading, setLoading] = useState(true);

  // Fetch all stats from API
  const fetchAllStats = async () => {
    const token = localStorage.getItem('token');
    try {
      // Fetch platform stats
      const statsResponse = await fetch('http://localhost:5001/api/admin/stats', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const statsData = await statsResponse.json();
      
      setPlatformStats({
        totalUsers: statsData.totalUsers || 0,
        totalProviders: statsData.totalProviders || 0,
        totalBookings: statsData.totalBookings || 0,
        totalRevenue: statsData.totalRevenue || 0,
        avgRating: statsData.avgRating || 4.78,
        pendingRequests: statsData.pendingProviders || 0,
        activeServices: statsData.activeServices || 0,
        completionRate: statsData.completionRate || 94,
        userGrowth: statsData.userGrowth || "+12%",
        revenueGrowth: statsData.revenueGrowth || "+8%"
      });

      // Fetch service performance
      const serviceResponse = await fetch('http://localhost:5001/api/admin/service-reports', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const serviceDataRaw = await serviceResponse.json();
      
      const formattedServiceData = serviceDataRaw.map(s => ({
        name: s.name,
        bookings: s.bookings,
        revenue: s.revenue,
        rating: s.rating,
        growth: parseInt(s.growth) || 0
      }));
      setServiceData(formattedServiceData);

      // Fetch incident data (mock for now - will be replaced with real API)
      setIncidentData([
        { type: "Late Arrival", count: 12, percentage: 34 },
        { type: "Unprofessional Behavior", count: 8, percentage: 23 },
        { type: "Cancellation", count: 7, percentage: 20 },
        { type: "Payment Issue", count: 5, percentage: 14 },
        { type: "Other", count: 3, percentage: 9 }
      ]);

      // Fetch period data
      const periodResponse = await fetch('http://localhost:5001/api/admin/stats/period', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const periodDataRaw = await periodResponse.json();
      
      setPeriodData({
        week: periodDataRaw.week || { bookings: 156, revenue: 312000, newUsers: 48, activeProviders: 128 },
        month: periodDataRaw.month || { bookings: 624, revenue: 1248000, newUsers: 189, activeProviders: 452 },
        year: periodDataRaw.year || { bookings: 2840, revenue: 5680000, newUsers: 2840, activeProviders: 452 }
      });

      setLoading(false);
    } catch (error) {
      console.error('Error fetching stats:', error);
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAllStats();
  }, []);

  const theme = {
    card: isDarkMode ? '#0a0a0a' : '#ffffff',
    text: isDarkMode ? '#e5e5e5' : '#171717',
    border: isDarkMode ? '#1f1f1f' : '#eee',
    input: isDarkMode ? '#050505' : '#f9f9f9',
    accent: '#a3e635',
    primary: '#1a2e05'
  };

  const getCurrentData = () => {
    if (filter === "period") return periodData.month;
    if (filter === "service") return serviceData;
    return incidentData;
  };

  const maxBookings = serviceData.length > 0 ? Math.max(...serviceData.map(s => s.bookings)) : 100;

  // Export to CSV function
  const exportToCSV = () => {
    let csvContent = "";
    let fileName = "";

    if (filter === "period") {
      fileName = `statistics_period_${dateRange.start}_to_${dateRange.end}.csv`;
      csvContent = "Metric,Value\n";
      csvContent += `Total Bookings,${periodData.month.bookings}\n`;
      csvContent += `Total Revenue (DZD),${periodData.month.revenue}\n`;
      csvContent += `New Users,${periodData.month.newUsers}\n`;
      csvContent += `Active Providers,${periodData.month.activeProviders}\n`;
      csvContent += `Date Range,${dateRange.start} to ${dateRange.end}\n`;
    } 
    else if (filter === "service") {
      fileName = `statistics_services_${new Date().toISOString().split('T')[0]}.csv`;
      csvContent = "Service Name,Bookings,Revenue (DZD),Rating (out of 5),Growth (%)\n";
      serviceData.forEach(service => {
        csvContent += `"${service.name}",${service.bookings},${service.revenue},${service.rating},${service.growth}\n`;
      });
      const totalBookings = serviceData.reduce((sum, s) => sum + s.bookings, 0);
      const totalRevenue = serviceData.reduce((sum, s) => sum + s.revenue, 0);
      csvContent += `\nTOTAL,${totalBookings},${totalRevenue},,\n`;
    } 
    else if (filter === "incidents") {
      fileName = `statistics_incidents_${new Date().toISOString().split('T')[0]}.csv`;
      csvContent = "Incident Type,Count,Percentage (%)\n";
      incidentData.forEach(incident => {
        csvContent += `"${incident.type}",${incident.count},${incident.percentage}\n`;
      });
      const totalIncidents = incidentData.reduce((sum, i) => sum + i.count, 0);
      csvContent += `\nTOTAL INCIDENTS,${totalIncidents},100\n`;
    }

    csvContent += "\n\n=== PLATFORM OVERVIEW ===\n";
    csvContent += `Total Users,${platformStats.totalUsers}\n`;
    csvContent += `Total Providers,${platformStats.totalProviders}\n`;
    csvContent += `Total Bookings,${platformStats.totalBookings}\n`;
    csvContent += `Total Revenue (DZD),${platformStats.totalRevenue}\n`;
    csvContent += `Average Rating,${platformStats.avgRating}\n`;
    csvContent += `Completion Rate (%),${platformStats.completionRate}\n`;
    csvContent += `Generated on,${new Date().toLocaleString()}\n`;

    const blob = new Blob(["\uFEFF" + csvContent], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    const url = URL.createObjectURL(blob);
    link.setAttribute("href", url);
    link.setAttribute("download", fileName);
    link.style.visibility = "hidden";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);

    alert(`Statistics exported successfully!\nFile: ${fileName}`);
  };

  if (loading) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>Loading statistics...</div>;
  }

  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div style={{ marginBottom: '30px' }}>
        <h2 style={{ color: '#1a2e05', fontSize: '28px', fontWeight: '800', letterSpacing: '-1px' }}>📈 Platform Statistics</h2>
        <p style={{ color: '#737373', fontSize: '14px' }}>Comprehensive analytics and performance metrics</p>
      </div>

      {/* Filter Bar */}
      <div style={{ 
        display: 'flex', gap: '15px', marginBottom: '30px', flexWrap: 'wrap',
        backgroundColor: theme.card, padding: '20px', borderRadius: '20px', border: `1px solid ${theme.border}`
      }}>
        <button 
          onClick={() => setFilter("period")}
          style={{ padding: '12px 24px', borderRadius: '12px', border: 'none', cursor: 'pointer', fontWeight: 'bold', fontSize: '13px',
            backgroundColor: filter === "period" ? theme.accent : theme.primary,
            color: filter === "period" ? '#000' : theme.accent
          }}
        >
          📅 By Period
        </button>
        <button 
          onClick={() => setFilter("service")}
          style={{ padding: '12px 24px', borderRadius: '12px', border: 'none', cursor: 'pointer', fontWeight: 'bold', fontSize: '13px',
            backgroundColor: filter === "service" ? theme.accent : theme.primary,
            color: filter === "service" ? '#000' : theme.accent
          }}
        >
          🛠️ By Service
        </button>
        <button 
          onClick={() => setFilter("incidents")}
          style={{ padding: '12px 24px', borderRadius: '12px', border: 'none', cursor: 'pointer', fontWeight: 'bold', fontSize: '13px',
            backgroundColor: filter === "incidents" ? theme.accent : theme.primary,
            color: filter === "incidents" ? '#000' : theme.accent
          }}
        >
          ⚠️ By Incidents
        </button>
        
        {filter === "period" && (
          <>
            <input type="date" value={dateRange.start} onChange={(e) => setDateRange({...dateRange, start: e.target.value})} 
              style={{ padding: '10px 15px', borderRadius: '10px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text }} />
            <span style={{ color: theme.text }}>to</span>
            <input type="date" value={dateRange.end} onChange={(e) => setDateRange({...dateRange, end: e.target.value})} 
              style={{ padding: '10px 15px', borderRadius: '10px', border: `1px solid ${theme.border}`, backgroundColor: theme.input, color: theme.text }} />
          </>
        )}
      </div>

      {/* Platform Overview Cards */}
      <div style={{ marginBottom: '30px' }}>
        <h3 style={{ marginBottom: '20px', fontSize: '16px', fontWeight: 'bold', color: theme.text }}>📊 Platform Overview</h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '20px' }}>
          <div style={{ backgroundColor: theme.card, padding: '20px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
            <div style={{ fontSize: '28px', marginBottom: '10px' }}>👥</div>
            <div style={{ fontSize: '28px', fontWeight: '800' }}>{platformStats.totalUsers}</div>
            <div style={{ fontSize: '12px', color: '#737373' }}>Total Users</div>
            <div style={{ fontSize: '11px', color: '#10b981' }}>{platformStats.userGrowth} vs last month</div>
          </div>
          <div style={{ backgroundColor: theme.card, padding: '20px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
            <div style={{ fontSize: '28px', marginBottom: '10px' }}>🛡️</div>
            <div style={{ fontSize: '28px', fontWeight: '800' }}>{platformStats.totalProviders}</div>
            <div style={{ fontSize: '12px', color: '#737373' }}>Active Providers</div>
            <div style={{ fontSize: '11px', color: '#10b981' }}>{platformStats.activeServices} services offered</div>
          </div>
          <div style={{ backgroundColor: theme.card, padding: '20px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
            <div style={{ fontSize: '28px', marginBottom: '10px' }}>💰</div>
            <div style={{ fontSize: '28px', fontWeight: '800' }}>{platformStats.totalRevenue.toLocaleString()} DZD</div>
            <div style={{ fontSize: '12px', color: '#737373' }}>Total Revenue</div>
            <div style={{ fontSize: '11px', color: '#10b981' }}>{platformStats.revenueGrowth} growth</div>
          </div>
          <div style={{ backgroundColor: theme.card, padding: '20px', borderRadius: '20px', border: `1px solid ${theme.border}` }}>
            <div style={{ fontSize: '28px', marginBottom: '10px' }}>⭐</div>
            <div style={{ fontSize: '28px', fontWeight: '800' }}>{platformStats.avgRating}</div>
            <div style={{ fontSize: '12px', color: '#737373' }}>Average Rating</div>
            <div style={{ fontSize: '11px', color: '#10b981' }}>{platformStats.completionRate}% completion rate</div>
          </div>
        </div>
      </div>

      {/* Dynamic Content Based on Filter */}
      {filter === "period" && (
        <div style={{ backgroundColor: theme.card, borderRadius: '25px', border: `1px solid ${theme.border}`, padding: '25px', marginBottom: '30px' }}>
          <h3 style={{ marginBottom: '20px', fontSize: '18px', fontWeight: 'bold' }}>📅 Period Analytics (Last 30 Days)</h3>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '20px' }}>
            <div style={{ padding: '20px', backgroundColor: theme.input, borderRadius: '15px' }}>
              <div style={{ fontSize: '12px', color: '#737373' }}>Total Bookings</div>
              <div style={{ fontSize: '32px', fontWeight: '800', color: theme.accent }}>{periodData.month.bookings}</div>
              <div style={{ fontSize: '11px', color: '#10b981' }}>↑ 15% vs last period</div>
            </div>
            <div style={{ padding: '20px', backgroundColor: theme.input, borderRadius: '15px' }}>
              <div style={{ fontSize: '12px', color: '#737373' }}>Total Revenue</div>
              <div style={{ fontSize: '32px', fontWeight: '800', color: theme.accent }}>{periodData.month.revenue.toLocaleString()} DZD</div>
              <div style={{ fontSize: '11px', color: '#10b981' }}>↑ 12% vs last period</div>
            </div>
            <div style={{ padding: '20px', backgroundColor: theme.input, borderRadius: '15px' }}>
              <div style={{ fontSize: '12px', color: '#737373' }}>New Users</div>
              <div style={{ fontSize: '32px', fontWeight: '800', color: theme.accent }}>{periodData.month.newUsers}</div>
              <div style={{ fontSize: '11px', color: '#10b981' }}>↑ 8% vs last period</div>
            </div>
            <div style={{ padding: '20px', backgroundColor: theme.input, borderRadius: '15px' }}>
              <div style={{ fontSize: '12px', color: '#737373' }}>Active Providers</div>
              <div style={{ fontSize: '32px', fontWeight: '800', color: theme.accent }}>{periodData.month.activeProviders}</div>
              <div style={{ fontSize: '11px', color: '#10b981' }}>↑ 5% vs last period</div>
            </div>
          </div>
        </div>
      )}

      {filter === "service" && serviceData.length > 0 && (
        <div style={{ backgroundColor: theme.card, borderRadius: '25px', border: `1px solid ${theme.border}`, overflow: 'hidden', marginBottom: '30px' }}>
          <div style={{ padding: '20px 25px', borderBottom: `1px solid ${theme.border}` }}>
            <h3 style={{ fontSize: '18px', fontWeight: 'bold' }}>🛠️ Service Performance</h3>
          </div>
          <div style={{ padding: '25px' }}>
            <div style={{ marginBottom: '30px' }}>
              <div style={{ fontSize: '13px', color: '#737373', marginBottom: '15px' }}>Bookings by Service</div>
              {serviceData.map(service => (
                <div key={service.name} style={{ marginBottom: '15px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '5px' }}>
                    <span style={{ fontSize: '12px' }}>{service.name}</span>
                    <span style={{ fontSize: '12px', fontWeight: 'bold' }}>{service.bookings} bookings</span>
                  </div>
                  <div style={{ height: '8px', backgroundColor: theme.input, borderRadius: '10px', overflow: 'hidden' }}>
                    <div style={{ width: `${(service.bookings / maxBookings) * 100}%`, height: '100%', backgroundColor: theme.accent, borderRadius: '10px' }} />
                  </div>
                </div>
              ))}
            </div>

            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
              <thead>
                <tr style={{ borderBottom: `1px solid ${theme.border}` }}>
                  <th style={{ padding: '12px 0', textAlign: 'left' }}>Service</th>
                  <th style={{ padding: '12px 0', textAlign: 'right' }}>Bookings</th>
                  <th style={{ padding: '12px 0', textAlign: 'right' }}>Revenue</th>
                  <th style={{ padding: '12px 0', textAlign: 'right' }}>Rating</th>
                  <th style={{ padding: '12px 0', textAlign: 'right' }}>Growth</th>
                 </tr>
              </thead>
              <tbody>
                {serviceData.map(service => (
                  <tr key={service.name} style={{ borderBottom: `1px solid ${theme.border}` }}>
                    <td style={{ padding: '12px 0', fontWeight: '600' }}>{service.name}</td>
                    <td style={{ padding: '12px 0', textAlign: 'right' }}>{service.bookings}</td>
                    <td style={{ padding: '12px 0', textAlign: 'right', color: theme.accent }}>{service.revenue.toLocaleString()} DZD</td>
                    <td style={{ padding: '12px 0', textAlign: 'right' }}>⭐ {service.rating}</td>
                    <td style={{ padding: '12px 0', textAlign: 'right', color: '#10b981' }}>↑ {service.growth}%</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {filter === "incidents" && (
        <div style={{ backgroundColor: theme.card, borderRadius: '25px', border: `1px solid ${theme.border}`, padding: '25px', marginBottom: '30px' }}>
          <h3 style={{ marginBottom: '20px', fontSize: '18px', fontWeight: 'bold' }}>⚠️ Incident Analysis</h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '30px' }}>
            <div>
              <div style={{ fontSize: '13px', color: '#737373', marginBottom: '15px' }}>Incidents by Type</div>
              {incidentData.map(incident => (
                <div key={incident.type} style={{ marginBottom: '15px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '5px' }}>
                    <span style={{ fontSize: '12px' }}>{incident.type}</span>
                    <span style={{ fontSize: '12px', fontWeight: 'bold' }}>{incident.count} incidents</span>
                  </div>
                  <div style={{ height: '8px', backgroundColor: theme.input, borderRadius: '10px', overflow: 'hidden' }}>
                    <div style={{ width: `${incident.percentage}%`, height: '100%', backgroundColor: '#ef4444', borderRadius: '10px' }} />
                  </div>
                </div>
              ))}
            </div>
            <div style={{ textAlign: 'center', padding: '20px', backgroundColor: theme.input, borderRadius: '15px' }}>
              <div style={{ fontSize: '48px', fontWeight: '800', color: '#ef4444' }}>35</div>
              <div style={{ fontSize: '12px', color: '#737373' }}>Total Incidents (Last 30 Days)</div>
              <div style={{ fontSize: '11px', color: '#10b981', marginTop: '10px' }}>↓ 8% vs last period</div>
              <div style={{ marginTop: '20px', fontSize: '12px' }}>
                <span style={{ color: '#ef4444' }}>●</span> Resolution Rate: <strong>82%</strong>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Export Button */}
      <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
        <button 
          onClick={exportToCSV}
          style={{ padding: '12px 30px', backgroundColor: theme.primary, color: theme.accent, border: `1px solid ${theme.accent}`, borderRadius: '12px', cursor: 'pointer', fontWeight: 'bold' }}
        >
          📊 Export Statistics
        </button>
      </div>
    </div>
  );
};

export default AdminStats;