import React, { useState, useEffect } from 'react';
import { Button, Card, CardBody, Grid, GridItem, HStack, Img, Text } from '@chakra-ui/react';

export interface Props {
  title: String;
  subTitle: String;
}
function ActionGridItem({ title, subTitle }: Props) {
  return (
    <GridItem maxH={'100%'} display={'flex'}>
      <Card borderColor={'gray.800'} borderWidth={2} borderRadius={15} display={'flex'} h={'100%'}>
        <CardBody>
          <Button
            disabled={true}
            width={'100%'}
            fontWeight={'bold'}
            mb={6}
            fontSize={'16px'}
            textAlign={'center'}>
            {title}
          </Button>
          <p>{subTitle}</p>
        </CardBody>
      </Card>
    </GridItem>
  );
}

export default ActionGridItem;
