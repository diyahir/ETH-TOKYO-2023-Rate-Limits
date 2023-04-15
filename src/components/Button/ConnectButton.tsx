/* eslint-disable @next/next/no-img-element */
/* eslint-disable @typescript-eslint/no-shadow */
import { Button, VStack, Text, ButtonGroup } from '@chakra-ui/react';
import { useAccount, useConnect, useDisconnect, useEnsAvatar, useEnsName } from 'wagmi';

const ConnectButton = () => {
  const { address, connector, isConnected } = useAccount();
  const { data: ensAvatar } = useEnsAvatar({ address });
  const { data: ensName } = useEnsName({ address });
  const { connect, connectors, error, isLoading, pendingConnector } = useConnect();
  const { disconnect } = useDisconnect();

  if (isConnected) {
    return (
      <Button onClick={() => disconnect()}>{ensName ? `${ensName}` : address} - Disconnect</Button>
    );
  }

  return (
    <ButtonGroup>
      {connectors.map((connector) => {
        if (!connector) return null;
        return (
          <Button
            type="button"
            disabled={!connector.ready}
            key={connector.id}
            onClick={() => connect({ connector, chainId: 1 })}>
            {connector.name}
            {!connector.ready && ' (unsupported)'}
            {isLoading && connector.id === pendingConnector?.id && ' (connecting)'}
          </Button>
        );
      })}

      {error && <div>{error.message}</div>}
    </ButtonGroup>
  );
};

export default ConnectButton;
