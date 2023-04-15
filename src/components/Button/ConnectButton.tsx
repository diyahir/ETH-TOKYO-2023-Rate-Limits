/* eslint-disable @next/next/no-img-element */
/* eslint-disable @typescript-eslint/no-shadow */
import { Button, VStack, Text, ButtonGroup, Select } from '@chakra-ui/react';
import { useEffect, useState } from 'react';
import { useAccount, useBalance, useConnect, useDisconnect, useEnsAvatar, useEnsName } from 'wagmi';

const ConnectButton = () => {
  const { address, connector, isConnected } = useAccount();

  const { data: ensAvatar } = useEnsAvatar({ address });
  const { data: ensName } = useEnsName({ address });
  const { connect, connectors, error, isLoading, pendingConnector } = useConnect();
  const { disconnect } = useDisconnect();
  const [chainId, setChainId] = useState(10200);

  if (isConnected) {
    return (
      <ButtonGroup>
        <Select placeholder="Switch Network">
          <option
            onChange={(e) => {
              console.log('e', e);
              setChainId(1);
            }}
            onClick={() => {
              setChainId(1);
            }}
            value="option1">
            Mainnet
          </option>
          <option
            onChange={(e) => {
              console.log('e', e);
              setChainId(97);
            }}
            onClick={() => setChainId(97)}
            value="option2">
            BSC Testnet
          </option>
          <option onClick={() => setChainId(100)} value="option2">
            Gnosis Chain
          </option>
        </Select>
        <Button minW={'fit-content'} onClick={() => disconnect()}>
          {ensName ? `${ensName}` : address} - Disconnect
        </Button>
      </ButtonGroup>
    );
  }

  return (
    <ButtonGroup>
      {connectors.map((connector) => {
        if (!connector) return null;
        return (
          <ButtonGroup>
            <Button
              type="button"
              disabled={!connector.ready}
              key={connector.id}
              onClick={() => connect({ connector, chainId: chainId })}>
              {connector.name}
              {!connector.ready && ' (unsupported)'}
              {isLoading && connector.id === pendingConnector?.id && ' (connecting)'}
            </Button>
          </ButtonGroup>
        );
      })}

      {error && <div>{error.message}</div>}
    </ButtonGroup>
  );
};

export default ConnectButton;
