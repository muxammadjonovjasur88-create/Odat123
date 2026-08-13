import React from 'react';

interface ODATCardProps {
  children: React.ReactNode;
  className?: string;
  style?: React.CSSProperties;
  onClick?: () => void;
  glow?: boolean;
}

export const ODATCard: React.FC<ODATCardProps> = ({ children, className = '', style, onClick, glow = false }) => {
  return (
    <div
      onClick={onClick}
      style={{
        background: 'var(--surface-1)',
        borderRadius: 'var(--radius-xl)',
        border: glow ? '1px solid var(--border-bright)' : '1px solid var(--border-subtle)',
        boxShadow: glow ? '0 0 20px rgba(0, 122, 255, 0.12)' : '0 4px 12px rgba(0, 0, 0, 0.2)',
        padding: '16px',
        transition: 'all 0.2s ease',
        cursor: onClick ? 'pointer' : 'default',
        position: 'relative',
        overflow: 'hidden',
        ...style,
      }}
      className={className}
    >
      {children}
    </div>
  );
};
