import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import './index.css';

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error("ErrorBoundary caught an error:", error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{ padding: 24, color: '#fff', background: '#0f172a', minHeight: '100vh', fontFamily: 'sans-serif' }}>
          <h2 style={{ color: '#ef4444' }}>⚠️ Admin Panel yuklanishida xatolik</h2>
          <pre style={{ background: '#1e293b', padding: 16, borderRadius: 8, overflow: 'auto', fontSize: 12 }}>
            {String(this.state.error?.stack || this.state.error)}
          </pre>
          <button
            onClick={() => window.location.reload()}
            style={{ marginTop: 16, padding: '10px 20px', background: '#10b981', color: '#000', border: 'none', borderRadius: 8, fontWeight: 'bold', cursor: 'pointer' }}
          >
            🔄 Sahifani qayta yuklash
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <ErrorBoundary>
    <App />
  </ErrorBoundary>
);
