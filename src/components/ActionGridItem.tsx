import React, { useState, useEffect } from 'react';
import {
  Button,
  Card,
  CardBody,
  Container,
  Grid,
  GridItem,
  HStack,
  Img,
  Text
} from '@chakra-ui/react';

import {
  useAccount,
  useContract,
  useContractWrite,
  usePrepareContractWrite,
  useProvider
} from 'wagmi';
import gaurdianJson from '../../contracts/out/Gaurdian.sol/Gaurdian.json';
import { FollowOnLens, ShareToLens } from '@lens-protocol/widgets-react';

export interface Props {
  title: String;
  subTitle: String;
}
function ActionGridItem({ title, subTitle }: Props) {
  // const provider = useProvider();
  // const contract = useContract({
  //   address: '0xD22a7ECF2e09dDa61a114751794bC1e3B8dBaa4f',
  //   abi: gaurdianJson.abi,
  //   signerOrProvider: provider
  // });

  const { config } = usePrepareContractWrite({
    address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
    abi: gaurdianJson.abi,
    functionName: 'overrideLimit'
  });
  const { write } = useContractWrite(config);

  return (
    <GridItem maxH={'100%'} display={'flex'}>
      <Card borderColor={'gray.800'} borderWidth={2} borderRadius={15} display={'flex'} h={'100%'}>
        <CardBody>
          <Button
            fontWeight={'bold'}
            fontFamily={'IBM Plex Mono'}
            // isDisabled={true}
            width={'100%'}
            mb={6}
            onClick={() => {
              write?.();
            }}
            fontSize={'16px'}
            textAlign={'center'}>
            {title}
          </Button>

          {title == '📣 Push Notification' && (
            <Container>
              <div>
                <ShareToLens content="Rate limit triggered." />
              </div>
            </Container>
          )}
          <Text fontWeight={'bold'} fontFamily={'IBM Plex Mono'}>
            {subTitle}
          </Text>
        </CardBody>
      </Card>
    </GridItem>
  );
}

export default ActionGridItem;
