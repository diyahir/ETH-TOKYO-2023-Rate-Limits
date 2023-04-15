import 'styles/globals.scss';
import type { AppProps } from 'next/app';
import WagmiProvider from 'providers/WagmiProvider';
import { ChakraProvider } from '@chakra-ui/react';
import { extendTheme, type ThemeConfig } from '@chakra-ui/react';

const MyApp = ({ Component, pageProps }: AppProps) => {
  const config: ThemeConfig = {
    initialColorMode: 'dark',
    useSystemColorMode: false
  };

  const theme = extendTheme({ config });

  return (
    <ChakraProvider theme={theme}>
      <WagmiProvider>
        <Component {...pageProps} />
      </WagmiProvider>
    </ChakraProvider>
  );
};

export default MyApp;
