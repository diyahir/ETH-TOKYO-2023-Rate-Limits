import React, { useState, useEffect } from 'react';
import { Card, CardBody, Grid, GridItem, HStack, Img, Text } from '@chakra-ui/react';

function ActionGrid({}) {
  return (
    <Grid mt={20} templateColumns={'repeat(4,1fr)'} gap={40}>
      <GridItem maxH={'100%'} display={'flex'}>
        <Card
          backgroundColor={'#16181C'}
          p={15}
          borderRadius={15}
          h={'max'}
          style={{
            cursor: 'pointer'
          }}>
          <CardBody>
            <Text fontWeight={'bold'} mb={10} fontSize={'16px'}>
              🌱 &nbsp; Override Rate Limit
            </Text>
            <p>
              If this was a false positive, you can override the rate limit and allow withdrawls.
            </p>
          </CardBody>
        </Card>
      </GridItem>

      <GridItem maxH={'100%'} display={'flex'}>
        <Card
          backgroundColor={'#16181C'}
          p={15}
          borderRadius={15}
          style={{
            cursor: 'pointer'
          }}>
          <Text fontWeight={'bold'} mb={10} fontSize={'16px'}>
            ⚡ &nbsp; Extend Timeout
          </Text>
          <p>If you need more time to assess the situation, you can extend the timeout period.</p>
        </Card>
      </GridItem>

      <GridItem maxH={'100%'} display={'flex'}>
        <Card
          backgroundColor={'#16181C'}
          p={15}
          borderRadius={15}
          style={{
            cursor: 'pointer'
          }}>
          <Text fontWeight={'bold'} mb={10} fontSize={'16px'}>
            📦 &nbsp; Migrate Contract
          </Text>
          <p>If you need to migrate the contract, you can do so here.</p>
        </Card>
      </GridItem>

      <GridItem maxH={'100%'} display={'flex'}>
        <Card
          backgroundColor={'#16181C'}
          p={15}
          borderRadius={15}
          style={{
            cursor: 'pointer'
          }}>
          <HStack mb={10}>
            {' '}
            <Img
              src="https://pbs.twimg.com/profile_images/1616110831975931909/5tUeoUR__400x400.png"
              alt="Telegram"
              width="20px"
              height="20px"
              borderRadius="100"
            />
            <Text fontWeight={'bold'} fontSize={'16px'}>
              Push Notification
            </Text>
          </HStack>
          <p>
            If you need to push an alert to the community, you can do so here. This will send a
            message alerting the community that the rate limit has been breached.
          </p>
        </Card>
      </GridItem>
    </Grid>
  );
}

export default ActionGrid;
