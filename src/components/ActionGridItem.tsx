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
            disabled={true}
            width={'100%'}
            fontWeight={'bold'}
            mb={6}
            onClick={() => {
              write?.();
            }}
            fontSize={'16px'}
            textAlign={'center'}>
            {title}
          </Button>
          {/* {title == '📣 Push Notification' && (
            <Container>
              <Img
                width={'50px'}
                src="https://pushprotocol.notion.site/image/https%3A%2F%2Fs3-us-west-2.amazonaws.com%2Fsecure.notion-static.com%2Ff3f8624f-e79a-441b-a732-1cba0af10134%2FBell.png?id=f57cc1cb-9300-4263-b121-0b3eedb15188&table=block&spaceId=95c3c07c-15ae-41e0-b1c2-cc952f688f21&width=290&userId=&cache=v2"
              />
            </Container>
          )} */}
          <p>{subTitle}</p>
        </CardBody>
      </Card>
    </GridItem>
  );
}

export default ActionGridItem;
