import React, { useState } from 'react';
import AdminLogin from './AdminLogin';
import AdminLayout from './AdminLayout';
import Dashboard from './Dashboard';
import ConsultUsers from './ConsultUsers';
import InscriptionRequests from './InscriptionRequests';
import AdminReports from './AdminReports';
import AdminStats from './AdminStats';
import AddCategory from './AddCategory';
import AddService from './AddService';
import ConsultCategories from './ConsultCategories';
import ConsultServices from './ConsultServices';
import BookingTracking from './BookingTracking';
import RefundClient from './RefundClient';
import ServiceReports from './ServiceReports';

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [isDarkMode, setIsDarkMode] = useState(true);
  const [currentPage, setCurrentPage] = useState('dashboard');

  const handleLogout = () => {
    setIsLoggedIn(false);
    setCurrentPage('dashboard');
  };

  if (!isLoggedIn) {
    return <AdminLogin onLogin={() => setIsLoggedIn(true)} isDarkMode={isDarkMode} />;
  }

  return (
    <AdminLayout 
      setCurrentPage={setCurrentPage} 
      currentPage={currentPage} 
      isDarkMode={isDarkMode}
      toggleTheme={() => setIsDarkMode(!isDarkMode)}
      onLogout={handleLogout}
    >
      {currentPage === 'dashboard' && <Dashboard isDarkMode={isDarkMode} />}
      {currentPage === 'users' && <ConsultUsers isDarkMode={isDarkMode} />}
      {currentPage === 'requests' && <InscriptionRequests isDarkMode={isDarkMode} />}
      {currentPage === 'tracking' && <BookingTracking isDarkMode={isDarkMode} />}
      {currentPage === 'refund' && <RefundClient isDarkMode={isDarkMode} />}
      {currentPage === 'reports' && <AdminReports isDarkMode={isDarkMode} />}
      {currentPage === 'service-reports' && <ServiceReports isDarkMode={isDarkMode} />}
      {currentPage === 'stats' && <AdminStats isDarkMode={isDarkMode} />}
      {currentPage === 'add-category' && <AddCategory isDarkMode={isDarkMode} />}
      {currentPage === 'add-service' && <AddService isDarkMode={isDarkMode} />}
      {currentPage === 'consult-categories' && <ConsultCategories isDarkMode={isDarkMode} />}
      {currentPage === 'consult-services' && <ConsultServices isDarkMode={isDarkMode} />}
    </AdminLayout>
  );
}

export default App;