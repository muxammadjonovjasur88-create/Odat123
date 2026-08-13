import React from 'react';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'success';
export type ButtonState = 'default' | 'loading' | 'success' | 'error' | 'disabled';

interface ODATButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  state?: ButtonState;
  fullWidth?: boolean;
  size?: 'sm' | 'md' | 'lg';
  icon?: React.ReactNode;
}

export const ODATButton: React.FC<ODATButtonProps> = ({
  children,
  variant = 'primary',
  state = 'default',
  fullWidth = false,
  size = 'md',
  icon,
  disabled,
  onClick,
  style,
  className = '',
  ...props
}) => {
  const isButtonDisabled = disabled || state === 'disabled' || state === 'loading';

  const getSizeStyles = () => {
    switch (size) {
      case 'sm': return { padding: '8px 14px', fontSize: '13px', borderRadius: '8px' };
      case 'lg': return { padding: '16px 24px', fontSize: '16px', borderRadius: '16px' };
      case 'md':
      default: return { padding: '12px 20px', fontSize: '14px', borderRadius: '12px' };
    }
  };

  const getVariantStyles = () => {
    if (state === 'success') {
      return {
        background: '#00e5ff',
        color: '#000000',
        border: 'none',
        boxShadow: '0 0 15px rgba(0, 229, 255, 0.4)',
      };
    }
    if (state === 'error') {
      return {
        background: '#ff4d4d',
        color: '#ffffff',
        border: 'none',
      };
    }

    switch (variant) {
      case 'secondary':
        return {
          background: 'var(--surface-2)',
          color: 'var(--text-primary)',
          border: '1px solid var(--border-subtle)',
        };
      case 'ghost':
        return {
          background: 'transparent',
          color: 'var(--brand-cyan)',
          border: '1px solid transparent',
        };
      case 'danger':
        return {
          background: 'rgba(255, 77, 77, 0.15)',
          color: '#ff4d4d',
          border: '1px solid rgba(255, 77, 77, 0.3)',
        };
      case 'success':
        return {
          background: 'rgba(0, 229, 255, 0.15)',
          color: '#00e5ff',
          border: '1px solid rgba(0, 229, 255, 0.3)',
        };
      case 'primary':
      default:
        return {
          background: 'var(--gradient-discipline)',
          color: '#ffffff',
          border: 'none',
          boxShadow: '0 4px 20px rgba(0, 122, 255, 0.3)',
        };
    }
  };

  return (
    <button
      disabled={isButtonDisabled}
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '8px',
        fontWeight: '600',
        cursor: isButtonDisabled ? 'not-allowed' : 'pointer',
        opacity: isButtonDisabled && state !== 'loading' ? 0.5 : 1,
        transition: 'all 0.2s cubic-bezier(0.16, 1, 0.3, 1)',
        width: fullWidth ? '100%' : 'auto',
        outline: 'none',
        fontFamily: 'inherit',
        ...getSizeStyles(),
        ...getVariantStyles(),
        ...style,
      }}
      className={className}
      {...props}
    >
      {state === 'loading' ? (
        <>
          <div style={{
            width: '16px',
            height: '16px',
            border: '2px solid rgba(255, 255, 255, 0.3)',
            borderTopColor: '#ffffff',
            borderRadius: '50%',
            animation: 'shimmer 0.8s infinite linear',
          }} />
          <span>Yuklanmoqda...</span>
        </>
      ) : state === 'success' ? (
        <>
          <span>✓ Bajarildi</span>
        </>
      ) : (
        <>
          {icon && <span style={{ display: 'inline-flex' }}>{icon}</span>}
          <span>{children}</span>
        </>
      )}
    </button>
  );
};
