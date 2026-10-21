import React from 'react';

interface MaterialIconProps {
  name: string;
  filled?: boolean;
  className?: string;
  size?: number | string;
  style?: React.CSSProperties;
}

/**
 * Google Material Symbols Rounded Icon
 * Renders authentic Material Symbols with variable FILL (filled when active, outlined when inactive)
 */
export const MaterialIcon: React.FC<MaterialIconProps> = ({
  name,
  filled = false,
  className = '',
  size = 24,
  style = {},
}) => {
  return (
    <span
      className={`material-symbols-rounded select-none inline-flex items-center justify-center shrink-0 ${filled ? 'filled' : ''} ${className}`}
      style={{
        fontSize: typeof size === 'number' ? `${size}px` : size,
        width: typeof size === 'number' ? `${size}px` : size,
        height: typeof size === 'number' ? `${size}px` : size,
        fontVariationSettings: `'FILL' ${filled ? 1 : 0}, 'wght' 400, 'GRAD' 0, 'opsz' 24`,
        lineHeight: 1,
        ...style,
      }}
      aria-hidden="true"
    >
      {name}
    </span>
  );
};
