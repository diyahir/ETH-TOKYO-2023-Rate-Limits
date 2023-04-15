import React, { useState, useEffect } from 'react';
import { Text } from '@chakra-ui/react';

function RateLimitIndicator({ limitReachedColor = 'red', limitNotReachedColor = 'green' }) {
  const [isLimitReached, setIsLimitReached] = useState(false);

  const dotColor = isLimitReached ? limitReachedColor : limitNotReachedColor;
  const statusText = isLimitReached ? 'Rate limit breached' : 'Operational';

  return (
    <div style={{ marginTop: '20px', display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          backgroundColor: dotColor,
          width: '10px',
          height: '10px',
          // pulsing

          borderRadius: '50%',
          marginRight: '5px'
        }}></div>
      <Text fontSize={'20px'}>Status: {statusText} </Text>
    </div>
  );
}

export default RateLimitIndicator;
