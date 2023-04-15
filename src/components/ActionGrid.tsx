import React, { useState, useEffect } from 'react';
import { Card, CardBody, Grid, GridItem, HStack, Img, Text } from '@chakra-ui/react';
import ActionGridItem from './ActionGridItem';

function ActionGrid({}) {
  return (
    <Grid mt={20} templateColumns={'repeat(4,1fr)'} gap={10}>
      <ActionGridItem
        title={'🌱 Override Rate Limit'}
        subTitle={
          'If this was a false positive, you can override the rate limit and allow withdrawls.'
        }
      />

      <ActionGridItem
        title={'⚡  Extend Timeout'}
        subTitle={
          'If this was a false positive, you can override the rate limit and allow withdrawls.'
        }
      />

      <ActionGridItem
        title={'📦 Migrate Contract'}
        subTitle={'If you need to migrate the contract, you can do so here.'}
      />

      <ActionGridItem
        title={'📣 Push Notification'}
        subTitle={
          'If you need to push an alert to the community, you can do so here. This will send a message alerting the community that the rate limit has been breached'
        }
      />
    </Grid>
  );
}

export default ActionGrid;
